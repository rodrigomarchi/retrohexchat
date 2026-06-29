# Topic Bar Migration

## Objetivo

Isolar a barra de topico/modes como componente de contexto ativo, sem calculos no template principal.

## Classificação para execução (agentes)

- **Tier:** ✅ Mecânico (leve/limpeza)
- **Dependências:** Independente. Sem estado.
- **Componente de referência:** Function component / wrapper stateless.
- **Abordagem:** Mover `topic_bar_modes/3` para dentro; reduzir assigns no parent. NÃO precisa ser stateful.
- **Gotchas:** Nenhum (sem estado).
- **Validação:** `make ci` 9/9.

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
- 2026-06-29: **COMPLETE (limpeza, não-stateful).** Movido o cálculo de `topic_bar_modes/3` do `chat_live.ex` (parent) PARA DENTRO do function component `Components.UI.TopicBar` como `mode_badges/2`. O parent agora passa `modes={@current_modes}` (string crua) em vez de `topic_bar_modes(@current_modes, @show_status_tab, @session.active_pm)`; o componente deriva os badges de `variant` + `modes` (status/PM = sem modos; string não-vazia = 1 badge; lista do showcase = passthrough). `attr :modes` mudou de `:list` para `:any` (aceita string crua OU lista do showcase). `topic_bar_modes/3` removido do parent. NÃO virou stateful (sem estado, como o plano indicava). `make ci` 9/9.
