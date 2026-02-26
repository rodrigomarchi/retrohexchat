# Dreamweb (ScummVM)

## Identity

| Campo | Valor |
|-------|-------|
| Nome | Dreamweb |
| Ano | 1994 |
| Gênero | Aventura (Point & Click) |
| Desenvolvedora | Creative Reality |
| Nossa ID | `scummvm_dreamweb` |
| Engine WASM | ScummVM (compartilhado) |
| ScummVM Engine ID | `dreamweb` |
| ScummVM Game ID | `dreamweb` |

## Source & License

| Item | Licença | Descrição |
|------|---------|-----------|
| Game data | **Freeware oficial** | Liberado pela Creative Reality |
| ScummVM engine | GPL v3 | Engine compartilhado (ver [scummvm.md](scummvm.md)) |

## Game Data

| Versão | Arquivo | Tamanho | Fonte |
|--------|---------|---------|-------|
| **CD UK (escolhida)** | `dreamweb-cd-uk-1.0.zip` | ~165 MB | [ScummVM extras](https://downloads.scummvm.org/frs/extras/Dreamweb/) |
| CD US | `dreamweb-cd-us-1.0.zip` | ~244 MB | [ScummVM extras](https://downloads.scummvm.org/frs/extras/Dreamweb/) |
| Floppy UK | `dreamweb-uk-1.1.zip` | ~10 MB | [ScummVM extras](https://downloads.scummvm.org/frs/extras/Dreamweb/) |

**Versão escolhida**: **CD UK** (~165 MB) — voice acting atmosférico essencial
para a experiência cyberpunk.

### Download URL

```
https://downloads.scummvm.org/frs/extras/Dreamweb/dreamweb-cd-uk-1.0.zip
```

### Arquivos após extração

```
dreamweb/
├── DREAMWEB.R00     # Room data files
├── DREAMWEB.R01
├── ...
├── DREAMWEB.S00     # Sound/speech files
├── DREAMWEB.V00     # Various data
├── SPEECH/          # Voice acting (CD only)
│   ├── *.RAW
│   └── ...
├── ...
└── index.json       # Gerado por build-make_http_index.py
```

### scummvm.ini entry

```ini
[dreamweb]
gameid=dreamweb
description=Dreamweb (CD)
path=/games/dreamweb
language=en
platform=pc
```

### Auto-start URL

```
/arcade/scummvm/index.html#-p /games/dreamweb/ dreamweb
```

## Sobre o Jogo

Aventura dark cyberpunk com visão top-down isométrica. Ryan, um jovem atormentado
por pesadelos, descobre que é o "chosen one" destinado a proteger o Dreamweb — uma
rede psíquica que conecta todas as mentes humanas. Para salvá-la, precisa eliminar
sete pessoas corrompidas pelo poder.

- **Estilo**: Cyberpunk dark, pixel art top-down isométrico, atmosfera opressiva
- **Duração**: ~3-5 horas
- **Dificuldade**: Alta — puzzles de observação, interação pixel-hunt
- **Controles**: Mouse (point & click), perspectiva top-down única
- **Destaque**: Atmosfera extremamente imersiva, visual único (top-down em vez de side-view), temática madura
- **Nota**: Conteúdo adulto — violência e nudez (classificação 18+)

## Catalog Entry

```elixir
%{
  id: "scummvm_dreamweb",
  name: "Dreamweb",
  tagline: "Dark cyberpunk top-down adventure (1994)",
  description: "Protect the Dreamweb — a psychic network connecting all human minds — in this dark, atmospheric cyberpunk adventure with a unique top-down perspective. Mature content.",
  engine: :scummvm,
  controls: "Point & click (top-down view): click to move and interact. Inventory panel on screen.",
  icon: "game_dreamweb"
}
```

## Build Script

**Mix task independente**: `mix arcade.build_scummvm_dreamweb`

Módulo: `Mix.Tasks.Arcade.BuildScummvmDreamweb`

```elixir
# 1. Garante engine ScummVM compilado (chama BuildScummvmEngine se necessário)
# 2. Baixa game data: GameData.ScummvmDreamweb.download(data_dir)
#    → dreamweb-cd-uk-1.0.zip → extrai DREAMWEB.*, SPEECH/, etc.
# 3. Gera index.json com build-make_http_index.py
# 4. Monta diretório final: priv/static/arcade/scummvm_dreamweb/
#    → copia engine + plugins + data/ + games/dreamweb/
```

Game data module: `Mix.Tasks.Arcade.GameData.ScummvmDreamweb`
- URL: `https://downloads.scummvm.org/frs/extras/Dreamweb/dreamweb-cd-uk-1.0.zip`
- Extrai para: `dreamweb/` (DREAMWEB.*, SPEECH/)
- Verificação: diretório SPEECH/ presente (confirma versão CD)
- **Maior download**: ~165 MB (voice acting completo)

## Prioridade

**Média** — Visual e atmosfera únicos, mas conteúdo maduro pode não ser ideal para todos.
Perspectiva top-down diferencia dos outros point & clicks. Tamanho razoável (10 MB).
