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

## Jogos Candidatos

### Referência Rápida

| # | Jogo | Gênero | Complexidade | Prioridade | Doc |
|---|------|--------|-------------|------------|-----|
| 1 | Wolfenstein 3D | FPS | Drop-in (engine próprio) | Alta | [wolfenstein-3d.md](wolfenstein-3d.md) |
| 2 | Quake II | FPS | New engine (Qwasm2) | Alta | [quake-ii.md](quake-ii.md) |
| 3 | Quake III Arena | FPS | New engine (JS puro) | Média | [quake-iii-arena.md](quake-iii-arena.md) |
| 4 | Return to Castle Wolfenstein | FPS | New engine (Wwasm) | Média | [return-to-castle-wolfenstein.md](return-to-castle-wolfenstein.md) |
| 5 | Doom 3 | FPS | New engine (D3wasm) | Baixa | [doom-3.md](doom-3.md) |
| 6 | Half-Life | FPS | New engine (webXash) | Média | [half-life.md](half-life.md) |
| 7 | Duke Nukem 3D | FPS | New engine (emduke32) | Baixa | [duke-nukem-3d.md](duke-nukem-3d.md) |
| 8 | OpenTyrian | Shoot-em-up | New engine (Emscripten) | Alta | [opentyrian.md](opentyrian.md) |
| 9 | Diablo | Action RPG | New engine (DiabloWeb) | Alta | [diablo.md](diablo.md) |
| 10 | NetHack | Roguelike | New engine (NetHackJS) | Média | [nethack.md](nethack.md) |
| 11 | Freeciv | Estratégia 4X | Native web app | Média | [freeciv.md](freeciv.md) |
| 12 | OpenTTD | Simulação | New engine (WASM) | Média | [openttd.md](openttd.md) |
| 13 | SuperTuxKart | Racing | New engine (experimental) | Baixa | [supertuxkart.md](supertuxkart.md) |
| 14 | ScummVM | Aventura | New engine (Emscripten) | Alta | [scummvm.md](scummvm.md) |
| 15 | Simon Tatham's Puzzles | Puzzle | Native web app | Alta | [simon-tatham-puzzles.md](simon-tatham-puzzles.md) |

### Classificação de Complexidade

- **Drop-in** — Mesmo engine já existente, só adicionar game data
- **New engine, proven WASM port** — Precisa de novo módulo `BuildXxxEngine`, mas port é maduro
- **New engine, experimental** — Port existe mas é pesado ou instável
- **Native web app** — HTML5/JS puro, padrão de integração diferente (pode não precisar de WASM)

### Por Categoria

**FPS (7 candidatos)**
Wolfenstein 3D, Quake II, Quake III Arena, Return to Castle Wolfenstein, Doom 3, Half-Life, Duke Nukem 3D

**Arcade / Shoot-em-up (1)**
OpenTyrian / Tyrian 2000

**RPG / Roguelike (2)**
Diablo, NetHack

**Estratégia (2)**
Freeciv, OpenTTD

**Racing (1)**
SuperTuxKart

**Aventura (1)**
ScummVM (gateway para 325+ jogos, bundlar com freeware titles)

**Puzzle (1)**
Simon Tatham's Puzzles (~40 jogos num pacote)

## Licenciamento

Todos os candidatos usam licenças open-source para o engine:

| Licença | Engines |
|---------|---------|
| GPL v2 | Wolfenstein 3D, Quake II/III, Duke Nukem 3D, OpenTyrian, ScummVM, OpenTTD, DOSBox |
| GPL v3 | Return to Castle Wolfenstein, Doom 3, SuperTuxKart, Prince of Persia (SDLPoP) |
| Unlicense | Diablo (DevilutionX) |
| NetHack GPL | NetHack |
| MIT | 2048, Simon Tatham's Puzzles |
| BSD 2-Clause | OpenLara (Tomb Raider) |

**Game data — status legal:**

| Status | Jogos |
|--------|-------|
| Shareware (redistribuível) | DOOM, Quake, Quake II, Wolfenstein 3D, Duke Nukem 3D, Half-Life (Uplink), Diablo |
| Freeware oficial | OpenTyrian/Tyrian 2000, Chex Quest, HacX |
| Open-source completo | Freedoom, LibreQuake, FreeDM, REKKR, NetHack, Freeciv, OpenTTD, SuperTuxKart |
| Freeware (adventure) | Beneath a Steel Sky, Flight of the Amazon Queen, Lure of the Temptress (via ScummVM) |
| MIT/domínio público | 2048, Simon Tatham's Puzzles |

## Menções Adicionais (sem doc individual)

- **2048** — MIT, HTML/JS puro, trivial de hospedar. Pode ser integrado diretamente sem iframe.
- **Brogue** — AGPL v3, roguelike visual elegante. WebBrogue existe mas é nicho.
- **OpenLara** (Tomb Raider) — BSD, WebGL, demo level incluído. Port parcial.
- **Prince of Persia** (1989) — GPL v3 via SDLPoP, compilável para Emscripten via SDL. Sem port pronto.
- **Command & Conquer** — Reimplementação HTML5 fan-made, licenciamento nebuloso.
- **Chrono Divide** (Red Alert 2) — Fan project, browser-native, imaturidade.
- **js-dos / em-dosbox** — GPL v2, DOSBox em WASM. Opção nuclear: roda qualquer jogo DOS.
  Abre acesso a Commander Keen, Epic Pinball, Jazz Jackrabbit (shareware).
  Considerar como plataforma futura caso queiramos dezenas de títulos DOS sem ports individuais.

## Próximos Passos

1. Priorizar os candidatos Alta (Wolfenstein 3D, OpenTyrian, Diablo, ScummVM, Simon Tatham's Puzzles, Quake II)
2. Para cada jogo priorizado: prototipar o build local, medir tamanho do bundle e uso de RAM
3. Implementar novos módulos `BuildXxxEngine` e entradas no `Arcade.Catalog`
4. Expandir a UI do SoloLobby para categorias (FPS, Puzzle, Strategy, etc.)
