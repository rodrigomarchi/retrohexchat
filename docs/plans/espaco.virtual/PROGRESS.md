# PROGRESS — Espaço Virtual

Arquivo vivo do loop de implementação. Toda iteração começa lendo este arquivo
e termina atualizando-o. O checklist canônico é o
`05-plano-implementacao.md`; aqui ficam estado, histórico e aprendizados.

## Estado atual

- **Status**: EM ANDAMENTO
- **Fase corrente**: Fase 2 — canvas, snapshot e presença (Fase 1 FECHADA:
  CI 9/9 verde + commit único na main)
- **Próximo item**: primeiro item da Fase 2 — `SpaceCanvasHook` lazy
  (`serverEvents: []`, `reason` obrigatório) em
  `hooks/lazy_feature_hooks.js`; começar pelos Vitest de
  `test/hooks/space/space_canvas_hook.test.js` (§Fase 2 do mapa de testes);
  na sequência `lib/space/protocol.js` e `lib/space/map.js`.
- **Último commit do projeto**: `feat(space): fase 1` (ver git log)

## Perguntas para o usuário

(nenhuma pendente)

## Aprendizados acumulados

Registrados na fase de planejamento/auditoria (2026-07-05), válidos para toda a
implementação:

- **Gabarito de contexto**: `RetroHexChat.Lobby` é o análogo exato do layout
  planejado (facade + policy/queries/registry/service/session_server/
  supervisor/schema). `Arcade` nomeia diferente — não usar como gabarito.
- **Primeira Phoenix Channel do projeto**: não existe UserSocket, `socket
  "/socket"`, diretório `channels/` nem ChannelCase. Tudo nasce na Fase 1.
- **Contrato de handler**: retorno `{:ok, :ui_action, atom, map}` com payload
  contendo `target`/`token`/`creator_id` (gabarito `Handlers.Lobby`); registro
  no mapa `@commands` de `Commands.Registry`; behaviour exige `help/0`,
  `syntax_definition/0` opcional, `category/0`.
- **Card em canal é inédito**: `:p2p_invite` só existe em `PrivateMessage`;
  `:arcade_link` é efêmero. `space_invite` entra em `Chat.Message @type_values`
  + `Chat.Service @known_types` (decisão 19).
- **Sem refresh ao vivo de card** (decisão 20): enrich no build da linha, como
  hoje.
- **Mapa canônico no Elixir** (decisão 21): cliente recebe tudo no
  `space_init`, sem cópia JS.
- **Settings de admin**: runtime via tabela `server_settings`
  (`get_setting/1` + fallback; whitelist em
  `Handlers.Admin.Server.validate_setting_value/2`), não config estática.
- **lazyFeatureHook**: `reason` obrigatório; `serverEvents: []` quando o hook
  não recebe eventos LiveView (caso do SpaceCanvasHook).
- **Sem precedente de netcode**: previsão/reconciliação é trabalho novo; os
  jogos atuais são host-autoritativos via DataChannel binário. Não herdar de
  `lib/game_engine.js`.
- **Ciclo de validação**: por arquivo durante o loop; `make ci` completo
  SOMENTE no fechamento de fase (pedido explícito do usuário — o CI é lento).
- **Commits**: um por fase, direto na `main`, stage por caminho explícito.

## Histórico de iterações

### 2026-07-05 — Iteração 3 (FECHAMENTO da Fase 1)

- Extração gettext controlada: rodada 2x (a 1ª revelou que os templates de
  help novos NÃO compilavam); ~460 catálogos não afetados revertidos/apagados
  (inclusive um domínio `lobby` novo de débito paralelo); mantidos 9 domínios
  afetados (admin/commands/help no domínio; chat/space/help_commands/
  help_features/help_p2p/help_space no web).
- **Bug real encontrado e corrigido**: `cmd_space.html.heex` e
  `feature_virtual_spaces.html.heex` não estavam em NENHUM glob de
  `embed_templates` — o tópico abriria com raise. O novo teste
  `help_content_coverage_test.exs` (todo topic id → função exportada) pegou
  TAMBÉM 3 tópicos pré-existentes quebrados (feature-session-cards,
  feature-message-layout, feature-network-stats) — globs corrigidos em
  commands_n_to_z/p2p/chat_features.
