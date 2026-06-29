# Add Command Dialog Migration

## Objetivo

Migrar Add Command form para subcomponente stateful do BotManagementDialog.

## Classificação para execução (agentes)

- **Tier:** 🔴 Complexo
- **Dependências:** Depende de: 49 (subdialog).
- **Componente de referência:** Sub-componente/estado interno de 49.
- **Abordagem:** Integrar como filho do BotManagement (Add Command do bot selecionado).
- **Gotchas:** —
- **Validação:** Junto com 49.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:952`
- Component function: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/bot_form_dialog.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/bot_events.ex`
- State atual: `show_add_command_dialog`, `bot_dialog_selected`.

## Tecnica

Use LiveComponent filho com draft local. O bot selecionado vem do BotManagementDialog, nao do parent global.

## Tasks

- [ ] Criar `AddCommandDialogComponent`.
- [ ] Passar `bot_name` do componente pai.
- [ ] Mover trigger/response/description/cooldown draft local.
- [ ] Validar trigger e response.
- [ ] Submit atualiza commands da tab selecionada.

## Validacao

- [ ] Add command para bot selecionado funciona.
- [ ] Sem bot selecionado nao abre ou mostra erro local.
- [ ] Validacao local impede campos obrigatorios vazios.
- [ ] Commands tab reflete novo comando.

## Prompt de execucao

O dialog depende do bot selecionado; portanto deve ser filho do BotManagement, nao irmao global no template do chat.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
