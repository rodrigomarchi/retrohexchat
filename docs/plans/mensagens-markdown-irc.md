# Mensagens IRC + Markdown - plano TDD

Data inicial: 2026-08-04

## Objetivo

Evoluir o conteudo das mensagens para suportar, de forma nativa e segura,
multiplos formatos:

- `irc`: formato atual, baseado em controles classicos de IRC/mIRC.
- `markdown`: novo formato rico, voltado a mensagens longas, codigo, listas,
  enfase, links e citacoes.
- `plain`: texto puro, sem semantica de formato.

O produto deve preservar a identidade retro/IRC da plataforma e, ao mesmo tempo,
abrir espaco para composicao moderna. A implementacao deve ser de nivel
produto completo, nao MVP: historico estavel, UX consistente, seguranca,
acessibilidade, testes, documentacao, migracao e validacao final.

## Principios de produto

1. Compatibilidade primeiro: nenhuma mensagem antiga pode mudar de significado
   visual. Mensagens sem metadado de formato devem ser tratadas como `irc`.
2. Formato por mensagem: o modo de composicao faz parte do conteudo salvo.
   Nao depender de preferencia global para reinterpretar historico.
3. Sem parser hibrido no primeiro desenho: uma mensagem e `irc`, `markdown` ou
   `plain`. Misturar IRC codes e Markdown na mesma mensagem cria ambiguidade de
   precedencia, seguranca e suporte.
4. Markdown seguro: HTML cru, scripts, `javascript:` e atributos perigosos
   devem ser removidos ou neutralizados antes de chegar ao DOM.
5. UX explicita: o usuario precisa saber em qual modo esta escrevendo, ter
   ferramentas certas para cada modo e conseguir prever o resultado quando usar
   Markdown.
6. Renderizacao barata: a lista de mensagens e virtualizada/streamed; qualquer
   renderizador novo precisa evitar custo excessivo por linha.
7. Texto visivel como fonte de verdade para busca, destaque, preview, reply,
   notificacoes e acessibilidade.

## Fora de escopo inicial

- Editor WYSIWYG completo.
- Suporte a HTML cru digitado pelo usuario.
- Imagens Markdown remotas renderizadas inline por padrao.
- Tabelas, checklists interativas, embeds ricos e Mermaid.
- Conversao automatica perfeita entre IRC e Markdown.
- Mudanca do default global para Markdown no primeiro rollout.

Esses itens podem virar fases futuras depois que o contrato base estiver estavel.

## Estado atual relevante

Arquivos principais a considerar durante a implementacao:

- `apps/retro_hex_chat/lib/retro_hex_chat/chat/formatter.ex`
  - Parser/renderizador atual de controles IRC/mIRC.
  - Deve continuar sendo a base do modo `irc`.
- `apps/retro_hex_chat/lib/retro_hex_chat/irc/escapes.ex`
  - Ajuda a representar escapes IRC de forma legivel em alguns fluxos.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_helpers.ex`
  - Caminho central de renderizacao HTML das mensagens.
  - Hoje combina formatter, linkify de URL e linkify de canais.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/message_row.ex`
  - Linha visual de mensagem.
  - Precisa receber/renderizar formato sem quebrar virtualizacao e estados.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/message_viewport.ex`
  - Viewport/stream das mensagens.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/composer.ex`
  - Entrada de mensagem e logica de envio.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/chat/formatting_toolbar.ex`
  - Controles atuais de formatacao IRC.
- `apps/retro_hex_chat_web/assets/js/hooks/paste*.js`
  - Fluxo de paste/multilinha. Precisa mudar no modo Markdown.
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/message.ex`
  - Schema de mensagem de canal.
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/private_message.ex`
  - Schema de mensagem privada.
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/service.ex`
  - Envio/edicao/delecao de mensagens privadas e possivelmente fluxos comuns.
- `apps/retro_hex_chat/lib/retro_hex_chat/irc/channels/server.ex`
  - Envio de mensagens de canal e aplicacao de modos/politicas.

Pontos de risco atuais:

- O historico nao tem `content_format`; sem esse campo, Markdown futuro poderia
  reinterpretar mensagens antigas.
- Busca, highlight, reply preview e notificacoes ainda dependem do texto bruto
  ou de strip IRC especifico.
- O paste atual tende a quebrar texto multilinha em varias mensagens, o que e
  ruim para blocos de codigo Markdown.
- O linkify atual precisa virar HTML-aware para nao alterar codigo, links ja
  existentes ou conteudo sanitizado.
- Canais com politica de strip de cores precisam ter comportamento definido para
  Markdown.