- Traduções REAIS das ~61 strings novas do projeto nos 20 locales exigidos
  (~1.270 msgstrs), aplicadas via polib (venv no scratchpad) com dicionários
  indexados por msgid canônico. Débito seeded pré-existente (strings antigas
  que a extração tornou visíveis) deixado como a tooling produziu — não é
  deste projeto e traduzi-lo aqui esconderia o débito real.
- `make ci`: falhas corrigidas — contagem hardcoded 55→56 comandos no
  `registry_test.exs`; ordem alfabética de alias (credo --strict é o modo do
  CI, pega até "software design suggestions" em testes).
- Commit único da fase na `main` (stage por caminho explícito).

Aprendizados desta iteração:

- **`mix gettext.extract` só vê o que COMPILA**: template heex fora de um
  glob `embed_templates` nem compila nem extrai — e o tópico de help quebra
  em runtime. O teste de cobertura novo fecha essa classe para sempre.
- **A rehydrate SEMEIA msgstr=msgid (inglês)** nos catálogos — "preencher
  seeds" significa procurar `msgstr == msgid` novos (diff contra HEAD), não
  `msgstr ""`.
- **Escopo de tradução**: separar "minhas strings" (referências `#:` nos
  arquivos do projeto) do débito visível novo; traduzir só as minhas.
- **credo do CI roda `--strict`**: sugestões [D] de design (nested modules em
  teste) também quebram; aliasar já no primeiro write TAMBÉM em testes.
- **`echo ===`/paths com `=`** quebram no zsh (path expansion).
- **Contagem de comandos é hardcoded** em `registry_test.exs` — todo comando
  novo exige bump (55→56).

### 2026-07-05 — Iteração 2 (itens web da Fase 1 completos)

Itens concluídos (TDD; 114 testes das duas camadas verdes ao final):

- Summaries do domínio ganharam `kind: :space`, `terminal?`, `created_at`,
  `closed_at/closed_reason` (live + DB) — o card consome direto.
- `SessionCard.enrich` p/ `:space_invite` (regex `/space/<token>`, href do
  próprio match); card `:space` no `Components.SessionCard` (título/criador/
  canal/mapa humanizado/lotação/validade; CTA "Enter space" só quando vivo);
  ramo `:space_invite` no `MessageRow` com fallback `p2p_invite_card` +
  extractors `extract_space_label/link` em `ChatHelpers`.
- Enrich agora roda TAMBÉM nas mensagens de canal: history
  (`Channel.message_to_stream_item`), pagination (`core_events`) e live
  (`pubsub_handlers/messages.ex` `new_message`) — antes só PMs enriqueciam.
- `Helpers.SpaceInvite` (mensagem de CANAL persistida `space_invite`, com
  fallback textual `/space/<token>`) + clause `:space_invite` no
  `CommandDispatch`.
- Migration `20260705130000_widen_messages_type`: `messages.type` era
  varchar(10) — "space_invite" tem 12 chars. Alargado p/ 20.
- `VirtualSpace.JoinToken` (salt `space_join`, max_age 3600s, secret
  `:p2p_token_secret` reutilizado) + testes.
- `Service.check_capacity/2` (advisory p/ tela de cheio; autoritativo continua
  no join do SessionServer) + delegate na facade.
- Rota `live "/space/:token", SpaceLive` + `SpaceLive` shell (estados
  invalid/terminal/full/denied com `data-testid` + shell com
  `phx-hook="SpaceCanvasHook"`, `data-space-token`, `data-join-token`).
- PRIMEIRA infra Phoenix Channel do projeto: `UserSocket` (anônimo, auth por
  canal), `socket "/socket"` no endpoint, `SpaceChannel` (join re-valida
  token assinado + policy + capacidade via `join_session`; responde
  `space_init` v1; `terminate/2` → leave; PubSub do domínio → `push`
  verbatim), `test/support/channel_case.ex`.

Aprendizados desta iteração:

