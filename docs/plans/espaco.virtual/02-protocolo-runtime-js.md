# Protocolo e runtime JavaScript

Status: auditado contra o codebase em 2026-07-05. Decisões fechadas com o
usuário. Pronto para implementação.

## Organização dos arquivos JS

Seguir a separação dos jogos atuais: hook só faz wiring, lib faz lógica.
Convenção auditada: os jogos vivem em `js/lib/games/<jogo>/` com exatamente
`audio.js, engine.js, physics.js, protocol.js, renderer.js`, mais a base
compartilhada `js/lib/game_engine.js`. Importante: NÃO herdar de
`game_engine.js` — ele é host-autoritativo sobre RTCDataChannel (modelo P2P);
o espaço é servidor-autoritativo sobre Phoenix Channel. O runtime do espaço é
uma engine nova que segue apenas a convenção modular. Testes Vitest espelham a
árvore em `assets/test/` (ex.: `test/lib/space/collision.test.js`).

Estrutura sugerida:

```text
apps/retro_hex_chat_web/assets/js/hooks/space/
  space_canvas_hook.js

apps/retro_hex_chat_web/assets/js/lib/space/
  engine.js
  renderer.js
  input.js
  protocol.js
  map.js
  collision.js
  camera.js
  avatar.js
  sprite_atlas.js
  zones.js
  interactions.js
  chat.js
  seating.js
  modal.js
  interpolation.js
```

O hook deve ser lazy. Contrato auditado de `lazyFeatureHook` (definido em
`js/hooks/lazy_feature_hook.js`, registrado em `js/hooks/lazy_feature_hooks.js`
e mesclado por `js/hooks/registry.js`): `reason` é obrigatório (lança erro se
faltar); `serverEvents` é um array — se não vazio, `readyEvent` é obrigatório.

```js
SpaceCanvasHook: lazyFeatureHook({
  name: "SpaceCanvasHook",
  loader: () => import("./space/space_canvas_hook"),
  serverEvents: [],
  reason: "Virtual-space canvas and engine are only needed inside a space session.",
})
```

O hook não recebe eventos LiveView via `push_event`; ele abre um Phoenix Channel
com o `join_token` assinado por `SpaceLive`. Por isso, `serverEvents: []` e sem
`readyEvent` no registro lazy. A readiness do runtime é o `channel.join()`.

## Responsabilidades

`SpaceCanvasHook`:

- monta a engine;
- abre/fecha Phoenix Socket e Channel;
- repassa eventos do Channel para a engine;
- envia eventos da engine para o Channel;
- limpa recursos.

`engine.js`:

- ciclo de vida;
- estado local;
- input;
- previsão;
- reconciliação;
- chamada do renderer.

`renderer.js`:

- Canvas 2D;
- render por camadas;
- ordenação por Y;
- nomes e balões;
- HUD de participantes/chat;
- modal de quadro;
- câmera.

`protocol.js`:

- normalização de payloads;
- validação leve no cliente;
- constantes de tipos de evento;
- versionamento.

`map.js` e `collision.js`:

- carregamento do mapa;
- consulta de tile;
- colisão;
- spawn;
- zonas.

`interactions.js`, `seating.js` e `modal.js`:

- resolver interação no tile à frente;
- sentar/levantar de cadeiras;
- abrir modal de imagem de quadro;
- aplicar respostas oficiais do servidor para interações.

## Protocolo Phoenix Channel

V1 deve usar JSON em Phoenix Channel. O limite default configurável, começando em
20 pessoas, torna isso simples, observável e suficiente. Binário só deve entrar
depois de medição real.

O hook cria (validado: `import { Socket } from "phoenix"` já é usado no
`app.js` — o pacote vem dos deps Elixir, não do npm):

```js
import { Socket } from "phoenix";

const socket = new Socket("/socket", { params: { _csrf_token } });
socket.connect();
const channel = socket.channel(`space:${spaceToken}`, { join_token: joinToken });
```

Cliente -> servidor:

```text
join
space_input
space_stop
space_interact
space_chat_bubble
space_admin_action
space_leave
```

Servidor -> cliente:

```text
space_init
space_snapshot
space_delta
space_reconcile
space_message
space_modal
space_admin_notice
space_closed
```

## `space_init`

Enviado quando o hook está pronto e a LiveView já entrou na sessão.
No Channel, isso deve vir como resposta `ok` do `join`, não como evento LiveView.

Payload:

```json
{
  "token": "abc",
  "self_key": "registered:123",
  "map": {"id": "tavern_cafe_v1", "version": 1},
  "config": {
    "tile_size": 16,
    "scale": 3,
    "max_participants": 20,
    "input_hz": 12,
    "text_chat": "global",
    "audio_proximity_reserved": true
  },
  "snapshot": {}
}
```

Decisão fechada (2026-07-05): o campo `map` do `space_init` SEMPRE carrega a
definição completa do mapa, serializada da fonte canônica em Elixir
(`VirtualSpace.Maps.*`). O cliente não tem cópia própria de mapa — `map.js` no
cliente apenas indexa/consulta a estrutura recebida (colisão em `Set`, zonas,
assentos, interactables).

## `space_input`

Payload:

```json
{
  "seq": 17,
  "dx": 1,
  "dy": 0,
  "dir": "right",
  "client_time": 123456789
}
```

Regras:

