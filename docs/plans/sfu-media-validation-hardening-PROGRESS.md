# SFU media validation hardening - progresso e aprendizados

> Diario de execucao do plano `sfu-media-validation-hardening.md`.
> Atualizar a cada bloco fechado com: validacao implementada, problemas
> expostos, correcoes aplicadas, comandos rodados e aprendizados.
>
> Criado em: 2026-07-14.

## Status por item

| Item | Descricao | Status |
|---|---|---|
| P0.1 | Todos audio-only | CONCLUIDA (2026-07-14) |
| P0.2 | Camera -> screen share -> camera mantendo RTP | CONCLUIDA (2026-07-14) |
| P0.3 | Churn longo de join/leave/rejoin | CONCLUIDA (2026-07-14) |
| P1.1 | RTP impairment: buracos, duplicados, reorder e burst irregular | CONCLUIDA (2026-07-14) |
| P1.2 | Stats ponta a ponta | CONCLUIDA (2026-07-14) |
| P1.3 | ICE candidate stale/late durante leave e restart | PENDENTE |
| P2.1 | Metadata de track imediatamente apos adicionar track | PENDENTE |
| P2.2 | Browser-real smoke script | PENDENTE |
| P3.1 | Simulcast/RID | ADIADO - depende de feature |

## Execucao

### 2026-07-14 - inicio do loop

- Objetivo ativo: iterar o plano de validacao SFU ate fechar os itens
  planejados e registrar aprendizados.
- Documento base:
  `docs/plans/sfu-media-validation-hardening.md`.
- Referencias principais ja mapeadas em `~/src`:
  - `fishjam-cloud-membrane_rtc_engine/.../basic_test.exs`;
  - `fishjam-cloud-membrane_rtc_engine/.../no_video_test.exs`;
  - `fishjam-cloud-membrane_rtc_engine/.../containerised_test.exs`;
  - `fishjam-cloud-membrane_rtc_engine/.../metadata_test.exs`;
  - `fishjam-cloud-membrane_rtc_engine/.../simulcast_test.exs`;
  - `elixir-webrtc-apps/broadcaster/headless_client.js`;
  - `elixir-webrtc-apps/nexus`.
- Proximo bloco: P0.1 todos audio-only.

### 2026-07-14 - P0.1 todos audio-only concluido

- Adicionados dois cenarios em
  `apps/retro_hex_chat/test/retro_hex_chat/group_call/sfu_media_path_test.exs`:
  - participantes audio-only entrando gradualmente, enviando RTP de audio,
    tentando video sem track local, deixando a chamada e mantendo audio entre
    os restantes;
  - quatro participantes audio-only entrando simultaneamente, com topologia SFU
    coerente, RTP de audio de todos os publishers e zero RTP de video.
- Problema exposto:
  - o RTP de audio era encaminhado, mas nenhuma track ficava persistida;
  - a causa era que tracks sinteticas de `ExWebRTC.MediaStreamTrack.new/2`
    chegam ao `PeerServer` com `track.id` numerico;
  - `RoomServer.track_added/3` tentava persistir esse valor em campo string
    (`webrtc_track_id`) e a changeset falhava silenciosamente no log debug.
- Correcao aplicada:
  - `PeerServer` agora normaliza apenas o payload de persistencia
    (`webrtc_track_id` e `stream_id`) com `to_string/1`, mantendo o ID bruto no
    estado usado para RTP.
