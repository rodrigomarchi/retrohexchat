# WebRTC media stability profiles

> Objetivo: padronizar codecs, constraints e limites conservadores de audio e
> video para P2P e conferencia, priorizando estabilidade sobre qualidade maxima.
>
> Criado em: 2026-07-14.
> Primeira iteracao implementada em: 2026-07-14.

## Motivacao

O Retro Hex Chat agora tem duas superficies WebRTC reais:

- P2P 1:1, com audio/video, screen share, file transfer, game data channel,
  stats e presets manuais de qualidade.
- Conferencia de canal via SFU, com audio/video, screen share, moderacao,
  stats por participante e smoke browser-real com frames decodificados.

O risco atual nao e falta de funcionalidade. O risco e cada caminho capturar ou
enviar midia com parametros implicitos demais:

- camera hoje pede `640x480 ideal`, sem limite de fps;
- audio hoje nao pede mono nem `autoGainControl`;
- screen share usa `video: true`, permitindo captura enorme em telas grandes;
- P2P tem cap manual de bitrate, mas nao aplica um perfil conservador ao entrar;
- conferencia nao aplica cap de bitrate/fps no sender browser;
- P2P prefere H.264 no browser, enquanto conferencia/SFU usa VP8 no backend.

Para este produto, a decisao de produto deve ser clara: chamada estavel e melhor
que chamada bonita que congela. A qualidade default deve ser conservadora. O
controle manual de qualidade fica fora da UI por enquanto; pode voltar depois
quando houver telemetria suficiente para justificar presets dinamicos.

## Status da primeira iteracao

Concluido em 2026-07-14:

- botoes visiveis de preset manual removidos do P2P/lobby;
- perfil `stable` aplicado por padrao a P2P e conferencia;
- screen share limitado e com fallback para captura sem constraints quando o
  browser rejeita o perfil conservador;
- `RTCRtpSender.setParameters()` usado para limitar bitrate/fps dos senders;
- testes adicionados para constraints, hints, caps de sender e ausencia de
  preset manual no markup.

## Pesquisa externa

| Fonte | Ponto usado no plano |
|---|---|
| MDN WebRTC codecs: https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Formats/WebRTC_codecs | Opus e codecs baseline de WebRTC; VP8 e H.264 sao amplamente suportados |
| RFC 7742: https://www.rfc-editor.org/rfc/rfc7742 | Browsers WebRTC devem implementar VP8 e H.264 Constrained Baseline |
| RFC 7874: https://www.rfc-editor.org/rfc/rfc7874 | Opus e codec obrigatorio/recomendado para audio WebRTC; G.711 e fallback |
| MDN constraints: https://developer.mozilla.org/en-US/docs/Web/API/Media_Capture_and_Streams_API/Constraints | Uso de `ideal`, `max`, constraints avancadas e risco de `OverconstrainedError` |
| MDN setParameters: https://developer.mozilla.org/en-US/docs/Web/API/RTCRtpSender/setParameters | `RTCRtpSender.setParameters()` permite limitar `maxBitrate` por encoding |
| MDN setCodecPreferences: https://developer.mozilla.org/en-US/docs/Web/API/RTCRtpTransceiver/setCodecPreferences | Preferencia de codec deve ser aplicada por transceiver, com fallback |
| Mozilla setCodecPreferences: https://blog.mozilla.org/webrtc/cross-browser-support-for-choosing-webrtc-codecs/ | `setCodecPreferences` influencia negociacao, mas nao deve ser tratado como "forcar codec" simplista |
| LiveKit bitrate guide: https://livekit.com/webrtc/bitrate-guide | 640x360/30fps por volta de 400 kbps; boa referencia para cap conservador |
| Daily adaptive bitrate: https://docs.daily.co/docs/guides/architecture-and-monitoring/adaptive-bitrate | Camadas pequenas comuns: 240p/15fps/200 kbps e 180p/15fps/100 kbps |
| BlogGeek video quality: https://bloggeek.me/tweaking-webrtc-video-quality-unpacking-bitrate-resolution-and-frame-rates/ | Reduzir fps/resolucao de tiles melhora estabilidade e CPU em chamadas multiusuario |

