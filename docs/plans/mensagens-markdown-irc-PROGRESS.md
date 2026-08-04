# Mensagens IRC + Markdown - progresso e aprendizados

Este arquivo registra o andamento da implementacao de mensagens com formatos
`irc`, `markdown` e `plain`.

Atualizar este diario ao final de cada etapa e tambem sempre que uma decisao
tecnica relevante for tomada. O objetivo e manter rastreabilidade: o que foi
testado primeiro, o que quebrou, como foi validado e o que aprendemos.

Plano principal: `docs/plans/mensagens-markdown-irc.md`

## Status

| Fase | Estado | Ultima atualizacao | Observacoes |
| --- | --- | --- | --- |
| F0 - Plano e contrato | Concluida | 2026-08-04 | Plano TDD e diario criados. |
| F1 - Contrato de conteudo | Concluida | 2026-08-04 | Fachada `Content` com IRC/Markdown/Plain e testes focados verdes. |
| F2 - Persistencia e schemas | Concluida | 2026-08-04 | Migracao/schemas feitos; `rtk make ci` verde. |
| F3 - Envio, broadcast e streams | Concluida | 2026-08-04 | Formato propagado em canal, PM, edit, payloads PubSub e stream items. |
| F4 - Renderizacao LiveView | Concluida | 2026-08-04 | Timeline renderiza Markdown pelo facade `Content`; fallback IRC preservado. |
| F5 - Composer, toolbar, paste e edicao | Concluida | 2026-08-04 | Seletor IRC/MD/TXT, toolbar por modo, preview Markdown, paste Markdown e edicao preservando formato. |
| F6 - Busca, highlight, URL catcher e copia | Pendente | - | Usar texto visivel/source nos lugares corretos. |
| F7 - Help, docs e i18n | Parcial | 2026-08-04 | Help inicial de formatos atualizado; i18n/catalogos completos ficam para F7. |
| F8 - Hardening e gate final | Pendente | - | Rodar validacoes completas e registrar resultado. |

## Como registrar cada etapa

Para cada fase, adicionar uma entrada com:

- data;
- escopo atacado;
- testes escritos antes da implementacao;
- falha inicial observada;
- implementacao feita;
- validacao rodada;
- resultado;
- aprendizados;
- decisoes ou desvios aceitos.

Modelo:

```md
### YYYY-MM-DD - Fase X: nome

Escopo:
- ...

Testes primeiro:
- ...

Falha inicial:
- ...

Implementacao:
- ...

Validacao:
- `rtk ...`

Resultado:
- ...

Aprendizados:
- ...

Decisoes/desvios:
- ...
```

## Checklist geral

- [x] Ler instrucoes do repositorio.
- [x] Mapear o pipeline atual de mensagens IRC.
- [x] Criar plano TDD do recurso completo.
- [x] Criar diario de progresso/aprendizados.
- [x] Fechar escolha de parser Markdown.
- [x] Fechar escolha de sanitizador.
- [ ] Definir whitelist final de HTML.
- [x] Escrever testes da fachada de conteudo.
- [x] Implementar fachada de conteudo.
- [x] Adicionar migracoes e schema changes.
- [x] Propagar formato nos fluxos de envio.
- [x] Integrar renderizacao LiveView.
- [x] Implementar UX do composer por modo.
- [x] Ajustar paste multilinha.
- [ ] Ajustar busca/highlight/reply/copy.
- [ ] Atualizar help/i18n.
- [x] Rodar `rtk make ci`.

## Entradas

### 2026-08-04 - F0: plano e contrato

Escopo:
- Criar a especificacao inicial para suportar mensagens `irc`, `markdown` e
  `plain`.
- Definir fases TDD, validacoes e criterios de aceite.
- Criar este diario para registrar progresso e aprendizados.

Testes primeiro:
- Nao se aplica nesta fase; a entrega e documental.
- O plano principal define os testes que devem ser escritos antes de cada fase
  de codigo.

Falha inicial:
- A plataforma tem renderizacao IRC madura, mas nao possui contrato explicito de
  formato por mensagem.
- Sem `content_format`, qualquer suporte global a Markdown arriscaria
  reinterpretar historico antigo.

Implementacao:
- Criado `docs/plans/mensagens-markdown-irc.md`.
- Criado `docs/plans/mensagens-markdown-irc-PROGRESS.md`.

Validacao:
- Arquivos criados no diretorio de planos do projeto.
- Revisao manual do conteudo do plano.

Resultado:
- F0 concluida.
- Proxima fase tecnica: F1 - contrato de conteudo.

