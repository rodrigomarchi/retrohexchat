# 042 — Camada Administrativa de Comandos

## Contexto

O RetroHexChat precisa de uma camada administrativa completa de comandos inline no chat, seguindo a filosofia IRC: administração acontece DENTRO do chat via comandos `/admin`, não em dashboard separado. O documento de discovery original (`docs/discovery/retro-hex-chat-admin-commands.md`) foi analisado e filtrado — toda a seção de federação foi descartada (não existe no sistema), assim como setup wizard, dashboard visual, scoped admins, e sessão admin com TTL/senha separada.

Cada comando é uma feature completa de ponta a ponta: parsing → validação → permissão → ação no domínio → persistência → broadcast PubSub → reação na UI → feedback textual → help topic.

---

## Discovery: Arquitetura Atual do Sistema

### Sistema de Comandos

Toda a infraestrutura de comandos já existe e é madura:

- **Behaviour:** `RetroHexChat.Commands.Handler` (`apps/retro_hex_chat/lib/retro_hex_chat/commands/handler.ex`)
  - Callbacks: `execute/2`, `validate/1`, `help/0`, `category/0`, `syntax_definition/0`
  - Context type: `%{nickname, active_channel, channels, identified, operator_in, half_operator_in, is_admin, is_server_operator}`

- **Registry:** `commands/registry.ex` — mapa `"command_name" => Handler.Module`. Atualmente 47 comandos registrados.

- **Dispatcher:** `commands/dispatcher.ex` — `dispatch/3` faz lookup no Registry, roda `validate/1` e depois `execute/2`.

- **Web layer dispatch:** `chat_live/command_dispatch.ex` — `dispatch_command/5` constrói o context a partir do session + ServerRoles + Server.get_state, tenta alias expansion, chama Dispatcher, e roteia o resultado via `handle_dispatch_result/3`.

- **Resultado types:**
  - `{:ok, :system, %{content: text}}` → mensagem ephemeral para o user
  - `{:ok, :ui_action, :action_atom, payload}` → roteado para `UiActionHandlers` → delega para submódulos (`UiActions.Core`, `UiActions.Notify`, etc.)
  - `{:error, msg}` → mensagem de erro

- **UiActionHandlers** (`chat_live/ui_action_handlers.ex`): Particiona actions em listas compile-time (`@core_actions`, `@notify_actions`, etc.) e delega para o submódulo correto.

### Fluxo Completo de um Comando (exemplo: `/kick`)

```
User types: /kick troll Spamming
    │
    ▼ ChatLive.handle_event("send_input")
    ▼ CommandDispatch.dispatch_command/5
        builds context (operator_in via Server.get_state per channel)
        Dispatcher.dispatch("kick", ["troll","Spamming"], context)
            │
            ▼ Registry.lookup("kick") → Handlers.Kick
              Handlers.Kick.execute(["troll","Spamming"], context)
                - require_channel → "#general"
                - require_kick_privilege → operator_in check
                - returns {:ok, :ui_action, :kick_user, %{channel, target, reason}}
            │
            ▼ handle_dispatch_result → UiActionHandlers → UiActions.Core
                Server.kick("#general", "myop", "troll", "Spamming")
                    GenServer.call(via("#general"), {:kick, ...})
                        │
                        ▼ handle_call({:kick,...}) in Server GenServer
                           Policy.can_kick?(membership, "myop", "troll")
                           Membership.remove(membership, "troll")
                           broadcast("channel:#general", {:user_kicked, %{...}})
            │
            ▼ PubSub delivers {:user_kicked,...} to ALL subscribers
                │
                ├─ KICKER + observers: remove from nicklist, system msg
                └─ KICKED user: part_channel, kick_queue dialog, system msg
```

### Roles e Permissões

**Server-level (config-only, SEM tabela no DB):**

