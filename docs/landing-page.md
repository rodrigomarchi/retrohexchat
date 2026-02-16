# RetroHexChat — Landing Page

## Documento de Arquitetura, Estrutura e Planejamento

---

## I. Visão Geral

A landing page é o ponto de entrada público do RetroHexChat. Deve ser otimizada
para SEO, servida como HTML estático (sem LiveView), e estruturada para crescer
com páginas de ajuda, suporte, instalação e conteúdo institucional.

### Decisões Técnicas

| Decisão | Justificativa |
|---------|---------------|
| **Controller Phoenix (não LiveView)** | HTML estático = melhor SEO, menor overhead, cacheable |
| **Layout dedicado (`landing.html.heex`)** | Separar do layout do app (sem LiveView JS, sem CSRF pesado) |
| **CSS dedicado (`landing.css`)** | Bundle separado, não carregar CSS do chat na landing |
| **JS mínimo (vanilla)** | Scroll suave, abas, animações. Zero frameworks. |
| **Rota inicial: `/landing`** | Validação antes de mover para `/`. ConnectLive continua em `/` por enquanto. |
| **Estrutura expansível** | Preparada para crescer com `/landing/help`, `/landing/install`, etc. |

---

## II. Arquitetura de Rotas e Navegação

### Estrutura de URLs

A landing page é um mini-site dentro do projeto, com sua própria hierarquia
de URLs, controller, layout e assets.

```
ROTAS PLANEJADAS (fase 1):
═════════════════════════════════

GET /landing                    → Página principal (one-page scroll)
GET /landing/features           → Detalhamento de features (future)
GET /landing/install            → Guia de instalação (future)
GET /landing/help               → Central de ajuda (future)
GET /landing/about              → Sobre o projeto (future)
GET /landing/faq                → FAQ expandido (future)
GET /landing/donate             → Como apoiar o projeto (future)
GET /landing/contributing       → Guia de contribuição (future)
GET /landing/privacy            → Política de privacidade (future)
GET /landing/terms              → Termos de uso (future)
GET /landing/p2p                → Página dedicada P2P (future)
GET /landing/changelog          → Changelog público (future)
GET /landing/roadmap            → Roadmap público (future)
```

### Navegação Global

```
┌──────────────────────────────────────────────────────────────────────┐
│ TASKBAR (fixa no topo — presente em TODAS as páginas do /landing)   │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  [🖥 RetroHexChat]  │ Features │ P2P │ Open Source │ Apoie │ FAQ │  │
│                     │          │     │            │       │     │  │
│                                                    [Entrar] [Criar] │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘

  COMPORTAMENTO:
  ─────────────
  ─ Na página principal (/landing): links fazem scroll suave para seções
  ─ Em sub-páginas (/landing/*): links apontam para /landing#secao
  ─ [Entrar] → link para / (ConnectLive)
  ─ [Criar conta] → link para / (ConnectLive, modo registro)
  ─ [🖥 RetroHexChat] → logo compacto + wordmark, link para /landing

  MOBILE:
  ┌──────────────────────────────────────┐
  │ [🖥 RetroHexChat]           [≡]      │
  └──────────────────────────────────────┘
    Menu hamburguer abre lista vertical com
    todos os links + Entrar/Criar conta.
```

### Arquitetura Phoenix

```
apps/retro_hex_chat_web/
├── lib/retro_hex_chat_web/
│   ├── controllers/
│   │   └── landing_controller.ex          # Controller para todas as rotas /landing
│   ├── components/
│   │   └── layouts/
│   │       ├── root.html.heex             # Layout existente (app)
│   │       └── landing.html.heex          # Layout dedicado da landing
│   └── templates/                         # Novo: templates EEx para landing
│       └── landing/
│           └── index.html.heex            # Página principal
├── assets/
│   ├── css/
│   │   └── landing.css                    # CSS dedicado (NÃO importado em app.css)
│   └── js/
│       └── landing.js                     # JS mínimo (scroll, abas, animações)
└── priv/static/
    └── images/
        └── landing/                       # Assets estáticos da landing
            ├── og-image.png               # Open Graph image (1200x630)
            └── desktop-icons/             # Ícones pixel art do "desktop"
```

### Router

```elixir
# router.ex — adição

# Pipeline dedicada para landing (sem LiveView overhead)
pipeline :landing do
  plug :accepts, ["html"]
  plug :fetch_session
  plug :put_root_layout, html: {RetroHexChatWeb.Layouts, :landing}
  plug :put_secure_browser_headers
end

scope "/landing", RetroHexChatWeb do
  pipe_through :landing

  get "/", LandingController, :index
  # Futuras rotas:
  # get "/features", LandingController, :features
  # get "/install", LandingController, :install
  # get "/help", LandingController, :help
  # get "/about", LandingController, :about
end
```

### Layout Dedicado (`landing.html.heex`)

