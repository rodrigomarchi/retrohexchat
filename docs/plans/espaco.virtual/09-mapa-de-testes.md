# Mapa de testes (TDD)

Status: criado na fase de planejamento (2026-07-05) para tornar o TDD mecânico:
cada item do `05-plano-implementacao.md` referencia os casos abaixo. O loop
escreve os testes ANTES da implementação, vê vermelho, implementa até verde.

Convenções auditadas:

- Domínio: `apps/retro_hex_chat/test/retro_hex_chat/virtual_space/…`, com
  `use RetroHexChat.DataCase` (DB real via sandbox, sem mocks), tags
  `@moduletag :unit` ou `:integration` — seguir o espelho de
  `test/retro_hex_chat/lobby/` e `test/retro_hex_chat/p2p/`.
- Web/LiveView: `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/…`, tag
  `@moduletag :liveview`, `import Phoenix.LiveViewTest`.
- Channel: `apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/…`, com o
  novo `RetroHexChatWeb.ChannelCase` (infra criada na Fase 1).
- JS: Vitest em `apps/retro_hex_chat_web/assets/test/lib/space/…` e
  `test/hooks/space/…`, espelhando `js/`.
- E2E: `e2e/tests/space-*.spec.ts`; rodar SEMPRE por arquivo (nunca a suite
  toda), matar servidor stale na :4003 antes.
- Nunca assertar em mensagens assíncronas de stream de LiveView; usar estado
  síncrono (`:sys.get_state` no SessionServer), unit de domínio ou dados
  persistidos. Sem sleep/render-retry.

## Fase 1

### `virtual_space/schema/session_test.exs` (:unit)

- changeset válido com defaults (`status "pending"`, `map_id "tavern_cafe_v1"`,
  `max_participants 20`).
- changeset rejeita status fora de
  `pending/active/closed/expired/failed`.
- token único (constraint) e obrigatório; `channel_name` e `creator_id`
  obrigatórios.
- `terminal?/1` verdadeiro para closed/expired/failed, falso para
  pending/active.

### `virtual_space/policy_test.exs` (:integration)

- criar: aceita usuário registrado+identificado com permissão de postar no
  canal; rejeita guest; rejeita não identificado; rejeita origem PM/Status.
- entrar: aceita membro elegível em canal público; rejeita guest; canal
  invite-only exige acesso conforme `Channels.Policy`; rejeita sessão terminal.
- capacidade: rejeita join quando participantes ativos == max e o usuário não
  está no espaço; aceita reentrada de quem já está (takeover).
- fechar: criador pode; participante comum não; admin/server operator pode.
- kick/mute/change_map: criador e admin podem; participante comum não.

### `virtual_space/map_test.exs` (:unit)

- `Map.get/1` retorna `{:ok, definition}` para os 4 ids e
  `{:error, :unknown_map}` para id arbitrário.
- definição do `tavern_cafe_v1` é consistente: spawns fora de colisão, zonas
  dentro dos bounds, assentos não colidem entre si, interactables com ids
  únicos.

### `virtual_space/service_test.exs` (:integration)

- create gera token url-safe de 32 bytes, persiste sessão `pending` vinculada
  ao canal, inicia child no supervisor.
- create respeita rate limit (config `p2p_session_rate_limit` de teste).
- create aplica TTL default 2h, aceita `ttl=` dentro do teto e rejeita acima
  de `virtual_space_max_ttl`.
- join em token inexistente retorna `{:error, :not_found}`; em token vencido
  marca `expired` antes de recusar; em token válido sem processo re-inicia o
  child (recuperação pós-restart).
- close registra `closed_at`/`closed_reason` e derruba o processo.

### `virtual_space/session_server_test.exs` (:integration)

- primeiro join transita `pending -> active` e grava `activated_at`.
- join atribui spawn determinístico livre; dois joins não caem no mesmo tile
  quando há spawn livre.
