# Fundamentos WebRTC

## Arquitetura P2P, Signaling e Travessia de NAT

---

## I. O que é WebRTC

WebRTC (Web Real-Time Communication) é uma API de navegador que permite
comunicação em tempo real entre dois peers — áudio, vídeo e dados — sem
plugins, sem servidores intermediários para mídia, e com criptografia
obrigatória.

Três capacidades fundamentais:

1. **MediaStream** — captura de áudio e vídeo do dispositivo (`getUserMedia`)
2. **RTCPeerConnection** — conexão P2P com negociação de mídia e travessia de NAT
3. **RTCDataChannel** — canal de dados arbitrários (texto, binário) sobre a conexão P2P

O navegador cuida de tudo: negociação de codecs, criptografia DTLS/SRTP,
estimativa de bandwidth, adaptação de qualidade. A aplicação precisa apenas
orquestrar o signaling — a troca de metadados que permite aos dois peers
se encontrarem.

## II. O Modelo Offer/Answer

WebRTC usa o modelo offer/answer (RFC 3264) para negociar a sessão:

```
  Peer A (Offerer)              Servidor               Peer B (Answerer)
       │                           │                          │
       │── createOffer() ──────────│                          │
       │── setLocalDescription() ──│                          │
       │                           │                          │
       │── offer SDP ──────────────▶── offer SDP ─────────────▶
       │                           │                          │
       │                           │                          │── setRemoteDescription()
       │                           │                          │── createAnswer()
       │                           │                          │── setLocalDescription()
       │                           │                          │
       │◀── answer SDP ────────────◀── answer SDP ────────────│
       │                           │                          │
       │── setRemoteDescription() ─│                          │
       │                           │                          │
       │◀═══════════ conexão P2P estabelecida ════════════════▶
```

**Passo a passo:**

1. Peer A cria uma `RTCPeerConnection`
2. Peer A chama `createOffer()` — gera um SDP descrevendo suas capacidades
3. Peer A define o offer como `localDescription`
4. Peer A envia o offer SDP ao servidor (signaling)
5. Servidor encaminha o offer SDP ao Peer B
6. Peer B define o offer como `remoteDescription`
7. Peer B chama `createAnswer()` — gera SDP com capacidades compatíveis
8. Peer B define o answer como `localDescription`
9. Peer B envia o answer SDP ao servidor
10. Servidor encaminha o answer SDP ao Peer A
11. Peer A define o answer como `remoteDescription`
12. Conexão P2P negociada — mídia pode fluir

## III. SDP — Session Description Protocol

O SDP é um formato de texto que descreve as capacidades de mídia de um peer.
Exemplo simplificado:

```
v=0
o=- 4567890 2 IN IP4 127.0.0.1
s=-
t=0 0
m=audio 49170 UDP/TLS/RTP/SAVPF 111
a=rtpmap:111 opus/48000/2
a=ice-ufrag:F7gI
a=ice-pwd:x9cml/YzichV2+XlhiMu8g
a=fingerprint:sha-256 D1:...:FF
m=video 51372 UDP/TLS/RTP/SAVPF 96
a=rtpmap:96 VP8/90000
```

Campos relevantes:
- **m=** — descrição de mídia (áudio, vídeo, dados)
- **a=rtpmap** — mapeamento de codecs
- **a=ice-ufrag/ice-pwd** — credenciais ICE
- **a=fingerprint** — fingerprint DTLS para verificação de identidade

O SDP é opaco para o servidor de signaling. O servidor apenas encaminha — não
precisa entender o conteúdo.

## IV. ICE — Interactive Connectivity Establishment

ICE é o framework que descobre o melhor caminho de rede entre dois peers.
O problema fundamental: ambos os peers podem estar atrás de NATs diferentes,
firewalls, proxies. ICE testa sistematicamente as possibilidades.

### Tipos de candidatos ICE

| Tipo | Descrição | Prioridade | Latência |
|------|-----------|------------|----------|
| `host` | IP local direto (LAN) | Alta | Mínima |
| `srflx` | Server Reflexive — IP público via STUN | Média | Baixa |
| `prflx` | Peer Reflexive — descoberto durante check | Média | Baixa |
| `relay` | Via servidor TURN | Baixa | Maior |