```
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  ─ charset, viewport
  ─ SEO meta tags (title, description, canonical)
  ─ Open Graph tags
  ─ Twitter Card tags
  ─ Structured Data (JSON-LD)
  ─ CSS: 98.css (CDN ou bundle) + landing.css
  ─ JS: landing.js (defer)
  ─ Sem LiveView JS (sem app.js, sem WebSocket)
  ─ Favicon: logo-compact.svg
</head>
<body>
  {@inner_content}
</body>
</html>
```

---

## III. Esbuild — Bundle Separado

A landing page precisa de seu próprio bundle CSS e JS, separado do app principal.

```javascript
// config/config.exs — adicionar segundo watcher esbuild

config :esbuild,
  # Bundle existente do app
  retro_hex_chat_web: [
    args: ~w(js/app.js --bundle ...),
    ...
  ],
  # Novo bundle da landing
  landing: [
    args: ~w(js/landing.js --bundle --target=es2020 --outdir=../priv/static/assets/landing),
    cd: Path.expand("../apps/retro_hex_chat_web/assets", __DIR__),
    env: %{"NODE_PATH" => ...}
  ]
```

O CSS da landing pode ser importado pelo `landing.js` (esbuild resolve) ou
servido como arquivo estático separado. A decisão será tomada na implementação
baseada na simplicidade — se o CSS for pequeno (<50KB), um `<link>` direto
para o arquivo estático é mais simples que configurar um segundo watcher.

---

## IV. SEO e Meta Tags

### Meta Tags Essenciais

```html
<title>RetroHexChat — Chat federado, como nos velhos tempos</title>
<meta name="description" content="Rode seu próprio servidor de chat.
  Conecte com outros. Sem empresa no meio. Open source, descentralizado,
  e livre como o IRC dos anos 2000." />
<link rel="canonical" href="https://retrohexchat.com/landing" />
<meta name="robots" content="index, follow" />
<html lang="pt-BR">
```

### Open Graph

```html
<meta property="og:title" content="RetroHexChat — Chat federado descentralizado" />
<meta property="og:description" content="Seus dados. Suas regras. Sua comunidade.
  Chat em tempo real com federação entre servidores independentes." />
<meta property="og:image" content="/images/landing/og-image.png" />
<meta property="og:type" content="website" />
<meta property="og:url" content="https://retrohexchat.com/landing" />
<meta property="og:locale" content="pt_BR" />
```

### Twitter Card

```html
<meta name="twitter:card" content="summary_large_image" />
<meta name="twitter:title" content="RetroHexChat — Chat federado" />
<meta name="twitter:description" content="Como email, mas para chat em tempo real.
  Open source e descentralizado." />
<meta name="twitter:image" content="/images/landing/og-image.png" />
```

### Structured Data (JSON-LD)

```html
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  "name": "RetroHexChat",
  "applicationCategory": "CommunicationApplication",
  "operatingSystem": "Web",
  "description": "Chat federado e descentralizado. Open source.",
  "license": "https://opensource.org/licenses/MIT",
  "url": "https://retrohexchat.com"
}
</script>
```

### Semântica HTML para SEO

```
<body>
  <header>      → Taskbar (nav + logo)
  <main>
    <section>   → Cada seção da landing (com id para deep-link)
  </main>
  <footer>      → Footer + taskbar inferior
</body>

Cada .window é uma <section> com:
  ─ <header> para title-bar (com heading h2/h3)
  ─ <div> para window-body
  ─ id="secao-nome" para anchor links

Headings hierarchy:
  h1 → "RetroHexChat" (hero, uma vez)
  h2 → Título de cada seção (O Problema, A Solução, etc.)
  h3 → Sub-seções (abas, sub-tópicos)
```

---

## V. Mapa Completo da Página Principal (`/landing`)

```
ORDEM DE SCROLL (top → bottom):
═══════════════════════════════

┌──────────────────────────────────┐
│  TASKBAR (fixa no topo)          │ ← <header><nav>
└──────────────────────────────────┘

┌──────────────────────────────────┐
│  SEÇÃO 1: HERO                   │ ← primeira impressão + CTA
└──────────────────────────────────┘

┌──────────────────────────────────┐
│  SEÇÃO 2: O PROBLEMA             │ ← por que isso existe
└──────────────────────────────────┘

┌──────────────────────────────────┐
│  SEÇÃO 3: A SOLUÇÃO              │ ← o que é + o que NÃO é + analogia email
└──────────────────────────────────┘

┌──────────────────────────────────┐
│  SEÇÃO 4: COMO FUNCIONA          │ ← 4 abas: Servidores, Federação,
│                                  │   Identidade, Segurança
└──────────────────────────────────┘

┌──────────────────────────────────┐
│  SEÇÃO 5: FEATURES               │ ← 7 abas: Chat, Canais, Rede,
│                                  │   Social, P2P, Admin, Comandos
└──────────────────────────────────┘

┌──────────────────────────────────┐
│  SEÇÃO 6: A REDE                 │ ← visualização do grafo de servidores
└──────────────────────────────────┘

┌──────────────────────────────────┐
│  SEÇÃO 7: RODE O SEU             │ ← 3 passos para instalar
└──────────────────────────────────┘

┌──────────────────────────────────┐
│  SEÇÃO 8: OPEN SOURCE            │ ← repositório, licença, contribuição
└──────────────────────────────────┘

┌──────────────────────────────────┐
│  SEÇÃO 9: APOIE O PROJETO        │ ← doação, patrocínio, como ajudar
└──────────────────────────────────┘

┌──────────────────────────────────┐
│  SEÇÃO 10: FAQ                   │ ← tree-view com 10+ perguntas
└──────────────────────────────────┘

┌──────────────────────────────────┐
│  SEÇÃO 11: FOOTER                │ ← links, quote, créditos
└──────────────────────────────────┘

┌──────────────────────────────────┐
│  TASKBAR INFERIOR                │ ← relógio real, botão scroll-to-top
└──────────────────────────────────┘
```

