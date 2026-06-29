# Message Row Renderer Migration

## Objetivo

Extrair `render_message/1` do `ChatLive` para componente dedicado de mensagens, com assigns minimos e sem capturar helpers globais desnecessarios.

## Classificação para execução (agentes)

- **Tier:** 🔴→🟡
- **Dependências:** Depende de: 10 (que decide o stream).
- **Componente de referência:** Function component puro por linha.
- **Abordagem:** Precompute campos caros no item do stream (timestamp, nick color, html seguro, flags). Determinístico, sem efeitos.
- **Gotchas:** Não fazer I/O nem assigns no renderer.
- **Validação:** `make ci` 9/9.

## Codigo atual

- Render private function: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.ex:335`
- Usado no stream: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:252`
- Components usados: `chat_message.ex`, `message_reply_block.ex`, `inline_help_card.ex`, `arcade_session_link.ex`, `p2p_invite_card.ex`
- `MessageIndicators` importado em `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.ex:49`

## Tecnica

Use function component puro para cada linha. O componente de viewport decide stream; o row renderer deve ser deterministico. Precompute campos caros no item de stream quando possivel: timestamp formatado, nick color, html seguro ou flags.

## Tasks

- [ ] Criar `MessageRow` em `ChatLive.Components`.
- [ ] Mover `render_message/1`, `message_classes/2` e helpers relacionados para modulo proprio.
- [ ] Evitar passar `Session`; passar `strip_formatting`, `timezone`, `timestamp_format`, `nick_color_fn`.
- [ ] Considerar preformatar timestamp e content ao inserir no stream para reduzir CPU por render.
- [ ] Validar uso de `raw(ChatHelpers.format_content(...))` e sanitizacao.
- [ ] Decidir se `MessageIndicators` deve ser usado ou removido do import.

## Validacao

- [ ] Todos os tipos renderizam: normal, action, system, service, error, notice, inline_help, arcade_link, p2p_invite, deleted, edited, failed.
- [ ] Reply block e retry button continuam acionando eventos.
- [ ] Snapshot/component tests cobrem tipos principais.
- [ ] Novo renderer nao depende de assigns do parent.

## Prompt de execucao

Nao transforme linha de mensagem em LiveComponent por default. Para milhares de mensagens, function component + stream e mais barato, salvo se cada linha tiver estado proprio real.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
