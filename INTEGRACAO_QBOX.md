# Integração Qbox / ox_*

Toda chamada externa está em `server/qbox.lua` (e `server/dispatch.lua`). Fontes: ver `REFERENCIAS_TECNICAS.md`.

| Necessidade | Chamada | Verificado |
|---|---|---|
| Jogador / citizenid | `exports.qbx_core:GetPlayer(src).PlayerData.citizenid` | código (GetPlayer exportado) |
| Policiais em serviço | `exports.qbx_core:GetDutyCountType(type)` → `count, players` | **código lido** (conta `onduty`) |
| Pagar | `player.Functions.AddMoney(tipo, valor, motivo)` → boolean | **código lido** |
| Notificar | `exports.qbx_core:Notify(src, texto, tipo)` | export presente no código |
| Estoque | `exports.ox_inventory:GetItemCount(src, item)` | **código lido** |
| Remover / devolver | `RemoveItem(src,item,n)` → `ok, resp`; `AddItem(src,item,n)` | **código lido** |
| Alvo | `exports.ox_target:addGlobalPed(opcoes)` / `removeGlobalPed(nome)` | código lido (assinatura) |

**Pendente de execução real:** nenhuma dessas chamadas foi executada contra um servidor Qbox (ver HOMOLOGACAO_FXSERVER.md).

## Dinheiro sujo
Qbox não tem "dinheiro sujo" nativo na carteira. Se a cidade usa um **item** (ex.: `black_money`), use
`payment.kind = 'item'` + `payment.moneyItem`. Se usa sistema financeiro próprio, não há integração pronta: não invente funções;
escreva uma porta `pay` equivalente em `server/qbox.lua`.

## Dispatch
Não existe dispatch universal. `dispatch.mode`:
- `export`: `exports[resource][export](exports[resource], alert)`;
- `event`: `TriggerEvent(event, alert)` (evento de servidor);
- `none` (padrão): apenas log.
`alert = { coords, code, message, src, zone }`. Se o seu dispatch exige outro formato (ps-dispatch, cd_dispatch…), ajuste o
adaptador em `server/dispatch.lua` conforme a documentação **da versão instalada**. Cooldown por jogador: `dispatch.cooldownSec`.