```elixir
# apps/retro_hex_chat/lib/retro_hex_chat/accounts/server_roles.ex
def admin?(nickname, identified) do
  identified and nickname in Application.get_env(:retro_hex_chat, :admins, [])
end

def server_operator?(nickname, identified) do
  identified and nickname in Application.get_env(:retro_hex_chat, :server_operators, [])
end
```

Ambos requerem `identified: true` (NickServ). Sem tabela de users no DB — identidade vem de `registered_nicks` (nick + bcrypt hash) e `Session` struct (in-memory per-LiveView).

**Channel-level (in-memory GenServer + DB para canais registrados):**

- 5 roles: `:owner` (4) > `:operator` (3) > `:half_operator` (2) > `:voiced` (1) > `:regular` (0)
- Armazenados em `Channels.Membership` (nick → {role, joined_at}) dentro do `Channels.Server` GenServer state
- Para canais registrados, roles persistidos via `access_list_entries` table (founder/sop/aop/vop)
- `ChanServ.check_access/2` converte levels do DB para roles no join

**Permissões checadas em:**
- `Channels.Policy` — `can_kick?/3`, `can_ban?/3`, `can_set_mode?/3`, `can_speak?/3`, `can_change_topic?/3`
- `Commands.Policy` — `require_channel/1`, `require_identified/1`, `require_operator/2`

### Comandos Admin Existentes

| Comando | Requer | O que faz |
|---|---|---|
| `/announce <msg>` | `is_admin` | Broadcast global via `"server:announcements"` |
| `/setmotd <text>` | `is_admin` | Seta MOTD persistido via `Services.Motd` |
| `/clearmotd` | `is_admin` | Limpa MOTD |
| `/wallops <msg>` | `is_admin` ou `is_server_operator` | Broadcast para users com `+w` mode |

### Comandos de Canal Existentes

| Comando | Min. Rank | Handler |
|---|---|---|
| `/kick <nick> [reason]` | half_operator | `handlers/kick.ex` |
| `/ban <nick> [reason]` | operator | `handlers/ban.ex` |
| `/unban <nick>` | operator | `handlers/unban.ex` |
| `/mode <flags> [params]` | operator (half-op para +v/-v) | `handlers/mode.ex` |
| `/topic <text>` | operator (se +t) | `handlers/topic.ex` |
| `/invite <nick>` | member (operator para +i) | `handlers/invite.ex` |

### Database Schema Relevante

```
registered_nicks:       nickname(16), password_hash, registered_at, last_seen_at
registered_channels:    name(50), founder_nickname(16), topic, modes, mode_key, mode_limit, mode_join_throttle
access_list_entries:    channel_name(50), nickname(16), level(founder/sop/aop/vop), added_by(16)
bans:                   channel_name(50), banned_nickname(16), banned_by(16), reason(255)
ban_exceptions:         channel_name, nickname, added_by
invite_exceptions:      channel_name, nickname, added_by
server_settings:        key(50), value(text), updated_by(16) — key/value store já existente
messages:               channel_name, sender_nickname, content, type, reply_to_*, edited_at, deleted_at
private_messages:       sender_nickname, recipient_nickname, content, type, reply_to_*, edited_at, deleted_at
```

### Serviços Relevantes

**NickServ** (`services/nick_serv.ex`) — GenServer:
- `register/2`, `identify/2`, `registered?/1`, `info/1`, `ghost/2`, `drop/2`
- `drop/2` verifica senha via `RegisteredNick.verify_password/2` (bcrypt). Para admin_drop, bypass necessário.
- State: `%{identified: MapSet.t()}` — set de nicks currently identified

**ChanServ** (`services/chan_serv.ex`) — GenServer:
- `register/2`, `drop/2`, `info/1`, `check_access/2`, `manage_access/5`
- `drop/2` verifica se requester é founder. Para admin_drop, bypass necessário.
- Hierarchy: `founder(4) > sop(3) > aop(2) > vop(1)`

**NickExpiry** (`services/nick_expiry.ex`) — Periodic task:
- Roda a cada 6h, purga nicks inativos há >7 dias
- Protege nicks currently identified (via `NickServ.list_identified/0`)
- Precisa ser modificado para também proteger nicks admin

