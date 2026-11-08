package.path = './?.lua;' .. package.path
local T = require 'tests.framework'
local cfg = require 'config.config'
local economy = require 'core.economy'
local rngmod = require 'core.rng'

T.test('config padrao e valido', function()
    T.truthy(economy.validate_config(cfg))
end)

-- R03.2 / R03.3: os nove valores por pacote exatos
T.test('tabela policial: multiplicadores e valores exatos 0..8', function()
    local mult = { [0] = 0.5, 0.625, 0.75, 0.875, 1.0, 1.25, 1.5, 1.75, 2.0 }
    local price = { [0] = 1000, 1250, 1500, 1750, 2000, 2500, 3000, 3500, 4000 }
    for n = 0, 8 do
        T.near(economy.police_multiplier(cfg, n), mult[n], 1e-12, 'mult ' .. n)
        T.eq(economy.package_price(cfg, n), price[n], 'preco ' .. n)
    end
end)

T.test('8 ou mais policiais permanece em 2.0x / $4000', function()
    T.eq(economy.package_price(cfg, 8), 4000)
    T.eq(economy.package_price(cfg, 9), 4000)
    T.eq(economy.package_price(cfg, 200), 4000)
end)

T.test('contagem policial invalida e rejeitada', function()
    T.err('bad_police_count', economy.package_price(cfg, -1))
    T.err('bad_police_count', economy.package_price(cfg, 2.5))
    T.err('bad_police_count', economy.package_price(cfg, '4'))
    T.err('bad_police_count', economy.package_price(cfg, nil))
    T.err('bad_police_count', economy.package_price(cfg, 0 / 0))
    T.err('bad_police_count', economy.package_price(cfg, math.huge))
    T.eq(economy.package_price(cfg, 4.0), 2000, 'float integral aceito (msgpack)')
end)

T.test('preco e monotono nao decrescente com policiais', function()
    local prev = 0
    for n = 0, 12 do
        local p = economy.package_price(cfg, n)
        T.truthy(p >= prev, 'monotonia em ' .. n)
        prev = p
    end
end)

T.test('tabela e editavel sem reescrever o motor (A22)', function()
    local c = { economy = {
        basePackagePrice = 1000, maxPackages = 4, roundTo = 1, offerRoundTo = 1, maxUnitPrice = 1e6,
        policeAnchors = { { 0, 1.0 }, { 10, 3.0 } }, scroll = cfg.economy.scroll }, rare = cfg.rare }
    T.eq(economy.package_price(c, 5), 2000)
    T.eq(economy.package_price(c, 99), 3000)
end)

T.test('config invalida e detectada', function()
    local c = { economy = { basePackagePrice = -1 }, rare = cfg.rare }
    T.err('bad_base_price', economy.validate_config(c))
    local d = { economy = { basePackagePrice = 1, maxPackages = 4, policeAnchors = { { 4, 1 }, { 0, 2 } } }, rare = cfg.rare }
    T.err('anchors_not_sorted', economy.validate_config(d))
end)

T.test('scroll: limites e passos', function()
    local lo, hi = economy.scroll_bounds(cfg)
    T.eq(lo, -10); T.eq(hi, 10)
    T.near(economy.ratio_from_step(cfg, 0), 1.0, 1e-12)
    T.near(economy.ratio_from_step(cfg, -10), 0.5, 1e-12)
    T.near(economy.ratio_from_step(cfg, 10), 1.5, 1e-12)
end)

T.test('scroll: cliente nao consegue preco arbitrario/negativo/fora do limite', function()
    T.err('step_out_of_range', economy.ratio_from_step(cfg, 11))
    T.err('step_out_of_range', economy.ratio_from_step(cfg, -11))
    T.err('step_out_of_range', economy.ratio_from_step(cfg, 1e9))
    T.err('bad_step', economy.ratio_from_step(cfg, 1.5))
    T.err('bad_step', economy.ratio_from_step(cfg, '3'))
    T.err('bad_step', economy.ratio_from_step(cfg, nil))
    T.err('bad_step', economy.ratio_from_step(cfg, 0 / 0))
    T.err('bad_step', economy.ratio_from_step(cfg, {}))
end)

T.test('oferta unitaria calculada no servidor a partir da referencia da sessao', function()
    T.eq(economy.offer_unit_price(cfg, 2000, 0), 2000)
    T.eq(economy.offer_unit_price(cfg, 2000, -10), 1000)
    T.eq(economy.offer_unit_price(cfg, 2000, 10), 3000)
    T.eq(economy.offer_unit_price(cfg, 2000, -1), 1900)
    T.eq(economy.offer_unit_price(cfg, 1250, 1), 1310) -- 1312.5 -> multiplo de 10
    T.err('bad_reference', economy.offer_unit_price(cfg, 0, 0))
    T.err('bad_reference', economy.offer_unit_price(cfg, -5, 0))
    T.err('bad_reference', economy.offer_unit_price(cfg, 'x', 0))
end)

T.test('combo 1..4: totais corretos e quantidade fora da faixa rejeitada (A14)', function()
    for q = 1, 4 do T.eq(economy.combo_total(cfg, 1900, q), 1900 * q) end
    T.err('bad_quantity', economy.combo_total(cfg, 1900, 0))
    T.err('bad_quantity', economy.combo_total(cfg, 1900, 5))
    T.err('bad_quantity', economy.combo_total(cfg, 1900, -1))
    T.err('bad_quantity', economy.combo_total(cfg, 1900, 2.5))
    T.err('bad_quantity', economy.combo_total(cfg, 1900, '2'))
    T.err('bad_unit_price', economy.combo_total(cfg, 0, 2))
    T.err('bad_unit_price', economy.combo_total(cfg, -10, 2))
    T.err('bad_unit_price', economy.combo_total(cfg, 1.5, 2))
    T.err('bad_unit_price', economy.combo_total(cfg, 1e12, 2))
end)

T.test('premio raro: sempre em [5x,10x] da referencia, sem multiplicador policial por padrao', function()
    local rng = rngmod.seeded(7)
    local lo, hi, sum = math.huge, 0, 0
    local N = 20000
    for _ = 1, N do
        local p = economy.rare_prize(cfg, 0, rng) -- 0 policiais: nao deve alterar o premio
        lo = math.min(lo, p); hi = math.max(hi, p); sum = sum + p
        T.truthy(p >= 10000 and p <= 20000, 'premio fora da faixa: ' .. p)
    end
    T.truthy(lo < 10300 and hi > 19700, 'cobre a faixa inteira')
    T.near(sum / N, 15000, 150, 'media ~ ponto medio')
    T.eq(economy.rare_prize(cfg, 8, rngmod.scripted(nil, { 0.0 })), 10000, 'piso exato')
    T.eq(economy.rare_prize(cfg, 8, rngmod.scripted(nil, { 0.999999999 })), 20000, 'teto exato')
end)

T.test('premio raro: multiplicador policial configuravel', function()
    local c = { economy = cfg.economy, rare = { denominator = 1000, referencePrice = 2000,
        applyPoliceMultiplier = true, prizeMultiplier = { min = 5, max = 10 }, roundTo = 10 } }
    T.eq(economy.rare_prize(c, 8, rngmod.scripted(nil, { 0.0 })), 20000) -- 2000*2*5
    T.eq(economy.rare_prize(c, 0, rngmod.scripted(nil, { 0.0 })), 5000)  -- 2000*0.5*5
end)
