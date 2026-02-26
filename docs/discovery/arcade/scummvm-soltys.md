# Soltys (ScummVM)

## Identity

| Campo | Valor |
|-------|-------|
| Nome | Soltys |
| Ano | 1995 |
| Gênero | Aventura (Point & Click / Puzzle) |
| Desenvolvedora | LK Avalon |
| Nossa ID | `scummvm_soltys` |
| Engine WASM | ScummVM (compartilhado) |
| ScummVM Engine ID | `cge` |
| ScummVM Game ID | `soltys` |

## Source & License

| Item | Licença | Descrição |
|------|---------|-----------|
| Game data | **Freeware oficial** | Liberado pela LK Avalon |
| ScummVM engine | GPL v3 | Engine compartilhado (ver [scummvm.md](scummvm.md)) |

**Nota**: O engine ID é `cge` (Color Graphics Engine), não `soltys`. O engine CGE
também roda Soltys 2 (Sfinx).

## Game Data

| Versão | Arquivo | Tamanho | Fonte |
|--------|---------|---------|-------|
| English | `soltys-en-v1.0.zip` | ~4 MB | [ScummVM extras](https://downloads.scummvm.org/frs/extras/Soltys/) |
| Polish (original) | `soltys-pl-v1.0.zip` | ~4 MB | [ScummVM extras](https://downloads.scummvm.org/frs/extras/Soltys/) |
| Spanish | `soltys-es-v1.0.zip` | ~4 MB | [ScummVM extras](https://downloads.scummvm.org/frs/extras/Soltys/) |

### Download URL

```
https://downloads.scummvm.org/frs/extras/Soltys/soltys-en-v1.0.zip
```

### Arquivos após extração

```
soltys/
├── SOLTYS.DAT       # Main data file
├── SOLTYS.BMP       # Graphics
├── SOLTYS.SPR       # Sprites
├── ...
└── index.json       # Gerado por build-make_http_index.py
```

### scummvm.ini entry

```ini
[soltys]
gameid=soltys
description=Soltys (English)
path=/games/soltys
language=en
platform=pc
```

### Auto-start URL

```
/arcade/scummvm/index.html#-p /games/soltys/ soltys
```

## Sobre o Jogo

Aventura puzzle polonesa com humor absurdo. O avô de Soltys foi sequestrado e
levado para debaixo da terra por piratas. Soltys precisa descer por vários andares
subterrâneos, resolvendo puzzles cada vez mais bizarros para resgatá-lo.

- **Estilo**: Cartoon, humor absurdo/surrealista, pixel art colorido
- **Duração**: ~2-4 horas
- **Dificuldade**: Média — puzzles criativos mas compactos
- **Controles**: Mouse (point & click), interface minimalista
- **Destaque**: Menor jogo da lista (~4 MB), humor surrealista, puzzles inventivos

## Catalog Entry

```elixir
%{
  id: "scummvm_soltys",
  name: "Soltys",
  tagline: "Surreal Polish puzzle adventure (1995)",
  description: "Rescue your grandfather from underground pirates in this charmingly absurd Polish point & click adventure full of creative puzzles and surreal humor.",
  engine: :scummvm,
  controls: "Point & click: left-click interact, right-click examine. Simple, streamlined interface.",
  icon: "game_soltys"
}
```

## Build Script

**Mix task independente**: `mix arcade.build_scummvm_soltys`

Módulo: `Mix.Tasks.Arcade.BuildScummvmSoltys`

```elixir
# 1. Garante engine ScummVM compilado (chama BuildScummvmEngine se necessário)
# 2. Baixa game data: GameData.ScummvmSoltys.download(data_dir)
#    → soltys-en-v1.0.zip → extrai SOLTYS.*
# 3. Gera index.json com build-make_http_index.py
# 4. Monta diretório final: priv/static/arcade/scummvm_soltys/
#    → copia engine + plugins + data/ + games/soltys/
```

Game data module: `Mix.Tasks.Arcade.GameData.ScummvmSoltys`
- URL: `https://downloads.scummvm.org/frs/extras/Soltys/soltys-en-v1.0.zip`
- Extrai para: `soltys/` (SOLTYS.*)
- Verificação: SOLTYS.DAT existe
- **Menor download**: ~4 MB

## Prioridade

**Média-baixa** — Menor e menos conhecido, mas tamanho tiny (~4 MB) e humor genuíno.
Bom complemento para variedade geográfica (jogo polonês) e como "palate cleanser"
entre aventuras mais longas.
