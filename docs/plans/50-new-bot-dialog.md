# New Bot Dialog Migration

## Objetivo

Migrar New Bot form para subcomponente stateful do BotManagementDialog.

## Classificação para execução (agentes)

- **Tier:** 🔴 Complexo
- **Dependências:** Depende de: 49 (subdialog).
- **Componente de referência:** Sub-componente/estado interno de 49.
- **Abordagem:** Integrar como filho do BotManagement.
- **Gotchas:** —
- **Validação:** Junto com 49.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:945`
- Component function: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/bot_form_dialog.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/bot_events.ex`
- State atual: `show_new_bot_dialog`.

## Tecnica

Use LiveComponent filho de BotManagementDialog. Draft do form e validacao ficam locais. Submit emite `{:create_bot, attrs}` ao componente pai/parent.

## Tasks

- [ ] Criar `NewBotDialogComponent`.
- [ ] Mover form fields para assigns locais.
- [ ] Validar nome/nickname/prefix/cooldown/capabilities.
- [ ] Fechar por cancel limpa draft.
- [ ] Apos criar, atualizar lista de bots no BotManagement.

## Validacao

- [ ] Criar bot com campos minimos funciona.
- [ ] Validacao impede nome vazio/invalido.
- [ ] Capabilities sao enviadas corretamente.
- [ ] Dialog filho trava/integra com dialog pai.

## Prompt de execucao

New Bot nao deve ser renderizado diretamente pelo `ChatLive`; ele pertence ao fluxo de Bot Management.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
