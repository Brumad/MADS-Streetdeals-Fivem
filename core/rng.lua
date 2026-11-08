-- Fonte de aleatoriedade injetavel. Producao: rng.system() (math.random, semeado pelo Lua 5.4
-- no inicio do VM). Testes: rng.seeded(seed) (splitmix64 deterministico) e rng.scripted().
local M = {}

function M.system()
    return {
        int = function(lo, hi) return math.random(lo, hi) end,
        float = function() return math.random() end,
    }
end

-- splitmix64: deterministico, uniforme; usa aritmetica inteira de 64 bits do Lua 5.4.
function M.seeded(seed)
    local state = math.tointeger(seed) or 0
    local function next64()
        state = state + 0x9E3779B97F4A7C15
        local z = state
        z = (z ~ (z >> 30)) * 0xBF58476D1CE4E5B9
        z = (z ~ (z >> 27)) * 0x94D049BB133111EB
        return z ~ (z >> 31)
    end
    return {
        int = function(lo, hi)
            local span = hi - lo + 1
            local limit = (0x7FFFFFFFFFFFFFFF // span) * span
            local v = next64() >> 1
            while v >= limit do v = next64() >> 1 end -- rejeicao: sem vies de modulo
            return lo + (v % span)
        end,
        float = function() return (next64() >> 11) * (1.0 / 9007199254740992.0) end,
    }
end

-- Sequencias fixas para testes de fronteira. Falha alto se a sequencia acabar.
function M.scripted(ints, floats)
    local ii, fi = 0, 0
    return {
        int = function(lo, hi)
            ii = ii + 1
            local v = ints and ints[ii]
            assert(v ~= nil, 'rng.scripted: sequencia de ints esgotada')
            assert(v >= lo and v <= hi, ('rng.scripted: %s fora de [%s,%s]'):format(v, lo, hi))
            return v
        end,
        float = function()
            fi = fi + 1
            local v = floats and floats[fi]
            assert(v ~= nil, 'rng.scripted: sequencia de floats esgotada')
            return v
        end,
        calls = function() return ii, fi end,
    }
end

return M