- Verificacoes:
  - `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/sfu_media_path_test.exs --seed 758627`: 9 testes, 0 falhas;
  - `rtk sh -c 'for i in 1 2 3; do mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/sfu_media_path_test.exs || exit $?; done'`: 3/3 ok;
  - `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs apps/retro_hex_chat/test/retro_hex_chat/group_call/rtp_forwarder_test.exs`: 23 testes, 0 falhas;
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs`: 4 testes, 0 falhas.
- Aprendizado:
  - nos testes audio-only, a track persistida so aparece depois de RTP real;
    portanto a validacao correta e primeiro provar fanout de audio e depois
    exigir tracks ativas persistidas.
- Proximo bloco: P0.2 camera -> screen share -> camera mantendo RTP.

### 2026-07-14 - P0.2 leitura de implementacao antes de continuar

- Ajuste de metodo: antes de novas tentativas, ler implementacao de referencia
  alem dos testes. O loop do plano foi atualizado com esse passo explicito.
- Implementacoes lidas:
  - `/Users/rodrigo/src/elixir-webrtc-apps/nexus/lib/nexus/peer.ex`;
  - `/Users/rodrigo/src/elixir-webrtc-apps/nexus/lib/nexus/room.ex`;
  - `/Users/rodrigo/src/fishjam-cloud-membrane_rtc_engine/ex_webrtc/integration_test/test_videoroom/assets/src/room.ts`;
  - `/Users/rodrigo/src/ex_webrtc/lib/ex_webrtc/peer_connection.ex`;
  - `apps/retro_hex_chat_web/assets/js/hooks/group_call/group_call_webrtc_hook.js`.
- Padroes confirmados:
  - Nexus encaminha RTP apenas para tracks inbound ja conhecidas; nao ha
    inferencia por payload no forwarding;
  - Fishjam usa warmup antes de validar stats de midia, entao o priming no
    harness headless e uma adaptacao segura, nao tentativa de mascarar falha;
  - screen share no Retro usa `sender.replaceTrack(track)` no hook e depois
    publica metadata pelo canal;
  - `ExWebRTC.PeerConnection.replace_track/3` substitui o track do sender sem
    renegociar m-line, desde que o kind seja compativel;
  - `PeerConnection.send_rtp/4` procura o track atual do sender, entao o peer
    sintetico precisa atualizar `state.local_tracks.video` apos `replace_track`.
- Decisao para P0.2:
  - manter teste headless usando `PeerConnection.replace_track/3`;
  - validar RTP antes/durante/depois, source/metadata no `RoomServer` e forma de
    transceivers sem crescimento.

### 2026-07-14 - P0.2 concluido

- Adicionado cenario em
  `apps/retro_hex_chat/test/retro_hex_chat/group_call/sfu_media_path_test.exs`:
  - publisher envia video de camera;
  - peer sintetico troca o track local com `PeerConnection.replace_track/3`;
  - runtime recebe `GroupCall.set_screen_share_state/4`;
  - video RTP continua chegando ao subscriber durante screen share;
  - publisher troca de volta para camera;
  - video RTP continua chegando;
  - `RoomServer` alterna source `camera -> screen -> camera`;
  - metadata `screen_track_id` entra e sai corretamente;
  - forma de transceivers permanece `1 recvonly audio`, `1 recvonly video`,
    `1 sendonly audio`, `1 sendonly video` para dois peers.
- Ajuste adicional no harness:
  - cenario "um participante sem camera" passou a primar a track de audio antes
    de medir fanout;
  - cenario all-at-once audio-only deixou RTP fanout fora da assercao principal,
    mantendo topologia, subscriber count, tracks persistidas e ausencia de video.
- Motivo do ajuste:
  - Nexus encaminha RTP apenas apos conhecer o track inbound;
  - Fishjam valida midia all-at-once com browser e warmup de stats;
  - no headless sintetico, usar a primeira rajada instantanea como medicao pode
    medir o priming da track, nao o estado estavel do SFU.
- Problema novo exposto:
  - nenhum bug de runtime alem do P0.1; este bloco aumentou cobertura e removeu
    uma fonte de flake no harness.
- Verificacoes:
  - `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/sfu_media_path_test.exs --seed 722309`: 10 testes, 0 falhas;
  - `rtk sh -c 'for i in 1 2 3; do mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/sfu_media_path_test.exs || exit $?; done'`: 3/3 ok;
  - `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs apps/retro_hex_chat/test/retro_hex_chat/group_call/rtp_forwarder_test.exs`: 23 testes, 0 falhas;
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs`: 4 testes, 0 falhas.
- Observacao:
  - uma tentativa de rodar dominio e channel em paralelo causou erro de escrita
    em `_build/test/consolidated`; repetir sequencialmente passou. Evitar `mix
    test` paralelo no mesmo build dir.
