# Invite Dialog Migration

> **STATUS: COMPLETE (2026-06-30) — the orchestrator. `Components.InviteQueueDialog`.**
> The render-model (the pending-invite stack) became a stateful island isolated from the
> parent hot-path; the Join/Ignore clicks route to `@myself` and bubble the channel up via
> `send(self(), {:invite_accept | :invite_ignore, channel})`. **The queue itself stays
> parent-owned** as `pending_invites` — genuine §1d: it is the Escape-priority read-model
> (`keyboard_events` dismisses the topmost invite before any other dialog) AND the per-invite
> expiration timers (`Process.send_after(self(), {:invite_expired, channel}, …)`) fire into
> the parent LiveView process's `handle_info`, which a LiveComponent cannot have. So this is
> the inverse of the kick queue (48): kick had no timers/Escape so the whole queue moved;
> invite's orchestration (enqueue + timers + Escape) stays on the parent and only the render +
> the two button events migrate. `invite_events.ex` stopped being an event hook (removed from
> `@event_hook_fns` + `attach_all_hooks`) and became plain `InviteEvents.accept/2` /
> `ignore/2` helpers the parent `handle_info` calls. `on_accept`/`on_ignore` pass
> `JS.push(target: @myself)` (no `[phx-click='…']` Elixir selectors exist for invite, so the
> opaque-blob caveat doesn't bite; `data-testid` + `phx-value-channel` preserved). `make ci`
> 9/9; component test (3) + `chat-ignore-notifications` V11 E2E. See PROGRESS.md log (2026-06-30).

## Objetivo

Migrar lista de convites pendentes para componente stateful ou notification queue dedicada.

## Classificação para execução (agentes)

- **Tier:** 🔴 Complexo (orquestrador)
- **Dependências:** Atravessa ~5 arquivos.
- **Componente de referência:** Fila com timer + prioridade de Escape — NÃO é dialog simples.
- **Abordagem:** `pending_invites` dirige a prioridade do Escape + timers de expiração por convite (timer_ref cancelado no Escape).
- **Gotchas:** Estado de orquestração genuíno — deixar para depois dos mecânicos.
- **Validação:** `make ci` 9/9 + E2E invite.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:913`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/invite_dialog.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/invite_events.ex`
- PubSub invite: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/presence.ex`
- State atual: `pending_invites`.

## Tecnica

Use LiveComponent stateful com queue local. Parent/PubSub envia `{:invite_received, invite}` ao componente. Accept/ignore sobem como comandos.

## Tasks

- [x] Criar `InviteQueueComponent` (`Components.InviteQueueDialog`).
- [x] ~~Mover `pending_invites` para o componente~~ — fica no parent (§1d: read-model de
  Escape-priority + timers de expiração disparam no `handle_info` do pai). Só o render-model migra.
- [x] Definir id unico por invite/channel/inviter (cada card por `invite.channel`).
- [x] Accept envia join ao parent (`{:invite_accept, channel}` → `InviteEvents.accept/2`).
- [x] Ignore remove (`{:invite_ignore, channel}` → `InviteEvents.ignore/2`).
- [x] Expirar convites: timers permanecem no parent (`{:invite_expired}` em `timer_handlers`).

## Validacao

- [ ] Convite recebido mostra dialog.
- [ ] Multiplos convites entram em fila.
- [ ] Accept entra no canal correto.
- [ ] Ignore remove somente o convite correto.
- [ ] Queue nao re-renderiza chat inteiro.

## Prompt de execucao

Convites sao notificacoes. Modele como queue, nao como lista global solta.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
- 2026-06-30: **COMPLETE — o orquestrador, último plano.** `Components.InviteQueueDialog`
  (render-model island). **Insight decisivo (§1d):** ao contrário da kick queue (48), a fila
  NÃO migra — `pending_invites` é o read-model síncrono lido pelo `keyboard_events` (prioridade
  de Escape: dispensa o invite topo antes de qualquer dialog) e os timers de expiração por-invite
  (`Process.send_after(self(), {:invite_expired, channel}, 300_000)`) disparam no `handle_info`
  do processo pai (LiveComponent não tem `handle_info`). Tentar mover a fila exigiria um espelho
  de Escape no pai + round-trip de timer (component cria timer → pai recebe → pai reenvia
  `send_update`) — MAIS maquinaria de coordenação, não menos. O correto é o split de perform/
  highlight/notify: **pai dono da fila + efeitos; componente dono só do render + dos 2 cliques.**
  Join/Ignore → `@myself` → `send(self(), {:invite_accept|:invite_ignore, channel})` → parent
  `handle_info` chama `InviteEvents.accept/2`/`ignore/2` (que viraram helpers puros; o módulo
  saiu do `@event_hook_fns` E do `attach_all_hooks` — uma entrada a menos na cadeia de hooks de
  TODO evento). `on_accept`/`on_ignore` = `JS.push(target: @myself)` (invite não tem seletor
  Elixir `[phx-click='…']`, então o blob opaco do JS.push não atrapalha; `data-testid` +
  `phx-value-channel` intactos → E2E `acceptInvite`/`inviteJoinButton` preservados). Removido o
  `import UI.InviteDialog` do parent. `make ci` 9/9; component test (3) + `chat-ignore-notifications`
  V11 (ignored-inviter não abre a invite UI).
