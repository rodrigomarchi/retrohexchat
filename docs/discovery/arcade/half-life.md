# Half-Life

## Identity

| Campo | Valor |
|-------|-------|
| Nome | Half-Life |
| Ano | 1998 |
| Gênero | FPS |
| Desenvolvedora | Valve |
| Nossa ID | `halflife_uplink` |
| Engine WASM | webXash (Xash3D-FWGS → Emscripten) |

## Source & License

| Repo | Licença | Descrição |
|------|---------|-----------|
| [x8BitRain/webXash](https://github.com/x8BitRain/webXash) | GPL v2 | Xash3D-FWGS compilado para Emscripten |
| [btarg/Xash3D-Emscripten](https://github.com/btarg/Xash3D-Emscripten) | GPL v2 | Fork alternativo do Xash3D para Emscripten |
| [AhmadNarworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworworwor| [FWGS/xash3d-fwgs](https://github.com/FWGS/xash3d-fwgs) | GPL v2 | Engine base (reimplementação do GoldSource) |

Xash3D-FWGS é uma reimplementação open-source do engine GoldSource da Valve.
O webXash é o port mais maduro para Emscripten.

## Game Data

| Arquivo | Tamanho | Fonte | Status Legal |
|---------|---------|-------|-------------|
| Half-Life: Uplink (demo) | ~35 MB | [moddb/fileplanet](https://www.moddb.com/games/half-life/downloads/half-life-uplink) | Demo gratuita oficial — redistribuível |
| Half-Life: Hazard Course | ~20 MB | Incluído na demo | Demo — redistribuível |
| Half-Life Deathmatch | ~30 MB | Incluído em algumas versões | Freeware (standalone) |
| Full game | ~200 MB | Requer compra (Steam) | Proprietário |

**Half-Life: Uplink** é uma demo standalone oficial da Valve com missões exclusivas (não presentes
no jogo completo), tornando-a um conteúdo único e redistribuível.

## Technology

- **Engine base**: Xash3D-FWGS (reimplementação do GoldSource/Half-Life engine)
- **Port WASM**: webXash compila via Emscripten
- **Demo online**: https://x8bitrain.github.io/webXash/
- **Rendering**: WebGL (software OpenGL → WebGL)
- **Dependências de build**: Emscripten SDK, cmake, python3
- **Áudio**: Web Audio API via SDL2
- **Tamanho do bundle**: ~50-60 MB (engine + Uplink demo)
- **RAM**: ~200-300 MB
- **Extras**: Suporta mods do GoldSource (Counter-Strike 1.6, Team Fortress Classic, etc.)

## Integration Plan

**Complexidade: New engine (proven WASM port)**

### Build Steps
1. Clonar `x8BitRain/webXash` (inclui scripts de build para Emscripten)
2. Build com Emscripten: `emcmake cmake` + `make`
3. Output: `index.html`, `xash.js`, `xash.wasm`

### Game Data
1. Baixar Half-Life: Uplink demo
2. Extrair diretório `valve_uplink/` (ou `valve/` dependendo da versão)
3. Packagear com `file_packager.py`

### Novos Módulos
- `Mix.Tasks.Arcade.BuildXashEngine` — compilação do webXash
- `Mix.Tasks.Arcade.Data.HalfLifeUplink` — download da demo Uplink
- Entry no `Arcade.Catalog`: `%{id: "halflife_uplink", engine: :xash3d, ...}`
- Ícone `icon_game_halflife` em `Icons.Games`

### Potencial Futuro
O Xash3D abre portas para outros jogos GoldSource:
- Counter-Strike 1.6 (se assets forem providenciados pelo usuário)
- Day of Defeat
- Natural Selection
- Sven Co-op
Mas estes requerem assets proprietários — Uplink é o único 100% redistribuível.

## Current Status

- **webXash**: Funcional, demo online jogável, última atualização recente
- **Maturidade**: Média-Alta — funciona bem mas com quirks ocasionais de input/áudio
- **Prioridade**: Média — grande valor nostálgico, bundle razoável, mas engine menos polido que Dwasm/Qwasm
- **Diferencial**: Uplink tem conteúdo exclusivo (não presente no jogo full), o que é um atrativo interessante