Aprendizados:
- O pipeline atual ja tem um ponto forte: existe um formatter IRC central que
  deve ser preservado e envolvido, nao substituido.
- O maior risco de produto e misturar renderizacao nova com historico antigo sem
  metadado persistido.
- O maior risco de seguranca e Markdown sem sanitizacao estrita.
- O maior risco de UX e tratar paste Markdown como varias mensagens, quebrando
  blocos de codigo e listas.
- O maior risco de performance e renderizar Markdown caro diretamente em cada
  linha da timeline sem cache/contrato claro.

Decisoes/desvios:
- Decisao inicial: nao implementar parser hibrido IRC+Markdown na primeira
  versao.
- Decisao inicial: default de mensagens antigas e novas sem formato sera `irc`.
- Decisao inicial: canais que removem formatacao devem converter Markdown para
  texto puro.

### 2026-08-04 - F1: contrato de conteudo

Escopo:
- Criar `RetroHexChat.Chat.Content` como fachada de dominio para conteudo
  format-aware.
- Adicionar renderizadores internos para `irc`, `markdown` e `plain`.
- Cobrir renderizacao, texto visivel, preview, validacao, strip formatting e
  extracao de URLs.

Testes primeiro:
- Criado `apps/retro_hex_chat/test/retro_hex_chat/chat/content_test.exs`.
- A primeira execucao falhou com 17 falhas por modulo/funcoes inexistentes,
  confirmando o contrato antes da implementacao.

Falha inicial:
- `RetroHexChat.Chat.Content` ainda nao existia.
- Nenhum ponto de dominio expunha renderizacao multi-formato.

Implementacao:
- Adicionado `MDEx` como parser Markdown em `apps/retro_hex_chat/mix.exs`.
- Criado `apps/retro_hex_chat/lib/retro_hex_chat/chat/content.ex`.
- Criados renderizadores:
  - `content/irc.ex`;
  - `content/markdown.ex`;
  - `content/plain.ex`.
- Markdown usa sanitizacao do `MDEx` e pos-processamento para links de chat com
  `target="_blank"`, `rel="noopener noreferrer"` e `class="chat-link"`.
- Imagens Markdown sao reescritas como links textuais nesta primeira entrega de
  dominio, evitando `<img>` inline.

Validacao:
- `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/chat/content_test.exs`
- `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/chat/formatter_test.exs`
- `rtk make ci`

Resultado:
- `content_test.exs`: 17 testes, 0 falhas.
- `formatter_test.exs`: 56 testes + 3 properties, 0 falhas.
- Primeira execucao de `rtk make ci` falhou em um teste P2P de feature
  aparentemente intermitente e sem relacao com a mudanca de conteudo.
- O teste P2P isolado passou em seguida.
- Segunda execucao de `rtk make ci`: 13/13 checks passaram, incluindo
  dialyzer.

Aprendizados:
- `MDEx` resolve bem a base CommonMark e ja traz uma camada de sanitizacao
  conservadora.
- A dependencia usa `rustler_precompiled`; na primeira compilacao baixou o NIF
  precompilado e depois reutilizou o cache local.
- A fachada permite manter o formatter IRC intacto e testado por paridade.
- Texto visivel de Markdown fica simples com `MDEx.to_delta!/2`, evitando strip
  manual de HTML.

Decisoes/desvios:
- Decisao: parser Markdown inicial sera `MDEx`.
- Decisao: sanitizacao inicial sera a politica padrao do `MDEx`, com ajuste de
  `link_rel`.
- Decisao: imagens Markdown nao renderizam inline; viram links textuais.
- Desvio aceito: a whitelist final ainda sera refinada em F4/F8 quando o HTML
  entrar na timeline real.

### 2026-08-04 - F2: persistencia e schemas

Escopo:
- Persistir `content_format` em mensagens de canal e PM.
- Criar `plain_content` como cache de texto visivel para writes novos.
- Garantir defaults/constraints de banco para historico e insercoes legadas.
- Atualizar reply previews para usar texto visivel.

Testes primeiro:
- Expandidos os testes de `Message`, `PrivateMessage`, `Queries`,
  `QueriesPm` e `Service`.
- Cobertura adicionada para:
  - default `content_format = "irc"`;
  - formatos aceitos `irc`, `markdown`, `plain`;
  - rejeicao de formato invalido;
  - `plain_content` calculado pelo servidor;
  - caller nao conseguir forjar `plain_content`;
  - constraints de banco presentes;
  - insert raw legado herdando default `irc`;
  - edit recomputando `plain_content`;
  - reply preview usando texto visivel de Markdown em canal e PM.

