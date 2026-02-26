# Duke Nukem 3D

## Identity

| Campo | Valor |
|-------|-------|
| Nome | Duke Nukem 3D |
| Ano | 1996 |
| Gênero | FPS |
| Desenvolvedora | 3D Realms |
| Nossa ID | `duke3d_shareware` |
| Engine WASM | emduke32 (EDuke32 → Emscripten) |

## Source & License

| Repo | Licença | Descrição |
|------|---------|-----------|
| [nicholasgasior/emduke32](https://github.com/nicholasgasior/emduke32) | GPL v2 | EDuke32 compilado para Emscripten |
| [nicholasgasior/nicholasgasior.com](https://nicholasgasior.com/emduke32/) | GPL v2 | Demo online |

EDuke32 é o source port de referência do Build engine (Duke Nukem 3D).
O emduke32 é um port Emscripten funcional mas menos polido que Dwasm/Qwasm.

## Game Data

| Arquivo | Tamanho | Fonte | Status Legal |
|---------|---------|-------|-------------|
| `DUKE3D.GRP` (shareware) | ~11 MB | [3drealms.com](https://legacy.3drealms.com/duke3d/) ou mirrors | Shareware — redistribuível |
| Full game | ~26 MB | Requer compra (Steam/GOG) | Proprietário |

O episódio shareware ("L.A. Meltdown") contém ~8 níveis completos.
O arquivo `.GRP` é o formato de archive do Build engine.

## Technology

- **Engine base**: EDuke32 (source port moderno do Build engine)
- **Port WASM**: emduke32 via Emscripten
- **Rendering**: Software rendering (Build engine raycasting) via Canvas/WebGL
- **Dependências de build**: Emscripten SDK, make
- **Áudio**: Web Audio API
- **Tamanho do bundle**: ~15-20 MB (engine + shareware data)
- **RAM**: ~100-150 MB

## Integration Plan

**Complexidade: New engine (WASM port menos polido)**

### Build Steps
1. Clonar `nicholasgasior/emduke32`
2. Build com Emscripten: `emmake make`
3. Output: `index.html`, `eduke32.js`, `eduke32.wasm`

### Game Data
1. Baixar shareware `DUKE3D.GRP` (disponível em múltiplos mirrors)
2. Packagear com `file_packager.py --preload DUKE3D.GRP`

### Novos Módulos
- `Mix.Tasks.Arcade.BuildDuke3dEngine` — compilação do emduke32
- `Mix.Tasks.Arcade.Data.Duke3dShareware` — download shareware GRP
- Entry no `Arcade.Catalog`: `%{id: "duke3d_shareware", engine: :duke3d, ...}`
- Ícone `icon_game_duke3d` em `Icons.Games`

### Desafios
- **Maturidade do port**: Menos polido que Dwasm/Qwasm — pode ter bugs de input ou áudio
- **Build system**: EDuke32 usa Makefile custom complexo, adaptação para Emscripten pode ter quirks
- **Input**: O Build engine tem controles peculiares que podem não mapear bem para browser

## Current Status

- **emduke32**: Funcional, demo online disponível, mas com atividade baixa no repo
- **Maturidade**: Média-Baixa — funciona para gameplay básico mas rough edges visíveis
- **Prioridade**: Baixa — o jogo é icônico mas o port precisa de mais polish
- **Recomendação**: Avaliar qualidade do demo online antes de investir no build pipeline. Priorizar jogos com ports mais maduros primeiro.
