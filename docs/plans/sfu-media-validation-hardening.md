# SFU media validation hardening

> Objetivo: expor problemas reais do media server/SFU sem depender primeiro de
> varios browsers. Este documento mapeia referencias locais em `~/src`, o que
> ja foi validado no Retro Hex Chat e o loop de testes que ainda falta fechar.
>
> Criado em: 2026-07-14.

## Resultado atual

Dois problemas reais ja foram expostos pela bateria headless:

| Problema | Evidencia | Correcao |
|---|---|---|
| PLI do subscriber nao chegava ao publisher correto | Teste `routes subscriber PLI feedback to the video publisher` falhava antes do fix | Commit `e26071ed Fix SFU keyframe request routing` |
| Joins concorrentes podiam duplicar transceivers `sendonly` para o mesmo peer | Teste de 4 participantes concorrentes mostrou forma de transceiver maior que o esperado | Commit `594e3b43 Stress SFU media negotiation edge cases` |

O harness atual fica em:

| Arquivo | Papel |
|---|---|
| `apps/retro_hex_chat/test/retro_hex_chat/group_call/sfu_media_path_test.exs` | Peers WebRTC sinteticos com `ExWebRTC`, sem browser, exercitando o fluxo real do servidor |
| `apps/retro_hex_chat/test/retro_hex_chat/group_call/rtp_forwarder_test.exs` | Regras puras de RTP forwarding, duplicados e rollover |
| `apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs` | Lifecycle de room/participant/track, policy, reconnect, moderacao e metadata |
| `apps/retro_hex_chat_web/assets/test/hooks/group_call/group_call_webrtc_hook.test.js` | Comportamento do hook de browser sem midia real |

## Referencias locais

| Referencia | Arquivo local | O que extrair |
|---|---|---|
| Fishjam/Membrane basic integration | `/Users/rodrigo/src/fishjam-cloud-membrane_rtc_engine/ex_webrtc/integration_test/test_videoroom/test/integration/basic_test.exs` | Join gradual, join all-at-once, combinacoes com/sem microfone/camera, telemetria |
| Fishjam/Membrane no-video | `/Users/rodrigo/src/fishjam-cloud-membrane_rtc_engine/ex_webrtc/integration_test/test_videoroom/test/integration/no_video_test.exs` | Todos entram sem video, audio continua fluindo e video fica zerado |
| Fishjam/Membrane packet loss | `/Users/rodrigo/src/fishjam-cloud-membrane_rtc_engine/ex_webrtc/integration_test/test_videoroom/test/integration/containerised_test.exs` | Degradacao em um peer e comparacao de stats entre sender/receiver |
| Fishjam/Membrane metadata | `/Users/rodrigo/src/fishjam-cloud-membrane_rtc_engine/ex_webrtc/integration_test/test_videoroom/test/integration/metadata_test.exs` | Metadata de peer/track atualizada durante ou logo apos adicionar track |
| Fishjam/Membrane simulcast | `/Users/rodrigo/src/fishjam-cloud-membrane_rtc_engine/ex_webrtc/integration_test/test_videoroom/test/integration/simulcast_test.exs` | RID/variant switching e validacao de stats por variante |
| ExWebRTC apps headless broadcaster | `/Users/rodrigo/src/elixir-webrtc-apps/broadcaster/headless_client.js` | Script isolado contra servidor real, com browser fake e encodings simulcast |
| ExWebRTC apps Nexus | `/Users/rodrigo/src/elixir-webrtc-apps/nexus/assets/js/home.js` e `/Users/rodrigo/src/elixir-webrtc-apps/nexus/lib/nexus/peer.ex` | Servidor como offerer, ICE restart e PeerServer como dono do `PeerConnection` |
| live_ex_webrtc publisher | `/Users/rodrigo/src/live_ex_webrtc/assets/publisher.js` | Stats browser-side, packet loss calculado e simulcast browser-side |

## Cobertura ja implementada

