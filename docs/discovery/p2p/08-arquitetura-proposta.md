# Arquitetura Proposta

## Bounded Context, GenServer, Schemas, Router e Componentes

---

## I. Visão Geral da Arquitetura

O P2P no RetroHexChat segue os mesmos padrões arquiteturais já estabelecidos
pelo projeto: bounded context no app de domínio, LiveView no app web, OTP
processes para estado em tempo real, Ecto para persistência.

```
┌──────────────────────────────────────────────────────────────┐
│                        Browser (Peer)                        │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  P2PSessionLive (LiveView)                             │  │
│  │  ├── webrtc_hook.js → lib/webrtc.js                    │  │
│  │  ├── file_transfer_hook.js → lib/file_transfer.js      │  │
│  │  └── media_hook.js → lib/media.js                      │  │
│  │                                                        │  │
│  │  RTCPeerConnection (API nativa do browser)             │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
                          │ WebSocket (LiveView)
                          ▼
┌──────────────────────────────────────────────────────────────┐
│                    retro_hex_chat_web                         │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  Router: /p2p/:token → P2PSessionLive                  │  │
│  │  Components: p2p_lobby, p2p_controls, p2p_video        │  │
│  │  CSS: p2p-session.css, p2p-lobby.css                   │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
                          │ Context API
                          ▼
┌──────────────────────────────────────────────────────────────┐
│                      retro_hex_chat                           │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  RetroHexChat.P2P (Bounded Context)                    │  │
│  │  ├── Service       → Orquestração de sessões           │  │
│  │  ├── Policy        → Autorização e regras              │  │
│  │  ├── SessionServer → GenServer por sessão              │  │
│  │  ├── SessionToken  → Geração/verificação de tokens     │  │
│  │  ├── TurnCredentials → Credenciais TURN temporárias    │  │
│  │  ├── RateLimit     → Limites de criação/signaling      │  │
│  │  ├── Schema        → p2p_sessions (Ecto)               │  │
│  │  └── Queries       → Consultas Ecto                    │  │
│  └────────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  Supervision Tree                                      │  │
│  │  └── P2P.DynamicSupervisor                             │  │
│  │      └── P2P.SessionServer (1 por sessão ativa)        │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────┐
│  PostgreSQL                                                  │
│  └── p2p_sessions (token, creator_id, peer_id, status, ...) │
└──────────────────────────────────────────────────────────────┘
```

## II. Novo Bounded Context: `RetroHexChat.P2P`

Seguindo o Princípio II da constituição (Umbrella + Bounded Contexts),
P2P é um contexto separado — não uma extensão de `Chat`.

### Justificativa para contexto próprio

1. **Domínio distinto** — P2P tem ciclo de vida, estados e regras próprias
2. **Sem dependência de canais** — sessões P2P são entre 2 usuários,
   independente de canais
3. **Processo architecture própria** — GenServer por sessão, não por canal
4. **Testabilidade** — contexto independente pode ser testado isoladamente

### Estrutura de módulos

```
lib/retro_hex_chat/p2p/
├── p2p.ex                  # Fachada do contexto (API pública)
├── service.ex              # Orquestração: criar, aceitar, encerrar
├── policy.ex               # Regras: quem pode criar, aceitar, etc.
├── session_server.ex       # GenServer por sessão ativa
├── session_token.ex        # Phoenix.Token para sessões
├── turn_credentials.ex     # Credenciais TURN de curta duração
├── rate_limit.ex           # Rate limiting específico de P2P
├── schema/
│   └── session.ex          # Schema Ecto: p2p_sessions
└── queries.ex              # Consultas Ecto
```

## III. Schema Ecto: `p2p_sessions`

### Migration

