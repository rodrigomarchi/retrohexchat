# Doom 3

## Identity

| Campo | Valor |
|-------|-------|
| Nome | Doom 3 |
| Ano | 2004 |
| Gênero | FPS / Horror |
| Desenvolvedora | id Software |
| Nossa ID | `doom3_demo` |
| Engine WASM | D3wasm (dhewm 3 → Emscripten) |

## Source & License

| Repo | Licença | Descrição |
|------|---------|-----------|
| [gabrielcuvillier/d3wasm](https://github.com/gabrielcuvillier/d3wasm) | GPL v3 | dhewm 3 (Doom 3 source port) compilado para WASM |
| [dhewm/dhewm3](https://github.com/dhewm/dhewm3) | GPL v3 | Source port base do Doom 3 |

## Game Data

| Arquivo | Tamanho | Fonte | Status Legal |
|---------|---------|-------|-------------|
| Demo `.pk4` files | ~400 MB | [fileplanet mirrors](https://www.moddb.com/games/doom-iii/downloads) | Demo — redistribuível |
| Full game | ~1.5 GB | Requer compra (Steam/GOG) | Proprietário |

A demo do Doom 3 é substancial (~400 MB) e inclui os primeiros níveis.
Os `.pk4` são ZIPs renomeados contendo texturas, modelos, sons e mapas.

## Technology

- **Engine base**: id Tech 4 (dhewm 3 source port)
- **Port WASM**: D3wasm compila via Emscripten
- **Demo online**: https://wasm.continuation-labs.com/d3demo/
- **Rendering**: WebGL 2 (GLSL shaders, stencil shadows)
- **Dependências de build**: Emscripten SDK, cmake
- **Áudio**: Web Audio API
- **Tamanho do bundle**: ~420 MB (engine ~20 MB + demo data ~400 MB)
- **RAM**: ~850 MB (requer bastante memória)

## Integration Plan

**Complexidade: New engine (proven WASM port, mas pesado)**

### Build Steps
1. Clonar `gabrielcuvillier/d3wasm`
2. Configurar com cmake + Emscripten
3. Build: `emcmake cmake` + `make`
4. Output: `index.html`, `index.js`, `index.wasm`

### Game Data
1. Baixar Doom 3 demo
2. Extrair `.pk4` files do diretório `base/`
3. Packagear com `file_packager.py --preload base/@base/`

### Novos Módulos
- `Mix.Tasks.Arcade.BuildDoom3Engine`
- `Mix.Tasks.Arcade.Data.Doom3Demo`
- Entry no `Arcade.Catalog`: `%{id: "doom3_demo", engine: :doom3, ...}`
- Ícone `icon_game_doom3` em `Icons.Games`

### Desafios
- **Bundle massivo**: ~420 MB download + ~850 MB RAM
- **Loading time**: Minutos para carregar — precisa de progress bar robusto
- **Compatibilidade**: Requer WebGL 2 (excluí browsers antigos)
- **Mobile**: Praticamente inviável em dispositivos móveis por RAM

## Current Status

- **D3wasm**: Funcional, demo online estável, mas projeto com baixa atividade recente
- **Maturidade**: Média — funciona mas é pesado e exigente
- **Prioridade**: Baixa — impressionante tecnicamente mas impraticável para muitos usuários
- **Recomendação**: Implementar apenas após jogos mais leves. Considerar como "showcase" para hardware potente.