---

## VI. Mockups ASCII — Seções

### Seção 1: Hero

```
┌─ BACKGROUND: #008080 (teal desktop) ──────────────────────────────┐
│                                                                    │
│  Ícones decorativos no desktop (clicáveis):                       │
│  [📁 Meus Chats]  [🌐 Rede]  [📝 README.txt]  [🗑 Lixeira]     │
│                                                                    │
│  ┌─────────────────────────────────────────────────────────┐      │
│  │ ■ RetroHexChat — Bem-vindo                 [─][□][✕]   │      │
│  ├─────────────────────────────────────────────────────────┤      │
│  │                                                         │      │
│  │        [wordmark.svg — RetroHexChat logo]              │      │
│  │                                                         │      │
│  │     Chat federado. Como nos velhos tempos.              │      │
│  │         Mas com a tecnologia de hoje.                   │      │
│  │                                                         │      │
│  │  Rode seu próprio servidor. Conecte com outros.         │      │
│  │  Sem empresa no meio. Sem algoritmos. Sem permissão.    │      │
│  │  Seus dados. Suas regras. Sua comunidade.               │      │
│  │                                                         │      │
│  │    ┌──────────────────┐  ┌───────────────────────┐     │      │
│  │    │  ▶ Criar conta   │  │  Entrar no servidor   │     │      │
│  │    └──────────────────┘  └───────────────────────┘     │      │
│  │                                                         │      │
│  ├─────────────────────────────────────────────────────────┤      │
│  │ 🟢 Open source │ MIT License │ Elixir + Phoenix        │      │
│  └─────────────────────────────────────────────────────────┘      │
│                                                                    │
│  ↓ scroll para saber mais                                         │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

### Seção 2: O Problema

```
┌───────────────────────────────────────────────────────────────┐
│ ■ C:\VERDADE\sobre_o_chat_moderno.txt            [─][□][✕]   │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  <h2> Sua comunidade não é sua. </h2>                        │
│                                                               │
│  ┌─ fieldset sunken ──────────────────────────────────────┐  │
│  │  ✕ Discord pode banir seu servidor amanhã.             │  │
│  │  ✕ Slack cobra por mensagem que você já enviou.        │  │
│  │  ✕ Telegram pode ser bloqueado no seu país inteiro.    │  │
│  │  ✕ Twitter/X mudou as regras do DM. De novo.          │  │
│  │  ✕ Seus dados treinam a IA de outra empresa.          │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                               │
│  <p> Nos anos 2000, não era assim. [nostalgia paragraph]</p>│
│  <p> Depois veio a "conveniência". E junto veio o controle.</p>│
│                                                               │
├───────────────────────────────────────────────────────────────┤
│  📄 C:\VERDADE\                                               │
└───────────────────────────────────────────────────────────────┘
```

### Seção 3: A Solução (3 janelas)

```
┌──── JANELA 1 (esquerda) ────────────┐  ┌──── JANELA 2 (direita) ──────────┐
│ ■ O que é o RetroHexChat   [─][□][✕]│  │ ■ O que NÃO é          [─][□][✕] │
├─────────────────────────────────────┤  ├──────────────────────────────────┤
│                                     │  │                                  │
│  Software de chat que qualquer      │  │  NÃO é um serviço.              │
│  pessoa pode instalar e rodar.      │  │  Não tem empresa controlando.   │
│                                     │  │  Não tem plano "Pro".           │
│  Pense como email:                  │  │  Não tem algoritmo.             │
│  • Você escolhe onde criar conta    │  │  Não pode ser comprado.         │
│  • Fala com qualquer servidor       │  │                                  │
│  • Muda e leva sua identidade       │  │  É software livre. É protocolo. │
│                                     │  │  É da comunidade.               │
├─────────────────────────────────────┤  ├──────────────────────────────────┤
│  ✓ Pronto                           │  │  ✓ Pronto                       │
└─────────────────────────────────────┘  └──────────────────────────────────┘