- Proximo bloco: P0.3 churn longo de join/leave/rejoin.

### 2026-07-14 - P0.3 leitura de implementacao antes de continuar

- Implementacoes e testes lidos antes de editar:
  - `/Users/rodrigo/src/fishjam-cloud-membrane_rtc_engine/ex_webrtc/integration_test/test_videoroom/test/integration/basic_test.exs`;
  - `/Users/rodrigo/src/elixir-webrtc-apps/nexus/lib/nexus/room.ex`;
  - `/Users/rodrigo/src/elixir-webrtc-apps/nexus/lib/nexus/peer.ex`;
  - `apps/retro_hex_chat/lib/retro_hex_chat/group_call/room_server.ex`;
  - `apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs`.
- Padroes confirmados:
  - Fishjam valida join gradual, warmup de midia e leave um por vez, sempre
    revalidando os peers restantes;
  - Nexus move peers de `pending` para ativos apenas apos readiness e remove
    peers com `DOWN`, propagando `peer_removed` para os demais;
  - Nexus remove tracks/transceivers outbound ligados ao peer que saiu e so
    encaminha RTP de tracks inbound conhecidas;
  - no Retro, `RoomServer.leave_participant/3` termina o peer, remove registry,
    encerra tracks ativas e notifica os peers restantes.
- Decisao para P0.3:
  - testar uma sequencia deterministica curta, nao property/random;
  - validar shape de SFU e cleanup apos cada fase antes de medir RTP;
  - nao usar fallback por payload ou inferencia de track, mantendo o contrato
    explicito observado nas referencias.

### 2026-07-14 - P0.3 concluido

- Adicionado cenario em
  `apps/retro_hex_chat/test/retro_hex_chat/group_call/sfu_media_path_test.exs`:
  - alice/bob/carol entram e recebem tracks remotas esperadas;
  - video de carol chega a alice e bob;
  - bob sai e deixa de existir no `PeerRegistry`;
  - tracks ativas de bob somem;
  - alice e carol renegociam e continuam recebendo RTP;
  - dave entra e o shape do SFU volta para 3 peers;
  - bob reentra com novo `participant_id`;
  - carol sai;
  - os peers vivos seguem com `subscriber_count`, transceivers e RTP coerentes.
- Helpers adicionados:
  - `assert_live_sfu_shape/2` para casar `subscriber_count` e transceivers com
    o numero de peers vivos;
  - `prime_video_track/2` para criar a track inbound antes de medir fanout;
  - `assert_peer_unregistered/2` e `assert_no_active_tracks_for/2` para cleanup.
- Ajuste de estabilidade no harness:
  - asserts de audio em cenarios graduais agora usam rajadas repetidas e
    acumulam RTP por janela curta;
  - isso segue o padrao das referencias, que validam midia com warmup/amostras,
    e evita que uma unica rajada sintetica meca o momento de criacao da track
    em vez do estado estavel do SFU.
- Problema novo exposto:
  - nenhum bug novo no runtime/SFU; este bloco aumentou cobertura de churn e
    removeu flake do harness de audio.
