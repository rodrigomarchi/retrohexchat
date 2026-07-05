# Arquitetura de servidor

Status: auditado contra o codebase em 2026-07-05. Decisões fechadas com o
usuário. Pronto para implementação.

## Contexto de domínio

Criar um novo bounded context:

```text
apps/retro_hex_chat/lib/retro_hex_chat/virtual_space.ex
apps/retro_hex_chat/lib/retro_hex_chat/virtual_space/
  policy.ex
  queries.ex
  registry.ex
  service.ex
  session_server.ex
  supervisor.ex
  map.ex
  maps/tavern_cafe_v1.ex
  schema/session.ex
```

O gabarito auditado é `RetroHexChat.Lobby`, que segue exatamente esse layout
(`lobby.ex` + `lobby/{policy,queries,registry,service,session_server,
supervisor,schema/session}.ex`), com `RetroHexChat.P2P` como segundo análogo
(ele adiciona `cleanup_task.ex`, `rate_limiter.ex` e `session_token.ex`).
`Arcade` segue o mesmo espírito mas nomeia diferente (`SoloSessionServer`,
`Schema.SoloSession`) — usar `Lobby` como referência primária. A facade pública
fica em `RetroHexChat.VirtualSpace`; handlers e LiveViews chamam a facade, não
módulos internos.

Decisão fechada (2026-07-05): a fonte canônica dos mapas (colisão, zonas,
assentos, interactables, camadas) vive no domínio Elixir, em
`virtual_space/maps/*.ex` com um `map.ex` de registry/consulta. O cliente JS
recebe o mapa inteiro no payload de join (`space_init`) e não mantém cópia
própria — impossível divergir colisão visual da oficial.

## Schema

Tabela recomendada: `virtual_space_sessions`.

Campos:

- `token :string`, único, até 64 chars;
- `channel_name :string`, canal onde o card foi publicado;
- `creator_id :integer`, required;
- `creator_nick :string`, snapshot do nick no momento da criação;
- `title :string`, nome do espaço;
- `status :string`, default `"pending"`;
- `map_id :string`, default `"tavern_cafe_v1"`;
- `max_participants :integer`, default `20`;
- `last_participant_count :integer`, default `0`;
- `peak_participants :integer`, default `0`;
- `metadata :map`, default `%{}`;
- `activated_at :utc_datetime_usec`;
- `last_activity_at :utc_datetime_usec`;
- `expires_at :utc_datetime_usec`;
- `closed_at :utc_datetime_usec`;
- `closed_reason :string`;
- timestamps.

Índices:

- unique `token`;
- `channel_name/status`;
- `creator_id`;
- `status`;
- `expires_at`;
- `created_at/status` se precisarmos de listagem administrativa.

Anclagem auditada: seguir a migration `20260625200000_create_lobby_sessions.exs`
como gabarito — `token` com `size: 64` + unique index, `creator_id` como FK para
`registered_nicks`, `closed_reason` com `size: 100`. Geração do token igual ao
`Lobby.Service.insert_session/2`:
`Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)`.

O banco guarda auditoria e estado macro. Movimento, posição, presença online e
ocupação ficam em memória no GenServer. `last_participant_count` é um snapshot
para cards/histórico; o resumo vivo deve consultar o processo quando ele existir.

## Estado quente no GenServer

Um `VirtualSpace.SessionServer` por token:

```elixir
%{
  token: token,
  session: session,
  map: map_definition,
  participants: %{
    participant_key => %{
      key: participant_key,
      user_id: user_id,
      nickname: nickname,
      role: :creator | :participant,
      color: color_index,
      avatar: avatar_id,
      joined_at: DateTime.t(),
      last_seen_at: DateTime.t(),
      online?: true,
      channel_pid: pid,
      socket_ref: ref,
      x: integer,
      y: integer,
      dir: "down",
      pose: "standing" | "sitting",
      seat_id: string_or_nil,
      moving?: false,
      input_seq: integer,
      muted?: false,
      zone_id: string_or_nil
    }
  },
  occupancy: %{{tile_x, tile_y} => MapSet.t(participant_key)},
  seats: %{seat_id => participant_key},
  recent_messages: [],
  timers: %{},
  tick_ref: nil
}
```

`participant_key` deve ser estável entre reconnects:

- `registered:<id>` para usuários registrados e identificados.

Se o mesmo `participant_key` entrar de novo, a entrada nova substitui a antiga,
seguindo o comportamento de takeover já existente no chat.

A posição do usuário deve permanecer enquanto a sessão estiver ativa. O
`SessionServer` mantém participantes offline no estado quente até o TTL/close,
permitindo reload/reconnect no mesmo tile. Para reinício do processo, salvar um
snapshot leve de posições em `metadata` em baixa frequência ou em eventos de
leave/map-change, nunca a cada passo.

