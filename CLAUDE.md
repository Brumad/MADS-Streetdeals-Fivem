# Instrucoes permanentes — Claude Code / MADS StreetDeals

Leia este arquivo e depois **REQUISITOS.md** e **CRITERIOS_DE_APROVACAO.md** por completo antes de editar codigo. Esses documentos sao a fonte de verdade do projeto. Se houver conflito, preserve o requisito explicito do usuario e registre a divergencia antes de fazer alteracoes irreversiveis.

## Missao

Construir **do zero** um resource FiveM chamado `mads_streetdeals`, com todas as funcionalidades previstas. Framework de integracao de producao: **Qbox / qbx_core somente**. Nao criar adaptadores Creative vRP, ESX ou QBCore tradicional. Uma pessoa informou que outra cidade usa "standalone"; isso **nao** demonstra compatibilidade do nosso resource Qbox com essa cidade e nao autoriza ampliar o escopo.

## Execucao: programar, nao apenas planejar

1. Verificar documentacao atual e, sempre que disponivel, os arquivos reais de Qbox, OneSync, ox_lib, ox_inventory, ox_target, dispatch e sistema financeiro da instalacao-alvo. Nao inventar exports, eventos, APIs ou assinaturas.
2. Elaborar arquitetura modular curta e em seguida produzir **arquivos Lua, NUI, configuracoes, testes e documentacao reais**.
3. Trabalhar em **grandes blocos integrados** com resultados verificaveis; avancar automaticamente ate produzir os artefatos de entrega, **sem pedir confirmacao entre modulos** (perguntas como "quer que eu continue?" sao proibidas). Interromper somente por impedimento real que exija acao do usuario.
4. Apos cada fase registrar o estado em `ESTADO_DESENVOLVIMENTO.md` e atualizar matriz de requisitos/testes (arquivos a criar). Associar requisito -> implementacao -> teste -> evidencia.
5. Preferir **poucos commits grandes e substanciais** (por bloco integrado, ou um unico commit do resource completo), nunca um commit por modulo pequeno nem commits isolados so para ajustar instrucoes; nao apagar codigo funcional para recomecar sem justificativa. Jamais sobrescrever trabalho existente silenciosamente.
6. Quando houver duas tentativas iguais sem progresso, parar, identificar causa e mudar estrategia. Nao alegar execucao em background.
7. Quando nao houver ferramenta/servidor/chave de API disponivel, entregar o que de fato foi desenvolvido, registrar precisamente o bloqueio e a proxima acao. **Nao inventar resultado de teste.**

## Prioridade de entrega (preferencia atual do usuario)

Meta: entregar o resource completo e instalavel (`MADS_StreetDeals_Qbox.zip`) e o projeto completo (`MADS_StreetDeals_Projeto_Completo.zip`). Implementar e testar antes de produzir relatorios extensos; nao repetir pesquisas/testes ja aprovados sem mudanca relevante; usar a skill `mads-checkpoint` so para preservar continuidade, nunca como ponto de parada. Entregar o ZIP **nao** e homologacao: a V1 so e aprovada com os 56 checks comprovados.

## Fronteiras tecnicas

- **Nucleo autoritativo server-side:** determina sessao, elegibilidade, probabilidade, orcamento, oferta validada, quantidade, risco, inventario e recompensa. Nunca confiar em dados financeiros enviados pela NUI/cliente.
- **IA somente para linguagem:** o LLM pode formular conversas e interpretar intencoes dentro de um contrato estruturado; nao autoriza vendas, item, dinheiro, porcentagens ou sorteio. Credenciais apenas no servidor, nunca no repositorio nem no cliente. Fallback local funcional, claramente distinguido de IA externa.
- **NPCs ambientais:** funcionalidade central. Nao substituir por lista de 12 compradores fixos. Tratar OneSync, network IDs, entities que so existem localmente, exclusao de ped controlado por outros resources, distancia, bucket, morte/despawn e concorrencia com medidas verificaveis; nao presumir que o servidor consegue validar qualquer ped local.
- **Seguranca financeira:** estoque e pagamento mediante operacoes validadas, idempotentes e registradas; compensacao e recuperacao explicitas. Nao prometer atomicidade entre recursos sem garantias demonstradas.
- **Framework:** Qbox unicamente. Detectar as dependencias reais antes de integra-las; nao presumir dispatch unico. Manter camada Qbox concentrada para que o motor de gameplay nao dependa de chamadas dispersas.
- **Desempenho:** evitar varredura global permanente de pedestres, threads excessivas, spam de HTTP e vazamento de sessoes; medir com ferramentas apropriadas.

## Regras de qualidade

Nao substituir requisitos por placeholders, TODOs em caminhos criticos, mocks de producao, frases que simulam resultados, UI decorativa sem backend ou testes sem assercoes relevantes. Preferir interface NUI legivel, responsiva, com mouse/teclado, scroll, chat, estados de loading, erro e cancelamento.

Testes unitarios com mocks sao uteis, mas **nao** equivalem a integracao real com Qbox ou homologacao no GTA. Marcar evidencias de forma diferenciada: implementado, teste local, integracao verificada, homologacao in-game aprovada.

Nao chamar o projeto de **V1 final** ate passar **todos os checks** de CRITERIOS_DE_APROVACAO.md. Corrigir bugs sem criar V2.

## Ordem sugerida

1. Inspecao das APIs e arquitetura.
2. Motor economico/probabilistico e testes.
3. NPCs ambientais, perfis e sessoes.
4. Dialogo IA + fallback e NUI.
5. Modos de negociacao, denuncia, combate e animacoes.
6. Integracoes Qbox (inventario, dinheiro, policia e dispatch).
7. Seguranca, journal/reconciliacao e tests adversariais.
8. Integracao real, desempenho, auditoria e empacotamento.

O passo seguinte a um plano deve ser **codificar**; nao produzir rodadas sucessivas de planejamento.

## Arquivos de acompanhamento a criar durante a execucao

`ESTADO_DESENVOLVIMENTO.md`, `ARQUITETURA.md`, `MATRIZ_TESTES.md`, `AUDITORIA_FINAL.md`, `INTEGRACAO_QBOX.md`, `HOMOLOGACAO_FXSERVER.md`, `INSTALACAO.md`, `CONFIGURACAO.md`, `IA_E_SEGURANCA.md`. Sao entregaveis de execucao, **nao** pretexto para marcar implementacao antes de existir codigo.

Ao final fornecer ZIP instalavel, ZIP com codigo/testes/docs e relatorio de status fiel as evidencias.
