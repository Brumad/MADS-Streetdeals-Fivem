# Instalação — mads_streetdeals (Qbox)

> Estado: **resource completo em código, NÃO homologado** em FXServer/FiveM (ver `HOMOLOGACAO_FXSERVER.md`).

## Requisitos (verificados no código-fonte das dependências)
| Recurso | Motivo |
|---|---|
| `qbx_core` (≥ 1.24.1 testado por leitura de código) | jogador, `GetDutyCountType`, dinheiro, notificações |
| `ox_lib` (≥ 3.x) | `require`, callbacks, notificações, anim dict |
| `ox_inventory` | `GetItemCount`, `RemoveItem`, `AddItem` |
| `ox_target` | opção global em pedestres (`addGlobalPed`) |
| `oxmysql` | journal financeiro durável |
| OneSync ligado, artefato ≥ 7290 | entidades de rede / routing buckets |

## Passos
1. Copie a pasta `mads_streetdeals/` para `resources/[local]/` (ou equivalente).
2. Copie as entradas de `install/ox_inventory_items.lua` para o `data/items.lua` do ox_inventory.
3. A tabela `mads_sd_journal` é criada sozinha no start (ou rode `sql/install.sql`).
4. No `server.cfg`, **depois** das dependências:
   ```
   ensure mads_streetdeals
   # IA externa (opcional; `set`, NUNCA `setr`):
   set mads_sd_ai_key "SUA_CHAVE"
   # permissoes de administracao
   add_ace group.admin command.mads_sd_review allow
   add_ace group.admin command.mads_sd_resolve allow
   ```
5. Ajuste `config/config.lua` (ou crie `config/local.lua`, ignorado pelo git, que é mesclado por cima):
   - `police.jobType`: `type` do job policial no seu `qbx_core/shared/jobs.lua` (padrão `leo`).
   - `payment.kind`: `cash`, `bank` ou `item` (+ `payment.moneyItem` para dinheiro sujo como item).
   - `dispatch`: ver `INTEGRACAO_QBOX.md`.
   - `goods`: nomes de item coerentes com o passo 2.
6. Reinicie e confira o console: `[mads_streetdeals] [info] iniciado ...`. Se aparecer
   `vendas BLOQUEADAS` ou `engine nao iniciou`, o resource está em **falha segura** (ver log).

## Uso
Aproxime-se de um pedestre comum: opção **Abordar** (ox_target) ou tecla `G` (configurável).
Role o mouse no painel de preço para ajustar a oferta; Esc cancela.

## Administração
`mads_sd_review` lista transações em revisão manual; `mads_sd_resolve <key> paid_manually|refunded_manually|dismissed`.
