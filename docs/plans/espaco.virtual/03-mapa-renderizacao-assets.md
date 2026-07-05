# Mapa, renderização e assets

Status: proposta para conversa. Nenhuma implementação feita ainda.

## Direção visual

O alvo é um escritório de fantasia top-down em estilo 8-bit autoral. O primeiro
mapa é uma taverna-cafe: um lugar de encontro com clima de cafeteria urbana e
fantasia medieval, sem copiar marcas, layout, nomes ou assets reais.

- chão de pedra, madeira e grama;
- mesas de escriba, estantes, quadros, cristais, pergaminhos;
- balcão de cafe/taverna, mesas pequenas, cadeiras, sofás e lareira;
- salas de reunião como círculos rúnicos ou mesas redondas;
- áreas de foco como bibliotecas/salas silenciosas;
- portais e placas como affordances;
- avatares pequenos com 4 direções e caminhada simples.

Não usar sprites, mapas, música, nomes ou personagens da Nintendo. A referência
é de linguagem visual e câmera, não de asset.

## Tile size

Embora WorkAdventure use tiles 32x32 em seus mapas, para um clima 8-bit antigo
a decisão V1 é usar tile lógico 16x16 e escalar no canvas.

Regras:

- `TILE_SIZE = 16`;
- render com escala inteira (`3x` ou `4x`);
- `ctx.imageSmoothingEnabled = false`;
- hitbox do avatar ocupa 1 tile;
- objetos altos podem ocupar mais tiles e renderizar parte superior na camada
  `above`.

## Formato de mapa V1

Decisão V1: começar com JSON/JS interno, versionado no repositório, sem exigir
Tiled no fluxo de desenvolvimento:

```js
export const tavernCafeV1 = {
  id: "tavern_cafe_v1",
  version: 1,
  width: 64,
  height: 48,
  tileSize: 16,
  spawn: [
    {x: 10, y: 12, dir: "down"},
    {x: 11, y: 12, dir: "down"}
  ],
  layers: {
    floor: [],
    decor: [],
    above: []
  },
  collision: [],
  zones: [],
  interactables: [],
  seats: []
};
```

`layers` pode começar como matriz de IDs por tile. `collision` deve ser fácil de
consultar no servidor e no cliente.

Formato recomendado para colisão:

```js
collision: [
  {x: 0, y: 0, w: 64, h: 1, kind: "wall"},
  {x: 8, y: 8, w: 3, h: 2, kind: "desk"}
]
```

Na carga, servidor e cliente expandem para `MapSet`/`Set` de tiles bloqueados.

## Zonas

Zonas iniciais:

```js
zones: [
  {id: "spawn", kind: "spawn", x: 10, y: 12, w: 6, h: 4},
  {id: "main_cafe", kind: "common", x: 8, y: 8, w: 24, h: 18},
  {id: "side_room", kind: "meeting", x: 36, y: 8, w: 12, h: 10},
  {id: "quiet_corner", kind: "quiet", x: 42, y: 24, w: 12, h: 10}
]
```

V1 deve mostrar mudança de zona/sala e permitir entrar em salas do mesmo mapa.
Proximidade de áudio/vídeo fica para depois.

## Interactables

Interações simples para dar vida ao escritório:

```js
interactables: [
  {
    id: "menu_board",
    kind: "board",
    x: 12,
    y: 10,
    title: "Menu da taverna",
    modal: {
      kind: "image",
      asset: "board_menu_v1"
    }
  },
  {
    id: "standup_board",
    kind: "board",
    x: 28,
    y: 12,
    title: "Daily",
    modal: {
      kind: "image",
      asset: "board_daily_v1"
    }
  }
]
```

Na V1, `space_interact` deve abrir modal de imagem no cliente para quadros. O
conteúdo vem do mapa/atlas autoral, não de upload arbitrário.

## Cadeiras

Cadeiras são interações de estado, não apenas decoração:

```js
seats: [
  {id: "seat_bar_1", x: 18, y: 14, dir: "up"},
  {id: "seat_table_1_a", x: 24, y: 20, dir: "right"}
]
```

Regras:

- servidor reserva uma cadeira por participante;
- sentar muda `pose` para `"sitting"` e ajusta direção;
- andar enquanto sentado levanta primeiro;
- cadeira ocupada rejeita segunda interação;
- cadeira e mesa continuam bloqueando movimento conforme `collision`.

## Map registry

V1 deve nascer com suporte a quatro mapas, mesmo que o primeiro seja o playbook
completo:

```js
export const spaceMaps = {
  tavern_cafe_v1,
  guild_hall_v1,
  arcane_library_v1,
  garden_camp_v1
};
```

Os três mapas depois do primeiro podem seguir o mesmo schema e reaproveitar o
atlas, mas a primeira entrega deve completar `tavern_cafe_v1` antes de expandir.

## Asset strategy

Para manter "100% JS autoral" na primeira etapa, a opção mais limpa é gerar um
atlas em `sprite_atlas.js` usando `OffscreenCanvas` ou canvas temporário:

- desenhar tiles por código;
- gerar padrões de chão;
- desenhar objetos simples em pixel art;
- desenhar avatares por paleta.
- desenhar imagens de quadros/modais como assets autorais do atlas.

Isso evita PNGs externos e deixa tudo revisável como código. Se depois quisermos
sprites mais ricos, podemos adicionar PNGs autorais em `assets/static/images`
sem mudar o protocolo.

## Render layers

Ordem:

```text
floor
ground decor
participants and low objects sorted by y
above/roof/tree tops
labels and bubbles
HUD
```

Participantes devem ser ordenados por coordenada Y para passarem visualmente
atrás/na frente de mesas e objetos.

## Spawn

Não colocar todos no mesmo tile. Usar lista de spawn points e escolher:

1. primeiro tile livre em ordem determinística;
2. se todos ocupados, permitir múltiplos no spawn apenas como fallback;
3. nunca spawnar em colisão.

Isso segue a mesma preocupação vista em ferramentas de mapas virtuais: área de
entrada grande evita que várias pessoas apareçam no mesmo ponto.

## Futuro: importador Tiled

WorkAdventure usa mapas JSON gerados pelo Tiled e propriedades como `collides`,
entry/start e zonas. Podemos aproveitar a ideia sem adotar o stack:

- manter mapa interno autoral na V1;
- criar depois um importador de `.tmj` para nosso formato;
- aceitar propriedades `collides`, `zone`, `spawn`, `interact`;
- salvar o resultado normalizado como módulo JS/JSON.

Isso permite usar Tiled como ferramenta, mas não torna o runtime dependente dele.
Qualquer mapa importado deve ser normalizado para o schema interno com
`tileSize`, `collision`, `zones` e `interactables`.
