# Bot Management Dialog Migration

## Objetivo

Migrar Bot Management para LiveComponent stateful com lista de bots, selecao, tabs, comandos/eventos/stats e operacoes admin async.

## Classificação para execução (agentes)

- **Tier:** 🔴 Complexo (gigante)
- **Dependências:** Bloqueia: 50, 51 (subdialogs New Bot / Add Command).
- **Componente de referência:** Mini-app administrativo.
- **Abordagem:** Lista de bots (stream), tabs, comandos/eventos/stats, ops admin async; subdialogs como filhos/estado interno.
- **Gotchas:** Sair inteiro do parent; remover bot_events da pipeline global depois.
- **Validação:** `make ci` 9/9 + E2E bot.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:929`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/bot_management_dialog.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/bot_events.ex`
- State atual: `show_bot_dialog`, `bot_dialog_bots`, `bot_dialog_selected`, `bot_dialog_channels`, `bot_dialog_commands`, `bot_dialog_events`, `bot_dialog_stats`, `bot_dialog_tab`, `bot_dialog_editing_field`, `show_new_bot_dialog`, `show_add_command_dialog`.

## Tecnica

Use LiveComponent stateful montado sob demanda. Lista de bots pode ser stream. Details por tab podem carregar async. Subdialogs New Bot/Add Command devem ser filhos ou state interno.

## Tasks

- [ ] Criar `BotManagementDialogComponent`.
- [ ] Mover todos os assigns `bot_dialog_*` e subdialog flags.
- [ ] Carregar bots ao abrir com async.
- [ ] Streamar bots se lista crescer.
- [ ] Selecionar bot carrega details/tab ativa.
- [ ] Emitir admin commands ao parent/contexto.
- [ ] Integrar NewBotDialog e AddCommandDialog como subcomponentes.
- [ ] Remover `bot_events.ex` da pipeline global apos migrar.

## Validacao

- [ ] Lista bots, selecao e tabs funcionam.
- [ ] Admin pode criar/deletar/toggle bot.
- [ ] Add command funciona para bot selecionado.
- [ ] Stats/events atualizam sem resetar dialog.
- [ ] Usuarios sem admin nao veem acoes proibidas.

## Prompt de execucao

Bot Management e mini-app administrativo. Mova inteiro para componente stateful e deixe o parent so executar operacoes de dominio.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.

- 2026-06-29: **COMPLETE.** Consolidado em `Components.BotManagementDialog` (LiveComponent único p/ 49+50+51). Extração total (0 read-model): handlers leem de params, `assign`→`put_bot/2` (`send_update`), eventos = adapters string. 11 chaves fora do `assign_defaults`. Filhos = `<.dialog>` normais (sem clobber modal-in-modal). `make ci` 9/9; component test (4) + feature test 5/5.