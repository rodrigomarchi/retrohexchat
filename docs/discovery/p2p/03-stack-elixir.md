# Ecossistema Elixir WebRTC

## Bibliotecas, Ferramentas e Recomendações

---

## I. Contexto

O ecossistema Elixir para WebRTC amadureceu significativamente entre 2023 e 2026.
A Software Mansion lidera com `ex_webrtc` e ferramentas complementares. O projeto
Membrane oferece uma abordagem alternativa mais pesada. Para STUN/TURN, existem
opções em Elixir puro.

Este documento analisa as opções disponíveis e recomenda a stack para o
RetroHexChat.

## II. ex_webrtc — Software Mansion

**Repositório:** `elixir-webrtc/ex_webrtc`
**Licença:** Apache 2.0

`ex_webrtc` é uma implementação WebRTC em Elixir puro. Diferente de wrappers
sobre libwebrtc (C++), é escrita do zero em Elixir/Erlang, com dependências
mínimas em Rust apenas para SCTP (via `ex_sctp`).

### O que oferece

- **PeerConnection completa** — offer/answer, SDP parsing, ICE
- **DataChannel** — via `ex_sctp` (requer Rust compiler)
- **Mídia** — RTP/RTCP, SRTP, codecs (VP8, H.264, Opus)
- **ICE** — implementação completa com suporte a STUN/TURN
- **DTLS** — criptografia obrigatória, como spec WebRTC exige

### Exemplo de uso (server-side)

```elixir
{:ok, pc} = ExWebRTC.PeerConnection.start_link(
  ice_servers: [
    %{urls: "stun:stun.l.google.com:19302"},
    %{urls: "turn:turn.example.com", username: "user", credential: "pass"}
  ]
)

# Receber offer do browser via signaling
{:ok, offer} = ExWebRTC.SessionDescription.from_json(offer_json)
:ok = ExWebRTC.PeerConnection.set_remote_description(pc, offer)

# Gerar answer
{:ok, answer} = ExWebRTC.PeerConnection.create_answer(pc)
:ok = ExWebRTC.PeerConnection.set_local_description(pc, answer)

# answer_json vai pro browser via signaling
answer_json = ExWebRTC.SessionDescription.to_json(answer)
```

### Maturidade

- Desenvolvimento ativo desde 2023
- Usado em produção pela Software Mansion
- Boa documentação e exemplos
- Comunidade crescente
- Suporte a DataChannel adicionado via `ex_sctp`

### Consideração importante

`ex_webrtc` é uma implementação **server-side** de WebRTC. Para P2P puro
entre browsers, o servidor não precisa de uma PeerConnection própria — ele
precisa apenas fazer signaling (encaminhar SDP e ICE candidates entre os
peers).

**Para o RetroHexChat, `ex_webrtc` seria necessário apenas se quiséssemos
o servidor como endpoint WebRTC** (ex: gravação, transcodificação, SFU).
Para P2P puro, o servidor faz apenas signaling — que é trivial via Phoenix
PubSub.

## III. Membrane WebRTC Plugin

**Repositório:** `membraneframework/membrane_webrtc_plugin`
**Licença:** Apache 2.0

Membrane é um framework de processamento de mídia em Elixir. O plugin WebRTC
integra com o ecossistema Membrane para pipelines de mídia complexos.

### O que oferece

- **Integração LiveView** — componentes prontos para WebRTC em LiveView
- **Pipelines de mídia** — processamento, mixing, transcodificação
- **SFU (Selective Forwarding Unit)** — para conferências multi-party
- **Gravação** — captura de streams para arquivo

### Quando usar

Membrane faz sentido para:
- Conferências com 3+ participantes (SFU)
- Gravação server-side de chamadas
- Transcodificação de formatos
- Pipelines de processamento de áudio/vídeo

### Quando NÃO usar

Para P2P 1-a-1 como o RetroHexChat:
- Overhead desnecessário — Membrane é um framework pesado
- Não precisamos de SFU (apenas 2 participantes)
- Não precisamos de processamento server-side de mídia
- Complexidade de setup e manutenção maior

## IV. Rel — TURN Server em Elixir

**Repositório:** `elixir-webrtc/rel`
**Licença:** Apache 2.0
**Parte do ecossistema ex_webrtc**

Rel é um servidor TURN implementado em Elixir puro. Permite rodar STUN/TURN
self-hosted sem dependências externas como coturn.

### Características

- STUN + TURN em um único servidor
- Elixir puro — sem dependências C/C++
- Configuração via Elixir config
- Autenticação de credenciais de curta duração
- Suporte a UDP e TCP
- Lightweight — pode rodar no mesmo node da aplicação

### Exemplo de configuração

```elixir
# config/runtime.exs
config :rel,
  listen_ip: {0, 0, 0, 0},
  listen_port: 3478,
  realm: "retro-hex-chat",
  auth_secret: System.get_env("TURN_SECRET"),
  # Credenciais de curta duração (TTL em segundos)
  credential_ttl: 3600
```

