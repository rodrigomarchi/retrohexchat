# Sinalização via Phoenix

## PubSub Signaling, Hooks e Sequência de Mensagens

---

## I. Papel do Servidor no P2P

O servidor do RetroHexChat tem um papel limitado mas crucial no fluxo P2P:
**sinalização** (signaling). Ele não carrega mídia, não processa dados,
não vê conteúdo. Ele apenas:

1. Gerencia sessões P2P (criação, estado, expiração)
2. Encaminha mensagens de signaling entre peers (SDP, ICE candidates)
3. Fornece credenciais TURN de curta duração

Depois que a conexão WebRTC é estabelecida, o servidor pode até cair
sem afetar a sessão ativa.

## II. Phoenix PubSub para Signaling

O signaling usa Phoenix PubSub — a mesma infraestrutura que já alimenta
todo o chat em tempo real do RetroHexChat.

### Tópico PubSub

```
"p2p:#{session_token}"
```

Cada sessão P2P tem um tópico único baseado no token. Apenas os dois peers
(via suas LiveViews) estão inscritos nesse tópico.

### Mensagens no tópico

```elixir
# Tipos de mensagem no PubSub
"p2p:#{token}" =>
  {:p2p_signal, %{type: "offer", sdp: "..."}}
  {:p2p_signal, %{type: "answer", sdp: "..."}}
  {:p2p_signal, %{type: "ice-candidate", candidate: %{...}}}
  {:p2p_lobby_message, %{from: "rodrigo", text: "opa!"}}
  {:p2p_action_request, %{type: "file-transfer", from: "rodrigo", metadata: %{...}}}
  {:p2p_action_response, %{type: "file-transfer", accepted: true}}
  {:p2p_session_event, %{event: "peer_joined" | "peer_left" | "session_closed"}}
```

## III. Fluxo Completo de Signaling

### Fase 1: Criação e lobby

```
  Peer A (Browser)          Servidor (LiveView)         Peer B (Browser)
       │                          │                          │
       │── /p2p rodrigo maria ────▶                          │
       │                          │── cria sessão (DB+GenServer)
       │                          │                          │
       │                          │── broadcast user:maria ──▶
       │                          │   {:p2p_invite, token}    │
       │                          │                          │
       │◀── redirect /p2p/:token ─│                          │
       │                          │                          │
       │── mount P2PSessionLive ──▶                          │
       │── subscribe p2p:token ───▶                          │
       │                          │                          │
       │                          │   (maria aceita convite)  │
       │                          │                          │
       │                          │◀── mount P2PSessionLive ─│
       │                          │◀── subscribe p2p:token ──│
       │                          │                          │
       │◀── {:p2p_session_event,  │── {:p2p_session_event, ──▶
       │     peer_joined}         │   peer_joined}           │
```

### Fase 2: Aceite mútuo e handshake WebRTC

```
  Peer A (Browser)          Servidor (LiveView)         Peer B (Browser)
       │                          │                          │
       │── "quero enviar arquivo" ▶                          │
       │                          │── {:p2p_action_request} ─▶
       │                          │                          │
       │                          │◀── "aceito" ─────────────│
       │◀── {:p2p_action_response}│                          │
       │                          │                          │
       │  ┌────────────────────────────────────────────┐     │
       │  │ WebRTC Handshake (via PubSub signaling)    │     │
       │  └────────────────────────────────────────────┘     │
       │                          │                          │
       │── createOffer() ─────────│                          │
       │── push_event "signal" ───▶                          │
       │                          │── {:p2p_signal, offer} ──▶
       │                          │                          │
       │                          │◀── push_event "signal" ──│
       │◀── {:p2p_signal, answer} │── createAnswer() ────────│
       │                          │                          │
       │── push_event "ice" ──────▶                          │
       │                          │── {:p2p_signal, ice} ────▶
       │                          │                          │
       │                          │◀── push_event "ice" ─────│
       │◀── {:p2p_signal, ice} ───│                          │
       │                          │                          │
       │═══════════ WebRTC P2P estabelecido ═════════════════│
       │           (servidor sai do caminho)                 │
```

## IV. LiveView Hooks — Bridge JS ↔ Servidor

Seguindo o padrão "hook = wiring, lib = logic" do projeto, a lógica WebRTC
fica em módulos JS separados dos hooks.

### Estrutura de arquivos

```
assets/js/
├── hooks/
│   └── webrtc_hook.js         # Wiring: DOM events ↔ LiveView ↔ lib
├── lib/
│   ├── webrtc.js              # Lógica: PeerConnection, ICE, SDP
│   ├── file_transfer.js       # Lógica: DataChannel, chunking, progresso
│   └── media.js               # Lógica: getUserMedia, controles de mídia
```

