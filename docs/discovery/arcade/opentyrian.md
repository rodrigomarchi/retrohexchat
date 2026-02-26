# OpenTyrian / Tyrian 2000

## Identity

| Campo | Valor |
|-------|-------|
| Nome | OpenTyrian (Tyrian 2000) |
| Ano | 1995 (original), 2007 (freeware release) |
| Gênero | Vertical Scrolling Shooter (Shoot-em-up) |
| Desenvolvedora | Eclipse Productions (original) |
| Nossa ID | `tyrian` |
| Engine WASM | OpenTyrian (SDL → Emscripten) |

## Source & License

| Repo | Licença | Descrição |
|------|---------|-----------|
| [opentyrian/opentyrian](https://github.com/opentyrian/opentyrian) | GPL v2 (engine) | Port open-source do Tyrian |
| [KScl/opentyrian2000](https://github.com/KScl/opentyrian2000) | GPL v2 (engine) | Fork com melhorias de Tyrian 2000 |

**Game data é oficialmente freeware** — liberado pelos desenvolvedores originais.
Não há nenhuma restrição legal para redistribuição dos assets.

## Game Data

| Arquivo | Tamanho | Fonte | Status Legal |
|---------|---------|-------|-------------|
| Tyrian 2000 data | ~8 MB | Incluído no release freeware | **Freeware oficial** — 100% redistribuível |

Os dados do jogo foram oficialmente liberados como freeware pela World Tree Games/Epic MegaGames.
Estão incluídos nos releases do OpenTyrian. Zero problemas legais.

## Technology

- **Engine base**: OpenTyrian (C, SDL 1.2/2.0)
- **Port WASM**: Compilável via Emscripten (SDL é suportado nativamente)
- **Demo online**: https://playtyrian.com/
- **Rendering**: Software rendering via SDL surface → Canvas
- **Dependências de build**: Emscripten SDK, SDL2 (Emscripten port)
- **Áudio**: SDL_mixer → Web Audio API
- **Tamanho do bundle**: ~10-12 MB total (engine + game data)
- **RAM**: ~30-50 MB (extremamente leve)

## Integration Plan

**Complexidade: New engine (proven, trivial build)**

OpenTyrian usa SDL, que tem suporte nativo no Emscripten. A compilação é direta.

### Build Steps
1. Clonar `opentyrian/opentyrian` ou `KScl/opentyrian2000`
2. Configurar build para Emscripten: `emcmake cmake` ou `emmake make`
3. SDL2 é provido pelo Emscripten automaticamente (`-sUSE_SDL=2`)
4. Output: `index.html`, `opentyrian.js`, `opentyrian.wasm`

### Game Data
1. Game data já está incluído no repo do OpenTyrian
2. Packagear com `file_packager.py --preload data/@data/`
3. Sem download externo necessário

### Novos Módulos
- `Mix.Tasks.Arcade.BuildTyrianEngine` — compilação do OpenTyrian
- Não precisa de módulo de data separado (incluído no repo)
- Entry no `Arcade.Catalog`: `%{id: "tyrian", engine: :tyrian, ...}`
- Ícone `icon_game_tyrian` em `Icons.Games`

### Vantagens
- **Bundle minúsculo**: ~10 MB — o mais leve dos candidatos
- **Zero problemas legais**: Engine GPL + data freeware oficial
- **Gameplay excelente**: Considerado um dos melhores shmups da era DOS
- **Build trivial**: SDL → Emscripten é caminho bem trilhado
- **Diversidade**: Único shoot-em-up, diversifica o catálogo além de FPS

## Current Status

- **OpenTyrian**: Mantido ativamente, última release recente
- **playtyrian.com**: Demo online estável e completa
- **Maturidade**: Alta — port web funciona perfeitamente
- **Prioridade**: Alta — bundle mínimo, zero riscos legais, gameplay viciante, diversifica o catálogo
- **Recomendação**: Um dos primeiros a implementar. Esforço mínimo, retorno máximo.
