# Ambiguidades fechadas

Status: decisões fechadas após revisão do plano, leitura de fontes externas e
respostas do usuário. Nenhuma implementação feita ainda.

## Fontes consultadas

- Phoenix Channels: a documentação oficial cita Channels para eventos de jogos
  multiplayer, clientes conectados a tópicos e broadcasts server->clientes.
  Fonte: https://hexdocs.pm/phoenix/channels.html
- Phoenix JS client: a documentação oficial mostra `Socket`, `channel`, `push`,
  `join`, eventos e suporte a JSON/binário sobre WebSocket.
  Fonte: https://hexdocs.pm/phoenix/js/
- Phoenix LiveView JS interop: hooks conseguem `pushEvent` e `handleEvent`, mas
  isso é interop de LiveView; não é a melhor espinha para tráfego de jogo.
  Fonte: https://hexdocs.pm/phoenix_live_view/js-interop.html
- WorkAdventure maps: usa mapas JSON/Tiled, camadas, tiles, entradas e colisão
  por propriedade `collides`.
  Fonte: https://docs.workadventu.re/map-building/tiled-editor/wa-maps/
- WorkAdventure entries/exits: entrada deve ter zona/layer inicial; áreas de
  spawn grandes evitam aglomeração.
  Fonte: https://docs.workadventu.re/map-building/tiled-editor/entry-exit/
- WorkAdventure README: virtual office com avatares e video-chat acionado por
  proximidade.
  Fonte: https://github.com/workadventure/workadventure/blob/master/README.md
- Gather Clone README e código: espaços customizáveis com tiles, movimento
  tile-based, networking multiplayer, proximidade e vídeo separado do mapa.
  Fonte: https://github.com/trevorwrightdev/gather-clone

## Decisões

### 1. Transporte realtime

Ambiguidade: usar LiveView `pushEvent`/`push_event` ou criar Phoenix Channel?

Decisão: usar Phoenix Channel para presença/movimento/mensagens do mundo.
`SpaceLive` fica apenas como shell, validação inicial, terminal de erro e
emissor de `join_token`.

Motivo: Phoenix Channels são documentados para eventos de jogos multiplayer,
clientes em tópicos e broadcasts. LiveView continua útil para montar a página,
mas não deve carregar o loop de runtime.

Implementação alvo:

```text
GET /space/:token -> SpaceLive -> assina join_token -> SpaceCanvasHook
SpaceCanvasHook -> Socket("/socket") -> channel("space:<token>", {join_token})
SpaceChannel -> VirtualSpace.SessionServer
```

### 2. Estado de sessão

Ambiguidade: manter `pending -> open -> active` ou simplificar?

Decisão: V1 usa `pending -> active -> closed | expired | failed`.

Motivo: não há negociação WebRTC nem sala de espera real. Quando o primeiro
participante entra, o espaço está ativo. `last_activity_at` e contagem de
participantes cobrem o que `open` tentava expressar.

### 3. Expiração

Ambiguidade: expira por inatividade ou tempo fixo? Qual TTL?

Decisão: TTL fixo desde criação, sem renovação por atividade. Default do comando:
2 horas, configurável e limitado por admin/settings. `pending` sem entrada
expira em 5 minutos. O criador também pode encerrar manualmente.

Motivo: o requisito diz que, por enquanto, o espaço expira junto com o link.
Renovar por atividade criaria comportamento diferente. O default de 2h segue a
resposta do usuário e mantém o link curto por padrão.

Se o espaço nascer de um lobby pai no futuro, usar:

```text
expires_at = min(parent_lobby.expires_at, now + requested_or_default_ttl)
```

### 4. Identidade e admissão

Ambiguidade: todo mundo precisa ser registrado/identificado ou só o criador?

Decisão: criar e entrar exigem usuário registrado e identificado, permissão no
canal de origem e `join_token` assinado. Guests não entram.

Motivo: resposta do usuário fechou que o espaço é somente para membros elegíveis
do canal e nunca para guests. Para evitar colisão/impersonation operacional, a
chave do participante é sempre `registered:<id>`.

### 5. Autorização do Channel

Ambiguidade: o token da URL basta para entrar no Channel?

Decisão: não. A URL é bearer capability para abrir a página, mas o Channel exige
`join_token` curto assinado por `SpaceLive`.

Motivo: isso reaproveita a sessão HTTP existente e impede que um cliente JS
conecte direto ao Channel só com um token copiado sem passar pelo fluxo do app.

