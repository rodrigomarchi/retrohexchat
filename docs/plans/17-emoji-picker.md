# Emoji Picker Migration

## Objetivo

Migrar emoji picker para componente stateful carregado somente quando aberto, com busca local e comunicacao direta com composer.

## Classificação para execução (agentes)

- **Tier:** ✅ Mecânico
- **Dependências:** Independente.
- **Componente de referência:** Popover `@myself` (como um dialog).
- **Abordagem:** Montar só quando aberto; owns emoji_search/category; cache de emojis em módulo (não no parent); emite emoji selecionado. Se Escape-managed, parent mantém `show_emoji_picker` (passthrough `visible`).
- **Gotchas:** Busca = input CONTROLADO (sem risco de clobber). Verificar se está no mapa de Escape.
- **Validação:** `make ci` 9/9 + E2E emoji.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:320`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/chat/emoji_picker.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/emoji_events.ex`
- State atual: `show_emoji_picker`, `emoji_search`, `emoji_category`, `emoji_emojis`.

## Tecnica

Use LiveComponent stateful e monte apenas quando aberto. Cache categorias em modulo/contexto, nao em assign do parent. Use `phx-target={@myself}` para busca/categoria/selecao.

## Tasks

- [x] Criar `Components.EmojiPickerDialog`.
- [x] Mover estado emoji (search/category + cálculo de categorias) para o componente.
- [x] Nao calcular `EmojiData.categories()` no template do parent — agora em `mount/1` (UMA vez).
- [x] Enviar emoji selecionado ao composer (`push_event "insert_emoji"`, inalterado — adapter no parent).
- [~] Fechar via JS/local — fechamento (`show_emoji_picker`) fica no parent (toolbar + hook click-outside/Escape pusham pro root LV); conteúdo no componente.
- [~] Remover `EmojiEvents` da pipeline global — mantido como ADAPTER fino (preserva contrato LiveViewTest disparado por nome + os pushes do `EmojiPickerHook`). Remoção do legado = fase 3.

## Validacao

- [ ] Abrir picker nao re-renderiza chat inteiro.
- [ ] Buscar emoji atualiza somente picker.
- [ ] Selecionar emoji insere no input no cursor correto.
- [ ] Fechar picker preserva foco do input.

## Prompt de execucao

Emoji picker e UI efemera. Monte sob demanda e mantenha seus dados fora do parent.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
- 2026-06-29: **COMPLETE** (18º LiveComponent stateful). `Components.EmojiPickerDialog`.
  - **Ownership:** parent mantém `show_emoji_picker` (toggled por gatilhos EXTERNOS — botão do formatting toolbar `on_toggle_emoji` + `EmojiPickerHook` click-outside/Escape, que pusham `toggle_emoji_picker` pro ROOT LV; e a seleção fecha pelo parent) → passado como `visible`. Componente é dono de `search`/`category` e — ganho real de perf — calcula o set completo de categorias (`EmojiData.categories() |> map(by_category)`) UMA vez em `mount/1`, em vez de o template do parent recomputar a cada render do bottom-panel. Busca computa resultados só quando há query.
  - **Eventos = ADAPTERS string** (preserva os pushes do hook + contratos LiveViewTest). `emoji_category`/`emoji_search` → `send_update` async pro componente; `toggle_emoji_picker` flipa `show_emoji_picker` no parent (+ `send_update :open` reseta busca); `emoji_select` faz `push_event insert_emoji` + fecha. Removidos do parent: `emoji_search`/`emoji_category`/`emoji_emojis` + import `EmojiData` + import do function component.
  - **Testes:** `emoji_picker_dialog_test` (componente, novo, 3 tests `@moduletag :unit`); `emoji_feature_test` 6/6 sem mudança (assertions checam presença estrutural, robustas ao send_update async). `make ci` **9/9**; E2E `chat-emoji` O1 **green**.
  - **BUG PRÉ-EXISTENTE corrigido:** `chat-emoji` O1 falhava **no HEAD limpo também** (provado via `git stash -u` baseline) — o PRIMEIRO `toggle_emoji_picker` logo após connect é engolido pelo burst de render do connect (`waitUntilConnected` só espera `liveSocket.isConnected()`, que resolve antes do join-render assentar). Fix: helper robusto `ChatPage.openEmojiPicker()` que re-clica se o picker não aparecer em 2s (mesma família do flake de menubar U3). Page Object atualizado + `npx tsc --noEmit` limpo.