## Estado atual no codigo

| Area | Arquivo | Estado atual |
|---|---|---|
| Constraints compartilhadas | `apps/retro_hex_chat_web/assets/js/lib/p2p/media.js` | `getAudioConstraints/1` usa echo cancellation e noise suppression; `getVideoConstraints/1` pede `640x480 ideal` sem fps |
| Presets P2P | `apps/retro_hex_chat_web/assets/js/lib/p2p/media.js` | `high=1.5 Mbps`, `medium=500 kbps`, `low=150 kbps`; so aplicados quando UI envia preset |
| Codec P2P | `apps/retro_hex_chat_web/assets/js/lib/p2p/media.js` | `setCodecPreferences/1` ordena H.264 antes de VP8 para video e Opus antes de outros para audio |
| P2P hook | `apps/retro_hex_chat_web/assets/js/lib/p2p/rtc_media_hook_factory.js` | Usa constraints compartilhadas ao iniciar chamada, ligar audio/video, trocar camera e aceitar upgrade |
| Conferencia hook | `apps/retro_hex_chat_web/assets/js/hooks/group_call/group_call_webrtc_hook.js` | Usa constraints compartilhadas, mas nao aplica cap de bitrate nem codec preferences no browser |
| Conferencia prejoin | `apps/retro_hex_chat_web/assets/js/hooks/group_call/group_call_prejoin_hook.js` | Preview usa as mesmas constraints compartilhadas |
| Screen share P2P | `apps/retro_hex_chat_web/assets/js/lib/p2p/rtc_media_hook_factory.js` | Usa `acquireDisplayMedia({ video: true, audio: false })` |
| Screen share conferencia | `apps/retro_hex_chat_web/assets/js/hooks/group_call/group_call_webrtc_hook.js` | Usa `getDisplayMedia({ video: true, audio: false })` |
| SFU backend | `apps/retro_hex_chat/lib/retro_hex_chat/group_call/peer_server.ex` | Anuncia `@audio_codecs [:opus]` e `@video_codecs [:vp8]` |
| RTP munger SFU | `apps/retro_hex_chat/lib/retro_hex_chat/group_call/rtp_forwarder.ex` | Usa clocks Opus 48 kHz e VP8 90 kHz |

## Decisoes recomendadas

### D1. Audio default

Usar Opus, mono, voz e bitrate baixo.

| Campo | Valor recomendado |
|---|---|
| Codec | Opus |
| Channel count | 1 canal, `ideal: 1` |
| Echo cancellation | `true` |
| Noise suppression | `true` |
| Auto gain control | `true` |
| Sender cap default | 40 kbps |
| Sender cap low | 32 kbps |
| `contentHint` | `speech` |

Motivo:

- voz de chat nao precisa stereo;
- menos banda e menos CPU ajudam P2P e conferencia;
- Opus e o codec certo para WebRTC moderno;
- G.711 deve permanecer so como fallback implicito do browser, nao como escolha
  de produto.

### D2. Camera default

Usar camera pequena, widescreen e fps baixo.

| Perfil | Captura | FPS | Video cap | Uso |
|---|---:|---:|---:|---|
| `stable` | 640x360 | 15 | 400 kbps | Default P2P e conferencia |
| `low` | 480x270 | 15 | 250 kbps | Manual ou fallback de rede/CPU |
| `high` | 640x360 ou 640x480 | 24-30 | 700 kbps | Opcional manual, nunca default |

Motivo:

- 640x360 encaixa melhor em tiles que 640x480;
- 15fps e suficiente para conversa e reduz CPU, encode e banda;
- em SFU, cada participante pode receber varios videos; default precisa ser
  adequado para N participantes, nao apenas 1:1;
- o browser ainda pode adaptar abaixo disso quando precisar.