### 6. Modelo de movimento

Ambiguidade: contínuo com tick fixo ou tile-a-tile por input?

Decisão: V1 é tile-a-tile, cardinal, sem diagonal, evento por input validado.
Servidor aceita no máximo um passo por `virtual_space_step_ms` por participante
e publica deltas apenas após validar.

Motivo: o produto pedido é estilo 8-bit antigo; o mapa é grid; 20 participantes
não exigem simulação contínua. Tick fixo fica para movimento fluido avançado.

### 7. Colisão entre pessoas

Ambiguidade: participantes bloqueiam tiles?

Decisão: não bloqueiam movimento na V1. Só mapa/objetos estáticos bloqueiam.
Ocupação de tile serve para spawn, proximidade futura e debug.

Motivo: bloquear pessoas em corredor/porta cria griefing e fricção em escritório.

### 8. Mapa e editor

Ambiguidade: adotar Tiled/WorkAdventure-style map imediatamente ou mapa autoral
interno?

Decisão: V1 usa mapa JS/JSON autoral interno com `tileSize`, `layers`,
`collision`, `zones` e `interactables`. Tiled fica como importador futuro.

Motivo: WorkAdventure valida o valor de mapas Tiled/JSON, camadas e propriedades
como `collides`, mas nosso runtime deve ficar pequeno e autoral agora.

### 9. Tamanho do tile

Ambiguidade: 32x32 por compatibilidade com WorkAdventure ou 16x16 por estética?

Decisão: V1 usa 16x16 lógico com escala inteira no Canvas. O schema guarda
`tileSize`, então um importador futuro pode normalizar mapas 32x32.

Motivo: 16x16 combina melhor com estética 8-bit NES-like; compatibilidade com
ferramentas fica no importador.

### 10. Onde o card aparece

Ambiguidade: `/space` posta no canal/PM ativo ou só mostra link privado?

Decisão: somente em canal de chat. Se `#canal-alvo` vier no comando, postar lá;
senão, postar no canal ativo. PM, Status e lobby P2P não são origem de espaço na
V1.

Motivo: resposta do usuário fechou que o espaço é um lobby ativo no canal e para
membros/elegíveis daquele canal.

### 11. Áudio/vídeo por proximidade

Ambiguidade: incluir já, reaproveitar P2P ou deixar para depois?

Decisão: fora da V1. Quando entrar, deve ser server-mediated/SFU, não mesh P2P
entre 20 pessoas.

Motivo: WorkAdventure e clones de Gather tratam vídeo/proximidade como camada
separada. O projeto já tem P2P para 2 pessoas, mas 20 pessoas precisa outra
arquitetura de mídia.

### 12. Sentido de "100% JS"

Ambiguidade: "100% JS" inclui servidor?

Decisão: "100% JS" vale para runtime visual do mundo: engine, renderização,
input, mapa e assets autorais. O servidor continua Elixir/Phoenix, como o resto
do projeto.

Motivo: o requisito também diz que este modo precisa ser via servidor; neste
repositório, o servidor realtime é Phoenix/BEAM.

### 13. Comando

Ambiguidade: `/space` simples ou com argumentos?

Decisão: `/space [#canal-alvo] [nome-do-space] ttl=[2h default]`.

Motivo: o usuário quer criar espaços para um canal específico, nomear o espaço e
controlar TTL sem abrir UI separada.

### 14. Capacidade

Ambiguidade: 20 rígido ou configurável?

Decisão: 20 é default, mas o limite é configurável pelo painel de admin do
servidor. Ao lotar, mostrar erro simples de recusado.

### 15. Primeiro mapa

Ambiguidade: mapa único/fixo ou seleção?

Decisão: planejar quatro mapas. O primeiro deve ser completo e servir de playbook:
`tavern_cafe_v1`, uma taverna-cafe de fantasia inspirada em cafeteria urbana.

### 16. Interações da V1

Ambiguidade: V1 mínima ou feature completa?

Decisão: V1 deve incluir colisão completa, chat textual global, balões, sentar em
cadeira, entrar em sala/zona, interagir com quadro, modal de imagem, persistência
de posição enquanto a sessão estiver ativa e poderes do criador.

### 17. Poderes do criador

Ambiguidade: criador só fecha ou também modera?

Decisão: criador pode expulsar usuário, fechar espaço, trocar mapa e mutar chat.
