local M = {}

function M.clamp(x, lo, hi)
    if x < lo then return lo elseif x > hi then return hi end
    return x
end

function M.range(rng, r) return r[1] + rng.float() * (r[2] - r[1]) end

-- Sorteio ponderado deterministico (chaves ordenadas): UMA chamada a rng.float().
function M.weighted_pick(rng, weights)
    local keys, total = {}, 0
    for k, w in pairs(weights) do
        if w > 0 then keys[#keys + 1] = k; total = total + w end
    end
    if total <= 0 then return nil end
    table.sort(keys)
    local x = rng.float() * total
    local acc = 0
    for _, k in ipairs(keys) do
        acc = acc + weights[k]
        if x < acc then return k end
    end
    return keys[#keys]
end

function M.shallow_copy(t)
    local c = {}
    for k, v in pairs(t) do c[k] = v end
    return c
end

-- Mescla `over` sobre `base` (tabelas aninhadas); listas sao substituidas por inteiro.
function M.deep_merge(base, over)
    for k, v in pairs(over) do
        if type(v) == 'table' and type(base[k]) == 'table' and #v == 0 and next(v) ~= nil then
            M.deep_merge(base[k], v)
        else
            base[k] = v
        end
    end
    return base
end

return M
