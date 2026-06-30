# Formatting Toolbar, Reply Bar And Typing Migration

> **STATUS: COMPLETE (2026-06-30) — folded into plan 14.** These controls were already interleaved with
> the input in one flex panel, so `Components.Composer` renders them in its bottom region. `reply_to` is
> composer-owned; formatting toolbar + typing indicator read passthrough (`session`/`show_status_tab`/
> `pm_typing_from`) and their events (`toggle_strip_formatting`/`toggle_emoji_picker`) stay parent. See 14.

## Objetivo

Agrupar elementos abaixo do viewport que pertencem ao fluxo de composicao, mas manter cada subcomponente puro quando nao ha estado proprio.

## Classificação para execução (agentes)

- **Tier:** 🔴 Complexo
- **Dependências:** Depende de: 14 (vivem dentro do Composer).
- **Componente de referência:** Function components dentro do ComposerComponent.
- **Abordagem:** Markup em function components; estado e eventos no composer.
- **Gotchas:** —
- **Validação:** `make ci` 9/9 + E2E formatting/typing.

## Codigo atual

- Formatting toolbar: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:327`
- Reply bar: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:335`
- Typing indicator: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:342`
- Components: `formatting_toolbar.ex`, `reply_bar.ex`, `typing_indicator.ex`
- Typing handlers: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pm_typing_events.ex` e `pubsub_handlers/messages.ex`

## Tecnica

Colocar toolbar/reply/typing dentro do `ComposerComponent`. Use function components para markup, mas deixe estado e eventos no composer.

## Tasks

- [ ] Mover `formatting_toolbar`, `reply_bar` e `typing_indicator` para o composer.
- [ ] `strip_formatting` pode continuar no contexto global/session, mas o evento local deve ser roteado pelo composer.
- [ ] `reply_to` deve sair do parent e ficar no composer, recebendo comandos de MessageViewport.
- [ ] `pm_typing_from` e timer podem ficar em componente de PM/composer se o indicador so renderiza ali.
- [ ] Manter `toggle_emoji_picker` integrado ao EmojiPickerComponent.

## Validacao

- [ ] Toggle formatting persiste e altera render de mensagens novas.
- [ ] Reply bar aparece ao responder e some ao cancelar/enviar.
- [ ] Typing indicator aparece so em PM ativo.
- [ ] Updates de typing nao re-renderizam viewport inteiro.

## Prompt de execucao

Nao crie tres LiveComponents se um `ComposerComponent` resolve ownership. Deixe subcomponentes como function components.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
