# Chamadas de Áudio e Vídeo

## getUserMedia, Codecs, Controles e Layout

---

## I. Visão Geral

Chamadas de áudio e vídeo no RetroHexChat usam a API `getUserMedia` do
navegador para capturar mídia e `RTCPeerConnection` para transmitir
diretamente ao peer. Nenhuma mídia passa pelo servidor — apenas o signaling
para estabelecer a conexão.

É o equivalente moderno das voice chats do mIRC (que usavam plugins como
o mIRC Voice Chat, limitados e instáveis). Agora com vídeo, criptografia
E2E, e adaptação automática de qualidade.

## II. getUserMedia — Captura de Mídia

### API básica

```javascript
// Chamada de áudio
const audioStream = await navigator.mediaDevices.getUserMedia({
  audio: true,
  video: false,
});

// Chamada de vídeo
const videoStream = await navigator.mediaDevices.getUserMedia({
  audio: true,
  video: {
    width: { ideal: 640 },
    height: { ideal: 480 },
    frameRate: { ideal: 30, max: 30 },
  },
});
```

### Requisitos do navegador

- **HTTPS obrigatório** — browsers recusam `getUserMedia` em HTTP
  (exceção: `localhost` para desenvolvimento)
- **Permissão do usuário** — prompt nativo do browser na primeira vez
- **Permissão por origem** — uma vez concedida, lembrada para o domínio

### Enumeração de dispositivos

```javascript
const devices = await navigator.mediaDevices.enumerateDevices();

const microphones = devices.filter(d => d.kind === "audioinput");
const cameras = devices.filter(d => d.kind === "videoinput");
const speakers = devices.filter(d => d.kind === "audiooutput");
```

Isso permite oferecer seletor de dispositivo na UI — qual microfone,
qual câmera, qual saída de áudio.

## III. Negociação de Codecs

WebRTC suporta múltiplos codecs. A negociação é automática via SDP — os
peers anunciam seus codecs suportados e acordam o melhor comum.

### Codecs de vídeo

| Codec | Qualidade | CPU | Suporte | Notas |
|-------|-----------|-----|---------|-------|
| **VP8** | Boa | Médio | Universal | Default WebRTC, royalty-free |
| **VP9** | Muito boa | Alto | Amplo | Melhor compressão, mais pesado |
| **H.264** | Muito boa | Baixo¹ | Universal | Aceleração HW em quase tudo |
| **AV1** | Excelente | Muito alto | Crescente | Futuro, ainda pesado para encode |

¹ H.264 tem aceleração de hardware na maioria dos dispositivos, resultando
em baixo uso de CPU.

### Codecs de áudio

| Codec | Qualidade | Bandwidth | Suporte | Notas |
|-------|-----------|-----------|---------|-------|
| **Opus** | Excelente | 6-510 kbps | Universal | Default WebRTC, adaptativo |
| **G.711** | Telefonia | 64 kbps | Universal | Fallback, qualidade limitada |

**Opus é o padrão** — qualidade excelente em bandwidth variável, adapta-se
automaticamente às condições de rede. Não há razão para usar outro codec
de áudio.

### Ordem de preferência recomendada

```
Vídeo: H.264 > VP8 > VP9
Áudio: Opus (único necessário)
```

H.264 como preferência por causa da aceleração de hardware, que resulta
em menor uso de CPU e bateria. VP8 como fallback universal.

## IV. Adicionando Tracks à PeerConnection

```javascript
async function startCall(peerConnection, withVideo) {
  const constraints = {
    audio: true,
    video: withVideo ? { width: 640, height: 480 } : false,
  };

  const localStream = await navigator.mediaDevices.getUserMedia(constraints);

  // Adicionar cada track à PeerConnection
  localStream.getTracks().forEach((track) => {
    peerConnection.addTrack(track, localStream);
  });

  // Exibir preview local
  localVideo.srcObject = localStream;

  return localStream;
}

// Receber tracks do peer remoto
peerConnection.ontrack = (event) => {
  remoteVideo.srcObject = event.streams[0];
};
```

## V. Controles de Chamada

### Mute/unmute microfone

```javascript
function toggleMute(localStream) {
  const audioTrack = localStream.getAudioTracks()[0];
  if (audioTrack) {
    audioTrack.enabled = !audioTrack.enabled;
    return audioTrack.enabled; // true = unmuted
  }
}
```

### Câmera on/off

```javascript
function toggleCamera(localStream) {
  const videoTrack = localStream.getVideoTracks()[0];
  if (videoTrack) {
    videoTrack.enabled = !videoTrack.enabled;
    return videoTrack.enabled; // true = camera on
  }
}
```

### Troca de dispositivo (câmera/microfone)

```javascript
async function switchDevice(peerConnection, localStream, deviceId, kind) {
  const constraints = kind === "video"
    ? { video: { deviceId: { exact: deviceId } } }
    : { audio: { deviceId: { exact: deviceId } } };

  const newStream = await navigator.mediaDevices.getUserMedia(constraints);
  const newTrack = newStream.getTracks()[0];

  // Substituir track na PeerConnection
  const sender = peerConnection.getSenders().find(
    (s) => s.track && s.track.kind === kind
  );

  if (sender) {
    await sender.replaceTrack(newTrack);
  }

  // Parar track antigo
  const oldTrack = localStream.getTracks().find((t) => t.kind === kind);
  if (oldTrack) {
    localStream.removeTrack(oldTrack);
    oldTrack.stop();
  }
  localStream.addTrack(newTrack);
}
```

### Upgrade áudio → vídeo

