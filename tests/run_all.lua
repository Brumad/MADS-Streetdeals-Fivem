-- Uso (raiz do projeto): python3 tools/run_lua_tests.py   |   lua5.4 tests/run_all.lua
package.path = './?.lua;' .. package.path
local T = require 'tests.framework'

local suites = {
    'tests.test_economy', 'tests.test_probability', 'tests.test_negotiation',
    'tests.test_profiles', 'tests.test_roll_guard', 'tests.test_ledger', 'tests.test_engine', 'tests.test_ai', 'tests.test_misc',
}
for _, s in ipairs(suites) do require(s) end

print(('\nLua %s | %d passou, %d falhou'):format(_VERSION, T.passed, T.failed))
for _, f in ipairs(T.failures) do print('  FALHA: ' .. f) end
if arg then os.exit(T.failed == 0 and 0 or 1) end
return T.failed
