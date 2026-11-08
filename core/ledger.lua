-- Ledger financeiro: venda = remover item -> pagar, com journal duravel, idempotencia, compensacao e
-- recuperacao. NAO ha atomicidade entre inventario e dinheiro (recursos distintos): a garantia e esta:
--   1) o registro (intencao) e gravado de forma duravel ANTES de cada acao externa;
--   2) logo, um registro perdido implica que a acao nao ocorreu;
--   3) estados ambiguos (acao pode ou nao ter ocorrido) NUNCA sao repetidos automaticamente: vao para
--      `needs_review` (revisao manual) - falha segura: sem pagamento duplicado e sem item duplicado.
--
-- Portas (injetadas pela camada Qbox; retornam true | false(falha definitiva); lancar erro = ambiguo):
--   ports.remove_item(tx)  ports.pay(tx)  ports.return_item(tx)
-- Store (duravel, ordem de insercao): store:append(rec) -> true | (nil,err);  store:load() -> recs | (nil,err)
local M = {}
M.__index = M

local TERMINAL = { completed = true, aborted = true, compensated = true, needs_review = true, resolved = true }
M.TERMINAL = TERMINAL

function M.new(opts)
    return setmetatable({
        store = assert(opts.store), ports = assert(opts.ports), clock = assert(opts.clock),
        maxUnitPrice = opts.maxUnitPrice or 1000000, maxPackages = opts.maxPackages or 4,
        recoverRemovedUnpaid = opts.recoverRemovedUnpaid or 'refund',
        tx = {}, locked = nil, started = false, seq = 0,
    }, M)
end

local function validate(self, tx)
    if type(tx) ~= 'table' or type(tx.key) ~= 'string' or tx.key == '' then return nil, 'bad_key' end
    if type(tx.identifier) ~= 'string' or tx.identifier == '' then return nil, 'bad_identifier' end
    if type(tx.item) ~= 'string' or tx.item == '' then return nil, 'bad_item' end
    local q, u, t = math.tointeger(tx.qty), math.tointeger(tx.unitPrice), math.tointeger(tx.total)
    if not q or q < 1 or q > self.maxPackages then return nil, 'bad_quantity' end
    if not u or u < 1 or u > self.maxUnitPrice then return nil, 'bad_unit_price' end
    if t ~= u * q then return nil, 'total_mismatch' end -- defesa em profundidade
    local ic = tx.itemCount == nil and q or math.tointeger(tx.itemCount)
    if not ic or ic < 1 or ic > 1000 then return nil, 'bad_item_count' end
    return { key = tx.key, identifier = tx.identifier, item = tx.item, itemCount = ic, qty = q, unitPrice = u,
        total = t, payKind = tx.payKind, kind = tx.kind, src = tx.src }
end

function M:_append(key, state, data, note)
    self.seq = self.seq + 1
    local ok, a, b = pcall(self.store.append, self.store,
        { id = key, seq = self.seq, state = state, ts = self.clock(), data = data, note = note })
    if not ok then return nil, tostring(a) end
    if a ~= true then return nil, b or 'append_failed' end
    local e = self.tx[key]
    if e then e.state = state; e.note = note; e.ts = self.clock() end
    return true
end

-- Carrega o journal e recupera pendencias. Falha de leitura/corrupcao => modo bloqueado (falha segura).
function M:start()
    self.started = true
    local recs, err = self.store:load()
    if not recs then
        self.locked = 'journal_unreadable:' .. tostring(err)
        return nil, self.locked
    end
    for _, r in ipairs(recs) do
        if type(r) ~= 'table' or type(r.id) ~= 'string' or type(r.state) ~= 'string' then
            self.locked = 'journal_corrupt'
            return nil, self.locked
        end
        local e = self.tx[r.id]
        if not e then
            if not r.data then self.locked = 'journal_corrupt'; return nil, self.locked end
            e = { key = r.id, data = r.data }
            self.tx[r.id] = e
        end
        e.state = r.state; e.note = r.note
        if r.seq and r.seq > self.seq then self.seq = r.seq end
    end
    return self:recover()
end

local function run_port(fn, tx)
    local ok, res = pcall(fn, tx)
    if not ok then return nil end -- excecao: resultado AMBIGUO
    return res == true             -- true | false definitivos
end

function M:_review(e, note)
    -- melhor esforco para registrar; em memoria o estado ja bloqueia reprocessamento
    local ok = self:_append(e.key, 'needs_review', nil, note)
    if not ok then e.state = 'needs_review'; e.note = note end
    return 'needs_review'
end

function M:_compensate(e)
    local ok = self:_append(e.key, 'compensating')
    if not ok then return self:_review(e, 'journal_write_failed_before_compensation') end
    local r = run_port(self.ports.return_item, e.data)
    if r == true then
        if not self:_append(e.key, 'compensated') then
            e.state = 'compensating' -- item JA devolvido; nao repetir
            return self:_review(e, 'compensated_but_journal_failed')
        end
        return 'compensated'
    end
    return self:_review(e, r == false and 'compensation_failed' or 'compensation_ambiguous')
