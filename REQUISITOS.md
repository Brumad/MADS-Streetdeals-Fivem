# Contrato de requisitos — MADS StreetDeals

**Fonte de verdade de escopo.** Todas as secoes abaixo fazem parte da primeira entrega; nao deslocar itens para V2. Produto: resource FiveM exclusivamente Qbox. O nucleo pode ser modular, mas nao desenvolver outra integracao de framework nesta execucao.

## R01 — Pedestres ambientais

- R01.1: permitir abordar pedestres comuns elegiveis de GTA V no mapa; nao limitar a compradores fixos.
- R01.2: descoberta eficiente proxima, via ox_target confirmado ou interacao alternativa configuravel.
- R01.3: filtrar players, peds mortos/ocupados/incompativeis ou controlados por outros resources; suportar OneSync, distancias e buckets.
- R01.4: impedir dois jogadores negociando com o mesmo NPC e abuso de NPCs/abordagens; tratar ped local sem identificacao confiavel.
- R01.5: finalizar sessao e restaurar estado em morte, despawn, cancelamento, desconexao e restart.
- R01.6: compradores fixos sao opcionais, nao substitutos.

## R02 — Personalidade, aparencia e contexto

- R02.1: NPC individual com modelo/skin, arquetipo, humor, paciencia, agressividade, orcamento, interesse, tolerancia a preco, propensao a denuncia, local e contexto.
- R02.2: atributos **alteram decisoes reais**; mesma skin pode gerar comportamentos diferentes.
- R02.3: arquetipos iniciais comum, empresario, atleta e morador de rua; atleta e morador de rua com modificador aumentado de confronto (perfis ficticios de gameplay).
- R02.4: humor muda durante conversa; paciencia/insistencia afetam respostas, negociacao e risco.
- R02.5: zonas configuraveis: movimentadas, residenciais, isoladas, risco policial, proximidade de delegacias; horario/contexto quando viavel.

## R03 — Economia e policia

- R03.1: preco-base **$2.000 por pacote** representando 5 unidades. Referencias de balanceamento: $120 unidade, $600 cinco unidades e $5.000 caixa eletronico.
- R03.2: multiplicadores por **policiais em servico**: 0=0,5x; 4=1x; 6=1,5x; 8+=2x; intermediarios interpolados: 1=0,625x; 2=0,75x; 3=0,875x; 5=1,25x; 7=1,75x.
- R03.3: valores por pacote correspondentes: $1000,$1250,$1500,$1750,$2000,$2500,$3000,$3500,$4000.
- R03.4: servidor calcula valor e snapshots validos da sessao; quantidade, arredondamentos, limites e tabelas editaveis.
- R03.5: scroll do mouse altera oferta durante negociacao: desconto tende a reduzir denuncia/favorecer aceitacao; sobrepreco faz o contrario, **em condicoes equivalentes**.
- R03.6: modificadores combinam preco, humor, perfil, orcamento e ambiente; nao garantir aceites por percentuais fixos.
- R03.7: configuracoes de itens/drogas e meios de pagamento; registrar regras de converter pacote (item proprio) versus cinco itens avulsos sem consumo duplo.

## R04 — Seis resultados principais

- R04.1: **recusa simples**, sem denuncia obrigatoria.
- R04.2: **recusa com denuncia**, gerando ocorrencia para dispatch quando integracao configurada.
- R04.3: **negociacao simples**, texto, oferta, contraproposta, aceitacao, irritacao, desistencias, cancelamento.
- R04.4: **Plus rara**: probabilidade exata de 1/1000 por **abordagem elegivel**, com sorteio unico e resistencia a repeticao da tela/cooldowns. Premio 5x–10x da referencia especial; padrao proposto referencia de $2.000 sem reaplicar multiplicador policial (configuravel). Distinguir ocorrer o evento de concluir a venda.
- R04.5: **Plus Combo**: de 1 a 4 pacotes, preco negociado por pacote, total correto, estoque validado; mais frequente que Plus rara.
- R04.6: **confronto fisico**: hostilidade, combate, eventual perseguicao, possiveis complicacoes durante fuga, animacoes e limpeza; modificadores de arquetipo.
- R04.7: probabilidades comuns sao configuraveis e nao foram formalmente fixadas pelo usuario; nao tratar estimativas antigas (30/10/45/10/4,9/0,1) como parametros obrigatorios.

## R05 — Conversacao por IA

- R05.1: chat **livre** em portugues brasileiro; nao trocar por menus fixos.
- R05.2: motor economico server-side autoritativo separado do motor de linguagem.
- R05.3: dialogo reage a humor, perfil, proposta, historico, situacao e resultados autorizados.
- R05.4: integracao HTTP **real** com provedor/modelo/endpoint configuraveis no servidor; guardar segredo fora do git/client.
- R05.5: limites de mensagens, tokens, custo, timeout, rate limit; validacao de saida e protecao contra prompt injection.
- R05.6: fallback local contextual funcional quando IA ausente, sem apresentacao enganosa como IA externa.
- R05.7: LLM nunca concede dinheiro, altera estoque/preco/probabilidade ou ignora guardrails do servidor.

