# Delete Confirm Dialog Migration

## Objetivo

Migrar confirmacao de delete de mensagem para componente local ao MessageViewport.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:546`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/delete_confirm_dialog.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/core_events.ex`
- State atual: `delete_confirm`.

## Tecnica

Como delete nasce de uma mensagem, o estado `message_id` deve ficar no `MessageViewportComponent` ou em um dialog filho dele. Parent recebe apenas `{:delete_message, id}`.

## Tasks

- [x] Mover `delete_confirm` para um LiveComponent stateful — `ChatLive.Components.DeleteConfirmDialog` (dono de `message_id`). NB: o plano original previa dobrar isto no `MessageViewport`; como o viewport ainda nao foi extraido (plano 10 deferido), virou um componente standalone. Quando o viewport sair, pode ser absorvido.
- [x] Abrir por evento do context menu/message row — `ctx_chat_delete` + caminho de edit-vazio → `send_update {:open, message_id}`.
- [x] Confirmar envia comando ao parent/contexto — `confirm_delete` fica no parent (precisa de session + `Service`); o botao confirm carrega o `message_id` via `JS.push(value:)`.
- [x] Atualizar stream com mensagem deletada apos resultado — `Service.delete_message` faz broadcast; o PubSub handler reinsere a linha como placeholder deletado (comportamento preservado; E2E O10 confirma).
- [x] Fechar limpa target — `cancel_delete`/sucesso → `send_update :close` → `message_id: nil`.

## Validacao

- [x] Delete em canal e PM funciona (`confirm_delete` ramifica em `active_pm`, preservado; E2E O10 canal).
- [x] Cancelar nao altera stream (cancel so fecha).
- [x] Confirmar atualiza a linha deletada sem resetar lista (PubSub `stream_insert`, E2E O10 placeholder para ambos os usuarios).
- [x] Sem assign `delete_confirm` no parent (removido do `assign_defaults`).

## Prompt de execucao

Delete confirm pertence ao viewport porque o target e uma mensagem renderizada ali.


## Progress Log

- 2026-06-28 — **COMPLETE.** Quarto LiveComponent stateful (terceiro dialog).
  - Arquivos: `live/chat_live/components/delete_confirm_dialog.ex` (novo), `delete_confirm_dialog_test.exs` (novo). Modificados: `core_events.ex` (2 caminhos de abertura → `open_delete_confirm`; `confirm_delete` le `message_id` de params; cancel → `close_delete_confirm`; import + alias), `chat_live.ex` (removido default + import), `chat_live.html.heex` (→ `<.live_component>`).
  - Novo padrao (confirm dialog COM target): o componente e dono do `message_id`; o botao confirm carrega o id via `JS.push("confirm_delete", value: %{message_id: @message_id})`, entao o parent (que tem session + `Service`) le de params. Inteiro preservado no round-trip (teste de componente assertou `"42"`; E2E confirma delete real).
  - Gotcha novo: funcoes privadas adicionadas num modulo de eventos devem ir na secao de helpers, NAO entre clausulas `handle_event/3` (senao warning "clauses should be grouped"). Incorporado ao playbook.
  - Validacao: `make ci` **9/9**; 3 testes de componente; **E2E 5/5** (O10 delete em canal mostra placeholder para ambos; R10 edit-vazio abre confirm e cancel restaura). Zero regressao; Page Object intacto.

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
