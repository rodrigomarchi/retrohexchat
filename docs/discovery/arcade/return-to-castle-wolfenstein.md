# Return to Castle Wolfenstein

## Identity

| Campo | Valor |
|-------|-------|
| Nome | Return to Castle Wolfenstein |
| Ano | 2001 |
| Gênero | FPS |
| Desenvolvedora | Gray Matter Interactive / id Software |
| Nossa ID | `rtcw_demo` |
| Engine WASM | Wwasm (iortcw → Emscripten) |

## Source & License

| Repo | Licença | Descrição |
|------|---------|-----------|
| [GMH-Code/Wwasm](https://github.com/GMH-Code/Wwasm) | GPL v3 | iortcw (RTCW source port) compilado para WASM |
| [iortcw/iortcw](https://github.com/iortcw/iortcw) | GPL v3 | Source port base do RTCW |

Wwasm é do mesmo autor (GMH-Code) que mantém Dwasm e Qwasm — os engines que já usamos.
Isso garante consistência de qualidade e padrão de build.

## Game Data

| Arquivo | Tamanho | Fonte | Status Legal |
|---------|---------|-------|-------------|
| Demo `.pk3` files | ~200 MB | [ftp.idsoftware.com mirrors](https://www.moddb.com/games/return-to-castle-wolfenstein/downloads) | Demo — redistribuível |
| Full game | ~600 MB | Requer compra (Steam/GOG) | Proprietário |

A demo inclui missões jogáveis completas.
Demo data consiste em vários `.pk3` files (ZIP renomeados com assets).

## Technology

- **Engine base**: id Tech 3 modificado (iortcw)
- **Port WASM**: Wwasm compila via Emscripten com GL4ES (mesmo pipeline de Dwasm/Qwasm)
- **Rendering**: WebGL via GL4ES (OpenGL → OpenGL ES → WebGL)
- **Demo online**: https://wwasm.m-h.org.uk/
- **Dependências de build**: Emscripten SDK, make, GL4ES (já temos)
- **Áudio**: Web Audio API via SDL2
- **Tamanho do bundle**: ~220 MB (engine ~20 MB + demo data ~200 MB)
- **RAM**: ~400-500 MB

## Integration Plan

**Complexidade: New engine (proven WASM port)**

O padrão de build é praticamente idêntico ao Dwasm e Qwasm — mesmo autor, mesma estrutura.

### Build Steps
1. Clonar `GMH-Code/Wwasm`
2. Reutilizar GL4ES já compilado do pipeline existente
3. Build com `make` (Makefile com targets Emscripten)
4. Output: `index.html`, `index.js`, `index.wasm`

### Game Data
1. Baixar RTCW demo (wolf-linux-goty-demo.x86.run ou equivalente)
2. Extrair `.pk3` files do diretório `main/`
3. Packagear com `file_packager.py --preload main/@main/`

### Novos Módulos
- `Mix.Tasks.Arcade.BuildRtcwEngine` — compilação do Wwasm
- `Mix.Tasks.Arcade.Data.RtcwDemo` — download e extração da demo
- Entry no `Arcade.Catalog`: `%{id: "rtcw_demo", engine: :rtcw, ...}`
- Ícone `icon_game_rtcw` em `Icons.Games`

### Considerações
- Bundle grande (~220 MB) — requer loading screen com progresso
- O pipeline já lida com bundles de ~100 MB (LibreQuake), mas RTCW é o dobro
- Considerar lazy-loading ou streaming dos `.pk3` files

## Current Status

- **Wwasm**: Estável, demo funcional online, mesmo autor dos nossos engines atuais
- **Maturidade**: Alta — port provado e testado
- **Prioridade**: Média — excelente jogo mas bundle pesado. Implementar após Quake II.
- **Vantagem**: Mesmo autor = suporte/patches consistentes, GL4ES compartilhado
