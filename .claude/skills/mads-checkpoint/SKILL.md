---
name: mads-checkpoint
description: Registra um checkpoint de desenvolvimento do MADS StreetDeals quando um modulo terminar, antes de compactar o contexto ou ao retomar uma tarefa longa. Mantem ESTADO_DESENVOLVIMENTO.md curto, rastreavel e fiel ao Git e aos testes realmente executados.
effort: low
---

# Checkpoint enxuto do MADS StreetDeals

1. Trabalhar exclusivamente na raiz do projeto `MADS-Streetdeals-Fivem`. Usar `CLAUDE.md`, `REQUISITOS.md` e `CRITERIOS_DE_APROVACAO.md` como referencias, lendo somente os trechos necessarios ao checkpoint.
2. Executar `git status --short`, `git diff --stat` e os comandos de testes pertinentes que ja existirem. Ler resultados atuais; nao inventar testes, commits, arquivos nem aprovacoes.
3. Atualizar **`ESTADO_DESENVOLVIMENTO.md`** com seis secoes curtas: (a) modulo/objetivo atual; (b) concluido com caminhos reais; (c) testes e evidencias; (d) pendencias/bloqueios; (e) riscos e decisoes; (f) proxima acao especifica, com arquivo ou comando previsto.
4. Marcar requisitos como **implementados** apenas se houver codigo; como **testados** apenas se houver execucao verificavel; como **homologados** apenas com evidencia de FXServer/Qbox/FiveM real. Nao modificar a lista de requisitos nem o gate de aprovacao para facilitar progresso.
5. Preservar informacoes de continuidade essenciais, remover repeticoes e evitar reproduzir o comando mestre ou historicos extensos. Preferir apontar links para os documentos de requisitos.
6. Nunca fazer `git add`, `commit`, `push`, exclusoes ou alteracoes no core Qbox sem uma instrucao separada. Reportar em poucas linhas o que foi atualizado e o proximo passo.