┌──── JANELA 3 (abaixo, full-width) ───────────────────────────────────────┐
│ ■ Como email, mas para chat                                   [─][□][✕]  │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Tabela comparativa: EMAIL vs RETROHEXCHAT                              │
│  (demonstra a analogia de forma visual)                                  │
│                                                                          │
│  A diferença? RetroHexChat é em tempo real. Com canais.                  │
│  Com presença. Com reações. Com P2P.                                     │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  ✓ Entendi                                                               │
└──────────────────────────────────────────────────────────────────────────┘
```

### Seção 4: Como Funciona (4 abas)

```
┌───────────────────────────────────────────────────────────────┐
│ ■ Como funciona                                    [─][□][✕]  │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────┬────────────┬────────────┬──────────────────┐   │
│  │Servidores│ Federação  │ Identidade │ Segurança        │   │
│  └──────────┴────────────┴────────────┴──────────────────┘   │
│  ┌───────────────────────────────────────────────────────┐   │
│  │                                                       │   │
│  │  (conteúdo varia por aba — ver discovery original)    │   │
│  │  Servidores: 3 cards visuais de servidores exemplo    │   │
│  │  Federação: diagrama de conexões entre servidores     │   │
│  │  Identidade: @alice vs @alice@alpha.chat              │   │
│  │  Segurança: diagrama de assinatura criptográfica      │   │
│  │                                                       │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                               │
├───────────────────────────────────────────────────────────────┤
│  📖 4 conceitos │ 2 min de leitura                            │
└───────────────────────────────────────────────────────────────┘
```

### Seção 5: Features (7 abas — inclui P2P)

```
┌───────────────────────────────────────────────────────────────┐
│ ■ O que você pode fazer                            [─][□][✕]  │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────┬────────┬───────┬────────┬──────┬────────┬────────┐ │
│  │ Chat │ Canais │ Rede  │ Social │ P2P  │ Admin  │Comandos│ │
│  └──────┴────────┴───────┴────────┴──────┴────────┴────────┘ │
│                                                               │
│  (conteúdo varia por aba)                                     │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

### Seção 5 — Aba P2P (NOVA)

```
┌── ABA: P2P — Conexão Direta ─────────────────────────────────┐
│                                                               │
│  Conecte-se diretamente. Sem intermediários.                  │
│                                                               │
│  O RetroHexChat traz de volta o DCC do IRC — mas com          │
│  tecnologia de 2026. WebRTC, criptografia ponta-a-ponta,     │
│  e travessia automática de NAT.                               │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                                                        │  │
│  │  ┌─────────────────────────────────────────────────┐   │  │
│  │  │ ■ Sessão P2P — alice ↔ bob          [─][□][✕]  │   │  │
│  │  ├─────────────────────────────────────────────────┤   │  │
│  │  │                                                 │   │  │
│  │  │  *** Sessão P2P criada por alice                │   │  │
│  │  │  *** bob entrou no lobby                        │   │  │
│  │  │  <alice> vou te mandar o relatório              │   │  │
│  │  │  <bob> manda aí!                                │   │  │
│  │  │                                                 │   │  │
│  │  │  ┌────────────────────────────────────────┐     │   │  │
│  │  │  │ 📁 relatorio.pdf                       │     │   │  │
│  │  │  │ ████████████████░░░░  67%  1.6/2.4 MB  │     │   │  │
│  │  │  │ Velocidade: 450 KB/s                    │     │   │  │
│  │  │  └────────────────────────────────────────┘     │   │  │
│  │  │                                                 │   │  │
│  │  └─────────────────────────────────────────────────┘   │  │
│  │                                                        │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                               │
│  O que o P2P oferece:                                         │
│                                                               │
│  • Transferência de arquivos — direto entre navegadores,      │
│    sem que o arquivo passe pelo servidor                      │
│  • Chamadas de áudio e vídeo — criptografia obrigatória,     │
│    qualidade adaptativa                                       │
│  • Lobby com chat — negocie antes de iniciar a ação           │
│  • Aceite bilateral — nada acontece sem consentimento         │
│    explícito dos dois lados                                   │
│  • Modo privado (TURN-only) — esconde seu IP do outro peer   │
│                                                               │
│  Comandos:                                                    │
│  /p2p <nick>       Abrir sessão P2P                          │
│  /call <nick>      Chamada de áudio/vídeo                    │
│  /sendfile <nick>  Enviar arquivo                            │
│                                                               │
│  Como no DCC do mIRC. Mas com criptografia.                  │
│  E funcionando atrás de NAT.                                  │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

### Seção 6: A Rede

```
┌───────────────────────────────────────────────────────────────┐
│ ■ A Rede RetroHexChat — ao vivo                    [─][□][✕] │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  N servidores. N usuários. N canais federados.                │
│                                                               │
│  ┌───────────────────────────────────────────────────────┐   │
│  │                                                       │   │
│  │     (alpha)──────(beta)                               │   │
│  │      / \           |  \                               │   │
│  │     /   \          |   \                              │   │
│  │  (gamma) (delta) (epsilon) (zeta)                     │   │
│  │     |      |        |                                 │   │
│  │   (eta)  (theta)  (iota)──(kappa)                     │   │
│  │                                                       │   │
│  │  Nós: ícones "computador" pixel art Win98             │   │
│  │  Linhas: conexões federadas                           │   │
│  │  Implementação: SVG estático (fase 1)                 │   │
│  │                                                       │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                               │
├───────────────────────────────────────────────────────────────┤
│  🟢 Rede descentralizada │ Cada nó é independente            │
└───────────────────────────────────────────────────────────────┘