Falha inicial:
- A primeira execucao falhou em compilacao com `KeyError` para
  `:content_format` nos structs, confirmando que os testes chegaram antes dos
  campos de schema.

Implementacao:
- Criada migracao
  `apps/retro_hex_chat/priv/repo/migrations/20260804125000_add_message_content_formats.exs`.
- Adicionados em `messages` e `private_messages`:
  - `content_format`, default `irc`, `NOT NULL`;
  - `plain_content`, nullable;
  - check constraints para `irc`, `markdown`, `plain`.
- Atualizados `Message` e `PrivateMessage`:
  - campo `content_format`;
  - campo `plain_content`;
  - casts de formato;
  - validacao de inclusao;
  - calculo de `plain_content` via `RetroHexChat.Chat.Content`;
  - `plain_content` nao e aceito de attrs externos.
- Atualizado `Chat.Service` para reply previews usarem `plain_content` quando
  disponivel, com fallback por `Content.preview/3`.

Validacao:
- `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/chat/message_test.exs apps/retro_hex_chat/test/retro_hex_chat/chat/private_message_test.exs apps/retro_hex_chat/test/retro_hex_chat/chat/queries_test.exs apps/retro_hex_chat/test/retro_hex_chat/chat/queries_pm_test.exs apps/retro_hex_chat/test/retro_hex_chat/chat/service_test.exs`
- `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/chat/content_test.exs apps/retro_hex_chat/test/retro_hex_chat/chat/formatter_test.exs apps/retro_hex_chat/test/retro_hex_chat/chat/message_test.exs apps/retro_hex_chat/test/retro_hex_chat/chat/private_message_test.exs apps/retro_hex_chat/test/retro_hex_chat/chat/queries_test.exs apps/retro_hex_chat/test/retro_hex_chat/chat/queries_pm_test.exs apps/retro_hex_chat/test/retro_hex_chat/chat/service_test.exs`

Resultado:
- F2 focado: 103 testes, 0 falhas.
- F1+F2 focado: 176 testes/properties, 0 falhas.
- `rtk make ci`: 13/13 checks passaram, incluindo dialyzer.

Aprendizados:
- `plain_content` deve ser servidor-owned. Aceitar valor vindo de attrs abriria
  divergencia entre source e texto visivel.
- `plain_content` nullable preserva compatibilidade com caminhos `insert_all`
  existentes e historico antigo; writes via changeset ja ficam preenchidos.
- Reply preview e um ponto onde Markdown poderia vazar source cru rapidamente;
  corrigir agora evita retrabalho nas fases de UI.

Decisoes/desvios:
- Decisao: `content_format` e obrigatorio no banco e sempre defaulta para
  `irc`.
- Decisao: `plain_content` entra agora, mas nullable.
- Decisao: backfill perfeito de `plain_content` historico fica para uma fase de
  migracao dedicada se a busca passar a depender exclusivamente da coluna.

### 2026-08-04 - F3: propagacao por envio, PubSub e streams

Escopo:
- Fazer `content_format` atravessar os caminhos reais de envio de mensagens de
  canal e PM.
- Publicar `content_format` nos eventos PubSub de nova mensagem e edicao.
- Garantir que read-models/stream items do LiveView recebam o formato, com
  fallback `irc` para linhas legadas e mensagens locais.
- Alinhar o caminho direto do `Channels.Server`, que persistia mensagens fora do
  `Chat.Service`.

Testes primeiro:
- Expandidos testes de `Chat.Service` para:
  - envio de canal com `content_format: "markdown"`;
  - broadcast `new_message` com formato;
  - envio de PM com Markdown persistido e broadcast `new_pm`;
  - broadcast de edicao de canal/PM preservando formato persistido.
- Expandidos testes de `Channels.Server` para:
  - formato default `irc` no payload e na persistencia;
  - envio Markdown via opts;
  - reply preview usando texto visivel do parent Markdown;
  - modo `+c` convertendo Markdown para texto plano e persistindo
    `content_format: "plain"`.
- Expandidos testes de helper de mensagens para stream item legado defaultar
  `content_format: "irc"` e item Markdown preservar `content_format`.