**Queries** (`services/queries.ex`):
- Nick: `find_by_nickname/1`, `delete_registered_nick/1`, `insert_registered_nick/2`
- Channel: `find_registered_channel/1`, `delete_registered_channel/1`, `list_channels_for_founder/1`, `update_channel_founder/2`
- Access: `add_access/4`, `remove_access/2`, `list_access/1`, `find_access/2`
- Bans: `add_ban/4`, `remove_ban/2`, `list_bans/1`
- Settings: `get_setting/1`, `upsert_setting/3`, `delete_setting/1`
- **Faltam:** `list_registered_nicks/0`, `count_registered_nicks/0`, `list_settings/0`, `update_password_hash/2`

### PubSub e Force Disconnect

**`{:force_disconnect, %{reason: reason}}`** já existe e funciona. Broadcasting em `"user:#{nickname}"` desconecta o user:

```elixir
# pubsub_handlers/membership.ex
def handle_info({:force_disconnect, %{reason: reason}}, socket) do
  cleanup_channels(socket.assigns.session)
  {:halt,
   socket
   |> push_event("intentional_disconnect", %{})
   |> push_event("clear_client_state", %{})
   |> Phoenix.LiveView.redirect(to: ~p"/chat/session/clear?reason=#{reason}")}
end
```

**Tópicos PubSub subscritos por ChatLive no mount:**
- `"user:#{nickname}"` — DMs, force_disconnect, nickserv_identified, force_rename
- `"presence:global"` — eventos de presença
- `"server:announcements"` — broadcasts de /announce
- `"server:wallops"` — broadcasts de /wallops
- `"server:settings"` — mudanças em server_settings

### Presença / Users Online

`Presence.Tracker` só lista users por tópico de canal (`list_users("channel:#foo")`). **Não existe tracking global de todos os users online.** Para `/admin user list --online`, precisa adicionar `Tracker.track_user("presence:global", nickname)` no `ChatLive.mount`.

### Rate Limiting / ETS Pattern

`RateLimit.Table` é um Agent que cria um ETS `:set` público. `RateLimit.Limiter` opera sobre ele com token bucket. O padrão é reutilizável para GlobalMuteTable.

### Mensagens

- Canal: `Server.send_message/4` → `handle_call({:send_message,...})` checa `Policy.can_speak?` → persiste via `Chat.Queries.insert_message/1` → broadcast
- PM: `Chat.Service.send_private_message/5` → checa `Policy.validate_content/1` → persiste → broadcast em `"pm:#{sorted}"`
- **Não existe bulk delete.** Apenas `soft_delete_message/2` (individual). Para `/admin channel purge` precisa de nova query.

### Supervision Tree

```elixir
children = [
  Repo, DNSCluster, PubSub,
  {Registry, name: ChannelRegistry},     # channel name → pid
  Channels.Supervisor,                    # DynamicSupervisor para Server GenServers
  {Registry, name: P2P.SessionRegistry},
  P2P.RateLimitTable, P2P.Supervisor, P2P.CleanupTask, P2P.Turn.Supervisor,
  Presence.Tracker, RateLimit.Table, Chat.LinkPreview.Cache,
  {Task.Supervisor, name: LinkPreviewTasks},
  Presence.WhowasCache,
  NickServ, NickExpiry, ChanServ, ChanExpiry
]
```

Novos children a adicionar: `BanCache`, `BanExpiry`, `RoleCache`, `GlobalMuteTable` (antes de NickServ).

---

## Plano de Implementação

### Infraestrutura Base

#### 1. Migration: `server_bans`

```
server_bans:
  id               binary_id PK
  nickname         string(16) NOT NULL
  reason           text
  banned_by        string(16) NOT NULL
  expires_at       utc_datetime_usec (NULL = permanente)
  active           boolean default true
  timestamps
  UNIQUE(nickname) WHERE active = true
  INDEX(active, expires_at)
```