| Cenario | Referencia | Teste no Retro | Status |
|---|---|---|---|
| Dois peers, video RTP bilateral | `basic_test.exs` | `forwards RTP video both ways between two synthetic WebRTC clients` | Concluido |
| PLI do viewer para publisher | Nexus `Peer` + RTCP flow | `routes subscriber PLI feedback to the video publisher` | Concluido |
| Terceiro participante entra depois | `basic_test.exs` join gradual | `keeps media fanout healthy when a third participant joins late` | Concluido |
| Quatro participantes entram ao mesmo tempo | `basic_test.exs` all-at-once | `keeps the transceiver graph sane when four participants join concurrently` | Concluido para sinalizacao/topologia |
| Um participante sem camera | `basic_test.exs` mixed devices | `keeps video routes healthy when one participant joins without camera` | Concluido |
| Todos audio-only, gradual e concorrente | `no_video_test.exs` | `keeps audio-only routes healthy when participants gradually join and leave`; `keeps audio-only routing sane when four participants join concurrently` | Concluido; expôs normalizacao de IDs de track |
| Participante sai e rotas restantes seguem vivas | `basic_test.exs` leave gradual | `keeps remaining media routes healthy after a participant leaves` | Concluido |
| Offer/ICE restart explicito | Nexus ICE restart pattern | `keeps media alive after an explicit offer request with ICE restart` | Concluido |

## Backlog priorizado

### P0. Todos audio-only - concluido em 2026-07-14

Referencia:

- `/Users/rodrigo/src/fishjam-cloud-membrane_rtc_engine/ex_webrtc/integration_test/test_videoroom/test/integration/no_video_test.exs`

O que testar:

- 3 ou 4 participantes entram com `media: %{audio: true, video: false}`.
- Variante gradual: entra um por vez, cada participante recebe audio dos que ja
  estavam e nenhum video.
- Variante concorrente: todos entram juntos, todos recebem audio dos outros e
  nenhum video.
- Ao sair um participante, audio continua roteando entre os restantes.

Aceite:

- Nenhum `:missing_local_track` inesperado para audio.
- `assert_audio_rtp_counts/1` passa entre todos os pares esperados.
- `refute_rtp_for(names, :video)` passa depois de bursts de video tentados por
  peers sem camera.
- Server stats mostram `subscriber_count` coerente e sem tracks inbound de video
  para publishers audio-only.

Implementacao sugerida:

- Estender `sfu_media_path_test.exs`.
- Reusar `SyntheticPeer` com `media` configuravel.
- Adicionar helper `assert_no_remote_track_count(name, :video, timeout)`.

Resultado:

- Implementados cenarios gradual/leave e concorrente.
- Bug exposto: tracks sinteticas com IDs numericos eram encaminhadas via RTP,
  mas falhavam na persistencia como `webrtc_track_id` string.
- Fix: `PeerServer` normaliza `webrtc_track_id` e `stream_id` para string no
  payload enviado ao `RoomServer`, mantendo o ID bruto no caminho RTP.

### P0. Camera -> screen share -> camera mantendo RTP

Referencia:

- `/Users/rodrigo/src/fishjam-cloud-membrane_rtc_engine/ex_webrtc/integration_test/test_videoroom/test/integration/metadata_test.exs`
- `apps/retro_hex_chat_web/assets/js/hooks/group_call/group_call_webrtc_hook.js`
- `apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs`

O que testar:

- Um publisher envia video de camera.
- O mesmo publisher troca o track local de video por outro track sintetico que
  representa screen share.
- O servidor recebe a mudanca de estado/metadata de screen share.
- RTP segue fluindo para subscribers depois da troca.
- Ao voltar para camera, RTP segue fluindo e source volta para `camera`.

Aceite:

- Antes, durante e depois da troca, subscribers recebem pelo menos
  `@min_forwarded_packets`.
- Track metadata/source no runtime fica coerente: `camera -> screen -> camera`.
- Nenhum transceiver extra e criado pela troca; deve ser `replaceTrack`, nao uma
  renegociacao que cria nova m-line.

Implementacao sugerida:

- No `SyntheticPeer`, adicionar mensagem `{:replace_local_video_track, source}`.
- Criar novo `MediaStreamTrack.new(:video, [stream_id])`, substituir no sender
  de video e continuar sequencia RTP.
