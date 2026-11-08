package.path = './?.lua;' .. package.path
local T = require 'tests.framework'
local guardmod = require 'core.roll_guard'

local function mk(over)
    local now = { t = 1000 }
    local o = { clock = function() return now.t end, playerCooldownSec = 20, pedCooldownSec = 600,
        approachTtlSec = 300, maxEntries = 50 }
    for k, v in pairs(over or {}) do o[k] = v end
    return guardmod.new(o), now
end

T.test('um unico sorteio por abordagem; repeticao (reabrir NUI) e bloqueada', function()
    local g = mk()
    local id = g:begin_approach('license:aaa', 'ped:1')
    T.truthy(id)
    T.truthy(g:consume_roll(id, 'license:aaa'))
    T.err('already_rolled', g:consume_roll(id, 'license:aaa'))
    T.err('already_rolled', g:consume_roll(id, 'license:aaa'))
end)

T.test('nova abordagem imediata e barrada por cooldown do jogador', function()
    local g, now = mk()
    T.truthy(g:begin_approach('license:aaa', 'ped:1'))
    T.err('player_cooldown', g:begin_approach('license:aaa', 'ped:2'))
    now.t = now.t + 21
    T.truthy(g:begin_approach('license:aaa', 'ped:2'))
end)

T.test('mesmo ped nao gera nova oportunidade (de outro jogador) durante a janela', function()
    local g, now = mk()
    T.truthy(g:begin_approach('license:aaa', 'ped:1'))
    T.err('ped_cooldown', g:begin_approach('license:bbb', 'ped:1'))
    now.t = now.t + 601
    T.truthy(g:begin_approach('license:bbb', 'ped:1'))
end)

T.test('reconexao nao burla cooldown: chave e o identificador persistente, nao o source', function()
    local g = mk()
    T.truthy(g:begin_approach('license:aaa', 'ped:1')) -- "source 5"
    -- jogador cai e reconecta com outro source: mesmo license -> continua em cooldown
    T.err('player_cooldown', g:begin_approach('license:aaa', 'ped:9'))
end)

T.test('so o dono consome o sorteio; abordagem inexistente/expirada falha', function()
    local g, now = mk()
    local id = g:begin_approach('license:aaa', 'ped:1')
    T.err('not_owner', g:consume_roll(id, 'license:bbb'))
    T.err('unknown_or_expired', g:consume_roll(9999, 'license:aaa'))
    now.t = now.t + 301
    T.err('unknown_or_expired', g:consume_roll(id, 'license:aaa'))
end)

T.test('finish remove a abordagem e id nao pode ser reaproveitado', function()
    local g = mk()
    local id = g:begin_approach('license:aaa', 'ped:1')
    g:finish(id)
    T.err('unknown_or_expired', g:consume_roll(id, 'license:aaa'))
end)

T.test('entradas invalidas rejeitadas', function()
    local g = mk()
    T.err('bad_identifier', g:begin_approach(nil, 'p'))
    T.err('bad_identifier', g:begin_approach('', 'p'))
    T.err('bad_ped', g:begin_approach('license:a', nil))
    T.err('bad_ped', g:begin_approach('license:a', 42))
end)

T.test('sem vazamento: sweep remove expirados e o teto de memoria falha seguro', function()
    local g, now = mk({ maxEntries = 30 })
    local accepted = 0
    for i = 1, 100 do
        local id = g:begin_approach('license:' .. i, 'ped:' .. i)
        if id then accepted = accepted + 1 end
    end
    T.truthy(accepted < 100, 'guard recusa ao encher')
    T.truthy(g.count <= 30, 'contagem respeita o teto: ' .. g.count)
    now.t = now.t + 10000
    g:sweep()
    T.eq(g.count, 0, 'tudo expirou e foi liberado')
    T.truthy(g:begin_approach('license:novo', 'ped:novo'), 'volta a aceitar apos a varredura')
end)

T.test('contabilidade de entradas permanece consistente em ciclo longo', function()
    local g, now = mk({ maxEntries = 100 })
    for i = 1, 2000 do
        now.t = now.t + 7
        local id = g:begin_approach('license:' .. (i % 13), 'ped:' .. i)
        if id then g:consume_roll(id, 'license:' .. (i % 13)); g:finish(id) end
    end
    g:sweep()
    local real = 0
    for _ in pairs(g.players) do real = real + 1 end
    for _ in pairs(g.peds) do real = real + 1 end
    for _ in pairs(g.approaches) do real = real + 1 end
    T.eq(g.count, real, 'contador == entradas reais')
    T.truthy(real <= 100)
end)