#### 2. Migration: `audit_logs`

```
audit_logs:
  id               binary_id PK
  actor            string(16) NOT NULL
  action           string(64) NOT NULL
  target_type      string(32) — "user" | "channel" | "server"
  target_id        string(64)
  details          map (JSONB)
  inserted_at      utc_datetime_usec NOT NULL
  INDEX(actor), INDEX(action), INDEX(inserted_at), INDEX(target_type, target_id)
```

#### 3. Migration: `admin_roles`

```
admin_roles:
  id               binary_id PK
  nickname         string(16) NOT NULL
  role             string(20) NOT NULL — "admin" | "server_operator"
  granted_by       string(16) NOT NULL
  timestamps
  UNIQUE(nickname, role)
  INDEX(nickname)
```

#### 4. Root Admins via Variável de Ambiente

- Env var: `ROOT_ADMINS=rodrigo,alice,bob` (nicks separados por vírgula)
- `runtime.exs`: `config :retro_hex_chat, :root_admins, String.split(System.get_env("ROOT_ADMINS", ""), ",")`
- Root admins são imutáveis — não podem ser removidos via comando
- Nicks NÃO são auto-registrados — o user precisa fazer `/ns register` normalmente
- Root admins podem promover outros admins (que ficam no DB e podem ser removidos)

**Proteção contra expiração:** Modificar `NickExpiry` para adicionar root_admins + DB admins à lista `protected`. Nenhum nick admin expira pela regra de 7 dias.

**Mudança em `ServerRoles.admin?/2`:** Checa 3 fontes:
1. Root admins (env var)
2. DB via `RoleCache` ETS
3. Config `:admins` fallback

#### 5. Façade: `RetroHexChat.Admin`

Módulo que orquestra ação + audit + broadcast. Os handlers chamam UMA função aqui:

```elixir
Admin.ban_user(nick, admin, reason, duration)
Admin.unban_user(nick, admin)
Admin.kick_user(nick, admin, reason)
Admin.mute_user(nick, admin, reason, duration)
Admin.unmute_user(nick, admin)
Admin.rename_user(old_nick, new_nick, admin)
Admin.set_role(nick, role, admin)
Admin.drop_nick(nick, admin)
Admin.reset_password(nick, new_password, admin)
Admin.drop_channel(channel, admin)
Admin.transfer_channel(channel, new_founder, admin)
Admin.manage_channel_access(channel, action, level, nick, admin)
Admin.create_channel(channel, admin)
Admin.delete_channel(channel, admin)
Admin.purge_channel(channel, opts, admin)
Admin.set_setting(key, value, admin)
```

Cada função: executa ação no domínio → `AuditLogs.log` → PubSub broadcast → retorna `{:ok, msg}` ou `{:error, msg}`.

#### 6. Contextos de Suporte

- **`Admin.ServerBans`** — `ban/4`, `unban/1`, `banned?/1`, `list_bans/0`, `expire_bans/0`
- **`Admin.AuditLogs`** — `log/4` (fire-and-forget), `list/1`
- **`Admin.BanCache`** — GenServer + ETS `:server_ban_cache`, seeded do DB no boot
- **`Admin.BanExpiry`** — Task periódica (hourly) para desativar bans expirados
- **`Admin.RoleCache`** — GenServer + ETS, seeded do DB no boot
- **`Admin.GlobalMutes`** — `mute/3`, `unmute/1`, `muted?/1`, `list_mutes/0`
- **`Admin.GlobalMuteTable`** — GenServer + ETS `:global_mutes` (ephemeral)

#### 7. Enforcement: `CheckServerBan` Plug

Intercepta POST `/chat/session`. Se nick em `BanCache`, redireciona para `/connect?reason=banned`.

#### 8. Enforcement: Global Mute

Dois pontos no web layer:
1. Antes de `Server.send_message/4` — checar `GlobalMutes.muted?(nickname)`
2. Antes de `Chat.Service.send_private_message/5` — mesmo check

