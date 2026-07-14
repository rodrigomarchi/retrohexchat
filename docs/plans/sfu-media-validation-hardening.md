# SFU media validation hardening

> Objetivo: expor problemas reais do media server/SFU sem depender primeiro de
> varios browsers. Este documento mapeia referencias locais em `~/src`, o que
> ja foi validado no Retro Hex Chat e o loop de testes que ainda falta fechar.
>
> Criado em: 2026-07-14.

## Resultado atual

Quatro problemas reais ja foram expostos pela bateria headless:

| Problema | Evidencia | Correcao |
|---|---|---|
| PLI do subscriber nao chegava ao publisher correto | Teste `routes subscriber PLI feedback to the video publisher` falhava antes do fix | Commit `e26071ed Fix SFU keyframe request routing` |
| Joins concorrentes podiam duplicar transceivers `sendonly` para o mesmo peer | Teste de 4 participantes concorrentes mostrou forma de transceiver maior que o esperado | Commit `594e3b43 Stress SFU media negotiation edge cases` |
| Pacotes RTP atrasados que preenchiam gaps pequenos eram descartados | Testes `forwards late packets that fill small sequence gaps once` e `keeps gap cache across RTP sequence rollover` falharam antes do fix | `RTPForwarder` agora mantem cache curta de gaps por midia |
| Metadata inicial de track era descartada | Teste `preserves track metadata supplied with immediate track announcement` falhava antes do fix | `RoomServer.track_added/3` persiste e publica `track_info.metadata` |

O harness atual fica em:

| Arquivo | Papel |
|---|---|
| `apps/retro_hex_chat/test/retro_hex_chat/group_call/sfu_media_path_test.exs` | Peers WebRTC sinteticos com `ExWebRTC`, sem browser, exercitando o fluxo real do servidor |
| `apps/retro_hex_chat/test/retro_hex_chat/group_call/rtp_forwarder_test.exs` | Regras puras de RTP forwarding, duplicados e rollover |
| `apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs` | Lifecycle de room/participant/track, policy, reconnect, moderacao e metadata |
| `apps/retro_hex_chat_web/assets/test/hooks/group_call/group_call_webrtc_hook.test.js` | Comportamento do hook de browser sem midia real |
| `e2e/tests/chat-group-call.spec.ts` | Smoke browser-real com cliente JavaScript, Chromium, SFU local e frames remotos decodificados |

## Camadas de cobertura

O cliente sintetico em Elixir nao substitui o cliente JavaScript real. Ele e
uma sonda controlada para isolar o media server/SFU e o contrato de signaling
sem depender de browser, DOM, permissoes de device, autoplay ou renderizacao.

| Camada | O que prova | O que nao prova |
|---|---|---|
| Harness Elixir com `ExWebRTC` | SFU, renegociacao server-side, transceiver shape, RTP/RTCP, cleanup de peers/tracks, contrato Phoenix/domain | Estado visual do hook, comportamento de `RTCPeerConnection` no browser, autoplay/render, `getStats()` real do browser |
| Testes JS do hook | State machine do cliente, chamadas ao canal, cleanup de streams/tracks, uso de `replaceTrack`/stats no codigo real | Forwarding real de RTP pelo SFU |
| Smoke browser-real sob demanda | Integra SFU + cliente JS + browser engine + decode/render/stats | Nao deve virar gate rapido; serve para diagnostico e regressao de alto nivel |

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

