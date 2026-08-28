# Onda 4 — P2P: primeiro o transporte, depois a superfície

**Depende de:** ondas 0, 1 e 2.

**Entrega:** `P2PChannel` (sinalização fora do LiveView) e `/p2p/:token`.

**É a onda de maior risco do plano.** A sinalização 1:1 é a única que ainda passa
pelo socket do LiveView, e ela carrega a lógica de recuperação mais frágil do
produto — epoch, offer_id, `connection_reset`, o modelo de ofertante único, e a
regra de que o answerer nunca se recupera sozinho. Por isso ela é dividida em
duas fases, e a primeira **não muda nada** que o usuário veja.

---

## 1. O que existe hoje

```
domínio      RetroHexChat.Lobby  (SessionServer 937 linhas)
sinalização  socket do LiveView:
             JS pushEvent → ChatLive.handle_event → PubSub "lobby:<token>"
             → LiveView do par → push_event → JS
             (live/chat_live/p2p_session_events.ex, 2.258 linhas)
validação    RetroHexChat.Calls.SignalValidation  ← compartilhada com o SFU
rate limit   RetroHexChat.P2P.SignalingRateLimit  (ETS)
host         ChatLive — janela "p2p-call" (chat_live.html.heex:546)
             console: P2PSessionConsole (call / files / games / stats)
             setup:  p2p_setup_dialog  (chat_live.html.heex:1179)
             âncora: #lobby-webrtc, keyed por token (chat_live.html.heex:1205)
             stats:  App.P2PStats (122 linhas)
JS           hooks/lobby/lobby_webrtc_hook.js  + lib/p2p/lobby_connection.js (1.155)
             lib/p2p/media.js (1.191), file_transfer*.js, rtc_media_hook_factory.js
convite      PM real, tipo p2p_invite, via send_private_message
             (live/chat_live/helpers/lobby_invite.ex:71)
```

O que **não** passa pelo LiveView e portanto não muda: transferência de arquivo e
jogos, que andam sobre a `RTCPeerConnection` única multiplexada
([`guide/webrtc-p2p.md` §8.3, §8.4](../../guide/webrtc-p2p.md)).

---

## Fase 4A — `P2PChannel`, sem mudar uma tela

**Objetivo:** a sinalização 1:1 passa a andar por um Phoenix Channel cru, com o
`ChatLive` ainda como host. Nada muda para o usuário. Se algo quebrar, quebra
aqui, com a suíte E2E de P2P existente apontando o dedo.

### 4A.1 Servidor

1. `RetroHexChat.Lobby.JoinToken` — espelho exato de
   `RetroHexChat.GroupCall.JoinToken` (`group_call/join_token.ex`): salt próprio
   (`"p2p_join"`), `SignedToken.sign/3`, ligando `session_token`, `user_id` e
   `nickname`. Salt diferente não é decoração: é o que impede gastar um token de
   space numa porta de P2P (`signed_token.ex` moduledoc).
2. `RetroHexChatWeb.P2PChannel`, tópico `p2p:<session_token>`, registrado no
   `UserSocket` ao lado de `space:*` e `group_call:*`.
3. Migram do `p2p_session_events.ex` para o channel, **sem reescrever a lógica**:
   `lobby_webrtc_ready`, `lobby_signal`, `lobby_signal_replay_request`,
   `lobby_renegotiate`, `lobby_connected`, `lobby_restart`, `lobby_start_offer`,
   `lobby_start_answer`.
4. Toda entrada continua passando por `Calls.SignalValidation`. **Não criar um
   segundo validador.** A regra está escrita: "Relaxing a bound is a one-file
   change on purpose; a third copy is how one path silently gets a wider attack
   surface than the other" ([`guide/webrtc-p2p.md` §8.2](../../guide/webrtc-p2p.md)).
5. `P2P.SignalingRateLimit` passa a ser chamado pelo channel, do mesmo jeito que
   `GroupCall.RateLimiter` é chamado por `GroupCallChannel`.
6. O broadcast continua em `"lobby:#{token}"` e o `SessionServer` continua sendo
   o dono do ciclo de vida. **O domínio não muda nesta fase.**

### 4A.2 Cliente

`lobby_connection.js` (1.155 linhas) já concentra a lógica; o hook é fino, como
manda §15.1. O que muda é a fonte dos eventos: em vez de `this.pushEvent` /
`this.handleEvent` do LiveView, um `socket.channel("p2p:<token>")`.