NOTA: Na fase 1 (MVP), o grafo é ilustrativo (SVG estático).
Na fase 2, pode ser alimentado por dados reais da rede.
```

### Seção 7: Rode o Seu

```
┌───────────────────────────────────────────────────────────────┐
│ ■ C:\SETUP.EXE — Rode o seu servidor              [─][□][✕]  │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  Quer seu próprio servidor? Três passos.                      │
│                                                               │
│  ┌─ fieldset ────────────────────────────────────────────┐   │
│  │  Passo 1: Instalar                                    │   │
│  │  <pre>                                                │   │
│  │  $ git clone https://github.com/...                   │   │
│  │  $ cd retro_hex_chat && mix deps.get                  │   │
│  │  $ mix ecto.setup                                     │   │
│  │  </pre>                                               │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌─ fieldset ────────────────────────────────────────────┐   │
│  │  Passo 2: Configurar                                  │   │
│  │  <pre>                                                │   │
│  │  $ mix retro_hex_chat.setup                           │   │
│  │  Nome do servidor: Alpha Chat                         │   │
│  │  Domínio: alpha.chat                                  │   │
│  │  </pre>                                               │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌─ fieldset ────────────────────────────────────────────┐   │
│  │  Passo 3: Subir e pronto                              │   │
│  │  <pre>                                                │   │
│  │  $ mix phx.server                                     │   │
│  │  🟢 Servidor online!                                  │   │
│  │  </pre>                                               │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                               │
│  Requisitos: Elixir 1.17+, PostgreSQL 16+, 512MB RAM,       │
│  domínio com HTTPS. VPS de $5/mês roda tranquilo.            │
│                                                               │
│  [📖 Documentação]                                            │
│                                                               │
├───────────────────────────────────────────────────────────────┤
│  💾 Open source │ MIT License                                 │
└───────────────────────────────────────────────────────────────┘
```

### Seção 8: Open Source

```
┌───────────────────────────────────────────────────────────────┐
│ ■ C:\OPEN_SOURCE\retro_hex_chat.md                 [─][□][✕] │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  <h2> Código aberto. Sempre. </h2>                           │
│                                                               │
│  RetroHexChat é 100% open source, licenciado sob MIT.         │
│  Qualquer pessoa pode ler, modificar, distribuir e rodar.     │
│  Sem cláusulas restritivas. Sem pegadinhas.                   │
│                                                               │
│  ┌─ fieldset "Repositório" ──────────────────────────────┐   │
│  │                                                       │   │
│  │  🖥 github.com/rodrigomarchi/retro_hex_chat           │   │
│  │                                                       │   │
│  │  ┌─────────────────────────────────────────────────┐  │   │
│  │  │  ★ Stars: N  │  🍴 Forks: N  │  📋 Issues: N  │  │   │
│  │  └─────────────────────────────────────────────────┘  │   │
│  │                                                       │   │
│  │  [⭐ Star no GitHub]   [📥 Clone]   [📖 Docs]       │   │
│  │                                                       │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌─ fieldset "Stack" ────────────────────────────────────┐   │
│  │                                                       │   │
│  │  Backend:   Elixir 1.17+ │ Phoenix 1.8+ │ OTP 27+    │   │
│  │  Frontend:  LiveView 1.0+ │ 98.css │ Vanilla JS      │   │
│  │  Database:  PostgreSQL 16+                            │   │
│  │  Protocolo: Federação própria │ WebRTC (P2P)          │   │
│  │  Licença:   MIT                                       │   │
│  │                                                       │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌─ fieldset "Contribua" ────────────────────────────────┐   │
│  │                                                       │   │
│  │  Quer contribuir? Ótimo. O projeto precisa de:        │   │
│  │                                                       │   │
│  │  📝 Código — bugs, features, refatoração              │   │
│  │  🐛 Bug reports — encontrou um problema? Abra issue   │   │
│  │  📖 Documentação — melhorar docs, traduzir            │   │
│  │  🎨 Design — CSS, pixel art, UX                       │   │
│  │  🧪 Testes — escrever testes, encontrar edge cases    │   │
│  │  🌍 Tradução — ajudar com i18n                        │   │
│  │  💬 Feedback — usar, opinar, sugerir                  │   │
│  │                                                       │   │
│  │  Leia o CONTRIBUTING.md antes do primeiro PR.          │   │
│  │                                                       │   │
│  │  [📖 Guia de Contribuição]  [🐛 Abrir Issue]         │   │
│  │                                                       │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                               │
├───────────────────────────────────────────────────────────────┤
│  💾 MIT License │ Código é de todos                           │
└───────────────────────────────────────────────────────────────┘
```

### Seção 9: Apoie o Projeto

```
┌───────────────────────────────────────────────────────────────┐
│ ■ Apoie o RetroHexChat                             [─][□][✕] │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  <h2> Ajude a manter o projeto vivo. </h2>                   │
│                                                               │
│  RetroHexChat é mantido por voluntários no tempo livre.       │
│  Não tem empresa por trás. Não tem investidor.                │
│  É feito por pessoas que acreditam em software livre          │
│  e comunicação descentralizada.                               │
│                                                               │
│  Sua contribuição ajuda a pagar:                              │
│  • Infraestrutura (servidor de demonstração, CI/CD)           │
│  • Domínios e certificados                                    │
│  • Servidores STUN/TURN para P2P                              │
│  • Tempo de desenvolvimento dedicado                          │
│                                                               │
│  ┌─ fieldset "Como apoiar" ──────────────────────────────┐   │
│  │                                                       │   │
│  │  ┌───────────┐  ┌───────────┐  ┌───────────────────┐ │   │
│  │  │           │  │           │  │                   │ │   │
│  │  │  GitHub   │  │  Open     │  │  PIX / Crypto     │ │   │
│  │  │ Sponsors  │  │ Collective│  │  (direto)         │ │   │
│  │  │           │  │           │  │                   │ │   │
│  │  │ Recorrente│  │ Transparên│  │ Doação única      │ │   │
│  │  │ ou única  │  │ cia total │  │ sem plataforma    │ │   │
│  │  │           │  │           │  │                   │ │   │
│  │  │ [Apoiar]  │  │ [Apoiar]  │  │ [Ver chaves]      │ │   │
│  │  └───────────┘  └───────────┘  └───────────────────┘ │   │
│  │                                                       │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌─ fieldset "Outras formas de ajudar" ──────────────────┐   │
│  │                                                       │   │
│  │  💰 não é a única moeda. Você também pode:            │   │
│  │                                                       │   │
│  │  ⭐ Dar uma star no GitHub                            │   │
│  │  📢 Divulgar para amigos e comunidades                │   │
│  │  📝 Contribuir código, docs ou traduções              │   │
│  │  🐛 Reportar bugs e sugerir features                  │   │
│  │  🖥 Rodar um servidor e expandir a rede               │   │
│  │  📖 Escrever sobre o projeto                          │   │
│  │                                                       │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                               │
│  Transparência: todo dinheiro recebido e gasto é público.     │
│  Sem surpresas. Sem contas secretas.                          │
│                                                               │
├───────────────────────────────────────────────────────────────┤
│  ❤ Mantido pela comunidade                                    │
└───────────────────────────────────────────────────────────────┘
```

### Seção 10: FAQ

```
┌───────────────────────────────────────────────────────────────┐
│ ■ Perguntas frequentes                             [─][□][✕] │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  Implementado com <details>/<summary> nativo do HTML.         │
│  Estilizado para parecer tree-view 98.css.                    │
│  Sem JS necessário para expand/collapse.                      │
│                                                               │
│  📁 Perguntas frequentes                                      │
│  ├─ 📄 Preciso rodar meu próprio servidor?                   │
│  ├─ 📄 Posso falar com pessoas de outros servidores?         │
│  ├─ 📄 O que acontece se meu servidor sair do ar?            │
│  ├─ 📄 É seguro?                                             │
│  ├─ 📄 Qual a diferença para Matrix/Mastodon?                │
│  ├─ 📄 Posso usar para minha empresa?                        │
│  ├─ 📄 É de graça?                                           │
│  ├─ 📄 Tem app mobile?                                       │
│  ├─ 📄 O que é P2P no RetroHexChat?                          │
│  ├─ 📄 Posso migrar minha comunidade do Discord?             │
│  ├─ 📄 Como posso contribuir?                                │
│  └─ 📄 Como posso apoiar financeiramente?                    │
│                                                               │
├───────────────────────────────────────────────────────────────┤
│  12 perguntas                                                 │
└───────────────────────────────────────────────────────────────┘