| Cenario | Referencia | Teste no Retro | Camada principal | Status |
|---|---|---|---|---|
| Dois peers, video RTP bilateral | `basic_test.exs` | `forwards RTP video both ways between two synthetic WebRTC clients` | Backend/SFU | Concluido |
| PLI do viewer para publisher | Nexus `Peer` + RTCP flow | `routes subscriber PLI feedback to the video publisher` | Backend/SFU | Concluido |
| Terceiro participante entra depois | `basic_test.exs` join gradual | `keeps media fanout healthy when a third participant joins late` | Backend/SFU | Concluido |
| Quatro participantes entram ao mesmo tempo | `basic_test.exs` all-at-once | `keeps the transceiver graph sane when four participants join concurrently` | Backend/SFU | Concluido para sinalizacao/topologia |
| Um participante sem camera | `basic_test.exs` mixed devices | `keeps video routes healthy when one participant joins without camera` | Backend/SFU | Concluido |
| Todos audio-only, gradual e concorrente | `no_video_test.exs` | `keeps audio-only routes healthy when participants gradually join and leave`; `keeps audio-only routing sane when four participants join concurrently` | Backend/SFU | Concluido; expôs normalizacao de IDs de track |
| Camera -> screen share -> camera | `metadata_test.exs`, hook `replaceTrack`, ExWebRTC `replace_track/3` | `keeps video RTP flowing while replacing camera with screen share and back` | Backend/SFU com contrato usado pelo JS | Concluido |
| Churn join/leave/rejoin | `basic_test.exs`, Nexus `Room`/`Peer` | `keeps media and transceivers coherent through join leave and rejoin churn` | Backend/SFU | Concluido |
| RTP gaps/duplicados/reorder | Fishjam `RTPMunger`, `containerised_test.exs` | `RTPForwarderTest`; `keeps forwarding video RTP through gaps duplicates and reorder` | Backend/SFU | Concluido; expôs cache de gaps ausente |
| Server RTP stats por delta | Fishjam/browser stats, live_ex_webrtc `processStats` | `reports monotonic server RTP stats while video flows` | Backend/SFU stats | Concluido |
| ICE late/stale | Nexus ICE flow, Retro queue before answer | `rejects ICE candidates that arrive after participant leave`; `keeps ICE candidates queued while retry offer is still pending` | Backend/protocolo | Concluido |
| Metadata imediata de track | Fishjam `metadata_test.exs` | `preserves track metadata supplied with immediate track announcement` | Backend/summary consumido pelo JS | Concluido; expôs metadata inicial descartada |
| Browser-real com frames decodificados | `headless_client.js`, Playwright fake media | `two identified channel users join the same SFU call and exchange decoded video frames` | Cliente JS real + SFU | Concluido; nao expôs bug novo |
| Participante sai e rotas restantes seguem vivas | `basic_test.exs` leave gradual | `keeps remaining media routes healthy after a participant leaves` | Backend/SFU | Concluido |
| Offer/ICE restart explicito | Nexus ICE restart pattern | `keeps media alive after an explicit offer request with ICE restart` | Backend/SFU | Concluido |

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

### P0. Camera -> screen share -> camera mantendo RTP - concluido em 2026-07-14

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

Resultado:

- Implementado com `PeerConnection.replace_track/3`, seguindo o comportamento
  do hook browser que usa `sender.replaceTrack(track)`.
- Validado RTP de video antes, durante e depois do screen share.
- Validado `camera -> screen -> camera` no `RoomServer`, metadata de screen e
  ausencia de transceivers extras.

### P0. Churn longo de join/leave/rejoin - concluido em 2026-07-14

Referencia:

- `/Users/rodrigo/src/fishjam-cloud-membrane_rtc_engine/ex_webrtc/integration_test/test_videoroom/test/integration/basic_test.exs`
- `/Users/rodrigo/src/elixir-webrtc-apps/nexus/lib/nexus/room.ex`
- `/Users/rodrigo/src/elixir-webrtc-apps/nexus/lib/nexus/peer.ex`

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

Resultado:

- Implementado cenario com alice/bob/carol, saida de bob, entrada de dave,
  reentrada de bob com novo `participant_id`, saida de carol e RTP validado
  entre os peers vivos depois de cada renegociacao.
- Validado cleanup de `PeerRegistry`, ausencia de tracks ativas do participante
  que saiu, `subscriber_count` e forma de transceivers coerentes em cada fase.