---

### Comandos Admin (`/admin`)

Arquitetura: UM handler `Handlers.Admin` registrado como `"admin"` no Registry, despacha para submódulos.

```
commands/handlers/admin.ex              ← entry point
commands/handlers/admin/server.ex       ← /admin server info|set|get|settings
commands/handlers/admin/user.ex         ← /admin user list|info|ban|unban|kick|mute|unmute|rename|banlist|role
commands/handlers/admin/channel.ex      ← /admin channel list|info|create|delete|purge|banlist
commands/handlers/admin/nick_serv.ex    ← /admin ns drop|info|resetpass
commands/handlers/admin/chan_serv.ex     ← /admin cs drop|info|transfer|access
commands/handlers/admin/debug.ex        ← /admin debug connections|processes|memory
commands/handlers/admin/log.ex          ← /admin log [--last N] [--user X]
```

**Permissão base:** `is_admin: true` no context.

#### Subcomandos Server

| Comando | Ação | Audit? |
|---|---|---|
| `/admin server info` | Stats: users online, canais, nicks registrados, uptime | Sim |
| `/admin server set <key> <value>` | Upsert em `server_settings`. Keys: server_name, server_description, welcome_message, max_channels, registration (open/closed) | Sim |
| `/admin server get <key>` | Query `server_settings` | Não |
| `/admin server settings` | Lista todos os settings | Não |

#### Subcomandos User

| Comando | Ação | Audit? |
|---|---|---|
| `/admin user list [--search Q] [--online]` | Lista nicks registrados/online | Sim |
| `/admin user info @nick` | Detalhes completos do user | Sim |
| `/admin user ban @nick [--reason R] [--duration D]` | Ban global → DB + ETS + force_disconnect | Sim |
| `/admin user unban @nick` | Remove ban → UPDATE active=false + ETS | Sim |
| `/admin user kick @nick [--reason R]` | Force disconnect (sem ban) | Sim |
| `/admin user mute @nick [--duration D]` | Mute global → ETS + broadcast | Sim |
| `/admin user unmute @nick` | Remove mute → ETS + broadcast | Sim |
| `/admin user rename @nick <novo>` | Force nick change → broadcast admin_rename | Sim |
| `/admin user banlist [--search Q]` | Lista bans ativos do servidor | Não |
| `/admin user role @nick <admin\|server_operator\|user>` | Promoção/demoção → DB + RoleCache | Sim |

#### Subcomandos Channel

| Comando | Ação | Audit? |
|---|---|---|
| `/admin channel list [--search Q]` | Lista canais ativos + registrados | Sim |
| `/admin channel info #canal` | Detalhes: membros, roles, modos, bans | Sim |
| `/admin channel create #canal` | Cria + registra (admin como founder) | Sim |
| `/admin channel delete #canal` | Broadcast channel_deleted + kick all + drop registro + stop GenServer | Sim |
| `/admin channel purge #canal [--from @nick]` | Bulk delete de msgs no DB | Sim |
| `/admin channel banlist #canal` | Lista bans do canal | Não |

#### Subcomandos NickServ

| Comando | Ação | Audit? |
|---|---|---|
| `/admin ns drop @nick` | Drop sem senha + force_disconnect | Sim |
| `/admin ns info @nick` | Info detalhada | Sim |
| `/admin ns resetpass @nick <senha>` | Reset password_hash no DB | Sim |

#### Subcomandos ChanServ

| Comando | Ação | Audit? |
|---|---|---|
| `/admin cs drop #canal` | Drop sem ser founder | Sim |
| `/admin cs info #canal` | Info + access list | Sim |
| `/admin cs transfer #canal @nick` | Transfere founder | Sim |
| `/admin cs access #canal` | Lista access list | Sim |
| `/admin cs access #canal add <level> @nick` | Add sem rank check | Sim |
| `/admin cs access #canal del <level> @nick` | Del sem rank check | Sim |

