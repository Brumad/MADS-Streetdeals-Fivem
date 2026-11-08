-- MADS StreetDeals - configuracao de gameplay (compartilhada, SEM segredos).
-- Segredos (chave de IA) NUNCA ficam aqui: use convars no server.cfg (ver IA_E_SEGURANCA.md).
-- Todos os valores abaixo sao DEFAULTS editaveis; apenas rare.denominator = 1000 e a tabela
-- policial/preco-base sao fixados pelo contrato (REQUISITOS.md R03/R04).
return {
    economy = {
        basePackagePrice = 2000, -- R03.1: USD por pacote
        unitsPerPackage = 5,     -- R03.1: um pacote = 5 unidades
        roundTo = 1,             -- arredondamento do preco de referencia por pacote
        offerRoundTo = 10,       -- arredondamento da oferta (scroll)
        maxUnitPrice = 1000000,  -- teto de sanidade (anti-overflow / anti-adulteracao)
        maxPackages = 4,         -- R04.5: combo 1..4
        -- R03.2: pontos ancora {policiais_em_servico, multiplicador}; intermediarios sao interpolados
        -- linearmente (1=0.625, 2=0.75, 3=0.875, 5=1.25, 7=1.75). >= ultimo ponto fica no ultimo.
        policeAnchors = { { 0, 0.5 }, { 4, 1.0 }, { 6, 1.5 }, { 8, 2.0 } },
        -- R03.5: o cliente envia apenas o PASSO do scroll (inteiro); o servidor calcula o preco.
        scroll = { minPct = 50, maxPct = 150, stepPct = 5 },
    },

    rare = {
        denominator = 1000,           -- R04.4: exatamente 1/1000 por abordagem elegivel
        referencePrice = 2000,        -- referencia especial (README: padrao proposto)
        applyPoliceMultiplier = false,-- decisao de balanceamento proposta: nao reaplicar
        prizeMultiplier = { min = 5, max = 10 },
        roundTo = 10,
    },

    -- Pesos dos resultados comuns (R04.7: configuraveis, NAO fixados pelo usuario).
    -- Default justificado: a maioria das abordagens vira conversa; combo ~8% (>> 0,1% do raro).
    approachWeights = {
        negotiate_simple = 45,
        refuse_simple = 28,
        refuse_report = 9,
        plus_combo = 8,
        fight = 10,
    },

    -- Modificadores de ambiente (R02.5) aplicados sobre os pesos acima.
    zones = {
        default      = { report = 1.0, fight = 1.0, combo = 1.0, negotiate = 1.0 },
        busy         = { report = 1.3, fight = 0.8, combo = 1.1, negotiate = 1.0 }, -- testemunhas
        residential  = { report = 1.1, fight = 0.9, combo = 0.9, negotiate = 1.0 },
        isolated     = { report = 0.7, fight = 1.3, combo = 1.0, negotiate = 1.0 },
        police_risk  = { report = 1.6, fight = 1.0, combo = 0.8, negotiate = 0.9 },
        near_station = { report = 2.0, fight = 0.9, combo = 0.6, negotiate = 0.8 },
    },

    -- Arquetipos (R02.3). Faixas sorteadas por NPC => mesma skin pode gerar comportamentos distintos.
    archetypes = {
        comum = {
            aggression = { 0.15, 0.5 }, patience = { 0.4, 0.8 }, interest = { 0.3, 0.7 },
            priceTolerance = { 0.9, 1.15 }, reportProneness = { 0.2, 0.5 }, budget = { 800, 6000 },
            mood = { 40, 60 }, fightMult = 1.0,
        },
        empresario = {
            aggression = { 0.05, 0.3 }, patience = { 0.3, 0.6 }, interest = { 0.2, 0.6 },
            priceTolerance = { 1.1, 1.4 }, reportProneness = { 0.3, 0.7 }, budget = { 4000, 20000 },
            mood = { 45, 65 }, fightMult = 0.6,
        },
        atleta = {
            aggression = { 0.5, 0.9 }, patience = { 0.3, 0.7 }, interest = { 0.2, 0.6 },
            priceTolerance = { 0.85, 1.1 }, reportProneness = { 0.25, 0.55 }, budget = { 1000, 5000 },
            mood = { 35, 65 }, fightMult = 2.0, -- R02.3: modificador de confronto aumentado
        },
        morador_de_rua = {
            aggression = { 0.4, 0.9 }, patience = { 0.2, 0.6 }, interest = { 0.4, 0.9 },
            priceTolerance = { 0.5, 0.8 }, reportProneness = { 0.05, 0.25 }, budget = { 100, 2200 },
            mood = { 25, 55 }, fightMult = 1.8, -- R02.3
        },
    },
    hintStrength = 0.8, -- chance de a dica do modelo definir o arquetipo (mesma skin pode divergir)
    -- Peso do arquetipo quando o modelo do ped nao tem dica (por zona; default usado se ausente).
    archetypeSpawnWeights = {
        default = { comum = 70, empresario = 10, atleta = 10, morador_de_rua = 10 },
        busy = { comum = 60, empresario = 20, atleta = 10, morador_de_rua = 10 },
        isolated = { comum = 50, empresario = 2, atleta = 13, morador_de_rua = 35 },
    },
    -- Dicas por modelo de ped (SO dicas; nomes de modelo GTA V a homologar in-game, ver REFERENCIAS_TECNICAS.md).
    modelArchetypeHints = {
        a_m_m_tramp_01 = 'morador_de_rua', a_m_o_tramp_01 = 'morador_de_rua', a_f_m_tramp_01 = 'morador_de_rua',
        a_m_y_business_01 = 'empresario', a_m_y_business_02 = 'empresario', a_m_y_business_03 = 'empresario',
        a_m_m_business_01 = 'empresario', a_f_y_business_01 = 'empresario', a_f_y_business_02 = 'empresario',
        a_m_y_runner_01 = 'atleta', a_m_y_runner_02 = 'atleta', a_f_y_runner_01 = 'atleta',
        a_m_y_musclbeac_01 = 'atleta', a_m_y_musclbeac_02 = 'atleta', a_f_y_fitness_01 = 'atleta',
    },

    -- Humor/paciencia (0..100 humor; paciencia 0..1).
    negotiation = {
        acceptSlope = 6.0,        -- sensibilidade da aceitacao a (tolerancia - razao da oferta)
        interestWeight = 1.6,
        moodWeight = 1.2,
        reportBase = 0.6, reportSlope = 2.0, reportFloor = 0.1,
        patienceCostBase = 0.12, patienceCostPerInsist = 0.06, patienceCostOverpriced = 0.10,
        fightBase = 0.5,
        moodDeltaAccept = 8, moodDeltaCounter = -3, moodDeltaRefuse = -10,
        moodDeltaGoodOffer = 4, moodDeltaBadOffer = -6,
        -- efeito de mensagens livres (so humor/paciencia; nunca preco/aceite)
        intentMood = {
            polite = { mood = 3 }, premium = { mood = 2 }, provoke = { mood = -10, patience = -0.1 },
            threat = { mood = -18, patience = -0.2 }, discount = { mood = -1, patience = -0.04, insist = 1 },
            bye = { mood = 0 }, chat = { mood = 0 },
        },
    },

    -- Controle de repeticao / abuso (R04.4, R08.3). Chave = identificador PERSISTENTE (nao o source).
    guard = {
        playerCooldownSec = 20,   -- minimo entre abordagens do mesmo jogador
        pedCooldownSec = 600,     -- mesmo ped nao gera nova oportunidade durante a janela
        approachTtlSec = 300,     -- abordagem sem conclusao expira (sem vazamento de memoria)
        maxEntries = 5000,        -- teto de memoria
    },

    -- Mercadorias (R03.7). mode='package': consome `item` (1 por pacote). mode='units': consome
    -- unitsPerPackage x `unitItem` por pacote. NUNCA os dois ao mesmo tempo.
    goods = {
        { key = 'pacote_rua', label = 'Pacote StreetDeals', mode = 'package', item = 'streetdeal_pacote',
          unitItem = 'streetdeal_unidade', priceMult = 1.0 },
    },
    -- Destino do pagamento (R: configuravel). kind: 'cash' | 'bank' (qbx_core Player.Functions.AddMoney)
    -- ou 'item' (ex.: item de dinheiro sujo do servidor, via ox_inventory:AddItem).
    payment = { kind = 'cash', moneyItem = 'black_money', reason = 'mads_streetdeals' },

    police = { jobType = 'leo' }, -- confirmar o `type` do job policial na instalacao (qbx_core shared/jobs.lua)

    -- Validacao de entidade/jogador no servidor (R08.1).
    validation = {
        maxApproachDistance = 4.0,  -- jogador <-> ped (quando o ped e entidade de rede)
        maxMoveFromStart = 12.0,    -- jogador nao pode se afastar mais que isso durante a sessao
        allowUnverifiedLocalPeds = true, -- ped local (sem netId valido): modo degradado (ver IA_E_SEGURANCA.md)
        populationTypes = nil,      -- ex.: { 1, 2, 3, 4 } so apos homologar GetEntityPopulationType in-game
        blockedModels = {},         -- nomes de modelo (ex.: policiais/seguranca) nunca elegiveis
    },

    session = {
        ttlSec = 180, dealTtlSec = 45, maxTurns = 24, minActionIntervalMs = 250, maxTextChars = 200,
        maxPerPlayerBurst = 6, -- acoes por janela de 5 s
        fightSeconds = 25, chaseChance = 0.35,
    },

    interaction = { mode = 'both', targetDistance = 2.5, key = 'G', keyDistance = 2.5, -- target|key|both
        allowedPedTypes = { 4, 5 } }, -- GetPedType: 4 CIVMALE, 5 CIVFEMALE (exclui policia, gangues, animais)

    dispatch = {
        -- mode: 'none' | 'export' | 'event' | 'command'. Preencha conforme o dispatch REAL instalado.
        mode = 'none', resource = '', export = '', event = '', command = '',
        code = '10-66', message = 'Tentativa suspeita de venda de entorpecentes', cooldownSec = 60,
    },

    ai = {
        enabled = true,             -- so efetiva se houver chave/endpoint; senao usa fallback local
        provider = 'anthropic',     -- 'anthropic' | 'openai' (compativel chat completions)
        endpoint = '',              -- vazio = padrao do provedor
        model = 'claude-haiku-5-5',
        timeoutMs = 6000, maxOutputTokens = 160, maxInputChars = 400, maxReplyChars = 260,
        perPlayerPerMin = 8, globalPerMin = 60, dailyRequests = 5000,
        breakerFailures = 4, breakerCooldownSec = 60,
        phraseOffers = true,        -- usar IA tambem para frasear respostas a ofertas (consome mais)
    },

    anim = {
        hello = { 'gestures@m@standing@casual', 'gesture_hello' },
        refuse = { 'gestures@m@standing@casual', 'gesture_no_way' },
        trade = { 'mp_common', 'givetake1_a' },
        tradeNpc = { 'mp_common', 'givetake1_b' },
    },

    -- Areas (R02.5): primeira correspondencia mais proxima define a zona. COORDENADAS DE EXEMPLO
    -- aproximadas: ajuste ao seu mapa. zones validas: busy|residential|isolated|police_risk|near_station.
    areas = {
        { zone = 'near_station', x = 425.1, y = -979.5, z = 30.7, r = 120.0 },   -- Mission Row
        { zone = 'near_station', x = -1108.0, y = -847.0, z = 19.3, r = 100.0 }, -- Vespucci
        { zone = 'near_station', x = 362.0, y = -1564.0, z = 29.3, r = 100.0 },  -- Davis
        { zone = 'near_station', x = 1855.0, y = 3683.0, z = 34.3, r = 100.0 },  -- Sandy Shores
        { zone = 'near_station', x = -447.0, y = 6012.0, z = 31.7, r = 100.0 },  -- Paleto
        { zone = 'busy', x = 195.0, y = -934.0, z = 30.7, r = 150.0 },           -- Legion Square
        { zone = 'busy', x = -1850.0, y = -1230.0, z = 13.0, r = 150.0 },        -- Del Perro Pier
        { zone = 'residential', x = 100.0, y = -1900.0, z = 21.0, r = 250.0 },   -- Davis/Strawberry
        { zone = 'isolated', x = 2500.0, y = 4800.0, z = 35.0, r = 600.0 },      -- Grapeseed (rural)
    },
    pedNames = {}, -- opcional: nomes de modelo extras que o servidor deve reconhecer (alem de modelArchetypeHints)
}
