# Composer And Chat Input Migration

> **STATUS: COMPLETE (2026-06-30) — done together with 15 + 16 as one island.**
> `RetroHexChatWeb.ChatLive.Components.Composer` owns the whole bottom region (autocomplete dropdown,
> syntax tooltip, formatting toolbar, reply bar, typing indicator, chat input) and ALL composer state
> (~15 keys out of `assign_defaults`). Form DOM events use `phx-target={@myself}`; the AutocompleteHook
> keeps pushing to the parent, which forwards via `send_update` adapters (zero JS changes). On submit the
> component bubbles `{:composer_dispatch, text, reply_to}` / `{:composer_submit_edit, content}` /
> `:composer_empty_edit` to the parent `handle_info` (Parser/CommandDispatch/Service stay on the LiveView).
> `edit_mode_message_id` stays parent (MessageViewport reads it); `reply_to` is a `send_plain_message/4`
> param; Escape/notice uses a parent `notice_active` boolean mirror. `make ci` 9/9. See PROGRESS.md log
> (2026-06-30) for the full findings.

## Objetivo

Migrar input, historico, envio, modo action/notice, reply/edit e paste para um componente stateful dono do fluxo de composicao.

## Classificação para execução (agentes)

- **Tier:** 🔴 Complexo (central)
- **Dependências:** Bloqueia: 15, 16. Paste (46) já feito (paste_* parcialmente no PasteConfirmDialog).
- **Componente de referência:** LiveComponent `@myself`.
- **Abordagem:** input_changed/send_input/history/toggles no componente; sobe só comandos semânticos (send msg/PM, slash, edit, paste).
- **Gotchas:** Muitos estados (reply/edit/action_mode/notice_target); command_dispatch no parent.
- **Validação:** `make ci` 9/9 + E2E send/edit/reply/paste.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:354`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/chat/chat_input.ex`
- Command dispatch: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/command_dispatch.ex`
- Core events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/core_events.ex`
- State atual: `input`, `history_index`, `command_history`, `recent_commands`, `action_mode`, `notice_target`, `input_error`, `reply_to`, `edit_mode_message_id`, `edit_original_input`, `paste_*`.

## Tecnica

Use LiveComponent stateful com `phx-target={@myself}` para `input_changed`, `send_input`, history navigation e toggles. O componente envia ao parent apenas comandos semanticos: send channel message, send PM, run slash command, edit message, paste lines.

## Tasks

- [ ] Criar `ComposerComponent`.
- [ ] Mover estado de input e historico para o componente.
- [ ] Mover `AutocompleteHook`, `CharCounterHook` e `PasteHook` para dentro dele.
- [ ] Separar parsing de comando em modulo puro reaproveitavel.
- [ ] Encapsular pending message local ou emitir evento para MessageViewport.
- [ ] Integrar reply/edit com updates recebidos do MessageViewport ou parent.
- [ ] Remover eventos quentes da pipeline global.

## Validacao

- [ ] Digitar nao aciona pipeline global extensa.
- [ ] Enter envia mensagem/command corretamente.
- [ ] Historico up/down funciona.
- [ ] Action mode, notice mode, reply, edit e retry continuam funcionando.
- [ ] Paste grande abre confirmacao e respeita flood warning.
- [ ] Input nao perde foco em updates de mensagem.

## Prompt de execucao

Composer e componente quente. Priorize reduzir roundtrips e assigns no parent antes de mexer no comportamento de comandos.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
- 2026-06-29: `in_progress` (junto com plano 16). Investigação completa da superfície (registrada aqui para a próxima volta). Decisão de arquitetura:
  - **`Components.Composer` (LiveComponent)** dona de: `input`, `command_history`, `history_index`, `recent_commands`, `action_mode`, `notice_target`, `input_error`, `reply_to`, `edit_original_input`, `autocomplete_*` (visible/mode/command/results/filter/selected), `syntax_tooltip`, `command_help_level`. Renderiza chat_input + autocomplete dropdown + syntax_tooltip + reply_bar.
  - **Fica no parent (shared/orquestrador):** `edit_mode_message_id` (o MessageViewport lê para a classe `--editing`). O composer recebe como context (passthrough) e sinaliza enter/exit edit ao parent.
  - **`input_changed`/`send_input`/teclas (form/textarea) → `@myself`** (via `phx-target` no chat_input). `send_input` computa `input_for_mode` (prefixo /me ou /notice), atualiza a própria history, reseta-se, e **sobe um comando semântico ao parent via `send(self(), {:composer_dispatch, text, reply_to})`** (ou `{:composer_submit_edit, msg_id, content}`); um hook `handle_info` no parent faz `Parser.parse` + `CommandDispatch` (session/server/viewport). Edit submit detecta edit via `edit_mode_message_id` passthrough.
  - **`AutocompleteHook` JS:** usa `pushEventTo(this.el, ...)` para os eventos internos do composer (autocomplete_query/close/navigate/select_current, tab_complete, syntax_tooltip_query/dismiss, history_navigate, recent_commands_loaded, input_changed do history-search) e `pushEvent` para os do parent (pm_typing/pm_stop_typing, edit_last_message, cancel_edit). `handleEvent` (set_input/clear_input/enter_edit_mode/exit_edit_mode/focus_input/insert_emoji/tab_matches) é global → continua funcionando de qualquer emissor.
  - **Acoplamentos de fronteira a religar:** (1) `command_dispatch` lê `socket.assigns[:reply_to]` → receber `reply_to` como param do dispatch bubble; (2) `context_menu_events:799` seta `notice_target`/`input` → `send_update(Composer, {:start_notice, nick})`; (3) `keyboard_events` Escape map lê `notice_target` (mapa de dismissal) → o composer é dono, mas o parent precisa coordenar Escape: avaliar manter um espelho mínimo OU o composer trata Escape-notice localmente; (4) resets de troca de contexto em `core_events`(switch_channel), `pm.ex`, `channel.ex` → `send_update(Composer, :reset_modes)`; (5) `edit_last_message` (parent) seta `edit_mode_message_id` + manda conteúdo ao composer; `cancel_edit` (parent) limpa + manda restore.
  - **Validação exigida:** `make ci` 9/9 + E2E send/edit/reply/paste/history/autocomplete/notice/action em canal E PM.
