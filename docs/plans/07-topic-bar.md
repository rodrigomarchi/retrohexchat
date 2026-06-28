# Topic Bar Migration

## Objetivo

Isolar a barra de topico/modes como componente de contexto ativo, sem calculos no template principal.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:142`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/chat/topic_bar.ex`
- Helpers: `topic_bar_modes/3` em `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.ex:1085`
- State atual: `current_topic`, `current_modes`, `show_status_tab`, `session.active_pm`, `session.active_channel`.

## Tecnica

Use function component ou LiveComponent stateless wrapper. Migrar para stateful somente se houver edicao inline de topico ou dropdown de modes.

## Tasks

- [ ] Criar `TopicBarComponent` com assign pequeno `active_context`.
- [ ] Mover `topic_bar_modes/3` para modulo do componente.
- [ ] Nao passar `Session` inteira.
- [ ] Preparar variants `:status`, `:pm`, `:channel`.
- [ ] Se futuramente houver edicao inline, adicionar `phx-target={@myself}`.

## Validacao

- [ ] Trocar canal atualiza topico e modos.
- [ ] PM e status ocultam modos corretamente.
- [ ] Mudanca de topico via PubSub atualiza somente topic bar e mensagens necessarias.

## Prompt de execucao

Mantenha simples: esta migracao e mais sobre reduzir dependencia do template do que criar estado novo.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
