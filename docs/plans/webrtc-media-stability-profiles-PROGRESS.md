# WebRTC media stability profiles - progresso e aprendizados

> Diario de execucao do plano `webrtc-media-stability-profiles.md`.
> Atualizar a cada bloco com: mudanca feita, problema exposto, comandos
> rodados e aprendizados.
>
> Criado em: 2026-07-14.

## Status por item

| Item | Descricao | Status |
|---|---|---|
| P0 | Remover controles manuais de qualidade visiveis | CONCLUIDO |
| P1 | Criar perfis fixos de midia em `media.js` | CONCLUIDO |
| P2 | Aplicar constraints conservadoras em P2P e conferencia | CONCLUIDO |
| P3 | Aplicar caps/hints nos senders | CONCLUIDO |
| P4 | Limitar screen share | CONCLUIDO |
| P5 | Atualizar testes e docs | CONCLUIDO |
| P6 | Rodar validacoes finais | CONCLUIDO |

## Execucao

### 2026-07-14 - baseline e decisao de produto

- Pedido do Rodrigo: desabilitar/remover o toggle de qualidade da chamada e
  deixar valores fixos por enquanto.
- Baseline encontrado:
  - P2P/lobby tinha botoes visiveis `High quality`, `Medium quality` e
    `Low quality` em:
    - `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/lobby/media_panel.ex`;
    - `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/p2p/call_panel.ex`.
  - Conferencia de canal tinha indicadores de qualidade e stats, mas nao botoes
    visiveis de preset de bitrate.
  - A infraestrutura interna de preset (`applyBitratePreset/2`,
    `media_select_preset`, `lobby_media_set_preset`) ainda existe, mas sem UI
    visivel o usuario nao consegue alternar manualmente.
- Decisao:
  - remover os botoes visiveis agora;
  - manter telemetria/indicadores de qualidade;
  - aplicar valores fixos no cliente em vez de depender de clique manual;
  - deixar limpeza de codigo morto para depois que os perfis fixos estiverem
    validados.

### 2026-07-14 - implementacao do perfil fixo

- Removidos os botoes visiveis de preset manual em:
  - `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/lobby/media_panel.ex`;
  - `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/p2p/call_panel.ex`.
- Atualizado o texto de ajuda em
  `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/features.ex` para
  falar de indicadores de qualidade, nao de ajuste manual por bitrate.
- Atualizado tambem o conteudo do topico
  `apps/retro_hex_chat_web/lib/retro_hex_chat_web/controllers/help_content/feature_call_quality.html.heex`,
  removendo a secao de ajuste manual High/Medium/Low.
- Criados perfis fixos em
  `apps/retro_hex_chat_web/assets/js/lib/p2p/media.js`:
  - `stable`: audio mono/voz, camera 640x360 a 15 fps, 40 kbps audio e
    400 kbps video;
  - `low`: camera 480x270 a 15 fps, 32 kbps audio e 250 kbps video;
  - `high`: mantido apenas como perfil interno conservador, 700 kbps video;
  - `screen`: captura ate 1280x720, 5-10 fps e 800 kbps video.
- Aplicados `contentHint` e caps de `RTCRtpSender.setParameters()` nos fluxos:
  - entrada de chamada P2P;
  - troca de microfone/camera P2P;
  - screen share P2P;
  - entrada de conferencia;
  - screen share da conferencia.
- Screen share agora tenta constraints conservadoras primeiro e cai para
  `{video: true, audio: false}` se o browser rejeitar por
  `OverconstrainedError`.
- `acquireDisplayMedia()` aplica `contentHint="detail"` diretamente no stream
  retornado, inclusive no fallback, para nao depender de cada hook repetir essa
  configuracao.

### 2026-07-14 - problemas expostos pelos testes

- Os testes de screen share modelavam apenas `replaceTrack`, mas o caminho real
  agora tambem precisa validar `getParameters/setParameters`. Os mocks foram
  fortalecidos para expor regressao quando o cap de sender nao for aplicado.
- O teste do painel P2P ainda esperava `phx-value-preset="high"`. A expectativa
  foi invertida para garantir que `High quality`, `Medium quality`, `Low quality`
  e `phx-value-preset` nao voltem no markup.
