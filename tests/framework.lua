-- Mini framework de testes (sem dependencias). Roda em qualquer Lua 5.4.
local T = { passed = 0, failed = 0, failures = {}, current = nil }

function T.test(name, fn)
    T.current = name
    local ok, err = pcall(fn)
    if ok then
        T.passed = T.passed + 1
    else
        T.failed = T.failed + 1
        T.failures[#T.failures + 1] = name .. '\n      ' .. tostring(err)
    end
end

local function fmt(v) return type(v) == 'string' and ('%q'):format(v) or tostring(v) end

function T.eq(actual, expected, msg)
    if actual ~= expected then
        error(('%s: esperado %s, obtido %s'):format(msg or 'eq', fmt(expected), fmt(actual)), 2)
    end
end

function T.near(actual, expected, eps, msg)
    if type(actual) ~= 'number' or math.abs(actual - expected) > eps then
        error(('%s: esperado %s +-%s, obtido %s'):format(msg or 'near', expected, eps, tostring(actual)), 2)
    end
end

function T.truthy(v, msg) if not v then error(msg or 'esperado verdadeiro', 2) end end
function T.falsy(v, msg) if v then error(msg or 'esperado falso/nil', 2) end end

-- Espera (nil, codigo) de funcoes que usam a convencao de erro do projeto.
function T.err(code, v, e, msg)
    if v ~= nil or e ~= code then
        error(('%s: esperado erro %q, obtido valor=%s erro=%s'):format(msg or 'err', code, tostring(v), tostring(e)), 2)
    end
end

function T.raises(fn, msg)
    local ok = pcall(fn)
    if ok then error(msg or 'esperado erro (assert)', 2) end
end

return T