### Processo ICE

```
  Peer A                                              Peer B
    │                                                    │
    │── gather candidates (host, srflx, relay) ──        │
    │                                                    │
    │── candidate: host 192.168.1.5:12345 ──────────────▶│
    │── candidate: srflx 203.0.113.1:54321 ─────────────▶│
    │── candidate: relay 198.51.100.1:3478 ─────────────▶│
    │                                                    │
    │◀── candidate: host 10.0.0.8:23456 ────────────────│
    │◀── candidate: srflx 198.51.100.2:65432 ───────────│
    │◀── candidate: relay 198.51.100.1:3479 ────────────│
    │                                                    │
    │══ connectivity checks (STUN binding requests) ════│
    │                                                    │
    │══ melhor par selecionado ═════════════════════════│
```

ICE testa todos os pares de candidatos (A.host↔B.host, A.host↔B.srflx, etc.)
e seleciona o par com melhor conectividade e menor latência.

### Trickle ICE

Na implementação moderna, candidatos são enviados incrementalmente conforme
são descobertos (trickle ICE), em vez de esperar reunir todos antes de
começar. Isso acelera o tempo de conexão.

```javascript
pc.onicecandidate = (event) => {
  if (event.candidate) {
    // Enviar ao peer via signaling
    sendToServer({ type: "ice-candidate", candidate: event.candidate });
  }
};
```

## V. STUN — Descoberta de IP Público

STUN (Session Traversal Utilities for NAT) é um protocolo simples: o cliente
envia um request, o servidor responde com o IP:porta como visto externamente.

```
  Cliente                    Servidor STUN
  (192.168.1.5)              (stun.example.com)
       │                          │
       │── Binding Request ───────▶
       │                          │
       │◀── Binding Response ─────│
       │    "Você é 203.0.113.1   │
       │     porta 54321"         │
       │                          │
```

**Características:**
- Protocolo leve (UDP, poucos bytes)
- Servidor stateless — pode atender milhares de clientes
- Não consome bandwidth significativo
- Muitos servidores STUN públicos gratuitos disponíveis
- Funciona para ~70% dos cenários de NAT

**Limitação:** STUN falha em NATs simétricos, que mudam a porta mapeada
para cada destino diferente. Nesses casos, é necessário TURN.

## VI. TURN — Relay para NATs Restritivos

TURN (Traversal Using Relays around NAT) é o fallback: quando a conexão
direta falha, o servidor TURN atua como relay, encaminhando pacotes entre
os peers.

```
  Peer A                  Servidor TURN               Peer B
    │                          │                          │
    │── Allocate Request ──────▶                          │
    │◀── Allocate Response ────│                          │
    │    (relay: 198.51.100.1  │                          │
    │     porta 3478)          │                          │
    │                          │                          │
    │── dados ─────────────────▶── dados ─────────────────▶
    │◀── dados ────────────────◀── dados ─────────────────│
    │                          │                          │
```

**Características:**
- Necessário em ~30% dos cenários (NATs simétricos, firewalls corporativos)
- Consome bandwidth do servidor (relay de todos os pacotes)
- Requer autenticação (credenciais de curta duração)
- Mais caro para operar — mas essencial para confiabilidade
- DTLS mantém criptografia ponta-a-ponta mesmo via relay

**Importante:** Mesmo passando pelo TURN, a criptografia é ponta-a-ponta.
O servidor TURN vê pacotes criptografados — não tem acesso ao conteúdo.

## VII. DataChannel — Transferência de Dados

RTCDataChannel permite envio de dados arbitrários (texto ou binário) sobre
a conexão P2P. Usa SCTP (Stream Control Transmission Protocol) sobre DTLS.

```javascript
// Criação do DataChannel
const dc = peerConnection.createDataChannel("file-transfer", {
  ordered: true,        // Entrega em ordem
  maxRetransmits: 3,    // Retry em caso de perda
});

dc.onopen = () => { /* pronto para enviar */ };
dc.onmessage = (event) => { /* dados recebidos */ };

// Envio de dados binários
dc.send(arrayBuffer);
```