- leave marca offline mas mantém posição; rejoin do mesmo
  `registered:<id>` faz takeover e preserva posição.
- `pending` sem entrada expira em `virtual_space_pending_timeout`.
- sessão ativa expira no `expires_at` e faz broadcast de fim.
- `session_summary/1` reflete contagem/status do processo vivo.

### `commands/handlers/space_test.exs` (:unit / :integration)

- `/space` em canal ativo cria sessão e retorna
  `{:ok, :ui_action, :space_invite, %{target:, token:, title:, creator_id:}}`.
- parse: `#canal-alvo` opcional, nome opcional, `ttl=` opcional com default 2h;
  formatos inválidos de ttl retornam erro de uso.
- recusa em PM/Status mesmo com `#canal-alvo` informado.
- recusa usuário não identificado.
- `help/0` e `syntax_definition/0` presentes; categoria `:user`; comando
  listado no `Commands.Registry`.

### `chat/message_test.exs` (extensão) (:unit)

- changeset de canal aceita type `space_invite`.

### Web: `live/space_live_test.exs` (:liveview)

- mount sem `chat_nickname` redireciona para `/connect`.
- token inexistente renderiza estado inválido; token expirado renderiza
  terminal; sessão cheia renderiza estado de cheio.
- token válido + usuário elegível renderiza o shell com
  `phx-hook="SpaceCanvasHook"`, `data-space-token` e `data-join-token`.
- `join_token` assinado verifica com o mesmo salt e expira no `max_age`.
- usuário sem acesso ao canal privado da sessão vê recusa.

### Web: `channels/space_channel_test.exs` (ChannelCase, novo)

- join com `join_token` válido responde `{:ok, space_init}` com snapshot.
- join com token adulterado/expirado recusa.
- join além da capacidade recusa com erro claro.
- leave/terminate remove o participante do SessionServer.

### Web: card (:liveview)

- comando `/space` publica mensagem `space_invite` persistida no canal alvo.
- card enriquecido mostra título, criador, canal, mapa, validade e CTA quando
  vivo; sem CTA quando terminal (montagem nova reflete o estado atual).
- fallback textual contém `/space/<token>`.

### Help (:unit)

- tópico do `/space` presente na categoria Commands; tópico "Virtual spaces"
  presente em Features; ambos com shape válido
  (`id/title/category/keywords/icon/description`).

## Fase 2

### Vitest `test/lib/space/protocol.test.js`

- normalização de `space_init`/`space_snapshot`/`space_delta` (campos
  faltantes viram defaults seguros; versão desconhecida loga erro).

### Vitest `test/lib/space/map.test.js`

- indexação da definição recebida: colisão vira `Set` consultável; consulta de
  zona por tile; lookup de assento/interactable por id; bounds.

### Vitest `test/lib/space/sprite_atlas.test.js`

- atlas gera entradas para todos os tile ids usados pelo `tavern_cafe_v1` e
  avatares nas 4 direções (contrato de chaves, sem asserção de pixels).

### Vitest `test/lib/space/engine.test.js`

- aplicar snapshot popula participantes; delta atualiza posição; `destroy()`
  cancela rAF e remove listeners (spies).

### Vitest `test/hooks/space/space_canvas_hook.test.js`

- contrato do hook lazy (registro com `serverEvents: []`, `reason`); mounted
  monta engine com dataset; destroyed chama `channel.leave()` e
  `socket.disconnect()`.

### Domínio/Channel

- `space_init` carrega o mapa completo serializado da fonte Elixir
  (ChannelCase: resposta do join contém `map.id`, colisão e assentos).
- broadcast `participant_joined/left` chega aos demais sockets (ChannelCase
  com 2 joins).

### E2E `e2e/tests/space-canvas.spec.ts`

- abre `/space/:token` com usuário identificado e verifica canvas não branco
  (amostra de pixels) e nome do espaço no shell.

## Fase 3

### Domínio `session_server` movimento (:integration)

