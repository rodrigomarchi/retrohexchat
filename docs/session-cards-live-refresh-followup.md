# Follow-up: atualização ao vivo dos cards de sessão (P2P / Arcade)

Status: proposta para revisão. Faz sequência ao já implementado em
`docs/mobile-chat-message-format-plan.md` (formato de mensagens + cards ricos).

## O que já foi entregue

Convites de lobby P2P (`:p2p_invite`) e links de Arcade (`:arcade_link`) agora
renderizam como **cards ricos** de sessão: ícone do assunto, quem criou, linha do
tempo (criado → conectado/iniciado → encerrado), duração, motivo e um botão de
ação (Entrar / Abrir lobby / Abrir Arcade) enquanto a sessão está viva. Sessões
terminais mostram o estado final e escondem o botão.

A montagem do card acontece em `RetroHexChatWeb.ChatLive.Helpers.SessionCard.enrich/1`,
que extrai o token do conteúdo, chama `Lobby.session_summary/1` /
`Arcade.session_summary/1` e anexa `:session_card` ao item de stream. Os
componentes de render (`chat_message/1`, `MessageRow`, `SessionCard`) permanecem
puros.

## A limitação (real, confirmada no código)

O resumo do card é consultado **no momento em que o item de stream é montado**.
Isso resolve corretamente:

- sessões **históricas/terminais**: sempre que a linha é (re)montada, o
  `session_summary` é lido do banco já no estado final;
- sessões **vivas**: mostram o estado atual no instante da montagem.

O que **não** acontece hoje: um card já renderizado na tela **não** vira sozinho
para o estado terminal quando a sessão encerra. Ele continua exibindo o estado
"vivo" (por exemplo `conectado` com o botão `Abrir lobby`) até que a linha seja
remontada.

Quando a linha é remontada (e o card se autocorrige):

- **P2P invite** (`:p2p_invite`): persistido como PM. Ao **reabrir a conversa**,
  o histórico é relido e o `enrich` reconsulta o resumo → card mostra o estado
  terminal. Ou seja: corrige ao trocar de aba, **não** ao vivo.
- **Arcade link** (`:arcade_link`): é **efêmero** (não vai para o banco) e sua
  linha some ao trocar de canal/aba. Nasce vivo (`pending`/`lobby`) e, na
  prática, **nunca** exibe o estado terminal no card — só a nota textual de
  encerramento na aba Status.

### Evidências no código

Padrão de "reinserir a linha pelo mesmo id" (é o mecanismo que faltaria acionar):

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/messages.ex:147`
  — `message_edited` → `MessageViewport.insert(socket, updated_item)` (mesmo id
  atualiza a linha no lugar).
- idem `:163` para `message_deleted`.

Eventos de fim de sessão que o chat recebe (assina `user:#{nickname}` em
`live/app/chat_live.ex:102`):

- `lobby_session_ended` — `apps/retro_hex_chat/lib/retro_hex_chat/lobby/session_server.ex:592`
  - payload: `%{peer_nick, reason, duration_seconds}` — **sem token / session_id**.
  - **Não há handler no chat**; cai no catch-all `handle_info(_, socket) ->
    {:cont, socket}` em `live/chat_live/pubsub_handlers.ex:259`. Nada acontece com
    o card.
- `arcade_session_ended` — `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/solo_session_live.ex:265`
  - payload: `%{game_name, reason, duration_seconds}` — **sem token**.
  - Handler existe em `live/chat_live/pubsub_handlers.ex:218`, mas **só empurra
    uma mensagem de status** (`push_status_message`); não toca na linha do card.

Ids das linhas (para saber se dá para mirar a linha certa):

- Arcade: id efêmero `"system-#{System.unique_integer([:positive])}"`
  (`command_dispatch.ex:321` e `pubsub_handlers.ex:199`) — **aleatório**, não
  derivado do token → hoje é impossível localizar a linha do card para reinserir.
- P2P invite: id estável = `pm.id` (id do banco) → mirável, desde que se saiba
  qual PM corresponde à sessão.

## Causas-raiz

1. **Linha montada uma vez.** Depois do `stream_insert`, a linha só muda se for
   reinserida com o mesmo id. Nenhum evento de fim de sessão dispara essa
   reinserção para os cards.
2. **Eventos de fim não carregam identidade da sessão.** `lobby_session_ended` e
   `arcade_session_ended` não incluem `token` (nem `session_id`/`session_kind`).
   Sem isso não dá para reconsultar o resumo nem localizar a linha.
3. **Arcade não tem id estável nem persistência.** O card do Arcade usa id
   aleatório e é efêmero; some ao trocar de canal e não é remontado do histórico.
