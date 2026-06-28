# Loading And Scroll Indicators Migration

## Objetivo

Migrar loading de canal e scroll loader para os componentes donos do carregamento: MessageViewport, StatusViewport ou dialogs com async.

## Codigo atual

- Loading spinner no template: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:211`
- Scroll loader no template: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:217`
- Components: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/shell/loading_spinner.ex` e `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/chat/scroll_loader.ex`
- State atual: `loading_channel`, `loading_more`.

## Tecnica

Use function components puros para o visual. O estado `loading_*` deve ficar no componente que executa a operacao async/paginacao. Para mensagens, `loading_more` pertence ao MessageViewport. Para troca de canal, `loading_channel` pode ser transient state do viewport ou do shell de conteudo.

## Tasks

- [ ] Mover `loading_more` para MessageViewportComponent.
- [ ] Mover `scroll_loader` para dentro do viewport.
- [ ] Decidir owner de `loading_channel`: MessageViewport se representa mensagens, parent se representa troca global de contexto.
- [ ] Padronizar loading para dialogs async usando o mesmo `loading_spinner`.
- [ ] Remover loading assigns globais quando nao usados.

## Validacao

- [ ] Load more mostra indicador no viewport e some ao finalizar.
- [ ] Troca de canal mostra loading sem bloquear header/sidebar.
- [ ] Loading de dialogs pesados nao afeta chat.
- [ ] Indicadores nao causam layout shift perceptivel.

## Prompt de execucao

Loading e estado da operacao, nao do app inteiro. Coloque o indicador no mesmo componente que inicia e finaliza a operacao.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
