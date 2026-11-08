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
    },

    -- Controle de repeticao / abuso (R04.4, R08.3). Chave = identificador PERSISTENTE (nao o source).
    guard = {
        playerCooldownSec = 20,   -- minimo entre abordagens do mesmo jogador
        pedCooldownSec = 600,     -- mesmo ped nao gera nova oportunidade durante a janela
        approachTtlSec = 300,     -- abordagem sem conclusao expira (sem vazamento de memoria)
        maxEntries = 5000,        -- teto de memoria
    },
}