### webrtc_hook.js (wiring)

```javascript
import { createPeerConnection, handleSignal } from "../lib/webrtc";
import { setupFileTransfer } from "../lib/file_transfer";
import { setupMedia } from "../lib/media";

const WebRTCHook = {
  mounted() {
    this.pc = null;

    // Receber sinais do servidor (via LiveView push_event)
    this.handleEvent("p2p_signal", (payload) => {
      handleSignal(this.pc, payload, (response) => {
        // Enviar resposta de volta ao servidor
        this.pushEvent("p2p_signal", response);
      });
    });

    // Iniciar handshake WebRTC (offerer)
    this.handleEvent("p2p_start_offer", async (config) => {
      this.pc = createPeerConnection(config.iceServers, {
        onIceCandidate: (candidate) => {
          this.pushEvent("p2p_signal", {
            type: "ice-candidate",
            candidate: candidate,
          });
        },
        onTrack: (event) => {
          // Atualizar vídeo remoto no DOM
          const remoteVideo = this.el.querySelector("#remote-video");
          if (remoteVideo) remoteVideo.srcObject = event.streams[0];
        },
        onDataChannel: (channel) => {
          setupFileTransfer(channel, this);
        },
      });

      const offer = await this.pc.createOffer();
      await this.pc.setLocalDescription(offer);
      this.pushEvent("p2p_signal", { type: "offer", sdp: offer.sdp });
    });

    // Controles de mídia
    this.handleEvent("p2p_start_media", async (config) => {
      await setupMedia(this.pc, config, this.el);
    });
  },

  destroyed() {
    if (this.pc) {
      this.pc.close();
      this.pc = null;
    }
  },
};

export default WebRTCHook;
```

### webrtc.js (lógica)

```javascript
export function createPeerConnection(iceServers, callbacks) {
  const pc = new RTCPeerConnection({ iceServers });

  pc.onicecandidate = (event) => {
    if (event.candidate) {
      callbacks.onIceCandidate(event.candidate);
    }
  };

  pc.ontrack = callbacks.onTrack;

  pc.ondatachannel = (event) => {
    callbacks.onDataChannel(event.channel);
  };

  return pc;
}

export async function handleSignal(pc, payload, sendResponse) {
  switch (payload.type) {
    case "offer":
      await pc.setRemoteDescription({ type: "offer", sdp: payload.sdp });
      const answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      sendResponse({ type: "answer", sdp: answer.sdp });
      break;

    case "answer":
      await pc.setRemoteDescription({ type: "answer", sdp: payload.sdp });
      break;

    case "ice-candidate":
      if (payload.candidate) {
        await pc.addIceCandidate(payload.candidate);
      }
      break;
  }
}
```

## V. Server-Side — handle_event e handle_info

### P2PSessionLive (simplificado)

```elixir
defmodule RetroHexChatWeb.P2PSessionLive do
  use RetroHexChatWeb, :live_view

  @impl true
  def mount(%{"token" => token}, session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "p2p:#{token}")
    end

    # Validar token, carregar sessão, verificar autorização...
    {:ok, assign(socket, token: token, session: session_data)}
  end

  # Receber sinal WebRTC do browser e rebroadcast ao peer
  @impl true
  def handle_event("p2p_signal", payload, socket) do
    Phoenix.PubSub.broadcast(
      RetroHexChat.PubSub,
      "p2p:#{socket.assigns.token}",
      {:p2p_signal, %{from: socket.assigns.current_user, payload: payload}}
    )
    {:noreply, socket}
  end

  # Receber sinal do PubSub e enviar ao browser
  @impl true
  def handle_info({:p2p_signal, %{from: from, payload: payload}}, socket)
      when from != socket.assigns.current_user do
    {:noreply, push_event(socket, "p2p_signal", payload)}
  end

  # Ignorar sinais próprios (broadcast inclui o sender)
  def handle_info({:p2p_signal, _}, socket), do: {:noreply, socket}
end
```

## VI. Alternativa: Phoenix Channel Dedicado vs LiveView Events

### Opção A: Tudo via LiveView (recomendado)

```
Browser ←→ LiveView (WebSocket) ←→ PubSub ←→ Peer LiveView ←→ Browser
```

**Vantagens:**
- Usa a mesma conexão WebSocket do LiveView
- Estado da sessão vive nos assigns do LiveView
- Rendering da UI integrado
- Simplicidade — menos moving parts

