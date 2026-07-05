# P2P automatico: direto primeiro com fallback em camadas

Data: 2026-07-05

## Resumo

O objetivo e remover completamente a possibilidade de modo de privacidade/TURN-only
do lobby P2P e trocar a experiencia por uma politica unica e automatica: tentar
conectar os usuarios diretamente primeiro e usar camadas de fallback somente
quando a rota direta nao fechar ou cair.

O projeto ja tem a base necessaria:

- WebRTC no cliente, concentrado no hook do lobby universal.
- STUN/TURN embutido no BEAM.
- Janela `Statistics` com `getStats()` continuo.
- Status bar do lobby alimentada pelo mesmo payload normalizado de estatisticas.

A melhoria principal nao e criar outro modo de P2P nem manter uma preferencia
de privacidade escondida. E transformar a conexao em um fluxo automatico:
direto quando possivel, servidor como fallback, sempre com feedback claro para o
usuario.

## Decisao fechada

- Nao existira mais modo de privacidade no P2P.
- Nao existira toggle, menu, preferencia persistida ou configuracao por usuario
  para forcar TURN-only.
- O usuario nao escolhe entre "direto" e "relay".
- O sistema sempre tenta o melhor caminho automatico para conectar os peers:
  primeiro direto, depois fallback pelo servidor quando necessario.
- O dominio, o contrato LiveView/JS e a UI devem refletir essa decisao. TURN
  deixa de ser um modo de produto e passa a ser uma camada tecnica de fallback.
- A UI deve informar o que esta acontecendo: tentando direto, usando direto,
  tentando servidor, usando relay ou falhou.

## Motivacao

Hoje existe um modo de privacidade que aciona `iceTransportPolicy = "relay"`.
Isso forca a rota pelo TURN, escondendo IPs, mas tambem transforma roteamento em
uma escolha manual do usuario. A nova direcao de produto e remover essa escolha
por completo.

O comportamento desejado e:

1. Sempre iniciar tentando uma rota direta entre os usuarios.
2. Se a conexao direta falhar dentro de uma janela curta, tentar a proxima camada
   automaticamente.
3. Usar o relay do servidor apenas como fallback tecnico, nao como modo de
   privacidade.
4. Mostrar ao usuario qual fase esta acontecendo.
5. Mostrar, depois de conectado, se a rota ativa e direta ou relay.

Isso reduz decisao manual, deixa a experiencia mais previsivel e torna o estado
real da conexao visivel na UI.

## Estudo do projeto

### Backend P2P/TURN

- `RetroHexChat.P2P.ice_servers/1` decide quais ICE servers o browser recebe.
- Quando `turn_configured?/0` e verdadeiro, hoje o retorno efetivo e apenas
  `turn:<relay_ip>:<listen_port>?transport=udp` com credenciais temporarias.
- Quando TURN nao esta configurado, o retorno e apenas
  `stun:stun.l.google.com:19302`.
- O TURN server embutido esta em `RetroHexChat.P2P.Turn.*` e tambem responde
  a Binding requests, ou seja, a infraestrutura ja cobre STUN/TURN no mesmo
  listener.

Conclusao: o backend precisa passar a expor perfis/camadas de ICE para um fluxo
automatico, por exemplo `direct` e `relay`, em vez de um unico array opaco ou
uma preferencia de privacidade.

### Lobby universal

- O P2P principal fica em `RetroHexChatWeb.App.LobbyLive`.
- O hook persistente e `LobbyWebRTCHook`.
- O hook cria uma unica `RTCPeerConnection` que multiplexa:
  - audio/video por tracks/transceivers;
  - arquivos pelo DataChannel `filetransfer`;
  - jogos pelo DataChannel `gamedata`.
- O criador da sessao e sempre o offerer, evitando glare.
- A UI ja tem uma janela `Statistics`, sempre aberta/pinada, e uma status bar
  no topo.

Conclusao: o fallback deve ficar no hook backbone, nao em media/file/game islands.

### Modo privacidade atual

Pontos encontrados:

- `turn_only` e carregado/salvo em `UserPreference.display_settings`.
- O menu bar e o Start menu mostram `Privacy: ON/OFF`.
- `LobbyLive` envia `turn_only` para o hook.
- `webrtc.js` aplica `iceTransportPolicy = "relay"` quando `turnOnly` e true.
- A janela Statistics mostra um icone de privacidade quando `turn_only` esta ativo.
- Testes JS e page objects ainda esperam esse controle.

Conclusao: a remocao nao e apenas visual. Precisa apagar a possibilidade de
configuracao no dominio, no contrato com o cliente, na UI, nos testes e na
documentacao. O comportamento novo deve ser automatico.

## Estudo WebRTC

