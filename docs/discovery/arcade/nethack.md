# NetHack

## Identity

| Campo | Valor |
|-------|-------|
| Nome | NetHack |
| Ano | 1987 (primeira release), desenvolvimento contínuo |
| Gênero | Roguelike |
| Desenvolvedora | The NetHack DevTeam |
| Nossa ID | `nethack` |
| Engine WASM | NetHackJS (NetHack → Emscripten) |

## Source & License

| Repo | Licença | Descrição |
|------|---------|-----------|
| [apowers313/NetHackJS](https://github.com/apowers313/NetHackJS) | NGPL (NetHack General Public License) | NetHack compilado para WASM via Emscripten |
| [NetHack/NetHack](https://github.com/NetHack/NetHack) | NGPL | Source oficial do NetHack |

A NetHack General Public License é permissiva (similar a MIT) — permite redistribuição
e modificação com atribuição.

## Game Data

| Arquivo | Tamanho | Fonte | Status Legal |
|---------|---------|-------|-------------|
| Jogo completo | ~5 MB | Incluído no source | **Livre** — sem assets proprietários |

NetHack é 100% open-source. Não há game data separado — tudo é gerado proceduralmente
ou incluído no source code. Zero preocupações legais.

## Technology

- **Engine base**: NetHack (C)
- **Port WASM**: NetHackJS compila via Emscripten com interface TTY (terminal)
- **Rendering**: Texto/ASCII renderizado em `<pre>` ou Canvas (tile mode)
- **Dependências de build**: Emscripten SDK, make
- **Áudio**: Nenhum (NetHack é silencioso por padrão)
- **Tamanho do bundle**: ~5-8 MB total
- **RAM**: ~20-30 MB (extremamente leve)

## Integration Plan

**Complexidade: New engine (proven, leve)**

### Build Steps
1. Clonar `apowers313/NetHackJS`
2. Seguir instruções de build (Emscripten + make)
3. Output: `index.html`, `nethack.js`, `nethack.wasm`

### Game Data
Não há download de game data — tudo está no source.

### Novos Módulos
- `Mix.Tasks.Arcade.BuildNethackEngine` — compilação do NetHackJS
- Não precisa de módulo de data
- Entry no `Arcade.Catalog`: `%{id: "nethack", engine: :nethack, ...}`
- Ícone `icon_game_nethack` em `Icons.Games`

### Considerações
- **Interface**: ASCII por padrão — combina perfeitamente com a estética retro da plataforma
- **Tileset**: Opção de tiles gráficos existe mas ASCII é mais autêntico
- **Input**: Keyboard-heavy — funciona bem no browser, mapeamento 1:1
- **Saves**: Pode usar IndexedDB para persistir save files entre sessões
- **Complexidade do jogo**: NetHack é notoriamente profundo — jogadores podem gastar centenas de horas
- **Tutorial**: Considerar incluir link para guia/wiki no lobby

## Current Status

- **NetHackJS**: Funcional, mas repo com baixa atividade recente
- **NetHack upstream**: Muito ativo (3.6.7 release recente)
- **Maturidade**: Média — o port funciona mas pode precisar de atualização para NetHack mais recente
- **Prioridade**: Média — bundle mínimo, jogo infinitamente rejogável, mas audiência nicho
- **Diferencial**: O roguelike definitivo. Profundidade de gameplay incomparável. Interface ASCII combina com estética da plataforma.
