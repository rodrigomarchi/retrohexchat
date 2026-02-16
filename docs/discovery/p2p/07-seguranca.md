# Segurança e Privacidade

## Tokens, Autorização, Proteção de IP e Rate Limiting

---

## I. Princípios de Segurança

A segurança do P2P no RetroHexChat se baseia em quatro pilares:

1. **Autenticação** — apenas usuários registrados podem criar/aceitar sessões
2. **Autorização** — tokens de sessão com escopo e expiração
3. **Criptografia** — DTLS/SRTP obrigatório em toda comunicação WebRTC
4. **Privacidade** — proteção contra leak de IP real

```
┌──────────────────────────────────────────────────────────┐
│                 Camadas de Segurança P2P                 │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ┌─ Autenticação ─────────────────────────────────────┐  │
│  │  Apenas usuários registrados (não guests)           │  │
│  │  Sessão Phoenix válida obrigatória                  │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                          │
│  ┌─ Autorização ──────────────────────────────────────┐  │
│  │  Phoenix.Token por sessão P2P                       │  │
│  │  Apenas os 2 peers autorizados podem acessar        │  │
│  │  Token expira em tempo configurável                 │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                          │
│  ┌─ Transporte ───────────────────────────────────────┐  │
│  │  HTTPS obrigatório (requisito do browser)           │  │
│  │  WebSocket sobre TLS (LiveView)                     │  │
│  │  DTLS (WebRTC signaling → dados)                    │  │
│  │  SRTP (WebRTC mídia)                                │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                          │
│  ┌─ Privacidade ──────────────────────────────────────┐  │
│  │  TURN-only mode opcional (esconde IP real)          │  │
│  │  Credenciais TURN de curta duração                  │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

## II. Tokens de Sessão

Cada sessão P2P é identificada por um token assinado via `Phoenix.Token`.

### Geração

```elixir
defmodule RetroHexChat.P2P.SessionToken do
  @max_age 86_400  # 24 horas (tempo máximo de vida da sessão)

  @spec generate(map()) :: String.t()
  def generate(%{creator_id: creator_id, peer_id: peer_id}) do
    Phoenix.Token.sign(
      RetroHexChatWeb.Endpoint,
      "p2p_session",
      %{
        creator_id: creator_id,
        peer_id: peer_id,
        created_at: System.system_time(:second)
      }
    )
  end

  @spec verify(String.t()) :: {:ok, map()} | {:error, atom()}
  def verify(token) do
    Phoenix.Token.verify(
      RetroHexChatWeb.Endpoint,
      "p2p_session",
      token,
      max_age: @max_age
    )
  end
end
```

### Propriedades do token

| Propriedade | Valor | Justificativa |
|-------------|-------|---------------|
| Algoritmo | HMAC-SHA256 | Padrão Phoenix.Token |
| Expiração | 24h | Sessões não devem durar mais que isso |
| Conteúdo | creator_id, peer_id, created_at | Identifica os participantes |
| Revogável | Sim (via estado no banco) | Encerramento antecipado |

### Validação no mount

```elixir
def mount(%{"token" => token}, _session, socket) do
  case P2P.SessionToken.verify(token) do
    {:ok, %{creator_id: cid, peer_id: pid}} ->
      current_user_id = socket.assigns.current_user.id

      if current_user_id in [cid, pid] do
        # Autorizado — é um dos peers
        {:ok, assign(socket, ...)}
      else
        # Não é participante desta sessão
        {:ok, redirect(socket, to: "/chat")}
      end

    {:error, :expired} ->
      {:ok, socket |> put_flash(:error, "Sessão expirada") |> redirect(to: "/chat")}

    {:error, _} ->
      {:ok, redirect(socket, to: "/chat")}
  end
end
```

## III. Autorização — Apenas Usuários Registrados

### Regra fundamental

**Guests NÃO podem usar P2P.** Ambos os participantes devem ser usuários
registrados com conta no sistema.

Justificativa:
1. **Identidade** — P2P requer confiança entre as partes. Guests não têm
   identidade persistente.
2. **Responsabilidade** — transferências de arquivo e chamadas precisam
   de rastreabilidade.
3. **Abuso** — guests poderiam criar sessões P2P para spam/DoS.

### Verificação

```elixir
defmodule RetroHexChat.P2P.Policy do
  @spec can_create_session?(User.t(), User.t()) :: :ok | {:error, atom()}
  def can_create_session?(creator, peer) do
    cond do
      creator.guest? -> {:error, :guests_cannot_use_p2p}
      peer.guest? -> {:error, :peer_is_guest}
      creator.id == peer.id -> {:error, :cannot_p2p_self}
      banned?(creator, peer) -> {:error, :peer_has_blocked_you}
      true -> :ok
    end
  end
