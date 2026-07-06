# PROGRESS — Espaço Virtual

Arquivo vivo do loop de implementação. Toda iteração começa lendo este arquivo
e termina atualizando-o. O checklist canônico é o
`05-plano-implementacao.md`; aqui ficam estado, histórico e aprendizados.

## Estado atual

- **Status**: EM ANDAMENTO
- **Fase corrente**: Fase 6 — robustez e produto completo (Fase 5 FECHADA:
  CI 9/9 verde + commit único na main). ÚLTIMA fase.
- **Próximo item**: primeiro item da Fase 6 — cenários de reconnect/offline
  (fechar aba marca offline; takeover); reinício do processo retoma sessão não
  expirada; métricas simples (PromEx se encaixar); logs de erro nas bordas;
  revisão final de help/i18n; passada de `/code-review` no diff acumulado;
  verificação manual guiada. Ver §Fase 6 do mapa de testes. Ao fechar a Fase
  6, marcar PROGRESS como CONCLUÍDO.
- **Último commit do projeto**: `feat(space): fase 5` (ver git log)

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

### 2026-07-06 — Iteração 7 (Fase 5 COMPLETA + fechada)

Poderes do criador, 4 mapas e persistência de posição. CI 9/9; 4 E2E do
espaço verdes (canvas, movimento, office, admin).

Backend (SessionServer + Channel):
- `admin_action/3` (kick/mute/close/change_map) com `Policy.can_admin?`;
  não-criador → `:forbidden`.
  - kick: marca offline + `state.kicked` (MapSet, bloqueia reentrada — join
    retorna `:kicked`), broadcast `space_participant_kicked` (+ delta left).
  - mute/unmute: seta `muted?`, delta.
  - close: `do_end` + stop.
  - change_map: valida no registry, respawna todos em spawn livre do novo
    mapa (identidade/mute/presença preservados), atualiza `session.map_id`,
    broadcast `space_map_changed` (map completo + snapshot).
- Channel `space_admin_action` (parse fechado; ator com is_admin/
  is_server_operator via `Accounts.ServerRoles`).
- **Presence deltas** (lacuna da Fase 2 corrigida): join/leave/kick agora
  transmitem `space_delta` com `joined`/`left` — antes só o nome ia, então a
  engine remota nunca adicionava/removia o outro participante.
- Persistência: snapshot leve de posições em `session.metadata["positions"]`
  no leave e no change_map (nunca por passo); `spawn_for/2` restaura a posição
  salva no join novo (sobrevive a restart do processo).

Mapas: `guild_hall_v1`, `arcane_library_v1`, `garden_camp_v1` completos
(floor layer gerada, zonas, assentos off-collision, board). `map_test`
generalizado — os 4 passam as mesmas invariantes.

Frontend:
- engine `applyMapChanged` (troca mapa + câmera + snapshot) e
  `removeParticipant`.
- hook: `space_map_changed`→engine, `space_participant_kicked` (self→tela de
  expulso + detach + leave; remoto→remove), painel do criador
  (`[data-space-admin-list]`, só renderizado p/ criador no HEEx, populado com
  botões Kick), overlays de expulso/encerrado, join-error `kicked`→tela.
- SpaceLive shell: `is_creator`, painel do host, overlays kicked/closed.

E2E `space-admin`: host expulsa guest → guest vê tela de expulso e, ao
recarregar, é rejeitado (kicked de novo).

Aprendizados desta iteração:
- **Lacuna de presença**: `space_participant_joined/left` (nome) não bastam;
  a engine remota precisa de `space_delta` com `joined`/`left`. Ao adicionar,
  o delta de presença aparece ANTES do delta de movimento nos testes → drenar
  no `start_space`.
- **`defp` no meio de cláusulas `handle_call`** dispara warning "clauses
  should be grouped" que quebra `--warnings-as-errors` — mover helpers para a
  seção privada.
- **dialyzer com tipos de mapa fechados**: `@type actor` com only
  required/optional é FECHADO — passar uma chave extra (`nickname`) falha;
  adicionar `optional(:nickname)`. E specs de erro precisam propagar `:kicked`
  por toda a cadeia (SessionServer→Service→facade→Channel `join_error`).
- **change_map**: respawn determinístico evitando colisão de tiles com
  `Enum.map_reduce` + `free_spawn`.

Decisões de implementação:
- kick bloqueia reentrada via `state.kicked` (runtime), não persistido na V1.
- Painel do criador só existe no DOM para o criador (server-rendered) — não
  há como um não-criador acionar admin pela UI.
- Persistência de posição é best-effort em leave/map-change; posição inválida
  (colisão) cai no spawn.

