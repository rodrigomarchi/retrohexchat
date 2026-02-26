# Flight of the Amazon Queen (ScummVM)

## Identity

| Campo | Valor |
|-------|-------|
| Nome | Flight of the Amazon Queen |
| Ano | 1995 |
| Gênero | Aventura (Point & Click) |
| Desenvolvedora | Interactive Binary Illusions |
| Nossa ID | `scummvm_fotaq` |
| Engine WASM | ScummVM (compartilhado) |
| ScummVM Engine ID | `queen` |
| ScummVM Game ID | `queen` |

## Source & License

| Item | Licença | Descrição |
|------|---------|-----------|
| Game data | **Freeware oficial** | Liberado como freeware em 2004 |
| ScummVM engine | GPL v3 | Engine compartilhado (ver [scummvm.md](scummvm.md)) |

## Game Data

| Versão | Arquivo | Tamanho | Fonte |
|--------|---------|---------|-------|
| **CD/Talkie (escolhida)** | `FOTAQ_Talkie-1.1.zip` | ~34 MB | [ScummVM extras](https://downloads.scummvm.org/frs/extras/Flight%20of%20the%20Amazon%20Queen/) |
| Floppy | `FOTAQ_Floppy.zip` | ~7 MB | [ScummVM extras](https://downloads.scummvm.org/frs/extras/Flight%20of%20the%20Amazon%20Queen/) |

**Versão escolhida**: **CD/Talkie** (~34 MB) — voice acting completo, muito divertido.

### Download URL

```
https://downloads.scummvm.org/frs/extras/Flight%20of%20the%20Amazon%20Queen/FOTAQ_Talkie-1.1.zip
```

### Arquivos após extração

```
fotaq/
├── QUEEN.1          # Main data file (~34 MB, inclui speech)
└── index.json       # Gerado por build-make_http_index.py
```

### scummvm.ini entry

```ini
[fotaq]
gameid=queen
description=Flight of the Amazon Queen (CD/Talkie)
path=/games/fotaq
language=en
platform=pc
```

### Auto-start URL

```
/arcade/scummvm/index.html#-p /games/fotaq/ queen
```

## Sobre o Jogo

Joe King, piloto de avião, precisa resgatar uma famosa atriz que desapareceu
na Amazônia. Descobre uma conspiração envolvendo um cientista louco que quer
transformar humanos em dinossauros. Aventura cômica no estilo Indiana Jones
com humor irreverente.

- **Estilo**: Aventura cômica, pixel art colorido, humor absurdo
- **Duração**: ~5-7 horas
- **Dificuldade**: Média-baixa — puzzles acessíveis, boa aventura para iniciantes
- **Controles**: Mouse (point & click), inventário no topo da tela
- **Destaque**: Diálogos com múltiplas opções, NPC memoráveis, paródias de filmes

## Catalog Entry

```elixir
%{
  id: "scummvm_fotaq",
  name: "Flight of the Amazon Queen",
  tagline: "Comic adventure in the Amazon (1995)",
  description: "Pilot Joe King crash-lands in the Amazon and stumbles into a mad scientist's plot to turn humans into dinosaurs. A hilarious Indiana Jones-style point & click adventure.",
  engine: :scummvm,
  controls: "Point & click: left-click interact, right-click examine. Inventory at top of screen.",
  icon: "game_fotaq"
}
```

## Build Script

**Mix task independente**: `mix arcade.build_scummvm_fotaq`

Módulo: `Mix.Tasks.Arcade.BuildScummvmFotaq`

```elixir
# 1. Garante engine ScummVM compilado (chama BuildScummvmEngine se necessário)
# 2. Baixa game data: GameData.ScummvmFotaq.download(data_dir)
#    → FOTAQ_Talkie-1.1.zip → extrai QUEEN.1
# 3. Gera index.json com build-make_http_index.py
# 4. Monta diretório final: priv/static/arcade/scummvm_fotaq/
#    → copia engine + plugins + data/ + games/fotaq/
```

Game data module: `Mix.Tasks.Arcade.GameData.ScummvmFotaq`
- URL: `https://downloads.scummvm.org/frs/extras/Flight%20of%20the%20Amazon%20Queen/FOTAQ_Talkie-1.1.zip`
- Extrai para: `fotaq/` (QUEEN.1)
- Verificação: arquivo QUEEN.1 > 30 MB (versão Talkie)

## Prioridade

**Alta** — Excelente aventura cômica, fácil de entrar. Complementa bem o tom mais sério
do Beneath a Steel Sky. Tamanho pequeno (7 MB).