- **`messages.type` era varchar(10)** — qualquer tipo novo >10 chars precisa
  de migration; o erro só aparece no INSERT (constraint do banco, não do
  changeset).
- **Canal x PM no enrich**: `SessionCard.enrich` só rodava nos caminhos de PM
  e em itens efêmeros; mensagens de CANAL têm 3 pontos de construção
  (history, pagination em `core_events`, live em `pubsub_handlers/messages`)
  — todos precisam do enrich.
- **Identificação em teste web**: `NickServ.register(nick, pass)` +
  `NickServ.identify(nick, pass)` cria o RegisteredNick E marca identificado
  (padrão de `autojoin_auto_add_test`). `chat_conn(conn, nickname)` injeta a
  sessão HTTP.
- **`registered_at` é `utc_datetime_usec`**: nunca `DateTime.truncate(:second)`
  em inserts diretos de `RegisteredChannel`.
- **ChannelTest**: broadcasts do domínio no tópico `space:<token>` chegam ao
  processo do channel como `handle_info` (mapa cru `%{event:, payload:}`) —
  repassar com `push/3`. O próprio join não recebe seu broadcast (a
  subscription acontece depois do callback). `close(socket)` é síncrono para
  o channel mas o `leave` é cast — esperar com wait_until em `get_state`.
- **Phoenix.Token**: dados com atom keys sobrevivem sign/verify (term binário).

Decisões de implementação:

- Card de espaço é mensagem de CANAL (decisão 19); o fallback textual usa
  "Enter the space: /space/<token>" (regex do label espelha o padrão do p2p).
- `JoinToken` reusa `:p2p_token_secret` com salt próprio `space_join`
  (não criar segundo segredo).
- `UserSocket.connect` aceita todo mundo; TODA autorização é por-channel via
  join token (o socket não identifica transporte, `id → nil`).
- Capacidade: check no mount é advisory (UX); o autoritativo é o do
  `SessionServer.join` re-executado pelo channel join.

### 2026-07-05 — Iteração 1 (backend-domínio da Fase 1 completo)

Itens concluídos (todos com TDD, 140 testes verdes ao final):

- Migration `virtual_space_sessions` (dev+test migradas) + `Schema.Session`
  (defaults pending/tavern_cafe_v1/20, `terminal?/1`, `status_changeset` exige
  `closed_at`/`closed_reason` em status terminal).
- `Queries` (insert/get/update_status/`list_expired_sessions`/expire).
- `Policy` com erros em ÁTOMOS (decisão: `:registration_required`,
  `:not_identified`, `:invalid_origin`, `:cannot_post`,
  `:channel_access_denied`, `:terminal_session`, `:space_full`, `:forbidden`) —
  a camada de apresentação traduz; o Lobby usa strings gettext, mas o espaço
  precisa distinguir cheio/expirado/inválido nas telas terminais.
- `Map` registry + 4 mapas (`tavern_cafe_v1` com colisão/zonas/assentos/
  interactables; outros 3 esqueléticos) + `collision_set/1` (rects → MapSet).
- `Registry`/`Supervisor` (gabarito Lobby) + children em `application.ex`
  (registry + supervisor + cleanup).
- `SessionServer` mínimo: join com capacidade+spawn determinístico livre,
  takeover por `participant_key` (`registered:<id>`) preservando posição,
  leave marca offline sem perder tile, pending_timeout, expiry no
  `expires_at`, `session_summary`, snapshot, broadcasts
  `space_participant_joined/left`/`space_closed` no tópico `space:<token>`.
- `Service`: create (token 32B url-safe, rate limit P2P, TTL default 2h/teto
  8h, setting `space_max_participants` com fallback 20 e teto config 50),
  join (marca expired antes de recusar; re-inicia child pós-restart), close
  (com processo morto → marca no DB), summary live-com-fallback-DB.
- Facade `RetroHexChat.VirtualSpace` (@spec em tudo).
- Setting `space_max_participants`: whitelist + validação (1..teto) em
  `Handlers.Admin.Server` (criado `server_test.exs` novo).
- `Handlers.Space` completo (parse `[#canal] [nome] ttl=`; recusa PM/Status
  pela ORIGEM `active_channel`, mesmo com `#canal-alvo`; erros do domínio
  mapeados p/ gettext) + registro `"space"` no `Commands.Registry`.