- O caminho de conferencia usava `navigator.mediaDevices.getDisplayMedia`
  diretamente. Foi alinhado ao helper compartilhado para ter o mesmo limite e o
  mesmo fallback do P2P.
- `applyMediaProfile()` nao tinha teste direto. Foi adicionado teste para
  garantir que todos os senders ativos recebem o perfil `stable` ao iniciar.

### 2026-07-14 - validacoes finais

- `rtk npm test -- test/lib/p2p/media.test.js test/hooks/lobby/lobby_media_hook.test.js test/hooks/group_call/group_call_webrtc_hook.test.js test/hooks/group_call/group_call_prejoin_hook.test.js`
  - resultado: 4 arquivos, 103 testes, 0 falhas.
- `rtk mix format apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/lobby/media_panel.ex apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/p2p/call_panel.ex apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/features.ex apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/p2p/call_panel_test.exs`
  - resultado: ok.
- `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/p2p/call_panel_test.exs apps/retro_hex_chat/test/retro_hex_chat/chat/help_topics_test.exs`
  - resultado: 57 testes, 0 falhas.
- `rtk npm test`
  - resultado: 137 arquivos, 3854 testes, 0 falhas.
- `rtk npm run format:check`
  - resultado: ok.
- `rtk npm run lint`
  - resultado: ok.
- `rtk mix test`
  - resultado: `retro_hex_chat` com 15 properties e 2725 testes, 0 falhas;
    `retro_hex_chat_web` com 770 testes, 0 falhas, 254 excluidos.
- `rtk mix test`
  - repetido apos atualizar `feature_call_quality.html.heex`;
  - resultado: `retro_hex_chat` com 15 properties e 2725 testes, 0 falhas;
    `retro_hex_chat_web` com 770 testes, 0 falhas, 254 excluidos.
- `rtk npm run lint:hooks`
  - resultado: contrato de LiveView hooks passou.
- `rtk npm test && rtk npm run format:check && rtk npm run lint && rtk npm run lint:hooks`
  - repetido apos centralizar `contentHint="detail"` em `acquireDisplayMedia()`;
  - resultado: 137 arquivos JS, 3854 testes, formatacao ok, lint ok e contrato
    de hooks ok.

## Aprendizados consolidados

- "Qualidade" tem dois significados na UI atual:
  - indicador medido de rede/midia, que deve continuar visivel;
  - preset manual de bitrate, que deve sair por enquanto.
- A conferencia ja estava mais proxima da decisao desejada: mostra qualidade,
  mas nao oferece controle manual de preset.
- P2P tem duas superficies de call que precisam ficar coerentes: lobby media
  panel e P2P call panel.
- Perfil conservador precisa existir em dois niveis:
  - constraints de captura, para reduzir trabalho de camera/screen desde a
    origem;
  - caps de sender, para garantir que o encoder nao suba bitrate/fps alem do
    objetivo mesmo quando o browser entregar uma captura maior.
- Screen share nao deve usar o mesmo perfil da camera: precisa de `detail`,
  resolucao limitada e fps baixo.
- Hints de screen share pertencem ao helper de captura, porque P2P e
  conferencia compartilham o mesmo comportamento e ambos precisam cobrir tambem
  o fallback de constraints.
- Testes de WebRTC que verificam troca de track devem mockar tambem
  `RTCRtpSender.getParameters/setParameters`; sem isso eles nao expõem regressao
  nos limites de envio.

## Comandos de verificacao

```bash
rtk mix format <arquivos alterados>
rtk npm test -- test/lib/p2p/media.test.js
rtk npm test -- test/hooks/group_call/group_call_webrtc_hook.test.js
rtk npm test -- test/hooks/group_call/group_call_prejoin_hook.test.js
rtk npm test -- test/hooks/lobby/lobby_media_hook.test.js
rtk npm test
rtk npm run format:check
rtk npm run lint
rtk npm run lint:hooks
rtk mix test
rtk mix test apps/retro_hex_chat/test/retro_hex_chat/chat/help_topics_test.exs
```