**Desvantagens:**
- Se o LiveView reconectar (navegação, refresh), perde o estado JS
- Signaling compartilha o WebSocket com UI updates

### Opção B: Phoenix Channel separado

```
Browser ←→ Channel (WebSocket separado) ←→ PubSub ←→ Peer Channel ←→ Browser
```

**Vantagens:**
- Canal dedicado para signaling, sem competir com UI
- Pode sobreviver a reconexões do LiveView

**Desvantagens:**
- WebSocket adicional
- Mais complexidade de setup
- Duplicação de autenticação

### Recomendação

**LiveView (Opção A)** é a escolha certa para o RetroHexChat:

1. A sessão P2P vive em URL dedicada (`/p2p/:token`) — o LiveView é estável
2. Uma vez que WebRTC está estabelecido, o signaling não é mais necessário
3. Simplicidade alinhada com o princípio da constituição (Princípio I)
4. O padrão já é usado com sucesso em todo o resto do chat

Se no futuro a reconexão do LiveView se provar problemática, migrar para
Channel é relativamente simples — as mensagens PubSub são as mesmas.

## VII. Credenciais TURN de Curta Duração

O servidor precisa fornecer credenciais TURN temporárias para cada sessão:

```elixir
defmodule RetroHexChat.P2P.TurnCredentials do
  @spec generate(String.t()) :: %{username: String.t(), credential: String.t()}
  def generate(session_token) do
    # Credenciais TURN de curta duração (RFC 5766)
    ttl = 3600 # 1 hora
    timestamp = System.system_time(:second) + ttl
    username = "#{timestamp}:#{session_token}"

    credential =
      :crypto.mac(:hmac, :sha, turn_secret(), username)
      |> Base.encode64()

    %{username: username, credential: credential}
  end

  defp turn_secret do
    Application.get_env(:retro_hex_chat, :turn_secret)
  end
end
```

As credenciais são enviadas ao browser no mount do LiveView, junto com
os ICE servers:

```elixir
ice_servers = [
  %{urls: "stun:#{stun_host()}:3478"},
  %{
    urls: "turn:#{turn_host()}:3478",
    username: creds.username,
    credential: creds.credential
  }
]

{:ok, push_event(socket, "p2p_config", %{ice_servers: ice_servers})}
```

## VIII. Sequência Completa de Mensagens

```
Tempo  Origem    Destino    Canal          Mensagem
─────  ────────  ─────────  ─────────────  ────────────────────────────────
t0     User A    Server     handle_event   /p2p maria
t1     Server    DB         Ecto           INSERT p2p_sessions
t2     Server    GenServer  DynSupervisor  start_child(P2PSession)
t3     Server    PubSub     user:maria     {:p2p_invite, token, from: "rodrigo"}
t4     User A    Server     HTTP           GET /p2p/:token
t5     Server    User A     LiveView       mount + subscribe p2p:token
t6     User B    Server     HTTP           GET /p2p/:token (aceita convite)
t7     Server    User B     LiveView       mount + subscribe p2p:token
t8     Server    PubSub     p2p:token      {:p2p_session_event, :peer_joined}
t9     User A    Server     push_event     "quero enviar arquivo"
t10    Server    PubSub     p2p:token      {:p2p_action_request, file_transfer}
t11    User B    Server     push_event     "aceito"
t12    Server    PubSub     p2p:token      {:p2p_action_response, accepted}
t13    Server    User A     push_event     "p2p_start_offer" + ice_servers
t14    User A    Server     push_event     p2p_signal {type: "offer", sdp: ...}
t15    Server    PubSub     p2p:token      {:p2p_signal, offer}
t16    Server    User B     push_event     "p2p_signal" {offer}
t17    User B    Server     push_event     p2p_signal {type: "answer", sdp: ...}
t18    Server    PubSub     p2p:token      {:p2p_signal, answer}
t19    Server    User A     push_event     "p2p_signal" {answer}
t20    User A    Server     push_event     p2p_signal {type: "ice-candidate", ...}
t21    Server    PubSub     p2p:token      {:p2p_signal, ice-candidate}
t22    ...       ...        ...            (mais ICE candidates em ambas direções)
t23    ═══      ═══════     ═══════════    WebRTC P2P ESTABELECIDO
t24    User A   ←────────── P2P ──────────→ User B (servidor não participa)
```

Após t23, toda comunicação de mídia e dados flui diretamente entre os peers.
O servidor continua disponível para:
- Chat do lobby (mensagens de texto entre peers)
- Eventos de sessão (encerramento, status)
- Mas NÃO carrega mídia ou dados de arquivo