Já existe o modelo pronto para copiar: `lib/group_call/conference_connection.js`
faz exatamente isso para o SFU. Seguir a mesma forma, inclusive na parte
chata — reconexão automática do channel pelo Phoenix, e rehydrate de nível de
aplicação por cima, porque "Phoenix rejoins channels automatically, but call
state living outside the channel does not come back"
([§8.5](../../guide/webrtc-p2p.md)).

### 4A.3 O que precisa sobreviver intacto

Cada item aqui é um bug já pago:

* **ofertante único** — só o criador emite oferta; nunca reordenar;
* **sinalização só começa depois que os DOIS hooks reportam ready** — a primeira
  oferta é descartada se o answerer ainda não está escutando
  (`p2p_session_events.ex` moduledoc);
* **epoch + offer_id + `connection_reset`** — respostas e candidatos de epoch
  antigo são descartados;
* **o answerer não se recupera sozinho** — ele pede ao iniciador via
  `lobby_renegotiate`, e é isso que faz dois cliques simultâneos em Retry serem
  idempotentes;
* **`candidate: ""` é sinal, não payload malformado** — é fim de candidatos, e só
  o Firefox manda. Recusar isso custa 13,2 s contra 2,1 s de conexão
  ([§8.6](../../guide/webrtc-p2p.md)).

### 4A.4 TDD da fase 4A

| Camada | Arquivo | Asserção |
|---|---|---|
| `:unit` | `.../lobby/join_token_test.exs` | assina/verifica; token de outro salt é `:invalid`; expirado é `:expired` |
| channel | `apps/retro_hex_chat_web/test/.../channels/p2p_channel_test.exs` (novo) | espelhar `group_call_channel_test.exs`: join válido / token forjado / token de outra sessão |
| channel | idem | SDP acima do limite recusado; candidato malformado recusado; **`candidate: ""` relayado** |
| channel | idem | rate limit de sinalização dispara e o payload é rejeitado sem derrubar o channel |
| channel | idem | sinal de epoch antigo é descartado; `connection_reset` com epoch novo passa |
| `:liveview` | existente, `chat_live` | o `ChatLive` não tem mais `handle_event` de sinalização |
| Playwright | `chat-p2p.spec.ts`, `chat-p2p-negotiation.spec.ts` | **verdes sem edição** |

A última linha é o critério da fase. Se um spec de P2P precisou mudar em 4A, o
comportamento mudou, e a fase falhou no que ela prometeu.

---

## Fase 4B — `/p2p/:token`

Com a sinalização num channel, o resto é a receita da onda 2.

### 4B.1 `RetroHexChatWeb.App.P2PLive`

* **root** em `/p2p/:token`;
* **nested** via `live_render/3` na janela `p2p-call` do chat.

`mount/3`: `Live.Surface` → `Lobby` resolve a sessão pelo token → `Lobby.Policy`
(`can_join?`) → assina `Lobby.JoinToken` → estado de setup no próprio mount.

Migram: `P2PSessionConsole` e suas quatro seções, `App.P2PStats`,
`P2PConfirmDialog`, e o `p2p_setup_dialog` — que, igual ao pré-join da onda 2,
vira o **primeiro estado da página** em vez de um diálogo do chat.

A âncora `#lobby-webrtc` continua com esse id exato: "the inner id MUST stay
`lobby-webrtc`: the media, game and file-transfer hooks locate the shared PC
through it" (`chat_live.html.heex:1199`). Ela muda de página, não de nome.

### 4B.2 A antessala do P2P é uma sala de partida — e isso conserta uma ordem frágil

Desenho: [`ux.md` §2.5](ux.md).

Por P1, a sessão P2P ganha host, `[Pronto]` e `[Iniciar]`. À primeira vista é
cerimônia a mais do que o "aceitar convite" de hoje. Não é: é a tornar visível
uma regra que hoje é implícita e já quebrou.

O moduledoc de `p2p_session_events.ex` diz, em maiúsculas, que a sinalização só
pode começar **depois que os dois hooks reportarem ready** — "never re-order
this: the first offer is dropped if the answerer's hook isn't listening yet". Ou
seja, o produto já tem um momento de "os dois estão prontos"; ele só não tem
nome, nem tela, nem forma de a pessoa saber que está esperando.

A sala de partida dá nome a ele:

| UI | Significado técnico |
|---|---|
| `[Pronto]` de cada um | dispositivos escolhidos **e** hook de WebRTC montado |
| `[Iniciar]` do host | libera o primeiro offer — o criador é sempre o ofertante ([§8.2](../../guide/webrtc-p2p.md)) |
| "aguardando bob" | o estado em que a pessoa hoje fica sem saber por quê |

O `p2p_setup_dialog` (`chat_live.html.heex:1179`) é a metade de dispositivos
dessa tela e migra inteiro, igual ao pré-join da onda 2.

