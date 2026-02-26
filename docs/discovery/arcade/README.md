# Solo Arcade — Discovery & Expansion

## O que é o Solo Arcade

O Solo Arcade é o sistema de jogos single-player da plataforma RetroHexChat. Jogos clássicos
compilados para WebAssembly rodam diretamente no browser, dentro de um iframe, sem plugins ou
instalação. O usuário acessa via `/singleplayer`, escolhe um jogo no lobby, e o engine WASM
carrega com os game data pré-empacotados.

## Arquitetura Atual

```
/singleplayer → SoloSessionLive → SoloLobby (game picker)
                                → ArcadeFrame (iframe)
                                    ↓
                        priv/static/arcade/{game_id}/
                            index.html   ← shell HTML
                            index.js     ← Emscripten glue + data loader
                            index.wasm   ← engine compilado
                            index.data   ← filesystem virtual (WADs/PAKs)
```

**Build pipeline:** `mix arcade.build` executa 3 estágios:
1. **Engine compilation** — clona repo do port WASM, compila com Emscripten + GL4ES
2. **Game data download** — baixa WADs/PAKs de fontes oficiais
3. **Packaging** — combina engine + data via `file_packager.py`, gera output final

Cada engine novo requer um módulo `BuildXxxEngine` no mix task. Cada jogo novo requer um módulo
de download de game data e uma entrada no `Arcade.Catalog`.

## Jogos Atuais (9 jogos, 2 engines)

| Engine | Game ID | Nome | Data Source |
|--------|---------|------|-------------|
| Dwasm (PrBoom+) | `doom_shareware` | DOOM: Knee-Deep in the Dead | doom1.wad (shareware) |
| Dwasm (PrBoom+) | `freedoom1` | Freedoom: Phase 1 | freedoom1.wad (BSD) |
| Dwasm (PrBoom+) | `freedoom2` | Freedoom: Phase 2 | freedoom2.wad (BSD) |
| Dwasm (PrBoom+) | `freedm` | FreeDM | freedm.wad (BSD) |
| Dwasm (PrBoom+) | `chex_quest` | Chex Quest | chex.wad (freeware) |
| Dwasm (PrBoom+) | `hacx` | HacX: Twitch 'n Kill | hacx.wad (freeware) |
| Dwasm (PrBoom+) | `rekkr` | REKKR: Sunken Land | rekkrsa.wad (freeware) |
| Qwasm (QuakeSpasm) | `quake_shareware` | Quake: Dimension of the Doomed | id1/pak0.pak (shareware) |
| Qwasm (QuakeSpasm) | `librequake` | LibreQuake | lq1/pak0+pak1.pak (GPL) |

## Jogos Candidatos (WASM estáveis)

Critério: apenas jogos com ports WebAssembly provados e funcionais em produção.

### Referência Rápida

| # | Jogo | Gênero | Complexidade | Prioridade | Doc |
|---|------|--------|-------------|------------|-----|
| 1 | Wolfenstein 3D | FPS | Drop-in (engine próprio) | Alta | [wolfenstein-3d.md](wolfenstein-3d.md) |
| 2 | Quake II | FPS | New engine (Qwasm2) | Alta | [quake-ii.md](quake-ii.md) |
| 3 | Return to Castle Wolfenstein | FPS | New engine (Wwasm) | Média | [return-to-castle-wolfenstein.md](return-to-castle-wolfenstein.md) |
| 4 | Doom 3 | FPS / Horror | New engine (D3wasm) | Média | [doom-3.md](doom-3.md) |
| 5 | Half-Life | FPS | New engine (webXash) | Média | [half-life.md](half-life.md) |
| 6 | OpenTyrian | Shoot-em-up | New engine (Emscripten) | Alta | [opentyrian.md](opentyrian.md) |
| 7 | Diablo | Action RPG | New engine (DiabloWeb) | Alta | [diablo.md](diablo.md) |
| 8 | ScummVM | Aventura | New engine (Emscripten) | Alta | [scummvm.md](scummvm.md) |
| 9 | Simon Tatham's Puzzles | Puzzle | WASM oficial | Alta | [simon-tatham-puzzles.md](simon-tatham-puzzles.md) |

### Classificação de Complexidade

- **Drop-in** — Mesmo engine já existente ou deploy trivial (arquivos estáticos)
- **New engine, proven WASM port** — Precisa de novo módulo `BuildXxxEngine`, mas port é maduro e testado

### Por Categoria

**FPS (4 candidatos)**
Wolfenstein 3D, Quake II, Return to Castle Wolfenstein, Doom 3, Half-Life

**Arcade / Shoot-em-up (1)**
OpenTyrian / Tyrian 2000

**Action RPG (1)**
Diablo

**Aventura (1)**
ScummVM (gateway para 325+ jogos, bundlar com freeware titles)

**Puzzle (1)**
Simon Tatham's Puzzles (~40 jogos num pacote)

## Licenciamento

Todos os candidatos usam licenças open-source para o engine:

| Licença | Engines |
|---------|---------|
| GPL v2 | Wolfenstein 3D, Quake II, OpenTyrian, ScummVM |
| GPL v3 | Return to Castle Wolfenstein, Doom 3 |
| Unlicense | Diablo (DevilutionX) |
| MIT | Simon Tatham's Puzzles |

**Game data — status legal:**

| Status | Jogos |
|--------|-------|
| Shareware (redistribuível) | DOOM, Quake, Quake II, Wolfenstein 3D, Half-Life (Uplink), Diablo |
| Freeware oficial | OpenTyrian/Tyrian 2000, Chex Quest, HacX |
| Open-source completo | Freedoom, LibreQuake, FreeDM, REKKR, Simon Tatham's Puzzles |
| Freeware (adventure) | Beneath a Steel Sky, Flight of the Amazon Queen, Lure of the Temptress (via ScummVM) |

## Próximos Passos

1. Priorizar os candidatos Alta (Wolfenstein 3D, OpenTyrian, Diablo, ScummVM, Simon Tatham's Puzzles, Quake II)
2. Para cada jogo priorizado: prototipar o build local, medir tamanho do bundle e uso de RAM
3. Implementar novos módulos `BuildXxxEngine` e entradas no `Arcade.Catalog`
4. Expandir a UI do SoloLobby para categorias (FPS, Puzzle, Strategy, etc.)