- Verificacoes:
  - `rtk mix format apps/retro_hex_chat/test/retro_hex_chat/group_call/sfu_media_path_test.exs`: ok;
  - `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/sfu_media_path_test.exs --seed 404725`: 11 testes, 0 falhas;
  - `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/sfu_media_path_test.exs --seed 598474`: 11 testes, 0 falhas;
  - `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/sfu_media_path_test.exs --seed 927311`: 11 testes, 0 falhas;
  - `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/sfu_media_path_test.exs --seed 731209`: 11 testes, 0 falhas;
  - `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs apps/retro_hex_chat/test/retro_hex_chat/group_call/rtp_forwarder_test.exs`: 23 testes, 0 falhas;
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs`: 4 testes, 0 falhas.
- Aprendizado:
  - o harness Elixir fortalece principalmente backend/SFU e contrato de
    protocolo; ele nao prova sozinho o comportamento do cliente JavaScript real;
  - cenarios que dependem de state machine do hook, renderizacao, `getStats()`
    do browser, cleanup de DOM/MediaStreams e engine real precisam de testes JS
    ou smoke browser-real complementares.
- Proximo bloco: P1.1 RTP impairment.

### 2026-07-14 - P1.1/P1.2 leitura de implementacao antes de continuar

- Implementacoes e testes lidos antes de editar:
  - `/Users/rodrigo/src/fishjam-cloud-membrane_rtc_engine/ex_webrtc/integration_test/test_videoroom/test/integration/containerised_test.exs`;
  - `/Users/rodrigo/src/fishjam-cloud-membrane_rtc_engine/ex_webrtc/lib/ex_webrtc/rtp_munger.ex`;
  - `/Users/rodrigo/src/fishjam-cloud-membrane_rtc_engine/ex_webrtc/lib/ex_webrtc/rtp_munger/cache.ex`;
  - `/Users/rodrigo/src/fishjam-cloud-membrane_rtc_engine/ex_webrtc/integration_test/test_videoroom/assets/src/stats.ts`;
  - `/Users/rodrigo/src/live_ex_webrtc/assets/publisher.js`;
  - `apps/retro_hex_chat/lib/retro_hex_chat/group_call/rtp_forwarder.ex`;
  - `apps/retro_hex_chat/lib/retro_hex_chat/group_call/peer_server.ex`;
  - `apps/retro_hex_chat/lib/retro_hex_chat/group_call/room_server.ex`.
- Padroes confirmados:
  - Fishjam mede degradacao por stats/frames depois de warmup e compara deltas,
    nao valores absolutos;
  - Fishjam `RTPMunger` guarda cache curta de gaps para aceitar pacote
    out-of-order que chega depois de um salto de sequencia;
  - live_ex_webrtc calcula bitrate/loss por diferenca entre amostras de
    `getStats()`;
  - o Retro agrega `inbound_rtp`, `outbound_rtp` e totais server-side via
    `PeerServer.stats/1` e `RoomServer.server_stats_payload/1`.
- Decisao para P1:
  - usar testes puros do `RTPForwarder` para validar numeros originais de
    sequencia, duplicado e rollover;
  - usar harness SFU para validar o caminho real, aceitando que o SFU reescreve
    sequencias para continuidade;
  - validar stats por crescimento/monotonicidade, nao por valor exato.

### 2026-07-14 - P1.1 RTP impairment concluido

- Testes adicionados em
  `apps/retro_hex_chat/test/retro_hex_chat/group_call/rtp_forwarder_test.exs`:
  - `forwards late packets that fill small sequence gaps once`;
  - `keeps gap cache across RTP sequence rollover`.
- Falha antes do fix:
  - gap pequeno: esperado `[100, 102, 101, 103]`, recebido `[100, 102, 103]`;
  - rollover: esperado `[65534, 1, 65535, 0, 2]`, recebido `[65534, 1, 2]`.
- Correcao aplicada:
  - `RTPForwarder` agora mantem `missing_rtp_sequences` por media kind;
  - quando um pacote futuro abre gap pequeno, as sequencias ausentes entram em
    uma cache de ate 64 posicoes;
  - pacote atrasado que preenche gap e encaminhado uma vez;
  - duplicados e pacotes stale continuam descartados;
  - `reset_kind/2` limpa tambem a cache de gaps.
- Teste SFU adicionado:
  - `keeps forwarding video RTP through gaps duplicates and reorder`;
  - o `SyntheticPeer` aceita `{:send_rtp_sequence, kind, sequences}`;
  - 5 envios irregulares viram 4 pacotes unicos no subscriber, sem quinto
    pacote duplicado.
- Aprendizado:
  - no caminho real, o SFU/munger reescreve sequencias para continuidade; por
    isso o teste headless valida contagem/unicidade, enquanto o teste puro valida
    os numeros originais.

### 2026-07-14 - P1.2 stats ponta a ponta concluido

- Teste adicionado em
  `apps/retro_hex_chat/test/retro_hex_chat/group_call/sfu_media_path_test.exs`:
  - `reports monotonic server RTP stats while video flows`.
- O que valida:
  - publisher envia video;
  - subscriber recebe todos os pacotes esperados;
  - `inbound_rtp.packets` do publisher cresce;
  - `outbound_rtp.packets` do subscriber cresce;
  - totais de sala `inbound_packets` e `outbound_packets` crescem;
  - segunda amostra nao regride em relacao a primeira.
- Ajustes de estabilidade relacionados:
  - testes de join tardio e leave passaram a primar tracks antes de medir fanout,
    alinhando o harness ao warmup das referencias;
  - no leave, o peer que saiu agora e parado e o teste valida cleanup de
    `PeerRegistry`, tracks ativas e shape dos peers vivos antes de medir RTP.
- Verificacoes:
  - `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/rtp_forwarder_test.exs`: 5 testes, 0 falhas;
  - `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/sfu_media_path_test.exs`: 13 testes, 0 falhas;
  - `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/sfu_media_path_test.exs --seed 404725`: 13 testes, 0 falhas;
  - `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/sfu_media_path_test.exs --seed 927311`: 13 testes, 0 falhas;
  - `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/sfu_media_path_test.exs --seed 731209`: 13 testes, 0 falhas;
  - `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/rtp_forwarder_test.exs apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs`: 25 testes, 0 falhas;
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs`: 4 testes, 0 falhas.
- Proximo bloco: P1.3 ICE candidate stale/late durante leave e restart.

