# IA e segurança

## Separação IA × economia (R05.2, R05.7)
O servidor decide tudo (`core/negotiation.lua`, `core/economy.lua`). A IA recebe a **decisão já tomada** e só:
1. escreve uma fala curta em pt-BR; 2. sugere uma *intenção* da whitelist (`chat, polite, provoke, threat, discount, premium, bye`).
A intenção só altera **humor/paciência** (`negotiation.apply_intent`); nunca preço, aceite, estoque ou dinheiro.

## Contrato e validação (`core/ai.lua`)
Resposta exigida: `{"reply":"...","intent":"..."}`. Rejeitadas (→ fallback local): JSON malformado, sem `reply`,
> 260 chars, **valores monetários não autorizados** (só os calculados pelo servidor são permitidos), vazamento de
instruções / quebra de personagem. Texto do jogador entra como **dado JSON** (`mensagem_do_jogador`), truncado a 400 chars.

## Custos e disponibilidade
Limites por jogador/min, global/min, requisições/dia, `max_tokens`, timeout (6 s, resposta tardia ignorada) e
**circuit breaker** (N falhas → pausa 60 s, sem spam de HTTP). Sem chave/endpoint → fallback local, sinalizado na NUI
como `local` (nunca como IA).

## Segredos
A chave vem de `set mads_sd_ai_key` (convar de servidor, não replicada). Não está no git, no cliente, na NUI nem nos logs.
**Provedores `anthropic` e `openai`: formato conforme documentação pública, NÃO testado com chamada real** (sem chave aqui).

## Segurança financeira (`core/ledger.lua`, `server/journal_store.lua`)
Intenção gravada **antes** de cada ação externa; chave idempotente `sessão:acordo`; estados ambíguos → `needs_review`
(nunca repetidos). **Não há atomicidade entre ox_inventory e qbx_core**; a garantia é: sem pagamento duplicado, sem item
duplicado, nada perdido em silêncio. Se o jogador sair no meio e o pagamento ficar ambíguo, o caso vai para revisão manual.

## Peds locais
Peds sem `netId` não podem ser validados pelo servidor (modo degradado, `allowUnverifiedLocalPeds`): exposição limitada por
cooldown (citizenid), exclusão mútua aproximada por posição, distância do jogador (posição do servidor) e porque preço,
estoque e pagamento são sempre do servidor. Desative a opção para exigir entidades de rede.
