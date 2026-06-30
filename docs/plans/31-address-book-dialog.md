# Address Book Dialog Migration

> **STATUS: COMPLETE (2026-06-30) — the last giant. Full ownership, −16 keys (`assign_defaults` 87 → 71).**
> `RetroHexChatWeb.ChatLive.Components.AddressBookDialog` owns the entire 4-tab mini-app (Contacts, Notify,
> Nick Colors, Control) — tab, the 4 selections, note drafts, palette-edit index, all 7 sub-form flags — and
> runs every domain mutation (`ContactList`/`NickColors`/`IgnoreList`/`NotifyOps`). `address_book_events.ex`
> gutted 446→44 lines (open/close routing); the Notify tab reuses the shared `NotifyOps` helper and
> `notify_events.ex` is retired to 31 lines (just the standalone open trigger). The work bubbles to the parent
> which owns the session read-model + side effects: `{:ab_session, session, kind}` (assign + persist; for
> `:nick_colors` also rebuild `nick_color_fn` + refresh the message stream), `{:ab_status, level, msg}`
> (status/system/error surface), `{:ab_ignore_timer, op, ...}` (debounce timers). `target` threaded through
> the design-system `address_book/1` (tabs via `JS.push(target:)`, tables/crud-buttons/sub-forms via string
> events + `phx-target`); the Nick-Color add sub-form uses `phx-update="ignore"` (in-form color picker
> re-renders the component, like highlight). `make ci` 9/9; component test (6) + `address_book_test` 49/49 +
> `address_book_feature_test` 21/21 (element-based) + `chat-notify`/`chat-ignore-notifications` E2E. See
> PROGRESS.md log (2026-06-30).

## Objetivo

Migrar Address Book para LiveComponent stateful com tabs internas, selecoes e subdialogs proprios.

## Classificação para execução (agentes)

- **Tier:** 🔴 Complexo (gigante + entrelaçado)
- **Dependências:** Compartilha notify com 30.
- **Componente de referência:** Mini-app com 3 tabs (contacts/nick-colors/control) + múltiplos sub-dialogs.
- **Abordagem:** Vários sub-dialogs modal + nick_palette_editing_index; estado compartilhado com 30.
- **Gotchas:** ⚠️ modal-in-modal (mesmo risco de 41) + estado compartilhado.
- **Validação:** `make ci` 9/9 + E2E address-book.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:585`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/address_book.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/address_book_events.ex`
- State atual: `show_address_book`, `address_book_tab`, `contacts_selected`, `nick_colors_selected`, `control_selected`, `selected_contact_note`, `selected_notify_note`, `show_contact_*`, `show_notify_*`, `show_nick_color_*`, `show_control_add_dialog`, `nick_palette_editing_index`.

## Tecnica

Use LiveComponent stateful montado sob demanda. Cada tab deve ser subcomponente ou funcao pura, mas a selecao/drafts ficam no AddressBookComponent. Para listas grandes, use streams por tab.

## Tasks

- [ ] Criar `AddressBookDialogComponent`.
- [ ] Mover tab ativa, selecoes e subdialog state.
- [ ] Separar notify state do `NotifyListDialogComponent`.
- [ ] Receber snapshots de contacts/notify/nick_colors/control.
- [ ] Emitir comandos add/edit/remove por tipo.
- [ ] Atualizar local state apos sucesso ou via update do parent.
- [ ] Avaliar streams em contacts/notify/control.
- [ ] Remover `address_book_events.ex` da pipeline global apos migrar.

## Validacao

- [ ] Contacts add/edit/remove passam.
- [ ] Notify tab nao interfere no Notify List dialog.
- [ ] Nick colors alteram mensagens/nicklist/sidebar.
- [ ] Control/ignore add/remove afeta filtros.
- [ ] Subdialogs travam dialog pai corretamente.
- [ ] Fechar limpa drafts e selecoes transientes.

## Prompt de execucao

Address Book e um mini-app. Nao tente manter todos os drafts no parent; mova o workflow inteiro.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
- 2026-06-30: **COMPLETE — o último gigante.** `Components.AddressBookDialog` é dono das 4 abas + 7
  sub-forms; roda as mutações de domínio e bubbla session/status/timers ao parent (que é dono do
  read-model + efeitos: rebuild do `nick_color_fn`, refresh do stream, persistência, timers de ignore).
  `address_book_events.ex` 446→44 linhas; `notify_events.ex` aposentado p/ 31 linhas (a aba Notify reusa
  `NotifyOps`). −16 chaves do parent. **Threading:** tabs via `JS.push(target:)`, e o resto (tabelas/
  crud-buttons/sub-forms) via eventos STRING + `phx-target` — escolhi string em vez de JS.push pros eventos
  não-tab porque os testes selecionam por `[phx-click='evento']`; com JS.push o phx-click vira um blob
  opaco e os seletores quebram. nick-color-add usa `phx-update="ignore"` (color picker in-form). **Custo de
  teste (§2 em escala):** ~30 testes de mutação convertidos p/ element-based (helpers `ab_click`/`ab_select`/
  `ab_form`/`ab_tab`). Dois aprendizados: (1) os eventos `notify_*` COLIDEM com o dialog standalone (mesmo
  `phx-click`, cid diferente) → escopar o seletor a `#address-book-dialog`; (2) os botões Edit/Remove das
  abas dependem de `@selected_tab == "aba"`, então o teste PRECISA trocar a aba de verdade (via o tab
  trigger), não só assumir que o conteúdo está no DOM. `make ci` 9/9; `address_book_test` 49 +
  `address_book_feature_test` 21 + component test 6. `chat-address-book` O16 falha no main (overlay "Tip").