- Chamar `GroupCall.set_screen_share_state/4` no teste para validar metadata.

### P0. Churn longo de join/leave/rejoin

Referencia:

- `/Users/rodrigo/src/fishjam-cloud-membrane_rtc_engine/ex_webrtc/integration_test/test_videoroom/test/integration/basic_test.exs`

O que testar:

- Rodadas repetidas com 4 participantes:
  - alice/bob/carol entram;
  - bob sai;
  - dave entra;
  - bob reentra;
  - carol sai;
  - todos renegociam.
- Enviar bursts de audio/video depois de cada fase.
- Inspecionar `PeerRegistry`, transceivers e `server_stats`.

Aceite:

- Nenhum peer antigo fica registrado depois de leave.
- `outbound_peer_count` e `subscriber_count` batem com o numero de peers vivos.
- A forma de transceivers bate com `1 recvonly audio`, `1 recvonly video`,
  `N-1 sendonly audio`, `N-1 sendonly video`.
- RTP continua chegando aos peers vivos depois de cada etapa.

Implementacao sugerida:

- Criar teste unico com loop curto, nao property.
- Reusar `assert_eventually_server_transceiver_shape/3`.
- Adicionar helper `refute_registered_peer(room_id, participant_id)`.

### P1. RTP impairment: buracos, duplicados, reorder e burst irregular

Referencia:

- `/Users/rodrigo/src/fishjam-cloud-membrane_rtc_engine/ex_webrtc/integration_test/test_videoroom/test/integration/containerised_test.exs`
- `apps/retro_hex_chat/test/retro_hex_chat/group_call/rtp_forwarder_test.exs`

O que testar:

- Enviar RTP com sequencias puladas.
- Enviar duplicados.
- Enviar pacote fora de ordem.
- Enviar burst irregular com pequenas pausas.

Aceite:

- Duplicados nao sao encaminhados em dobro.
- Rollover continua aceito.
- Buracos nao travam forwarding futuro.
- Stats nao ficam negativos ou incoerentes.

Implementacao sugerida:

- No `SyntheticPeer`, aceitar `{:send_rtp_sequence, kind, sequences}`.
- No media path, validar eventos de RTP recebidos pelos subscribers.
- No `RTPForwarder`, manter testes puros para edge cases de sequencia.

### P1. Stats ponta a ponta

Referencia:

- `/Users/rodrigo/src/fishjam-cloud-membrane_rtc_engine/ex_webrtc/integration_test/test_videoroom/test/integration/basic_test.exs`
- `/Users/rodrigo/src/live_ex_webrtc/assets/publisher.js`

O que testar:

- Publisher envia X pacotes.
- Server stats inbound aumentam para o publisher.
- Server stats outbound aumentam para cada subscriber.
- Subscribers sinteticos recebem pacote suficiente para confirmar fanout.

Aceite:

- `packets_received` inbound do publisher cresce apos burst.
- `packets_sent` outbound dos subscribers cresce apos burst.
- Contadores nao regridem em amostras sucessivas.

Implementacao sugerida:

- Criar helper `sample_server_rtp_stats(token, participant_id)`.
- Comparar delta antes/depois de burst, sem depender de valor exato.

### P1. ICE candidate stale/late durante leave e restart

Referencia:

- Nexus/client ICE flow em `/Users/rodrigo/src/elixir-webrtc-apps/nexus/assets/js/home.js`
- Teste atual `queues ICE candidates that arrive before the SDP answer` em
  `runtime_test.exs`

O que testar:

- Candidate chega antes do answer.
- Candidate chega depois de leave.
- Candidate de uma offer antiga chega depois de `request_offer`.

Aceite:

- Candidate antes do answer e enfileirado e flushado.
- Candidate depois de leave nao derruba processo/teste.
- Candidate stale nao corrompe signaling state.

Implementacao sugerida:

- Parte fica em `runtime_test.exs`.
- Parte pode ficar no `SyntheticPeer`, enviando candidate atrasado apos `leave`.

### P2. Metadata de track imediatamente apos adicionar track

Referencia:

- `/Users/rodrigo/src/fishjam-cloud-membrane_rtc_engine/ex_webrtc/integration_test/test_videoroom/test/integration/metadata_test.exs`

