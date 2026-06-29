# Loading And Scroll Indicators Migration

## Objetivo

Migrar loading de canal e scroll loader para os componentes donos do carregamento: MessageViewport, StatusViewport ou dialogs com async.

## Classificação para execução (agentes)

- **Tier:** 🔴→🟡
- **Dependências:** Depende de: 10 (loading_more pertence ao MessageViewport).
- **Componente de referência:** Function components puros para o visual.
- **Abordagem:** Estado loading_* fica no componente que faz a operação async/paginação.
- **Gotchas:** loading_channel pode ser transient do viewport/shell.
- **Validação:** `make ci` 9/9.

## Codigo atual

- Loading spinner no template: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:211`
- Scroll loader no template: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:217`
- Components: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/shell/loading_spinner.ex` e `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/chat/scroll_loader.ex`
- State atual: `loading_channel`, `loading_more`.

## Tecnica

Use function components puros para o visual. O estado `loading_*` deve ficar no componente que executa a operacao async/paginacao. Para mensagens, `loading_more` pertence ao MessageViewport. Para troca de canal, `loading_channel` pode ser transient state do viewport ou do shell de conteudo.

## Tasks

- [x] Mover `loading_more` para MessageViewportComponent. (VISUAL movido; o estado `loading_more` fica no parent — é lido sincronamente pela lógica de paginação em `core_events.ex`, logo é read-model. Passthrough.)
- [x] Mover `scroll_loader` para dentro do viewport.
- [x] Decidir owner de `loading_channel`: MessageViewport se representa mensagens, parent se representa troca global de contexto. (Visual no MessageViewport — é o loading das MENSAGENS; estado escrito pelo channel-switch do parent fica no parent. Passthrough.)
- [ ] Padronizar loading para dialogs async usando o mesmo `loading_spinner`. (Fora de escopo — nenhum dialog async migrado hoje usa indicador próprio; quando algum precisar, reusar `loading_spinner`. Sem mudança necessária agora.)
- [x] Remover loading assigns globais quando nao usados. (Imports órfãos `LoadingSpinner`/`ScrollLoader` removidos do parent; os assigns `loading_more`/`loading_channel` continuam necessários — lidos pela paginação/channel-switch.)

## Validacao

- [x] Load more mostra indicador no viewport e some ao finalizar. (E2E chat-history-pagination 2/2; `scroll_loader` agora renderiza dentro do MessageViewport quando `loading_more`.)
- [x] Troca de canal mostra loading sem bloquear header/sidebar. (Spinner está na coluna de mensagens, não no header/sidebar; markup inalterado, só movido. Component test cobre `loading_channel`.)
- [x] Loading de dialogs pesados nao afeta chat. (Indicadores de chat isolados no viewport; dialogs não tocados.)
- [x] Indicadores nao causam layout shift perceptivel. (Markup idêntico; o `class="contents"` do root do MessageViewport é transparente no layout → spinner/loader permanecem filhos diretos da coluna de mensagens, na mesma ordem.)

## Prompt de execucao

Loading e estado da operacao, nao do app inteiro. Coloque o indicador no mesmo componente que inicia e finaliza a operacao.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
- 2026-06-29: `in_progress`. Aplicando o shared-read-model do plano 10: `loading_more` é lido sincronamente pela lógica de paginação do parent (`core_events.ex` decide pular o load-more com base nele) e `loading_channel` é escrito pelo channel-switch do parent — **estado fica no parent**; só o VISUAL (`loading_spinner` + `scroll_loader`) migra para dentro do `MessageViewport` como passthrough (`loading_more`/`loading_channel` viram assigns do componente). O DOM-window limit (`limit: -N`) continua deferido — exigiria migrar o read-model de scroll/paginação, o que o padrão evita.
- 2026-06-29: `complete`. `loading_spinner` (canal) + `scroll_loader` (load-older) movidos do template do parent para o `render/1` do `MessageViewport`, co-localizados com as mensagens que descrevem. Estado `loading_more`/`loading_channel` continua no parent (read-model — paginação/channel-switch) e chega como passthrough; adicionados aos defaults do `mount/1` + ao merge de contexto do `update/2`. Imports `LoadingSpinner`/`ScrollLoader` removidos do parent (órfãos após a remoção; `-W0` pegou). `class="contents"` do root do componente é transparente no layout → spinner/loader seguem filhos diretos da coluna de mensagens, mesma ordem → zero layout shift. **Validação:** `make ci` **9/9**; `message_viewport_test.exs` +2 (spinner só com `loading_channel`; scroll-loader só com `loading_more`) = 7; E2E chat-history-pagination 2/2 (load-more exercita o `scroll_loader` no viewport). Sem baseline-check (markup movido verbatim, comportamento idêntico).
