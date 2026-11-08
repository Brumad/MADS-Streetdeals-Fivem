# Matriz requisito -> implementacao -> teste -> evidencia

Estados: NAO_INICIADO, IMPLEMENTADO_NAO_TESTADO, TESTE_LOCAL_APROVADO, INTEGRACAO_VERIFICADA, HOMOLOGADO, BLOQUEADO, REPROVADO (NAO_VERIFICADO = sem evidencia).
**Nenhum check esta INTEGRACAO_VERIFICADA ou HOMOLOGADO.** V1 NAO aprovada. TESTE_LOCAL = Lua 5.4 (lupa) / Chromium (Playwright) com dublês, container Linux; nao prova Qbox nem gameplay.

Comandos: `python3 tools/run_lua_tests.py` e `node tests/nui/run.js`. Ultima execucao: ver ESTADO_DESENVOLVIMENTO.md.

| Check | Descricao | Implementacao | Teste | Estado | Pendencia |
|---|---|---|---|---|---|
| A01 | Peds ambientais negociaveis | client/main.lua (ox_target+tecla), server/engine.lua approach | tests/test_engine.lua (ped c/ netId e local) | TESTE_LOCAL_APROVADO (logica) | in-game: peds ambientais reais |
| A02 | Filtros ped/entidade/bucket/OneSync | engine.approach, server/qbox.lua ped() | test_engine (morto, jogador, longe, bucket, bloqueado, local) | TESTE_LOCAL_APROVADO (logica) | OneSync/netId reais |
| A03 | Personalidade individual | core/profiles.lua | test_profiles, test_negotiation | TESTE_LOCAL_APROVADO |  |
| A04 | Humor/paciencia/agressividade/orcamento/interesse | core/negotiation.lua | test_negotiation, test_probability | TESTE_LOCAL_APROVADO |  |
| A05 | 4 arquetipos + modificadores | config.archetypes | test_profiles, test_probability | TESTE_LOCAL_APROVADO |  |
| A06 | Zonas configuraveis | config.zones/areas, main.lua zone() | test_probability (zona) | TESTE_LOCAL_APROVADO (logica) | coordenadas de areas sao EXEMPLO |
| A07 | $2000/pacote + tabela policial | core/economy.lua | test_economy (9 valores exatos) | TESTE_LOCAL_APROVADO |  |
| A08 | Policiais em servico | server/qbox.lua police_count (GetDutyCountType) | test_engine (fake) | IMPLEMENTADO_NAO_TESTADO | INTEGRACAO real: tipo do job |
| A09 | Scroll ajusta oferta | economy.ratio_from_step, NUI wheel | test_negotiation (monotonia), tests/nui (scroll) | TESTE_LOCAL_APROVADO |  |
| A10 | Recusa simples | engine._terminal | test_engine | TESTE_LOCAL_APROVADO (logica) |  |
| A11 | Recusa com denuncia + dispatch real | server/dispatch.lua | test_engine (dispatch fake) | IMPLEMENTADO_NAO_TESTADO | BLOQUEADO: dispatch real da cidade |
| A12 | Negociacao com chat/contra/cancelar | engine _say/_offer/_accept_counter | test_engine, tests/nui | TESTE_LOCAL_APROVADO (logica) |  |
| A13 | Plus rara 1/1000, unico sorteio, 5x-10x | core/probability, roll_guard, economy.rare_prize | test_probability (1M), test_roll_guard, test_engine | TESTE_LOCAL_APROVADO (logica) |  |
| A14 | Plus Combo 1-4 | economy.combo_total, engine | test_economy, test_engine, test_probability | TESTE_LOCAL_APROVADO (logica) | estoque real (ox_inventory) |
| A15 | Confronto fisico/perseguicao | engine (decisao), client start_fight | test_engine (decisao) | IMPLEMENTADO_NAO_TESTADO | in-game: combate e limpeza |
| A16 | Chat livre pt-BR via IA externa | core/ai.lua, server/main.lua build_ai | test_ai, test_engine (HTTP fake) | IMPLEMENTADO_NAO_TESTADO | BLOQUEADO: sem chave/provedor real |
| A17 | IA sem autoridade financeira + limites | core/ai.lua validate/limites | test_ai, test_engine (injecao) | TESTE_LOCAL_APROVADO |  |
| A18 | Fallback local contextual | core/dialogue.lua | test_misc, test_engine | TESTE_LOCAL_APROVADO |  |
| A19 | NUI profissional/responsiva | nui/* | tests/nui/run.js (25, Chromium) | TESTE_LOCAL_APROVADO | CEF do FiveM nao testado |
| A20 | Animacoes coerentes/interrompiveis | client/main.lua play/release | — | IMPLEMENTADO_NAO_TESTADO | in-game: nomes de anim |
| A21 | Item/estoque/consumo/pagamento sem duplicar | core/ledger, server/qbox ports | test_ledger, test_engine (fakes) | TESTE_LOCAL_APROVADO (logica) | ox_inventory/qbx_core reais |
| A22 | Modulos/config administraveis | config/config.lua, deep_merge local.lua | test_economy (tabela editavel) | TESTE_LOCAL_APROVADO (parcial) |  |
| B01 | APIs qbx_core consultadas e validadas | REFERENCIAS_TECNICAS.md | leitura de codigo-fonte | IMPLEMENTADO_NAO_TESTADO | chamadas nao executadas em servidor |
| B02 | Inventario real consulta/consome | server/qbox.lua | — | IMPLEMENTADO_NAO_TESTADO | BLOQUEADO: sem FXServer |
| B03 | Dinheiro real paga exato | server/qbox.lua pay | — | IMPLEMENTADO_NAO_TESTADO | BLOQUEADO: sem FXServer |
| B04 | Job duty consulta policiais | server/qbox.lua | — | IMPLEMENTADO_NAO_TESTADO | BLOQUEADO: sem FXServer |
| B05 | Dispatch real recebe alertas | server/dispatch.lua | — | IMPLEMENTADO_NAO_TESTADO | BLOQUEADO: dispatch da cidade |
| B06 | Target e notificacoes reais | client/main.lua, qbox.notify | — | IMPLEMENTADO_NAO_TESTADO | BLOQUEADO: sem FiveM |
| B07 | Validacao server-side completa | server/engine.lua | test_engine (adulteracao) | TESTE_LOCAL_APROVADO (logica) |  |
| B08 | Concorrencia/duplicacao/expirada | core/session, roll_guard, ledger | test_misc, test_engine, test_ledger | TESTE_LOCAL_APROVADO (logica) | multiplayer real |
| B09 | Journal/idempotencia/compensacao/recuperacao | core/ledger, journal_store | test_ledger (queda em cada operacao) | TESTE_LOCAL_APROVADO (store fake) | oxmysql real |
| B10 | Desconexao/restart/corrupcao falham seguro | ledger.start, engine.close_player | test_ledger, test_engine | TESTE_LOCAL_APROVADO (logica) | restart real |
| B11 | IA: HTTP malformado/timeout/injection | core/ai.lua | test_ai, test_engine | TESTE_LOCAL_APROVADO (HTTP fake) | provedor real |
| B12 | NUI recupera controle; sem confirmacao dupla | nui/app.js, client callbacks | tests/nui (falha, timeout, duplo clique) | TESTE_LOCAL_APROVADO | CEF real |
| B13 | Consumo medido sem vazamentos | sweep/forget/limites | test_roll_guard, test_misc (churn) | NAO_VERIFICADO | BLOQUEADO: resmon/profiler |
| B14 | Sem chaves/segredos versionados | convar, .gitignore, tools/package.py scan | varredura no empacotamento | TESTE_LOCAL_APROVADO |  |
| C01 | Testes economia/interpolacao | — | test_economy | TESTE_LOCAL_APROVADO |  |
| C02 | Testes probabilidade e Plus rara | — | test_probability | TESTE_LOCAL_APROVADO |  |
| C03 | Testes combo/estoque/totais | — | test_economy, test_engine | TESTE_LOCAL_APROVADO |  |
| C04 | Testes sessoes/estado/eventos adulterados | — | test_misc, test_engine | TESTE_LOCAL_APROVADO |  |
| C05 | Testes HTTP/IA/fallback/limitadores | — | test_ai, test_engine | TESTE_LOCAL_APROVADO |  |
| C06 | Testes NUI em navegador | — | tests/nui/run.js | TESTE_LOCAL_APROVADO | CEF |
| C07 | Testes financeiros adversariais/reinicios | — | test_ledger, test_engine | TESTE_LOCAL_APROVADO |  |
| C08 | Resource inicia em FXServer Qbox | fxmanifest.lua | — | BLOQUEADO | sem FXServer |
| C09 | Testes reais no FiveM | — | — | BLOQUEADO | sem cliente FiveM |
| C10 | Multiplayer: exclusao mutua | — | — | BLOQUEADO | sem servidor com 2 jogadores |
| C11 | resmon/profiler | — | — | BLOQUEADO | sem FXServer |
| C12 | Falhas criticas corrigidas e retestadas | — | regressoes nos suites | TESTE_LOCAL_APROVADO (parcial) | falhas in-game desconhecidas |
| D01 | fxmanifest + Lua + NUI + config completos | raiz | sintaxe Lua 5.4 de todos os .lua | IMPLEMENTADO_NAO_TESTADO | nao carregado em FXServer |
| D02 | Instalacao/itens/banco/dispatch/IA documentados | INSTALACAO, CONFIGURACAO, INTEGRACAO_QBOX, IA_E_SEGURANCA | — | IMPLEMENTADO_NAO_TESTADO | validar passos em servidor |
| D03 | Matriz auditavel | este arquivo | — | IMPLEMENTADO_NAO_TESTADO | auditoria independente (/mads-audit) pendente |
| D04 | ZIPs gerados e verificados | tools/package.py | unzip/testzip + testes a partir do ZIP | TESTE_LOCAL_APROVADO |  |
| D05 | Licencas/direitos | — | — | NAO_INICIADO | sem codigo de terceiros; licenca do projeto nao definida |
| D06 | Relatorio diferencia niveis | ESTADO_DESENVOLVIMENTO.md | — | IMPLEMENTADO_NAO_TESTADO |  |
| D07 | Sem placeholders criticos | — | grep TODO/FIXME | NAO_VERIFICADO | revisao final |
| D08 | Revisao final de todos os itens | — | — | NAO_INICIADO | depende da auditoria |

Resumo (por estado base): BLOQUEADO=4, IMPLEMENTADO_NAO_TESTADO=15, NAO_INICIADO=2, NAO_VERIFICADO=2, TESTE_LOCAL_APROVADO=33
