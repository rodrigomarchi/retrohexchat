# Hidden Hooks Migration

> **STATUS: COMPLETE (2026-06-30).** Every component-specific hook moved into its owning island
> as that island was extracted (`SearchHighlightHook` → SearchBar, `ScrollHook` → MessageViewport,
> `NicklistHook` → Nicklist, `ConnectionStatusHook` → ConnectionStatus, `EmojiPickerHook` →
> EmojiPickerDialog, `FormatToolbarHook`/`CharCounterHook`/`AutocompleteHook` → Composer,
> `ConversationsHook` → Conversations, `URLCatcherHook` → UrlCatcherDialog). The final straggler,
> `PasteHook` (listens for multi-line paste on `#chat-input`), moved into the `Composer` island in
> this plan. The hooks that REMAIN as hidden divs in the parent are genuinely document-global and
> correctly stay: `ShortcutDispatcherHook` (global keymap), `SoundHook` (audio), `TitleFlashHook`
> (browser tab title), `NickChangeFormHook` + the `nick-change-session-form` (a full-page session
> re-auth POST, not the NickChangeDialog draft), and `ViewportDetectHook` (reads `window.innerWidth`
> and sets the parent-owned layout flags `show_conversations`/`show_nicklist` — a shell/layout
> concern the parent owns, not an island's). `make ci` 9/9 + `chat-paste` E2E. See PROGRESS.md log.

## Objetivo

Revisar hooks ocultos no topo do template e separar hooks globais indispensaveis de hooks que pertencem a componentes especificos.

## Classificação para execução (agentes)

- **Tier:** 🔴 Complexo
- **Dependências:** Depende de: 09, 10/11, 14 e dialogs (cada hook segue o componente dono). NÃO independente.
- **Componente de referência:** —
- **Abordagem:** Mover cada hook global para o componente dono; `phx-update="ignore"` para DOM controlado pelo hook.
- **Gotchas:** Não migrar hooks em bloco — um por vez, junto do componente dono.
- **Validação:** `make ci` 9/9 + E2E do componente dono.

## Codigo atual

- Hidden hooks no template: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:1`
- Main container `SoundHook`: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:25`
- Hooks citados: `TitleFlashHook`, `NickChangeFormHook`, `SearchHighlightHook`, `ViewportDetectHook`, `ShortcutDispatcherHook`, `PasteHook`, `SoundHook`.

## Tecnica

Use hooks globais apenas quando eles realmente precisam do documento inteiro. Hooks que pertencem a input, search, messages ou dialogs devem ficar dentro do componente dono. Use `phx-update="ignore"` para DOM controlado totalmente pelo hook.

## Tasks

- [x] Inventariar cada hook JS e seus eventos `push_event`.
- [x] Manter no parent apenas `ShortcutDispatcherHook`, `SoundHook`, `TitleFlashHook`,
  `NickChangeFormHook` e `ViewportDetectHook` (todos document-global — ver nota de status).
- [x] Mover `SearchHighlightHook` para Search/MessageViewport (feito no tail do plano 09 → SearchBar).
- [x] Mover `PasteHook` para Composer.
- [x] ~~Mover `NickChangeFormHook`~~ — fica global: dirige o `nick-change-session-form` (POST de
  re-auth de página inteira p/ `/chat/session`), que é fluxo global de troca de sessão, não o draft
  do NickChangeDialog.
- [x] ~~Mover `ViewportDetectHook` para layout shell~~ — fica global: seta os flags de layout
  `show_conversations`/`show_nicklist` do parent (coordenação parent-owned, não de ilha).
- [x] Documentar eventos JS emitidos/recebidos por hook (inline + nota de status).
- [x] Remover hidden divs que ficarem sem uso (PasteHook saiu do template do parent).

## Validacao

- [ ] Nenhum hook especifico de componente permanece como hidden div global.
- [ ] Paste, atalhos, troca de nick, som, flash de titulo e search highlight continuam funcionando.
- [ ] Hooks nao sao remontados sem necessidade durante updates de mensagens.
- [ ] Elementos com `phx-update="ignore"` nao dependem de HTML re-renderizado pelo server.

## Prompt de execucao

Comece pelo inventario dos hooks em assets JS. Depois mova um hook por vez para o componente dono, mantendo o mesmo id quando testes dependem dele.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
- 2026-06-30: **COMPLETE.** A maior parte foi feita por tabela: cada hook component-específico migrou
  junto com sua ilha durante a extração (Search/Scroll/Nicklist/ConnectionStatus/Emoji/Format/
  CharCounter/Autocomplete/Conversations/URLCatcher). O último straggler, `PasteHook` (intercepta
  paste multi-linha no `#chat-input`), saiu do template do parent e foi pro render da ilha `Composer`
  — co-locado com o input que ele controla. **Comportamento preservado:** o `pushEvent("paste_lines")`
  do hook continua roteando pro ROOT LiveView (hooks usam `pushEvent`, não `pushEventTo`), tratado por
  `core_events` → `send_update` pra ilha PasteConfirmDialog; o JS segue usando `getElementById("chat-input")`
  (zero mudança no JS). Os hooks restantes no parent são genuinamente globais e ficam: `ShortcutDispatcherHook`,
  `SoundHook`, `TitleFlashHook`, `NickChangeFormHook` (form de re-auth de sessão) e `ViewportDetectHook`
  (seta flags de layout parent-owned). `make ci` 9/9; JS hook test (PasteHook isolado) + `chat-paste` E2E.