Participantes não bloqueiam movimento uns dos outros na V1. `occupancy` serve
para escolher spawn livre, calcular proximidade futura e depurar presença; a
colisão de movimento considera mapa, paredes, portas fechadas, balcões, mesas,
cadeiras e objetos estáticos. Isso evita trancar portas/corredores com avatares.
Assentos são exceção: uma cadeira ocupada fica reservada em `seats`, mas isso não
transforma o avatar em obstáculo global.

## APIs públicas

Facade sugerida:

```elixir
VirtualSpace.create_session(creator_context, opts)
VirtualSpace.join_session(token, participant_context)
VirtualSpace.leave(token, participant_key)
VirtualSpace.close_session(token, actor_context, reason)
VirtualSpace.input(token, participant_key, input_payload)
VirtualSpace.interact(token, participant_key, interact_payload)
VirtualSpace.chat_bubble(token, participant_key, text)
VirtualSpace.kick_participant(token, actor_context, target_key, reason)
VirtualSpace.mute_participant(token, actor_context, target_key, muted?)
VirtualSpace.change_map(token, actor_context, map_id)
VirtualSpace.session_summary(token)
VirtualSpace.session_info(token)
```

`creator_context` e `participant_context` devem carregar o que o domínio precisa,
sem acoplar ao socket:

```elixir
%{
  nickname: "alice",
  user_id: 123,
  identified: true,
  channel_name: "#general",
  channel_role: :owner | :operator | :half_operator | :voiced | :regular
}
```

## Policy

Regras recomendadas:

- criar: requer usuário registrado/identificado, canal de origem e permissão para
  postar naquele canal;
- entrar: requer usuário registrado/identificado, sessão não terminal e permissão
  de acesso ao `channel_name` da sessão;
- canal público: qualquer usuário registrado/identificado pode entrar pelo link;
- canal privado/invite-only/restrito: exigir membership/acesso conforme o domínio
  `RetroHexChat.Channels`;
- capacidade: negar se a contagem de participantes ativos no processo atingir
  `max_participants` e o usuário ainda não estiver no espaço;
- server ban: correção auditada — `CheckServerBan` NÃO está na pipeline `:app`
  das rotas LiveView; ele protege apenas as rotas `/chat/session` do
  `SessionController`, onde o `chat_nickname` da sessão HTTP nasce. A proteção
  do espaço vem de exigir sessão identificada (que já passou pelo ban check) +
  policy de domínio. Não adicionar plug novo na rota;
- fechar: criador, admin/server operator ou expiração;
- expulsar/mutar/trocar mapa: criador ou admin/server operator;
- rate limit de criação: reaproveitar
  `RetroHexChat.P2P.RateLimiter.check_session_rate/1`, exatamente como
  `Lobby.Service` já faz (auditado). Não criar rate limiter próprio na V1.

Para a checagem de acesso ao canal, usar `RetroHexChat.Channels.Policy`
(`can_join?/6` com `check_invite/check_key/check_limit/check_registered`),
`Channels.Membership` (`member?/2`, `role/2`) e `Channels.Modes`
(`invite_only?/1`, `registered_only?/1` etc.) — os checks de acesso vivem em
`Policy`, não em `Queries`.

Ignore/block P2P não deve bloquear entrada por link na V1, porque o espaço é
coletivo e pertence a um canal. Não há convite por PM na V1.

## LiveView, Channel e PubSub

Nova LiveView:

```text
apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/space_live.ex
apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/space_live.html.heex
```

Rota (no scope `RetroHexChatWeb.App`, dentro da `live_session :app_locale` com
`on_mount: [{RetroHexChatWeb.Live.PutLocale, :default}]`, pipeline `:app` —
mesmo lugar de `/lobby/:token`, `/solo/:token` e `/arcade/:token/:game_id`):

```elixir
live "/space/:token", SpaceLive
```

Atenção (auditado): o projeto NÃO tem Phoenix Channels hoje. Não existe
diretório `channels/`, não existe `UserSocket`, o endpoint declara apenas
`socket "/live", Phoenix.LiveView.Socket`, e não há `ChannelCase` de teste.
Esta é a primeira Phoenix Channel do projeto — a Fase 1 cria a infra do zero:

```text
apps/retro_hex_chat_web/lib/retro_hex_chat_web/channels/user_socket.ex
apps/retro_hex_chat_web/lib/retro_hex_chat_web/channels/space_channel.ex
apps/retro_hex_chat_web/test/support/channel_case.ex
```

