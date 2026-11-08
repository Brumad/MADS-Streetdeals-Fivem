# Referencias tecnicas consultadas

Hierarquia: codigo real da dependencia > docs oficiais > repos oficiais. Data da consulta: 2026-11-08.
Limitacao: `docs.qbox.re` e `docs.fivem.net` retornaram 403 do proxy do ambiente; a verificacao foi feita
pelo **codigo-fonte** em `raw.githubusercontent.com`. Itens de docs ainda nao lidos estao marcados.

| Fonte | Versao/commit | O que foi verificado | Onde e usado |
|---|---|---|---|
| qbx_core `server/functions.lua` (branch main) | fxmanifest `1.24.1` | `exports('GetDutyCountType', fn)` e `GetDutyCountJob` retornam `(count, players)`; contam apenas jogadores **em servico** (`onduty`) | contagem policial (a implementar em `server/qbox.lua`) |
| qbx_core `server/player.lua` | 1.24.1 | `AddMoney(identifier, moneyType, amount, reason) -> boolean`; `RemoveMoney` idem; falha se `moneyType` nao existe em `PlayerData.money`; `GetMoney` | pagamento (a implementar) |
| qbx_core `fxmanifest.lua` | 1.24.1 | depende de `ox_lib`, `oxmysql`, OneSync; `lua54 'yes'`; `provide 'qb-core'` | `fxmanifest.lua` do resource |
| ox_lib `init.lua` / `require.lua` | 3.42.2 | `require` e instalado por `@ox_lib/init.lua`; delega ao resource `require` (`fx_dependencies 'require: 1.0.2'`) | modulos `core.*` carregados com `require` |
| ox_inventory `fxmanifest.lua`, `modules/items/server.lua` | main | arquivos baixados; **assinaturas de `RemoveItem/AddItem/GetItemCount` ainda NAO verificadas** | pendente (fase Qbox/inventario) |

## Pendente de verificacao (nao assumir)
- ox_inventory: exports de servidor, retorno de `RemoveItem`, hooks, metadata.
- ox_target: `addGlobalPed` / `removeGlobalPed` (cliente) e suas opcoes.
- Qbox: nome real do `type` de job policial na instalacao (`leo` e o padrao do qbx_core, **a confirmar** em `shared/jobs.lua` da cidade).
- Dispatch real instalado (ps-dispatch, cd_dispatch, etc.): nao presumir.
- Docs FiveM: OneSync/network IDs, state bags, NUI callbacks, `PerformHttpRequest`.
- Nomes de modelos de ped em `modelArchetypeHints`: sao dicas; homologar in-game.
