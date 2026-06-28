# Autocomplete And Syntax Tooltip Migration

## Objetivo

Migrar autocomplete e syntax tooltip para uma ilha de composer, removendo estado de autocomplete do parent.

## Codigo atual

- Render autocomplete: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:309`
- Render syntax tooltip: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:317`
- Components: `autocomplete.ex`, `syntax_tooltip.ex`
- State atual: `autocomplete_command`, `autocomplete_filter`, `autocomplete_mode`, `autocomplete_results`, `autocomplete_selected`, `autocomplete_visible`, `syntax_tooltip`, `command_help_level`.
- Tests/features: autocomplete feature tests em `apps/retro_hex_chat_web/test/retro_hex_chat_web/live`.

## Tecnica

Use state local no `ComposerComponent` ou sub-LiveComponent se a logica ficar grande. Recalcule resultados em evento local com debounce minimo; para listas grandes, mantenha indices em memoria/ETS/contexto.

## Tasks

- [ ] Mover todos os assigns `autocomplete_*` para o composer.
- [ ] Mover `syntax_tooltip` e `command_help_level`.
- [ ] Fazer `AutocompleteHook` conversar com o composer.
- [ ] Preparar provider puro para comandos/nicks/canais.
- [ ] Evitar passar `channel_users` inteiro pelo parent; usar lookup provider ou update incremental de nicks.
- [ ] Preservar selecao por teclado.

## Validacao

- [ ] Autocomplete de comando, nick e canal funciona.
- [ ] Tooltip acompanha comando atual.
- [ ] Teclas de navegacao nao vazam para handlers globais.
- [ ] Digitar rapido nao gera patch pesado.

## Prompt de execucao

Autocomplete pertence ao input. Nao deixe estado transitorio de digitacao no `ChatLive` parent.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