end

-- Recuperacao (chamada por start()). Idempotente: cada tx so avanca ou vai para revisao.
function M:recover()
    local summary = { refunded = 0, review = 0, untouched = 0 }
    for _, e in pairs(self.tx) do
        local s = e.state
        if TERMINAL[s] then
            if s == 'needs_review' then summary.review = summary.review + 1 end
        elseif s == 'created' or s == 'paying' or s == 'compensating' then
            -- acao externa pode ou nao ter ocorrido: NUNCA repetir; revisao manual
            self:_review(e, 'ambiguous_after_restart:' .. s)
            summary.review = summary.review + 1
        elseif s == 'item_removed' then
            -- item removido e pagamento comprovadamente NAO iniciado (paying nao foi gravado)
            if self.recoverRemovedUnpaid == 'refund' then
                local res = self:_compensate(e)
                if res == 'compensated' then summary.refunded = summary.refunded + 1 else summary.review = summary.review + 1 end
            else
                self:_review(e, 'removed_unpaid_policy_review'); summary.review = summary.review + 1
            end
        elseif s == 'pay_failed' then
            local res = self:_compensate(e)
            if res == 'compensated' then summary.refunded = summary.refunded + 1 else summary.review = summary.review + 1 end
        elseif s == 'paid' then
            self:_append(e.key, 'completed')
        else
            self:_review(e, 'unknown_state:' .. tostring(s)); summary.review = summary.review + 1
        end
    end
    return summary
end

-- Executa uma venda. Retorna { status = ... , key = ... } ou (nil, erro).
function M:execute_sale(input)
    if not self.started then return nil, 'ledger_not_started' end
    if self.locked then return nil, 'ledger_locked' end
    local tx, verr = validate(self, input)
    if not tx then return nil, verr end

    local existing = self.tx[tx.key]
    if existing then -- idempotencia: mesmo evento repetido nunca refaz acoes
        return { status = existing.state, key = tx.key, duplicate = true }
    end
    -- (reentrada/concorrencia no mesmo key cai no ramo acima: self.tx[key] e criado ANTES de qualquer acao)
    local function done(status)
        return { status = status, key = tx.key }
    end

    -- 1) intencao duravel ANTES de qualquer acao externa
    local e = { key = tx.key, data = tx, state = 'new' }
    self.tx[tx.key] = e
    local ok, werr = self:_append(tx.key, 'created', tx)
    if not ok then
        self.tx[tx.key] = nil -- nada foi feito
        return nil, 'journal_write_failed:' .. tostring(werr)
    end

    -- 2) remover item
    local rem = run_port(self.ports.remove_item, tx)
    if rem == false then
        self:_append(tx.key, 'aborted', nil, 'remove_item_failed')
        e.state = 'aborted'
        return done('aborted')
    elseif rem == nil then
        return done(self:_review(e, 'remove_item_ambiguous'))
    end
    if not self:_append(tx.key, 'item_removed') then
        return done(self:_review(e, 'item_removed_but_journal_failed'))
    end

    -- 3) pagar: intencao 'paying' duravel ANTES de pagar
    if not self:_append(tx.key, 'paying') then
        -- pagamento NAO iniciado e item removido: devolver
        return done(self:_compensate(e))
    end
    local pay = run_port(self.ports.pay, tx)
    if pay == nil then
        return done(self:_review(e, 'payment_ambiguous'))
    elseif pay == false then
        if not self:_append(tx.key, 'pay_failed') then
            return done(self:_review(e, 'pay_failed_but_journal_failed'))
        end
        return done(self:_compensate(e))
    end
    if not self:_append(tx.key, 'paid') then
        return done(self:_review(e, 'paid_but_journal_failed')) -- pagou; nunca repetir
    end
    self:_append(tx.key, 'completed')
    e.state = 'completed'
    return done('completed')
end

-- Administracao: resolve item em revisao (apos conferencia humana).
function M:resolve(key, action)
    local e = self.tx[key]
    if not e or e.state ~= 'needs_review' then return nil, 'not_in_review' end
    if action ~= 'paid_manually' and action ~= 'refunded_manually' and action ~= 'dismissed' then
        return nil, 'bad_action'
    end
    local ok, err = self:_append(key, 'resolved', nil, action)
    if not ok then return nil, err end
    return true
end

function M:list_review()
    local out = {}
    for k, e in pairs(self.tx) do if e.state == 'needs_review' then out[#out + 1] = { key = k, note = e.note, data = e.data } end end
    table.sort(out, function(a, b) return a.key < b.key end)
    return out
end

-- Libera memoria de transacoes terminais antigas (chaves de idempotencia ficam no journal).
function M:prune(olderThanSec)
    local now, n = self.clock(), 0
    for k, e in pairs(self.tx) do
        if TERMINAL[e.state] and e.state ~= 'needs_review' and e.data and (e.ts or 0) <= now - olderThanSec then
            self.tx[k] = nil; n = n + 1
        end
    end
    return n
end

return M