NOTAS:
─ Pergunta P2P: transferência de arquivos, chamadas, criptografia E2E.
─ Pergunta contribuição: links para CONTRIBUTING.md, issues, áreas de ajuda.
─ Pergunta doação: GitHub Sponsors, Open Collective, PIX/Crypto, transparência.
```

### Seção 11: Footer

```
┌───────────────────────────────────────────────────────────────┐
│ ■ Sobre                                            [─][□][✕] │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  RetroHexChat é software livre, licenciado sob MIT.           │
│  Feito com Elixir, Phoenix, e LiveView.                       │
│  Inspirado pelo IRC dos anos 2000 e pela liberdade            │
│  que ele representava.                                        │
│                                                               │
│  ┌──────────────┬──────────────┬──────────────┬────────────┐ │
│  │ PROJETO      │ COMUNIDADE   │ LEGAL        │ APOIE      │ │
│  │              │              │              │            │ │
│  │ GitHub       │ #help        │ Licença MIT  │ Sponsors   │ │
│  │ Docs         │ #dev         │ Privacidade  │ Open Coll. │ │
│  │ Changelog    │ #general     │ Termos       │ PIX/Crypto │ │
│  │ Roadmap      │ Diretório    │ Segurança    │            │ │
│  │ Contributing │              │ (security    │ ⭐ Star    │ │
│  │ Issues       │              │  .md)        │            │ │
│  └──────────────┴──────────────┴──────────────┴────────────┘ │
│                                                               │
│  "A internet é uma rede de redes.                             │
│   O chat deveria ser também."                                 │
│                                                               │
├───────────────────────────────────────────────────────────────┤
│  v0.x.x │ MIT License │ Feito por humanos │ 2025-2026        │
└───────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────┐
│ [🖥 RetroHexChat]                                    4:20 PM  │
└───────────────────────────────────────────────────────────────┘
  Taskbar inferior: relógio real (JS), scroll-to-top.