### 2026-07-05 — Iteração 6 (Fase 4 COMPLETA + fechada)

Escritório vivo: zonas, chat/balões, cadeiras, quadro→modal, HUD. CI 9/9;
3 E2E do espaço verdes (canvas, movimento, office).

Backend (SessionServer + Channel):
- Zonas: `zone_id` setado no join e no move; `space_zone_changed`
  (%{key, zone_id, from}) publicado ao cruzar zona.
- Assentos: `interact/3` kind "sit"/"stand"; `state.seats` (%{seat_id => key});
  sentar exige adjacência (Chebyshev ≤ 1), snap ao tile do assento, pose
  "sitting", dir do assento; 2ª ocupação → `:seat_taken`; andar levanta
  primeiro (`free_seat` em resolve_step) e leave/close libera o assento.
- Quadro: interact kind "use" → `{:ok, %{modal: %{title, kind, asset}}}`
  (asset do mapa); alvo inexistente `:invalid_target`, distante `:too_far`.
- Chat: `chat_bubble/3` normaliza (strip control, colapsa whitespace, trim),
  rejeita >160 (`:too_long`), mutado (`:muted`), rate limit por participante
  (`virtual_space_chat_rate`, default {5,5000}, `:rate_limited`); publica
  `space_message` (%{key, nickname, text}).
- Channel `handle_in` para `space_chat_bubble` e `space_interact` (payload
  fechado; board → push `space_modal` só para o requester).

Frontend (js/lib/space + hook):
- `chat.js` (ChatState): balão por participante com expiração + side log
  limitado.
- `seating.js`/`interactions.js`: `frontTile`, `interactTarget`, `seatTarget`
  (resolvem o tile à frente/adjacente; sit vs stand).
- `modal.js` (ModalController): open/close, Escape fecha.
- `input.js`: teclas de ação `e` (interact) / `f` (sit) via `onAction`,
  coalescidas e respeitando foco.
- `engine.js`: ChatState integrada — `receiveMessage`/`chatLog`, balões
  passados ao renderer por frame; `self()` exposto.
- `renderer.js`: desenha balão de fala com `fillText` (texto, nunca HTML) —
  teste dedicado com `<b>` verbatim.
- hook: liga `onAction`→interact/seat, `space_message`→engine,
  `space_modal`→ModalController (desenha o board do atlas num overlay),
  input de chat (Enter→push), HUD de contagem (só o número no JS; label
  traduzida no HEEx).
- SpaceLive shell: input de chat, host do modal, HUD e dica de controles
  (todos DENTRO do canvas-root p/ o hook querySelect).

E2E `space-office.spec.ts`: chat pinta balão (canvas muda) e o quadro abre
`data-space-modal` (com "Tavern menu"), Escape fecha.

Aprendizados desta iteração:
- **CSS consistency (lint.css) valida classes Tailwind usadas em JS**: uma
  classe nova só em string JS (`mb-1`) que o Tailwind não gerou quebra o CI
  ("Missing CSS classes"). Usar só classes já geradas em JS, ou evitar classe
  nova em JS.
- **credo --strict conta complexidade em TESTES também**: helper `walk_to`
  com cond+`&&` estourou (10>9); extrair `step_toward/3`.
- **HUD/labels no JS**: manter a label traduzível no HEEx (`dgettext`) e o JS
  atualizar só o número via `data-*` — evita a maquinaria de i18n JS.
- **elementos que o hook consulta** (`querySelector`) precisam estar DENTRO do
  elemento com `phx-hook` (o `this.el`), não irmãos.
- **normalização de chat**: `\p{C}` (control) + colapso `\s+` + trim; canvas
  `fillText` já é seguro contra HTML, mas o side-log DOM deve usar textContent.
- gettext desta fase: só o domínio `space` (3 strings novas) traduzido nos 20
  locales; resto revertido.

Decisões de implementação:
- Sentar exige adjacência e faz snap ao tile do assento; andar levanta.
- Rate limit e bubble/log são efêmeros (chat do espaço não persiste).
- Modal é per-usuário (push ao requester), não broadcast.
- HUD mostra contagem viva (participantCount da engine), atualizado em
  snapshot/delta.

### 2026-07-05 — Iteração 5 (Fase 3 COMPLETA + fechada)

Movimento tile-a-tile server-authoritative com previsão/reconciliação no
cliente e interpolação de remotos. CI 9/9 verde; 2 E2E (canvas + movimento
multiplayer) verdes.

