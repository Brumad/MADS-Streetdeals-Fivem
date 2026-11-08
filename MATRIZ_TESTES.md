# Matriz requisito -> implementacao -> teste -> evidencia

Estados: NAO_INICIADO, IMPLEMENTADO_NAO_TESTADO, TESTE_LOCAL_APROVADO, INTEGRACAO_VERIFICADA, HOMOLOGADO, BLOQUEADO, REPROVADO.
Ambiente das evidencias: Lua 5.4 (lupa.lua54) em container Linux, 2026-11-08. **Teste local != Qbox real != in-game.**
Comando: `python3 tools/run_lua_tests.py` (72 testes, 0 falhas no ultimo run). Mutacoes de sanidade: 6/6 (core) e 4/4 (ledger) detectadas.

| Req | Descricao | Implementacao | Teste | Estado |
|---|---|---|---|---|
| R03.1-R03.4 / A07 / C01 | $2000/pacote, tabela policial exata+interpolada | core/economy.lua | tests/test_economy.lua | TESTE_LOCAL_APROVADO |
| R03.5 / A09 | scroll: desconto↑aceite/↓denuncia, sobrepreco inverso | core/negotiation.lua, economy.ratio_from_step | test_negotiation.lua (monotonia) | TESTE_LOCAL_APROVADO |
| R04.4 / A13 / C02 | raro 1/1000, sorteio unico, premio 5x–10x | core/probability.lua, roll_guard.lua, economy.rare_prize | test_probability.lua, test_roll_guard.lua | TESTE_LOCAL_APROVADO (logica) |
| R04.5 / A14 / C03 | combo 1–4, total, mais frequente que raro | economy.combo_total, probability | test_economy, test_probability | PARCIAL: estoque/inventario NAO_INICIADO |
| R02 / A03-A06 | perfis, humor, zonas afetam decisoes | core/profiles.lua, negotiation, probability | test_profiles, test_negotiation, test_probability | TESTE_LOCAL_APROVADO (logica) |
| R04.6 / A15 | confronto fisico | probabilidade de briga em core | test_negotiation | PARCIAL: combate real NAO_INICIADO |
| R08.3 (reroll/cooldown) | anti-repeticao, reconexao | core/roll_guard.lua | test_roll_guard.lua | TESTE_LOCAL_APROVADO (logica) |
| R01, R05, R06, R07, R08.4-R08.5, R09.3-R09.6 | NPC ambiental, IA, NUI, Qbox, journal, NUI/in-game | — | — | NAO_INICIADO |

| R08.4 / R08.5 / B09 / B10 / C07 (logica) | journal, idempotencia, compensacao, recuperacao, falha segura | core/ledger.lua | tests/test_ledger.lua (queda em cada operacao, corrupcao, IO) | TESTE_LOCAL_APROVADO (portas fake; store duravel e Qbox/ox_inventory reais NAO_INICIADO) |