Endpoint (declaração nova, ao lado do `socket "/live"` existente):

```elixir
socket "/socket", RetroHexChatWeb.UserSocket,
  websocket: true,
  longpoll: false
```

Tópico:

```text
"space:#{token}"
```

`SpaceLive` valida a sessão HTTP, usuário identificado, canal de origem e
permissão de entrada; renderiza o shell; e assina um token curto de entrada no
Channel. O runtime do mundo não passa por `push_event`/`pushEvent` do LiveView.

Fluxo:

```text
SpaceLive mount -> assina join_token -> SpaceCanvasHook -> Phoenix Socket ->
SpaceChannel.join("space:<token>", %{join_token}) -> VirtualSpace.join_session
```

Eventos PubSub domínio -> Channel:

- `space_snapshot`;
- `space_participant_joined`;
- `space_participant_left`;
- `space_participant_updated`;
- `space_chat_bubble`;
- `space_zone_changed`;
- `space_interaction`;
- `space_map_changed`;
- `space_participant_kicked`;
- `space_participant_muted`;
- `space_closed`;
- `space_inactivity_warning`.

Eventos Channel -> SessionServer:

- `space_input`;
- `space_chat_bubble`;
- `space_interact`;
- `space_admin_action`;
- `space_leave`.

Eventos Channel -> JS:

- `space_init`;
- `space_snapshot`;
- `space_delta`;
- `space_reconcile`;
- `space_message`;
- `space_modal`;
- `space_admin_notice`;
- `space_closed`.

## Tick e broadcast

Decisão V1: movimento tile-a-tile, evento por input validado, sem tick fixo de
simulação. O servidor aceita no máximo um passo cardinal por participante a cada
`virtual_space_step_ms` (recomendado: 150ms) e publica delta após aceitar ou
rejeitar/corrigir o input.

Tick fixo de 10-12 Hz fica para quando houver movimento contínuo ou efeitos que
precisem de simulação independente de input.

Mesmo sem tick fixo, o servidor deve controlar:

- cooldown mínimo entre passos;
- direção;
- destino adjacente;
- colisão;
- bounds do mapa;
- validade da zona/teleporte.

## Validação de movimento

O cliente nunca deve poder enviar "minha posição agora é x/y" como verdade.
Payload fechado:

```json
{
  "seq": 42,
  "dx": 1,
  "dy": 0,
  "client_time": 123456789
}
```

O servidor responde/publica:

```json
{
  "seq": 42,
  "participants": {
    "registered:123": {
      "x": 14,
      "y": 9,
      "dir": "right",
      "moving": false,
      "zone_id": "main_hall"
    }
  }
}
```

Para click-to-move, o cliente pode calcular path local, mas deve enviar passos
adjacentes. Se enviar destino distante, o servidor rejeita.

## Expiração

Config inicial (padrão auditado: as chaves `lobby_*_timeout` são lidas via
`Application.get_env` e sobrescritas nos testes — seguir igual):

```elixir
config :retro_hex_chat,
  virtual_space_pending_timeout: :timer.minutes(5),
  virtual_space_default_ttl: :timer.hours(2),
  virtual_space_max_ttl: :timer.hours(8),
  virtual_space_max_participants_ceiling: 50,
  virtual_space_step_ms: 150
```

O limite default de participantes NÃO fica em config estática: ele é
configurável pelo admin em runtime via `server_settings` (chave
`"space_max_participants"`), seguindo o padrão auditado de `"max_channels"` em
`Commands.Handlers.Join` — `Services.Queries.get_setting/1` com fallback em
atributo de módulo — e whitelist da chave em
`Commands.Handlers.Admin.Server.validate_setting_value/2`.

Regra V1:

- se ninguém entra em 5 minutos, `expired`;
- depois de ativo, expira no `expires_at` criado junto com o link;
- atividade não renova o TTL;
- criador ou admin pode encerrar antes do TTL;
- encerrar notifica chat/card com `token` para refresh ao vivo.

Se quisermos "expira depois de inatividade", isso é outra decisão de produto e
deve ser separado do TTL do link.

## Recuperação

Ao reiniciar o servidor:

- sessões não terminais com `expires_at` no futuro podem ser retomadas quando
  alguém abrir o link;
- o `Service.join_session/2` inicia o child se o token existe mas o processo não;
- sessões vencidas são marcadas `expired` antes de permitir entrada.

Um cleanup periódico deve seguir o padrão auditado de
`RetroHexChat.P2P.CleanupTask` (`p2p/cleanup_task.ex`): GenServer com intervalo
configurável que expira sessões vencidas via `Queries`, pulando sessões cujo
processo ainda está registrado no Registry.