Backend (`SessionServer` + Channel):
- `SessionServer.input/3` + `handle_call({:input,...})`: valida passo cardinal
  (dx/dy ∈ {-1,0,1}, exatamente um não-zero), cooldown
  (`virtual_space_step_ms`, monotonic `last_input_at`), bounds, colisão
  (`state.blocked`); ignora terminal/ausente. Aceito → atualiza pos+dir+
  zone_id e publica `space_delta` com `seq_ack`; rejeitado por bounds/colisão
  → publica delta de CORREÇÃO (posição atual) p/ o cliente reconciliar;
  malformado/cooldown → drop silencioso. Facade `VirtualSpace.input/3`.
- `SpaceChannel.handle_in("space_input")` parseia o payload fechado
  (seq/dx/dy inteiros; qualquer outra coisa é descartada) e chama a facade.

Frontend:
- `input.js` (`InputController`): setas+WASD → intent {dx,dy,dir}, coalesce
  auto-repeat (Set de teclas pressionadas; 1 intent por press), suprime
  captura quando `document.activeElement` é input/textarea/contenteditable;
  `currentIntent`, attach/detach.
- `interpolation.js` (`Interpolator`): tween linear por-remoto entre tiles
  (duração 120ms), `reset`/`moveTo` (retarget a partir da pos amostrada)/
  `position`/`remove`.
- `engine.js` previsão/reconciliação: `predict(intent)` move o self na hora
  se o tile é livre localmente (mesma colisão do servidor), enfileira pending
  {seq,dx,dy}, retorna payload; colisão local → não anima nem envia.
  `applyDelta` reconcilia o self (descarta pending ≤ seq_ack, rebase na pos
  autoritativa, re-aplica pending restante com colisão local → rollback limpo
  em rejeição) e alimenta o interpolador dos remotos; `renderPosition(key,now)`
  = predito (self) / interpolado (remoto); `_draw` monta participantes com
  posições (fracionárias) por frame; `setClock` p/ teste.
- Hook liga `InputController` → `engine.predict` → só o passo aceito vai ao
  canal (`space_input` com seq); `destroyed` faz `input.detach`.

E2E `space-movement.spec.ts`: 2 usuários no mesmo espaço; Alice anda e a
assinatura do canvas do Bob muda (viu o avatar mover); vista estável sem input.

Aprendizados desta iteração:
- **eslint pega `import` não usado como ERRO** (`vi` importado sem uso no
  input.test) — quebra o JS Lint do CI; warnings de console não quebram.
- **`assert_receive` de PubSub pega o PRIMEIRO match** — testes que geram
  vários deltas (walk_to) precisam drenar o mailbox (`flush_deltas`) antes de
  assertar o delta específico.
- **Colisão local == servidor** (mesma definição de mapa via space_init) →
  a previsão do cliente já bloqueia contra parede; o servidor só corrige
  divergências reais (ex.: rejeição por cooldown → delta de correção com a
  pos antiga → rollback do pending).
- **E2E de movimento sem seam de teste**: assinatura do canvas (soma
  ponderada por índice de getImageData) detecta mudança de sprite sem expor
  a engine; polling com toPass evita flake.
- **cooldown com monotonic time**: `System.monotonic_time(:millisecond)` +
  `last_input_at` no participante; `step_ms=0` no setup de teste desliga o
  cooldown, `10_000` força a rejeição.

Decisões de implementação:
- Rejeição por bounds/colisão publica correção; cooldown/malformado é drop
  silencioso (evita spam; o cliente já não move localmente contra parede).
- `dir` derivado de dx/dy no servidor (fonte de verdade do facing).
- Interpolação só para remotos; self usa previsão (já imediata/suave).

### 2026-07-05 — Iteração 4 (Fase 2 COMPLETA + fechada)

Runtime JS do espaço (TDD, 41 testes Vitest do espaço; suíte JS 3714 verde) +
backend do protocolo. Fluxo E2E ponta-a-ponta verde num browser real.

Frontend (`js/lib/space/` + `js/hooks/space/`):
- `protocol.js` — versão, constantes `CLIENT_EVENTS/SERVER_EVENTS`,
  normalização defensiva de `space_init/snapshot/delta/participant` (defaults
  seguros; versão desconhecida loga `console.error` e segue).
- `map.js` — `SpaceMap.from(def)` indexa a definição recebida: colisão em
  `Set` (`isBlocked` inclui out-of-bounds), `zoneAt`, `seat/interactable` por
  id, `defaultSpawn`, `floorTile(x,y)` lendo `layers.floor` com fallback.
