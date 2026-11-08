-- Motor economico AUTORITATIVO (puro, sem natives). Nunca recebe dinheiro do cliente:
-- o cliente envia apenas passo de scroll e quantidade; todo valor e recalculado aqui.
-- Convencao de erro: retorna (valor) ou (nil, 'codigo_do_erro').
local M = {}

local function round_to(x, step)
    step = step or 1
    return math.floor(x / step + 0.5) * step
end
M.round_to = round_to

-- Aceita inteiros e floats integrais (msgpack/JSON podem entregar 3.0). Rejeita NaN/inf/fracao/string.
local function as_int(v)
    if type(v) ~= 'number' then return nil end
    return math.tointeger(v)
end
M.as_int = as_int

function M.validate_config(cfg)
    local e = cfg and cfg.economy
    if not e then return nil, 'economy_missing' end
    if not (type(e.basePackagePrice) == 'number' and e.basePackagePrice > 0) then return nil, 'bad_base_price' end
    if not (as_int(e.maxPackages) and e.maxPackages >= 1) then return nil, 'bad_max_packages' end
    if type(e.policeAnchors) ~= 'table' or #e.policeAnchors < 2 then return nil, 'bad_anchors' end
    local prev
    for _, a in ipairs(e.policeAnchors) do
        if not (as_int(a[1]) and a[1] >= 0 and type(a[2]) == 'number' and a[2] > 0) then return nil, 'bad_anchor' end
        if prev and a[1] <= prev then return nil, 'anchors_not_sorted' end
        prev = a[1]
    end
    local s = e.scroll
    if not (s and s.minPct > 0 and s.maxPct >= s.minPct and s.stepPct > 0) then return nil, 'bad_scroll' end
    local r = cfg.rare
    if not (r and as_int(r.denominator) and r.denominator >= 1) then return nil, 'bad_rare_denominator' end
    if not (r.prizeMultiplier and r.prizeMultiplier.min > 0 and r.prizeMultiplier.max >= r.prizeMultiplier.min) then
        return nil, 'bad_rare_multiplier'
    end
    return true
end

-- R03.2/R03.3: multiplicador por policiais EM SERVICO, interpolacao linear entre ancoras.
function M.police_multiplier(cfg, count)
    local n = as_int(count)
    if not n or n < 0 then return nil, 'bad_police_count' end
    local a = cfg.economy.policeAnchors
    if n <= a[1][1] then return a[1][2] end
    local last = a[#a]
    if n >= last[1] then return last[2] end
    for i = 1, #a - 1 do
        local lo, hi = a[i], a[i + 1]
        if n >= lo[1] and n <= hi[1] then
            local t = (n - lo[1]) / (hi[1] - lo[1])
            return lo[2] + (hi[2] - lo[2]) * t
        end
    end
    return last[2] -- inalcancavel (ancoras ordenadas); defensivo
end

-- Preco de referencia POR PACOTE para o numero de policiais em servico.
function M.package_price(cfg, policeCount)
    local m, err = M.police_multiplier(cfg, policeCount)
    if not m then return nil, err end
    return round_to(cfg.economy.basePackagePrice * m, cfg.economy.roundTo)
end

-- Limites do scroll em passos inteiros: ratio = 1 + passo * stepPct/100.
function M.scroll_bounds(cfg)
    local s = cfg.economy.scroll
    local lo = math.ceil((s.minPct - 100) / s.stepPct - 1e-9)
    local hi = math.floor((s.maxPct - 100) / s.stepPct + 1e-9)
    return lo, hi
end

function M.ratio_from_step(cfg, step)
    local n = as_int(step)
    if not n then return nil, 'bad_step' end
    local lo, hi = M.scroll_bounds(cfg)
    if n < lo or n > hi then return nil, 'step_out_of_range' end
    return 1 + n * cfg.economy.scroll.stepPct / 100
end

-- Preco unitario (por pacote) ofertado pelo passo de scroll, sobre a referencia da SESSAO.
function M.offer_unit_price(cfg, refPrice, step)
    if not (type(refPrice) == 'number' and refPrice > 0) then return nil, 'bad_reference' end
    local ratio, err = M.ratio_from_step(cfg, step)
    if not ratio then return nil, err end
    local price = round_to(refPrice * ratio, cfg.economy.offerRoundTo)
    if price < 1 then price = 1 end
    if price > cfg.economy.maxUnitPrice then return nil, 'price_too_high' end
    return price
end

-- R04.5: total do combo; unitario negociado x quantidade (1..maxPackages). So inteiros.
function M.combo_total(cfg, unitPrice, qty)
    local q, u = as_int(qty), as_int(unitPrice)
    if not q or q < 1 or q > cfg.economy.maxPackages then return nil, 'bad_quantity' end
    if not u or u < 1 or u > cfg.economy.maxUnitPrice then return nil, 'bad_unit_price' end
    return u * q
end

-- R04.4: premio da Plus rara = referencia especial x U[min,max]; por padrao sem multiplicador policial.
function M.rare_prize(cfg, policeCount, rng)
    local r = cfg.rare
    local ref = r.referencePrice
    if r.applyPoliceMultiplier then
        local m, err = M.police_multiplier(cfg, policeCount)
        if not m then return nil, err end
        ref = ref * m
    end
    local mult = r.prizeMultiplier.min + rng.float() * (r.prizeMultiplier.max - r.prizeMultiplier.min)
    local lo, hi = ref * r.prizeMultiplier.min, ref * r.prizeMultiplier.max
    local prize = round_to(ref * mult, r.roundTo)
    if prize < lo then prize = lo elseif prize > hi then prize = hi end
    return math.floor(prize + 0.5)
end

return M