Falha inicial:
- Os testes focados falharam em nove pontos no app core e dois no web:
  - `Chat.Service` ignorava `content_format` dos opts;
  - payloads `new_message`, `new_pm` e `message_edited` nao continham formato;
  - `Channels.Server` persistia sempre como default `irc`;
  - reply preview no servidor usava Markdown bruto;
  - `+c` removia apenas codigos IRC e mantinha Markdown source;
  - stream items nao tinham fallback nem propagacao de formato.

Implementacao:
- `Chat.Service` agora:
  - normaliza `opts[:content_format]`;
  - valida conteudo pelo facade `Content`;
  - grava `content_format` em canal e PM;
  - valida edicoes pelo formato persistido da mensagem;
  - publica `content_format` em `new_message`, `new_pm` e `message_edited`.
- `Channels.Server` agora:
  - aceita API compativel `send_message/4` e nova forma `send_message/5`;
  - normaliza `opts[:content_format]`;
  - valida conteudo pelo facade `Content`;
  - persiste `content_format`;
  - inclui `content_format` no payload PubSub;
  - calcula reply preview por `plain_content`/`Content.preview`;
  - aplica `+c` como politica de texto visivel, convertendo resultado para
    formato `plain`.
- Read-models do LiveView agora incluem `content_format` em:
  - helper de canal;
  - helper de PM;
  - handler PubSub de PM;
  - carregamento incremental em `CoreEvents`;
  - mensagens otimistas;
  - mensagens locais de sistema, erro, servico e notice.

Validacao:
- `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/chat/service_test.exs apps/retro_hex_chat/test/retro_hex_chat/channels/server_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/helpers/messages_test.exs`

Resultado:
- Bateria focada F3: 147 testes, 0 falhas.
- Primeira execucao de `rtk make ci`: 10/13 checks passaram; falhou em um teste
  P2P de reattach e em um teste RSS HTTP. Ambos passaram isolados em seguida,
  indicando falhas intermitentes/concorrencia de suite sem relacao direta com a
  mudanca de formato.
- Segunda execucao de `rtk make ci`: testes e feature tests passaram; Dialyzer
  apontou uma clausula de fallback impossivel em `Channels.Server.preview_for/1`.
- Terceira execucao de `rtk make ci`: 13/13 checks passaram, incluindo Dialyzer.

Aprendizados:
- `Channels.Server` e `Chat.Service` tinham contratos quase paralelos para
  mensagens de canal; Markdown precisa manter esses dois caminhos sincronizados
  enquanto o servidor de canal continuar persistindo diretamente.
- `+c` deixa de ser apenas uma politica de cores quando ha multiplos formatos:
  no produto completo ele significa "timeline sem formatacao visual", portanto
  precisa produzir `plain`.
- Reply preview e broadcasts de edicao sao pontos de vazamento rapido de
  Markdown source; testar esses pontos evita que a UI tenha que adivinhar
  formato depois.
- Dialyzer ajudou a remover fallback generico que parecia defensivo, mas era
  impossivel para o tipo real retornado por `Chat.Queries.get_message/1`.

Decisoes/desvios:
- Decisao: `content_format` entra em todo payload persistido/reidratado e nos
  mapas locais com fallback `irc`.
- Decisao: edicao preserva o formato persistido; troca de formato durante edicao
  fica para a fase de UX/composer, se o produto decidir expor isso.
- Decisao: capturas de URL, highlight e renderizacao visual ainda ficam em fases
  posteriores; F3 limita-se ao contrato de transporte e stream.

### 2026-08-04 - F4: renderizacao format-aware na timeline

Escopo:
- Fazer a timeline renderizar Markdown quando `content_format` for `markdown`.
- Preservar compatibilidade do renderer IRC existente para linhas sem formato
  explicito.
- Manter a preferencia global de "strip formatting" funcionando tambem para
  Markdown.

Testes primeiro:
- Expandidos testes de `ChatHelpers` para:
  - `format_content/3` renderizar Markdown com `<strong>` e links seguros;
  - strip de Markdown produzir texto visivel sem `<strong>`/`<a>`;
  - Markdown sanitizar HTML/script e links inseguros;
  - formato `plain` escapar HTML e linkificar URLs.
- Expandidos testes de `MessageRow` para:
  - mensagem normal Markdown renderizar a marcacao;
  - `strip_formatting: true` remover marcacao Markdown na linha renderizada.

Falha inicial:
- Os testes de `ChatHelpers` falharam porque `format_content/3` nao existia.
- Os testes de `MessageRow` falharam porque o componente recebia
  `content_format`, mas ainda chamava o formatter IRC-only.