- `sprite_atlas.js` — atlas autoral procedural (11 tiles + 4 avatares×4
  direções + board art), paleta como dígitos hex sem `#` montados via
  `String.fromCharCode(35)` (padrão game_colors → audit-clean), cache lazy,
  `OffscreenCanvas`→`createElement` fallback.
- `camera.js` — segue o avatar local, clampa às bordas, `worldToScreen`.
- `renderer.js` — Canvas 2D, `imageSmoothingEnabled=false`, floor a partir de
  `map.floorTile`, avatares ordenados por Y, labels de nick.
- `engine.js` — estado local (participants Map), `start(init)`/`applySnapshot`/
  `applyDelta` (joins/leaves/updates), rAF loop injetável, `destroy()` limpa
  rAF+listener resize+renderer.
- `space_canvas_hook.js` lazy (`serverEvents: []`) — abre `Socket("/socket")`,
  join `space:<token>` com `join_token`, roteia delta/snapshot→engine,
  `destroyed` faz engine.destroy+channel.leave+socket.disconnect. Factories
  de socket/engine injetáveis p/ teste.

Backend:
- `space_init` reescrito p/ o protocolo: `%{version, token, self_key, map
  (definição completa inline), config, snapshot}`.
- `build_snapshot` → shape do protocolo `%{server_time, participants:
  %{key => view}}`; `participant_view` com chaves JSON limpas (sem `?`, sem
  campos server-only).
- Avatar determinístico por participante (`avatar_for`, phash2 do key, cicla
  os 4 evitando colisão) — em sync com `AVATAR_IDS` do JS.
- `tavern_cafe_v1` ganhou `layers.floor` (matriz 48×64 gerada: perímetro
  wall_stone, side_room floor_stone, quiet_corner floor_grass, resto
  floor_wood).
- Takeover de reconexão já vinha da Fase 1.

Infra de teste:
- `vitest.config.js` aliasa `phoenix` → `deps/phoenix/priv/static/phoenix.mjs`
  (espelha o `NODE_PATH=deps` do esbuild) p/ testar hooks que importam Socket.
- ChannelCase de space_init atualizado ao novo shape + teste de broadcast
  `participant_joined` com 2 sockets.
- E2E `space-canvas.spec.ts`: registra, entra em canal, `/space`, abre
  `/space/<token>`, valida shell+título e canvas não-branco (amostra de
  pixels com variância). VERDE.

Aprendizados desta iteração:
- **`OffscreenCanvas` é undefined no jsdom** mas `document`/canvas existem;
  atlas usa fallback `createElement` e guarda `if (ctx)` (getContext 2d é null
  no jsdom — canvas mantém dims, contrato testável sem pixels). Falha inicial
  "document is not defined" foi transiente de setup do jsdom (re-run passou).
- **`phoenix` não resolve no vitest** sem alias (esbuild usa NODE_PATH=deps) —
  alias no vitest.config resolve.
- **eslint do projeto: `eqeqeq: ["error","always"]`** — `!= null` quebra; usar
  helper `isPresent` (`!== undefined && !== null`). `no-console` é só warning
  (surface de erro é OK, igual aos hooks existentes).
- **audit.styles escaneia JS por `#[0-9a-fA-F]{3,8}`** (categoria JS-COLOR) —
  paleta de sprite como dígitos sem `#` + `String.fromCharCode(35)` é o padrão
  audit-clean (game_colors.js).
- **enforce_hooks_contract.cjs (lint.hooks) NÃO está no `make ci`** — mas
  greps ingênuos: `import(...)` em JSDoc `@param {import("./x").T}` dispara
  falso-positivo de dynamic-import; usar tipos simples no JSDoc. (Pré-existente
  fora do meu escopo: LobbyMediaHook readyEvent sem handler — não corrigido,
  feature diferente, fora do gate.)
- **Snapshot da Fase 1 era lista; protocolo quer map keyed** — mudança de
  contrato deliberada, ChannelCase atualizado junto.
- **DB e2e (`retro_hex_chat_e2e`) precisa `MIX_ENV=e2e mix ecto.migrate`**
  separado — o E2E falhou com "relation virtual_space_sessions does not exist"
  até migrar; e `MIX_ENV=e2e mix assets.build` antes do playwright.
- **credo --strict do CI**: comprehension aninhada + cond estoura nesting/
  complexity; extrair `floor_tile/2` resolve.

Decisões de implementação:
- space_init sempre carrega o mapa completo inline (decisão 21); o JS só
  indexa, nunca tem cópia própria.
- Camada `floor` gerada programaticamente (não Tiled); renderer consome
  `floorTile` com fallback procedural p/ tiles fora da matriz.
- Avatar determinístico por key (reconnect preserva o visual).

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
