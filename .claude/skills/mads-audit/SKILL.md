---
name: mads-audit
description: Audita o desenvolvimento do MADS StreetDeals contra o contrato e os 56 checks da V1. Use sob demanda antes de merge, homologacao e entrega; detecta codigo ausente, integracoes simuladas, riscos financeiros e testes sem evidencia.
disable-model-invocation: true
context: fork
effort: high
---

# Auditoria independente do StreetDeals

1. Verificar que esta no repositorio correto e ler **`REQUISITOS.md`**, **`CRITERIOS_DE_APROVACAO.md`**, **`CLAUDE.md`** e o estado de desenvolvimento registrado. Nao inventar novos requisitos nem dispensar os atuais.
2. Inspecionar a implementacao real e relacionar cada check `A01..A22`, `B01..B14`, `C01..C12`, `D01..D08` com caminhos de arquivos, codigos relevantes, comandos de teste e logs. Se nao houver evidencia, marcar como `NAO_VERIFICADO` ou `BLOQUEADO`, nunca `PASS`.
3. Validar especialmente: NPCs ambientais (nao so 12 peds fixos), um unico sorteio raro 1/1000 por abordagem elegivel, combos 1–4, tabela de policiais em servico, direcao do risco conforme scroll, LLM sem autoridade financeira, fallback, responsividade NUI, OneSync/entidade real, inventario e pagamentos idempotentes.
4. Executar apenas testes seguros e disponiveis, priorizando economia, probabilidades, concorrencia, seguranca, falhas HTTP, NUI, compensacao e regressao. Distinguir testes mockados, integracao Qbox real e homologacao in-game; nao afirmar ter executado o GTA se nao o fez.
5. Escrever ou atualizar **`AUDITORIA_FINAL.md`** e **`MATRIZ_TESTES.md`** com status, evidencia, bloqueio, severidade, reproducoes e acoes corretivas, sem reescrever o proprio codigo auditado durante esta etapa.
6. Reportar um resumo direto: total aprovado, pendente, bloqueado e reprovado; riscos criticos; top proximas correcoes. Manter release V1 bloqueada enquanto qualquer check obrigatorio estiver sem comprovacao.
7. Nao fazer `git commit`, `push`, merge, mudanca de versao ou release automaticamente.
