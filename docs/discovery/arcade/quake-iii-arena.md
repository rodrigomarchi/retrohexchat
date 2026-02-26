# Quake III Arena

## Identity

| Campo | Valor |
|-------|-------|
| Nome | Quake III Arena |
| Ano | 1999 |
| Gênero | FPS (Arena Shooter) |
| Desenvolvedora | id Software |
| Nossa ID | `quake3_demo` |
| Engine WASM | ioquake3.js (JavaScript puro) ou Emscripten port |

## Source & License

| Repo | Licença | Descrição |
|------|---------|-----------|
| [ioquake/ioq3](https://github.com/ioquake/ioq3) | GPL v2 | Source port mantido do Quake III engine |
| [nicholasgasior/goquake3-wasm](https://github.com/nicholasgasior/goquake3-wasm) | GPL v2 | Port Go → WASM (experimental) |
| [nicholasgasior/nicholasgasior.com](https://nicholasgasior.com/goquake3-wasm/) | GPL v2 | Demo online |

Nota: o repo `lrusso/Quake3` mencionado na pesquisa inicial parece ser JavaScript puro,
mas a maturidade é questionável. O ioquake3 é o source port de referência.

## Game Data

| Arquivo | Tamanho | Fonte | Status Legal |
|---------|---------|-------|-------------|
| `baseq3/pak0.pk3` (demo) | ~50 MB | [linuxq3ademo-1.11-6.x86.gz.sh](https://ftp.gwdg.de/pub/misc/ftp.idsoftware.com/quake3/) | Shareware — redistribuível |
| Full game | ~500 MB | Requer compra (Steam/GOG) | Proprietário |

A demo contém mapas de arena suficientes para single-player contra bots.
Nota: Q3A é primariamente multiplayer, mas tem bots com AI decente para solo.

## Technology

- **Engine base**: id Tech 3
- **Port WASM**: Precisa de Emscripten build do ioquake3 (não há port oficial maduro)
- **Alternativa**: Go port (goquake3-wasm) — experimental mas funcional
- **Rendering**: WebGL (OpenGL → WebGL via Emscripten ou GL4ES)
- **Dependências de build**: Emscripten SDK, cmake/make
- **Áudio**: Web Audio API
- **Tamanho do bundle**: ~60-80 MB (engine + demo pk3s)
- **RAM**: ~300-400 MB

## Integration Plan

**Complexidade: New engine (experimental)**

Não há um port WASM maduro e bem-mantido como Dwasm/Qwasm. As opções são:

### Opção A: Emscripten build do ioquake3
1. Fork do ioquake3
2. Adaptar build system para Emscripten (cmake + emcmake)
3. Resolver dependências de OpenGL → WebGL (GL4ES)
4. Trabalho de portabilidade significativo
5. Risco: pode exigir patches extensos

### Opção B: Usar Q3A via Wwasm (iortcw engine)
O engine do Return to Castle Wolfenstein (iortcw) é baseado no id Tech 3 (mesmo que Q3A).
Wwasm já é um port WASM maduro. Potencialmente pode rodar Q3A data com modificações.

### Novos Módulos
- `Mix.Tasks.Arcade.BuildQuake3Engine`
- `Mix.Tasks.Arcade.Data.Quake3Demo`
- Entry no `Arcade.Catalog`
- Ícone `icon_game_quake3`

## Current Status

- **Maturidade do port web**: Baixa — não há port WASM maduro e bem-testado
- **ioquake3**: Engine excelente, mas sem Emscripten backend oficial
- **goquake3-wasm**: Funcional mas experimental, escrito em Go→WASM (performance questionável)
- **Prioridade**: Média — grande valor nostálgico mas integração incerta
- **Recomendação**: Aguardar um port mais maduro ou investir em Return to Castle Wolfenstein primeiro (mesmo engine, port WASM provado via Wwasm)
