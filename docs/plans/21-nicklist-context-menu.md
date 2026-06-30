# Nicklist Context Menu Migration

> **STATUS: COMPLETE (2026-06-29) — migrated as a cluster with plan 19.**
> `RetroHexChatWeb.ChatLive.Components.UserContextMenus` (one stateful island) owns the nicklist menu
> (`context_menu`) + `show_context_color_picker` alongside the chat menu — three keys out of
> `assign_defaults`. The color swatch already carried `phx-value-nick`, so `context_pick_color` reads
> `params["nick"]` (zero parent read in the apply path). `nick_right_click`/`context_set_nick_color`/close
> are STRING adapters via `put_menu/2` (`send_update`); the ~25 `context_*` actions keep their privileged
> session/server work on the parent. Pragmatic relaxation of the "resolve target from a local user stream"
> gotcha: the canonical `channel_users` passes through and `is_target_op/voiced/muted` derive in `render/1`
> (same as plans 05/13/20). Also removed the dead `Helpers.Session.close_context_menu/1` (stale after
> plan 20). `make ci` 9/9; shared component test `user_context_menus_test.exs` (7).

## Objetivo

Migrar context menu da nicklist para dentro do `NicklistComponent`, junto com color picker e permissoes por usuario.

## Classificação para execução (agentes)

- **Tier:** 🔴 Complexo
- **Dependências:** Depende de: 13 (vive dentro de Nicklist).
- **Componente de referência:** Estado local no NicklistComponent.
- **Abordagem:** Resolver status do target via stream/cache local de usuários.
- **Gotchas:** NÃO pedir `channel_user_op?(@channel_users, ...)` ao parent — usar cache local.
- **Validação:** `make ci` 9/9 + E2E nicklist-context-menu.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:452`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/chat/nicklist_context_menu.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/context_menu_events.ex`
- State atual: `context_menu`, `show_context_color_picker`.

## Tecnica

Use state local no NicklistComponent. O menu deve resolver status do target a partir do stream/cache local de usuarios, nao pedindo `channel_user_op?(@channel_users, ...)` ao parent.

## Tasks

- [ ] Mover `context_menu` e `show_context_color_picker` para NicklistComponent.
- [ ] Manter indice local por nick para role/voice/mute.
- [ ] Passar viewer permissions como assign pequeno.
- [ ] Emitir comandos semanticos para query/whois/ignore/kick/ban/op/voice/color.
- [ ] Compartilhar componente de color picker se necessario.

## Validacao

- [ ] Opcoes de moderacao respeitam operator/identified.
- [ ] Color picker atualiza nick color e propaga para mensagens/nicklist.
- [ ] Target self/ignored/registered continuam corretos.
- [ ] Menu fecha em troca de canal.

## Prompt de execucao

O menu depende da nicklist; mova os dois juntos para evitar duplicar consultas e helpers no parent.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