#### Subcomandos Debug

| Comando | Ação | Audit? |
|---|---|---|
| `/admin debug connections` | WebSocket/LiveView count | Não |
| `/admin debug processes` | Channel GenServers ativos + membros | Não |
| `/admin debug memory` | `:erlang.memory()` formatado | Não |

#### Subcomando Log

| Comando | Ação | Audit? |
|---|---|---|
| `/admin log [--last N] [--user X]` | Query audit_logs | Não |

---

### Comandos de Gestão de Canal (handlers separados)

| Comando | Handler | Permissão | Implementação |
|---|---|---|---|
| `/op @nick` | `Handlers.Op` | operator/owner | Wrapper: `{:ok, :ui_action, :set_mode, %{mode_string: "+o"}}` |
| `/deop @nick` | `Handlers.Deop` | operator/owner | Wrapper: `"-o"` |
| `/voice @nick` | `Handlers.Voice` | operator/half_op/owner | Wrapper: `"+v"` |
| `/devoice @nick` | `Handlers.Devoice` | operator/half_op/owner | Wrapper: `"-v"` |
| `/slow [seconds]` | `Handlers.Slow` | operator/owner | Message throttle (avaliar +j ou novo modo) |
| `/mute @nick [duration]` | `Handlers.Mute` | operator/owner (outrank) | Novo: `channel_mutes` MapSet no Server state |
| `/unmute @nick` | `Handlers.Unmute` | operator/owner | Remove de `channel_mutes` |
| `/transfer @nick` | `Handlers.Transfer` | owner ONLY | `Server.transfer_ownership/3` + ChanServ update |

**`/mute` (channel)** requer mudanças no domínio:
- `Channels.Server` state: adicionar `channel_mutes: MapSet.new()`
- Novas calls: `channel_mute/4`, `channel_unmute/3`
- Check em `handle_call({:send_message,...})` para bloquear muted users
- `Channels.Policy`: novo `can_mute?/3`

**`/transfer`** requer:
- `Server.transfer_ownership/3`: seta novo owner, demove antigo para operator
- Se registrado: atualiza `access_list_entries` (founder transfer) via ChanServ
- Novo `Commands.Policy.require_owner/2`

---

## Arquivos a Criar

| Arquivo | Tipo |
|---|---|
| `admin.ex` | Façade |
| `admin/server_ban.ex` | Schema |
| `admin/audit_log.ex` | Schema |
| `admin/admin_role.ex` | Schema |
| `admin/server_bans.ex` | Contexto |
| `admin/audit_logs.ex` | Contexto |
| `admin/ban_cache.ex` | GenServer + ETS |
| `admin/ban_expiry.ex` | Task periódica |
| `admin/role_cache.ex` | GenServer + ETS |
| `admin/global_mutes.ex` | Contexto |
| `admin/global_mute_table.ex` | GenServer + ETS |
| `commands/handlers/admin.ex` | Entry point |
| `commands/handlers/admin/server.ex` | Subcomandos |
| `commands/handlers/admin/user.ex` | Subcomandos |
| `commands/handlers/admin/channel.ex` | Subcomandos |
| `commands/handlers/admin/nick_serv.ex` | Subcomandos |
| `commands/handlers/admin/chan_serv.ex` | Subcomandos |
| `commands/handlers/admin/debug.ex` | Subcomandos |
| `commands/handlers/admin/log.ex` | Subcomandos |
| `commands/handlers/op.ex` | Handler |
| `commands/handlers/deop.ex` | Handler |
| `commands/handlers/voice_cmd.ex` | Handler |
| `commands/handlers/devoice.ex` | Handler |
| `commands/handlers/slow.ex` | Handler |
| `commands/handlers/mute_cmd.ex` | Handler |
| `commands/handlers/unmute.ex` | Handler |
| `commands/handlers/transfer.ex` | Handler |
| `plugs/check_server_ban.ex` | Plug |
| 3 migrations | DB |
| Tests para todos os módulos acima | |

