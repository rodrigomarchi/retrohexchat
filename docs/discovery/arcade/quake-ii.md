# Quake II

## Identity

| Campo | Valor |
|-------|-------|
| Nome | Quake II |
| Ano | 1997 |
| Gênero | FPS |
| Desenvolvedora | id Software |
| Nossa ID | `quake2_shareware` |
| Engine WASM | Qwasm2 (Yamagi Quake II → Emscripten) |

## Source & License

| Repo | Licença | Descrição |
|------|---------|-----------|
| [GMH-Code/Qwasm2](https://github.com/GMH-Code/Qwasm2) | GPL v2 | Yamagi Quake II compilado para WASM. Mesmo autor do Qwasm (Quake I) que já usamos |
| [turol/webquake2](https://github.com/turol/webquake2) | GPL v2 | Alternativa, menos mantida |

Qwasm2 é do mesmo autor (GMH-Code) que mantém o Qwasm que já usamos para Quake I.
Consistência de qualidade garantida.

## Game Data

| Arquivo | Tamanho | Fonte | Status Legal |
|---------|---------|-------|-------------|
| `baseq2/pak0.pak` (demo) | ~48 MB | [q2-324-demo-x86.exe](ftp://ftp.idsoftware.com/) ou mirrors | Shareware — redistribuível |
| Full game | ~180 MB | Requer compra (Steam/GOG) | Proprietário |

A demo contém os primeiros níveis (Unit 1) e é suficiente para demonstração.
O pak0.pak precisa ser extraído do installer da demo (self-extracting archive).

## Technology

- **Engine base**: Yamagi Quake II (source port moderno, mantido ativamente)
- **Port WASM**: Qwasm2 compila via Emscripten com GL4ES (OpenGL → OpenGL ES → WebGL)
- **Rendering**: WebGL 2 (hardware-accelerated) + fallback software rendering
- **Dependências de build**: Emscripten SDK, cmake, GL4ES (mesmo que já usamos)
- **Áudio**: Web Audio API via SDL2
- **Tamanho do bundle**: ~60-70 MB (engine ~12 MB + demo data ~48 MB)
- **RAM**: ~200-300 MB

## Integration Plan

**Complexidade: New engine (proven WASM port)**

Apesar de ser "Quake II", o engine (Yamagi) é diferente do QuakeSpasm (Quake I), então precisa
de um módulo de build separado.

### Build Steps
1. Clonar `GMH-Code/Qwasm2`
2. Clonar GL4ES (já temos no pipeline — reutilizar)
3. Build GL4ES para Emscripten (mesmo processo do Qwasm)
4. Build Qwasm2 com Emscripten: `emcmake cmake` + `make`
5. Output: `index.html`, `index.js`, `index.wasm`

### Game Data
1. Baixar demo do Quake II (q2-324-demo-x86.exe)
2. Extrair `baseq2/pak0.pak` do installer
3. Packagear com `file_packager.py --preload baseq2/@baseq2/`

### Novos Módulos
- `Mix.Tasks.Arcade.BuildQuake2Engine` — compilação do Qwasm2
- `Mix.Tasks.Arcade.Data.Quake2Demo` — download e extração da demo
- Entry no `Arcade.Catalog`: `%{id: "quake2_shareware", engine: :quake2, ...}`
- Ícone `icon_game_quake2` em `Icons.Games`

### Sinergia com Pipeline Existente
- GL4ES já é compilado para Qwasm — pode ser compartilhado
- O padrão de build é quase idêntico ao Qwasm, reduzindo esforço
- Mesmo autor = mesma estrutura de Makefile e output

## Current Status

- **Qwasm2**: Ativo, mantido, demo funcional em https://nicholasgasior.com/qwasm2-demo/
- **Maturidade**: Alta — Yamagi Quake II é um dos source ports mais robustos
- **Prioridade**: Alta — complemento natural ao Quake I que já temos, mesmo autor do Qwasm