### Vantagem para o RetroHexChat

Self-hosted é um princípio do projeto. Rodar Rel no mesmo deployment elimina
a dependência de TURN servers externos, mantendo a premissa de zero serviços
SaaS para mídia.

## V. Alternativas STUN/TURN

### MongooseICE (Erlang Solutions)

- STUN/TURN server em Elixir
- Projeto mais antigo, menos ativo
- Compatível, mas menos integrado com ex_webrtc

### XTurn

- Outra implementação TURN em Elixir
- Menos documentação e comunidade
- Funcional mas sem desenvolvimento ativo

### coturn (C)

- O TURN server mais usado do mundo
- Robusto, battle-tested, altamente configurável
- Não é Elixir — precisa de deploy separado
- Boa opção se performance de relay for crítica

## VI. Tabela Comparativa

| Critério | ex_webrtc | Membrane | Rel | coturn |
|----------|-----------|----------|-----|--------|
| **Linguagem** | Elixir | Elixir | Elixir | C |
| **Propósito** | PeerConnection server-side | Pipeline de mídia + SFU | TURN server | TURN server |
| **Necessário para P2P puro?** | Não¹ | Não | Sim (relay) | Sim (relay) |
| **Complexidade** | Média | Alta | Baixa | Baixa |
| **Self-hosted** | Sim | Sim | Sim | Sim |
| **Maturidade** | Boa | Boa | Moderada | Excelente |
| **Manutenção** | Ativa | Ativa | Ativa | Ativa |
| **Deploy integrado** | Sim | Sim | Sim | Separado |
| **Elixir stack** | ✓ | ✓ | ✓ | ✗ |

¹ Para P2P puro entre browsers, o servidor faz apenas signaling. `ex_webrtc` seria
necessário apenas para server-side media (gravação, SFU, etc.).

## VII. Recomendação para o RetroHexChat

### Stack recomendada

```
┌────────────────────────────────────────────────┐
│                Navegador (Peer)                │
│  ┌──────────────────────────────────────────┐  │
│  │  RTCPeerConnection (API nativa)          │  │
│  │  RTCDataChannel (transferência)          │  │
│  │  getUserMedia (áudio/vídeo)              │  │
│  └──────────────────────────────────────────┘  │
└────────────────────────────────────────────────┘
                     │ signaling
                     ▼
┌────────────────────────────────────────────────┐
│              Servidor RetroHexChat             │
│  ┌──────────────────────────────────────────┐  │
│  │  Phoenix PubSub (signaling SDP+ICE)      │  │
│  │  GenServer por sessão P2P                │  │
│  │  Ecto schema (p2p_sessions)              │  │
│  └──────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────┐  │
│  │  Rel (STUN/TURN integrado)               │  │
│  └──────────────────────────────────────────┘  │
└────────────────────────────────────────────────┘
```

### Justificativa

1. **Signaling via Phoenix PubSub** — não precisa de `ex_webrtc` para P2P puro.
   O servidor encaminha SDP e ICE candidates. Trivial em Elixir.

2. **RTCPeerConnection no browser** — toda a complexidade WebRTC é resolvida
   pela API nativa do navegador. Sem libs JS extras.

3. **Rel para STUN/TURN** — self-hosted, Elixir puro, deploy integrado.
   Sem dependência de coturn externo.

4. **ex_webrtc como dependência futura** — se no futuro quisermos gravação
   server-side, SFU para conferências, ou processamento de mídia, `ex_webrtc`
   pode ser adicionado. Mas para P2P 1-a-1, é overhead desnecessário.

### Dependências a adicionar

```elixir
# mix.exs do app de domínio
defp deps do
  [
    # STUN/TURN server self-hosted
    {:rel, "~> x.x"},  # verificar versão atual
  ]
end
```

```javascript
// Lado do browser — ZERO dependências extras
// RTCPeerConnection é API nativa
const pc = new RTCPeerConnection({
  iceServers: [
    { urls: "stun:stun.retro-hex-chat.example:3478" },
    { urls: "turn:turn.retro-hex-chat.example:3478",
      username: credentials.username,
      credential: credentials.password }
  ]
});
```

## VIII. Dependência em Rust — ex_sctp

`ex_sctp` é a dependência de `ex_webrtc` que implementa SCTP (necessário
para DataChannel). Usa NIF em Rust, então requer Rust compiler no build.

**Para o RetroHexChat, isso não se aplica na recomendação atual**, já que
não usamos `ex_webrtc` server-side. DataChannel é implementado nativamente
pelo browser.

Se no futuro adicionarmos `ex_webrtc`:

```bash
# Requisito de build
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

O CI precisaria de Rust instalado. Algo a considerar antes de adicionar
a dependência.
