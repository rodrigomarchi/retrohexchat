# Hidden Hooks Migration

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

- [ ] Inventariar cada hook JS e seus eventos `push_event`.
- [ ] Manter no parent apenas `ShortcutDispatcherHook`, `SoundHook` e talvez `TitleFlashHook`.
- [ ] Mover `SearchHighlightHook` para Search/MessageViewport.
- [ ] Mover `PasteHook` para Composer.
- [ ] Mover `NickChangeFormHook` para NickChangeDialog ou para fluxo global de troca de sessao.
- [ ] Mover `ViewportDetectHook` para layout shell se ele altera somente layout.
- [ ] Documentar eventos JS emitidos/recebidos por hook.
- [ ] Remover hidden divs que ficarem sem uso.

## Validacao

- [ ] Nenhum hook especifico de componente permanece como hidden div global.
- [ ] Paste, atalhos, troca de nick, som, flash de titulo e search highlight continuam funcionando.
- [ ] Hooks nao sao remontados sem necessidade durante updates de mensagens.
- [ ] Elementos com `phx-update="ignore"` nao dependem de HTML re-renderizado pelo server.

## Prompt de execucao

Comece pelo inventario dos hooks em assets JS. Depois mova um hook por vez para o componente dono, mantendo o mesmo id quando testes dependem dele.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
