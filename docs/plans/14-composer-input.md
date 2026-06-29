# Composer And Chat Input Migration

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