## Arquitetura alvo

### Modelo de dados

Adicionar metadado de formato nas tabelas de mensagens:

- `messages.content_format`, default `irc`, `NOT NULL`.
- `private_messages.content_format`, default `irc`, `NOT NULL`.
- Check constraint permitindo apenas `irc`, `markdown`, `plain`.

Campo recomendado para produto completo:

- `plain_content`, texto visivel/canonico da mensagem.

`plain_content` deve ser produzido no momento de salvar/editar a mensagem e
usado por:

- busca;
- highlight;
- reply preview;
- notificacoes;
- acessibilidade;
- indexacao futura.

Se `plain_content` for adiado por custo de migracao, isso deve ser registrado no
arquivo de progresso como desvio aceito, com alternativa temporaria testada.

### API de conteudo

Criar um modulo de fachada para isolar renderizacao e texto visivel:

```elixir
RetroHexChat.Chat.Content.render_html(content, format, opts \\ [])
RetroHexChat.Chat.Content.plain_text(content, format)
RetroHexChat.Chat.Content.preview(content, format, opts \\ [])
RetroHexChat.Chat.Content.validate(content, format, opts \\ [])
RetroHexChat.Chat.Content.extract_urls(content, format)
RetroHexChat.Chat.Content.strip_formatting(content, format)
```

Renderizadores internos:

- `RetroHexChat.Chat.Content.Irc`
  - Envolve o formatter atual.
  - Mantem paridade visual com o comportamento existente.
- `RetroHexChat.Chat.Content.Markdown`
  - Converte Markdown para HTML seguro.
  - Sanitiza HTML e URLs.
  - Gera texto puro consistente.
- `RetroHexChat.Chat.Content.Plain`
  - Escapa HTML e preserva quebras de linha.

Regra importante: nenhum LiveView/component deve decidir diretamente como
renderizar Markdown ou IRC. A decisao passa pela fachada.

### Markdown e sanitizacao

Escolha tecnica a validar antes da fase de codigo:

- Parser candidato: `MDEx`.
- Sanitizador candidato: `HtmlSanitizeEx` ou politica propria baseada em
  parser HTML seguro.

Politica obrigatoria:

- HTML cru do usuario nao deve ser renderizado como HTML confiavel.
- `script`, `style`, `iframe`, eventos `on*`, `javascript:`, `data:` perigoso e
  atributos desconhecidos devem ser bloqueados.
- Links externos devem receber `target="_blank"` e
  `rel="noopener noreferrer"`.
- Elementos permitidos inicialmente:
  - paragrafo;
  - quebra de linha;
  - strong/em/code/pre/blockquote;
  - listas ordenadas e nao ordenadas;
  - links;
  - headings pequenos, se aprovados visualmente;
  - strikethrough, se suportado sem extensao arriscada.
- Imagens Markdown devem ser desabilitadas ou renderizadas como link textual na
  primeira entrega completa.

### Fluxo de envio

O composer passa a enviar:

```elixir
%{
  content: "...",
  content_format: "markdown"
}
```

Fluxos impactados:

- mensagem de canal;
- mensagem privada;
- edicao;
- retry de mensagem pendente;
- reply;
- eventos PubSub/stream;
- persistencia local de draft, se existir;
- comandos slash.

Slash commands nao devem ser interpretados como Markdown. A parser de comandos
deve analisar o texto bruto antes de qualquer renderizacao. Mensagens normais
passam o `content_format` adiante.

### Politica de `+c` / strip formatting

Politica recomendada:

- `irc`: remover controles IRC e salvar/enviar texto sem formatacao.
- `markdown`: converter para texto puro visivel e salvar/enviar como `plain`.
- `plain`: manter como esta.

Justificativa: a semantica de canal que remove cores/formatacao deve continuar
removendo apresentacao, independentemente do formato de entrada. Isso evita que
Markdown burle canais configurados para texto simples.

Essa decisao precisa de teste especifico porque muda a superficie de produto.

### Renderizacao web

`ChatHelpers.format_content/2` deve ser substituido ou reduzido para chamar a
fachada de conteudo. A ordem correta para Markdown deve evitar alteracoes dentro
de blocos de codigo e links ja gerados:

1. Validar/normalizar conteudo.
2. Renderizar pelo formato escolhido.
3. Sanitizar HTML.
4. Aplicar enriquecimentos HTML-aware que ainda forem necessarios.
5. Entregar `Phoenix.HTML.safe()`.

Linkify de URLs e canais precisa ser consciente de HTML:

