# ChatLive Orchestrator Migration

## Objetivo

Transformar `RetroHexChatWeb.App.ChatLive` em um orquestrador fino. Ele deve cuidar de sessao, PubSub, autorizacao global, subscriptions e coordenacao entre ilhas stateful. Ele nao deve ser dono de estado de UI especifico de mensagens, input, nicklist, dialogs, context menus, autocomplete ou admin console.

## Codigo atual

- LiveView principal: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.ex`
- Template monolitico: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex`
- Estado concentrado em `assign_defaults/2`: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.ex:638`
- Streams atuais inicializados no parent: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.ex:917`
- Hook pipeline atual: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.ex:517`

## Tecnica

Use `Phoenix.LiveComponent` stateful para cada ilha de UI com estado proprio. O parent passa identidade minima, contexto ativo e callbacks. Atualizacoes vindas de PubSub devem ser roteadas pelo parent para componentes com `send_update/3` ou mensagens padronizadas.

## Estado que deve sair do parent

- Mensagens: `oldest_message_id`, `has_more`, `loaded_message_count`, `loading_more`, `chat_clear_token`.
- Composer: `input`, `history_index`, `command_history`, `action_mode`, `notice_target`, `reply_to`, `edit_mode_message_id`.
- Autocomplete/tooltip/emoji/search.
- Nicklist: `channel_users`, estado de menu e color picker.
- Dialogs: todos os `show_*`, drafts, selected items e errors especificos.
- Admin/bot/url catcher/timers: todos os assigns com prefixo proprio.

## Tasks

- [x] Criar namespace `RetroHexChatWeb.ChatLive.Components`.
- [ ] Extrair `ChatLive` para renderizar componentes stateful em vez de function components com muitos assigns.
- [ ] Definir contratos de mensagem do parent para filhos, por exemplo `{:chat_message, :append, item}` e `{:nicklist, :reset, users}`.
- [ ] Remover imports de componentes que forem usados apenas dentro dos novos componentes.
- [x] Criar struct ou modulo para contexto global minimo, por exemplo `%ChatContext{nickname, active_channel, active_pm, timezone, identified, admin?}`.
- [ ] Manter subscriptions e cleanup no parent ate que um componente prove que precisa assinar diretamente.
- [ ] Substituir `assign_defaults/2` por defaults globais pequenos e defaults locais em cada componente.
- [ ] Medir tamanho de assigns do parent antes/depois em dev.

## Validacao

- [ ] `ChatLive` continua montando, reconectando e fazendo takeover de sessao.
- [ ] Entrar, sair, trocar nick, trocar canal, PM e reconnect continuam funcionando.
- [ ] O parent nao contem estado de dialog fechado.
- [ ] O parent nao contem stream de mensagens.
- [ ] O parent renderiza com assigns globais pequenos e estaveis.
- [ ] Testes LiveView existentes passam.
- [ ] Criar teste novo que abre chat, envia mensagem e confirma que o componente de mensagens recebe update sem resetar todo o template.

## Prompt de execucao

Migre primeiro a fronteira, nao a funcionalidade. Crie componentes vazios ou wrappers stateful com a mesma UI, mova assigns por componente, preserve comportamento e so depois otimize streams e handlers internos.

## Progress Log

### 2026-06-27 — Fronteira: namespace + ChatContext

Escopo: estabelecer a fronteira fundacional do orquestrador antes de mover
qualquer estado de UI. Slice vertical pequeno e sem mudanca de contrato publico.

Arquivos tocados:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components.ex`
  (novo) — modulo-ancora do namespace `RetroHexChatWeb.ChatLive.Components`.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/chat_context.ex`
  (novo) — struct `%ChatContext{}` com `from_session/2` e os helpers de
  autorizacao `admin?/1`, `admin_only?/1`, `root_admin?/1` (fonte unica de
  verdade).
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.ex` —
  helpers privados `admin?/1`, `admin_only?/1`, `root_admin?/1` agora delegam a
  `ChatContext`; alias `ServerRoles` removido (sem uso direto), alias
  `ChatContext` adicionado. Comportamento identico ao anterior.
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/chat_context_test.exs`
  (novo) — teste unit cobrindo mapeamento de identidade e semantica das tres
  flags de autorizacao (incl. `root_admin?` exige `identified`).

Validacao executada:

- `mix compile --warnings-as-errors` — limpo.
- `mix test .../chat_live/chat_context_test.exs` — 5 testes, 0 falhas.
- `mix test .../server_administration_feature_test.exs --include liveview_feature`
  — 25 testes, 0 falhas (confirma que a delegacao preserva o gating admin).
- `mix format` + `mix credo` nos arquivos novos — sem issues.

Pendente neste plano: extracao real de componentes stateful (mensagens,
composer, nicklist, dialogs), contratos de mensagem parent→filho, e medicao de
tamanho de assigns. `assign_defaults/2` permanece intacto por ora.

Proximo passo: comecar a mover estado de UI auto-contido para um primeiro
LiveComponent stateful (candidato de baixo risco: search bar ou connection
status), seguindo a ordem do README, ou avancar para o plano 02
(event-routing) que mapeia ownership de eventos.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
