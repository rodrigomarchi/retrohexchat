# Beneath a Steel Sky (ScummVM)

## Identity

| Campo | Valor |
|-------|-------|
| Nome | Beneath a Steel Sky |
| Ano | 1994 |
| Gênero | Aventura (Point & Click) |
| Desenvolvedora | Revolution Software |
| Nossa ID | `scummvm_bass` |
| Engine WASM | ScummVM (compartilhado) |
| ScummVM Engine ID | `sky` |
| ScummVM Game ID | `sky` |

## Source & License

| Item | Licença | Descrição |
|------|---------|-----------|
| Game data | **Freeware oficial** | Liberado pela Revolution Software em 2003 |
| ScummVM engine | GPL v3 | Engine compartilhado (ver [scummvm.md](scummvm.md)) |

Revolution Software liberou oficialmente o jogo como freeware. É redistribuído
pelo próprio projeto ScummVM.

## Game Data

| Versão | Arquivo | Tamanho | Fonte |
|--------|---------|---------|-------|
| **CD (escolhida)** | `bass-cd-1.2.zip` | ~66 MB | [ScummVM extras](https://downloads.scummvm.org/frs/extras/Beneath%20a%20Steel%20Sky/) |
| Floppy | `BASS-Floppy-1.3.zip` | ~7 MB | [ScummVM extras](https://downloads.scummvm.org/frs/extras/Beneath%20a%20Steel%20Sky/) |

**Versão escolhida**: **CD** (~66 MB) — voice acting completo com elenco profissional.

### Download URL

```
https://downloads.scummvm.org/frs/extras/Beneath%20a%20Steel%20Sky/bass-cd-1.2.zip
```

Alternativa (SourceForge mirror):
```
https://sourceforge.net/projects/scummvm/files/extras/Beneath%20a%20Steel%20Sky/bass-cd-1.2.zip/download
```

### Arquivos após extração

```
bass/
├── SKY.DNR          # Data file index
├── SKY.DSK          # Main data file (~65 MB, inclui speech)
└── index.json       # Gerado por build-make_http_index.py
```

### scummvm.ini entry

```ini
[bass]
gameid=sky
description=Beneath a Steel Sky (CD)
path=/games/bass
language=en
platform=pc
```

### Auto-start URL

```
/arcade/scummvm/index.html#-p /games/bass/ sky
```

## Sobre o Jogo

Obra-prima cyberpunk da Revolution Software. Robert Foster acorda em uma cidade
industrial distópica chamada Union City, controlada pela supercomputadora LINC.
Com a ajuda de seu robô Joey, precisa descobrir seu passado e desafiar o sistema.

- **Estilo**: Cyberpunk, pixel art detalhado, diálogos inteligentes
- **Duração**: ~6-8 horas
- **Dificuldade**: Média — puzzles lógicos, inventário clássico
- **Controles**: Mouse (point & click), menu de verbos por botão direito
- **Legado**: Precursor de Broken Sword (mesmo estúdio). Sequência (Beyond a Steel Sky) lançada em 2020

## Catalog Entry

```elixir
%{
  id: "scummvm_bass",
  name: "Beneath a Steel Sky",
  tagline: "Cyberpunk point & click adventure (1994)",
  description: "Escape Union City and uncover your past in this cyberpunk classic by Revolution Software. One of the greatest point & click adventures ever made.",
  engine: :scummvm,
  controls: "Point & click: left-click interact, right-click verb menu. Drag items from inventory to combine or use.",
  icon: "game_bass"
}
```

## Build Script

**Mix task independente**: `mix arcade.build_scummvm_bass`

Módulo: `Mix.Tasks.Arcade.BuildScummvmBass`

```elixir
# 1. Garante engine ScummVM compilado (chama BuildScummvmEngine se necessário)
# 2. Baixa game data: GameData.ScummvmBass.download(data_dir)
#    → bass-cd-1.2.zip → extrai SKY.DNR, SKY.DSK
# 3. Gera index.json com build-make_http_index.py
# 4. Monta diretório final: priv/static/arcade/scummvm_bass/
#    → copia engine + plugins + data/ + games/bass/
```

Game data module: `Mix.Tasks.Arcade.GameData.ScummvmBass`
- URL: `https://downloads.scummvm.org/frs/extras/Beneath%20a%20Steel%20Sky/bass-cd-1.2.zip`
- Extrai para: `bass/` (SKY.DNR, SKY.DSK)
- Verificação: arquivo SKY.DSK > 60 MB (versão CD)

## Prioridade

**Muito Alta** — O jogo mais emblemático da lista. Justifica sozinho a integração do ScummVM.
Amplamente considerado um dos melhores point & click adventures de todos os tempos.
