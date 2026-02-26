# Diablo

## Identity

| Campo | Valor |
|-------|-------|
| Nome | Diablo |
| Ano | 1996 |
| Gênero | Action RPG / Dungeon Crawler |
| Desenvolvedora | Blizzard North |
| Nossa ID | `diablo_shareware` |
| Engine WASM | DiabloWeb (DevilutionX → Emscripten) |

## Source & License

| Repo | Licença | Descrição |
|------|---------|-----------|
| [d07RiV/diabloweb](https://github.com/d07RiV/diabloweb) | Unlicense (engine) | DevilutionX compilado para WASM com UI web |
| [AJenbo/devilutionX](https://github.com/AJenbo/devilutionX) | Unlicense | Engine base — reverse engineering do Diablo original |

DevilutionX é uma reconstrução do Diablo a partir de reverse engineering do executável original.
O engine é Unlicense (domínio público). Os game data (`.mpq`) são proprietários.

## Game Data

| Arquivo | Tamanho | Fonte | Status Legal |
|---------|---------|-------|-------------|
| `SPAWN.MPQ` (shareware) | ~49 MB | [archive.org](https://archive.org/details/DiabloShareware) | Shareware — redistribuível |
| `DIABDAT.MPQ` (full) | ~500 MB | Requer compra (GOG/Battle.net) | Proprietário |

O shareware (`SPAWN.MPQ`) contém:
- Classes jogáveis (Warrior apenas)
- Cathedral dungeon (primeiros 4 níveis)
- NPCs e quests iniciais
- Suficiente para uma sessão completa de dungeon crawling

## Technology

- **Engine base**: DevilutionX (C++, SDL2)
- **Port WASM**: DiabloWeb compila DevilutionX via Emscripten + adiciona UI web (loading, file picker)
- **Demo online**: https://d07riv.github.io/diabloweb/
- **Rendering**: Software rendering via SDL2 surface → Canvas/WebGL
- **Dependências de build**: Emscripten SDK, cmake, SDL2 (Emscripten port)
- **Áudio**: SDL2_mixer → Web Audio API
- **Tamanho do bundle**: ~55-60 MB (engine ~6 MB + SPAWN.MPQ ~49 MB)
- **RAM**: ~150-200 MB

## Integration Plan

**Complexidade: New engine (proven WASM port)**

### Build Steps
1. Clonar `d07RiV/diabloweb`
2. Build DevilutionX com Emscripten: `emcmake cmake` + `make`
3. O DiabloWeb já inclui shell HTML com loading progress e controles
4. Output: `index.html`, `diablo.js`, `diablo.wasm`

### Game Data
1. Baixar `SPAWN.MPQ` (shareware) de archive.org
2. Packagear com `file_packager.py --preload SPAWN.MPQ`
3. Ou usar o loader do DiabloWeb que carrega o `.mpq` via fetch

### Novos Módulos
- `Mix.Tasks.Arcade.BuildDiabloEngine` — compilação do DiabloWeb
- `Mix.Tasks.Arcade.Data.DiabloShareware` — download SPAWN.MPQ
- Entry no `Arcade.Catalog`: `%{id: "diablo_shareware", engine: :diablo, ...}`
- Ícone `icon_game_diablo` em `Icons.Games`

### Considerações
- **Save games**: DiabloWeb usa IndexedDB para persistir saves no browser
- **Controles**: Mouse-driven (point-and-click) — funciona bem no browser
- **Mobile**: Touch controls possíveis mas não ideais para Diablo
- **Shareware limitado**: Apenas Warrior class e Cathedral — mas suficiente para nostalgia

## Current Status

- **DiabloWeb**: Estável, demo online funcional, projeto com commits recentes
- **DevilutionX**: Muito ativo, releases frequentes, comunidade grande
- **Maturidade**: Alta — o port web é sólido e o engine base é excepcional
- **Prioridade**: Alta — nostalgia massiva, gênero único no catálogo (action RPG), bundle razoável
- **Diferencial**: Único action RPG no catálogo. Diablo é universalmente reconhecido. O shareware oferece experiência completa de dungeon crawling.