```elixir
defmodule RetroHexChat.Repo.Migrations.CreateP2PSessions do
  use Ecto.Migration

  def change do
    create table(:p2p_sessions) do
      add :token, :string, null: false
      add :creator_id, references(:users, on_delete: :delete_all), null: false
      add :peer_id, references(:users, on_delete: :delete_all), null: false
      add :status, :string, null: false, default: "pending"
      add :session_type, :string  # "generic", "file_transfer", "audio_call", "video_call"
      add :metadata, :map, default: %{}  # Dados adicionais (nome do arquivo, etc.)
      add :closed_at, :utc_datetime_usec
      add :closed_reason, :string  # "graceful", "timeout", "error", "rejected"

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:p2p_sessions, [:token])
    create index(:p2p_sessions, [:creator_id])
    create index(:p2p_sessions, [:peer_id])
    create index(:p2p_sessions, [:status])
    create index(:p2p_sessions, [:inserted_at])
  end
end
```

### Schema

```elixir
defmodule RetroHexChat.P2P.Schema.Session do
  use Ecto.Schema
  import Ecto.Changeset

  @type status :: :pending | :lobby | :connecting | :active | :closed | :expired | :failed

  schema "p2p_sessions" do
    field :token, :string
    field :status, Ecto.Enum, values: [:pending, :lobby, :connecting, :active,
                                       :closed, :expired, :failed]
    field :session_type, Ecto.Enum, values: [:generic, :file_transfer,
                                              :audio_call, :video_call]
    field :metadata, :map, default: %{}
    field :closed_at, :utc_datetime_usec
    field :closed_reason, :string

    belongs_to :creator, RetroHexChat.Accounts.User
    belongs_to :peer, RetroHexChat.Accounts.User

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields [:token, :creator_id, :peer_id, :status]
  @optional_fields [:session_type, :metadata, :closed_at, :closed_reason]

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(session, attrs) do
    session
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:token)
    |> foreign_key_constraint(:creator_id)
    |> foreign_key_constraint(:peer_id)
  end
end
```

## IV. GenServer por Sessão P2P

Seguindo o Princípio III (OTP Process Architecture), cada sessão P2P ativa
tem seu próprio GenServer, gerenciado por DynamicSupervisor.

### Supervision tree

```
RetroHexChat.Application
└── RetroHexChat.P2P.Supervisor (rest_for_one)
    ├── Registry (P2P.SessionRegistry)
    └── DynamicSupervisor (P2P.DynamicSupervisor)
        ├── P2P.SessionServer {:session, "token-abc"}
        ├── P2P.SessionServer {:session, "token-def"}
        └── ...
```

### SessionServer

```elixir
defmodule RetroHexChat.P2P.SessionServer do
  use GenServer

  @pending_timeout :timer.minutes(5)
  @lobby_timeout :timer.minutes(15)

  defstruct [
    :session_id, :token, :creator_id, :peer_id,
    :status, :lobby_messages, :peers_present,
    :missed_heartbeats
  ]

  # --- API pública ---

  @spec start_link(map()) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args,
      name: via_tuple(args.token))
  end

  @spec join_lobby(String.t(), integer()) :: :ok | {:error, atom()}
  def join_lobby(token, user_id) do
    GenServer.call(via_tuple(token), {:join_lobby, user_id})
  end

  @spec send_lobby_message(String.t(), integer(), String.t()) :: :ok
  def send_lobby_message(token, user_id, text) do
    GenServer.cast(via_tuple(token), {:lobby_message, user_id, text})
  end

  @spec request_action(String.t(), integer(), map()) :: :ok
  def request_action(token, user_id, action) do
    GenServer.cast(via_tuple(token), {:request_action, user_id, action})
  end

  # --- Callbacks ---

  @impl true
  def init(args) do
    state = %__MODULE__{
      session_id: args.session_id,
      token: args.token,
      creator_id: args.creator_id,
      peer_id: args.peer_id,
      status: :pending,
      lobby_messages: [],
      peers_present: MapSet.new(),
      missed_heartbeats: 0
    }

    schedule_timeout(@pending_timeout)
    {:ok, state}
  end

  @impl true
  def handle_call({:join_lobby, user_id}, _from, state) do
    if user_id in [state.creator_id, state.peer_id] do
      new_peers = MapSet.put(state.peers_present, user_id)
      new_status = if MapSet.size(new_peers) == 2, do: :lobby, else: state.status

      broadcast(state.token, {:p2p_session_event, :peer_joined, user_id})

      if new_status == :lobby do
        cancel_timeout()
        schedule_timeout(@lobby_timeout)
      end

      {:reply, :ok, %{state | peers_present: new_peers, status: new_status}}
    else
      {:reply, {:error, :unauthorized}, state}
    end
  end

  # ... demais callbacks (lobby_message, request_action, timeouts)

  defp via_tuple(token) do
    {:via, Registry, {RetroHexChat.P2P.SessionRegistry, {:session, token}}}
  end

  defp broadcast(token, message) do
    Phoenix.PubSub.broadcast(RetroHexChat.PubSub, "p2p:#{token}", message)
  end
end
```

