# Chat Unused Components Audit

## Objetivo

Auditar componentes de `components/ui/chat` importados ou existentes que nao tem ownership claro no template atual.

## Classificação para execução (agentes)

- **Tier:** 🧹 Auditoria/limpeza
- **Dependências:** Independente. NÃO é migração.
- **Componente de referência:** —
- **Abordagem:** Listar/remover não-usados (chat_layout, color_picker, message_indicators, tab_bar, history_search, scroll_loader, etc.).
- **Gotchas:** Confirmar zero uso (chat + showcase) antes de remover.
- **Validação:** `make ci` 9/9.

## Codigo atual

- Imports chat: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.ex:25`
- Template principal: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex`
- Componentes no catalogo:
  - `chat_layout.ex`
  - `color_picker.ex`
  - `message_indicators.ex`
  - `tab_bar.ex`
  - `history_search.ex`
  - `scroll_loader.ex`
  - `inline_help_card.ex`
  - `arcade_session_link.ex`
  - `p2p_invite_card.ex`
  - `message_reply_block.ex`

## Tecnica

Classificar cada componente como:

- `pure`: function component usado dentro de outro componente.
- `owned`: deve virar parte de uma ilha stateful.
- `dead`: remover import/arquivo se sem uso.
- `showcase-only`: manter fora da migracao de chat.

## Tasks

- [ ] Rodar `rg` para cada componente listado.
- [ ] `scroll_loader` deve ir para MessageViewport.
- [ ] `history_search` deve ir para Composer ou ser removido se oculto permanentemente.
- [ ] `message_reply_block`, `inline_help_card`, `arcade_session_link`, `p2p_invite_card` ficam sob MessageRow.
- [ ] `color_picker` deve ser componente puro compartilhado por Nicklist/AddressBook/Highlight.
- [ ] `message_indicators` deve ser usado pelo MessageRow ou removido.
- [ ] `chat_layout` e `tab_bar` precisam de decisao: substituir layout atual ou remover se legado/showcase.

## Validacao

- [ ] Nenhum import sem uso permanece em `ChatLive`.
- [ ] Componentes puros continuam testados.
- [ ] Componentes mortos sao removidos em commit separado.
- [ ] Showcase continua compilando se depender deles.

## Prompt de execucao

Depois das migracoes principais, faca esta auditoria para limpar imports e evitar que componentes antigos mantenham acoplamento invisivel.


## Decisão final (auditoria 2026-06-29)

| Componente | Classificação | Evidência / próximo dono |
|------------|---------------|--------------------------|
| `chat_layout.ex` | **showcase-only** | Só `showcase_live/chat/chat_layout_page.ex`. O chat tem layout próprio no `chat_live.html.heex`. |
| `tab_bar.ex` | **showcase-only** | Usado só por `chat_layout.ex` (showcase) + páginas showcase. O chat usa `IrcTabs` (`irc_tab_bar`/`irc_tab_item`). |
| `color_picker.ex` | **pure (compartilhado, em uso)** | Usado por `highlight_dialog`, `address_book`, `nicklist_context_menu`, `context_menu_events`, `helpers/session`. Já é o componente puro compartilhado pedido pela task. |
| `message_indicators.ex` | **pure (em uso)** | Importado em `chat_live.ex`; `edited_tag`/`deleted_placeholder`/`retry_button` renderizados no fluxo de mensagens. Vai p/ MessageRow no plano 12. |
| `history_search.ex` | **owned (em uso)** | Renderizado pelo `Components.SearchBar` (plano 09) + heex. Já está sob o island de busca. |
| `scroll_loader.ex` | **owned (em uso)** | No `chat_live.html.heex`. Vai p/ MessageViewport no plano 10/56. |
| `inline_help_card.ex` | **owned (em uso)** | `chat_live.ex` (fluxo de mensagens). Fica sob MessageRow/Viewport (plano 10/12). |
| `arcade_session_link.ex` | **owned (em uso)** | idem. |
| `p2p_invite_card.ex` | **owned (em uso)** | idem. |
| `message_reply_block.ex` | **owned (em uso)** | idem. |

**Resultado: ZERO componentes mortos / ZERO imports sem uso em `ChatLive`.** As reatribuições de ownership (`scroll_loader`→Viewport, `message_*`→MessageRow, etc.) são **dependentes dos planos 10 (viewport) / 12 (row) / 14 (composer)** — feitas quando esses planos (🔴) entrarem no escopo, não agora.

## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
- 2026-06-29: **COMPLETE (auditoria).** Classificados os 10 componentes (ver tabela). `chat_layout`/`tab_bar` = showcase-only; `color_picker`/`message_indicators` = pure em uso; os demais = owned em uso (donos finais sob viewport/row/composer — planos 10/12/14). Zero mortos, zero imports órfãos. Sem mudança de código (auditoria). `make ci` 9/9.
