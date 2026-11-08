# Configuração (`config/config.lua`)

Todos os valores são **defaults editáveis**; fixados pelo contrato: preço-base $2.000/pacote (5 unidades),
tabela policial, `rare.denominator = 1000`. Probabilidades comuns são propostas (R04.7).

| Bloco | Chaves principais | Efeito |
|---|---|---|
| `economy` | `basePackagePrice`, `policeAnchors`, `scroll{minPct,maxPct,stepPct}`, `maxPackages`, `offerRoundTo` | preço, interpolação (1=0,625x…), faixa do scroll (±50%, passo 5%) |
| `rare` | `denominator`, `referencePrice`, `applyPoliceMultiplier`, `prizeMultiplier` | Plus rara 1/1000; prêmio 5x–10x da referência; multiplicador policial opcional |
| `approachWeights` | pesos dos 5 resultados comuns | frequência base (combo ≈ 8%) |
| `zones` / `areas` | multiplicadores por zona; círculos no mapa (**coordenadas de exemplo**) | denúncia/briga/combo por local |
| `archetypes`, `archetypeSpawnWeights`, `modelArchetypeHints` | faixas de atributos, `fightMult` | perfis e confronto; novos arquétipos sem tocar no motor |
| `negotiation` | `acceptSlope`, custos de paciência, `intentMood` | sensibilidade a preço/humor/insistência |
| `guard` | `playerCooldownSec`, `pedCooldownSec` | anti-repetição (chave = citizenid) |
| `goods` | `mode = package|units`, `item`, `unitItem`, `priceMult` | pacote como item próprio **ou** 5 unidades — nunca os dois |
| `payment` | `kind = cash|bank|item`, `moneyItem` | destino do pagamento |
| `police.jobType` | tipo do job policial | contagem em serviço |
| `validation` | distâncias, `allowUnverifiedLocalPeds`, `populationTypes`, `blockedModels` | validação server-side |
| `session` | TTL, turnos, ritmo, briga | limites de sessão |
| `dispatch` | `mode = none|export|event` | ver INTEGRACAO_QBOX.md |
| `ai` | provedor, modelo, timeout, limites/min, orçamento diário, circuit breaker | ver IA_E_SEGURANCA.md |
| `anim`, `interaction` | pares `{dict, nome}`; modo target/key/both | animações (nomes a homologar) |

Convars: `mads_sd_ai_key` (segredo, só servidor), `mads_sd_loglevel` (`debug|info|warn|error`).