4. **Não há vínculo estável token → linha.** Para o P2P, mesmo com o token no
   evento, é preciso descobrir qual PM (`pm.id`) é aquela sessão. Hoje `messages`
   e `private_messages` não têm coluna `metadata`, então o vínculo teria que vir
   de outra fonte (mapa em memória no socket, ou busca por conteúdo — frágil).

## Proposta de implementação

Objetivo: quando a sessão encerrar (ou mudar de status relevante), o card já
visível vira para o estado correto **sem** o usuário trocar de aba.

### Passo 1 — Enriquecer os eventos de fim com a identidade da sessão

Incluir `token` (e, de brinde, `session_kind` e `session_id`) nos payloads:

- `lobby/session_server.ex` → `notify_chat_user/4`: adicionar `token: session.token`.
- `solo_session_live.ex` → broadcast de `arcade_session_ended`: adicionar
  `token: token` (a var já existe no escopo).

Compatível com o que já existe; apenas amplia o mapa.

### Passo 2 — Id estável para o card de Arcade

Trocar o id efêmero `"system-<int>"` por `"arcade-<token>"` nos dois produtores
(`command_dispatch.ex` e `pubsub_handlers.ex` do `bot_notice`). Assim a linha
passa a ser mirável por `MessageViewport.insert(%{id: "arcade-<token>", ...})`.

Observação: como a linha ainda é efêmera (some ao trocar de canal), o refresh ao
vivo só vale enquanto o usuário permanece no mesmo canal. Persistir o
arcade-link (ou promovê-lo a mensagem real) é um passo opcional maior, fora deste
follow-up.

### Passo 3 — Vincular token → linha para o P2P invite

Duas opções, em ordem de preferência:

- **(A) Mapa em memória no socket.** Ao montar um card de P2P
  (`SessionCard.enrich` para `:p2p_invite`), registrar `token → pm.id` num assign
  (`session_card_rows :: %{token => row_id}`). No handler de
  `lobby_session_ended`, olhar o mapa, reconsultar o resumo e reinserir a linha.
  Simples, sem migração; custo: o mapa vive só na sessão atual (se a página foi
  recarregada, cai no comportamento atual de corrigir ao reabrir a conversa —
  aceitável).
- **(B) Coluna `metadata :map` em `private_messages`** (e `messages`), guardando
  `%{session_kind, session_id, token}`. Torna o vínculo persistente e permite
  localizar a mensagem por metadado. É a arquitetura "ideal" citada no plano
  original, mas exige migração + backfill; recomendo deixar para quando houver
  outra motivação para o campo `metadata`.

### Passo 4 — Handlers de refresh no chat

Em `live/chat_live/pubsub_handlers.ex`:

- Novo handler `lobby_session_ended`: `SessionCard` reconsulta
  `Lobby.session_summary(token)`, e:
  - Arcade/P2P vivo na tela → `MessageViewport.insert` da linha reenriquecida
    (mesmo id), virando o card para terminal.
  - Manter (ou adicionar) a nota de status textual, se desejado.
- Estender o handler existente `arcade_session_ended` para, além da nota de
  status, reinserir `"arcade-<token>"` reenriquecido.

Fallback: se o token não resolver (sessão purgada) ou a linha não existir mais no
stream, não fazer nada — o `stream_insert` de um id inexistente apenas cria uma
linha nova indesejada, então **checar presença** antes de reinserir (ou só
reinserir quando o id estiver no mapa do Passo 3 / for um id de PM conhecido).

## Escopo e risco

- Passos 1, 2 e 4 (sem migração, opção 3A): mudança localizada, baixo risco.
  Toca 4 arquivos de produção + handlers. É o caminho recomendado.
- Passo 3B (migração `metadata`): maior, com migração e backfill; adiar.
- Cuidado principal: **não** criar linha nova ao reinserir um id que já saiu do
  stream (trocar de canal). Guardar a checagem de presença / restringir ao
  canal/PM ativo.

## Plano de testes

- **Unit (component)**: já coberto — `SessionCard` renderiza estados vivo e
  terminal (`test/.../components/session_card_test.exs`).
- **Unit (resolver)**: já coberto — `enrich/1` resolve e faz fallback
  (`test/.../helpers/session_card_test.exs`).
- **Integração (novo)**: montar um card P2P vivo no stream, enviar
  `lobby_session_ended` com `token`, e assertar que a linha reinserida contém o
  estado terminal (sem CTA). Idem Arcade com `"arcade-<token>"`.
- **Regra anti-regressão**: enviar `lobby_session_ended` para um token cuja linha
  não está mais no stream e assertar que **nenhuma** linha nova aparece.
- Seguir a memória `flaky-feature-test-suite`: assertar em estado síncrono
  (`:sys.get_state` / dado persistido / unit de componente), nunca em mensagens
  assíncronas de `send_update`.
