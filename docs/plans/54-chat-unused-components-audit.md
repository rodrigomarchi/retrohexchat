# Chat Unused Components Audit

## Objetivo

Auditar componentes de `components/ui/chat` importados ou existentes que nao tem ownership claro no template atual.

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


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