- nao transformar texto dentro de `code`, `pre`, `a`;
- nao criar link dentro de link;
- nao quebrar entidades HTML;
- preservar texto visivel para screen readers.

### Busca, highlight e preview

Toda feature que precisa comparar texto deve usar `plain_content` ou
`Content.plain_text/2`.

Casos obrigatorios:

- busca por palavra envolvida em Markdown: `**release**` deve encontrar
  `release`;
- highlight nao pode inserir markup dentro de HTML inseguro;
- reply preview deve mostrar texto legivel, nao fonte Markdown bruta;
- notificacoes devem usar texto visivel;
- copia de texto deve permitir diferenciar "source" e "plain text".

## UX/UI alvo

### Modo de composicao

Adicionar um seletor segmentado no composer:

- `IRC`
- `MD`
- `Plain`

Regras:

- Default inicial: `IRC`, preservando comportamento atual.
- O modo selecionado deve ficar visivel perto da toolbar.
- A preferencia do usuario pode ser persistida localmente, mas nunca deve
  reinterpretar mensagens antigas.
- Ao responder/editar, o modo deve seguir a mensagem original.

### Toolbar por modo

Modo `IRC`:

- Manter controles atuais de bold, italico, underline, cores, reset etc.
- Continuar gerando controles IRC/mIRC.

Modo `MD`:

- Bold: envolve selecao com `**`.
- Italic: envolve com `_`.
- Code inline: envolve com crase.
- Code block: gera bloco fenced.
- Quote: prefixa `>`.
- Lista: prefixa `-`.
- Link: cria `[texto](url)`.
- Preview: alterna entre escrita e visualizacao.

Modo `Plain`:

- Toolbar reduzida ou desabilitada.
- Manter comandos de anexo/copy/paste se existirem.

### Preview Markdown

Adicionar alternancia compacta:

- `Write`
- `Preview`

Regras:

- Preview usa o mesmo renderizador/sanitizador de producao.
- Preview nao deve enviar mensagem nem alterar o source.
- Erros de validacao aparecem junto ao composer de forma objetiva.
- Em mobile, preview deve ocupar a area do composer sem quebrar layout.

### Paste multilinha

No modo `IRC`:

- manter comportamento atual, salvo se testes existentes indicarem bug.

No modo `MD`:

- paste multilinha deve preservar o conteudo como uma unica mensagem por padrao.
- quando houver muitas linhas, oferecer acao secundaria para enviar linha a
  linha, se esse padrao ja existir no produto.

Casos obrigatorios:

- bloco de codigo fenced;
- lista;
- quote;
- texto com linhas em branco;
- URL em linha propria.

### Edicao

Ao editar mensagem:

- abrir no formato original;
- mostrar seletor de modo;
- mudar modo deve ser uma escolha explicita;
- quando o usuario troca de modo, oferecer conversao simples:
  - `IRC -> Plain`: strip IRC;
  - `Markdown -> Plain`: plain text;
  - `Plain -> IRC/MD`: manter texto, sem tentar enriquecer;
  - `IRC <-> Markdown`: nao converter automaticamente na primeira entrega.

### Menu de mensagem

Adicionar ou revisar acoes:

- copiar texto;
- copiar source;
- ver source, se houver espaco no produto;
- editar preservando formato;
- responder usando preview em texto visivel.

### Indicador visual de formato

Nao poluir a timeline com badges em toda mensagem. Recomendacao:

- mostrar formato em tooltip/menu de contexto;
- mostrar aviso apenas em casos especiais, como mensagem Markdown sanitizada com
  conteudo removido;
- em debug/admin, exibir formato explicitamente.

### Acessibilidade

- Conteudo renderizado deve ter ordem de leitura natural.
- Blocos de codigo devem preservar texto e contraste.
- Controles da toolbar precisam de label/tooltip.
- Preview Markdown deve ser navegavel por teclado.
- Nenhum texto pode estourar botoes, linha da mensagem ou composer em mobile.

## Estrategia TDD

Regra geral: cada fase de implementacao comeca com testes falhando que
descrevem o comportamento esperado. So depois vem codigo de producao.

Cada etapa deve registrar no arquivo de progresso:

- testes adicionados antes da implementacao;
- falha inicial observada;
- arquivos alterados;
- comandos de validacao;
- aprendizados;
- decisoes ou desvios aceitos.

### F0 - Plano e contrato

Entregaveis:

- este arquivo;
- arquivo de progresso/aprendizados;
- lista inicial de criterios de aceite.

Validacao:

