-- Dublês de teste: store em memoria com injecao de falhas e "mundo" que simula queda do processo.
local F = {}

local function deepcopy(v)
    if type(v) ~= 'table' then return v end
    local c = {}
    for k, x in pairs(v) do c[k] = deepcopy(x) end
    return c
end
F.deepcopy = deepcopy

-- world: conta efeitos reais e "mata o processo" na operacao numero dieAt (append ou porta).
function F.world(dieAt)
    return { ops = 0, dieAt = dieAt, dead = false, removed = 0, paid = 0, returned = 0, log = {} }
end

local function tick(w)
    if w.dead then return false end
    w.ops = w.ops + 1
    if w.dieAt and w.ops >= w.dieAt then w.dead = true; return false end
    return true
end

function F.store(w, opts)
    opts = opts or {}
    local s = { recs = {}, appends = 0, failAt = opts.failAt, corrupt = opts.corrupt }
    function s:append(rec)
        self.appends = self.appends + 1
        if w and not tick(w) then return nil, 'process_dead' end
        if self.failAt and self.appends == self.failAt then return nil, 'io_error' end
        self.recs[#self.recs + 1] = deepcopy(rec)
        return true
    end
    function s:load()
        if self.corrupt then return nil, 'corrupt' end
        return deepcopy(self.recs)
    end
    return s
end

-- opts: removeResult / payResult / returnResult = true | false | 'throw'
function F.ports(w, opts)
    opts = opts or {}
    local function mk(name, effect, result)
        return function(tx)
            if not tick(w) then error('CRASH') end
            if result == 'throw' then error('boom ' .. name) end
            if result == false then return false end
            w[effect] = w[effect] + 1
            w.log[#w.log + 1] = name
            return true
        end
    end
    return {
        remove_item = mk('remove_item', 'removed', opts.removeResult),
        pay = mk('pay', 'paid', opts.payResult),
        return_item = mk('return_item', 'returned', opts.returnResult),
    }
end

function F.tx(over)
    local t = { key = 'sess1:conf1', identifier = 'license:aaa', item = 'streetdeal_package',
        qty = 2, unitPrice = 1900, total = 3800, payKind = 'item_dirty_cash' }
    for k, v in pairs(over or {}) do t[k] = v end
    return t
end

return F