- Nenhum bug novo de runtime foi exposto; o bloco aumentou cobertura para a
  area de maior risco de corrida.
- O harness de audio foi ajustado para amostrar rajadas repetidas em cenarios
  graduais, seguindo o padrao das referencias que usam warmup antes de medir
  midia/stats.

### P1. RTP impairment: buracos, duplicados, reorder e burst irregular - concluido em 2026-07-14

Referencia:

- `/Users/rodrigo/src/fishjam-cloud-membrane_rtc_engine/ex_webrtc/integration_test/test_videoroom/test/integration/containerised_test.exs`
- `/Users/rodrigo/src/fishjam-cloud-membrane_rtc_engine/ex_webrtc/lib/ex_webrtc/rtp_munger.ex`
- `/Users/rodrigo/src/fishjam-cloud-membrane_rtc_engine/ex_webrtc/lib/ex_webrtc/rtp_munger/cache.ex`
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

Resultado:

- Adicionados testes puros para gap pequeno, duplicado e rollover.
- Bug exposto: `RTPForwarder` descartava pacote atrasado que preenchia gap
  pequeno, enquanto a referencia Fishjam guarda mapeamento de gaps para aceitar
  esse pacote uma vez.
- Fix: `RTPForwarder` mantem `missing_rtp_sequences` por kind, com janela curta
  de 64 sequencias, aceita late gap uma vez, descarta duplicados/stale e limpa a
  cache por janela.
- Harness SFU passou a suportar envio de sequencias RTP explicitas para validar
  o caminho real. Como o SFU reescreve sequencias para continuidade, o teste de
  media path valida contagem/unicidade; o teste puro valida os numeros originais.

### P1. Stats ponta a ponta - concluido em 2026-07-14

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

Resultado:

- Adicionado teste `reports monotonic server RTP stats while video flows`.
- Validado que RTP recebido pelo publisher aumenta `inbound_rtp`, RTP enviado
  ao subscriber aumenta `outbound_rtp` e os totais de sala crescem por delta.
- O teste usa duas amostras sucessivas e exige monotonicidade, seguindo o estilo
  das referencias browser-side que calculam bitrate/loss por diferenca entre
  amostras.

### P1. ICE candidate stale/late durante leave e restart - concluido em 2026-07-14

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

Resultado:

- Adicionados testes de runtime para candidato depois de `leave` e candidato
  chegando enquanto retry offer ainda esta pendente.
- O comportamento atual ja era seguro: candidato depois de leave retorna
  `{:error, :not_found}` e candidato durante offer pendente permanece na fila.
- O bloco virou cobertura de regressao do contrato do dominio/canal.

### P2. Metadata de track imediatamente apos adicionar track - concluido em 2026-07-14

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

Resultado:

- Bug exposto: `RoomServer.track_added/3` ignorava `track_info.metadata`.
- Fix: metadata inicial da track agora e persistida, emitida no
  `group_call_track_added` e incluida no summary ativo da sala.
- Validado que um participante que entra depois ve a track com metadata final
  via `GroupCall.get_summary/1`.

### P2. Browser-real smoke script e paridade do cliente JS - concluido em 2026-07-14

Referencia:

- `/Users/rodrigo/src/elixir-webrtc-apps/broadcaster/headless_client.js`
- `e2e/helpers/syntheticMedia.ts`
- `e2e/tests/chat-group-call.spec.ts`

Resultado:

- Teste unitario do hook JS foi executado:
  `rtk npm test -- test/hooks/group_call/group_call_webrtc_hook.test.js`
  com 28 testes passando.
- O smoke browser-real foi implementado no Playwright existente:
  `two identified channel users join the same SFU call and exchange decoded video frames`.
- O teste sobe o app em `MIX_ENV=e2e`, cria dois Chromiums com fake media,
  entra na chamada SFU real e exige:
  - track remota `live`;
  - dimensoes de video carregadas;
  - contador de frames decodificados crescendo nos dois lados;
  - janela de stats do cliente ainda consumindo dados do backend.