Pontos relevantes das referencias:

- WebRTC usa signaling externo para trocar SDP/ICE; o app ja faz isso via
  LiveView/PubSub.
- Candidatos ICE tem tipos como `host`, `srflx`, `prflx` e `relay`.
- `relay` representa uma rota via TURN.
- `iceTransportPolicy = "relay"` restringe a coleta/uso de candidatos relay.
- `RTCPeerConnection.getStats()` permite encontrar o candidate pair ativo e seus
  candidatos local/remoto.

Leitura pratica para este projeto:

- Para detectar rota direta vs relay, ler o candidate pair selecionado no
  `getStats()`.
- Se o candidato local ou remoto ativo for `relay`, a UI deve mostrar relay via
  servidor.
- Se ambos forem `host`, `srflx` ou `prflx`, a UI deve mostrar direto.
- Durante a tentativa, usar uma fase propria, independente do estado bruto
  `connectionState`.

Referencias:

- WebRTC peer connections: https://webrtc.org/getting-started/peer-connections
- MDN `RTCIceCandidate.type`: https://developer.mozilla.org/en-US/docs/Web/API/RTCIceCandidate/type
- MDN `RTCIceCandidatePairStats`: https://developer.mozilla.org/en-US/docs/Web/API/RTCIceCandidatePairStats
- MDN `RTCPeerConnection.getStats()`: https://developer.mozilla.org/en-US/docs/Web/API/RTCPeerConnection/getStats
- W3C WebRTC PC, `iceTransportPolicy`: https://w3c.github.io/webrtc-pc/

## Desenho proposto

### Perfil ICE

Substituir o modelo atual por camadas automaticas:

- `direct`: primeira camada. Deve incluir candidatos diretos/STUN e nao deve forcar
  `iceTransportPolicy`.
- `relay`: camada de fallback. Deve usar TURN do servidor somente depois que a
  tentativa direta falhar.

Nao deve haver parametro do usuario para escolher a camada. O hook decide a
camada com base no estado real da conexao.

Payload sugerido do backend para o hook:

```elixir
%{
  ice_profiles: %{
    direct: [%{urls: ["stun:..."]}],
    relay: [%{urls: ["turn:..."], username: "...", credential: "..."}]
  },
  role: "initiator"
}
```

Enquanto a transicao nao estiver completa, da para manter `ice_servers` por
compatibilidade interna, mas a implementacao final deve ter um contrato claro.

### Maquina de fallback automatica no hook

Fases sugeridas:

- `direct_attempt`: criando a conexao com perfil direto.
- `direct_connected`: conectado por rota direta.
- `relay_pending`: rota direta falhou, preparando fallback.
- `relay_attempt`: recriando/renegociando com TURN.
- `relay_connected`: conectado via relay.
- `failed`: falhou apos fallback/retries.

Timeout inicial sugerido:

- `directAttemptMs`: 8 a 12 segundos.
- Em `failed` ou timeout enquanto em `direct_attempt`, reconstruir a conexao
  usando perfil `relay`.
- Depois do relay, manter o retry atual (`RETRY_CONFIG`) com cuidado para nao
  voltar para direto no meio da sessao.

Fluxo desejado:

1. Criar `RTCPeerConnection` com camada `direct`.
2. Negociar SDP/ICE normalmente.
3. Se conectar, medir a rota escolhida por `getStats()` e reportar `Direct` ou
   `Relay` se o navegador escolheu relay por algum motivo.
4. Se nao conectar dentro do timeout direto, fechar a conexao atual, limpar
   candidatos pendentes e iniciar a camada `relay`.
5. Se relay conectar, reportar `Relay via server`.
6. Se relay falhar depois dos retries, reportar falha definitiva.

### Telemetria de rota

Adicionar no snapshot de stats:

```js
route: {
  phase: "direct_attempt" | "direct_connected" | "relay_attempt" | "relay_connected" | "failed",
  type: "unknown" | "direct" | "relay",
  local_candidate_type: "host" | "srflx" | "prflx" | "relay" | null,
  remote_candidate_type: "host" | "srflx" | "prflx" | "relay" | null
}
```

A coleta deve:

1. Chamar `pc.getStats()`.
2. Encontrar o transport ativo com `selectedCandidatePairId`, quando existir.
3. Buscar o `candidate-pair`.
4. Buscar `localCandidateId` e `remoteCandidateId`.
5. Derivar `type`:
   - `relay` se local ou remoto for `relay`;
   - `direct` se existir par selecionado e nenhum lado for relay;
   - `unknown` antes de selecionar par.

### UI

Janela `Statistics`, aba `Network`:

