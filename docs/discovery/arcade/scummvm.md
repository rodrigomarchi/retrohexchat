# ScummVM

## Identity

| Campo | Valor |
|-------|-------|
| Nome | ScummVM (+ jogos freeware) |
| Ano | 2001 (engine), jogos de 1990–1996 |
| Gênero | Aventura (Point & Click) |
| Desenvolvedora | ScummVM Team |
| Engine WASM | ScummVM (Emscripten backend oficial em `dists/emscripten/`) |

## Source & License

| Repo | Licença | Descrição |
|------|---------|-----------|
| [scummvm/scummvm](https://github.com/scummvm/scummvm) | GPL v3 | Engine com backend Emscripten oficial |
| [chkuendig/scummvm-demo](https://github.com/chkuendig/scummvm-demo) | — | CI/deploy de referência (GitHub Actions) |

O backend Emscripten é mantido oficialmente pelo projeto ScummVM — não é um fork
ou port de terceiros. O build system vive em `dists/emscripten/`.

## Jogos Freeware (um .md por jogo)

| Jogo | Engine ID | ScummVM GameID | Tamanho (CD) | Doc |
|------|-----------|----------------|--------------|-----|
| Beneath a Steel Sky | `sky` | `sky` | ~66 MB | [scummvm-bass.md](scummvm-bass.md) |
| Flight of the Amazon Queen | `queen` | `queen` | ~34 MB | [scummvm-fotaq.md](scummvm-fotaq.md) |
| Lure of the Temptress | `lure` | `lure` | ~5 MB | [scummvm-lure.md](scummvm-lure.md) |
| Drascula: The Vampire Strikes Back | `drascula` | `drascula` | ~59 MB | [scummvm-drascula.md](scummvm-drascula.md) |
| Dreamweb | `dreamweb` | `dreamweb` | ~165 MB | [scummvm-dreamweb.md](scummvm-dreamweb.md) |
| Soltys | `cge` | `soltys` | ~4 MB | [scummvm-soltys.md](scummvm-soltys.md) |

**Total game data: ~333 MB** (versões CD com vozes quando disponível) + ~15 MB engine WASM ≈ **~348 MB total**.

Nota: Lure of the Temptress e Soltys só existem em versão floppy.

## Technology

- **Engine base**: ScummVM (C++, multi-engine architecture com plugins dinâmicos)
- **Port WASM**: Backend Emscripten oficial (`dists/emscripten/`)
- **emsdk**: 4.0.10+ (padrão do build.sh, overridável via env var)
- **Build script**: `./dists/emscripten/build.sh` — pipeline: setup → libs → configure → make → games → dist → add-games → icons
- **Rendering**: SDL2 → Canvas (2D)
- **Áudio**: SDL2_mixer → Web Audio API (MIDI, MP3, OGG, FLAC)
- **Game data loading**: HTTP virtual filesystem (`backends/fs/emscripten/http-fs.cpp`)
- **Libs compiladas no build**: a52dec, faad2, fluidlite, fribidi, libmad, libmpeg2, libmpcdec, libopenmpt, RetroWave, libtheora, libvpx
- **Demo de referência**: https://scummvm.kuendig.io/

## Build Architecture

### HTTP Virtual Filesystem (chave da integração)

ScummVM Emscripten **NÃO usa `file_packager.py` para game data**. Em vez disso, usa
um filesystem virtual HTTP implementado em `backends/fs/emscripten/http-fs.cpp`:

1. Cada diretório de game data precisa de um `index.json` gerado por `build-make_http_index.py`
2. Formato: `{"filename.dat": 12345, "subdir": {}}` (keys = nomes, values = tamanho ou `{}` para dirs)
3. ScummVM faz `fetch()` sob demanda quando precisa de um arquivo
4. Arquivos ficam cached em `/.cache/` no virtual FS

**Implicação**: game data é servido como **static files** do nosso servidor Phoenix,
não embedado no WASM. Cada jogo é um diretório com seus arquivos + `index.json`.

### Build Steps

```bash
# 1. Clonar ScummVM
git clone --depth 1 https://github.com/scummvm/scummvm.git

# 2. Build com apenas os engines necessários (plugins dinâmicos)
cd scummvm
./dists/emscripten/build.sh build --verbose \
  --disable-all-engines --enable-plugins --default-dynamic \
  --enable-engine=sky,queen,lure,drascula,dreamweb,cge

# 3. Gerar distribuição
./dists/emscripten/build.sh dist

# Output em dists/emscripten/dist/:
#   scummvm.html (custom shell)
#   scummvm.js + scummvm.wasm (engine)
#   scummvm.worker.js (web worker)
#   plugins/*.wasm (engine plugins: sky.wasm, queen.wasm, etc.)
#   data/ (scummvm.dat, gui-icons.dat, translations.dat, etc.)
```

### Game Data Setup

```bash
# 4. Para cada jogo freeware, criar diretório com game data
mkdir -p games/bass games/fotaq games/lure games/drascula games/dreamweb games/soltys

# 5. Baixar e extrair game data em cada diretório (ver .md de cada jogo)

# 6. Gerar index.json para cada diretório
python3 dists/emscripten/build-make_http_index.py games/

# 7. Configurar scummvm.ini com paths para cada jogo
# O build.sh task "add-games" faz isso automaticamente,
# ou podemos gerar manualmente
```

### Output Structure (no nosso priv/static/arcade/)

```
priv/static/arcade/scummvm/
├── index.html                    # custom shell (renomeado de scummvm.html)
├── scummvm.js                    # engine glue
├── scummvm.wasm                  # engine binary
├── scummvm.worker.js             # web worker (se usado)
├── plugins/                      # engine plugins (dinâmicos)
│   ├── sky.wasm
│   ├── queen.wasm
│   ├── lure.wasm
│   ├── drascula.wasm
│   ├── dreamweb.wasm
│   └── cge.wasm
├── data/                         # engine shared data
│   ├── scummvm.dat
│   ├── gui-icons.dat
│   ├── translations.dat
│   └── index.json
└── games/                        # game data (HTTP filesystem)
    ├── bass/
    │   ├── SKY.DNR, SKY.DSK, ...
    │   └── index.json
    ├── fotaq/
    │   ├── QUEEN.1
    │   └── index.json
    ├── lure/
    │   ├── lure.dat, disk1.vga, ...
    │   └── index.json
    ├── drascula/
    │   ├── PACKET.001, ...
    │   └── index.json
    ├── dreamweb/
    │   ├── DREAMWEB.*, ...
    │   └── index.json
    ├── soltys/
    │   ├── SOLTYS.*, ...
    │   └── index.json
    └── index.json
```

### Auto-start por Jogo

O `custom_shell-pre.js` do ScummVM extrai parâmetros do **URL fragment** (`#param`).
Isso permite auto-start de um jogo específico:

```
/arcade/scummvm/index.html#-p /games/bass/ sky
```

Onde:
- `-p /games/bass/` = path dos game data
- `sky` = game ID para iniciar diretamente

Cada entry no Catalog pode apontar para a mesma `index.html` com fragment diferente.

## Integration Pattern

**Padrão: Engine compartilhado + HTTP filesystem (novo padrão D)**

Este é um padrão novo no nosso arcade, diferente dos 3 existentes:

| Aspecto | ScummVM (D) | DOOM (A) | Quake II (B) | Half-Life (C) |
|---------|-------------|----------|------------|---------------|
| Engine build | Uma vez | Uma vez | Com game data | Pre-compiled |
| Game data | HTTP on-demand | file_packager | Embedado | ZIP runtime |
| Múltiplos jogos | Sim, compartilhado | Sim, repackage | Não | Não |
| Tamanho por jogo | ~engine + data individual | engine + .data | Tudo junto | Tudo + zip |

### Vantagens deste padrão
- **6 jogos, 1 engine build** — máximo ROI
- **Game data servido on-demand** — não precisa baixar tudo para jogar 1 jogo
- **Extensível** — adicionar novos jogos é só colocar game data + index.json
- **Cache-friendly** — engine cached pelo browser, só game data muda

### Novos Módulos — Build independente por jogo

**Cada jogo tem seu próprio mix task de build**, seguindo o padrão do projeto
(como `BuildQuake2Engine`, `BuildWolf3dEngine`, `BuildXashEngine`). Não existe
build big-bang — cada jogo pode ser buildado e testado isoladamente.

```
apps/retro_hex_chat_web/lib/mix/tasks/arcade/
├── build_scummvm_engine.ex              # Compila ScummVM engine (compartilhado)
├── build_scummvm_bass.ex                # mix arcade.build_scummvm_bass
├── build_scummvm_fotaq.ex               # mix arcade.build_scummvm_fotaq
├── build_scummvm_lure.ex                # mix arcade.build_scummvm_lure
├── build_scummvm_drascula.ex            # mix arcade.build_scummvm_drascula
├── build_scummvm_dreamweb.ex            # mix arcade.build_scummvm_dreamweb
├── build_scummvm_soltys.ex              # mix arcade.build_scummvm_soltys
└── game_data/
    ├── scummvm_bass.ex                  # Download Beneath a Steel Sky CD
    ├── scummvm_fotaq.ex                 # Download Flight of the Amazon Queen Talkie
    ├── scummvm_lure.ex                  # Download Lure of the Temptress
    ├── scummvm_drascula.ex              # Download Drascula + Audio MP3
    ├── scummvm_dreamweb.ex              # Download Dreamweb CD UK
    └── scummvm_soltys.ex               # Download Soltys
```

**Cada `build_scummvm_{game}.ex`:**
1. Verifica se o engine ScummVM já está compilado (chama `BuildScummvmEngine` se necessário)
2. Baixa game data específico desse jogo (chama `GameData.Scummvm{Game}`)
3. Gera `index.json` para HTTP filesystem
4. Monta o diretório final em `priv/static/arcade/scummvm_{game}/`
5. Pode ser executado isoladamente: `mix arcade.build_scummvm_bass`

**O orquestrador `build.ex`** chama cada um quando `--only scummvm` é usado,
mas cada jogo pode ser buildado independentemente.

- 6 entries no `Arcade.Catalog` (uma por jogo, todas com `engine: :scummvm`)
- `game_url/1` retorna URL com fragment para auto-start
- Ícones: `icon_game_scummvm` (genérico) + opcionalmente um por jogo

## Catalog Entries

```elixir
# Todas compartilham engine: :scummvm
# game_url retorna: /arcade/scummvm/index.html#-p /games/{dir}/ {gameid}

%{id: "scummvm_bass",      name: "Beneath a Steel Sky",              engine: :scummvm}
%{id: "scummvm_fotaq",     name: "Flight of the Amazon Queen",       engine: :scummvm}
%{id: "scummvm_lure",      name: "Lure of the Temptress",            engine: :scummvm}
%{id: "scummvm_drascula",  name: "Drascula: The Vampire Strikes Back", engine: :scummvm}
%{id: "scummvm_dreamweb",  name: "Dreamweb",                         engine: :scummvm}
%{id: "scummvm_soltys",    name: "Soltys",                           engine: :scummvm}
```

## Current Status

- **ScummVM Emscripten**: Estável, mantido oficialmente, backend no source tree principal
- **Maturidade**: Muito Alta — ScummVM é um dos projetos open-source mais robustos (20+ anos)
- **Prioridade**: Alta — 6 jogos completos com 1 build, gênero totalmente novo no catálogo
- **Recomendação**: Implementar próximo. O ROI é o mais alto de qualquer engine — 6 jogos freeware com um único build de ~15 MB
