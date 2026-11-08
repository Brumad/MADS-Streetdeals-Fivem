# MADS StreetDeals

Resource FiveM de negociacao imersiva com NPCs ambientais, conversas em portugues, precos dinamicos, risco policial e resultados variados. **Destino exclusivo deste desenvolvimento: Qbox (qbx_core)** com as dependencias efetivamente verificadas na instalacao. Nao e um projeto Creative vRP, ESX ou QBCore tradicional.

> **Estado: planejamento e contrato de desenvolvimento.** Este repositorio ainda nao contem o resource implementado. Nao anunciar V1 final antes dos testes e da homologacao descritos em [CRITERIOS_DE_APROVACAO.md](CRITERIOS_DE_APROVACAO.md).

## Objetivo

Permitir que jogadores abordem pedestres comuns elegiveis pelo mapa do GTA V e negociem a venda de mercadorias ficticias de RP em conversas por texto. O preco, o humor e o perfil individual do NPC, o local, o estoque e o numero de policiais em servico influenciam o resultado.

O produto contempla seis comportamentos: recusa simples; recusa com denuncia; negociacao simples com contrapropostas; negociacao Plus rara (1 em 1.000 abordagens elegiveis, pagando 5x a 10x a referencia do evento); negociacao Plus Combo (1 a 4 pacotes); e confronto fisico. A modalidade Combo deve ser mais frequente que a rara.

## Referencia economica

- Valor-base: **$2.000 por pacote**; cada pacote representa cinco unidades da mercadoria.
- Referencia historica de balanceamento: aproximadamente $120 por unidade avulsa, $600 por cinco unidades e $5.000 por roubo de caixa eletronico.
- Policiais **em servico**: 0=0,5x; 4=1x; 6=1,5x; 8 ou mais=2x. Valores intermediarios por interpolacao configuravel.
- A oferta e ajustada pelo scroll: desconto tende a reduzir risco e favorecer aceitacao; sobrepreco tende a aumentar dificuldade e possibilidade de denuncia.
- A regra inicial proposta para o evento raro usa o valor-base sem aplicar o multiplicador policial uma segunda vez; deixar parametrizavel, registrar que esta e uma decisao de balanceamento proposta.

## Tecnologias previstas

Lua/CfxLua, FiveM FXServer/OneSync, Qbox, NUI em HTML/CSS/JavaScript, integracoes verificadas com ox_lib/ox_inventory/ox_target quando correspondentes a instalacao real, banco de dados quando necessario e IA HTTP server-side opcional com fallback local. O servidor e autoritativo para sorteios, estoque, validacoes e dinheiro.

## Documentos obrigatorios

- [CLAUDE.md](CLAUDE.md) — instrucoes permanentes de execucao para Claude Code.
- [REQUISITOS.md](REQUISITOS.md) — contrato integral de escopo e regras de negocio.
- [CRITERIOS_DE_APROVACAO.md](CRITERIOS_DE_APROVACAO.md) — verificacoes e bloqueio de encerramento da V1.
- [.gitignore](.gitignore) — arquivos e segredos que nao devem entrar no Git.

## Inicio com Claude Code

1. Clone o repositorio e abra a pasta no Claude Code.
2. Instrua o Claude a ler **CLAUDE.md, REQUISITOS.md e CRITERIOS_DE_APROVACAO.md** antes de escrever codigo.
3. Verifique APIs atuais e as dependencias realmente instaladas; gere codigo e testes reais, nao so um plano.
4. Registre progresso duravel e faca commits por modulo testavel. Nao publique tags de release ate passar o gate.
5. Homologue no FXServer/Qbox e no FiveM; nenhum teste mockado comprova funcionamento no jogo.

## Distribuicao

Repositorio atualmente publico. **Nao commitar** API keys, identificadores privados de servidor, arquivos de ambiente, bancos de dados, dumps nem dados de jogadores. Definir uma licenca de distribuicao antes de liberar a V1 publicamente. Sem arquivo de licenca, nao assumir permissao automatica para reutilizar codigo de terceiros.

## Versionamento

A primeira entrega aprovada sera a **V1 completa**. Fases internas e correcoes de bugs nao criam V2; V2 fica reservada a expansoes futuras decididas depois da homologacao.
