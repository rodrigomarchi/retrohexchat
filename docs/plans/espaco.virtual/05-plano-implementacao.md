# Plano de implementação

Status: auditado contra o codebase em 2026-07-05. Decisões fechadas com o
usuário. Este documento é a lista de tarefas canônica do loop de implementação:
o agente marca `[x]` aqui conforme avança e registra aprendizados em
`PROGRESS.md`.

## Regras do ciclo (obrigatórias)

- **TDD do começo ao fim**: cada item começa pelos testes do
  `09-mapa-de-testes.md` (vermelhos), depois implementa até verde. Nunca
  implementar antes do teste existir.
- **Validação por arquivo durante o loop** (o CI completo demora; não rodar a
  cada passo):
  - Elixir: `mix format <arquivos>` + `mix test <arquivo_de_teste>` (do app
    correspondente) + `mix credo <arquivos>` quando tocar módulo novo;
  - JS: `npx vitest run <arquivo>` + `npx eslint <arquivos>` +
    `npx prettier --check <arquivos>` (em `apps/retro_hex_chat_web/assets`);
  - E2E: somente specs alvo, `npx playwright test <arquivo>:<linha>` — nunca a
    suite inteira; matar servidor stale na :4003 antes de confiar no resultado.
- **`make ci` completo SOMENTE no fechamento de cada fase**, imediatamente
  antes do commit da fase. Se falhar, a fase não fecha — corrigir e rodar de
  novo. Nenhuma das 9 checagens pode ser pulada no fechamento.
- **Um commit por fase**, grande e funcional, direto na `main` (nunca criar
  branch). Stage por caminho explícito (`git add <paths>`), nunca `git add -A`.
- **Aprendizados**: cada iteração do loop registra em `PROGRESS.md` o que fez,
  o que aprendeu e o próximo passo antes de encerrar.
- Todo módulo/função pública com `@spec`; LiveViews finas delegando ao domínio;
  aliases já no primeiro write; comentários descrevem o código, não a migração;
  sem cores hardcoded em Elixir/JS; sem SVG inline (usar módulos `Icons`);
  nenhum `catch` silencioso no JS.

## Fase 0: decisão e documentação — CONCLUÍDA (2026-07-05)

- [x] Documentos em `docs/plans/espaco.virtual/`.
- [x] Auditoria dos apontamentos contra o codebase (3 varreduras: domínio,
      web, JS).
- [x] Ambiguidades levadas ao usuário e fechadas: Phoenix Channel; card
      persistido `space_invite` em mensagem de canal; sem refresh ao vivo de
      card; mapa canônico no Elixir.
- [x] Nome final: contexto `VirtualSpace`, rota `/space/:token`, comando
      `/space [#canal-alvo] [nome-do-space] ttl=2h`, limite default 20
      configurável via `server_settings`.
- [x] Mapa de testes (`09-mapa-de-testes.md`), prompt de loop
      (`10-prompt-loop.md`) e `PROGRESS.md` criados.

## Fase 1: domínio, comando, card e channel mínimo (sem canvas)

Backend — domínio:

- [x] Migration `virtual_space_sessions` (gabarito:
      `20260625200000_create_lobby_sessions.exs`; token size 64 + unique index,
      FK `creator_id` -> `registered_nicks`).
- [x] `VirtualSpace.Schema.Session` (status
      `pending/active/closed/expired/failed`, `terminal?/1`).
- [x] `VirtualSpace.Queries` (get por token, listagem de vencidas, expire).
- [x] `VirtualSpace.Policy` (criar/entrar/fechar/kick/mute/change_map;
      integração com `Channels.Policy`/`Membership`/`Modes`).
- [x] `VirtualSpace.Map` + `VirtualSpace.Maps.TavernCafeV1` esqueleto
      (definição mínima válida: bounds, spawn, collision vazia é aceitável
      nesta fase).
- [x] `VirtualSpace.Registry` + `VirtualSpace.Supervisor` (gabarito Lobby) +
      children em `application.ex`.
- [x] `VirtualSpace.SessionServer` mínimo (join/leave/close/expire, estado de
      participantes, snapshot simples; TTLs via `Application.get_env`).
- [x] `VirtualSpace.Service` (create com token forte + rate limit via
      `P2P.RateLimiter.check_session_rate/1`, join com recuperação de processo,
      close, summaries).