- Adicionar uma linha "Route" ou "Path".
- Mostrar:
  - `Trying direct`
  - `Direct`
  - `Direct failed, trying server`
  - `Relay via server`
  - `Failed`
- Opcional: mostrar tipos locais/remotos como detalhe quando `info_open` estiver
  ativo.

Status bar:

- Hoje mostra estado, kbps e ms.
- Acrescentar o tipo de rota no campo de conexao, por exemplo:
  - `Connecting... - Direct`
  - `Connected - Direct`
  - `Connected - Relay`
  - `Trying server relay...`

### Remocao do modo privacidade

Remover:

- Botao/menu `Privacy: ON/OFF`.
- Evento `toggle_privacy_mode`.
- Persistencia `p2p_settings.turn_only`.
- `turn_only` do payload para o hook.
- `iceTransportPolicy = "relay"` controlado por preferencia.
- Icone de privacidade na aba de Statistics.
- Topico de ajuda que descreve TURN-only como controle do usuario.

Nao e necessario migrar banco: a chave antiga pode ficar ignorada em
`display_settings`.

Importante: remover nao significa apenas esconder o botao. A possibilidade de
configurar essa politica deve sair do fluxo funcional. Se uma chave antiga
`turn_only` existir no banco, ela deve ser ignorada.

## Arquivos modificados neste estudo

- `docs/p2p-direct-first-fallback-plan.md` foi criado.

## Arquivos previstos para a implementacao

Backend/domain:

- `apps/retro_hex_chat/lib/retro_hex_chat/p2p/p2p.ex`
  - adicionar camadas/perfis ICE direto/relay para uso automatico;
  - manter ou substituir `ice_servers/1` conforme impacto nos testes.
- `apps/retro_hex_chat/lib/retro_hex_chat/lobby/service.ex`
  - atualizar payload de `start_signaling/2`, se ainda usado.
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/features.ex`
  - remover/renomear o topico de Privacy Settings.
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/commands.ex`
  - remover referencias a `feature-privacy-mode`.

LiveView/UI:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/lobby_live.ex`
  - remover `turn_only`;
  - enviar `ice_profiles`;
  - normalizar `stats.route`;
  - atualizar labels de conexao/fallback.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/lobby_live.html.heex`
  - remover passagem de `turn_only`.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/lobby/universal_lobby.ex`
  - remover controles de privacidade do menu bar e Start menu;
  - passar route/status para status bar e Statistics.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/lobby/lobby_menu_bar.ex`
  - remover item `Privacy: ON/OFF`.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/lobby/lobby_status_bar.ex`
  - exibir tipo/fase da rota.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/lobby/lobby_network_panel.ex`
  - exibir rota ativa e fase de fallback;
  - remover icone `lobby-tray-privacy`.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/controllers/help_content/feature_privacy_settings.html.heex`
  - remover ou substituir por texto de roteamento automatico.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/controllers/help_content/feature_audio_call.html.heex`
  - remover link para Privacy Settings.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/controllers/help_content/feature_video_call.html.heex`
  - remover link para Privacy Settings.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/controllers/help_content/cmd_admin_turn.html.heex`
  - ajustar referencia a Privacy Mode.

JavaScript:

- `apps/retro_hex_chat_web/assets/js/lib/p2p/webrtc.js`
  - remover `turnOnly` como opcao publica;
  - ou manter somente uma opcao interna `relayOnly` para fallback, sem UI.
- `apps/retro_hex_chat_web/assets/js/hooks/lobby/lobby_webrtc_hook.js`
  - implementar maquina automatica de fallback direto -> relay;
  - enviar eventos de fase para LiveView;
  - enriquecer stats com `route`.
- `apps/retro_hex_chat_web/assets/js/lib/p2p/media.js`
  - coletar/derivar candidate pair ativo e tipos local/remoto.

Testes:

- `apps/retro_hex_chat/test/retro_hex_chat/p2p/p2p_test.exs`
  - cobrir perfis ICE direto/relay.
- `apps/retro_hex_chat_web/assets/test/lib/p2p/webrtc.test.js`
  - remover expectativa de `turnOnly` usuario;
  - cobrir criacao normal sem `iceTransportPolicy`.
- `apps/retro_hex_chat_web/assets/test/lib/p2p/feature_stats.test.js`
  - cobrir `route.type` e candidate pair ativo.