O que testar:

- Track e anunciada.
- Metadata/source/mute e atualizado imediatamente.
- Subscriber que entra logo depois recebe metadata final, nao estado antigo.

Aceite:

- Queries e summary mostram metadata final.
- Eventos de channel chegam na ordem ou com estado consolidado correto.

Implementacao sugerida:

- `runtime_test.exs` para estado persistido.
- Channel test para evento consolidado.

### P2. Browser-real smoke script

Referencia:

- `/Users/rodrigo/src/elixir-webrtc-apps/broadcaster/headless_client.js`

O que testar:

- Script opcional que sobe um browser fake media contra servidor real/local.
- Dois ou tres clients entram em uma chamada real.
- Coleta `getStats()` e verifica frames/bytes crescendo.

Aceite:

- Nao entra no gate rapido do `mix test`.
- Rodavel sob demanda para validar decode/render real, quando o headless BEAM
  nao for suficiente.

Implementacao sugerida:

- `scripts/group_call_sfu_probe.mjs`.
- Parametros por env: `BASE_URL`, `CHANNEL`, `USERS`, `DURATION_MS`.
- Usar fake device/fake UI quando browser suportar.

### P3. Simulcast/RID

Referencia:

- `/Users/rodrigo/src/fishjam-cloud-membrane_rtc_engine/ex_webrtc/integration_test/test_videoroom/test/integration/simulcast_test.exs`
- `/Users/rodrigo/src/elixir-webrtc-apps/broadcaster/headless_client.js`
- `/Users/rodrigo/src/live_ex_webrtc/assets/publisher.js`

Estado atual:

- O dominio tem campo `rid`, mas o SFU atual nao implementa selecao de variante
  nem policy de encodings.
- Portanto, isso e feature futura, nao lacuna imediata de regressao.

O que testar quando existir suporte:

- Publisher envia `h/m/l`.
- Subscriber recebe a variante alvo.
- Desabilitar `h` troca para `m`.
- Escolher `l` e voltar para `m` altera stats/frames de forma coerente.

## Loop de execucao

Para cada item do backlog:

1. Ler a referencia local indicada.
2. Escrever ou ampliar teste menor que exponha o risco no Retro.
3. Rodar o teste antes do fix quando possivel e registrar a falha no comentario
   de progresso.
4. Corrigir o menor ponto necessario no runtime.
5. Rodar:

```bash
rtk mix format <arquivos alterados>
rtk mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/sfu_media_path_test.exs
rtk sh -c 'for i in 1 2 3; do mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/sfu_media_path_test.exs || exit $?; done'
rtk mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs apps/retro_hex_chat/test/retro_hex_chat/group_call/rtp_forwarder_test.exs
rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs
```

6. Atualizar este documento: marcar status, escrever bug exposto ou justificar
   por que o teste so aumentou cobertura.
7. Fazer commit pequeno com teste + fix.

## Ordem sugerida

| Ordem | Item | Motivo |
|---:|---|---|
| 1 | Todos audio-only | Referencia direta, alto sinal, simples de expor |
| 2 | Camera -> screen share -> camera | Mais proximo do sintoma de imagem remota congelada |
| 3 | Churn longo | Melhor chance de achar race de renegociacao/processos |
| 4 | RTP impairment | Exercita tolerancia a rede ruim sem browser |
| 5 | Stats ponta a ponta | Ajuda a diagnosticar assimetria publisher/subscriber |
| 6 | ICE stale/late | Hardening de signaling sob corrida |
| 7 | Browser-real smoke script | Complemento para decode/render real |
| 8 | Simulcast/RID | So quando a feature existir |

## Criterio de conclusao

Este plano pode ser considerado concluido quando:

- Todos os itens P0 e P1 estiverem implementados ou explicitamente descartados
  com justificativa tecnica.
- O harness SFU passar 3 vezes seguidas.
- A bateria relacionada de runtime/forwarder/channel passar.
- `mix test` completo passar antes do ultimo commit de hardening.
- O documento estiver atualizado com os bugs efetivamente expostos e os commits
  que corrigiram cada um.