Implementacao:
- `ChatHelpers.format_content/2` foi mantido como compatibilidade IRC.
- Criado `ChatHelpers.format_content/3`, que:
  - normaliza formato via `RetroHexChat.Chat.Content`;
  - renderiza IRC/Markdown/plain pelo facade de conteudo;
  - aplica strip por `Content.strip_formatting/2`;
  - mantem linkificacao de URLs para IRC/plain;
  - evita reprocessar HTML Markdown com `URLDetector.linkify_html/1`, prevenindo
    double-link em anchors ja gerados pelo parser Markdown;
  - continua linkificando nomes de canal no HTML final.
- `Components.UI.MessageRow` agora extrai `content_format` de `@msg` com fallback
  `irc` e passa o formato para `ChatHelpers.format_content/3` em todos os tipos
  de linha que renderizam texto.

Validacao:
- `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/app/chat_helpers_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/message_row_test.exs`

Resultado:
- Bateria focada F4: 45 testes, 0 falhas.
- `rtk make ci`: 13/13 checks passaram, incluindo Dialyzer.

Aprendizados:
- `URLDetector.linkify_html/1` e seguro para HTML gerado pelo formatter IRC, mas
  nao deve rodar sobre HTML Markdown que ja contem anchors, porque ele nao e
  tag-aware o bastante para evitar reprocessar `href`.
- A API de compatibilidade `format_content/2` permite migrar a timeline sem
  quebrar superficies antigas que ainda assumem IRC.

Decisoes/desvios:
- Decisao: Markdown rendered HTML vem do facade `Content`; a camada web apenas
  aplica linkificacao de canais e politicas de UI.
- Decisao: suporte visual avancado para blocos Markdown/listas/codigo fica para
  refinamento CSS/UX posterior se a primeira renderizacao mostrar necessidade.

### 2026-08-04 - F5: composer, toolbar, paste e edicao

Escopo:
- Expor seletor de formato no composer com `IRC`, `MD` e `TXT`.
- Enviar `content_format` no submit de mensagem, edit e retry.
- Fazer a toolbar mudar de comandos conforme o formato ativo.
- Adicionar preview Markdown usando o mesmo renderizador/sanitizador de
  producao.
- Preservar paste multilinha como uma unica mensagem em Markdown.
- Abrir edicao no formato original da mensagem e restaurar o formato anterior do
  composer ao sair da edicao.
- Atualizar Help inicial do produto para explicar os tres formatos.

Testes primeiro:
- Criado `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/composer_format_test.exs`
  cobrindo envio Markdown, envio plain e edicao no formato original.
- Expandidos testes de `Chat.Service` para troca explicita de formato em
  edicoes de canal e PM.
- Expandidos testes JS de `FormatToolbarHook` para wrappers Markdown.
- Expandidos testes JS de `PasteHook` para manter paste multilinha em Markdown.

Falha inicial:
- A primeira execucao focada falhou porque `Service.edit_message/4` e
  `Service.edit_private_message/4` ainda nao existiam.
- A LiveView nao tinha seletor de formato no composer.
- Os hooks JS ainda conheciam apenas controles IRC e paste multilinha sempre
  abria o fluxo de confirmacao.

Implementacao:
- `Composer` agora possui estado proprio de `content_format` e
  `composer_view`.
- O form inclui `content_format`, e o componente envia mensagens semanticas
  novas para o parent:
  - `{:composer_dispatch, text, reply_to, content_format}`;
  - `{:composer_submit_edit, content, content_format}`.
- `CoreEvents` e `CommandDispatch` propagam formato para canal, PM, pending row,
  retry e edicao.
- `Service.edit_message/4` e `Service.edit_private_message/4` permitem trocar o
  formato explicitamente e preservam o formato persistido quando opts nao sao
  informados.
- `FormattingToolbar` renderiza:
  - controles IRC no modo `irc`;
  - bold, italic, inline code, code block, quote, list e link no modo
    `markdown`;
  - controles globais reduzidos no modo `plain`.
- `FormatToolbarHook` passou a operar selecao Markdown por wrappers/prefixos.
- `PasteHook` consulta o campo `content_format` do form e deixa paste multilinha
  seguir nativo em Markdown.
- Adicionado reset visual CSS para blocos Markdown em mensagens e preview.
- Adicionado topico de Help `formatting-message-formats` e link a partir do
  overview de formatacao.

Validacao:
- `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/chat/service_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/composer_format_test.exs`
- `rtk npm --prefix apps/retro_hex_chat_web/assets test -- test/hooks/chat/format_toolbar_hook.test.js test/hooks/chat/paste_hook.test.js`
- `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/help_live/help_content_coverage_test.exs`
- `rtk make test.js.changed`
- `rtk make lint.js.changed`
- Gate final do diff: `rtk make ci`.