### D3. Screen share

Screen share e diferente de camera: texto precisa detalhe, mas nao precisa fps
alto.

| Campo | Valor recomendado |
|---|---|
| Captura maxima | 1280x720 |
| FPS | 5-10 |
| Video cap | 800 kbps default, 1 Mbps max |
| Audio | `false` por enquanto |
| `contentHint` | `detail` |

Motivo:

- `video: true` pode capturar tela 4K e estourar CPU/banda;
- para tela estatica, fps alto e desperdicio;
- `contentHint = "detail"` ajuda o encoder a preservar texto quando suportado.

### D4. Codec de video

| Superficie | Recomendacao |
|---|---|
| P2P | Manter H.264 preferido, VP8 fallback |
| Conferencia/SFU | Manter VP8 + Opus por enquanto |
| Futuro | Avaliar H.264 no SFU somente com bateria dedicada |

Motivo:

- P2P ja prefere H.264 e isso e razoavel para 1:1, principalmente por suporte
  amplo e hardware acceleration em muitos devices;
- SFU atual ja esta testado em VP8, usa `Munger.new(:vp8, 90_000)` e nao faz
  transcoding;
- adicionar H.264 no SFU envolve payload/packetization/profile e precisa de
  testes de interoperabilidade antes de virar producao;
- VP9/AV1 nao devem entrar agora: melhor compressao, mas maior variabilidade de
  suporte, CPU e negociacao.

### D5. Presets de qualidade

Os nomes podem continuar iguais, mas os valores devem ficar mais conservadores.

| Preset | Video | Audio | Observacao |
|---|---:|---:|---|
| low | 250 kbps | 32 kbps | Bom fallback e redes fracas |
| medium | 400 kbps | 40 kbps | Deve virar default implicito |
| high | 700 kbps | 64 kbps | Manual, para P2P ou rede boa |

Opcao de produto:

- Se quisermos preservar `high=1.5 Mbps`, renomear mentalmente para futuro
  `hd` e nao usar como default.
- Para estabilidade, `medium` precisa ser suficiente e aplicado automaticamente
  ao iniciar a chamada.

## Implementacao proposta

### P0. Centralizar perfis em `media.js`

Adicionar constantes exportadas:

```js
export const MEDIA_PROFILE_NAMES = {
  stable: "stable",
  low: "low",
  high: "high",
  screen: "screen",
};

export const MEDIA_PROFILES = {
  stable: {
    audio: {
      echoCancellation: true,
      noiseSuppression: true,
      autoGainControl: true,
      channelCount: { ideal: 1 },
    },
    camera: {
      width: { ideal: 640 },
      height: { ideal: 360 },
      frameRate: { ideal: 15, max: 15 },
      facingMode: "user",
    },
    send: {
      audioBitrate: 40_000,
      videoBitrate: 400_000,
      maxFramerate: 15,
    },
    hints: {
      audio: "speech",
      video: "motion",
    },
  },
  low: {
    camera: {
      width: { ideal: 480 },
      height: { ideal: 270 },
      frameRate: { ideal: 15, max: 15 },
      facingMode: "user",
    },
    send: {
      audioBitrate: 32_000,
      videoBitrate: 250_000,
      maxFramerate: 15,
    },
  },
  high: {
    camera: {
      width: { ideal: 640 },
      height: { ideal: 360 },
      frameRate: { ideal: 24, max: 30 },
      facingMode: "user",
    },
    send: {
      audioBitrate: 64_000,
      videoBitrate: 700_000,
      maxFramerate: 30,
    },
  },
  screen: {
    display: {
      width: { max: 1280 },
      height: { max: 720 },
      frameRate: { ideal: 5, max: 10 },
    },
    send: {
      videoBitrate: 800_000,
      maxFramerate: 10,
    },
    hints: {
      video: "detail",
    },
  },
};
```

Notas:

- Nao usar `exact` para resolucao/fps.
- Usar `max` com cuidado e ter fallback quando o browser retornar
  `OverconstrainedError`.
