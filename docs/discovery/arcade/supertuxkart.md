# SuperTuxKart

## Identity

| Campo | Valor |
|-------|-------|
| Nome | SuperTuxKart |
| Ano | 2004 (desenvolvimento contínuo) |
| Gênero | Racing / Kart |
| Desenvolvedora | SuperTuxKart community |
| Nossa ID | `supertuxkart` |
| Engine WASM | STK WASM (experimental, Emscripten) |

## Source & License

| Repo | Licença | Descrição |
|------|---------|-----------|
| [ading2210/stk-code](https://github.com/ading2210/stk-code) (wasm branch) | GPL v3 | Fork com build Emscripten |
| [supertuxkart/stk-code](https://github.com/supertuxkart/stk-code) | GPL v3 | Source oficial |
| [supertuxkart/stk-assets](https://github.com/supertuxkart/stk-assets) | Various (CC-BY-SA, GPL, etc.) | Assets do jogo |

Todos os assets são livres (Creative Commons, GPL).

## Game Data

| Arquivo | Tamanho | Fonte | Status Legal |
|---------|---------|-------|-------------|
| Assets completos | ~600 MB (comprimido: ~120 MB) | [supertuxkart.net](https://supertuxkart.net/) | **Livre** — CC-BY-SA + GPL |

Todos os assets (pistas, karts, texturas, sons, músicas) são open-source/Creative Commons.
Zero dados proprietários.

## Technology

- **Engine base**: SuperTuxKart (C++, Irrlicht 3D engine + Bullet physics)
- **Port WASM**: Experimental — compilado via Emscripten
- **Demo online**: https://nicholasgasior.com/stk-web-demo/
- **Rendering**: WebGL 2 (shaders GLSL, shadow mapping)
- **Dependências de build**: Emscripten SDK, cmake, muitas bibliotecas (Irrlicht, Bullet, OpenAL, etc.)
- **Áudio**: OpenAL → Web Audio API
- **Tamanho do bundle**: ~120 MB comprimido (~600 MB descomprimido)
- **RAM**: ~500-700 MB

## Integration Plan

**Complexidade: New engine (experimental, pesado)**

### Build Steps
1. Clonar fork `ading2210/stk-code` (branch wasm)
2. Baixar stk-assets
3. Build com Emscripten: `emcmake cmake` + `make` (build complexo com muitas dependências)
4. Packagear assets selecionados (não todos — reduzir bundle)
5. Output: `index.html`, `stk.js`, `stk.wasm`, `stk.data`

### Novos Módulos
- `Mix.Tasks.Arcade.BuildStkEngine` — compilação complexa
- `Mix.Tasks.Arcade.Data.StkAssets` — download e seleção de assets
- Entry no `Arcade.Catalog`: `%{id: "supertuxkart", engine: :stk, ...}`
- Ícone `icon_game_stk` em `Icons.Games`

### Desafios Significativos
- **Bundle massivo**: 120 MB download — loading lento
- **RAM**: 500-700 MB — excluí dispositivos com pouca memória
- **Build complexo**: Muitas dependências C++ para compilar via Emscripten
- **Performance**: 3D rendering pesado — pode ter FPS baixo em hardware modesto
- **Input**: Gamepad ideal, teclado funciona mas subótimo
- **Experimental**: O port WASM não é oficialmente suportado pelo projeto
- **Networking**: Sem suporte a multiplayer no WASM port

## Current Status

- **STK WASM**: Experimental, funcional mas com problemas de performance e rendering
- **STK upstream**: Muito ativo, releases frequentes, comunidade grande
- **Maturidade**: Baixa (port WASM) / Alta (jogo base)
- **Prioridade**: Baixa — jogo excelente mas o port WASM é pesado, lento e experimental
- **Recomendação**: Monitorar progresso do port WASM. Não priorizar para implementação agora — investir em jogos mais leves primeiro. Reavaliar quando o port amadurecer.