## V. Router

```elixir
# lib/retro_hex_chat_web/router.ex

scope "/", RetroHexChatWeb do
  pipe_through [:browser, :require_authenticated_user]

  # ... rotas existentes ...

  live "/p2p/:token", P2PSessionLive, :show
end
```

A rota `/p2p/:token` está no pipe `require_authenticated_user`, garantindo
que apenas usuários registrados e autenticados podem acessar.

## VI. P2PSessionLive

```elixir
defmodule RetroHexChatWeb.P2PSessionLive do
  use RetroHexChatWeb, :live_view

  alias RetroHexChat.P2P

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case P2P.verify_and_join(token, socket.assigns.current_user) do
      {:ok, session} ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "p2p:#{token}")
        end

        ice_servers = P2P.ice_servers_for_session(token)

        {:ok,
         socket
         |> assign(token: token, session: session, ice_servers: ice_servers)
         |> assign(lobby_messages: [], action_pending: nil)}

      {:error, reason} ->
        {:ok,
         socket
         |> put_flash(:error, error_message(reason))
         |> redirect(to: ~p"/chat")}
    end
  end

  # ... handle_event para signaling, lobby messages, ações
  # ... handle_info para PubSub messages
end
```

## VII. JS Hooks

Seguindo o padrão "hook = wiring, lib = logic":

### Arquivos novos

```
assets/js/
├── hooks/
│   ├── webrtc_hook.js              # Wiring: signaling ↔ PeerConnection
│   ├── file_transfer_hook.js       # Wiring: UI ↔ DataChannel
│   └── media_hook.js               # Wiring: UI ↔ getUserMedia
├── lib/
│   ├── webrtc.js                   # Lógica: PeerConnection, ICE, SDP
│   ├── file_transfer.js            # Lógica: chunking, progresso, resume
│   └── media.js                    # Lógica: getUserMedia, controles
└── test/
    ├── hooks/
    │   ├── webrtc_hook.test.js
    │   ├── file_transfer_hook.test.js
    │   └── media_hook.test.js
    └── lib/
        ├── webrtc.test.js
        ├── file_transfer.test.js
        └── media.test.js
```

### Registro dos hooks

```javascript
// app.js
import WebRTCHook from "./hooks/webrtc_hook";
import FileTransferHook from "./hooks/file_transfer_hook";
import MediaHook from "./hooks/media_hook";

const Hooks = {
  // ... hooks existentes ...
  WebRTC: WebRTCHook,
  FileTransfer: FileTransferHook,
  Media: MediaHook,
};
```

## VIII. CSS

Seguindo a arquitetura CSS do projeto (ver CLAUDE.md):

### Arquivos novos

```
assets/css/
├── p2p-session.css    # Layout geral da sessão P2P (>40 linhas)
└── p2p-lobby.css      # Lobby: chat, controles, vídeo (>40 linhas)
```