## Arquivos a Modificar

| Arquivo | O que muda |
|---|---|
| `commands/registry.ex` | +10 entries: admin, op, deop, voice, devoice, slow, mute, unmute, transfer |
| `application.ex` | +4 children: BanCache, BanExpiry, RoleCache, GlobalMuteTable |
| `router.ex` | +1 plug: CheckServerBan |
| `accounts/server_roles.ex` | admin?/2 checa RoleCache + root_admins + config |
| `channels/server.ex` | +channel_mutes state, +channel_mute/4, +channel_unmute/3, +admin_destroy/2 |
| `channels/policy.ex` | +can_mute?/3 |
| `commands/policy.ex` | +require_owner/2, +require_admin/1 |
| `ui_action_handlers.ex` | +channel_mute_user, +channel_unmute_user ao @core_actions |
| `ui_actions/core.ex` | +2 clauses para mute/unmute |
| `pubsub_handlers.ex` | +dispatch para novos eventos |
| `pubsub_handlers/channel_state.ex` | +clauses: user_channel_muted, user_channel_unmuted, channel_deleted |
| `pubsub_handlers/server_messages.ex` | +clauses: admin_rename, role_changed, user_muted, user_unmuted |
| `services/queries.ex` | +list_registered_nicks/0, +count_registered_nicks/0, +list_settings/0, +update_password_hash/2 |
| `services/nick_serv.ex` | +admin_drop/2, +admin_reset_password/2 |
| `services/chan_serv.ex` | +admin_drop/2, +admin_transfer/3, +admin_manage_access/4 |
| `services/nick_expiry.ex` | +root_admins + DB admins na lista protected |
| `chat/queries.ex` | +bulk_delete_messages/1 (por canal), +bulk_delete_messages/2 (por canal+autor) |
| `chat_live.ex` | +Tracker.track_user("presence:global", nickname) no mount |
| `chat_live/helpers` | +check GlobalMutes.muted?/1 antes de send_message e send_pm |
| `config/runtime.exs` | +ROOT_ADMINS env var parsing |
| `chat/help_topics.ex` | +topics para todos os novos comandos |

---

## Ordem de Implementação

1. Migrations + Schemas (server_bans, audit_logs, admin_roles)
2. ServerBans context + BanCache + BanExpiry + CheckServerBan plug
3. AuditLogs context
4. RoleCache + modificação em ServerRoles + ROOT_ADMINS env var
5. GlobalMuteTable + GlobalMutes context
6. Façade `Admin`
7. `/admin` handler base + `/admin server info` + `/admin server set|get|settings` + `/admin debug *` + `/admin log`
8. `/admin user list` + `/admin user info` + `/admin user banlist`
9. `/admin user ban` + `/admin user unban` + `/admin user kick`
10. `/admin user mute` + `/admin user unmute`
11. `/admin user rename`
12. `/admin user role`
13. `/admin channel list` + `/admin channel info` + `/admin channel banlist`
14. `/admin channel create` + `/admin channel delete` + `/admin channel purge`
15. `/admin ns drop` + `/admin ns info` + `/admin ns resetpass`
16. `/admin cs drop` + `/admin cs info` + `/admin cs transfer` + `/admin cs access`
17. `/op` + `/deop` + `/voice` + `/devoice`
18. `/slow`
19. `/mute` + `/unmute` (channel)
20. `/transfer`
21. Help topics para todos os comandos

## Verificação

Para cada feature, rodar o pipeline CI completo:

1. `mix compile --warnings-as-errors`
2. Em paralelo: `mix format --check-formatted` | `mix credo --strict` | `make lint.js` | `make lint.css` | `npm test --prefix apps/retro_hex_chat_web/assets` | `mix test --include e2e` | `mix dialyzer`

Teste manual: conectar com nick na env var `ROOT_ADMINS`, identificar via `/ns identify`, executar cada comando e verificar output + side effects.
