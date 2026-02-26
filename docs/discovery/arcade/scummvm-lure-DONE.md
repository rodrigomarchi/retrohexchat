# Lure of the Temptress (ScummVM)

## Identity

| Campo | Valor |
|-------|-------|
| Nome | Lure of the Temptress |
| Ano | 1992 |
| Gênero | Aventura (Point & Click) |
| Desenvolvedora | Revolution Software |
| Nossa ID | `scummvm_lure` |
| Engine WASM | ScummVM (compartilhado) |
| ScummVM Engine ID | `lure` |
| ScummVM Game ID | `lure` |

## Source & License

| Item | Licença | Descrição |
|------|---------|-----------|
| Game data | **Freeware oficial** | Liberado pela Revolution Software |
| ScummVM engine | GPL v3 | Engine compartilhado (ver [scummvm.md](scummvm.md)) |

Primeiro jogo da Revolution Software, liberado oficialmente como freeware.

## Game Data

| Versão | Arquivo | Tamanho | Fonte |
|--------|---------|---------|-------|
| English | `lure-1.1.zip` | ~5 MB | [ScummVM extras](https://downloads.scummvm.org/frs/extras/Lure%20of%20the%20Temptress/) |
| German | `lure-de-1.1.zip` | ~5 MB | [ScummVM extras](https://downloads.scummvm.org/frs/extras/Lure%20of%20the%20Temptress/) |

### Download URL

```
https://downloads.scummvm.org/frs/extras/Lure%20of%20the%20Temptress/lure-1.1.zip
```

### Arquivos após extração

```
lure/
├── lure.dat         # Engine data
├── DISK1.VGA        # Graphics data
├── DISK2.VGA
├── DISK3.VGA
├── DISK4.VGA
└── index.json       # Gerado por build-make_http_index.py
```

### scummvm.ini entry

```ini
[lure]
gameid=lure
description=Lure of the Temptress
path=/games/lure
language=en
platform=pc
```

### Auto-start URL

```
/arcade/scummvm/index.html#-p /games/lure/ lure
```

## Sobre o Jogo

Aventura medieval com o sistema Virtual Theatre — NPCs que se movem independentemente
pelo mundo, seguindo suas próprias rotinas. O herói Diermot deve libertar a vila de
Turnvale da feiticeira Selena e do exército Skorl que a dominou.

- **Estilo**: Fantasia medieval, pixel art VGA, NPCs autônomos
- **Duração**: ~4-6 horas
- **Dificuldade**: Alta — puzzles obscuros (típico dos anos 90), NPCs com rotinas
- **Controles**: Mouse (point & click), menu de verbos contextual
- **Destaque**: Virtual Theatre (NPCs independentes) — inovador para 1992, precursor de Broken Sword

## Catalog Entry

```elixir
%{
  id: "scummvm_lure",
  name: "Lure of the Temptress",
  tagline: "Medieval fantasy adventure (1992)",
  description: "Free the village of Turnvale from the sorceress Selena. Revolution Software's debut game featuring the innovative Virtual Theatre system with autonomous NPCs.",
  engine: :scummvm,
  controls: "Point & click: left-click interact, right-click verb menu. NPCs follow their own schedules.",
  icon: "game_lure"
}
```

## Build Script

**Mix task independente**: `mix arcade.build_scummvm_lure`

Módulo: `Mix.Tasks.Arcade.BuildScummvmLure`

```elixir
# 1. Garante engine ScummVM compilado (chama BuildScummvmEngine se necessário)
# 2. Baixa game data: GameData.ScummvmLure.download(data_dir)
#    → lure-1.1.zip → extrai lure.dat, DISK1-4.VGA
# 3. Gera index.json com build-make_http_index.py
# 4. Monta diretório final: priv/static/arcade/scummvm_lure/
#    → copia engine + plugins + data/ + games/lure/
```

Game data module: `Mix.Tasks.Arcade.GameData.ScummvmLure`
- URL: `https://downloads.scummvm.org/frs/extras/Lure%20of%20the%20Temptress/lure-1.1.zip`
- Extrai para: `lure/` (lure.dat, DISK1.VGA–DISK4.VGA)
- Verificação: lure.dat existe

## Prioridade

**Média** — Valor histórico como primeiro jogo da Revolution Software. Puzzles
datados podem frustrar jogadores modernos, mas o sistema Virtual Theatre é fascinante.
Tamanho mínimo (~5 MB).