LINKS DO FOOTER (todos apontam para URLs reais):
─────────────────────────────────────────────────
PROJETO:
  GitHub        → https://github.com/rodrigomarchi/retro_hex_chat
  Docs          → /landing/install (ou link externo se tiver)
  Changelog     → /landing/changelog (ou GitHub releases)
  Roadmap       → /landing/roadmap (ou GitHub projects)
  Contributing  → https://github.com/rodrigomarchi/retro_hex_chat/blob/main/CONTRIBUTING.md
  Issues        → https://github.com/rodrigomarchi/retro_hex_chat/issues

LEGAL:
  Licença MIT   → https://github.com/rodrigomarchi/retro_hex_chat/blob/main/LICENSE
  Privacidade   → /landing/privacy
  Termos        → /landing/terms
  Segurança     → https://github.com/rodrigomarchi/retro_hex_chat/blob/main/SECURITY.md

APOIE:
  Sponsors      → https://github.com/sponsors/rodrigomarchi
  Open Coll.    → (quando criado)
  PIX/Crypto    → /landing/donate
  ⭐ Star       → https://github.com/rodrigomarchi/retro_hex_chat
```

---

## VII. Responsividade

```
DESKTOP (>1024px):
─ Janelas com max-width, centralizadas com margin: auto
─ Seção 3 (Solução): 2 janelas lado a lado (grid 2 colunas)
─ Footer: 3 colunas
─ Taskbar: todos os links visíveis

TABLET (768-1024px):
─ Janelas centralizadas, width: 90%
─ Seção 3: 2 janelas empilhadas
─ Footer: 2 colunas
─ Taskbar: todos os links (compacto)

MOBILE (<768px):
─ Janelas full-width com margin: 8px
─ Tudo empilhado (1 coluna)
─ Footer: 1 coluna
─ Taskbar: menu hamburguer
─ Abas: scroll horizontal se necessário
```

---

## VIII. CSS Architecture — Landing

O CSS da landing é um bundle separado. NÃO é importado no `app.css`.

```
assets/css/
└── landing.css             # Arquivo principal da landing

Dentro do landing.css:
─────────────────────
1. Reset/base mínimo (ou 98.css como base)
2. Desktop (fundo teal, ícones)
3. Taskbar (fixa, navegação)
4. Window (seções como janelas 98.css)
5. Seção-specific (hero, problema, solução, etc.)
6. Tabs (abas para "Como Funciona" e "Features")
7. FAQ (tree-view com details/summary)
8. Footer
9. Responsividade (media queries)
10. Animações (window-open, scroll-reveal)
11. Acessibilidade (prefers-reduced-motion)
```

---

## IX. JavaScript — Landing

```javascript
// landing.js — funcionalidades:

1. Scroll suave para âncoras (taskbar links → seções)
2. Abas (Como Funciona, Features) — show/hide panels
3. Taskbar mobile — toggle menu hamburguer
4. Relógio na taskbar inferior (atualiza a cada minuto)
5. Scroll-reveal — animação de "abrir janela" ao scrollar
   (IntersectionObserver)
6. Desktop icons — click handlers (scroll ou easter egg)
7. Konami code — easter egg (↑↑↓↓←→←→BA)

SEM DEPENDÊNCIAS. Vanilla JS, ES2020+.
Estimativa: ~150-250 linhas.
```

---

## X. Performance e Acessibilidade

```
PERFORMANCE:
────────────
─ 98.css: ~10KB gzipped
─ landing.css: estimativa ~5-10KB
─ landing.js: estimativa ~3-5KB
─ Zero frameworks JS
─ Imagens: SVG inline (logo, grafo)
─ Fontes: system fonts (98.css nativo)
─ Total estimado da landing: <50KB (sem cache)

