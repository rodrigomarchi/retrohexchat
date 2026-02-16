# RetroHexChat — Identidade Visual

## Conceito

O logotipo do RetroHexChat combina dois elementos centrais da marca:

1. **A Pedra Hex (Hexágono Lapidado)** — uma gema hexagonal com facetas que remete
   às texturas de jogos e ícones dos anos 2000. O formato hexagonal reforça o "Hex"
   do nome e evoca solidez, comunidade (células de colmeia) e a estética pixel-art
   da época.

2. **O Balão de Chat Win98** — dentro da gema, um balão de diálogo com as bordas 3D
   características do Windows 98 (bevel claro no topo-esquerda, escuro no
   canto inferior-direito). As linhas de texto dentro do balão usam as cores
   primárias do projeto (navy, teal, cinza).

### Sparkles Pixel

Pequenos brilhos pixelados no canto superior-direito da gema adicionam o toque
"retro-gamer" que caracteriza a era Y2K/early-2000s.

---

## Paleta de Cores Institucional

### Cores Primárias

| Nome              | Hex       | Uso                                     |
|-------------------|-----------|-----------------------------------------|
| **Teal Desktop**  | `#008080` | Cor principal da marca, fundo desktop   |
| **Navy Selection**| `#000080` | Destaques, seleções, links ativos       |
| **Surface Gray**  | `#c0c0c0` | Superfícies Win98, elementos de UI      |

### Cores Secundárias

| Nome              | Hex       | Uso                                     |
|-------------------|-----------|-----------------------------------------|
| **Deep Teal**     | `#004d4d` | Sombras da gema, fundos profundos       |
| **Bright Teal**   | `#00b3b3` | Destaques luminosos da gema             |
| **Aqua Glow**     | `#00cccc` | Brilho (versão dark), acentos neon      |
| **Cyan**          | `#00ffff` | Sparkles na versão dark                 |

### Cores de Suporte

| Nome              | Hex       | Uso                                     |
|-------------------|-----------|-----------------------------------------|
| **Black**         | `#000000` | Texto principal, bordas                 |
| **White**         | `#ffffff` | Texto sobre escuro, highlights          |
| **Medium Gray**   | `#808080` | Bordas, texto muted, separadores        |
| **Win98 Beige**   | `#d4d0c8` | Botões, tabs, elementos de interface    |

### Cores Semânticas (do projeto)

| Nome              | Hex       | Uso                                     |
|-------------------|-----------|-----------------------------------------|
| **Success Green** | `#009300` | Online, operações bem-sucedidas         |
| **Error Red**     | `#cc0000` | Erros, operadores, ações destrutivas    |
| **Warning Orange**| `#cc8800` | Avisos, connecting, lag                  |
| **Action Purple** | `#800080` | Ações /me, destaque especial            |
| **Notice Pink**   | `#cc6699` | Notices IRC                             |
| **Link Blue**     | `#0066cc` | Links clicáveis                         |

---

## Variantes do Logo

### 1. Logo Principal (`logo.svg`)
- 512×512px, fundo transparente
- Uso: avatar, ícone de app, favicon (reduzido), og:image
- A gema teal com balão Win98 centralizado

### 2. Logo Dark (`logo-dark.svg`)
- 512×512px, fundo `#0a0a0a`
- Uso: contextos com fundo escuro, headers escuros
- Mesmo conceito com glow neon nos sparkles e contornos

### 3. Logo Compacto (`logo-compact.svg`)
- 64×64px, fundo transparente
- Uso: favicon, notificações, ícones pequenos
- Versão simplificada sem detalhes finos

### 4. Wordmark (`wordmark.svg`)
- 800×120px, fundo transparente
- Uso: header da landing page, README, documentação
- Gema mini + "RetroHexChat" com cores segmentadas:
  - **Retro** em preto (a base sólida)
  - **Hex** em teal `#008080` (a gema, o coração)
  - **Chat** em navy `#000080` (a comunicação)
- Tagline: "PUBLIC CHAT PLATFORM" em gray `#808080`

---

## Tipografia

### Primária (UI do app)
- **MS Sans Serif** (Win98 nativo via 98.css)
- Fallback: `Segoe UI → Tahoma → Geneva → Verdana → sans-serif`

### Secundária (código, logs)
- **Monospace stack**: `Consolas → Monaco → Courier New → monospace`

### Wordmark
- Usa a stack primária em **bold**, `52px`, `letter-spacing: -1px`
- Tagline em `14px`, `letter-spacing: 2px`, uppercase

---

## Guia de Aplicação

### Espaçamento Mínimo
A área de proteção (safe zone) ao redor do logo é equivalente a 1/4 da
largura do hexágono em cada direção.

### Tamanhos Mínimos
- Logo completo: mínimo 32×32px (abaixo disso usar `logo-compact.svg`)
- Wordmark: mínimo 200px de largura
- Logo compacto: até 16×16px (favicon)

### Sobre Fundos

| Fundo              | Variante recomendada     |
|--------------------|--------------------------|
| Branco / claro     | `logo.svg` (transparente)|
| Cinza `#c0c0c0`    | `logo.svg` (transparente)|
| Teal `#008080`     | `logo-dark.svg` (recortado, sem fundo preto) |
| Preto / escuro     | `logo-dark.svg`          |
| Colorido / foto    | `logo.svg` com sombra    |

### Usos Proibidos
- Não rotacionar a gema
- Não distorcer as proporções
- Não remover o balão de chat de dentro da gema
- Não usar cores fora da paleta institucional
- Não adicionar efeitos (blur, glow) fora das variantes oficiais
- Não separar o wordmark do ícone verticalmente (sempre lado a lado)

---

## Contextos de Uso

### Web
- **Favicon**: `logo-compact.svg` convertido para `.ico` (16, 32, 48px)
- **og:image**: `logo.svg` sobre fundo `#008080` em 1200×630
- **Header**: `wordmark.svg`
- **Footer**: `logo-compact.svg` + texto "RetroHexChat"

### GitHub
- **Avatar do org**: `logo.svg`
- **Social preview**: Wordmark centrado sobre fundo teal `#008080`
- **README badge**: Logo compacto inline

### Chat (dentro do app)
- **MOTD decoration**: Logo compacto ao lado do nome do servidor
- **About dialog**: Logo principal com versão abaixo

---

## DNA Visual: O Espírito Y2K Moderno

A identidade do RetroHexChat vive na tensão criativa entre:

- **Nostalgia Win98** — bordas 3D bevel, cinza `#c0c0c0`, pixels nítidos
- **Energia Y2K** — teal vibrante, sparkles pixelados, formas geométricas
- **Modernidade** — gradientes suaves nas facetas, SVG escalável, design system

Essa mistura garante que a marca funcione tanto para quem viveu a era IRC
quanto para novos usuários que descobrem o charme do retro pela primeira vez.