### Classes

```css
/* p2p-session.css */
.p2p-session { /* Container principal */ }
.p2p-session__header { /* Barra de título */ }
.p2p-session__content { /* Área de conteúdo */ }

/* p2p-lobby.css */
.p2p-lobby { /* Container do lobby */ }
.p2p-lobby__chat { /* Área de chat temporário */ }
.p2p-lobby__actions { /* Painel de ações */ }
.p2p-lobby__controls { /* Controles de mídia */ }
.p2p-lobby__video { /* Container de vídeo */ }
.p2p-lobby__video--remote { /* Vídeo remoto (grande) */ }
.p2p-lobby__video--local { /* Vídeo local (PiP) */ }
.p2p-lobby__progress { /* Barra de progresso de arquivo */ }
```

### Import em app.css

```css
/* Layer 4: Components */
@import "./p2p-session.css";
@import "./p2p-lobby.css";
```

## IX. Integração com Sistema de Ajuda

Seguindo o Princípio XI (Help Documentation), novos help topics:

```elixir
# Em RetroHexChat.Chat.HelpTopics

%{
  title: "P2P Sessions",
  category: "Features",
  content: """
  P2P (Peer-to-Peer) permite transferência de arquivos e chamadas de
  áudio/vídeo diretamente entre dois usuários, sem que os dados passem
  pelo servidor.

  Comandos:
    /p2p <nickname>      - Iniciar sessão P2P genérica
    /call <nickname>     - Iniciar chamada de áudio/vídeo
    /sendfile <nickname> - Enviar arquivo

  Requisitos:
    - Ambos os participantes devem ser usuários registrados
    - HTTPS necessário para chamadas de áudio/vídeo

  See Also: File Transfer, Audio/Video Calls, Privacy Settings
  """
}

%{
  title: "File Transfer",
  category: "Features",
  content: """
  Transfira arquivos diretamente para outro usuário via P2P.
  Os dados são criptografados ponta-a-ponta e não passam pelo servidor.

  Uso:
    /sendfile <nickname>

  Limites:
    - Tamanho máximo: 500 MB (configurável pelo operador)
    - Tipos bloqueados: .exe, .bat, .cmd, .scr
    - Uma transferência por sessão

  See Also: P2P Sessions
  """
}

%{
  title: "Audio/Video Calls",
  category: "Features",
  content: """
  Faça chamadas de áudio e vídeo diretamente com outro usuário.
  A mídia é criptografada ponta-a-ponta via WebRTC.

  Uso:
    /call <nickname>

  Controles durante a chamada:
    - Mute/unmute microfone
    - Ligar/desligar câmera
    - Trocar dispositivo (microfone, câmera)
    - Picture-in-Picture (vídeo)

  Modo Privado:
    Ative "TURN-only" nas configurações do lobby para esconder
    seu IP do outro participante.

  See Also: P2P Sessions, Privacy Settings
  """
}
```

### Novos comandos a registrar

| Comando | Handler Module | Descrição |
|---------|---------------|-----------|
| `/p2p` | `Commands.Handlers.P2P` | Iniciar sessão P2P genérica |
| `/call` | `Commands.Handlers.Call` | Iniciar chamada de áudio/vídeo |
| `/sendfile` | `Commands.Handlers.SendFile` | Enviar arquivo via P2P |

## X. Diagrama de Componentes