- [x] Facade `RetroHexChat.VirtualSpace` com `@spec` em tudo.
- [x] Setting `"space_max_participants"`: leitura com fallback + whitelist em
      `Handlers.Admin.Server.validate_setting_value/2`.
- [x] Comando `Handlers.Space` (behaviour completo: `help/0`,
      `syntax_definition/0`, `category/0 = :user`; parse de
      `[#canal-alvo] [nome] ttl=`; recusa em PM/Status) + registro em
      `Commands.Registry`.

Backend — web:

- [x] Tipo `space_invite` em `Chat.Message @type_values` +
      `Chat.Service @known_types`.
- [x] `Helpers.SpaceInvite` + especial-case em
      `CommandDispatch.handle_dispatch_result/3` (análogo `:lobby_invite`).
- [x] Enrich clause em `Helpers.SessionCard` + render em
      `Components.SessionCard`/`MessageRow` + pontos de
      `pubsub_handlers/messages.ex` (+ history/pagination enrich; migration
      alargou `messages.type` p/ varchar(20)).
- [x] Rota `live "/space/:token", SpaceLive` na `live_session :app_locale`.
- [x] `SpaceLive` shell: auth via `SessionHelpers`, validação de token/policy,
      terminal retro para inválido/expirado/cheio, assinatura do `join_token`
      (`Phoenix.Token`, padrão `P2P.SessionToken`), canvas placeholder com
      `phx-hook="SpaceCanvasHook"` + data attributes.
- [x] Infra Phoenix Channel do zero: `UserSocket`, `socket "/socket"` no
      endpoint, `SpaceChannel` (join valida `join_token` + policy + capacidade;
      responde snapshot simples; leave em `terminate/2`),
      `test/support/channel_case.ex`.
- [x] Cleanup periódico (gabarito `P2P.CleanupTask`) + config
      `virtual_space_*`.
- [x] Tópicos de help (`/space` em Commands; "Virtual spaces" em Features) +
      strings gettext (domínios afetados extraídos; ~61 strings novas
      traduzidas de verdade nos 20 locales exigidos).

Fechamento da fase:

- [x] Testes da fase no `09-mapa-de-testes.md` §Fase 1 todos verdes.
- [x] `make ci` completo verde (9/9, incluindo dialyzer).
- [x] Commit único da fase na `main`.

## Fase 2: canvas, snapshot e presença

Frontend:

- [ ] `SpaceCanvasHook` lazy (`serverEvents: []`, `reason` obrigatório) em
      `hooks/lazy_feature_hooks.js`.
- [ ] `lib/space/protocol.js` (constantes de eventos, normalização,
      versionamento).
- [ ] `lib/space/map.js` (indexa definição recebida no `space_init`: colisão em
      `Set`, zonas, assentos, interactables).
- [ ] `lib/space/sprite_atlas.js` autoral (tiles, avatares 4 direções,
      paleta própria).
- [ ] `lib/space/camera.js` + `lib/space/renderer.js` (camadas, ordenação por
      Y, `imageSmoothingEnabled = false`, escala inteira).
- [ ] `lib/space/engine.js` (ciclo de vida, rAF, estado local, aplicação de
      snapshot).
- [ ] Cleanup completo em `destroyed` (rAF, listeners, timers, canvas,
      `channel.leave()` + `socket.disconnect()`).

Backend:

- [ ] `tavern_cafe_v1` completo no domínio (camadas, colisão real, zonas,
      assentos, interactables, spawns).
- [ ] `space_init` como resposta do join com mapa inline + snapshot.
- [ ] Broadcasts `participant_joined/left` -> eventos do Channel.
- [ ] Takeover de reconexão pelo mesmo `participant_key` (posição preservada).

Fechamento da fase:

- [ ] Testes §Fase 2 verdes (Vitest de map/protocol/atlas, contrato do hook,
      ChannelCase de snapshot, E2E canvas não branco).
- [ ] `make ci` completo verde.
- [ ] Commit único da fase na `main`.

## Fase 3: movimento autoritativo

Backend:

- [ ] `space_input` no Channel -> `VirtualSpace.input/3`.
- [ ] Validação: passo cardinal adjacente, colisão, bounds, cooldown
      `virtual_space_step_ms`, ignore em sessão terminal/participante ausente.
- [ ] Delta broadcast com `seq_ack`.

Frontend:

- [ ] `lib/space/input.js` (setas/WASD, coalescência, respeito a foco de
      input/textarea).
