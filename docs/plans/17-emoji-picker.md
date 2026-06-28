# Emoji Picker Migration

## Objetivo

Migrar emoji picker para componente stateful carregado somente quando aberto, com busca local e comunicacao direta com composer.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:320`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/chat/emoji_picker.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/emoji_events.ex`
- State atual: `show_emoji_picker`, `emoji_search`, `emoji_category`, `emoji_emojis`.

## Tecnica

Use LiveComponent stateful e monte apenas quando aberto. Cache categorias em modulo/contexto, nao em assign do parent. Use `phx-target={@myself}` para busca/categoria/selecao.

## Tasks

- [ ] Criar `EmojiPickerComponent`.
- [ ] Mover estado emoji para o componente.
- [ ] Nao calcular `EmojiData.categories()` no template do parent.
- [ ] Enviar emoji selecionado ao ComposerComponent.
- [ ] Fechar via JS/local quando apropriado.
- [ ] Remover `EmojiEvents` da pipeline global.

## Validacao

- [ ] Abrir picker nao re-renderiza chat inteiro.
- [ ] Buscar emoji atualiza somente picker.
- [ ] Selecionar emoji insere no input no cursor correto.
- [ ] Fechar picker preserva foco do input.

## Prompt de execucao

Emoji picker e UI efemera. Monte sob demanda e mantenha seus dados fora do parent.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