### 4B.3 O que fica no `ChatLive`

O **convite**, inteiro. Ele é uma PM de verdade, persistida, com card no
histórico (`message_row.ex:121`), e criar a sessão **é** convidar
([§8.1](../../guide/webrtc-p2p.md)). Isso é conversa, e conversa é o chat.

Ficam também: `@p2p_pm_sessions`, o `p2p_peer_entry` da barra de abas, o badge
da conversa, e `LobbyInvite`.

O convite ganha, ao lado do card, o link `/join/:slug` da onda 1 — porque um
convite P2P por rede social é o caso que a D1 mais limita (o par precisa estar
registrado, identificado e online, `commands/handlers/lobby.ex:21-26`). Vale
mandar o link mesmo assim: quem clica e não pode entrar recebe um card que
explica, e isso é melhor do que um link que não existe.

### 4B.4 TDD da fase 4B

| Camada | Asserção |
|---|---|
| `:liveview` root | sessão inexistente/terminal → card de encerrada |
| `:liveview` root | não identificado → mensagem da política |
| `:liveview` root | não é participante da sessão → recusa |
| `:liveview` root | a antessala (sala de partida) é o primeiro render |
| `:liveview` root | `[Iniciar]` fica desabilitado enquanto os dois não estiverem `[Pronto]` |
| `:liveview` root | `[Iniciar]` só aparece para o host |
| `:liveview` root | host sai antes de iniciar → a sala fecha e o link morre (P7) |
| `:liveview` root | **nenhum offer é emitido antes do `[Iniciar]`** — a regra do moduledoc, agora testável pela UI |
| `:liveview` root | `terminate/2` inesperado **não** encerra a sessão (mesma regra da onda 2 §2.4) |
| `:liveview` nested | mesma bateria dentro da janela `p2p-call`; fechar a janela não desmonta o hook |
| `:liveview` chat | o convite continua chegando como PM e o card continua renderizando |
| Playwright | `p2p-surface.spec.ts` — mídia bidirecional real, arquivo no meio da chamada, jogo no meio da chamada. Os três cenários que a onda de integração original considerou pré-requisito para desligar o `/lobby` (commit `de1fe324`) |
| Playwright | fechar a aba do P2P não encerra a sessão do outro lado |

---

## 5. Obrigações do repositório

- [ ] `PerfBudgets` para `:p2p`.
- [ ] `SURFACE.txt`: ~25 eventos `lobby_*` saem de "liveview-events" e entram em
      "channel-events". O snapshot vai acusar, e deve.
- [ ] Help topics: o tópico "P2P Lobby" já existe e já foi reescrito uma vez para
      a realidade in-chat (commit `de1fe324`) — dezenas de páginas de jogo linkam
      pra ele. Reescrever de novo, não deletar.
- [ ] `docs/guide/webrtc-p2p.md`: a política de nomes ("There is NO standalone
      lobby page") **muda com esta onda**. Atualizar o parágrafo no mesmo commit
      que cria a rota, senão o guia passa a mentir.
- [ ] `docs/reference/call-handshake-resilience-map.md` (677 linhas) descreve o
      handshake atual — revisar inteiro, é o documento mais afetado.
- [ ] i18n dos domínios tocados.

## 6. Riscos

* **É a onda que pode quebrar chamada em produção.** Mitigação é a divisão em
  4A/4B e o critério "specs de P2P verdes sem edição" na 4A.
* **Firefox.** A suíte é Chromium apenas. Trocar o transporte de sinalização é
  exatamente a classe de mudança que quebra só o Firefox e passa no `make ci`.
  Rodar um spec descartável em Firefox antes de fechar 4A, com
  `pc.getStats()` — par de candidatos parado em `nominated: false` é o sinal.
* **A ordem "ambos ready antes do primeiro offer"** é fácil de perder ao trocar
  de transporte, porque o channel conecta em outro momento que o LiveView.
  Teste dedicado, não confiança.
* **Duas abas na mesma sessão P2P.** Diferente do SFU, não existe `rejoin` por
  `previous_participant_id` aqui. Decidir e testar: a segunda aba assume, ou é
  recusada? *Recomendação: assume*, com a primeira recebendo um aviso — é o
  mesmo contrato do takeover de chat, e é o menos surpreendente.

## 7. Pronto quando

- 4A: `make ci` verde **e** os specs de P2P verdes sem edição.
- 4B: bateria root e nested igual, mídia bidirecional real, arquivo e jogo no
  meio da chamada.
- `guide/webrtc-p2p.md` e `call-handshake-resilience-map.md` atualizados.
