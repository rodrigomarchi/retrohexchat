# Wolfenstein 3D

## Identity

| Campo | Valor |
|-------|-------|
| Nome | Wolfenstein 3D |
| Ano | 1992 |
| Gênero | FPS |
| Desenvolvedora | id Software |
| Nossa ID | `wolfenstein_3d` |
| Engine WASM | ECWolf-JS (Emscripten) ou wolf3d-browser (id oficial) |

## Source & License

| Repo | Licença | Descrição |
|------|---------|-----------|
| [id-Software/wolf3d-browser](https://github.com/id-Software/wolf3d-browser) | GPL v2 | Release oficial da id Software para browser |
| [54ac/ecwolf-js](https://github.com/54ac/ecwolf-js) | GPL v2 | ECWolf compilado via Emscripten (mais moderno) |
| [jseidelin/wolf3d](https://github.com/jseidelin/wolf3d) | GPL v2 | Reimplementação HTML5 pura |

O release oficial da id Software (`wolf3d-browser`) é o caminho mais seguro legalmente.

## Game Data

| Arquivo | Tamanho | Fonte | Status Legal |
|---------|---------|-------|-------------|
| `wolf3d.wl6` (shareware) | ~700 KB | Incluído no repo oficial | Shareware — redistribuível |
| Full game data | ~1.4 MB | Requer compra | Proprietário |

O episódio 1 (shareware) contém 10 níveis completos e é suficiente para uma experiência satisfatória.
Os dados shareware estão incluídos diretamente no repositório `wolf3d-browser` da id Software.

## Technology

- **Engine original**: id Tech 0 (Wolfenstein 3D engine)
- **Port WASM**: ECWolf-JS usa Emscripten para compilar o ECWolf (source port moderno do Wolf3D)
- **Port oficial**: `wolf3d-browser` é JavaScript puro, sem WASM — roda nativamente no browser
- **Dependências de build**: Emscripten SDK (para ECWolf-JS) ou nenhuma (para wolf3d-browser)
- **Rendering**: Software rendering (raycasting), Canvas 2D
- **Áudio**: Web Audio API
- **Tamanho do bundle**: ~2-5 MB total (engine + shareware data)
- **RAM**: ~50-100 MB (muito leve)

## Integration Plan

**Complexidade: Drop-in (engine próprio, mas trivial)**

O `wolf3d-browser` da id Software é praticamente um drop-in — é um diretório de arquivos estáticos
que pode ser copiado para `priv/static/arcade/wolfenstein_3d/`.

### Opção A: wolf3d-browser (recomendada)
1. Clonar `id-Software/wolf3d-browser`
2. Copiar os arquivos para `priv/static/arcade/wolfenstein_3d/`
3. Ajustar `index.html` se necessário (dimensões do canvas, fullscreen)
4. Não precisa de Emscripten — já é JavaScript puro
5. Novo módulo de build seria trivial (download + copy)

### Opção B: ECWolf-JS
1. Clonar `54ac/ecwolf-js`
2. Compilar com Emscripten (cmake + emcmake)
3. Packagar com `file_packager.py` como fazemos com Doom/Quake
4. Mais fiel ao pipeline existente, mas mais complexo

### Integração no sistema
- Novo entry no `Arcade.Catalog` com `engine: :wolfenstein`
- Novo módulo `BuildWolfensteinData` (download shareware data)
- Se Opção A: módulo de build simplificado (clone + copy, sem compilação)
- Se Opção B: novo `BuildWolfensteinEngine` seguindo padrão Dwasm/Qwasm
- Novo ícone `icon_game_wolfenstein` em `Icons.Games`

## Current Status

- **wolf3d-browser**: Estável, release oficial, mas JavaScript antigo (2012). Funciona em browsers modernos.
- **ECWolf-JS**: Ativo, mantido, compilação Emscripten testada. Suporta mods e episódios adicionais.
- **Maturidade**: Alta — o avô dos FPS, amplamente testado em browsers.
- **Prioridade**: Alta — deploy trivial, nostalgia máxima, bundle minúsculo.
