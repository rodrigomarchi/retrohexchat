# Mute Duration Dialog Migration

## Objetivo

Migrar o dialog de duracao de mute para componente stateful pequeno, removendo `mute_duration_dialog` do parent.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:485`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/mute_duration_dialog.ex`
- Events relacionados: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/context_menu_events.ex`
- State atual: `mute_duration_dialog: %{show, target_nick}`.

## Tecnica

Use LiveComponent stateful montado sempre ou sob demanda. Estado local: target, duration draft, validation error. Evento local com `phx-target={@myself}`; parent recebe somente `{:mute_user, nick, duration}`.

## Tasks

- [x] Criar `MuteDurationDialogComponent` (`ChatLive.Components.MuteDurationDialog`).
- [x] Mover show/target para o componente (draft = input nao-controlado; nao havia estado de `error` no original).
- [x] Abrir via `send_update/2` a partir do context menu (`open_mute_duration_dialog` despacha `{:open, nick}`).
- [x] Validar duracao com helper puro — `Commands.Duration.parse/1` (total: invalido → `:permanent`, conforme "blank = permanent"). Nao ha estado invalido a exibir; validacao estrita seria mudanca de produto, fora de escopo.
- [x] Emitir comando final ao parent (`mute_duration_submit` continua no parent, que aplica o mute via `Server` e devolve `:close` ao componente).

## Validacao

- [x] Abrir por context menu preserva target nick (feature test + E2E).
- [x] Confirmar aplica mute com duracao correta (`channel_muted?` no feature test; E2E real mostra "You are muted").
- [x] Cancelar limpa draft (cancel → `:close` → `target_nick: nil`; input nao-controlado some no re-render).
- [x] Dialog fechado nao deixa assign no parent (`mute_duration_dialog` removido do `assign_defaults`).

## Prompt de execucao

Trate como dialog transiente: parent nao deve guardar formulario nem coordenadas.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
- 2026-06-28 — **COMPLETE.** Primeiro dialog migrado via playbook (segundo LiveComponent stateful do app).
  - Arquivos: `live/chat_live/components/mute_duration_dialog.ex` (novo, ~55 linhas), `mute_duration_dialog_test.exs` (novo, componente). Modificados: `context_menu_events.ex` (open/close → `send_update`; alias), `chat_live.ex` (removido assign default + import do function component), `chat_live.html.heex` (→ `<.live_component>`), `channel_moderation_context_menu_feature_test.exs` (flush `render(view)` apos open async).
  - Padrao: adapter (eventos legados no parent) + `send_update` para abrir/fechar; submit fica no parent (precisa de session + `Server.channel_mute`) e devolve `:close`. Contratos 100% preservados (dialog id, `form[phx-submit=mute_duration_submit]`, `data-testid=mute-duration-input`) → **Page Object intacto**.
  - Gotchas novos (incorporados ao playbook): raiz do componente precisa de tag estatica (envolver function component num `<div>`); atribuir `:id` no `mount` para `send_update` so-de-acao nao quebrar.
  - Validacao: `make ci` **9/9**; feature test (5 acoes de moderacao) + 3 testes de componente 0 falhas; **E2E `chat-ui-features-channel` 4/4 verde** (fluxo real de mute: abrir, digitar 30s, OK, escondido, "You are muted"). Zero regressao.
  - Esforco baixo confirma que a receita escala para os ~30 dialogs restantes.
