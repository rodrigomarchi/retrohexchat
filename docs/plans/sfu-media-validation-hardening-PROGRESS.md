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
| P0.2 | Camera -> screen share -> camera mantendo RTP | PENDENTE |
| P0.3 | Churn longo de join/leave/rejoin | PENDENTE |
| P1.1 | RTP impairment: buracos, duplicados, reorder e burst irregular | PENDENTE |
| P1.2 | Stats ponta a ponta | PENDENTE |
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

## Comandos de verificacao por bloco

```bash
rtk mix format <arquivos alterados>
rtk mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/sfu_media_path_test.exs
rtk sh -c 'for i in 1 2 3; do mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/sfu_media_path_test.exs || exit $?; done'
rtk mix test apps/retro_hex_chat/test/retro_hex_chat/group_call/runtime_test.exs apps/retro_hex_chat/test/retro_hex_chat/group_call/rtp_forwarder_test.exs
rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs
```