- Nao entrou no gate rapido; e um smoke sob demanda para diagnostico/regressao
  de alto nivel.
- Rodado com:
  `rtk npm test -- --grep "two identified channel users join the same SFU call and exchange decoded video frames"`
  em `e2e/`: 1 teste, 0 falhas.

O que testar:

- Script opcional que sobe um browser fake media contra servidor real/local.
- Dois ou tres clients entram em uma chamada real.
- Coleta `getStats()` e verifica frames/bytes crescendo.
- Validar que o hook JavaScript real consome os mesmos contratos ja exercitados
  pelo harness Elixir: offer/answer, ICE restart, `replaceTrack`, leave/rejoin,
  cleanup de tracks e stats.

Aceite:

- Nao entra no gate rapido do `mix test`.
- Rodavel sob demanda para validar decode/render real, quando o headless BEAM
  nao for suficiente.
- Frames remotos decodificados crescem em ambos os lados; uma track apenas
  `live` nao basta como prova de render continuo.

Implementacao sugerida:

- Manter o smoke no Playwright E2E existente enquanto ele precisar login/UI
  reais do produto.
- Se for necessario rodar contra ambiente remoto sem fluxo de UI, criar depois
  um `scripts/group_call_sfu_probe.mjs` com `BASE_URL`, `CHANNEL`, `USERS` e
  `DURATION_MS`, reaproveitando os mesmos criterios de frame/stats.

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
2. Ler a implementacao correspondente na referencia, nao apenas o teste.
3. Registrar no progresso qual padrao sera copiado/adaptado e qual padrao nao
   sera usado.
4. Escrever ou ampliar teste menor que exponha o risco no Retro.
5. Rodar o teste antes do fix quando possivel e registrar a falha no comentario
   de progresso.
6. Corrigir o menor ponto necessario no runtime.
7. Rodar:

```bash
rtk mix format <arquivos alterados>
rtk mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/sfu_media_path_test.exs
rtk mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/sfu_media_path_test.exs --seed <seed-1>
rtk mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/sfu_media_path_test.exs --seed <seed-2>
rtk mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/sfu_media_path_test.exs --seed <seed-3>
rtk mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs apps/retro_hex_chat/test/retro_hex_chat/group_call/rtp_forwarder_test.exs
rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs
```

8. Atualizar este documento: marcar status, escrever bug exposto ou justificar
   por que o teste so aumentou cobertura.
9. Fazer commit pequeno com teste + fix.

## Padroes de implementacao das referencias

| Padrao | Referencia | Aplicacao no Retro |
|---|---|---|
| Encaminhar RTP somente depois de conhecer o track inbound | `elixir-webrtc-apps/nexus/lib/nexus/peer.ex` | Nao inferir tipo por payload como fallback generico; preferir preparar o teste/fluxo para esperar `:track` ou usar warmup |
| Servidor prealoca transceivers outbound e assina peers apos answer | `elixir-webrtc-apps/nexus/lib/nexus/peer.ex` | Validar forma de transceivers e `subscriber_count` em joins concorrentes |
| `replaceTrack` nao cria nova m-line | `apps/retro_hex_chat_web/assets/js/hooks/group_call/group_call_webrtc_hook.js` e `ex_webrtc/lib/ex_webrtc/peer_connection.ex` | Testar screen share via `PeerConnection.replace_track/3` no peer sintetico, mantendo transceiver shape |
| Testes browser usam warmup antes de stats | `fishjam-cloud-membrane_rtc_engine/.../basic_test.exs` e `no_video_test.exs` | Em headless, usar priming de RTP antes de medir fanout quando a primeira rajada pode criar a track |
| Metadata de track e evento de midia sao fluxos separados | `fishjam-cloud-membrane_rtc_engine/.../room.ts` e `metadata_test.exs` | Validar source/metadata pelo `RoomServer` e RTP pelo harness; nao misturar uma coisa como prova unica da outra |

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
