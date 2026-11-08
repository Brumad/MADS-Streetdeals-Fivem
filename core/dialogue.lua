-- Dialogo LOCAL contextual (fallback quando a IA nao esta disponivel) e classificador de intencao.
-- Texto livre so produz uma INTENCAO da whitelist; nunca preco, estoque ou aceite (R05.7).
local M = {}

M.INTENTS = { 'chat', 'polite', 'provoke', 'threat', 'discount', 'premium', 'bye' }
local INTENT_SET = {}
for _, i in ipairs(M.INTENTS) do INTENT_SET[i] = true end
function M.valid_intent(i) return INTENT_SET[i] == true end

function M.mood_label(mood)
    if mood < 20 then return 'furioso' elseif mood < 40 then return 'irritado'
    elseif mood < 60 then return 'neutro' elseif mood < 80 then return 'receptivo' end
    return 'animado'
end

local accents = { ['á']='a',['à']='a',['â']='a',['ã']='a',['ä']='a',['é']='e',['ê']='e',['è']='e',['í']='i',['î']='i',
    ['ó']='o',['ô']='o',['õ']='o',['ò']='o',['ú']='u',['ü']='u',['û']='u',['ç']='c' }
local function norm(s)
    s = s:lower()
    s = s:gsub('[\xC3][\x80-\xBF]', function(c) return accents[c] or c end)
    return s
end
M.normalize = norm

local function has(t, list)
    for _, w in ipairs(list) do if t:find(w, 1, true) then return true end end
    return false
end

-- Heuristica local (a IA pode sugerir outra intencao, validada contra a whitelist).
function M.parse_intent(text)
    local t = norm(text or '')
    if has(t, { 'te mato', 'vou te bater', 'arrebento', 'te quebro', 'passa tudo', 'perdeu' }) then return 'threat' end
    if has(t, { 'otario', 'idiota', 'burro', 'imbecil', 'trouxa', 'cala a boca', 'vai se f', 'lixo', 'pobre' }) then return 'provoke' end
    if has(t, { 'tchau', 'deixa pra la', 'esquece', 'to indo', 'falou', 'vou nessa' }) then return 'bye' end
    if has(t, { 'desconto', 'mais barato', 'abaixa', 'baixa o preco', 'faz por menos', 'pague menos' }) then return 'discount' end
    if has(t, { 'qualidade', 'puro', 'o melhor', 'da boa', 'top de linha' }) then return 'premium' end
    if has(t, { 'por favor', 'obrigad', 'valeu', 'bom dia', 'boa tarde', 'boa noite', 'e ai', 'opa', ' oi', 'ola' }) or t:find('^oi') then
        return 'polite'
    end
    return 'chat'
end

local L = {
    greet = {
        comum = { 'E aí. Pode falar, o que você tem?', 'Opa... fala baixo. O que é?' },
        empresario = { 'Estou com pressa. Seja direto.', 'Tenho pouco tempo. Qual é a proposta?' },
        atleta = { 'Fala, parceiro. Tô treinando, mas pode falar.', 'E aí, mano. Que papo é esse?' },
        morador_de_rua = { 'Ei, irmão... tem algo pra mim?', 'Opa, chefe... fala aí.' },
    },
    combo = {
        comum = { 'Se o preço for bom, levo mais de um.', 'Tô precisando de uns {max}... depende do valor.' },
        empresario = { 'Posso levar até {max} para a equipe. Mostre o valor.', 'Compro em quantidade se for justo.' },
        atleta = { 'Se rolar bom preço, levo uns {max} pro pessoal.', 'Fechando bem, levo mais de um.' },
        morador_de_rua = { 'Se for barato levo mais, mas é pouco dinheiro...', 'Quanto sai? Posso juntar pra levar mais.' },
    },
    rare = {
        _ = { 'Escuta, eu pago MUITO bem por isso. Preço fechado: ${price}. Topa?',
            'Faz tempo que procuro isso. Pago ${price} agora, sem enrolar. Fechado?' },
    },
    accept = {
        _ = { 'Fechado! ${price} por pacote. Vamos fazer rápido.', 'Beleza, pode ser ${price}. Passa aí.', 'Tá combinado: ${price}.' },
    },
    counter = {
        _ = { 'Tá caro. Faço por ${price}.', 'Assim não dá... ${price} e a gente fecha.', 'Que tal ${price}? É o que eu pago.' },
    },
    hesitate = {
        _ = { 'Hmm... não sei não. Tô meio desconfiado.', 'Deixa eu pensar... não me convenceu ainda.', 'Sei lá, mano. Convence aí.' },
    },
    cannot_afford = {
        _ = { 'Não tenho dinheiro pra tudo isso. No máximo {max}.', 'Tô sem grana pra essa quantidade. Só consigo {max}.' },
    },
    refuse = {
        _ = { 'Não tô interessado. Some daqui.', 'Passo. Procura outro.', 'Cansei dessa conversa. Tchau.' },
    },
    refuse_report = {
        _ = { 'Você tá doido? Vou chamar a polícia!', 'Isso é crime! Vou denunciar!' },
    },
    fight = {
        _ = { 'Você tá me tirando?! Vem pra cima!', 'Já deu! Vou te ensinar respeito!' },
    },
    no_stock = { _ = { 'Você nem tem nada pra vender...' } },
    walk_away = { _ = { 'Cansei. Fui.', 'Perdi a paciência. Tchau.' } },
    chat = {
        _ = { 'Hmm, tá. E aí, qual o preço?', 'Entendi. Mostra a proposta.', 'Continua... tô ouvindo.' },
        irritado = { 'Fala logo o que quer.', 'Tô sem paciência hoje.' },
        furioso = { 'Não me irrita.', 'Cuidado com o que fala.' },
        animado = { 'Gostei da conversa! Vamos ver esse preço.', 'Tô de bom humor, manda a proposta.' },
    },
    polite = { _ = { 'Boa! Educado você. Vamos ver o negócio.', 'Valeu a educação. Qual é a proposta?' } },
    provoke = { _ = { 'Olha o respeito, hein!', 'Fala assim comigo de novo e vai ver.' } },
    threat = { _ = { 'Tá me ameaçando?! Péssima ideia.', 'Ameaça não funciona comigo.' } },
    discount = { _ = { 'Desconto? Só se a proposta for boa.', 'Mexe no preço aí que eu vejo.' } },
    premium = { _ = { 'Qualidade importa, mas o preço também.', 'Se for bom mesmo, a gente conversa.' } },
    bye = { _ = { 'Beleza, então. Falou.', 'Tá certo. Até.' } },
}

local function fill(s, v)
    return (s:gsub('%${price}', function() return v.price and ('$' .. tostring(v.price)) or '' end)
        :gsub('{max}', function() return tostring(v.max or '') end)
        :gsub('{price}', function() return tostring(v.price or '') end))
end

-- kind: chave de L; vars: { price=, max= }. UMA chamada a rng.int.
function M.line(rng, kind, archetype, moodLabel, vars)
    local group = L[kind] or L.chat
    local list = group[archetype] or group[moodLabel] or group._
    if not list or #list == 0 then list = L.chat._ end
    return fill(list[rng.int(1, #list)], vars or {})
end

M.LINES = L
return M