- revisao do plano;
- nomes de fases e responsabilidades claros;
- sem alteracao de codigo de producao.

Aceite:

- plano descreve arquitetura, UX/UI, TDD, validacao e riscos;
- progresso tem estrutura pronta para diario por etapa.

### F1 - Contrato de conteudo

Testes primeiro:

- `Content.render_html/3` renderiza IRC com paridade ao formatter atual.
- `Content.render_html/3` renderiza Markdown basico:
  - bold;
  - italic;
  - inline code;
  - code block;
  - quote;
  - lista;
  - link.
- `Content.render_html/3` bloqueia XSS:
  - `<script>`;
  - `<img onerror=...>`;
  - `[x](javascript:alert(1))`;
  - HTML cru perigoso;
  - atributos `on*`.
- `Content.plain_text/2` retorna texto visivel para `irc`, `markdown` e
  `plain`.
- `Content.preview/3` corta texto sem quebrar HTML ou entidades.
- `Content.validate/3` rejeita formato desconhecido e conteudo acima do limite.
- `Content.strip_formatting/2` implementa a politica de strip para os tres
  formatos.

Validacao focada:

```bash
rtk mix test apps/retro_hex_chat/test/retro_hex_chat/chat/content_test.exs
rtk mix test apps/retro_hex_chat/test/retro_hex_chat/chat/formatter_test.exs
```

Aceite:

- API de conteudo existe e cobre os tres formatos.
- IRC atual nao regrediu.
- Markdown nunca entrega HTML inseguro.
- Texto puro e preview sao deterministas.

### F2 - Persistencia e schemas

Testes primeiro:

- migracao adiciona `content_format` em mensagens de canal.
- migracao adiciona `content_format` em mensagens privadas.
- default de mensagens antigas/sem campo e `irc`.
- changesets aceitam apenas `irc`, `markdown`, `plain`.
- inserts de canal salvam `content_format`.
- inserts de PM salvam `content_format`.
- edicao preserva formato quando ele nao e alterado.
- edicao atualiza `plain_content` quando conteudo muda.
- constraints do banco rejeitam formato invalido.

Validacao focada:

```bash
rtk mix test apps/retro_hex_chat/test/retro_hex_chat/chat/message_test.exs
rtk mix test apps/retro_hex_chat/test/retro_hex_chat/chat/private_message_test.exs
rtk mix test apps/retro_hex_chat/test/retro_hex_chat/chat/service_test.exs
```

Aceite:

- historico antigo continua interpretado como IRC.
- banco impede formato invalido.
- `plain_content`, se implementado nesta fase, fica sincronizado.

### F3 - Envio, broadcast e streams

Testes primeiro:

- `Channels.Server.send_message` aceita formato explicito.
- envio sem formato assume `irc`.
- canal com `+c` converte Markdown para `plain`.
- `Chat.Service.send_private_message` salva formato.
- reply carrega formato da mensagem original quando necessario.
- eventos PubSub incluem `content_format`.
- mensagens pendentes e retry preservam formato.
- edicao broadcasta formato atualizado.

Validacao focada:

```bash
rtk mix test apps/retro_hex_chat/test/retro_hex_chat/irc/channels/server_test.exs
rtk mix test apps/retro_hex_chat/test/retro_hex_chat/chat/service_test.exs
rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_test.exs
```

Aceite:

- todo caminho de envio suporta formato.
- compatibilidade com clientes/fluxos antigos mantida por default `irc`.
- politica de canal e aplicada antes de persistir/broadcastar.

### F4 - Renderizacao LiveView

Testes primeiro:

- `MessageRow` renderiza `irc` com HTML equivalente ao atual.
- `MessageRow` renderiza Markdown sanitizado.
- `MessageRow` renderiza plain com escape HTML.
- strip formatting visual usa texto puro.
- URL linkify nao altera `code`, `pre` ou `a`.
- channel linkify nao altera `code`, `pre` ou `a`.
- deleted/edited/reply preview continuam corretos.
- mensagens longas nao quebram layout basico.

Validacao focada:

```bash
rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/message_row_test.exs
rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/app/chat_helpers_test.exs
```

Aceite:

- renderizacao fica centralizada na fachada de conteudo.
- nenhum helper injeta HTML inseguro.
- timeline continua performatica e visualmente estavel.

### F5 - Composer, toolbar, paste e edicao

Testes primeiro:

