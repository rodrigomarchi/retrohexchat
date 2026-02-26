# Drascula: The Vampire Strikes Back (ScummVM)

## Identity

| Campo | Valor |
|-------|-------|
| Nome | Drascula: The Vampire Strikes Back |
| Ano | 1996 |
| Gênero | Aventura (Point & Click) |
| Desenvolvedora | Alcachofa Soft |
| Nossa ID | `scummvm_drascula` |
| Engine WASM | ScummVM (compartilhado) |
| ScummVM Engine ID | `drascula` |
| ScummVM Game ID | `drascula` |

## Source & License

| Item | Licença | Descrição |
|------|---------|-----------|
| Game data | **Freeware oficial** | Liberado pela Alcachofa Soft |
| Áudio extra | Freeware | MP3/OGG/FLAC add-ons disponíveis |
| ScummVM engine | GPL v3 | Engine compartilhado (ver [scummvm.md](scummvm.md)) |

## Game Data

| Versão | Arquivo | Tamanho | Fonte |
|--------|---------|---------|-------|
| **Base game (escolhida)** | `drascula-1.0.zip` | ~31 MB | [ScummVM extras](https://downloads.scummvm.org/frs/extras/Drascula_%20The%20Vampire%20Strikes%20Back/) |
| **Audio MP3 (escolhida)** | `drascula-audio-mp3-2.0.zip` | ~28 MB | [ScummVM extras](https://downloads.scummvm.org/frs/extras/Drascula_%20The%20Vampire%20Strikes%20Back/) |
| Audio OGG (alternativa) | `drascula-audio-ogg-2.0.zip` | ~35 MB | [ScummVM extras](https://downloads.scummvm.org/frs/extras/Drascula_%20The%20Vampire%20Strikes%20Back/) |

**Versão escolhida**: **Base game + Audio MP3** (~31 MB + ~28 MB = ~59 MB) — vozes adicionam
muito ao humor do jogo.

### Download URLs

Base game:
```
https://downloads.scummvm.org/frs/extras/Drascula_%20The%20Vampire%20Strikes%20Back/drascula-1.0.zip
```

Audio MP3 (vozes):
```
https://downloads.scummvm.org/frs/extras/Drascula_%20The%20Vampire%20Strikes%20Back/drascula-audio-mp3-2.0.zip
```

**Nota**: O nome do diretório no server ScummVM usa underscore e espaço:
`Drascula_ The Vampire Strikes Back` (com espaço após o underscore).

### Arquivos após extração

Ambos os ZIPs extraídos no mesmo diretório:

```
drascula/
├── PACKET.001       # Main data files (do base game)
├── PACKET.002
├── ...
├── drascula-audio/  # ou arquivos MP3 diretamente (do audio pack)
│   ├── *.mp3
│   └── ...
└── index.json       # Gerado por build-make_http_index.py
```

### scummvm.ini entry

```ini
[drascula]
gameid=drascula
description=Drascula: The Vampire Strikes Back
path=/games/drascula
language=en
platform=pc
```

### Auto-start URL

```
/arcade/scummvm/index.html#-p /games/drascula/ drascula
```

## Sobre o Jogo

Paródia cômica de Drácula e do gênero de terror. John Hacker, um agente imobiliário
britânico, acaba na Transilvânia e precisa derrotar o vampiro Drascula que sequestrou
sua namorada. Humor absurdo, referências pop dos anos 90, e quebra da quarta parede.

- **Estilo**: Comédia/paródia, pixel art cartoon colorido, humor espanhol
- **Duração**: ~5-7 horas
- **Dificuldade**: Média — alguns puzzles criativos, humor ajuda na motivação
- **Controles**: Mouse (point & click), inventário clássico
- **Destaque**: Humor genuinamente engraçado, referências a filmes de terror, estética única

## Catalog Entry

```elixir
%{
  id: "scummvm_drascula",
  name: "Drascula: The Vampire Strikes Back",
  tagline: "Comedic Dracula parody adventure (1996)",
  description: "British real estate agent John Hacker must defeat the vampire Drascula in this hilarious Spanish point & click adventure full of pop culture references and absurd humor.",
  engine: :scummvm,
  controls: "Point & click: left-click interact, right-click examine. Inventory at bottom of screen.",
  icon: "game_drascula"
}
```

## Build Script

**Mix task independente**: `mix arcade.build_scummvm_drascula`

Módulo: `Mix.Tasks.Arcade.BuildScummvmDrascula`

```elixir
# 1. Garante engine ScummVM compilado (chama BuildScummvmEngine se necessário)
# 2. Baixa game data: GameData.ScummvmDrascula.download(data_dir)
#    → drascula-1.0.zip → extrai PACKET.001, etc.
#    → drascula-audio-mp3-2.0.zip → extrai arquivos MP3
#    → Ambos no mesmo diretório drascula/
# 3. Gera index.json com build-make_http_index.py
# 4. Monta diretório final: priv/static/arcade/scummvm_drascula/
#    → copia engine + plugins + data/ + games/drascula/
```

Game data module: `Mix.Tasks.Arcade.GameData.ScummvmDrascula`
- URL 1: `https://downloads.scummvm.org/frs/extras/Drascula_%20The%20Vampire%20Strikes%20Back/drascula-1.0.zip`
- URL 2: `https://downloads.scummvm.org/frs/extras/Drascula_%20The%20Vampire%20Strikes%20Back/drascula-audio-mp3-2.0.zip`
- Extrai para: `drascula/` (PACKET.001 + MP3 audio)
- Verificação: PACKET.001 existe + diretório de áudio presente
- **2 downloads** necessários (base game + audio pack)

## Prioridade

**Alta** — O maior em tamanho (31 MB) mas também o mais divertido. Humor acessível
e universalmente engraçado. Estilo totalmente diferente dos outros jogos da lista.