- `apps/retro_hex_chat_web/assets/test/hooks/lobby/lobby_webrtc_hook.test.js`
  - cobrir timeout/falha direto -> fallback relay.
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/app/lobby_live/*`
  - ajustar assigns e renderizacao, se houver testes afetados.
- `e2e/pages/LobbyPage.ts`
  - remover locator `privacyButton`.
- E2E P2P, se existir cobertura ativa:
  - validar que Statistics/status bar mostram direto ou relay.

Documentacao:

- `README.md`
  - atualizar descricao P2P para "direct-first, automatic server relay fallback".
- `docs/AGENT-GUIDE.md`
  - substituir a regra antiga de TURN-only privacy mode pela nova regra de fallback.

## Task list

### Fase 1 - Contrato ICE

- [ ] Criar funcao de backend para retornar perfis ICE separados.
- [ ] Incluir STUN para tentativa direta.
- [ ] Incluir TURN com credenciais temporarias apenas no perfil relay.
- [ ] Garantir que nao exista parametro de usuario para escolher TURN-only.
- [ ] Ajustar chamadas em `LobbyLive` e/ou `Lobby.Service`.
- [ ] Testar `P2P` com TURN configurado e nao configurado.

### Fase 2 - Hook WebRTC

- [ ] Remover uso de `turn_only` vindo da UI.
- [ ] Adicionar estado interno de fase: direto, fallback, relay, failed.
- [ ] Iniciar conexao com perfil direto.
- [ ] Adicionar timer de tentativa direta.
- [ ] Ao falhar/expirar direto, fechar PC atual e reconstruir com perfil relay.
- [ ] Garantir que o initiator recria DataChannels ao reconstruir.
- [ ] Garantir que pending candidates/descriptions antigos nao vazam para o PC novo.
- [ ] Emitir eventos de fase para LiveView.
- [ ] Manter retry atual sem alternar indevidamente entre direto e relay.

### Fase 3 - Estatisticas de rota

- [ ] Estender `collectFeatureSnapshot` para localizar selected candidate pair.
- [ ] Derivar `route.type`, `local_candidate_type` e `remote_candidate_type`.
- [ ] Normalizar `stats.route` em `LobbyLive`.
- [ ] Adicionar testes unitarios de stats com candidatos `host/srflx/relay`.

### Fase 4 - UI

- [ ] Adicionar linha de rota na aba Network da janela Statistics.
- [ ] Mostrar detalhe de candidatos quando `info_open` estiver ativo.
- [ ] Atualizar status bar com tipo/fase de conexao.
- [ ] Ajustar diagrama/labels se necessario para mostrar relay.
- [ ] Validar layout mobile/desktop da Statistics window.

### Fase 5 - Remover privacidade

- [ ] Remover item de menu `Privacy: ON/OFF` do menu bar.
- [ ] Remover item de Start menu `Privacy: ON/OFF`.
- [ ] Remover evento `toggle_privacy_mode`.
- [ ] Remover `load_turn_only_preference/1` e `save_turn_only_preference/2`.
- [ ] Remover `turn_only` dos assigns.
- [ ] Ignorar qualquer `p2p_settings.turn_only` antigo salvo em preferencias.
- [ ] Remover icone de privacidade da Statistics.
- [ ] Ajustar page objects e testes que esperam o botao.
- [ ] Atualizar help topics e docs.

### Fase 6 - Verificacao

- [ ] Rodar testes Elixir focados em P2P/Lobby.
- [ ] Rodar testes JS focados em `p2p` e `lobby_webrtc_hook`.
- [ ] Rodar testes LiveView afetados.
- [ ] Rodar E2E P2P representativo.
- [ ] Testar manualmente dois browsers na mesma rede: deve mostrar `Direct`.
- [ ] Testar manualmente ambiente que bloqueia direto: deve mostrar fallback e depois `Relay`.
- [ ] Verificar `/admin turn stats` enquanto relay esta ativo.

## Riscos e decisoes pendentes

- Timeout direto: curto demais causa relay desnecessario; longo demais piora UX.
  Sugestao inicial: 10 segundos.
- STUN publico vs STUN proprio: o TURN listener local responde Binding requests,
  mas a URL `stun:` para o mesmo listener precisa ser validada em browser real.
  Se houver problema, manter Google STUN como direto inicial e usar o TURN proprio
  somente no fallback.
- Recriacao da conexao pode derrubar media/file/game ativos. Como fallback ocorre
  antes de conectar, isso e aceitavel; para quedas depois de conectado, manter
  retry no perfil atual.
- O campo antigo `p2p_settings.turn_only` pode permanecer no banco sem uso; nao
  ha necessidade imediata de migracao.

## Criterios de aceite

- Nao existe controle visivel de Privacy/TURN-only no lobby.
- Nao existe caminho funcional para o usuario forcar Privacy/TURN-only.
- O primeiro caminho tentado e direto.
- Se direto falhar, o usuario ve feedback de fallback para servidor.
- Depois de conectado, Statistics e status bar mostram `Direct` ou `Relay`.
- Quando relay e usado, `/admin turn stats` reflete alocacoes ativas.
- Testes focados passam.