- seletor `IRC | MD | Plain` aparece e altera modo ativo.
- toolbar muda comandos conforme modo.
- botoes Markdown inserem sintaxe correta na selecao.
- preview Markdown usa renderizador real.
- paste de bloco Markdown envia uma mensagem unica.
- modo IRC preserva comportamento de paste esperado.
- edicao abre no formato original.
- retry de mensagem pendente mantem formato original.
- mobile nao sobrepoe toolbar, preview e textarea.

Validacao focada:

```bash
rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/composer_test.exs
rtk make test.js.changed
rtk make e2e.smoke SURFACE=chat
```

Aceite:

- usuario consegue compor nos tres modos sem ambiguidade.
- Markdown tem preview confiavel.
- fluxo mobile e desktop nao quebra layout.

### F6 - Busca, highlight, URL catcher e copia

Testes primeiro:

- busca encontra texto visivel de Markdown.
- highlight nao quebra HTML renderizado.
- URL catcher identifica links Markdown.
- URL catcher ignora URLs em blocos de codigo se essa for a politica definida.
- copiar texto retorna plain text.
- copiar source retorna conteudo original.
- reply preview usa plain text.
- notificacao usa plain text.

Validacao focada:

```bash
rtk mix test apps/retro_hex_chat/test/retro_hex_chat/chat/search_test.exs
rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_test.exs
rtk make test.js.changed
```

Aceite:

- Markdown nao degrada busca, highlights, replies ou notificacoes.
- texto visivel e source tem contratos separados.

### F7 - Help, docs e i18n

Testes primeiro:

- strings novas aparecem nos arquivos de traducao quando aplicavel.
- help/documentacao mostra os tres modos.
- comandos/atalhos documentados batem com a UI real.

Validacao focada:

```bash
rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/help_test.exs
rtk make gettext.check
```

Aceite:

- usuario consegue descobrir o recurso dentro do produto.
- strings nao ficam hardcoded fora do padrao do projeto.

### F8 - Hardening, performance e gate final

Testes/validacoes:

- suite completa Elixir.
- suite JS.
- E2E smoke de chat.
- auditoria manual de XSS.
- teste manual mobile/desktop.
- teste com mensagens antigas.
- teste com canal `+c`.

Comandos finais:

```bash
rtk make ci
```

Aceite:

- `rtk make ci` verde.
- nenhum teste IRC existente removido para acomodar Markdown.
- mensagens antigas renderizam igual antes.
- XSS conhecido bloqueado.
- UX completa em desktop e mobile.
- progresso/aprendizados atualizado com decisao final de dependencias,
  validacoes e desvios.

## Criterios de aceite globais

1. Mensagens antigas sem `content_format` renderizam como `irc`.
2. Mensagens novas salvam `content_format`.
3. `irc`, `markdown` e `plain` tem renderizacao, plain text, preview e validacao
   cobertos por testes.
4. Markdown renderizado e sanitizado antes de chegar ao DOM.
5. Raw HTML perigoso e links perigosos nao executam.
6. Linkify de URL/canal nao altera blocos de codigo nem links ja existentes.
7. Search/highlight/reply/notification usam texto visivel.
8. Composer mostra modo ativo e toolbar correta.
9. Preview Markdown usa o mesmo pipeline de producao.
10. Paste multilinha em Markdown preserva blocos como uma mensagem por padrao.
11. Edicao preserva formato original.
12. Copy text e copy source tem comportamento separado.
13. Canais com strip formatting nao deixam Markdown passar como formatacao rica.
14. Desktop e mobile nao tem overflow, sobreposicao ou controles invisiveis.
15. Help/documentacao do produto cobre o recurso.
16. `rtk make ci` passa antes de considerar pronto.

## Decisoes pendentes

Essas decisoes devem ser fechadas e registradas no arquivo de progresso antes
ou durante F1:

1. Parser Markdown final.
2. Sanitizador final.
3. Lista exata de tags/atributos permitidos.
4. Politica final para imagens Markdown.
5. Limites de tamanho, linhas e profundidade de Markdown.
6. Persistir `plain_content` desde a primeira migracao ou calcular sob demanda
   temporariamente.
7. Expor modo Markdown para bots/admin/system messages ou apenas usuarios.
8. Persistencia da preferencia local de modo do composer.

## Rollout

1. Implementar atras de contrato de formato, com default `irc`.
2. Migrar banco adicionando campos com default seguro.
3. Liberar UI de modo para usuarios internos/teste, se houver feature flag.
4. Validar IRC historico, Markdown seguro e mobile.
5. Liberar para todos mantendo `IRC` como default inicial.
6. Observar erros de renderizacao, mensagens sanitizadas e desempenho da
   timeline.
7. Considerar default Markdown por usuario/canal apenas depois de estabilizar.