ACESSIBILIDADE:
────────────────
─ Semântica: <header>, <nav>, <main>, <section>, <footer>
─ Headings: h1 (hero) → h2 (seções) → h3 (sub-seções)
─ ARIA: nav com aria-label, sections com aria-labelledby
─ Tab navigation: todos os botões/links focáveis
─ Contraste: Win98 tem alto contraste natural
─ prefers-reduced-motion: desabilita animações
─ <details>/<summary> no FAQ: acessível nativamente
─ Alt text em SVGs e ícones decorativos
─ Skip-to-content link (hidden, visível no focus)
```

---

## XI. Checklist de Implementação

### Fase 1 — Infraestrutura

- [ ] **T01** — Criar pipeline `:landing` no router com layout dedicado
- [ ] **T02** — Criar `LandingController` com action `:index`
- [ ] **T03** — Criar layout `landing.html.heex` (HTML semântico, meta tags SEO, OG tags, Twitter Cards, JSON-LD)
- [ ] **T04** — Criar arquivo `landing.css` (bundle separado, ou `<style>` inline no layout se simples)
- [ ] **T05** — Criar arquivo `landing.js` (bundle separado, defer)
- [ ] **T06** — Configurar esbuild para bundle da landing (se necessário — avaliar se `<link>` estático basta)
- [ ] **T07** — Copiar SVGs de branding para `priv/static/images/landing/` (logo, wordmark, logo-compact)

### Fase 2 — Seções da Página

- [ ] **T08** — Implementar Taskbar (nav fixa, logo, links âncora, botões Entrar/Criar conta, menu mobile)
- [ ] **T09** — Implementar Seção Hero (janela principal, wordmark, subtítulo, CTAs, ícones desktop, status bar)
- [ ] **T10** — Implementar Seção O Problema (janela com lista de problemas, parágrafos nostalgia/transição)
- [ ] **T11** — Implementar Seção A Solução (3 janelas: o que é, o que NÃO é, analogia email)
- [ ] **T12** — Implementar Seção Como Funciona (janela com 4 abas: Servidores, Federação, Identidade, Segurança)
- [ ] **T13** — Implementar Seção Features (janela com 7 abas: Chat, Canais, Rede, Social, P2P, Admin, Comandos)
- [ ] **T14** — Implementar Seção A Rede (grafo SVG estático ilustrativo)
- [ ] **T15** — Implementar Seção Rode o Seu (3 passos com blocos `<pre>`, requisitos)
- [ ] **T16** — Implementar Seção Open Source (repositório GitHub, stack, badges stars/forks/issues, guia de contribuição)
- [ ] **T17** — Implementar Seção Apoie o Projeto (GitHub Sponsors, Open Collective, PIX/Crypto, outras formas de ajudar)
- [ ] **T18** — Implementar Seção FAQ (details/summary estilizado como tree-view, incluir perguntas P2P, contribuição, doação)
- [ ] **T19** — Implementar Footer (links em 4 colunas: Projeto, Comunidade, Legal, Apoie — com URLs reais do GitHub)
- [ ] **T20** — Implementar Taskbar inferior (relógio real, scroll-to-top)

### Fase 3 — Interatividade e Polish

- [ ] **T21** — Implementar JS: scroll suave para âncoras
- [ ] **T22** — Implementar JS: sistema de abas (Como Funciona + Features)
- [ ] **T23** — Implementar JS: menu mobile (hamburguer toggle)
- [ ] **T24** — Implementar JS: relógio na taskbar inferior
- [ ] **T25** — Implementar JS: scroll-reveal com IntersectionObserver (animação window-open)
- [ ] **T26** — Implementar CSS: responsividade (desktop, tablet, mobile)
- [ ] **T27** — Implementar CSS: animações (window-open, hover states)

### Fase 4 — Easter Eggs e Extras

- [ ] **T28** — Desktop icons clicáveis (Meus Chats → features, Rede → rede, README.txt → manifesto popup, Lixeira → easter egg)
- [ ] **T29** — Konami code (↑↑↓↓←→←→BA → muda wallpaper para Bliss 5s)
- [ ] **T30** — Criar og-image.png (preview do desktop Win98 para social sharing, 1200x630)

### Fase 5 — Arquivos OSS Padrão

- [ ] **T31** — Criar/atualizar CONTRIBUTING.md na raiz do projeto (guia de contribuição, workflow de PR, code style)
- [ ] **T32** — Criar SECURITY.md na raiz do projeto (política de divulgação responsável de vulnerabilidades)
- [ ] **T33** — Verificar LICENSE (MIT) está presente e correto na raiz
- [ ] **T34** — Criar .github/FUNDING.yml (GitHub Sponsors, Open Collective, links de doação)

### Fase 6 — Validação

- [ ] **T35** — Rodar validação CI completa (compile, format, credo, dialyzer, lint.js, lint.css, testes)
- [ ] **T36** — Testar SEO: validar meta tags, heading hierarchy, semântica HTML
- [ ] **T37** — Testar responsividade: desktop, tablet, mobile
- [ ] **T38** — Testar acessibilidade: tab navigation, screen reader, prefers-reduced-motion
- [ ] **T39** — Testar performance: verificar que landing não carrega JS do LiveView/app