- [ ] Previsão local com colisão local + envio de intenção.
- [ ] Reconciliação por `seq_ack` (snap curto/easing 80-120ms em divergência).
- [ ] `lib/space/interpolation.js` para remotos.
- [ ] Labels de nickname sobre avatares.

Fechamento da fase:

- [ ] Testes §Fase 3 verdes (unit servidor de colisão/cooldown/bounds, Vitest
      de previsão/reconciliação, E2E 2 usuários vendo movimento mútuo, input
      inválido não move).
- [ ] `make ci` completo verde.
- [ ] Commit único da fase na `main`.

## Fase 4: escritório vivo

- [ ] Zonas com transição (`zone_id` em delta; `space_zone_changed`).
- [ ] Chat textual global (`space_chat_bubble`: limite 160 chars, escape,
      rate limit, mute).
- [ ] Balão de fala sobre avatar + log lateral efêmero.
- [ ] Cadeiras: reserva no servidor (`seats`), pose `sitting`, levantar ao
      andar, rejeição de segunda ocupação.
- [ ] Interactables: quadro -> `space_modal` com imagem autoral do atlas.
- [ ] HUD de participantes/lotação.
- [ ] Telas de cheio/expirado/encerrado refinadas.

Fechamento da fase:

- [ ] Testes §Fase 4 verdes.
- [ ] `make ci` completo verde.
- [ ] Commit único da fase na `main`.

## Fase 5: poderes do criador e mapas

- [ ] `space_admin_action`: kick (com bloqueio de reentrada na sessão), mute/
      unmute, close, change_map — validação de papel no servidor.
- [ ] UI do criador no HUD.
- [ ] Três mapas restantes no registry Elixir (`guild_hall_v1`,
      `arcane_library_v1`, `garden_camp_v1`) seguindo o playbook do primeiro.
- [ ] Troca de mapa: snapshot completo, respawn válido, preserva identidade/
      mute/presença.
- [ ] Persistência de posição em reload/reconnect (snapshot leve em `metadata`
      em eventos de leave/map-change, nunca por passo).

Fechamento da fase:

- [ ] Testes §Fase 5 verdes.
- [ ] `make ci` completo verde.
- [ ] Commit único da fase na `main`.

## Fase 6: robustez e produto completo

- [ ] Cenários de reconnect/offline (fechar aba marca offline; takeover).
- [ ] Reinício do processo retoma sessão não expirada (join re-inicia child).
- [ ] Métricas simples (PromEx se encaixar no padrão existente).
- [ ] Logs de erro úteis em todas as bordas.
- [ ] Revisão final de help/i18n (traduções reais, não msgstr seeds).
- [ ] Passada de `/code-review` no diff acumulado e correções.
- [ ] Verificação manual guiada (abrir espaço com 2+ sessões, fluxo completo
      do produto).

Fechamento da fase:

- [ ] Testes §Fase 6 verdes.
- [ ] `make ci` completo verde.
- [ ] Commit único da fase na `main`.
- [ ] `PROGRESS.md` marcado como CONCLUÍDO com resumo final.

## Fases futuras (fora da V1)

- proximidade de áudio/vídeo (server-mediated/SFU);
- salas privadas; múltiplos andares; portais entre espaços;
- editor de mapa; importador Tiled/TMJ;
- persistência permanente de escritórios;
- uploads/edição de imagens de quadros;
- refresh ao vivo de cards de sessão no chat.

## Decisões fechadas

Ver `06-ambiguidades-fechadas.md` (17 originais + 4 da auditoria de
2026-07-05).

## Riscos

- Primeira Phoenix Channel do projeto: sem análogo local; riscos de
  configuração de socket/CSRF e de teste. Mitigação: ChannelCase próprio desde
  a Fase 1 e testes de join antes de qualquer feature.
- Previsão/reconciliação sem precedente no repo. Mitigação: Vitest denso na
  engine antes da integração; tile-a-tile simplifica o problema.
- Eventos realtime pesados. Mitigação: input discreto, deltas pequenos,
  limite 20.
- Canvas capturando teclado quebra chat. Mitigação: respeitar foco; testes de
  input com foco em textarea.
- Assets "inspirados" virarem cópia. Mitigação: tiles/personagens/nomes/paleta
  autorais; checkouts de referência são só pesquisa (ver
  `08-referencias-locais.md`).