- Tipo `space_invite` em `Chat.Message @type_values` +
  `Chat.Service @known_types`.
- Help topics: nova categoria "Virtual Spaces" (icon_community) + `cmd-space`
  + `feature-virtual-spaces` + templates HEEx (`cmd_space.html.heex`,
  `feature_virtual_spaces.html.heex`).
- `CleanupTask` periódico + config `virtual_space_*` no `config.exs`.

Aprendizados desta iteração (não repagar):

- **`echo ===` quebra no zsh** (`=x` é expansão de path); usar `echo '---'`.
- **Registry lag**: a desregistração é via monitor e ATRASA a morte do
  processo. Produção: `SessionServer.call/2` captura `:exit {:noproc|:normal}`
  → `{:error, :not_found}`. Testes: helper `wait_for_deregistration` após
  `GenServer.stop` antes de assertar lookup.
- **`Channels.Server.get_state/1`** devolve mapa DERIVADO (`state_to_map`):
  `members` é lista `{nick, role}`, `modes` é string, `modes_detail` tem
  booleans, `invite_exceptions` é lista. Não expõe os structs Modes/Membership.
- **Acesso a canal sem servidor vivo**: `Channels.Queries.load_persisted_state/1`
  (modes string + invite_exceptions); reconstruir `Modes` com
  `Modes.new() |> Modes.apply_changes("+i")` (prefixar "+" se faltar) e usar
  `Channels.Policy.can_join?/6` com `Membership.new()` (limit check passa
  vazio de propósito — join de espaço não é join de canal).
- **`Commands.Duration.parse/1`** devolve `:permanent` para formato inválido —
  tratar como erro de uso no ttl=.
- **Registry de comandos**: função de lookup é `Registry.lookup/1`
  (não `get_handler`).
- **Setting runtime**: gravar é `Services.Queries.upsert_setting/3`
  (não existe `set_setting` em Queries; `Admin.set_setting/3` é o caminho com
  audit log).
- **Help topics têm teste de integridade**: todo topic id NOVO exige template
  `help_content/<id_com_underscores>.html.heex` no app web, senão
  `help_topics_test` quebra.
- **Session expiry**: `SessionServer` agenda `session_expiry` com
  `max(diff_ms, 0)` a partir do `expires_at` — child iniciado para sessão já
  vencida expira imediatamente (comportamento desejado).
- **CleanupTask testável sem processo real**: registrar um processo dummy no
  `SessionRegistry` via `Registry.register/3` simula "processo vivo".

Decisões de implementação:

- Erros de Policy/Service como átomos (justificativa acima); handler traduz.
- `space_max_participants` é estampado em `max_participants` na CRIAÇÃO da
  sessão (não lido a cada join) — capacidade viva usa o valor da sessão.
- Card usa fallback textual `/space/<token>` no content da mensagem (a
  publicar na próxima iteração via SpaceInvite helper).
- Categoria de help própria "Virtual Spaces" (não cabia em P2P & Calls).

Pendências conhecidas da Fase 1 (itens web):

- `Helpers.SpaceInvite` + dispatch; enrich `SessionCard` + render; rota +
  `SpaceLive`; UserSocket + SpaceChannel + ChannelCase; extração gettext
  (fazer SÓ no fechamento da fase, junto do `make ci` — manter apenas
  catálogos dos domínios afetados: commands/admin/help/help_commands/
  help_space).

### 2026-07-05 — Planejamento (sessão de auditoria)

- Plano auditado contra o codebase com 3 varreduras (domínio, web, JS); todos
  os apontamentos inválidos corrigidos nos docs 00–08.
- 4 ambiguidades levadas ao usuário e fechadas (decisões 18–21 no doc 06).
- `05-plano-implementacao.md` reescrito como checklist rastreável por fase;
  `09-mapa-de-testes.md` criado (inventário TDD por fase);
  `10-prompt-loop.md` criado (prompt do loop); este PROGRESS criado.
- Implementação: nada iniciado. A Fase 1 começa na próxima iteração.
