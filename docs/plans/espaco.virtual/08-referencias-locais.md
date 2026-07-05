# Referências locais para implementação

Status: repositórios externos clonados em `~/src` apenas para consulta. Não são
dependências deste projeto.

## Checkouts

### WorkAdventure

- Local: `/Users/rodrigo/src/workadventure`
- Upstream: https://github.com/workadventure/workadventure
- Remote: `https://github.com/workadventure/workadventure.git`
- Commit consultado: `d88ffa3`

Usar para tirar dúvidas sobre:

- formato mental de mapas virtuais com camadas, zonas e colisão;
- Tiled/JSON como referência futura para importador;
- entrada/spawn e evitar aglomeração;
- áreas especiais, meeting rooms, links, arquivos e zonas de interação;
- separação entre mapa, presença e mídia por proximidade.

Arquivos úteis para começar:

```text
/Users/rodrigo/src/workadventure/README.md
/Users/rodrigo/src/workadventure/docs/map-building/index.md
/Users/rodrigo/src/workadventure/docs/map-building/tiled-editor/wa-maps.md
/Users/rodrigo/src/workadventure/docs/map-building/tiled-editor/entry-exit.md
/Users/rodrigo/src/workadventure/docs/map-building/tiled-editor/meeting-rooms.md
/Users/rodrigo/src/workadventure/docs/map-building/tiled-editor/special-zones.md
/Users/rodrigo/src/workadventure/docs/map-building/inline-editor/area-editor/index.md
/Users/rodrigo/src/workadventure/maps/starter/map.json
/Users/rodrigo/src/workadventure/maps/Tuto/tutoV3.json
```

### Gather Clone

- Local: `/Users/rodrigo/src/gather-clone`
- Upstream: https://github.com/trevorwrightdev/gather-clone
- Remote: `https://github.com/trevorwrightdev/gather-clone.git`
- Commit consultado: `3d44216`

Usar para tirar dúvidas sobre:

- sessão multiplayer em memória por espaço;
- join/leave e broadcast por socket;
- movimento tile-based;
- schema de mapa com tiles especiais;
- editor visual de salas/mapa como referência futura;
- separação entre networking, mapa e vídeo por proximidade.

Arquivos úteis para começar:

```text
/Users/rodrigo/src/gather-clone/README.md
/Users/rodrigo/src/gather-clone/backend/src/session.ts
/Users/rodrigo/src/gather-clone/backend/src/sockets/sockets.ts
/Users/rodrigo/src/gather-clone/backend/src/sockets/socket-types.ts
/Users/rodrigo/src/gather-clone/frontend/utils/pixi/zod.ts
/Users/rodrigo/src/gather-clone/frontend/utils/defaultmap.json
/Users/rodrigo/src/gather-clone/frontend/utils/pixi/PlayApp.ts
/Users/rodrigo/src/gather-clone/frontend/utils/pixi/pathfinding.ts
/Users/rodrigo/src/gather-clone/frontend/app/editor/Editor.tsx
/Users/rodrigo/src/gather-clone/frontend/app/editor/PixiEditor.tsx
```

## Regra de uso

Esses checkouts são material de pesquisa, não fonte para cópia. O runtime do
Retro Hex Chat deve continuar autoral, 100% JS no cliente, e integrado ao padrão
Phoenix/LiveView/Channel deste repositório.

Pode-se copiar ideias de arquitetura em alto nível, como:

- usar sessão quente por espaço;
- tratar movimento como intenção validada pelo servidor;
- modelar mapa com camadas, colisão, zonas e interactables;
- separar chat textual, presença e mídia;
- manter vídeo/áudio por proximidade fora do core de movimento.

Não copiar:

- código;
- sprites, tiles, áudio ou imagens;
- nomes, marcas, trade dress ou textos de produto;
- dependências pesadas sem nova decisão de arquitetura.

## Como atualizar

Antes de uma fase grande de implementação, o agente pode atualizar os checkouts:

```sh
git -C /Users/rodrigo/src/workadventure pull --ff-only
git -C /Users/rodrigo/src/gather-clone pull --ff-only
```

Se atualizar, registrar aqui os novos commits consultados para manter
rastreabilidade.
