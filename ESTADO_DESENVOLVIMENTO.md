# Estado do desenvolvimento — MADS StreetDeals

Contrato: [REQUISITOS.md](REQUISITOS.md) · Gate: [CRITERIOS_DE_APROVACAO.md](CRITERIOS_DE_APROVACAO.md) · Matriz (56 checks): [MATRIZ_TESTES.md](MATRIZ_TESTES.md)
Branch: `claude/keen-brown-5dpabc`. **V1 NAO aprovada**: nenhum check esta INTEGRACAO_VERIFICADA/HOMOLOGADO.

## (a) Objetivo atual
Resource completo em codigo (todos os sistemas implementados) e empacotado; falta homologacao externa (FXServer/Qbox/FiveM/IA real).

## (b) Concluido (implementado)
Nucleo `core/*`, `server/{engine,main,qbox,dispatch,journal_store}.lua`, `client/main.lua`, `nui/*`, `fxmanifest.lua`,
`sql/`, `install/`, `config/config.lua`, `tools/package.py`, docs (INSTALACAO, CONFIGURACAO, IA_E_SEGURANCA, INTEGRACAO_QBOX,
HOMOLOGACAO_FXSERVER, ARQUITETURA, REFERENCIAS_TECNICAS, MATRIZ_TESTES).

## (c) Testes e evidencias (locais; container Linux, 2026-11-08)
- `python3 tools/run_lua_tests.py`: **133 passou, 0 falhou** (Lua 5.4 via lupa). Inclui 1M de sorteios do raro, varredura de queda em cada operacao do ledger, engine ponta a ponta com dublês, IA com HTTP fake (malformado/timeout/injecao/limites/breaker).
- `node tests/nui/run.js`: **25 passou, 0 falhou** (Chromium/Playwright): scroll, teclado, chat, loading, falha, timeout, cancelar, duplo clique, 5 resolucoes.
- Mutacoes de sanidade detectadas (core 6/6, ledger 4/4). Sintaxe Lua 5.4 de todos os .lua valida.
- Pacotes gerados e verificados por `tools/package.py` (testzip + varredura de segredos).

## (d) Pendencias / bloqueios (dependem do usuario/ambiente)
FXServer+Qbox+ox_*+oxmysql (C08, B01–B06), cliente FiveM (C09, A15, A20), 2 jogadores (C10), resmon (B13, C11),
dispatch real (A11, B05), chave/provedor de IA (A16 real), definir licenca (D05). Ver HOMOLOGACAO_FXSERVER.md.

## (e) Riscos e decisoes
- Sem atomicidade inventario<->dinheiro: ambiguo -> `needs_review`, nunca repete acao.
- Ped local (sem netId) nao e validavel: modo degradado configuravel (`allowUnverifiedLocalPeds`).
- Nomes de animacao/modelo/`areas` (coordenadas) sao exemplos a homologar; `populationTypes` desligado ate homologar.
- IA: formatos `anthropic`/`openai` pela documentacao publica, nao testados com chamada real.
- `GetEntityPopulationType`, `lib.requestAnimDict`, `onSelect(data.entity)` do ox_target: usados conforme conhecimento/codigo lido, a confirmar in-game.

## (f) Proxima acao
Instalar em servidor de teste Qbox e executar HOMOLOGACAO_FXSERVER.md item a item; depois `/mads-audit` (auditoria independente).
