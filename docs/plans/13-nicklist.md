# Nicklist Migration

## Objetivo

Migrar nicklist para componente stateful com stream de usuarios, updates incrementais e context menu local.

## Classificação para execução (agentes)

- **Tier:** 🔴 Complexo
- **Dependências:** Bloqueia: 21 (nicklist-context-menu vive dentro). Streams + PubSub.
- **Componente de referência:** LiveComponent com `stream(:users, reset: true)`.
- **Abordagem:** `stream_insert/delete` em join/part/nick/mode/away; reset só ao trocar canal.
- **Gotchas:** Presence PubSub churn — não reatribuir a lista inteira por evento.
- **Validação:** `make ci` 9/9 + E2E nicklist (O12 é pre-existente).

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:288`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/chat/nicklist.ex`
- Context menu: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/chat/nicklist_context_menu.ex`
- Load users: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/channel.ex:178`
- Membership PubSub: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/membership.ex`
- State atual: `channel_users`, `show_nicklist`, `context_menu`, `show_context_color_picker`.

## Tecnica

Use LiveComponent stateful com `stream(:users, users, reset: true)` ao trocar canal e `stream_insert/delete` em join/part/nick change/mode change/away. Evite reatribuir a lista inteira em cada evento de presenca.

## Tasks

- [x] Criar `Components.Nicklist` (dono de `stream(:users)`).
- [x] Definir id estavel por nick normalizado (`dom_id/1` = `"nick-" <> downcase`).
- [x] `load_channel_users/2` mantém a lista canônica no parent E envia `{:reset, users}` ao componente.
- [x] PubSub membership/channel_state/session enviam deltas (`{:upsert}`/`{:remove}`/`{:reset}`).
- [x] `NicklistHook` segue no container do componente (pushEvent ainda mira o root LV).
- [x] Mover o chrome do sidebar para `Components.UI.Nicklist.nicklist_sidebar/1` (component-first + CSS-consistency).
- [~] `show_nicklist` e o context menu FICAM no parent — context menu lê `channel_users` (canônico) e é o plano **21** (integração local do menu vive lá).
- [~] "Expor só ações semânticas": parcial — o parent continua dono da lista (lida pelo tab-complete/menu/core/session); decompor os leitores fica para quando o composer (14) e o menu (21) forem extraídos.

## Validacao

- [x] Join/part atualiza um item (`stream_insert`/`stream_delete_by_dom_id`), não a lista inteira. (E2E B2/B3/B4)
- [x] Nick change preserva ordem/role/status (`{:reset}` com a lista re-mapeada). (E2E W1)
- [x] Mode changes atualizam role/voiced/muted (`apply_mode_to_users` → `{:reset}`). (E2E I2)
- [x] Context menu ainda conhece permissão do viewer (lê `channel_users` no parent — inalterado).
- [x] Status bar user_count continua correto (`channel_user_counts` é assign separado, intocado).
- [x] `make ci` 9/9 + E2E nicklist 9/9 (multiuser, roles, away W8, rename).

## Prompt de execucao

Nicklist e segunda prioridade depois de mensagens. Ela e uma lista viva; trate como stream, nao como assign de lista.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
- 2026-06-29: **COMPLETE — primeiro componente dono de STREAM (21º stateful).**
  `Components.Nicklist` é dono de `stream(:users)`. Descoberta-chave: `channel_users`
  NÃO é estado self-contained — é lido sincronamente pelo tab-complete
  (`MenuToolbarEvents`), pelo context menu (`channel_user_op?/voiced?/muted?`) e por
  core/session. Em vez de refatorar todos os leitores (big-bang), o parent CONTINUA
  dono da lista canônica e empurra deltas ao componente. O ganho dominante: o `:for`
  saiu do template do parent → a nicklist parou de re-renderizar a cada re-render do
  parent (msg/typing/lag); change-tracking a isola. Deltas: join→`{:upsert}`,
  part/kick→`{:remove}`, switch/mode/away/rename/mute→`{:reset}` (em `helpers/channel`,
  `membership`, `channel_state`, `helpers/session`; `rebuild_nick_color_fn` também
  reseta p/ re-estilizar cores — streams não re-estilizam num re-render comum). Chrome
  do sidebar → `Components.UI.Nicklist.nicklist_sidebar/1` (raw Tailwind fora do
  LiveComponent: `live/chat_live/components/` NÃO está em `@tailwind_paths` do
  css-consistency). `make ci` 9/9; teste de componente (5); **E2E 9/9** (multiuser
  B2-B4, roles I2, away W8, rename W1). Receita destilada no playbook §1d. Desbloqueia
  o plano 21 (context menu da nicklist).