Resultado:
- Bateria focada de dominio + LiveView: 43 testes, 0 falhas.
- Vitest focado: 17 testes, 0 falhas.
- HelpContent coverage: 1 teste, 0 falhas.
- JS changed tests/lint: 0 falhas.

Aprendizados:
- O formato precisa ser estado do composer, nao apenas campo do form; testes
  LiveView podem submeter params parciais e ainda assim o contrato precisa
  refletir a escolha do usuario.
- Edicao deve armazenar o formato anterior do composer para nao deixar uma
  mensagem antiga alterar permanentemente o modo de escrita do usuario.
- Paste multilinha e uma regra de produto dependente de formato: em IRC pode
  significar varias mensagens, mas em Markdown frequentemente e uma unica
  mensagem com bloco de codigo, lista ou citacao.
- Renderizar Markdown real sem reset CSS deixa margens de `p`, `pre` e listas
  vazarem para a timeline compacta.

Decisoes/desvios:
- Decisao: o modo selecionado permanece entre novas mensagens.
- Decisao: slash commands continuam sendo parseados antes de qualquer semantica
  de formato.
- Decisao: `Plain` fica como modo de texto literal, com toolbar reduzida.
- Desvio aceito: persistencia local da preferencia de formato fica fora da F5.
- Desvio aceito: conversao automatica entre IRC e Markdown em edicao fica fora
  da F5; troca explicita de formato salva o novo source como digitado.

### 2026-08-04 - F6: busca, highlight, URL catcher e copia

Escopo:
- Fazer busca persistida usar texto visivel (`plain_content`) com fallback para
  `content` em linhas legadas.
- Fazer highlight/notificacao operar por formato, usando `Content.plain_text/2`
  antes da comparacao.
- Proteger o highlight visual do cliente contra insercao de `<mark>` dentro de
  `code`, `pre`, `a` e controles interativos.
- Fazer URL catcher chamar `Content.extract_urls/2`, incluindo politica
  Markdown de capturar URLs renderizadas/clicaveis e ignorar URLs em codigo.
- Separar copy de texto visivel e copy de source no menu de contexto.
- Preservar source no DOM de forma codificada para nao vazar bytes de IRC nem
  conteudo substituido por placeholder.
- Tornar linkificacao de canais HTML-aware para nao alterar `code`, `pre` ou
  links existentes.

Testes primeiro:
- Expandidos testes de `Search` para Markdown pesquisavel por texto visivel,
  regex sobre texto visivel, fallback legado e filtro de mencao sem considerar
  URL escondida.
- Expandidos testes de `Highlight` para `check/5` com Markdown.
- Expandidos testes de `Content.extract_urls/2` para `data-url` em links
  Markdown e ignorar URLs em codigo.
- Expandidos testes JS de search/highlight para areas protegidas.
- Expandidos testes JS de contexto para `message_source` e `message_format`.
- Expandidos testes de `MessageRow` e `UserContextMenus` para copy text/copy
  source.
- Adicionado teste LiveView do URL catcher recebendo mensagem Markdown via
  PubSub.

Falha inicial:
- `Highlight.check/5` nao existia.
- `Search.count_matches/3` ainda consultava `content` cru.
- O highlight do cliente marcava texto dentro de `code`, `pre` e `a`.
- O source cru em `data-message-source` vazava digitos de codigos IRC e tambem
  expunha conteudo de convites P2P que a UI substitui por placeholder.

Implementacao:
- `RetroHexChat.Chat.Search` usa `coalesce(plain_content, content)` em busca
  literal, regex e filtro de mencao.
- `RetroHexChat.Chat.Highlight` manteve `check/4` compativel e adicionou
  `check/5` format-aware.
- `Content.Markdown.extract_urls/1` extrai `href` do HTML Markdown sanitizado,
  entao segue a politica do que ficou clicavel.
- `Content.Markdown` adiciona `data-url` aos anchors endurecidos.
- `Session.capture_urls/6` passou a receber `content_format` e chamar
  `Content.extract_urls/2`; handlers PubSub propagam o formato.
- `MessageRow` publica `data-message-text` e `data-message-source-b64`, omitindo
  metadados para linhas deletadas, inline-help e p2p-invite.
- `chat.js` decodifica source Base64 e envia `message_source`/`message_format`
  no evento de menu de contexto.