- Device id continua sendo adicionado por `_withDevice/2`.

### P1. Atualizar constraints compartilhadas

Exemplo:

```js
export function getAudioConstraints(deviceId = "", profileName = "stable") {
  const profile = MEDIA_PROFILES[profileName] || MEDIA_PROFILES.stable;
  const constraints = { ...MEDIA_PROFILES.stable.audio, ...(profile.audio || {}) };
  return deviceId ? { ...constraints, deviceId: { exact: deviceId } } : constraints;
}

export function getVideoConstraints(deviceId = "", profileName = "stable") {
  const profile = MEDIA_PROFILES[profileName] || MEDIA_PROFILES.stable;
  const constraints = profile.camera || MEDIA_PROFILES.stable.camera;
  return deviceId ? { ...constraints, deviceId: { exact: deviceId } } : constraints;
}
```

Pontos de cuidado:

- manter assinatura compativel com chamadas existentes;
- se adicionarmos segundo parametro, atualizar testes com chamadas antigas e
  novas;
- preview e chamada passam a usar a mesma captura conservadora.

### P2. Aplicar caps de sender automaticamente

Criar helper unico:

```js
export async function applySenderProfile(sender, profileName = "stable") {
  if (!sender?.track || !sender.setParameters) return;

  const profile = MEDIA_PROFILES[profileName] || MEDIA_PROFILES.stable;
  const params = sender.getParameters?.() || {};
  if (!params.encodings || params.encodings.length === 0) params.encodings = [{}];

  const send = profile.send || MEDIA_PROFILES.stable.send;
  const maxBitrate = sender.track.kind === "video" ? send.videoBitrate : send.audioBitrate;

  for (const encoding of params.encodings) {
    if (maxBitrate) encoding.maxBitrate = maxBitrate;
    if (sender.track.kind === "video" && send.maxFramerate) {
      encoding.maxFramerate = send.maxFramerate;
    }
  }

  await sender.setParameters(params);
}

export async function applyMediaProfile(pc, profileName = "stable") {
  if (!pc?.getSenders) return;
  await Promise.all(pc.getSenders().map((sender) => applySenderProfile(sender, profileName)));
}
```

Onde chamar:

- P2P `_startCall` depois de `addMediaTracks`;
- P2P `_enableAudio`, `_enableVideo` e upgrade depois de `addTrack`;
- P2P `switchAudioInput` e `switchVideoInput` depois de `replaceTrack`;
- P2P screen share depois de `replaceTrack`;
- conferencia `_ensureLocalTracks` depois de `pc.addTrack`;
- conferencia screen share depois de `replaceTrack`;
- conferencia retorno de screen share para camera.

### P3. Aplicar `contentHint`

Exemplo:

```js
export function applyTrackHints(stream, profileName = "stable") {
  const profile = MEDIA_PROFILES[profileName] || MEDIA_PROFILES.stable;

  for (const track of stream?.getAudioTracks?.() || []) {
    if ("contentHint" in track) track.contentHint = profile.hints?.audio || "speech";
  }

  for (const track of stream?.getVideoTracks?.() || []) {
    if ("contentHint" in track) track.contentHint = profile.hints?.video || "motion";
  }
}
```

Screen share deve usar:

```js
if ("contentHint" in track) track.contentHint = "detail";
```

### P4. Screen share com constraints explicitas

Adicionar helper:

```js
export function getScreenShareConstraints(profileName = "screen") {
  const profile = MEDIA_PROFILES[profileName] || MEDIA_PROFILES.screen;
  return {
    video: profile.display || MEDIA_PROFILES.screen.display,
    audio: false,
  };
}
```

Substituir:

```js
getDisplayMedia({ video: true, audio: false })
```

por:

```js
getDisplayMedia(getScreenShareConstraints())
```

Fallback:

```js
try {
  return await navigator.mediaDevices.getDisplayMedia(getScreenShareConstraints());
} catch (error) {
  if (error?.name === "OverconstrainedError") {
    return await navigator.mediaDevices.getDisplayMedia({ video: true, audio: false });
  }
  throw error;
}
```

### P5. Rebaixar presets manuais

Atualizar `BITRATE_PRESETS`:

```js
export const BITRATE_PRESETS = {
  high: { video: 700_000, audio: 64_000 },
  medium: { video: 400_000, audio: 40_000 },
  low: { video: 250_000, audio: 32_000 },
};
```

Depois, avaliar UI:

- mostrar preset ativo;
- default implicito deve ser `medium` ou `stable`;
- clique em `High` deve aplicar cap, nao liberar qualidade ilimitada.

### P6. Codec policy

P2P:

- manter `setCodecPreferences`;
- ajustar comentario para refletir realidade: preferencia de negociacao, nao
  garantia absoluta;
- manter teste para H.264 antes de VP8;
- adicionar teste que Opus fica antes dos demais codecs de audio;
- preservar codecs auxiliares associados se houver RTX/RED/FEC.

Conferencia:

- nao adicionar H.264 no SFU neste plano;
- documentar que `PeerServer` permanece VP8/Opus;
- criar tarefa futura para H.264 SFU so depois de testes de packetization,
  profile-level-id, PLI/keyframe e browser interop.

### P7. Fallback de constraints

Adicionar fallback so quando necessario.

Fluxo recomendado:

1. tentar perfil `stable`;
2. em `OverconstrainedError`, tentar `low`;
3. se ainda falhar, tentar constraints minimas atuais;
4. se falhar, manter erro ja existente.

Exemplo:

```js
export async function acquireMediaWithProfile(constraintsForProfile, fallbackProfiles = []) {
  try {
    return await navigator.mediaDevices.getUserMedia(constraintsForProfile("stable"));
  } catch (error) {
    if (error?.name !== "OverconstrainedError") throw error;
  }

  for (const profileName of fallbackProfiles) {
    try {
      return await navigator.mediaDevices.getUserMedia(constraintsForProfile(profileName));
    } catch (error) {
      if (error?.name !== "OverconstrainedError") throw error;
    }
  }

  return await navigator.mediaDevices.getUserMedia(constraintsForProfile("minimal"));
}
```

## Testes planejados

### Unit JS

Arquivo principal:

- `apps/retro_hex_chat_web/assets/test/lib/p2p/media.test.js`

Cobrir:

- `getAudioConstraints()` inclui `autoGainControl`, `channelCount`, echo e noise;
- `getVideoConstraints()` retorna 640x360/15fps no default;
- `getVideoConstraints("", "low")` retorna 480x270/15fps;
- `getScreenShareConstraints()` limita 1280x720/10fps;
- `applySenderProfile()` seta `maxBitrate` e `maxFramerate`;
- `applyTrackHints()` aplica `speech`, `motion`, `detail`;
- `setCodecPreferences()` mantem H.264 antes de VP8 e Opus antes de outros.

### Hook JS

Arquivos:

- `apps/retro_hex_chat_web/assets/test/hooks/group_call/group_call_webrtc_hook.test.js`
- `apps/retro_hex_chat_web/assets/test/hooks/group_call/group_call_prejoin_hook.test.js`
- testes do P2P hook se ja existirem no mesmo padrao.

Cobrir:

- conferencia chama `getUserMedia` com constraints conservadoras;
- prejoin preview usa as mesmas constraints;
- screen share usa `getScreenShareConstraints`;
- P2P aplica sender profile ao iniciar chamada;
- ligar camera depois de audio aplica o mesmo perfil;
- `replaceTrack` de screen share aplica cap/hint correto.

### E2E browser-real sob demanda

Arquivos:

- `e2e/tests/chat-p2p.spec.ts`
- `e2e/tests/chat-group-call.spec.ts`

Cobrir:

- P2P video real ainda conecta e renderiza;
- conferencia ainda troca frames remotos decodificados;
- se o fake media registrar constraints, validar que o browser recebeu perfil
  `stable`;
