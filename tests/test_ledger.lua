package.path = './?.lua;' .. package.path
local T = require 'tests.framework'
local F = require 'tests.fakes'
local ledgermod = require 'core.ledger'

local function mk(portOpts, storeOpts, dieAt)
    local w = F.world(dieAt)
    local store = F.store(w, storeOpts)
    local ports = F.ports(w, portOpts)
    local l = ledgermod.new({ store = store, ports = ports, clock = function() return 1000 end })
    return l, w, store, ports
end

local function states(store)
    local out = {}
    for _, r in ipairs(store.recs) do out[#out + 1] = r.state end
    return table.concat(out, '>')
end

T.test('venda feliz: ordem, uma remocao, um pagamento, journal completo', function()
    local l, w, store = mk()
    T.truthy(l:start())
    local r = l:execute_sale(F.tx())
    T.eq(r.status, 'completed')
    T.eq(w.removed, 1); T.eq(w.paid, 1); T.eq(w.returned, 0)
    T.eq(states(store), 'created>item_removed>paying>paid>completed')
    T.eq(w.log[1], 'remove_item'); T.eq(w.log[2], 'pay')
end)

T.test('evento de pagamento DUPLICADO nao paga nem remove de novo (idempotencia)', function()
    local l, w = mk()
    l:start()
    l:execute_sale(F.tx())
    local r2 = l:execute_sale(F.tx())
    T.eq(r2.status, 'completed'); T.truthy(r2.duplicate)
    for _ = 1, 20 do l:execute_sale(F.tx()) end
    T.eq(w.removed, 1); T.eq(w.paid, 1)
end)

T.test('duplicata mesmo com valores diferentes (adulterado) mantem a transacao original', function()
    local l, w = mk()
    l:start()
    l:execute_sale(F.tx())
    local r = l:execute_sale(F.tx({ unitPrice = 9999, total = 19998 }))
    T.truthy(r.duplicate); T.eq(w.paid, 1)
end)

T.test('reentrada durante a remocao (concorrencia) e tratada como duplicata', function()
    local w = F.world()
    local store = F.store(w)
    local l
    local inner
    local ports = F.ports(w)
    local orig = ports.remove_item
    ports.remove_item = function(tx) inner = l:execute_sale(F.tx()); return orig(tx) end
    l = ledgermod.new({ store = store, ports = ports, clock = function() return 1 end })
    l:start()
    local r = l:execute_sale(F.tx())
    T.truthy(inner.duplicate, 'chamada reentrante nao reexecuta')
    T.eq(r.status, 'completed'); T.eq(w.removed, 1); T.eq(w.paid, 1)
end)

T.test('falha ao gravar a intencao: NADA e removido nem pago', function()
    local l, w = mk(nil, { failAt = 2 }) -- 1 = (nenhum no start); 1o append e created
    l:start()
    local store = l.store; store.failAt = 1; store.appends = 0
    local r, err = l:execute_sale(F.tx())
    T.eq(r, nil); T.truthy(err:find('journal_write_failed'))
    T.eq(w.removed, 0); T.eq(w.paid, 0)
    T.eq(l.tx['sess1:conf1'], nil, 'nao deixa estado fantasma')
end)

T.test('estoque ausente (remove_item=false): aborta sem pagar', function()
    local l, w, store = mk({ removeResult = false })
    l:start()
    T.eq(l:execute_sale(F.tx()).status, 'aborted')
    T.eq(w.paid, 0); T.eq(w.returned, 0); T.eq(states(store), 'created>aborted')
end)

T.test('remove_item lanca erro (ambiguo): revisao, sem pagamento e sem devolucao', function()
    local l, w = mk({ removeResult = 'throw' })
    l:start()
    T.eq(l:execute_sale(F.tx()).status, 'needs_review')
    T.eq(w.paid, 0); T.eq(w.returned, 0)
end)

T.test('pagamento falha (false): devolve o item exatamente uma vez', function()
    local l, w, store = mk({ payResult = false })
    l:start()
    T.eq(l:execute_sale(F.tx()).status, 'compensated')
    T.eq(w.removed, 1); T.eq(w.paid, 0); T.eq(w.returned, 1)
    T.eq(states(store), 'created>item_removed>paying>pay_failed>compensating>compensated')
end)

T.test('pagamento lanca erro (ambiguo): NAO devolve (evita duplicar) e NAO repaga', function()
    local l, w = mk({ payResult = 'throw' })
    l:start()
    T.eq(l:execute_sale(F.tx()).status, 'needs_review')
    T.eq(w.paid, 0); T.eq(w.returned, 0)
    T.eq(#l:list_review(), 1)
end)

T.test('falha na compensacao: revisao manual', function()
    local l, w = mk({ payResult = false, returnResult = false })
    l:start()
    T.eq(l:execute_sale(F.tx()).status, 'needs_review')
    T.eq(w.returned, 0)
end)

T.test('validacao defensiva: total adulterado, quantidade, chave, preco', function()
    local l = mk(); l:start()
    T.err('total_mismatch', l:execute_sale(F.tx({ total = 1 })))
    T.err('bad_quantity', l:execute_sale(F.tx({ qty = 5, total = 9500 })))
    T.err('bad_quantity', l:execute_sale(F.tx({ qty = 0, total = 0 })))
    T.err('bad_unit_price', l:execute_sale(F.tx({ unitPrice = -5, total = -10 })))
    T.err('bad_key', l:execute_sale(F.tx({ key = '' })))
    local noid = F.tx(); noid.identifier = nil
    T.err('bad_identifier', l:execute_sale(noid))
    T.err('bad_item', l:execute_sale(F.tx({ item = 5 })))
    T.err('bad_key', l:execute_sale(nil))
end)

T.test('journal corrompido/ilegivel: BLOQUEIA vendas (falha segura)', function()
    local l, w = mk(nil, { corrupt = true })
    local ok, err = l:start()
    T.eq(ok, nil); T.truthy(err:find('journal_unreadable'))
    T.err('ledger_locked', l:execute_sale(F.tx()))
    T.eq(w.removed, 0); T.eq(w.paid, 0)
end)

T.test('registro malformado no journal tambem bloqueia', function()
    local w = F.world(); local store = F.store(w)
    store.recs = { { id = 'k', state = 'paid' } } -- sem `created`/data
    local l = ledgermod.new({ store = store, ports = F.ports(w), clock = function() return 1 end })
    local ok, err = l:start()
    T.eq(ok, nil); T.eq(err, 'journal_corrupt')
    store.recs = { 'lixo' }
    local l2 = ledgermod.new({ store = store, ports = F.ports(w), clock = function() return 1 end })
    T.eq(select(2, l2:start()), 'journal_corrupt')
end)

T.test('nao inicia sem start()', function()
    local l = mk()
    T.err('ledger_not_started', l:execute_sale(F.tx()))
end)

T.test('restart com item removido e pagamento NAO iniciado: devolve o item (1x) e e idempotente', function()
    -- journal manual: created > item_removed (queda antes de `paying`)
    local w = F.world(); local store = F.store(w)
    store.recs = { { id = 'k1', seq = 1, state = 'created', data = F.tx({ key = 'k1' }) },
        { id = 'k1', seq = 2, state = 'item_removed' } }
    local mkl = function() return ledgermod.new({ store = store, ports = F.ports(w), clock = function() return 1 end }) end
    local l = mkl()
    local sum = l:start()
    T.eq(sum.refunded, 1); T.eq(w.returned, 1); T.eq(w.paid, 0)
    local l2 = mkl(); l2:start(); l2:start()
    T.eq(w.returned, 1, 'segunda recuperacao NAO devolve de novo')
end)

T.test('restart em estados ambiguos (created/paying/compensating) vai para revisao sem agir', function()
    for _, st in ipairs({ 'created', 'paying', 'compensating' }) do
        local w = F.world(); local store = F.store(w)
        store.recs = { { id = 'k', seq = 1, state = 'created', data = F.tx({ key = 'k' }) } }
        if st ~= 'created' then store.recs[2] = { id = 'k', seq = 2, state = st } end
        local l = ledgermod.new({ store = store, ports = F.ports(w), clock = function() return 1 end })
        local sum = l:start()
        T.eq(sum.review, 1, st); T.eq(w.paid, 0, st); T.eq(w.returned, 0, st); T.eq(w.removed, 0, st)
    end
end)

T.test('resolve: revisao manual fecha o caso e so aceita acoes validas', function()
    local l = mk({ payResult = 'throw' }); l:start()
    l:execute_sale(F.tx())
    T.err('bad_action', l:resolve('sess1:conf1', 'qualquer'))
    T.truthy(l:resolve('sess1:conf1', 'refunded_manually'))
    T.eq(#l:list_review(), 0)
    T.err('not_in_review', l:resolve('sess1:conf1', 'dismissed'))
    T.err('not_in_review', l:resolve('nao-existe', 'dismissed'))
end)

T.test('prune libera memoria de terminais antigos (nunca de needs_review)', function()
    local now = { t = 1000 }
    local w = F.world(); local store = F.store(w)
    local l = ledgermod.new({ store = store, ports = F.ports(w), clock = function() return now.t end })
    l:start()
    l:execute_sale(F.tx({ key = 'a' }))
    local l2 = ledgermod.new({ store = F.store(w), ports = F.ports(w, { payResult = 'throw' }), clock = function() return now.t end })
    l2:start(); l2:execute_sale(F.tx({ key = 'b' }))
    now.t = now.t + 5000
    T.eq(l:prune(3600), 1); T.eq(l2:prune(3600), 0)
end)

-- C07 / B09 / B10: queda do processo em QUALQUER operacao (append ou chamada de porta)
local scenarios = {
    { name = 'feliz', ports = {} },
    { name = 'pagamento falha', ports = { payResult = false } },
    { name = 'remocao falha', ports = { removeResult = false } },
}
for _, sc in ipairs(scenarios) do
    T.test('queda em cada ponto (' .. sc.name .. '): invariantes financeiros apos reinicio', function()
        local points = 0
        for k = 1, 40 do
            local w = F.world(k)
            local store = F.store(w)
            local l = ledgermod.new({ store = store, ports = F.ports(w, sc.ports), clock = function() return 1 end })
            l:start()
            pcall(l.execute_sale, l, F.tx())
            if not w.dead then break end -- k alem do total de operacoes: ja cobrimos tudo
            points = points + 1
            -- "reinicio": mesmo journal duravel, processo novo
            w.dead = false; w.dieAt = nil
            local l2 = ledgermod.new({ store = store, ports = F.ports(w, sc.ports), clock = function() return 1 end })
            l2:start()
            local e = l2.tx['sess1:conf1']
            local state = e and e.state
            local msg = ('k=%d estado=%s removed=%d paid=%d returned=%d'):format(k, tostring(state), w.removed, w.paid, w.returned)
            T.truthy(w.paid <= 1 and w.removed <= 1 and w.returned <= 1, 'sem duplicacao: ' .. msg)
            T.truthy(w.paid == 0 or w.removed == 1, 'pagamento so apos remocao: ' .. msg)
            T.truthy(w.returned == 0 or (w.removed == 1 and w.paid == 0), 'devolucao so se removeu e nao pagou: ' .. msg)
            if e then
                T.truthy(ledgermod.TERMINAL[state], 'estado final terminal: ' .. msg)
                if state == 'completed' then T.truthy(w.removed == 1 and w.paid == 1, msg) end
                if state == 'aborted' then T.truthy(w.removed == 0 and w.paid == 0, msg) end
                if state == 'compensated' then T.truthy(w.returned == 1 and w.paid == 0, msg) end
            end
            -- nada perdido em silencio: item removido sem pagamento/devolucao => revisao
            if w.removed == 1 and w.paid == 0 and w.returned == 0 and e then
                T.eq(state, 'needs_review', 'item perdido deve ir a revisao: ' .. msg)
            end
            -- pagou sem fechar => revisao (nunca repagar)
            if w.paid == 1 and e and state ~= 'completed' then
                T.eq(state, 'needs_review', 'pagamento ambiguo deve ir a revisao: ' .. msg)
            end
            -- segunda recuperacao nao altera efeitos
            local before = w.removed * 100 + w.paid * 10 + w.returned
            ledgermod.new({ store = store, ports = F.ports(w, sc.ports), clock = function() return 1 end }):start()
            T.eq(w.removed * 100 + w.paid * 10 + w.returned, before, 'recuperacao idempotente: ' .. msg)
        end
        T.truthy(points >= 3, 'varreu pontos de queda: ' .. points)
    end)
end

T.test('IO falha em cada append isolado: nunca duplica efeito e nunca perde silenciosamente', function()
    for n = 1, 8 do
        local w = F.world()
        local store = F.store(w, { failAt = n })
        local l = ledgermod.new({ store = store, ports = F.ports(w), clock = function() return 1 end })
        l:start()
        store.appends = 0
        l:execute_sale(F.tx())
        T.truthy(w.paid <= 1 and w.removed <= 1 and w.returned <= 1, 'falha no append ' .. n)
        T.truthy(w.paid == 0 or w.removed == 1, 'paga so com remocao, append ' .. n)
    end
end)
