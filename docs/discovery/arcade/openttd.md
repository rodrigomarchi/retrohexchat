# OpenTTD

## Identity

| Campo | Valor |
|-------|-------|
| Nome | OpenTTD (Open Transport Tycoon Deluxe) |
| Ano | 2004 (baseado em Transport Tycoon Deluxe de 1995) |
| Gênero | Simulação / Gestão de Transporte |
| Desenvolvedora | OpenTTD community |
| Nossa ID | `openttd` |
| Engine WASM | WebTTD (OpenTTD → Emscripten) |

## Source & License

| Repo | Licença | Descrição |
|------|---------|-----------|
| [nicholasgasior/WebTTD](https://github.com/nicholasgasior/WebTTD) | GPL v2 | OpenTTD compilado para WASM via Emscripten |
| [OpenTTD/OpenTTD](https://github.com/OpenTTD/OpenTTD) | GPL v2 | Engine base |

## Game Data

| Arquivo | Tamanho | Fonte | Status Legal |
|---------|---------|-------|-------------|
| OpenGFX (gráficos) | ~3 MB | [openttd.org](https://www.openttd.org/downloads/opengfx-releases/) | GPL v2 — **livre** |
| OpenSFX (sons) | ~10 MB | [openttd.org](https://www.openttd.org/downloads/opensfx-releases/) | CC Sampling Plus 1.0 — **livre** |
| OpenMSX (música) | ~10 MB | [openttd.org](https://www.openttd.org/downloads/openmsx-releases/) | GPL v2 — **livre** |

**Todos os assets são open-source.** O OpenTTD desenvolveu substitutos completos para os
gráficos, sons e músicas originais do Transport Tycoon Deluxe.
Zero dependência de dados proprietários.

## Technology

- **Engine base**: OpenTTD (C++)
- **Port WASM**: WebTTD compila via Emscripten
- **Demo online**: https://nicholasgasior.com/WebTTD/
- **Rendering**: Software rendering via SDL2 → Canvas
- **Dependências de build**: Emscripten SDK, cmake, SDL2 (Emscripten port)
- **Áudio**: SDL2_mixer → Web Audio API
- **Tamanho do bundle**: ~25-30 MB (engine + OpenGFX + OpenSFX)
- **RAM**: ~100-200 MB
- **Saves**: Possível via IndexedDB

## Integration Plan

**Complexidade: New engine (proven WASM port)**

### Build Steps
1. Clonar `nicholasgasior/WebTTD`
2. Build com Emscripten: `emcmake cmake` + `make`
3. Baixar OpenGFX, OpenSFX, OpenMSX
4. Packagear assets com `file_packager.py`
5. Output: `index.html`, `openttd.js`, `openttd.wasm`, `openttd.data`

### Novos Módulos
- `Mix.Tasks.Arcade.BuildOpenttdEngine` — compilação do WebTTD
- `Mix.Tasks.Arcade.Data.OpenttdAssets` — download OpenGFX/SFX/MSX
- Entry no `Arcade.Catalog`: `%{id: "openttd", engine: :openttd, ...}`
- Ícone `icon_game_openttd` em `Icons.Games`

### Considerações
- **Sessões longas**: OpenTTD é jogo de sessões de horas — timeout do solo session pode ser problema
- **Interface**: Mouse-heavy com menus complexos — funciona bem em desktop, ruim em mobile
- **AI**: Inclui AI opponents para single-player
- **Save/Load**: Importante para sessões longas — implementar persistência via IndexedDB
- **Resolução**: Interface pequena em resoluções altas — pode precisar de scaling

## Current Status

- **WebTTD**: Funcional, demo online estável
- **OpenTTD upstream**: Muito ativo, releases frequentes
- **Maturidade**: Alta — OpenTTD é um dos projetos open-source de jogos mais maduros
- **Prioridade**: Média — bundle razoável, 100% livre, gameplay profundo, mas sessões longas e audiência específica
- **Diferencial**: Único simulador de gestão no catálogo. Replay value infinito.
