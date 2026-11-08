# Gate de aprovacao — MADS StreetDeals V1

**Regra vinculante:** V1 nao termina ate que todos os checks decididos pelo usuario sejam comprovados. Corrigir bugs, otimizar e homologar **nao** constitui V2. Nenhum teste mockado substitui teste de integracao, nem navegador substitui gameplay FiveM.

Estados permitidos na matriz: `NAO_INICIADO`, `IMPLEMENTADO_NAO_TESTADO`, `TESTE_LOCAL_APROVADO`, `INTEGRACAO_VERIFICADA`, `HOMOLOGADO`, `BLOQUEADO`, `REPROVADO`. Registrar evidencia e data em arquivo de auditoria; NUNCA preencher aprovado por estimativa.

## A. Escopo funcional — todos obrigatorios

- [ ] **A01** Pedestres ambientais elegiveis sao negociaveis (sem dependencia de 12 NPCs fixos).
- [ ] **A02** Filtros de NPC/entidade, proximidade, bucket, OneSync, bloqueios e limpeza funcionam.
- [ ] **A03** Personalidade individual afeta a logica e nao depende somente da skin.
- [ ] **A04** Humor, paciencia, agressividade, orcamento e interesse mudam resultados e dialogos.
- [ ] **A05** Perfis comum, empresario, atleta e morador de rua, com modificadores previstos.
- [ ] **A06** Localizacao e zonas configuraveis influenciam riscos/decisoes.
- [ ] **A07** Preco-base $2000/pacote (5 unidades) e tabela policial exata/interpolada.
- [ ] **A08** Contagem policial usa efetivamente agentes em servico.
- [ ] **A09** Scroll ajusta proposta; desconto/sobrepreco afetam aceitacao/denuncia.
- [ ] **A10** Recusa simples funciona sem denuncia obrigatoria.
- [ ] **A11** Recusa com denuncia emite dispatch real configurado.
- [ ] **A12** Negociacao simples com chat, contrapropostas, aceitacao, recusa e cancelamento.
- [ ] **A13** Plus rara: 1/1000 por abordagem elegivel, sorteio unico, premio 5x–10x e bloqueio de reroll.
- [ ] **A14** Plus Combo: 1–4 pacotes, preco unitario/total e estoque corretos; mais frequente que raro.
- [ ] **A15** Confronto fisico e possivel perseguicao funcionam com encerramento seguro.
- [ ] **A16** Conversa em texto livre pt-BR via IA externa configuravel com contrato estruturado.
- [ ] **A17** IA nao pode alterar resultado financeiro; seguranca, limites e controle de custos.
- [ ] **A18** Fallback local contextual funciona quando IA falha ou nao foi configurada.
- [ ] **A19** NUI profissional e responsiva: chat, scroll, quantidade, preco, feedback, loading, erros e foco.
- [ ] **A20** Animacoes de abordagem/troca/recusa/combate sao coerentes, interrompiveis e seguras.
- [ ] **A21** Item/estoque, consumo, devolucao e pagamento operam sem duplicacao.
- [ ] **A22** Modulos e configuracoes administraveis sem reescrever o motor.

## B. Integracao, seguranca e qualidade

- [ ] **B01** APIs qbx_core e dependencias consultadas e chamadas validadas com versoes reais.
- [ ] **B02** Inventario/Qbox da instalacao real consulta e consome itens corretamente.
- [ ] **B03** Dinheiro/Qbox paga exatamente o autorizado, em conta/modalidade correta.
- [ ] **B04** Job duty/Qbox consulta policiais efetivamente em servico.
- [ ] **B05** Dispatch real da instalacao recebe alertas adequados.
- [ ] **B06** Target e notificacoes funcionam com recursos reais instalados.
- [ ] **B07** Toda acao relevante e validada server-side (entidade, jogador, preco, distancia, estoque, bucket, sessao).
- [ ] **B08** Concorrencia/duplicacao de evento/sessao expirada sao rejeitadas.
- [ ] **B09** Journal duravel, idempotencia, compensacao e recuperacao financeira passam por testes de falha.
- [ ] **B10** Desconexao/restart/reconexao e corrupcao de armazenamento falham de modo seguro.
- [ ] **B11** IA trata HTTP malformado, timeout, prompt injection e indisponibilidade.
- [ ] **B12** NUI recupera controle em falhas e nao produz confirmacoes duplicadas.
- [ ] **B13** Consumo de recursos e concorrencia sao medidos, sem vazamentos graves.
- [ ] **B14** Ausencia de chaves, credenciais e arquivos sensiveis nos arquivos versionados.

## C. Matriz de testes e homologacao

- [ ] **C01** Testes de economia e interpolacao aprovados com assercoes e evidencias.
- [ ] **C02** Testes deterministas/estatisticos cobrem probabilidades e Plus rara.
- [ ] **C03** Testes de combo, variacao de estoque e totais aprovados.
- [ ] **C04** Testes de sessoes, estado de NPC e eventos adulterados aprovados.
- [ ] **C05** Testes de HTTP/IA/fallback e limitadores aprovados.
- [ ] **C06** Testes NUI em navegador: scroll, chat, cancelamento, falhas, foco e resolucoes.
- [ ] **C07** Testes financeiros adversariais, reinicios e compensacao aprovados.
- [ ] **C08** Resource inicia em FXServer Qbox com dependencias reais, sem erros impeditivos.
- [ ] **C09** Testes reais no FiveM demonstram pedestres ambientais, trocas, animacoes, policia e confrontos.
- [ ] **C10** Testes multiplayer confirmam exclusao mutua e transacoes sem duplicacao.
- [ ] **C11** resmon/profiler documenta desempenho sob carga representativa.
- [ ] **C12** Falhas criticas e regressivas identificadas foram corrigidas e retestadas.

## D. Entrega e integridade

- [ ] **D01** `fxmanifest.lua`, codigo Lua client/server/shared, NUI e configuracoes completos.
- [ ] **D02** Instalacao Qbox, itens, banco, dispatch e IA documentados sem supor dependencias inexistentes.
- [ ] **D03** Matriz requisito -> implementacao -> teste -> evidencia preenchida e auditavel.
- [ ] **D04** ZIP instalavel e ZIP de projeto completo gerados e verificados.
- [ ] **D05** Licencas de dependencias e direitos de distribuicao verificados; nao incluir codigo de terceiros sem permissao.
- [ ] **D06** Relatorio final distingue implementado, teste local, integracao real e homologacao in-game.
- [ ] **D07** Nenhuma funcionalidade obrigatoria deixada como placeholder/TODO critico.
- [ ] **D08** Revisao final compara todos os itens de REQUISITOS.md e este gate, sem omissoes.

## Condicoes de desbloqueio

- Cada caixa somente deve ser marcada com evidencia: comando/teste, resultado, arquivo/log e ambiente.
- Um teste local pode aprovar o codigo da logica, mas nao autoriza marcar checks de gameplay Qbox/FiveM.
- Se faltar servidor, credenciais validas, inventario real ou dispatch: manter bloqueio explicito.
- Nao criar release/tag de V1 enquanto existir um check obrigatorio nao atendido.
- V2 somente para expansao futura, **nao** para implementar algo que ja era obrigatorio na V1.
