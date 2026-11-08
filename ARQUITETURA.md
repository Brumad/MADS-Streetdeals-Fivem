# Arquitetura — mads_streetdeals (Qbox)

Principio: **nucleo puro e testavel** (`core/`, sem natives, sem Qbox) + **camadas finas de integracao**
(`server/`, `client/`, `nui/`) que so traduzem para Qbox/ox_*/natives. Servidor e autoritativo.

```
config/config.lua        defaults editaveis (sem segredos); config/local.lua opcional (ignorado pelo git)
core/                    NUCLEO PURO (sem natives) - testado localmente
  rng util json          RNG injetavel, utilitarios, JSON estrito
  economy                tabela policial interpolada, scroll->preco, combo, premio raro
  profiles negotiation   NPC individual; decisao por proposta; humor/paciencia/intencao
  probability roll_guard resultados da abordagem; Plus rara 1/1000; 1 oportunidade por abordagem
  session                1 sessao/jogador, 1 jogador/NPC, expiracao, seq anti-replay, ritmo
  ledger                 journal duravel, idempotencia, compensacao, recuperacao (portas injetadas)
  dialogue ai            fallback local + classificador de intencao; cliente de IA com contrato/limites
server/engine.lua        orquestrador autoritativo (env injetado) - testado com dublês
server/main.lua          cola FiveM: callbacks ox_lib, threads, comandos admin
server/qbox.lua          UNICA camada Qbox/ox_inventory (player, ped, policiais, estoque, portas)
server/dispatch.lua      adaptador de dispatch (none|export|event)
server/journal_store.lua store duravel em oxmysql
client/main.lua          ox_target + tecla, abordagem, NUI, animacoes, briga, limpeza
nui/                     HTML/CSS/JS responsivo (scroll, chat, loading, erros, cancelamento)
tests/ tools/            suites Lua (133), NUI Chromium (25), empacotamento
```

## Decisoes
1. **Cliente nunca envia dinheiro**: envia `step` (inteiro do scroll) e `qty`; `economy` recalcula (R08.1).
2. **Sorteio raro**: `rng.int(1, 1000) == 1`, sem influencia de atributos; `roll_guard` entrega um token
   por abordagem elegivel; reabrir a NUI nao gera novo sorteio; chave = identificador persistente.
3. **Estado do NPC imutavel por turno** (`negotiation.evaluate` devolve copia) => facil de journalar/reproduzir.
4. **Zonas e arquetipos em config**: adicionar perfil/zona nao exige mexer no motor (A22).
5. **IA so linguagem** (a implementar): contrato JSON estruturado; decisao vem de `negotiation`.

## Limites honestos
Nao ha atomicidade entre ox_inventory e qbx_core: o ledger usara intencao -> remocao -> pagamento ->
confirmacao, com compensacao/reconciliacao (R08.4). Peds apenas locais: servidor nao os valida; sera
usado netId quando existir e, caso contrario, sessao + distancia + cooldown por identificador.