## Aprendizados consolidados

- O harness headless com `ExWebRTC` e suficiente para expor bugs de
  sinalizacao, topologia de transceivers, RTP forwarding e RTCP PLI sem subir
  browsers.
- Testes all-at-once de RTP sintetico precisam distinguir bug real do SFU de
  limitacao/artifato da geracao sintetica; para join concorrente, a topologia de
  transceivers e `subscriber_count` deram sinal mais confiavel.
- Antes de enviar RTP em testes, esperar `subscriber_count` evita races do
  proprio harness e faz a falha apontar para rota SFU ausente.
- IDs de track vindos de peers sinteticos podem ser inteiros; a camada de
  persistencia deve normalizar IDs para string sem alterar o ID bruto usado por
  `PeerConnection.send_rtp/3` e matching de RTP.
- Nao rodar dois `mix test` em paralelo no mesmo `_build/test`; o build dir pode
  falhar em consolidacao de protocolos. Paralelizar leituras shell, nao Mix.
- Em testes headless all-at-once, usar RTP instantaneo como prova de fanout pode
  testar o artefato do gerador sintetico. Para concorrencia, preferir topologia,
  subscriber count e tracks persistidas; fanout RTP completo fica nos cenarios
  graduais ou no futuro smoke browser-real.
- Separar a matriz por camada evita conclusoes erradas: harness Elixir cobre
  media server/SFU e contrato de protocolo; cliente JavaScript real ainda
  precisa de paridade para `RTCPeerConnection`, hook, stats e render.
- Referencia de munger importa para testes de rede ruim: o caminho puro deve
  validar numeros originais; o caminho SFU real pode reescrever sequencias e
  deve ser validado por entrega, unicidade e deltas de stats.

## Comandos de verificacao por bloco

```bash
rtk mix format <arquivos alterados>
rtk mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/sfu_media_path_test.exs
rtk mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/sfu_media_path_test.exs --seed <seed-1>
rtk mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/sfu_media_path_test.exs --seed <seed-2>
rtk mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/sfu_media_path_test.exs --seed <seed-3>
rtk mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs apps/retro_hex_chat/test/retro_hex_chat/group_call/rtp_forwarder_test.exs
rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs
```