- passo cardinal adjacente válido atualiza posição e publica delta com
  `seq_ack`.
- passo em tile de colisão é rejeitado; posição oficial não muda; delta de
  correção publicado.
- passo fora dos bounds rejeitado; `dx/dy` fora de {-1,0,1} ou diagonal
  rejeitado.
- segundo input antes de `virtual_space_step_ms` é rejeitado (cooldown).
- input de participante ausente/sessão terminal é ignorado.

### Vitest `test/lib/space/input.test.js`

- setas/WASD viram intenções; teclas repetidas coalescem; foco em
  input/textarea suprime captura.

### Vitest `test/lib/space/engine.test.js` (previsão/reconciliação)

- previsão local move imediatamente; `seq_ack` confirma e descarta previsões
  antigas; divergência aplica correção suave; colisão local impede animar
  contra parede.

### Vitest `test/lib/space/interpolation.test.js`

- remoto interpola entre posição anterior e nova no intervalo esperado.

### E2E `e2e/tests/space-movement.spec.ts`

- 2 usuários no mesmo espaço: A anda e B vê o avatar de A mudar de tile.
- input inválido (spam de teclas contra parede) não teleporta A na visão de B.

## Fase 4

### Domínio (:integration)

- entrar em zona atualiza `zone_id` e publica `space_zone_changed`.
- chat: mensagem > 160 chars rejeitada; participante mutado não envia; rate
  limit aplicado; texto é escapado/normalizado.
- cadeira: sentar reserva `seat_id` e muda pose; segunda ocupação rejeitada;
  andar levanta primeiro; leave libera o assento.
- interact em quadro retorna `space_modal` com asset do mapa; alvo
  distante/inexistente rejeitado.
- capacidade lida de `server_settings` (`space_max_participants`) com
  fallback.

### Vitest

- `test/lib/space/chat.test.js`: balão expira após N segundos; log lateral
  limitado.
- `test/lib/space/seating.test.js` e `test/lib/space/interactions.test.js`:
  resolução do tile à frente; aplicação de respostas oficiais.
- `test/lib/space/modal.test.js`: abre/fecha modal de quadro; Escape fecha.
- renderer: balão renderiza texto como texto (nunca HTML).

### E2E `e2e/tests/space-office.spec.ts`

- fluxo: entrar, sentar numa cadeira, enviar mensagem, ver balão, abrir
  quadro/modal, mudar de sala.

## Fase 5

### Domínio (:integration)

- kick remove participante, bloqueia reentrada na sessão e publica evento;
  alvo recebe motivo.
- mute impede chat e unmute restaura.
- close manual transita para `closed` e derruba clientes com estado terminal.
- change_map: novo snapshot completo; todos em spawn válido do novo mapa;
  identidade/mute preservados; map_id fora do registry rejeitado.
- ações administrativas de participante comum retornam `{:error, :forbidden}`.
- posição persiste em reload (snapshot leve em `metadata` no leave/map-change).

### Vitest

- HUD do criador só aparece para o criador; aplicação dos eventos
  `space_admin_notice`/`space_closed` na engine.

### Consistência dos 4 mapas (:unit)

- os 4 mapas do registry passam nas mesmas invariantes do
  `map_test.exs` (spawns livres, zonas nos bounds, assentos válidos).

### E2E `e2e/tests/space-admin.spec.ts`

- criador expulsa B; B vê tela de expulso e não reentra.

## Fase 6

### Domínio (:integration)

- cleanup task expira sessões vencidas e pula sessões com processo vivo.
- reinício: matar o processo e fazer join re-inicia child com posições do
  snapshot de `metadata`.
- fechar aba (terminate do Channel) marca participante offline sem remover
  posição.

### E2E `e2e/tests/space-reconnect.spec.ts`

- reload da página volta no mesmo tile; segunda aba faz takeover da primeira.

### Gate final

- `make ci` completo verde (as 9 checagens) — nenhum teste do mapa inteiro
  pulado ou tagueado como skip.