- `ChatContextMenu` ganhou acao `Copy Source`.
- `ChatHelpers.linkify_channels/1` passou a manter pilha simples de tags
  protegidas para nao linkificar dentro de `a`, `code` ou `pre`.
- `URLDetector.linkify_html/1` tambem passou a respeitar `a`, `code` e `pre`
  para nao criar links dentro de links ou blocos de codigo.

Validacao:
- `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/chat/search_test.exs apps/retro_hex_chat/test/retro_hex_chat/chat/highlight_test.exs apps/retro_hex_chat/test/retro_hex_chat/chat/content_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/app/chat_helpers_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/message_row_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/user_context_menus_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/helpers/messages_test.exs`
- `rtk npm test -- test/lib/chat/search.test.js test/hooks/chat/search_highlight_hook.test.js test/lib/chat/chat.test.js`
- `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/session_buffers_test.exs --include liveview_feature`
- `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/chat/url_detector_test.exs`
- Gate final do diff: `rtk make ci`.

Resultado:
- Bateria focada de dominio + componentes: 111 testes, 0 falhas.
- Vitest focado: 46 testes, 0 falhas.
- URL catcher LiveView: 2 testes, 0 falhas.
- URLDetector focado: 47 testes + 3 properties, 0 falhas.
- CI completo: 13/13 checks, 0 falhas.

Aprendizados:
- Source original nao deve ser exposto como atributo HTML cru: IRC pode conter
  controles invisiveis e fluxos especiais podem carregar conteudo que a UI
  deliberadamente nao mostra.
- Para Markdown, URL catcher deve seguir o que o renderizador transforma em link
  clicavel; isso resolve automaticamente o caso de codigo.
- `plain_content` precisa ser usado tambem nos filtros auxiliares, nao so na
  query principal, senao "minhas mencoes" volta a enxergar source escondido.

Decisoes/desvios:
- Decisao: `Copy Message` continua copiando a linha legivel com timestamp/nick
  quando esses elementos existem; `Copy Source` copia somente o conteudo original
  digitado.
- Decisao: mensagens `p2p_invite`, `inline_help` e deletadas nao publicam source
  no DOM.
- Desvio aceito: busca de historico continua limitada a mensagens de canal; PM
  search historico fica fora desta fase porque o modulo existente nao consulta
  `private_messages`.

### 2026-08-04 - Validacao visual Playwright

Escopo:
- Criar cobertura E2E real para o fluxo de formatacao convivendo IRC e
  Markdown.
- Capturar screenshots de preview Markdown, timeline renderizada, busca,
  menu de contexto, URL catcher e retorno ao IRC.
- Inspecionar visualmente os PNGs gerados, nao apenas confiar no resultado
  automatico do teste.

Falha visual encontrada:
- O hook de link preview ja adicionava o titulo resolvido do link depois do
  anchor, mas nao havia estilo para `.chat-link-preview`.
- No screenshot da timeline Markdown, o titulo `Connect - RetroHexChat`
  apareceu colado ao texto do link.

Implementacao:
- `chat-formatting.spec.ts` ganhou fluxo Playwright que envia mensagem
  Markdown com bold, link e URL em codigo; valida busca, copy source, URL
  catcher e retorno para IRC.
- `.chat-link-preview` recebeu estilo discreto e separador visual por
  parenteses.
- `ChatViewportHook` passou a nao criar preview vazio e a atualizar um preview
  existente em vez de duplicar spans.
- `chat_viewport_hook.test.js` ganhou testes focados para preview unico,
  atualizacao de titulo e ausencia de spans vazios.

Validacao:
- `rtk npm test --prefix apps/retro_hex_chat_web/assets -- test/hooks/chat/chat_viewport_hook.test.js`
- `rtk make e2e.shots FILE=tests/chat-formatting.spec.ts`

Resultado:
- Vitest focado do viewport hook: 9 testes, 0 falhas.
- Playwright screenshots: 2 testes, 0 falhas.
- Screenshots inspecionados em:
  `e2e/screenshots/chat-formatting/markdown-mode-renders-rich-messages-without-breaking-search-copy-source-or-url-c/`
- Evidencias visuais conferidas: `01-markdown-toolbar-menu.png`,
  `02-markdown-preview.png`, `03-timeline-markdown-rendered.png`,
  `04-search-highlight-skips-link-and-code.png`, `05-copy-source-menu.png`,
  `06-url-catcher-markdown-link.png`, `07-timeline-irc-still-renders.png`.