```javascript
async function upgradeToVideo(peerConnection, localStream) {
  const videoStream = await navigator.mediaDevices.getUserMedia({
    video: { width: 640, height: 480 },
  });
  const videoTrack = videoStream.getVideoTracks()[0];

  peerConnection.addTrack(videoTrack, localStream);
  localStream.addTrack(videoTrack);

  // Renegociação automática via onnegotiationneeded
}
```

## VI. Layout do Vídeo no Lobby

### Chamada de áudio

```
┌─────────────────────────────────────────────────────────┐
│ [■] Sessão P2P — rodrigo ↔ maria          [─][□][✕]    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │            📞 Chamada de Áudio                  │    │
│  │                                                 │    │
│  │         ┌──────────┐    ┌──────────┐            │    │
│  │         │ rodrigo  │    │  maria   │            │    │
│  │         │   🔊     │    │   🔊     │            │    │
│  │         └──────────┘    └──────────┘            │    │
│  │                                                 │    │
│  │         Duração: 05:23                          │    │
│  └─────────────────────────────────────────────────┘    │
│                                                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │  [🔇 Mute]  [📹 Ligar Vídeo]  [🔴 Encerrar]     │  │
│  └───────────────────────────────────────────────────┘  │
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │ chat do lobby continua disponível...            │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

### Chamada de vídeo

```
┌─────────────────────────────────────────────────────────┐
│ [■] Sessão P2P — rodrigo ↔ maria          [─][□][✕]    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │                                                 │    │
│  │    ┌─────────────────────────────────────┐      │    │
│  │    │                                     │      │    │
│  │    │          maria (vídeo remoto)        │      │    │
│  │    │                                     │      │    │
│  │    │                                     │      │    │
│  │    │                           ┌───────┐ │      │    │
│  │    │                           │ eu    │ │      │    │
│  │    │                           │(local)│ │      │    │
│  │    │                           └───────┘ │      │    │
│  │    └─────────────────────────────────────┘      │    │
│  │                                                 │    │
│  └─────────────────────────────────────────────────┘    │
│                                                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │  [🔇 Mute]  [📷 Câmera Off]  [🔴 Encerrar]      │  │
│  │                                                   │  │
│  │  Duração: 03:42  |  Qualidade: Boa ●●●○           │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Picture-in-Picture

Para que o usuário possa voltar ao chat principal enquanto mantém a chamada:

```javascript
async function enablePiP(videoElement) {
  if (document.pictureInPictureEnabled) {
    await videoElement.requestPictureInPicture();
  }
}
```

O vídeo remoto pode ser destacado em PiP nativo do navegador. Isso permite
voltar à aba do chat principal sem perder a chamada de vídeo.

## VII. Qualidade Adaptativa

WebRTC ajusta automaticamente a qualidade baseado nas condições de rede:

### Bandwidth estimation

```javascript
// Monitorar estatísticas da conexão
const stats = await peerConnection.getStats();

stats.forEach((report) => {
  if (report.type === "outbound-rtp" && report.kind === "video") {
    // Bits por segundo sendo enviados
    const bitrate = report.bytesSent * 8; // simplificado
  }

  if (report.type === "candidate-pair" && report.nominated) {
    // RTT da conexão
    const rtt = report.currentRoundTripTime;
    // Bandwidth disponível estimado
    const bandwidth = report.availableOutgoingBitrate;
  }
});
```

### Indicador de qualidade na UI

```
Qualidade baseada no RTT e packet loss:

  Excelente ●●●●  — RTT < 50ms, loss < 1%
  Boa       ●●●○  — RTT < 150ms, loss < 3%
  Regular   ●●○○  — RTT < 300ms, loss < 5%
  Ruim      ●○○○  — RTT > 300ms ou loss > 5%
```

### Ajuste de resolução via constraints

```javascript
async function adjustQuality(sender, quality) {
  const params = sender.getParameters();

  if (!params.encodings || params.encodings.length === 0) {
    params.encodings = [{}];
  }

  switch (quality) {
    case "high":
      params.encodings[0].maxBitrate = 1500000; // 1.5 Mbps
      break;
    case "medium":
      params.encodings[0].maxBitrate = 500000;  // 500 Kbps
      break;
    case "low":
      params.encodings[0].maxBitrate = 150000;  // 150 Kbps
      break;
  }

  await sender.setParameters(params);
}
```

## VIII. Tratamento de Erros de Mídia

### Permissão negada

```javascript
try {
  const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
} catch (error) {
  if (error.name === "NotAllowedError") {
    // Usuário negou permissão
    showMessage("Permissão de microfone necessária para chamada de áudio.");
  } else if (error.name === "NotFoundError") {
    // Dispositivo não encontrado
    showMessage("Nenhum microfone detectado.");
  } else if (error.name === "NotReadableError") {
    // Dispositivo em uso por outra aplicação
    showMessage("Microfone em uso por outra aplicação.");
  }
}
```

### Dispositivo desconectado durante chamada

```javascript
navigator.mediaDevices.ondevicechange = async () => {
  const devices = await navigator.mediaDevices.enumerateDevices();
  // Verificar se dispositivos ativos ainda existem
  // Se não, notificar e tentar fallback
};
```

## IX. Comparação com Voice Chat do mIRC

| Aspecto | mIRC Voice Chat | RetroHexChat P2P |
|---------|-----------------|-------------------|
| Protocolo | Proprietário / plugins | WebRTC (padrão W3C) |
| Vídeo | Não suportado | Suportado nativamente |
| Codecs | Limitados | Opus, VP8, H.264, VP9 |
| Criptografia | Nenhuma | DTLS/SRTP obrigatório |
| NAT | Problemático | ICE automático |
| Qualidade | Fixa | Adaptativa (bandwidth estimation) |
| Setup | Plugin + configuração | Zero config (API do browser) |
| Picture-in-Picture | Não existia | PiP nativo do browser |