- stats mostram resolucao/fps dentro do esperado quando o browser reportar
  valores confiaveis.

### Backend/SFU

Arquivos:

- `apps/retro_hex_chat/test/retro_hex_chat/group_call/sfu_media_path_test.exs`
- `apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs`

Cobrir:

- nenhuma mudanca inicial necessaria no SFU backend;
- manter VP8/Opus e testes atuais;
- se futuramente codec policy virar configuravel, adicionar testes antes de
  habilitar qualquer codec novo.

## Ordem de execucao

| Ordem | Bloco | Motivo |
|---:|---|---|
| 1 | Criar `MEDIA_PROFILES` e testes puros | Baixo risco, cria contrato unico |
| 2 | Atualizar `getAudioConstraints`, `getVideoConstraints`, screen constraints | Muda captura real, precisa de testes de hook |
| 3 | Aplicar sender caps em P2P | P2P ja tem infraestrutura de presets |
| 4 | Aplicar sender caps em conferencia | Mais sensivel porque envolve SFU e renegociacao |
| 5 | Ajustar screen share P2P e conferencia | Reduz risco de captura 4K |
| 6 | Atualizar presets UI e ajuda | Produto precisa refletir nova politica |
| 7 | Rodar smoke browser-real P2P + conferencia | Prova que perfil conservador nao quebrou midia |
| 8 | Avaliar codec H.264 no SFU como plano futuro | So depois do baseline estavel |

## Criterios de aceite

O plano esta concluido quando:

- P2P e conferencia usam as mesmas funcoes de constraints;
- camera default e 640x360/15fps ou menor;
- audio default e Opus/voz/mono com cap baixo de sender;
- screen share tem constraints e cap explicitos;
- P2P aplica cap de bitrate ao iniciar, nao apenas quando usuario clica preset;
- conferencia aplica cap de bitrate/fps no sender local;
- P2P continua preferindo H.264 com VP8 fallback;
- SFU continua VP8/Opus sem regressao;
- unit tests JS passam;
- testes de hook passam;
- smoke browser-real P2P e conferencia passam;
- `make ci` passa antes de deploy.

## Riscos e mitigacoes

| Risco | Mitigacao |
|---|---|
| Browser rejeitar constraints com `OverconstrainedError` | fallback `stable -> low -> minimal` |
| `setParameters()` falhar em algum browser | catch com warning/debug, chamada continua |
| `maxFramerate` nao ser honrado | confiar no cap de captura + stats; nao tornar hard failure |
| Screen share ficar borrado | usar `contentHint="detail"` e cap maior que camera |
| P2P perder qualidade percebida | manter preset `high` manual, mas default conservador |
| SFU H.264 parecer simples mas quebrar interoperabilidade | deixar fora deste plano; criar plano futuro dedicado |
| Testes fake media nao refletirem resolucao real | validar constraints por unit/hook e frames por E2E |

## Perguntas abertas

- O preset `high` deve continuar em 1.5 Mbps como opcao manual, ou ja deve ser
  rebaixado para 700 kbps?
- O default do P2P deve ser exatamente igual ao da conferencia (`stable`), ou
  P2P pode usar um default um pouco maior por ser 1:1?
- Screen share deve permitir audio do sistema no futuro, ou manter audio sempre
  desabilitado?
- Devemos expor um seletor "Stable / High" no prejoin da conferencia ou manter
  isso invisivel por enquanto?

## Loop de trabalho sugerido

Para cada bloco:

1. Ler novamente o trecho de codigo tocado.
2. Atualizar testes primeiro quando o contrato for claro.
3. Implementar a menor mudanca.
4. Rodar teste focado.
5. Rodar smoke se a mudanca afetar browser real.
6. Registrar resultado em um `-PROGRESS.md` quando a execucao comecar.
7. Fazer commit pequeno.
8. So deployar depois de `make ci` passar.