**Características:**
- Suporta texto (UTF-8) e binário (ArrayBuffer, Blob)
- Pode ser reliable (TCP-like) ou unreliable (UDP-like)
- Múltiplos DataChannels na mesma PeerConnection
- Tamanho máximo de mensagem: ~256KB (varia por browser)
- Para arquivos grandes: chunking necessário (ver `04-transferencia-arquivos.md`)

## VIII. MediaStream — Captura de Mídia

`getUserMedia()` captura áudio e vídeo do dispositivo:

```javascript
const stream = await navigator.mediaDevices.getUserMedia({
  audio: true,
  video: { width: 640, height: 480 }
});

// Adicionar tracks à PeerConnection
stream.getTracks().forEach(track => {
  peerConnection.addTrack(track, stream);
});
```

**Requisitos do navegador:**
- HTTPS obrigatório (ou localhost para desenvolvimento)
- Permissão explícita do usuário (prompt do navegador)
- Permissão por origem — concedida uma vez, lembrada

Ver `05-audio-video.md` para detalhes de codecs e controles.

## IX. Segurança — DTLS Obrigatório

Toda comunicação WebRTC é criptografada por padrão. Não é opcional.

```
  ┌────────────────────────────────────────────────┐
  │              Camadas de Segurança              │
  ├────────────────────────────────────────────────┤
  │  Dados:  SCTP → DTLS → ICE → UDP              │
  │  Mídia:  RTP  → SRTP → DTLS → ICE → UDP       │
  ├────────────────────────────────────────────────┤
  │  • DTLS handshake antes de qualquer dado       │
  │  • Fingerprint no SDP para verificação         │
  │  • Chaves efêmeras por sessão                  │
  │  • Forward secrecy via ECDHE                   │
  │  • Mesmo via TURN, conteúdo é E2E criptografado│
  └────────────────────────────────────────────────┘
```

**DTLS** (Datagram TLS) é o equivalente do TLS para UDP. Toda PeerConnection
faz handshake DTLS antes de transmitir qualquer dado. As chaves são
verificadas via fingerprint presente no SDP.

**SRTP** (Secure RTP) protege os streams de mídia (áudio/vídeo) usando
chaves derivadas do handshake DTLS.

## X. Diagrama Completo — Handshake WebRTC

```
  Peer A                    Servidor                    Peer B
    │                       (Signaling)                    │
    │                          │                          │
    │  1. createOffer()        │                          │
    │  2. setLocalDescription()│                          │
    │                          │                          │
    │── 3. offer SDP ──────────▶── 4. offer SDP ─────────▶
    │                          │                          │
    │── 5. ICE candidate ──────▶── 6. ICE candidate ──────▶
    │── 5. ICE candidate ──────▶── 6. ICE candidate ──────▶
    │                          │                          │
    │                          │   7. setRemoteDescription()
    │                          │   8. createAnswer()
    │                          │   9. setLocalDescription()
    │                          │                          │
    │◀── 11. answer SDP ───────◀── 10. answer SDP ───────│
    │                          │                          │
    │◀── 13. ICE candidate ────◀── 12. ICE candidate ────│
    │◀── 13. ICE candidate ────◀── 12. ICE candidate ────│
    │                          │                          │
    │  14. setRemoteDescription()                         │
    │                          │                          │
    │═══ 15. ICE connectivity checks ════════════════════│
    │═══ 16. DTLS handshake ═════════════════════════════│
    │═══ 17. SCTP association (se DataChannel) ══════════│
    │═══ 18. SRTP key exchange (se mídia) ═══════════════│
    │                          │                          │
    │◀══════════ P2P ATIVO — mídia/dados fluindo ════════▶
    │                          │                          │
    │      (servidor não        │                          │
    │       participa mais)     │                          │
```

Note que após o passo 18, o servidor não participa mais da comunicação.
Toda mídia e dados fluem diretamente entre os peers. O servidor pode até
cair sem afetar a sessão ativa.