end
```

### Integração com ignore/ban

O sistema de ignore existente (feature 019) se aplica ao P2P:
- Se Peer B bloqueou Peer A, Peer A não pode iniciar sessão P2P
- A notificação de convite não é enviada — Peer A recebe erro genérico
  (sem revelar que foi bloqueado)

## IV. Proteção contra IP Leak

### O problema

WebRTC, por design, troca endereços IP entre peers via ICE candidates.
Isso inclui:
- IPs locais (192.168.x.x, 10.x.x.x)
- IP público (via STUN)
- IPs de interfaces VPN

Em uma conexão P2P direta, ambos os peers conhecem o IP real um do outro.
Isso pode ser um problema de privacidade.

### TURN-only mode

Solução: modo onde toda comunicação passa pelo servidor TURN, escondendo
os IPs reais dos peers.

```javascript
// Configuração TURN-only
const pc = new RTCPeerConnection({
  iceServers: [
    {
      urls: "turn:turn.example.com:3478",
      username: credentials.username,
      credential: credentials.password,
    },
  ],
  iceTransportPolicy: "relay",  // <-- Força uso exclusivo de TURN
});
```

Com `iceTransportPolicy: "relay"`, o browser descarta candidatos `host` e
`srflx`, usando apenas candidatos `relay`. Os peers nunca veem o IP real
um do outro — apenas o IP do servidor TURN.

### Trade-offs do TURN-only

| Aspecto | P2P direto | TURN-only |
|---------|------------|-----------|
| Privacidade IP | IPs expostos | IPs escondidos |
| Latência | Mínima | Maior (relay) |
| Bandwidth | Sem custo servidor | Servidor carrega tudo |
| Qualidade de mídia | Melhor | Pode ser inferior |

### Configuração

O TURN-only mode deve ser **opção do usuário**, não padrão:

```elixir
# user_preferences.p2p_settings
%{
  "turn_only" => false,  # Default: conexão direta quando possível
}
```

Na UI do lobby, antes de iniciar a chamada:

```
┌──────────────────────────────────────────────────┐
│  Configurações de Privacidade                    │
│                                                  │
│  ☐ Modo privado (TURN-only)                      │
│    Esconde seu IP do outro participante.          │
│    Pode reduzir qualidade de áudio/vídeo.         │
│                                                  │
└──────────────────────────────────────────────────┘
```

## V. Rate Limiting na Criação de Sessões

O sistema de rate limiting existente (feature 020) se estende ao P2P:

### Limites

| Ação | Limite | Janela |
|------|--------|--------|
| Criar sessão P2P | 5 | 10 min |
| Enviar convite P2P | 10 | 30 min |
| Signaling messages | 100 | 1 min |

### Implementação

```elixir
defmodule RetroHexChat.P2P.RateLimit do
  use RetroHexChat.RateLimit

  @spec check_session_creation(integer()) :: :ok | {:error, :rate_limited}
  def check_session_creation(user_id) do
    check("p2p:create:#{user_id}", limit: 5, window: 600)
  end

  @spec check_signaling(String.t()) :: :ok | {:error, :rate_limited}
  def check_signaling(session_token) do
    check("p2p:signal:#{session_token}", limit: 100, window: 60)
  end
end
```

### Proteção contra abuso

Cenários protegidos:
1. **Spam de convites** — rate limit na criação impede bombardeio
2. **DoS via signaling** — rate limit em mensagens de signaling
3. **Sessões fantasma** — timeout automático em sessões inativas
4. **Harvest de IPs** — TURN-only mode + limites de sessão

## VI. Expiração Automática de Sessões

### GenServer com timeouts

```elixir
defmodule RetroHexChat.P2P.SessionServer do
  use GenServer

  @pending_timeout :timer.minutes(5)
  @lobby_timeout :timer.minutes(15)
  @heartbeat_interval :timer.seconds(30)
  @max_missed_heartbeats 3

  def init(state) do
    schedule_timeout(@pending_timeout)
    {:ok, state}
  end

  def handle_info(:timeout, %{status: :pending} = state) do
    expire_session(state)
    {:stop, :normal, state}
  end

  def handle_info(:timeout, %{status: :lobby} = state) do
    expire_session(state)
    {:stop, :normal, state}
  end

  def handle_info(:heartbeat_check, state) do
    if state.missed_heartbeats >= @max_missed_heartbeats do
      expire_session(state)
      {:stop, :normal, state}
    else
      schedule_heartbeat()
      {:noreply, %{state | missed_heartbeats: state.missed_heartbeats + 1}}
    end
  end

  defp expire_session(state) do
    P2P.Service.expire_session(state.session_id)
    broadcast(state.token, {:p2p_session_event, :expired})
  end
end
```

### Limpeza de sessões órfãs

Cron job (via GenServer periódico) para limpar sessões que ficaram em
estados intermediários:

```elixir
# A cada hora, limpar sessões pendentes com mais de 1 hora
def handle_info(:cleanup, state) do
  P2P.Queries.expire_stale_sessions(max_age: 3600)
  schedule_cleanup()
  {:noreply, state}
end
```

## VII. HTTPS — Requisito do Browser

`getUserMedia()` e WebRTC exigem contexto seguro (HTTPS ou localhost).
Isso não é uma restrição do RetroHexChat — é imposta pelo navegador.

### Em desenvolvimento

```elixir
# config/dev.exs
config :retro_hex_chat_web, RetroHexChatWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000]
  # localhost funciona sem HTTPS
```

### Em produção

```elixir
# config/runtime.exs
config :retro_hex_chat_web, RetroHexChatWeb.Endpoint,
  url: [host: "chat.example.com", scheme: "https", port: 443],
  force_ssl: [rewrite_on: [:x_forwarded_proto]]
```

HTTPS é obrigatório em produção. Sem ele, o browser recusa:
- `navigator.mediaDevices.getUserMedia()` — erro `NotAllowedError`
- `RTCPeerConnection` — pode funcionar em alguns browsers mas sem garantia

## VIII. Resumo das Ameaças e Mitigações

| Ameaça | Mitigação |
|--------|-----------|
| Sessão não autorizada | Phoenix.Token + verificação de peer_id |
| Guest usando P2P | Policy check: registrados only |
| Spam de convites | Rate limiting (5/10min) |
| DoS via signaling | Rate limiting (100/min por sessão) |
| Sessão abandonada | Timeout automático por estado |
| IP leak | TURN-only mode opcional |
| Interceptação de mídia | DTLS/SRTP obrigatório (built-in WebRTC) |
| Token roubado | Expiração 24h + verificação de user_id no mount |
| Abuso após bloqueio | Integração com sistema de ignore |
| HTTP em produção | force_ssl + verificação no mount |
