# Arquitetura — mads_streetdeals (Qbox)

Principio: **nucleo puro e testavel** (`core/`, sem natives, sem Qbox) + **camadas finas de integracao**
(`server/`, `client/`, `nui/`) que so traduzem para Qbox/ox_*/natives. Servidor e autoritativo.

```
config/config.lua      defaults editaveis (sem segredos)
core/rng.lua           RNG injetavel (system | seeded | scripted)
core/util.lua          clamp, range, weighted_pick, shallow_copy
core/economy.lua       tabela policial interpolada, preco/pacote, scroll->preco, combo, premio raro
core/profiles.lua      NPC individual: arquetipo + atributos sorteados por faixa
core/negotiation.lua   decisao por proposta (aceite/contra/hesita/denuncia/briga) + humor/paciencia
core/probability.lua   resultados na abordagem; Plus rara 1/1000 (1 sorteio inteiro)
core/roll_guard.lua    1 oportunidade por abordagem; cooldown por identificador persistente
tests/                 framework proprio + suites; tools/run_lua_tests.py (Lua 5.4 via lupa)
```

## Decisoes
1. **Cliente nunca envia dinheiro**: envia `step` (inteiro do scroll) e `qty`; `economy` recalcula (R08.1).
2. **Sorteio raro**: `rng.int(1, 1000) == 1`, sem influencia de atributos; `roll_guard` entrega um token
   por abordagem elegivel; reabrir a NUI nao gera novo sorteio; chave = identificador persistente.
3. **Estado do NPC imutavel por turno** (`negotiation.evaluate` devolve copia) => facil de journalar/reproduzir.
4. **Zonas e arquetipos em config**: adicionar perfil/zona nao exige mexer no motor (A22).
5. **IA so linguagem** (a implementar): contrato JSON estruturado; decisao vem de `negotiation`.

## Planejado (ainda NAO implementado)
`server/session.lua` (sessao + trava de NPC), `server/ledger.lua` (journal duravel/idempotencia/compensacao),
`server/qbox.lua` (unica camada que chama qbx_core/ox_inventory/dispatch), `server/ai.lua` + fallback local,
`client/` (descoberta de peds, target, animacoes, briga), `nui/`, `fxmanifest.lua`, SQL/itens.

## Limites honestos
Nao ha atomicidade entre ox_inventory e qbx_core: o ledger usara intencao -> remocao -> pagamento ->
confirmacao, com compensacao/reconciliacao (R08.4). Peds apenas locais: servidor nao os valida; sera
usado netId quando existir e, caso contrario, sessao + distancia + cooldown por identificador.
