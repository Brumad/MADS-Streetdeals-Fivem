# Homologação em FXServer/FiveM — roteiro e estado

**Estado: NÃO EXECUTADA.** Este ambiente não possui FXServer, cliente GTA/FiveM, Qbox instalado, dispatch real nem chave de IA.
Marque cada item abaixo com data/ambiente/evidência somente após executá-lo de verdade.

| # | Verificação | Checks | Estado |
|---|---|---|---|
| 1 | Resource inicia sem erros com qbx_core/ox_*/oxmysql; tabela criada | C08 B01 | PENDENTE |
| 2 | `GetDutyCountType('<tipo>')` conta só policiais em serviço; preço muda 0→8 | A08 B04 | PENDENTE |
| 3 | RemoveItem/AddItem/pagamento corretos (cash/bank/item) | B02 B03 A21 | PENDENTE |
| 4 | Pedestres ambientais: `netId` existe? ox_target aparece? tecla funciona? | A01 A02 B06 C09 | PENDENTE |
| 5 | Peds locais (sem netId): comportamento do modo degradado | A02 R01.4 | PENDENTE |
| 6 | Nomes de animação existem e sincronizam (hello/refuse/trade) | A20 | PENDENTE |
| 7 | Briga/perseguição + limpeza (ped volta ao normal) | A15 | PENDENTE |
| 8 | Denúncia dispara o dispatch real configurado | A11 B05 | PENDENTE |
| 9 | Duas pessoas, mesmo NPC: exclusão mútua; sem duplicação | C10 B08 | PENDENTE |
| 10 | Queda/restart no meio da venda → `mads_sd_review` coerente | B09 B10 | PENDENTE |
| 11 | IA externa real (provedor/chave): resposta, timeout, limites | A16 B11 | PENDENTE |
| 12 | NUI no CEF: foco, scroll, resoluções | A19 B12 | PENDENTE |
| 13 | resmon/profiler com carga | B13 C11 | PENDENTE |
| 14 | Coordenadas de `areas` e nomes de modelo conferidos no mapa | A06 | PENDENTE |