Aprendizados:
- Screenshot real pegou uma falha que testes funcionais nao pegariam: conteudo
  correto, mas metadata sem separacao visual.
- Preview de link deve ser tratado como metadata de mensagem, nao como
  continuacao do texto digitado pelo usuario.

### 2026-08-04 - Refinamento UX do composer Markdown

Motivacao:
- Feedback visual mostrou que os botoes grandes `IRC / MD / TXT / Preview`
  dentro da linha do composer deixavam a area de digitar pesada e feia.
- O padrao da plataforma usa toolbars de icones; controles Markdown com texto
  solto nao atingiam o nivel visual esperado.
- O preview Markdown precisava parecer a mensagem final no chat, nao um campo
  auxiliar generico.

Implementacao:
- Seletor de formato e Preview foram movidos para dentro do popover da toolbar
  existente, deixando o composer com um unico botao discreto ao lado do input.
- Criados icones SVG autorais em `RetroHexChatWeb.Icons.Formatting` para modos
  `IRC`, `Markdown`, `Plain`, preview e comandos Markdown.
- Toolbar Markdown agora cobre heading, bold, italic, strike, inline code,
  code block, quote, lista com bullets, lista numerada e link.
- Preview Markdown virou popover acima do composer e reutiliza `ChatMessage`,
  com nick, timestamp, icone, spine e corpo renderizado pelo mesmo
  `ChatHelpers.format_content/3` usado na timeline.
- `FormatToolbarHook` preserva foco do textarea para acoes LiveView do menu.
- Segunda revisao visual: a linha de acoes Markdown passou a nao quebrar em
  duas linhas; em viewports estreitas ela mantem uma unica linha horizontal.
- Preview Markdown passou a aparecer apenas quando ha conteudo digitado e some
  ao trocar para IRC/TXT, evitando preview vazio/perdido sobre o composer.

Validacao:
- `rtk npm test --prefix apps/retro_hex_chat_web/assets -- test/hooks/chat/format_toolbar_hook.test.js`
- `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/composer_format_test.exs`
- `rtk make e2e.shots FILE=tests/chat-formatting.spec.ts`
- `rtk make ci`

Resultado:
- Vitest focado do toolbar: 16 testes, 0 falhas.
- LiveView focado do composer: 5 testes, 0 falhas.
- Playwright screenshots: 2 testes, 0 falhas.
- CI completo: 13/13 checks, 0 falhas.
- Capturas reais inspecionadas confirmaram menu discreto com icones, preview
  como mensagem real, acoes Markdown em uma linha, busca, URL catcher e retorno
  ao IRC sem regressao visual.

Aprendizados:
- Em composer de chat, controles de modo competem diretamente com o espaco de
  digitacao; formato deve viver no menu de ferramentas, nao como botoes
  permanentes.
- Preview de Markdown precisa usar o proprio componente de mensagem para evitar
  uma segunda linguagem visual.

## Aprendizados acumulados

- Preservar IRC como formato de primeira classe e essencial para manter a
  identidade da plataforma.
- Markdown deve entrar como evolucao do conteudo, nao como substituto silencioso
  do IRC.
- O campo `plain_content` tende a simplificar busca, preview, reply,
  notificacoes e acessibilidade.
- UX de modo explicito evita ambiguidade e reduz suporte.
- TDD aqui precisa cobrir seguranca, historico e fluxo de usuario, nao apenas
  renderizacao feliz.
- Dependencias nativas precompiladas precisam aparecer explicitamente no diario
  porque afetam ambiente de CI e cache de build.
- Colunas cacheadas de texto visivel precisam ser protegidas no changeset para
  nao virarem uma segunda fonte de verdade editavel por callers.
- Caminhos paralelos de envio (`Chat.Service` e `Channels.Server`) precisam de
  testes de contrato duplicados enquanto ambos existirem; do contrario o formato
  novo passa em um caminho e some no outro.
- O estado de composicao precisa guardar tanto o formato ativo quanto o formato
  anterior ao editar, para preservar intencao do usuario entre mensagens.
- Source de mensagem deve trafegar pelo DOM em representacao segura, separada
  do texto visivel, para suportar copy source sem quebrar renderizacao ou
  privacidade de linhas especiais.
- Validacao visual com Playwright deve fazer parte do fechamento de mudancas de
  UX, porque encontrou um problema de apresentacao que nao quebrava asserts de
  comportamento.
- Controles de formato no composer devem ser iconograficos e contextuais; texto
  grande na linha de composicao rouba area do input e degrada a leitura.
