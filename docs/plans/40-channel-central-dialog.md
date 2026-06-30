# Channel Central Dialog Migration

> **STATUS: COMPLETE (2026-06-30) — full ownership; THE modal-in-modal reference.**
> `RetroHexChatWeb.ChatLive.Components.ChannelCentralDialog` owns the entire dialog: all 21
> `channel_central_*`/`show_cc_*` assigns, every event (`@myself`), the privileged `Server`/`ChanServ`
> calls, and all derive helpers. `channel_central_events.ex` gutted to open/close routing (~45 lines). The
> 4 `fixed inset-0` sub-forms are fixed at the root via a `target` attr threaded through the design-system
> `channel_central_dialog/1` (`phx-target={@target}` on every event) — the sub-form `<form>` submits to the
> component that owns its DOM, so the uncontrolled input survives PubSub re-renders. System errors bubble
> (`{:cc_system_error, msg}` → parent `error_event`); the 2 PubSub refresh clones → `send_update(refresh:)`;
> JS tabs use `on_tab={JS.push(..., target: @myself)}`; Escape handled by `<.dialog>` itself. `make ci`
> 9/9; both feature tests (35) converted to element-based firing. **See PROGRESS.md log + playbook §0a-anti
> for the canonical pattern that 30/31/35/41 follow.**

## Objetivo

Migrar Channel Central para LiveComponent stateful com tabs internas, formularios, listas de bans/exceptions e operacoes ChanServ isoladas.

## Classificação para execução (agentes)

- **Tier:** 🔴 Complexo (o MAIOR — lote dedicado)
- **Dependências:** Independente, mas gigante: 34 assigns, 4 subdialogs, ChanServ.
- **Componente de referência:** Mini-app administrativo do canal.
- **Abordagem:** Sair INTEIRO do parent; tabs/seleções/drafts/subdialogs no componente; operações ChanServ retornam por update.
- **Gotchas:** Não migrar tab por tab mantendo `channel_central_*` no ChatLive.
- **Validação:** `make ci` 9/9 + E2E channel-central.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:776`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/channel_central_dialog.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/channel_central_events.ex`
- PubSub state: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/channel_state.ex`
- State atual: `show_channel_central`, `channel_central_*`, `show_cc_add_ban_dialog`, `show_cc_add_ban_ex_dialog`, `show_cc_add_invite_ex_dialog`, `show_cc_transfer_dialog`.

## Tecnica

Use LiveComponent stateful montado sob demanda. Channel Central e mini-app administrativo do canal: tabs, selections, drafts e modals internos devem ficar nele. Listas de bans/exceptions/access podem usar stream quando crescerem. Operacoes que chamam server/ChanServ retornam resultado por update.

## Tasks

- [ ] Criar `ChannelCentralDialogComponent`.
- [ ] Mover todos os assigns `channel_central_*` e `show_cc_*`.
- [ ] Abrir com snapshot do canal ativo e permissoes viewer.
- [ ] Carregar dados pesados async ao abrir/trocar tab.
- [ ] Streamar bans, ban exceptions, invite exceptions e access entries se necessario.
- [ ] Encapsular subdialogs de add ban/exceptions e transfer.
- [ ] Emitir comandos ao parent/contexto: set_topic, save_welcome, modes, bans, register/drop, access.
- [ ] Atualizar componente em eventos PubSub do canal aberto.

## Validacao

- [ ] Todas as tabs funcionam: general, modes, bans, exceptions, registration/access.
- [ ] Operador/owner/identified controlam permissoes corretamente.
- [ ] Add/remove ban/exceptions atualiza lista sem reset global.
- [ ] Transfer/drop/register confirmacoes funcionam.
- [ ] Mudanca de topico/modes via PubSub atualiza dialog se aberto.
- [ ] Fechar limpa drafts e selecoes.

## Prompt de execucao

Channel Central deve sair inteiro do parent. Nao migre tab por tab mantendo `channel_central_*` no `ChatLive`.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