```
┌─────────────────────────────────────────────────────────────────┐
│                          Browser                                │
│                                                                 │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────────────┐ │
│  │ WebRTCHook  │  │ FileTransfer │  │     MediaHook          │ │
│  │             │  │    Hook      │  │                        │ │
│  └──────┬──────┘  └──────┬───────┘  └───────────┬────────────┘ │
│         │                │                      │              │
│  ┌──────▼──────┐  ┌──────▼───────┐  ┌───────────▼────────────┐ │
│  │ webrtc.js   │  │file_transfer │  │     media.js           │ │
│  │ (lib)       │  │   .js (lib)  │  │     (lib)              │ │
│  └──────┬──────┘  └──────┬───────┘  └───────────┬────────────┘ │
│         │                │                      │              │
│  ┌──────▼────────────────▼──────────────────────▼────────────┐ │
│  │              RTCPeerConnection (API nativa)                │ │
│  │  ├── DataChannel (arquivos)                               │ │
│  │  ├── MediaStream (áudio/vídeo)                            │ │
│  │  └── ICE (travessia de NAT)                               │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────┬───────────────────────────────────┘
                              │ push_event / handle_event
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      P2PSessionLive                             │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Components:                                             │   │
│  │  ├── p2p_lobby (chat + ações)                            │   │
│  │  ├── p2p_video (layout de vídeo)                         │   │
│  │  ├── p2p_controls (mute, câmera, encerrar)               │   │
│  │  ├── p2p_file_progress (barra de progresso)              │   │
│  │  └── delete_confirm_dialog (reutilizado)                 │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────┬───────────────────────────────────┘
                              │ Context API
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    RetroHexChat.P2P                              │
│  ┌──────────┐  ┌────────┐  ┌───────────────┐  ┌─────────────┐  │
│  │ Service  │  │ Policy │  │ SessionServer │  │   Queries   │  │
│  │          │  │        │  │  (GenServer)  │  │   (Ecto)    │  │
│  └────┬─────┘  └────┬───┘  └───────┬───────┘  └──────┬──────┘  │
│       │             │              │                  │         │
│  ┌────▼─────────────▼──────────────▼──────────────────▼──────┐  │
│  │                    PubSub "p2p:#{token}"                  │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌───────────────┐  ┌─────────────────┐  ┌─────────────────┐   │
│  │ SessionToken  │  │TurnCredentials  │  │   RateLimit     │   │
│  └───────────────┘  └─────────────────┘  └─────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        PostgreSQL                               │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  p2p_sessions                                             │  │
│  │  ├── id, token (unique), creator_id, peer_id              │  │
│  │  ├── status, session_type, metadata                       │  │
│  │  ├── closed_at, closed_reason                             │  │
│  │  └── inserted_at, updated_at                              │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## XI. Conformidade com a Constituição

| Princípio | Conformidade | Detalhes |
|-----------|-------------|----------|
| I. Stack Exclusiva | ✓ | Elixir + Phoenix + LiveView. Sem libs JS para WebRTC (API nativa). |
| II. Umbrella + Bounded Contexts | ✓ | Novo contexto `P2P` em `retro_hex_chat`, `P2PSessionLive` em `retro_hex_chat_web`. |
| III. OTP Process Architecture | ✓ | GenServer por sessão, DynamicSupervisor, Registry via_tuple. |
| IV. TDD | ✓ | Testes para Service, Policy, SessionServer, Queries. JS tests para webrtc.js, file_transfer.js, media.js. |
| V. Contracts e Behaviours | ✓ | Handlers para `/p2p`, `/call`, `/sendfile` implementando Handler behaviour. |
| VI. Static Analysis | ✓ | @spec em todas as funções públicas. Credo, Dialyzer, ESLint, Prettier. |
| VII. Lean LiveViews | ✓ | P2PSessionLive delega para P2P context. Hooks são wiring, lógica em lib/. |
| VIII. retro Fidelity | ✓ | retro design system para lobby, controles, diálogos. Estética consistente com o resto. |
| IX. Hot/Cold Data | ✓ | SessionServer (GenServer) para estado ativo, PostgreSQL para histórico. |
| X. Scalable Architecture | ✓ | PubSub escala via pg adapter. GenServer por sessão isola falhas. |
| XI. Help Documentation | ✓ | Help topics para P2P Sessions, File Transfer, Audio/Video Calls. |
