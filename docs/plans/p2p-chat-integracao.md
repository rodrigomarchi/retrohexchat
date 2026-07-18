# PM = P2P — integração do Lobby ao chat principal

> Historico/superseded: este plano descreve a primeira integracao P2P ao chat,
> antes da unificacao mobile-first de P2P e conferencia. Nao use nomes de
> janelas legadas deste arquivo como fonte atual. Fonte operacional atual:
> `docs/reference/media-session-p2p-conference-current.md`.

> Fase seguinte à integração do Virtual Space aos canais (`canal-espaco-integracao.md`).
> Este documento mapeia o que existe hoje, o modelo alvo, a migração e os riscos —
> para revisão conjunta antes de qualquer código.

## 1. Visão

O lobby P2P deixa de ser uma página própria (`/lobby/:token`, aba separada do
navegador) e passa a viver **dentro do desktop do chat**, ancorado à mensagem
privada. O P2P é 1:1 entre usuários — a superfície natural dele é o PM, assim
como a superfície natural do space é o canal. As janelas do lobby (Call, Files,
Games, Statistics) viram `desktop_window`s do desktop do chat, ao lado dos 18
diálogos já migrados; a conversa da sessão É o próprio PM.

```
┌─ Desktop do chat ──────────────────────────────────┐
│ ┌─ RetroHex Chat (janela principal, pinned) ─────┐ │
│ │ [#geral] [@fulano ●]   ← PM tab                │ │
│ │  você: bora um pong?                           │ │
│ │  * Sessão P2P iniciada                         │ │
│ │  * fulano ativou a câmera                      │ │
│ │  * hex_pong: você venceu 5–3                   │ │
│ └────────────────────────────────────────────────┘ │
│    ┌─ Call: fulano ───┐   ┌─ Files ─────────┐      │
│    │ [vídeo remoto]   │   │ relatorio.pdf   │      │
│    │  🎤  📷  ⏹      │   │ ▓▓▓▓▓░░ 42%     │      │
│    └──────────────────┘   └─────────────────┘      │
│ [Start][chat][Call: fulano][Files]      tray 🕐    │
└────────────────────────────────────────────────────┘
```

## 2. Decisões já tomadas (Rodrigo, 2026-07-08)

| # | Decisão |
|---|---------|
| D1 | **Forma**: as features P2P viram `desktop_window`s do desktop do chat (Call, Files, Games, Statistics), ancoradas à sessão ativa — NÃO o toggle de viewport do space, NÃO painéis dentro da janela do PM |
| D2 | **PM absorve o chat do lobby**: a `ChatIsland` do lobby é aposentada; mensagens durante a sessão são o PM normal (persistido); avisos de feature (chamada, arquivo, resultado de jogo) viram mensagens de sistema no buffer do PM |
| D3 | **`/lobby/:token` é removida após paridade** — igual ao que fizemos com `/p2p` e `/game` legados; o chat vira a única superfície P2P |
| D4 | **Uma sessão P2P por vez** no chat (com um peer). Iniciar outra exige encerrar a atual. Multi-sessão (uma por PM) fica explicitamente fora do escopo |
| D5 | **Recusa explícita**: o card do PM tem [Aceitar] [Recusar]; recusar encerra a sessão pendente na hora e o iniciador vê "fulano recusou" como mensagem de sistema no PM (novo `decline_session` no domínio) |
| D6 | **Convite para quem já está em sessão**: o convite é entregue normalmente (não vaza status "ocupado"); Aceitar com sessão ativa abre confirm modal "encerrar a atual e entrar nesta?" |
| D7 | **Fechar a tab do PM não encerra a sessão**: só fecha o buffer; chamada/jogo/transferência continuam e as janelas ficam. Nova mensagem/aviso reabre a tab |
| D8 | **Indicador de sessão na status bar do chat**: área permanente mostrando a sessão P2P (peer + estado + facetas ativas); **clicar foca (traz à frente) as janelas P2P** — se nenhuma estiver aberta, abre a mais relevante (Call se em chamada, senão Statistics). A área também **cancela/encerra**: pendente → [✕] cancela o convite; conectada → [⏹] encerra com confirm. Conteúdo por estado em §4.7 |

Decisões herdadas que continuam valendo:

- Do lobby windowed (2026-06-26): fechar (X) uma janela de feature **esconde**
  (a feature continua viva); teardown real só por botão dedicado ("Encerrar
  chamada", "Encerrar sessão"). Chrome de janela 100% client-side
  (`WindowManagerHook` + localStorage).
- Do chat desktop (2026-07-02): canais/PMs continuam **tabs** dentro da janela
  principal (sem botão de taskbar por PM); as janelas P2P, por serem janelas,
  ganham botão de taskbar normalmente. Persistência via `persist_key="chat"`.
- Do universal lobby: as **3 constraints WebRTC** (§4.6) são invioláveis.

## 3. O que temos hoje

### 3.1 Fluxo do usuário hoje

1. Usuário roda `/p2p <nick>` (ou menu de contexto na nicklist). Requisitos:
   ambos registrados, alvo online (`Presence.Tracker.online?/2`), sem sessão
   ativa entre o par, sem bloqueio (`ignore_list_entries`).
2. `Commands.Handlers.Lobby` → `Lobby.create_session/2`: linha em
   `lobby_sessions` (`status: "pending"`, token aleatório), `SessionServer`
   iniciado, `notify_peer/3`.
3. O convite chega por **dois canais**: um PM tipo `"p2p_invite"` com card
   rico "Join lobby" (`lobby_invite.ex`, `session_card.ex`,
   `p2p_invite_card.ex` — link `target="_blank"`) e um aviso de status via
   PubSub `"user:#{nick}"` (`pubsub_handlers.ex`).
4. **Ambos abrem `/lobby/<token>` numa nova aba do navegador.** O LobbyLive
   monta, verifica participante, entra na sessão, e a partir daí tudo acontece
   naquela página: chat efêmero, chamada, arquivos, jogos, estatísticas.
5. Fechar a aba = `terminate/2` = `Lobby.leave/2` = sessão encerrada para os
   dois. Voltar ao chat é literalmente trocar de aba do navegador.

**Dores de UX desse fluxo:** contexto partido em duas abas (o PM e o lobby não
se veem); o chat efêmero do lobby duplica o PM e morre com a sessão; o convite
navega para fora do chat; nenhuma presença/status da sessão visível no chat.

### 3.2 LobbyLive — desktop, janelas, ilhas

- `live/app/lobby_live.ex` (~787 linhas) + `lobby_live.html.heex`; master
  component `components/ui/lobby/universal_lobby.ex` (desktop win98 próprio,
  `persist_key="lobby"`, menu bar + status bar + taskbar + start menu +
  shortcuts próprios).
- Janelas: `conn` (Statistics, **pinned**), `chat` (aberta por default),
  `call` e `file` (sempre montadas, `open={false}` — precisam de hook vivo),
  `game` (**server-managed**, monta/desmonta via `@open_windows`), mais
  `about-dialog`, aviso de inatividade e overlay de boot.
- 4 ilhas LiveComponent (`live/app/lobby_live/components/`): `ChatIsland`
  (mensagens efêmeras + Composer compartilhado + sink de mensagens de
  sistema), `MediaIsland` (chamada), `FileIsland` (transferência),
  `GameIsland` (catálogo/proposta/canvas/resultado).
- Host = agregador puro: adapters de eventos de hook (inbound) → `send_update`
  para as ilhas; ilhas espelham `{:feature_summary, ...}` para taskbar/strip
  (contratos C1/C2/C3 da decomposição em ilhas).

### 3.3 Hooks JS / WebRTC

| Hook | Papel |
|---|---|
| `LobbyWebRTCHook` (`#lobby-webrtc`, `phx-update="ignore"`) | UM `RTCPeerConnection` persistente; multiplexa mídia (transceivers) + data channels `"filetransfer"` e `"gamedata"`; **single-offerer** (só o iniciador emite offer; o answerer pede `lobby_renegotiate`); stats a cada 2,5s |
| `LobbyMediaHook` | wrapper do `rtc_media_hook_factory.js` (modo self-controlled, autoJoin) |
| `LobbyGameCanvasHook` | importa lazy o engine do jogo (28 jogos, 37 entradas de catálogo) sobre o canal `gamedata` |
| `FileTransferHook` (compartilhado) | eventos `ft_*`; **precisa ficar montado a conexão inteira** |
| `WindowManagerHook` / `MenuBarHook` | chrome de janela / menus (genéricos, já usados pelo chat) |

**Fato-chave de wiring:** todo `pushEvent` de hook vai para o **LiveView
raiz**, nunca para componente. Hoje o raiz é o LobbyLive; no alvo passa a ser
o ChatLive.

### 3.4 Domínio `RetroHexChat.Lobby`

- Máquina de estados: `pending → lobby → connected → (closed | expired |
  failed)`. Timeouts: pending 5 min; inatividade aviso 10 min / expira 15 min
  (resetada por mensagem de chat); `connecting_timeout` 30s.
- Sinalização **coordenada por prontidão**: o `SessionServer` só emite
  `lobby_start_signaling` quando AMBOS os hooks reportaram `webrtc_ready`.
- PubSub: tópico único `"lobby:#{token}"` (status/sinal/mídia/jogo/arquivo/
  chat) + `"user:#{nick}"` para convites e fim de sessão.
- ICE/TURN/rate-limit reutilizam `RetroHexChat.P2P` (contexto legado ainda
  supervisionado, sem rota — é infraestrutura compartilhada, **não deletar**).
- Sem suporte a guest (policy exige ambos registrados) — não muda.

### 3.5 ChatLive — desktop e PMs

- `live/app/chat_live.ex` (~891 linhas) + template (~926 linhas); ~40 módulos
  de handler anexados via `attach_hook` (`chat_live/*.ex`); ~18 janelas de
  diálogo declaradas no template; helper `Windows` (`open/2`, `open_with/4`,
  `@managed`) + `@open_windows` MapSet — **mesmo padrão do lobby**.
- **PMs são tabs/buffers, não janelas**: `session.pm_conversations` +
  `session.active_pm`; o PM ativo renderiza no mesmo `MessageViewport` da
  janela principal. PubSub `"pm:#{sorted_ids}"`; envio via
  `Chat.Service.send_private_message/3` (persistido); unread em
  `@unread_counts`; typing indicator próprio.
- O card de convite P2P **já existe no PM** (`session_card.ex` resolve
  `/lobby/<token>` e enriquece via `Lobby.session_summary/1`).

### 3.6 O precedente do space — o que se aplica e o que não

| Aplica-se | Não se aplica |
|---|---|
| Entrega side-by-side (integrar antes de remover o legado) | O space integrado é **painel alternável por canal**, não janela — o P2P vai de janelas (D1) |
| Convite/card e helpers de invite como ponte | O runtime do space passa por **canal Phoenix próprio** (`space:<token>`), fora do LiveView; o lobby é todo LiveView-cêntrico (PubSub + hooks no raiz) |
| "Modo canal" no domínio (análogo: "modo chat" na sessão de lobby) | O space não tinha ilhas nem WebRTC; a complexidade de estado do lobby é muito maior |

O template estrutural mais fiel para esta migração não é o space — é a
**própria migração chat-desktop** (diálogos → janelas) somada à decomposição
em ilhas do lobby, que já deixou cada feature isolada numa ilha + janela.

## 4. Modelo alvo

### 4.1 Fluxo do usuário (novo)

1. `/p2p <nick>` (comando ou menu de contexto) — validações inalteradas.
2. Para o **iniciador**: o PM com o alvo abre/foca (já acontece hoje) e o chat
   entra em estado "sessão pendente" (mensagem de sistema no PM: "Convite P2P
   enviado — aguardando fulano…").
3. Para o **convidado**: o card `p2p_invite` chega no PM como hoje, mas com
   **[Aceitar] [Recusar]** (D5). Aceitar entra na sessão ali mesmo (o ChatLive
   dele faz `join_session`, monta os hooks); se ele já estiver em outra sessão,
   confirm modal para encerrar a atual antes (D6). Recusar encerra a pendente
   e avisa o iniciador.
4. Conectado: janelas **Call / Files / Games / Statistics** disponíveis via
   start menu / menu bar / badges; abrem sob demanda (auto-abrem nos mesmos
   gatilhos de hoje: peer ligou mídia → flash/open Call; `ft_offer_received` →
   open Files; proposta de jogo → open Games). A **status bar** mostra a
   sessão ativa o tempo todo; clicar nela foca as janelas P2P (D8).
5. A conversa durante a sessão é o PM (persistido). Eventos de feature viram
   mensagens de sistema no buffer do PM (D2).
6. Encerrar: botão "Encerrar sessão" (menu/janela) ou sair do chat. Trocar de
   tab (canal/outro PM) **não** encerra nada — as janelas continuam abertas e
   flutuando, esse é o ganho do modelo de janelas.

### 4.2 Janelas no desktop do chat

| Janela (id proposto) | Origem | Lifecycle no chat |
|---|---|---|
| `p2p-call` | MediaIsland + `media_panel` | sempre montada enquanto há sessão (`open={false}`), X esconde |
| `p2p-files` | FileIsland + `file_panel` | idem — hook precisa viver a conexão inteira |
| `p2p-games` | GameIsland + `game_panel` | server-managed (como hoje), monta ao abrir |
| `p2p-stats` | painel `conn` / `lobby_network_panel` | managed comum (deixa de ser pinned — no chat a única pinned é a janela principal) |

- Ids prefixados `p2p-*` para não colidir com janelas existentes (o lobby usa
  `chat`, que colide com a janela principal do chat — a ilha de chat morre
  mesmo (D2), e `conn`/`call`/`file`/`game` são renomeadas).
- Elemento persistente `#lobby-webrtc` (hook raiz do WebRTC) passa a viver no
  template do ChatLive, `:if={@p2p_session}`, `phx-update="ignore"`, com o
  gate `ever_connected`/sticky-mount de hoje para blips de status.
- Taskbar: as janelas P2P ganham `taskbar_button` com os badges atuais
  (duração da chamada, % de arquivo, dot de jogo ativo) vindos dos
  `feature_summary` — o read-model C2 é portado como está.
- Menu: menu **"P2P"** na menu bar do chat, habilitado quando há sessão:
  Start audio/video, Send a file, Play a game, Statistics, Privacy (TURN),
  End session. *Verificado*: `menu_bar_app.ex` é HEEx literal (novo bloco
  `<.menu label="P2P" disabled={...}>`) e o start menu é componente separado
  (`start_menu_app.ex`) — o espelhamento (decisão 4 do chat-desktop) é
  wiring manual nos dois lugares, não automático.
- **Status bar (D8)**: a status bar do chat (slot `:header` do desktop) ganha
  uma área de sessão P2P, visível enquanto `@p2p_session` existe — peer +
  estado (pendente/conectando/conectado) + duração de chamada quando houver,
  alimentada pelo mesmo read-model dos badges. **Clicável**: dispara
  `window_command focus` para cada janela `p2p-*` aberta (traz à frente na
  z-order); se nenhuma estiver aberta, abre a mais relevante (Call se em
  chamada, senão Statistics). É o "onde está minha sessão?" de um clique,
  útil quando as janelas ficaram atrás da janela principal maximizada.
  *Implementação (verificado)*: `status_bar_app.ex` é de zonas fixas, sem
  slots — a área P2P entra como **zona nova no próprio componente** (o
  correto pelo component-first), seguindo o precedente da zona 3 (badge de
  notify, que já é `<button phx-click>`), com assigns roscados via
  `chat_app_header`/`ChatShell`. A zona P2P NÃO ganha `hidden md:flex`
  (diferente de buddy/lag/clock) — sessão ativa precisa ser visível também
  no mobile.

### 4.3 PM absorve o chat do lobby (D2)

- `ChatIsland`, `chat_dispatch.ex` e a janela `chat` do lobby são aposentados.
- Mensagem durante a sessão = `send_private_message/3` normal. O rate limit,
  histórico e paginação do PM já existem — o chat efêmero (cap de 100
  mensagens, morre com a sessão) simplesmente deixa de existir.
- Mensagens de sistema de feature ("fulano ativou a câmera", "arquivo X
  recebido", "hex_pong: você venceu 5–3") entram no buffer do PM. O contrato
  C1 (ilhas → sink de sistema) muda de alvo: em vez de `send_update` para a
  ChatIsland, o host injeta no viewport do PM. **Aberto (§7): persistir ou
  não** — recomendação: persistir como novo tipo de mensagem (`p2p_system`),
  renderização muted; dá histórico ("ganhei de 5–3 ontem") de graça.
- O `SessionServer` para de re-transmitir chat (`send_lobby_message` some);
  as mensagens de PM continuam resetando o timer de inatividade da sessão —
  ver §7 sobre a base do timer.
- **Tipo `p2p_system` é só um valor novo** (verificado): `PrivateMessage.type`
  é string com `validate_inclusion` em `~w(message action system p2p_invite)`
  — sem migração; precedente direto: o autorespond já persiste PMs tipo
  `"system"` renderizadas `* {content}` no `MessageRow`.
- **Regra do escritor único**: `p2p_system` é persistida via
  `send_private_message` (que já entrega aos dois lados) por UM lado por
  classe de evento — resultado de jogo → host da partida; encerramento → quem
  encerrou; recusa → quem recusou; arquivo concluído → quem recebeu. Sem essa
  regra, os dois hosts persistiriam o mesmo aviso em duplicata.
- **Transferência de arquivo não tem eventos de domínio** (verificado): roda
  pura no data channel, o servidor nunca vê. Os avisos de arquivo nascem dos
  `ft_*` que o hook entrega ao host — logo o escritor é sempre o lado que
  recebe o evento autoritativo (ex.: receptor no `ft_complete`).

### 4.4 Arquitetura no ChatLive

- **Host adapters**: os handlers hoje no LobbyLive (inbound de hooks:
  `lobby_signal`, `lobby_media_*`, `ft_*`, `lobby_game_*`, `lobby_webrtc_*`,
  stats) viram um módulo de hook anexado — `chat_live/p2p_events.ex` (+
  handlers de PubSub em `pubsub_handlers/`), no mesmo pipeline dos ~40
  existentes. **ChatLive não incha**: a lógica fica no módulo anexado + ilhas,
  o padrão exato da casa.
- **Ilhas portadas, não reescritas**: MediaIsland / FileIsland / GameIsland
  mudam de pasta (`chat_live/components/`) e de host, mas o contrato
  (send_update in, feature_summary/window_command out) é o mesmo. O
  window-self-drive (C3) já funciona de dentro de LiveComponent.
- **Estado no host**: um assign `@p2p_session` (token, peer, status, summaries)
  substitui os assigns soltos do LobbyLive; `nil` = sem sessão. A subscrição
  `"lobby:#{token}"` é feita no aceite/criação e cancelada no encerramento.
- **Domínio quase intocado**: a máquina de estados, o SessionServer, policy e
  queries continuam valendo. Novidades pequenas: (a) entrar na sessão sem
  navegação (o ChatLive chama `join_session` direto); (b) eventos de chat
  saem do escopo do server; (c) opcional: emitir os avisos de sistema como
  eventos que o host traduz em mensagens de PM.
- **JS**: hooks inalterados na essência — continuam empurrando para o raiz,
  que agora é o ChatLive. `LobbyCloseWindowHook` (fecha a aba do navegador)
  morre. *Verificado*: o registro lazy é **global** (hook map único do
  LiveSocket, mount por `phx-hook` em qualquer LV) — funciona no ChatLive sem
  mudança. Nuance: não há replay de eventos push anteriores ao import do
  módulo — irrelevante aqui porque o gate `webrtc_ready` (constraint §4.6.1)
  já garante que o servidor só sinaliza depois do hook pronto; manter o mesmo
  padrão readiness para qualquer evento novo.

### 4.5 Ciclo de vida da sessão dentro do chat

| Evento | Hoje (página própria) | Alvo (no chat) |
|---|---|---|
| Aceitar convite | abrir `/lobby/<token>` em nova aba | clicar "Aceitar" no card do PM |
| Recusar convite | não existe (ignora e expira em 5 min) | "Recusar" no card → sessão encerra, iniciador é avisado no PM |
| Trocar de contexto | trocar de aba do navegador (lobby não vê o chat) | trocar de tab de canal/PM; janelas P2P continuam na tela |
| Fechar janela de feature | esconde, feature viva | idem (decisão herdada) |
| Encerrar sessão | "Sair do lobby" ou fechar a aba | "End session" (menu/janela) |
| Fechar o chat / disconnect | `terminate` → `Lobby.leave` | idem: `terminate` do ChatLive faz leave **se** há sessão |
| Fim terminal (peer saiu, expirou) | página vira `LobbyTerminal` | mensagem de sistema no PM + janelas P2P fecham; nada de tela terminal |

### 4.6 Constraints invioláveis (custaram caro; não regredir)

1. **Sinalização gated por `webrtc_ready` dos DOIS lados** — sem isso a
   primeira offer é dropada e a conexão trava em "Connecting…".
2. **Single-offerer** (só o iniciador emite offers; answerer pede
   `lobby_renegotiate`) — perfect negotiation causou vídeo unidirecional.
3. **`FileTransferHook` montado a conexão inteira** — o data channel não tem
   `onmessage` sem o hook; janela Files é `open={false}` + esconder, nunca
   managed.
4. (Nova, do chat) **Geometria de janela nunca muda sob o ponteiro** — não
   recomputar geometria em pointerdown ao abrir/flash de janelas P2P.

### 4.7 Sessão única: máquina de estados, troca A→B e edge cases

Com "uma sessão por vez" (D4), a sessão P2P vira um **estado global do chat**
— e precisa ser tratada como tal: uma única máquina de estados no host, da
qual TODA a UI deriva (status bar, menu P2P, janelas, badges, cards).

**Máquina de estados do host** (`@p2p_session.state`):

```
none ──/p2p──▶ invite_sent ──aceite do peer──▶ joining ─▶ connecting ─▶ connected
  ▲                │                              │            │            │
  └──cancelou/─────┘                              └────────────┴──ending──◀─┘
     recusado/expirado                                (leave, troca, terminal)
```

Regras: exatamente um estado ≠ `none` por vez. Convites **recebidos** não
entram na máquina — são cards nos PMs (pode haver N pendentes, de N pessoas
diferentes); só o aceite transiciona. O aceite do convidado pula direto para
`joining`.

**Visibilidade e controle globais (D8 detalhada).** A área da status bar vive
no slot `:header` do desktop — fora da janela do chat — logo permanece visível
em **qualquer** contexto: tab de canal, outro PM, status tab, space aberto,
qualquer janela em foco. Conteúdo por estado:

| Estado | Status bar |
|---|---|
| `invite_sent` | `P2P: aguardando fulano… [✕]` — ✕ cancela o convite pendente |
| `joining`/`connecting` | `P2P: conectando com fulano…` |
| `connected` | `P2P: fulano · 12:34 📞⇅🎮 [⏹]` — ícones das facetas ativas; clique foca as janelas; ⏹ encerra com confirm |

Reforço secundário: a **tab do PM** do peer ganha um glifo de sessão (●)
enquanto conectado — identifica a conversa "dona" da sessão na fileira de tabs.

**Protocolo de troca de sessão (E1/E2).** Vale para os dois sentidos — aceitar
convite de B com sessão A ativa, ou rodar `/p2p B` com A ativa. O confirm é
**informado**: enumera o que será perdido ("Você está em chamada e
transferindo `relatorio.pdf` (42%) com fulano. Encerrar e iniciar sessão com
beltrano?"). Sequência dirigida pelo host:

1. **Validar B antes de encerrar A** — `session_summary` confirma que o
   convite de B ainda é joinable (não expirou/cancelou). Isso reduz a janela
   de "perdi A e não ganhei B" para milissegundos.
2. **Encerrar A** (`ending`): fecha o PC, desmonta ilhas e janelas `p2p-*`,
   aguarda o cleanup do hook (o elemento `#lobby-webrtc` e os DOM ids são
   singleton — nada de B monta antes de A liberar).
3. **Entrar em B** (`joining`): nova subscrição `"lobby:#{token_B}"`, remount
   do hook, gate `webrtc_ready` normal.
4. Se (3) falhar mesmo assim (B morreu na janela da troca): mensagem de
   sistema no PM, estado `none`. O usuário foi avisado do risco no confirm.

As janelas **não migram** entre sessões: morrem com A e renascem nos gatilhos
de B (título com o novo peer). Menos estado para limpar, zero vazamento de UI
de uma sessão na outra.

**Matriz de edge cases** (comportamento decidido nesta fase):

| # | Cenário | Comportamento |
|---|---|---|
| E1 | Aceitar convite com sessão ativa | confirm informado → protocolo de troca acima |
| E2 | `/p2p` com sessão ativa | mesmo confirm → encerra atual → cria + entra na nova |
| E3 | Aceitar card de sessão expirada/cancelada | botões desabilitados; se race, o join falha → "convite expirou" no PM |
| E4 | Iniciador cancela convite pendente | [✕] na status bar; peer vê o card virar "cancelado" + mensagem de sistema |
| E5 | N convites pendentes de N pessoas | independentes; aceitar um NÃO recusa os outros (expiram sozinhos em 5 min) |
| E6 | Peer encerra/cai no meio de jogo/transferência | mensagem de sistema com motivo no PM; janelas `p2p-*` fecham; parcial de arquivo descartado |
| E7 | Convite do MESMO peer com sessão ativa entre o par | já bloqueado pela policy (inalterado) |
| E8 | Blip de rede / reconexão do LiveView durante sessão | **DEFEITO CONFIRMADO no código atual**: `leave` é terminal em QUALQUER estado (`do_close` → `"closed"` para os dois peers, sem branch por estado, sem grace, sem rastrear quem saiu) — um refresh de `/lobby/:token` já mata a sessão HOJE. F1 redesenha: saída por usuário + monitors de processo + grace de rejoin antes do terminal (corrige o standalone de brinde) |
| E9 | Card antigo num PM reaberto depois | `SessionCard.enrich` já resolve estado terminal → card inerte |
| E10 | Auto-open/flash de janela enquanto o usuário digita | **já satisfeito** (verificado): o `WindowManagerHook` nunca chama `.focus()`/`.blur()` — open/focus/flash só mudam z-order/visibilidade/CSS. Guarda: manter assim |

**Card vivo (F4).** O card `p2p_invite` reage a mudanças de estado (aceito,
recusado, cancelado, expirado): o host re-enriquece e atualiza a row no stream
do PM ao receber os eventos da sessão — o card nunca fica prometendo um
Aceitar que vai falhar. *Verificado — o mecanismo já existe*: edits/deletes de
mensagem já fazem `stream_insert` com o mesmo `dom_id` para atualizar rows
históricas in place, e o `SessionCard` já rende inerte para sessão terminal
(`cta(%{terminal?: true}) → nil`); o `enrich` roda uma vez no build, então o
"vivo" é só re-enriquecer + re-inserir no evento. **Gap encontrado**: o
fallback `p2p_invite_card` (quando a row da sessão foi expurgada do banco)
renderiza um link "Join lobby" sempre ativo — corrigir em F4 (card inerte
"sessão indisponível" quando não resolve).

**Convivência das facetas.** Nada muda no modelo de concorrência: chamada,
jogo e transferência continuam rodando **ao mesmo tempo** sobre a mesma
conexão (é o ponto do lobby). A UX de convivência é o próprio WM: cada faceta
na sua janela, badges na taskbar, ícones das facetas ativas na status bar. Os
guardas novos são só E10 (foco de teclado) e a regra herdada "X esconde,
feature viva".

## 5. Migração (fases; side-by-side como no space)

Cada fase fecha com validação alvo nos arquivos tocados; `make ci` completo no
fim de cada bloco funcional. `/lobby/:token` continua funcionando até a F6.

- **F0 — Este documento.** Revisão conjunta; decisões travadas.
- **F1 — Domínio.** O bloco maior, com escopo já verificado no código:
  - **Redesenho do `leave` (E8, defeito confirmado)**: saída por usuário em
    vez de terminal imediato; `SessionServer` passa a monitorar os processos
    que deram join (hoje não há monitor nem rastreio de quem saiu) e aplica
    grace de rejoin antes do terminal. Corrige o refresh-mata-sessão do
    standalone de brinde. Os monitors também dão a **detecção de segunda
    aba** (§7 item 3) — hoje `join_session` é idempotente e cego a processos.
  - **`decline_session` (D5) e cancelamento de pendente (E4)**: wrappers
    finos sobre `close_session/3` (já autoriza qualquer participante em
    estado não-terminal) com vocabulário novo de `closed_reason`
    (`"declined"`, `"invite_cancelled"`) — o status continua `"closed"`;
    cards e mensagens de sistema mapeiam pela reason.
  - **Query nova `active_session_for_user/1`** (não existe — as queries
    atuais exigem os DOIS ids): `(creator_id == uid or peer_id == uid) and
    status not in terminal` — base da re-hidratação no reconnect.
  - Base do timer de inatividade redefinida (§7); tipo `p2p_system` no
    changeset de `PrivateMessage`; chat efêmero deprecado no server (mantido
    enquanto `/lobby` existir). Testes de unidade.
- **F2 — Espinha no ChatLive.** A **máquina de estados `@p2p_session` (§4.7)**
  completa, incluindo o protocolo de troca A→B; subscrição, elemento
  `#lobby-webrtc`, módulo `chat_live/p2p_events.ex` com os adapters de
  sinalização; aceite/recusa via card do PM (confirm informado E1/E2); guarda
  multi-aba; **status bar por estado (D8)** com cancelar pendente e encerrar.
  Sem features ainda — só conectar, trocar e ver status. E2E mínimo: dois
  ChatLive conectam; troca A→B.
- **F3 — Janelas, uma por vez** (menor acoplamento primeiro, como na
  decomposição): `p2p-stats` → `p2p-files` → `p2p-call` → `p2p-games`.
  Cada uma: portar ilha + janela + badges + entradas de menu.
- **F4 — Absorção do PM.** Mensagens de sistema no buffer do PM; aposentar
  ChatIsland/janela chat do lado integrado; convite/estado pendente no PM;
  **card vivo** (reage a aceito/recusado/cancelado/expirado, §4.7); glifo de
  sessão na tab do PM.
- **F5 — Paridade + E2E.** Auditar contra o inventário (§3) e reescrever
  `chat-lobby.spec.ts` (16–20 testes) para o fluxo in-chat — incluindo os
  testes de RTP real bidirecional. Help topics (F1 obrigatório do repo):
  atualizar "P2P Lobby"/Video Call/File Transfer/Games + cheatsheet.
- **F6 — Remoção.** Deletar LobbyLive/universal_lobby/painéis/menu/status bar
  do lobby, `LobbyCloseWindowHook`, rota (redirect `/lobby/:token` → `/chat`
  abrindo o PM/sessão), showcase, e2e legado. **Manter**: domínio `Lobby`,
  `RetroHexChat.P2P` (infra), `Games.Catalog`, engines JS, hooks portados.

## 6. Riscos

| Risco | Grau | Mitigação |
|---|---|---|
| **Reconexão do LiveView**: `leave` atual é terminal imediato (defeito E8 confirmado) e não existe query de sessão ativa por usuário | Alto | F1: redesenho do leave (monitors + grace) + `active_session_for_user/1`; mount do ChatLive re-hidrata `@p2p_session` |
| **Troca A→B**: teardown/setup do PC singleton com race de expiração do convite B | Médio | Protocolo sequenciado do §4.7 (validar B → encerrar A → entrar em B), janelas renascem em vez de migrar; E2E dedicado de troca em F2 |
| **Duas abas do /chat abertas**: ambas tentariam montar o PC | Alto | **Verificado: o domínio hoje NÃO detecta segundo join** (idempotente, sem monitor) — a detecção vem dos monitors do redesenho do leave (F1); a segunda aba mostra "sessão ativa em outra aba" (F2) |
| **ChatLive já é grande** (~40 hooks, 891 linhas) e ganha WebRTC | Médio | Tudo em módulo anexado + ilhas; zero lógica nova no chat_live.ex além do assign e do template |
| **Colisão de ids/persistência**: ids de janela e localStorage do desktop | Médio | Prefixo `p2p-*`; janelas novas entram no `persist_key="chat"`; chave `rhc:desktop:lobby` fica órfã e é ignorada |
| **Regressão das constraints WebRTC** (§4.6) durante o re-wiring dos adapters | Alto | Portar handlers 1:1 antes de refatorar; E2E de RTP bidirecional roda em toda fase que toca sinalização/mídia |
| **Timer de inatividade** perde a fonte (chat efêmero morre) | Baixo | Redefinir atividade = mídia/jogo/arquivo ativos OU mensagem no PM do par (ver §7) |
| **Elementos de vídeo dentro de janela escondida**: streams precisam sobreviver a hide/show do WM | Médio | Já resolvido no lobby (X esconde via classe, hooks vivos) — portar o comportamento, não reimplementar |
| **E2E**: suíte inteira do lobby assume página própria | Médio | Reescrita planejada em F5; até lá a suíte antiga segue válida contra `/lobby` |
| **Divergência durante o side-by-side** (duas superfícies) | Baixo | Janela de coexistência curta; nada de feature nova no standalone durante a migração |

## 7. Decisões complementares (confirmadas 2026-07-08 — nada pendente)

As três grandes viraram D5/D6/D7 no §2. As menores, todas confirmadas na
recomendação proposta:

1. **Mensagens de sistema P2P são persistidas no PM** como novo tipo
   `p2p_system`, renderização muted — histórico de partidas/arquivos de graça
   (F4).
2. **Timer de inatividade**: qualquer feature ativa (mídia/jogo/transferência)
   OU mensagem no PM do par reseta; limites de aviso 10 min / expiração 15 min
   inalterados (F1).
3. **Multi-aba do /chat**: a segunda aba é bloqueada de montar a sessão —
   mostra "sessão ativa em outra aba" (F2).
4. **Janela Call não auto-abre no aceite** — abre nos gatilhos de mídia, como
   hoje (F3).
5. **Comando continua `/p2p`**; só textos de UI mudam de "lobby" para
   "sessão P2P".

## 8. Fora de escopo

- Multi-sessão (uma sessão P2P por PM) — D4.
- Guests em sessão P2P (policy continua exigindo ambos registrados).
- Screen share (não existe hoje; não entra agora).
- Convites tipados/auto-launch (`/call`-like) — segue como gap conhecido do
  lobby, pode virar fase própria depois da integração.
- Solo/arcade (`/solo`, `/arcade`) — intocados.
- Mobile: herda o modo stacked <720px do WM, como decidido no chat-desktop.

## 9. Apêndice — fatos verificados no código (2026-07-08)

Verificação feita para o plano ser autocontido; cada linha é fato lido do
código, não suposição:

| Afirmação do plano | Veredito |
|---|---|
| `terminate → leave` mata a sessão num refresh | **CONFIRMADO — defeito atual**: `leave` → `do_close("peer_left")` → `"closed"` para os dois, em qualquer estado, sem grace; o re-mount cai em `verify_not_terminal` → tela terminal |
| Domínio detecta join de segunda aba | **FALSO**: `join_session` é idempotente (dois booleans `creator_joined`/`peer_joined`), sem monitor/pid — monitors entram no redesenho F1 |
| Existe API de recusa/cancelamento | **NÃO, mas `close_session/3` cobre**: participante + estado não-terminal + reason string livre; terminais são só `closed/expired/failed`, distinguidos por `closed_reason` |
| Eventos de domínio cobrem os avisos de sistema | **PARCIAL**: join/media/status/close/jogo sim (payloads em `session_server.ex`); **arquivo NÃO tem evento de domínio** (data channel puro) — avisos `ft_*` nascem no host, lado receptor escreve |
| Existe query "sessão ativa do usuário" sem token | **FALSO**: todas as queries exigem token ou os dois ids — `active_session_for_user/1` é nova (F1) |
| Policy bloqueia criar sessão se o alvo está ocupado com terceiro | **FALSO (como o plano assume)**: check é só do par exato — D6/E1 são cenários reais; a regra "uma por vez" é do cliente |
| Status bar visível em qualquer contexto | **CONFIRMADO**: slot `:header` do desktop, fora do workspace — sobrevive a tab/space/janelas e ao stacked <720px (zonas buddy/lag/clock se escondem <768px; a zona P2P não deve) |
| `status_bar_app` aceita slot para a área P2P | **FALSO**: zonas fixas sem slot — área P2P = zona nova no componente (precedente: botão de notify da zona 3) |
| Card fica inerte para sessão terminal | **CONFIRMADO** no card rico (`cta(%{terminal?: true}) → nil`); **gap**: o fallback (sessão expurgada do banco) mostra "Join lobby" ativo — corrigir em F4 |
| Atualizar card histórico in place é viável | **CONFIRMADO**: edits/deletes já fazem `stream_insert` com mesmo `dom_id` |
| `p2p_system` exige migração | **FALSO**: `type` é string com `validate_inclusion` — só adicionar o valor (+ `pm_resolve_type` + branch no `MessageRow`) |
| WM rouba foco de teclado em open/flash | **FALSO**: nenhum `.focus()`/`.blur()` no hook — só z-order/CSS (E10 já satisfeito) |
| Hooks lazy funcionam com ChatLive como raiz | **CONFIRMADO**: hook map global do LiveSocket, mount por elemento; sem replay pré-import (gate `webrtc_ready` já cobre) |
| Menu bar/start menu são data-driven | **FALSO**: HEEx literal em dois componentes — menu "P2P" é wiring manual nos dois |
| Tabs de PM suportam indicador extra | **PARCIAL**: precedentes `type_icon` + `unread`, mas sem slot genérico — glifo de sessão = attr novo em `irc_tab_item` + campo em `build_tabs` |