## R06 — NUI, UX e animacoes

- R06.1: NUI profissional e original em HTML/CSS/JS, responsiva e em pt-BR; identifique comprador, mensagens, input, preco, quantidade, contraproposta e total.
- R06.2: scroll, confirmar, cancelar, loading, erros, feedback de venda/recusa/denuncia/confronto.
- R06.3: foco de teclado/mouse correto; controles desbloqueados apos erro/requisicao rejeitada.
- R06.4: animacoes apropriadas para abordar, conversar, trocar mercadoria, aceitar, recusar, encerrar e combater; sincronizacao viavel, interrupcao e limpeza.
- R06.5: animacao ou callback da NUI nao pode provocar duplicacao de pagamento.

## R07 — Qbox e sistemas reais

- R07.1: verificar exports/APIs reais de qbx_core e ecossistema efetivo (ox_lib, ox_inventory, ox_target, oxmysql quando presentes).
- R07.2: integrar identidade, item/estoque, consumo/devolucao, dinheiro, job em servico, notificacao, target e persistencia.
- R07.3: dispatch e policia dependem do resource real instalado; nao supor um dispatch universal.
- R07.4: confirmar contagem de policiais **efetivamente em servico**, e nao todos os integrantes do job.
- R07.5: nao criar integracao Creative vRP, ESX ou standalone como obrigacao desta entrega.
- R07.6: uso por cidade standalone nao esta comprovado e seria trabalho adicional de integracao.

## R08 — Seguranca e consistencia financeira

- R08.1: validar source/identidade, sessao, entidade, distancia, bucket, existencia e estado do ped, estoque, preco, quantidade, cooldown e expiracao **no servidor**.
- R08.2: rejeitar evento duplicado, adulterado, fora de ordem, rate-limit ou de sessao ja encerrada.
- R08.3: impedir negociacao concorrente com o mesmo NPC, pagamento ou item duplicado, brute-force da Plus rara.
- R08.4: proteger operacao de remocao e pagamento com identidade de transacao, idempotencia, journal duravel, compensacao/reconciliacao; nao prometer atomicidade cross-resource sem demonstracao.
- R08.5: desconexao, restart, corrupcao de journal ou falha de IO nao podem produzir pagamento indevido; falha segura e recuperacao demonstravel.
- R08.6: logs e diagnosticos de erros/negociacoes, sem expor chaves/dados privados.
- R08.7: desempenho aceitavel com multiplos jogadores, sem scans globais permanentes ou recursos vazando.

## R09 — Testes e evidencias

- R09.1: testes unitarios de economia, multiplicadores e probabilidades (incluindo raro), precos e combos 1–4.
- R09.2: testes de personalidade/zonas, negociacao, sessoes, eventos adversariais e tratamento de falhas.
- R09.3: testes NUI em navegador real; foco, scroll, chat, erros, responsividade e controle de botoes.
- R09.4: testes IA/fallback, HTTP incorreto, timeouts, prompt injection e limites.
- R09.5: teste de Qbox real com inventario, dinheiro, policiais, dispatch e target da instalacao; mocks nao substituem integracao.
- R09.6: homologacao FXServer/OneSync e GTA/FiveM (NPC ambiental, animacao, briga, denuncia, multiplayer e resmon/profiler).
- R09.7: regressao: HTTP malformado, NUI presa, reconexao burlando cooldown, duplicacao, restart no pagamento, falha compensatoria e corrupcao persistente.
- R09.8: criar matriz requisito -> arquivo -> teste -> evidencia e relatorio de pendencias sem declaracoes ficticias.

## R10 — Entrega e politica de conclusao

- R10.1: resource instalavel com fxmanifest, scripts client/server/shared, NUI, configuracoes, items, SQL quando necessario, instrucoes, logs, testes e licencas/dependencias.
- R10.2: gerar pacote instalavel e pacote de projeto completo com auditoria.
- R10.3: somente declarar **V1 final** apos TODOS os criterios de [CRITERIOS_DE_APROVACAO.md](CRITERIOS_DE_APROVACAO.md) aprovados com evidencia.
- R10.4: testes, bugs, seguranca e correcoes permanecem na V1; V2 somente para expansoes decididas apos a V1.
- R10.5: ausencia de acesso ao FXServer, chaves IA ou modulos da cidade e **bloqueio declarado**, nao autorizacao para fingir conclusao.

## Decisoes de implementacao abertas (nao requisitos inventados)

- Percentuais das cinco reacoes comuns, dentro da restricao de raridade, ficam configuraveis.
- Limites percentuais do scroll, alcance da interacao, duracao/cooldown, areas, quantidade de arquetipos, NPCs fixos opcionais, premio especial e valores distintos de itens devem ter defaults justificados.
- Escolha de dispatch Qbox depende do servidor.
- Destino do pagamento (conta/dinheiro sujo/item) requer configuracao conforme economia do servidor.
- Compatibilidade com NPCs ambientais locais requer projeto de verificacao de entidades, nao suposicoes de ownership.

**Nao excluir itens deste contrato sem nova instrucao expressa do usuario.**
