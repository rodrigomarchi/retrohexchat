# ScummVM

## Identity

| Campo | Valor |
|-------|-------|
| Nome | ScummVM (+ jogos freeware) |
| Ano | 2001 (engine), jogos de 1990-2000 |
| Gênero | Aventura (Point & Click) |
| Desenvolvedora | ScummVM Team |
| Nossa ID | `scummvm_bass`, `scummvm_fotaq`, `scummvm_lure` (um por jogo) |
| Engine WASM | ScummVM (Emscripten backend oficial) |

## Source & License

| Repo | Licença | Descrição |
|------|---------|-----------|
| [scummvm/scummvm](https://github.com/scummvm/scummvm) | GPL v3 | Engine com backend Emscripten oficial (em `dists/emscripten/`) |

ScummVM suporta **325+ jogos** de aventura. O backend Emscripten é mantido oficialmente
pelo projeto — não é um fork ou port de terceiros.

## Game Data — Jogos Freeware Bundláveis

Estes jogos foram oficialmente liberados como freeware e podem ser redistribuídos:

| Jogo | Ano | Tamanho | Status Legal | Descrição |
|------|-----|---------|-------------|-----------|
| **Beneath a Steel Sky** | 1994 | ~70 MB | Freeware oficial (Revolution Software) | Cyberpunk point & click. Um dos melhores do gênero. |
| **Flight of the Amazon Queen** | 1995 | ~20 MB | Freeware oficial | Aventura cômica estilo Indiana Jones |
| **Lure of the Temptress** | 1992 | ~5 MB | Freeware oficial (Revolution Software) | Aventura medieval, primeiro jogo da Revolution |
| **Drascula: The Vampire Strikes Back** | 1996 | ~30 MB | Freeware oficial | Aventura cômica espanhola, paródia de Drácula |
| **Dreamweb** | 1994 | ~15 MB | Freeware oficial (Creative Reality) | Cyberpunk dark, atmosfera única |
| **Soltys** | 1995 | ~3 MB | Freeware oficial | Aventura puzzle polonesa |

**Total bundlável: ~143 MB** para 6 jogos completos, todos 100% redistribuíveis.

## Technology

- **Engine base**: ScummVM (C++, multi-engine — suporta SCUMM, AGI, SCI, etc.)
- **Port WASM**: Backend Emscripten oficial no source tree (`dists/emscripten/`)
- **Demo online**: https://nicholasgasior.com/scummvm-web/
- **Rendering**: SDL2 → Canvas (2D rendering)
- **Dependências de build**: Emscripten SDK, make, SDL2
- **Áudio**: SDL2_mixer → Web Audio API (suporta MIDI, MP3, OGG)
- **Tamanho do bundle**: ~15 MB (engine) + game data por jogo
- **RAM**: ~50-100 MB por jogo
- **PWA**: O port Emscripten funciona como Progressive Web App

## Integration Plan

**Complexidade: New engine (proven WASM port, official)**

### Build Steps
1. Clonar `scummvm/scummvm`
2. Usar scripts de build em `dists/emscripten/`
3. Configurar engines desejados (SCUMM, SWORD, etc.) via `./configure --enable-engines=...`
4. Build: `emmake make`
5. Output: `index.html`, `scummvm.js`, `scummvm.wasm`

### Game Data (por jogo freeware)
1. Baixar game data de fontes oficiais (ScummVM wiki lista URLs)
2. Cada jogo é um diretório com seus arquivos de dados
3. Packagear cada jogo separadamente: `file_packager.py --preload {game_dir}@/{game_dir}/`
4. Configurar `scummvm.ini` com paths pré-configurados

### Padrão de Integração — Duas Opções

**Opção A: Um ScummVM com game picker (recomendada)**
- Um único build do ScummVM com todos os jogos freeware pré-carregados
- ScummVM já tem UI de seleção de jogos built-in
- Uma entry no Catalog: `%{id: "scummvm", engine: :scummvm}`
- Bundle total: ~160 MB (engine + 6 jogos)

**Opção B: Um entry por jogo**
- Builds separados do ScummVM, cada um com --autostart para um jogo
- Múltiplas entries no Catalog
- Bundles menores mas mais storage total

### Novos Módulos
- `Mix.Tasks.Arcade.BuildScummvmEngine` — compilação do ScummVM
- `Mix.Tasks.Arcade.Data.ScummvmGames` — download de todos os jogos freeware
- Entry(ies) no `Arcade.Catalog`
- Ícone `icon_game_scummvm` em `Icons.Games` (+ opcionalmente ícones por jogo)

### Vantagens
- **Gateway para 325+ jogos**: Se o usuário tiver seus próprios game data, pode usar upload
- **Port oficial**: Mantido pelo projeto ScummVM, não um fork de terceiros
- **6 jogos freeware**: Conteúdo substancial sem nenhuma preocupação legal
- **Gênero único**: Point & click adventures — totalmente diferente de tudo no catálogo

## Current Status

- **ScummVM Emscripten**: Estável, mantido oficialmente, backend no source tree principal
- **Maturidade**: Muito Alta — ScummVM é um dos projetos open-source mais robustos
- **Prioridade**: Alta — acesso a múltiplos jogos com um único engine, gênero totalmente novo
- **Recomendação**: Um dos primeiros a implementar. O ROI é altíssimo — 6 jogos completos com um único build. Beneath a Steel Sky sozinho justifica a integração.
