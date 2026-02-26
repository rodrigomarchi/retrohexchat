# Simon Tatham's Portable Puzzle Collection

## Identity

| Campo | Valor |
|-------|-------|
| Nome | Simon Tatham's Portable Puzzle Collection |
| Ano | 2004 (desenvolvimento contínuo) |
| Gênero | Puzzle (coleção de ~40 jogos) |
| Desenvolvedora | Simon Tatham |
| Nossa ID | `puzzles` (ou um entry por puzzle) |
| Engine | JavaScript/WASM nativo (build oficial) |

## Source & License

| Repo | Licença | Descrição |
|------|---------|-----------|
| [chrisboyle/sgtpuzzles](https://github.com/chrisboyle/sgtpuzzles) | MIT | Mirror/fork com builds CI |
| Source oficial | MIT | https://www.chiark.greenend.org.uk/~sgtatham/puzzles/ |

**Licença MIT** — a mais permissiva possível. Pode redistribuir, modificar, comercializar.

## Game Data

| Arquivo | Tamanho | Fonte | Status Legal |
|---------|---------|-------|-------------|
| Coleção completa (~40 puzzles) | ~2-5 MB total | Build oficial ou compilação | **MIT** — totalmente livre |

Não há game data separado. Cada puzzle é auto-contido — geração procedural de níveis.
O jogo inteiro são poucos MB.

## Lista de Puzzles Incluídos (~40)

| Puzzle | Tipo |
|--------|------|
| Mines | Minesweeper |
| Solo | Sudoku |
| Bridges | Connect islands |
| Loopy | Slitherlink |
| Galaxies | Galaxy puzzle |
| Net | Rotate pipes to connect |
| Fifteen | Sliding puzzle |
| Towers | Latin square com torres |
| Unequal | Futoshiki |
| Map | 4-color map coloring |
| Keen | KenKen |
| Filling | Fillomino |
| Signpost | Number path |
| Pattern | Nonogram/Picross |
| Pearl | Masyu |
| Tracks | Rail tracks |
| Range | Kuromasu |
| Dominosa | Domino placement |
| Mosaic | Minesweeper variant |
| Undead | Mirror puzzle |
| ... e mais ~20 outros |

## Technology

- **Engine base**: C com frontends portáteis (GTK, Windows, JavaScript)
- **Port WASM**: Build oficial Emscripten mantido pelo autor
- **Demo online**: https://www.chiark.greenend.org.uk/~sgtatham/puzzles/js/
- **Rendering**: Canvas 2D (cada puzzle renderiza em um canvas)
- **Dependências de build**: Emscripten SDK, cmake
- **Áudio**: Nenhum
- **Tamanho do bundle**: ~2-5 MB (todos os puzzles juntos)
- **RAM**: ~10-20 MB (extremamente leve)

## Integration Plan

**Complexidade: Native web app (build oficial, trivial)**

### Opção A: Puzzles individuais (recomendada para UX)
1. Compilar cada puzzle como JavaScript/WASM standalone
2. Cada puzzle gera um `{puzzle_name}.html` + `.js` auto-contido
3. No Catalog, uma entry por puzzle ou uma entry com sub-seleção

### Opção B: Todos numa página
1. Copiar os builds oficiais de https://www.chiark.greenend.org.uk/~sgtatham/puzzles/js/
2. Cada `.html` é ~100-200 KB, auto-contido
3. Servir como static files em `priv/static/arcade/puzzles/{name}.html`

### Build Steps
1. Clonar source oficial ou usar builds pré-compilados
2. `emcmake cmake` + `make` → gera um `.html`/`.js` por puzzle
3. Copiar outputs para `priv/static/arcade/puzzles/`

### Novos Módulos
- `Mix.Tasks.Arcade.BuildPuzzlesEngine` — compilação (ou download de builds prontos)
- Entry no `Arcade.Catalog` (ver opções abaixo)
- Ícone `icon_game_puzzles` em `Icons.Games`

### Padrão de Catalog

**Opção 1: Uma entry "Puzzles" com seletor interno**
- `%{id: "puzzles", engine: :puzzles}` → abre puzzle picker
- Precisa de UI custom no SoloLobby para seleção de puzzle
- Mais limpo no catálogo principal

**Opção 2: Entries individuais (top 10-15 puzzles)**
- `%{id: "puzzle_mines", engine: :puzzles}`, `%{id: "puzzle_solo", ...}`, etc.
- Mais entries no lobby mas sem UI custom
- Pode poluir o catálogo se forem 40 puzzles

**Recomendação**: Opção 1 com top 15 puzzles disponíveis.

## Current Status

- **Build oficial**: Mantido pelo autor, sempre atualizado
- **Maturidade**: Muito Alta — décadas de desenvolvimento, build web é first-class
- **Prioridade**: Alta — ROI espetacular: ~40 jogos em ~5 MB, MIT, build trivial
- **Diferencial**: Diversidade massiva de puzzles, bundle mínimo, geração procedural = infinito replay. Perfeito para sessões curtas. Complementa os FPS pesados com algo leve e casual.
