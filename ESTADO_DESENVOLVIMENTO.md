# Estado do desenvolvimento — MADS StreetDeals

Contrato: [REQUISITOS.md](REQUISITOS.md) · Gate: [CRITERIOS_DE_APROVACAO.md](CRITERIOS_DE_APROVACAO.md) · Matriz: [MATRIZ_TESTES.md](MATRIZ_TESTES.md)
Branch: `claude/keen-brown-5dpabc`. V1 NAO concluida (nenhum dos 56 checks esta HOMOLOGADO).

## (a) Modulo atual
Fundacoes do nucleo puro (economia, probabilidade, perfis, negociacao) e integridade financeira (ledger).

## (b) Concluido (implementado)
- `config/config.lua`, `core/{rng,util,economy,profiles,negotiation,probability,roll_guard,ledger}.lua`
- `tests/` (framework, fakes, 6 suites), `tools/run_lua_tests.py`
- Docs: `ARQUITETURA.md`, `REFERENCIAS_TECNICAS.md`, `MATRIZ_TESTES.md`

## (c) Testes e evidencias
- `python3 tools/run_lua_tests.py` -> 72 passou, 0 falhou (Lua 5.4 via lupa, container Linux, 2026-11-08). Teste LOCAL, sem Qbox/FiveM.
- Mutacoes de sanidade: 6/6 no core e 4/4 no ledger detectadas.
- Ledger: varredura de queda em cada operacao (3 cenarios), idempotencia, corrupcao, falha de IO.
- Nao commitado ainda: `core/ledger.lua`, `tests/fakes.lua`, `tests/test_ledger.lua`, edicao em `tests/run_all.lua`.

## (d) Pendencias / bloqueios
- Sem FXServer/Qbox/cliente FiveM: C08–C10 BLOQUEADO. Sem chave de IA: A16/B11 real BLOQUEADO.
- `docs.qbox.re` e `docs.fivem.net` dao 403 no proxy; verificacao so via codigo no GitHub.
- NAO_INICIADO: sessoes/trava de NPC, camada Qbox, ox_inventory/ox_target (assinaturas nao verificadas), dispatch, IA+fallback, NUI, client (peds, animacoes, briga), store duravel de producao (oxmysql/arquivo), fxmanifest, SQL/itens, docs restantes.

## (e) Riscos e decisoes
- Sem atomicidade inventario<->dinheiro: estados ambiguos vao a `needs_review`, nunca repetem acao.
- Ped apenas local nao e validavel pelo servidor: mitigar por sessao + distancia + cooldown por identificador.
- Defaults de pesos/zonas/arquetipos sao propostas editaveis (R04.7).
- Tipo de job policial (`leo`?) a confirmar na instalacao.

## (f) Proxima acao
1. Commit do ledger. 2. Verificar assinaturas reais de ox_inventory (`RemoveItem/AddItem/GetItemCount`) e ox_target (`addGlobalPed`) em raw.githubusercontent.com e registrar em `REFERENCIAS_TECNICAS.md`. 3. Criar `core/session.lua` (trava de NPC, expiracao, estados) + `tests/test_session.lua`.