- `dx/dy` aceitam apenas `-1`, `0`, `1`;
- movimento diagonal não entra na V1;
- rate max recomendado: 12 inputs/s;
- repetir input parado deve ser coalescido no cliente;
- servidor ignora input de sessão terminal ou participante ausente.
- servidor rejeita destino distante; o payload é intenção de passo, não posição
  absoluta.

## `space_snapshot`

Snapshot completo, enviado no init, em reconnect e ocasionalmente para corrigir
desvio.

Payload:

```json
{
  "server_time": 123456999,
  "participants": {
    "registered:123": {
      "nickname": "alice",
      "avatar": "mage_blue",
      "x": 12,
      "y": 8,
      "dir": "down",
      "moving": false,
      "zone_id": "main_hall",
      "pose": "standing",
      "seat_id": null,
      "muted": false,
      "online": true
    }
  }
}
```

## `space_delta`

Delta pequeno para movimento e mudanças de presença.

Payload:

```json
{
  "server_time": 123457050,
  "seq_ack": {"registered:123": 17},
  "updates": {
    "registered:123": {"x": 13, "y": 8, "dir": "right", "moving": false}
  },
  "joined": {},
  "left": []
}
```

O cliente local usa `seq_ack` para descartar previsões antigas e reconciliar.
Clientes remotos interpolam entre posição anterior e nova.

## `space_chat_bubble`

Chat textual da V1 é global dentro do espaço. Todos os participantes recebem a
mensagem, e o renderer mostra balão acima do avatar por alguns segundos.

Payload cliente -> servidor:

```json
{
  "client_id": "msg-17",
  "text": "vamos para a sala lateral?"
}
```

Regras:

- participante mutado não envia mensagem;
- limite recomendado: 160 chars;
- servidor escapa/normaliza texto e aplica rate limit;
- mensagem do espaço é efêmera e não precisa entrar no histórico persistido do
  canal.

## `space_interact`

Interação sempre mira o tile à frente do avatar ou um `interactable_id` conhecido
no snapshot/mapa.

Payload:

```json
{
  "seq": 21,
  "kind": "use",
  "target_id": "board_daily"
}
```

Respostas possíveis:

- cadeira: servidor reserva/libera `seat_id` e publica delta de `pose`;
- porta/zona: servidor valida entrada e publica `zone_id`;
- quadro: servidor envia `space_modal` com a imagem/conteúdo configurado no mapa;
- alvo inválido/distante: servidor rejeita e o cliente não muda estado.

## `space_admin_action`

Somente criador ou admin/server operator:

```json
{"kind": "kick", "target_key": "registered:456", "reason": "spam"}
{"kind": "mute", "target_key": "registered:456", "muted": true}
{"kind": "close", "reason": "done"}
{"kind": "change_map", "map_id": "guild_hall_v1"}
```

Trocar mapa deve reemitir snapshot completo. Participantes voltam para spawn
válido do novo mapa, preservando identidade, mute e presença.

## Previsão e reconciliação

Atenção (auditado): não existe precedente de previsão/reconciliação de rede no
codebase — os jogos atuais são host-autoritativos com broadcast de estado
binário via DataChannel, e as "interpolações" existentes são suavização visual
local. Este bloco é trabalho novo de verdade, sem análogo local para copiar.
Cobrir pesado em Vitest (`engine`, `interpolation`) antes de integrar.

Para parecer responsivo:

1. usuário pressiona tecla;
2. cliente valida colisão local e anima o passo imediatamente;
3. cliente envia `channel.push("space_input", payload)`;
4. servidor valida e publica delta;
5. se a posição oficial bate, cliente só confirma;
6. se diverge, cliente corrige com snap curto ou easing de 80-120ms.

O cliente local pode ter colisão local para evitar andar visualmente contra
parede, mas a fonte de verdade continua sendo o servidor. Participantes remotos
não entram na colisão local na V1.

## Renderização

Usar Canvas 2D, sem Phaser/Pixi na V1. Motivos:

- o projeto atual já tem jogos Canvas autorais;
- o mundo é pequeno;
- as regras são simples;
- evita dependência pesada e budget de bundle;
- dá controle visual para o estilo NES/fantasia.

Config visual:

- tile lógico: `16x16`;
- escala: `3x` ou `4x`, com `imageSmoothingEnabled = false`;
- câmera seguindo o jogador local;
- draw order: floor -> lower objects -> participants sorted by Y -> upper
  objects/roof -> labels/UI.

## Input

Controles:

- setas e WASD para andar;
- toque/drag mobile como direção virtual simples;
- click-to-move só depois que o servidor aceitar passos adjacentes com clareza;
- Enter ou tecla dedicada para abrir chat/balão;
- tecla de ação para interagir com cadeira/quadro/porta;
- Escape para sair/focar fora do canvas.

O hook deve respeitar foco do chat: não capturar teclas quando input/textarea
estiver ativo.

## Falhas e cleanup

Não usar `catch` silencioso. Qualquer falha em asset, mapa, canvas ou protocolo
deve fazer `console.error`/`console.warn` e enviar evento de erro quando fizer
sentido.

Em `destroyed`:

- cancelar `requestAnimationFrame`;
- remover listeners de teclado/touch/resize;
- limpar timers;
- soltar referências a canvas/context;
- parar áudio, se houver.
- chamar `channel.leave()` e `socket.disconnect()`.
