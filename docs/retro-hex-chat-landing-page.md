# Retro Hex Chat — Especificação da Landing Page

## Documento de Design, Conteúdo e Estrutura

### Design System: 98.css (https://jdan.github.io/98.css/)

---

## I. Conceito Visual

A landing page inteira é um "desktop" do Windows 98. Cada seção é uma
`window` do 98.css que o usuário encontra ao scrollar. O fundo é o
teal clássico (#008080). A UX por baixo é moderna: scroll suave,
responsivo, animações de abertura de janela.

### Componentes 98.css que Usamos

```
  Mapeamento direto para os componentes do 98.css:

  COMPONENTE 98.css            ONDE USAMOS
  ─────────────────            ──────────────────────────────
  .window                      Cada seção da landing
  .title-bar                   Cabeçalho de cada seção
  .title-bar-text              Título da seção
  .title-bar-controls          Botões ─ □ ✕ decorativos
  .window-body                 Conteúdo da seção
  button                       CTAs, navegação
  .field-row                   Formulários (login/registro)
  input[type="text"]           Campos de input
  input[type="password"]       Campo de senha
  input[type="radio"]          Escolhas no onboarding
  input[type="checkbox"]       Opções de configuração
  select                       Dropdowns
  .tabs / [role="tabpanel"]    Abas nas seções de features
  .tree-view                   Árvore de servidores/canais
  ul.tree-view                 Lista hierárquica
  .status-bar                  Barra de status nas janelas
  .status-bar-field            Campos da status bar
  fieldset / legend            Agrupamento de opções
  pre                          Blocos de "terminal"
  progress                     Barras de progresso

  CORES DO DESKTOP (fora das windows):
  ─────────────────────────────────────
  Background:  #008080 (teal Win98 clássico)
  Taskbar:     Componente custom usando 98.css tokens

  TIPOGRAFIA:
  ──────────
  98.css já define a fonte padrão (Arial / MS Sans Serif).
  Para blocos de "terminal" e código: usamos <pre> que o
  98.css estiliza com fonte monospace.
```

### Responsividade

```
  DESKTOP (>1024px):
  ─ Janelas flutuam no desktop com posição levemente randômica
  ─ Algumas janelas lado a lado
  ─ Efeito de profundidade (janelas sobrepostas)

  TABLET (768-1024px):
  ─ Janelas centralizadas, uma por vez
  ─ Largura 90%

  MOBILE (<768px):
  ─ Janelas full-width com margem mínima
  ─ Taskbar simplificada
  ─ Menus adaptados

  Em todos os tamanhos: scroll vertical entre seções.
  Cada seção (window) aparece com animação de "abrir janela".
```

---

## II. Mapa Completo da Página

```
  ORDEM DE SCROLL (top → bottom):
  ═══════════════════════════════

  ┌──────────────────────────────────┐
  │  TASKBAR (fixa no topo)          │ ← navegação global
  └──────────────────────────────────┘

  ┌──────────────────────────────────┐
  │  SEÇÃO 1: HERO                   │ ← primeira impressão + CTA
  └──────────────────────────────────┘

  ┌──────────────────────────────────┐
  │  SEÇÃO 2: O PROBLEMA             │ ← por que isso existe
  └──────────────────────────────────┘

  ┌──────────────────────────────────┐
  │  SEÇÃO 3: A SOLUÇÃO              │ ← o que é o Retro Hex Chat
  └──────────────────────────────────┘

  ┌──────────────────────────────────┐
  │  SEÇÃO 4: COMO FUNCIONA          │ ← explicação técnica acessível
  └──────────────────────────────────┘

  ┌──────────────────────────────────┐
  │  SEÇÃO 5: FEATURES               │ ← abas com funcionalidades
  └──────────────────────────────────┘

  ┌──────────────────────────────────┐
  │  SEÇÃO 6: A REDE                 │ ← mapa visual da federação
  └──────────────────────────────────┘

  ┌──────────────────────────────────┐
  │  SEÇÃO 7: RODE O SEU             │ ← para quem quer hospedar
  └──────────────────────────────────┘

  ┌──────────────────────────────────┐
  │  SEÇÃO 8: PERGUNTAS FREQUENTES   │ ← FAQ
  └──────────────────────────────────┘

  ┌──────────────────────────────────┐
  │  SEÇÃO 9: FOOTER                 │ ← links, open source, créditos
  └──────────────────────────────────┘

  ┌──────────────────────────────────┐
  │  TELA: LOGIN / REGISTRO          │ ← acessível via CTA
  └──────────────────────────────────┘

  ┌──────────────────────────────────┐
  │  TELA: ONBOARDING (pós-registro) │ ← escolher nick, avatar, etc.
  └──────────────────────────────────┘
```

---

## III. Taskbar (Fixa no Topo)

A taskbar é fixa e acompanha o scroll. Usa a estética da barra
de tarefas do Windows 98 mas funciona como navbar moderna.

```
┌──────────────────────────────────────────────────────────────────────┐
│ [🖥 Retro Hex Chat]  │ O Problema │ A Solução │ Como Funciona │ Features │   │
│             │            │           │               │          │   │
│                                           [Entrar]  [Criar conta]  │
└──────────────────────────────────────────────────────────────────────┘

  DETALHES:
  ─────────
  ─ [🖥 Retro Hex Chat] é o botão "Start" — ícone pixelado + nome
    Ao clicar: scroll suave até o topo (hero)

  ─ Links centrais: scroll suave até a seção correspondente
    Estilo: texto simples, sem botão, sublinhado no hover

  ─ [Entrar] e [Criar conta]: componentes <button> do 98.css
    [Entrar] = botão default
    [Criar conta] = botão com destaque (pode usar estilo
    "default focused" do 98.css)

  ─ No mobile: taskbar colapsa, links viram menu "Start"
    que abre ao clicar no [🖥 Retro Hex Chat]

  MOBILE:
  ┌──────────────────────────────────────┐
  │ [🖥 Retro Hex Chat]           [Entrar] [▼]   │
  └──────────────────────────────────────┘
    Ao clicar [▼]:
  ┌──────────────────────────────────────┐
  │  O Problema                          │
  │  A Solução                           │
  │  Como Funciona                       │
  │  Features                            │
  │  ─────────────                       │
  │  Criar conta                         │
  └──────────────────────────────────────┘
```

---

## IV. Seção 1 — HERO

A primeira coisa que o visitante vê. Uma janela grande centralizada
no desktop teal. Impacto imediato.

```
  ┌─ BACKGROUND: #008080 (teal) ─ desktop wallpaper ─────────────────┐
  │                                                                   │
  │   Ícones decorativos no desktop (estilo Win98):                   │
  │   [📁 Meus Chats]  [🌐 Rede]  [📝 README.txt]  [🗑 Lixeira]    │
  │                                                                   │
  │   ┌─────────────────────────────────────────────────────────┐     │
  │   │ ■ Retro Hex Chat — Bem-vindo                          [─][□][✕] │     │
  │   ├─────────────────────────────────────────────────────────┤     │
  │   │                                                         │     │
  │   │                                                         │     │
  │   │           ░█░█░ RETRO HEX CHAT ░█░█░                             │     │
  │   │                                                         │     │
  │   │        Chat federado. Como nos velhos tempos.           │     │
  │   │            Mas com a tecnologia de hoje.                │     │
  │   │                                                         │     │
  │   │   Rode seu próprio servidor. Conecte com outros.        │     │
  │   │   Sem empresa no meio. Sem algoritmos. Sem permissão.   │     │
  │   │                                                         │     │
  │   │   Seus dados. Suas regras. Sua comunidade.              │     │
  │   │                                                         │     │
  │   │                                                         │     │
  │   │     ┌──────────────────┐  ┌───────────────────────┐    │     │
  │   │     │  ▶ Criar conta   │  │   Entrar no servidor  │    │     │
  │   │     └──────────────────┘  └───────────────────────┘    │     │
  │   │                                                         │     │
  │   │     Já existe uma rede. 47 servidores. 12k usuários.   │     │
  │   │                                                         │     │
  │   ├─────────────────────────────────────────────────────────┤     │
  │   │ 🟢 Rede online │ 47 servidores │ 342 canais federados  │     │
  │   └─────────────────────────────────────────────────────────┘     │
  │                                                                   │
  │   ↓ scroll para saber mais                                       │
  │                                                                   │
  └───────────────────────────────────────────────────────────────────┘

  TEXTOS:
  ─────────

  Título (art ASCII ou pixel font):
    "RETRO HEX CHAT"

  Subtítulo:
    "Chat federado. Como nos velhos tempos.
     Mas com a tecnologia de hoje."

  Descrição:
    "Rode seu próprio servidor. Conecte com outros.
     Sem empresa no meio. Sem algoritmos. Sem permissão.
     Seus dados. Suas regras. Sua comunidade."

  Social proof:
    "Já existe uma rede. 47 servidores. 12k usuários."
    (números dinâmicos — puxados da rede real)

  Status bar:
    "🟢 Rede online │ 47 servidores │ 342 canais federados"

  CTAs:
    Primário:   [▶ Criar conta]     → abre tela de registro
    Secundário: [Entrar no servidor] → abre tela de login

  NOTA SOBRE O LOGO:
  O logo "RETRO HEX CHAT" pode ser renderizado em pixel art ou como
  ASCII art estilo banner. Referência:

    ███████╗██╗  ██╗██╗██████╗  ██████╗
    ██╔════╝╚██╗██╔╝██║██╔══██╗██╔════╝
    █████╗   ╚███╔╝ ██║██████╔╝██║
    ██╔══╝   ██╔██╗ ██║██╔══██╗██║
    ███████╗██╔╝ ██╗██║██║  ██║╚██████╗
    ╚══════╝╚═╝  ╚═╝╚═╝╚═╝  ╚═╝ ╚═════╝
```

---

## V. Seção 2 — O PROBLEMA

Janela que aparece ao scrollar. Tom: direto, um pouco provocativo,
sem ser agressivo. Fala com quem já perdeu algo na centralização.

```
  ┌───────────────────────────────────────────────────────────────┐
  │ ■ C:\VERDADE\sobre_o_chat_moderno.txt            [─][□][✕]  │
  ├───────────────────────────────────────────────────────────────┤
  │                                                               │
  │  ⚠ Sua comunidade não é sua.                                 │
  │                                                               │
  │  Você construiu uma comunidade no Discord. Ou no Slack.       │
  │  Investiu meses. Milhares de mensagens. Conexões reais.       │
  │                                                               │
  │  Agora pense:                                                 │
  │                                                               │
  │  ┌─────────────────────────────────────────────────────────┐  │
  │  │                                                         │  │
  │  │  ✕ O Discord pode banir seu servidor amanhã.            │  │
  │  │    Sem aviso. Sem apelação. Sem backup.                 │  │
  │  │                                                         │  │
  │  │  ✕ O Slack cobra por mensagem que você já enviou.       │  │
  │  │    Seu histórico, atrás de um paywall.                  │  │
  │  │                                                         │  │
  │  │  ✕ O Telegram pode ser bloqueado no seu país inteiro.   │  │
  │  │    Uma decisão judicial e sua comunidade some.          │  │
  │  │                                                         │  │
  │  │  ✕ O Twitter/X mudou as regras do DM. De novo.         │  │
  │  │    Sua rede de contatos, refém de uma empresa.          │  │
  │  │                                                         │  │
  │  │  ✕ Seus dados treinam a IA de outra empresa.            │  │
  │  │    Suas conversas viram produto.                        │  │
  │  │                                                         │  │
  │  └─────────────────────────────────────────────────────────┘  │
  │                                                               │
  │                                                               │
  │  Nos anos 2000, não era assim.                                │
  │                                                               │
  │  Você rodava um servidor de IRC no porão de casa.             │
  │  Conectava na EFnet, na Undernet, na BrasIRC.                 │
  │  Sua comunidade existia em uma rede que ninguém controlava.   │
  │  Ninguém podia tirar ela de você.                             │
  │                                                               │
  │  Depois veio a "conveniência". E junto veio o controle.       │
  │                                                               │
  │                                                               │
  ├───────────────────────────────────────────────────────────────┤
  │  📄 C:\VERDADE\                                               │
  └───────────────────────────────────────────────────────────────┘
```

**Textos desta seção:**

Título da janela: `C:\VERDADE\sobre_o_chat_moderno.txt`

Headline: "⚠ Sua comunidade não é sua."

Os 5 pontos (estilizados como items de uma lista sunken do 98.css, usando
uma `<ul>` dentro de um `fieldset` sunken):

1. "O Discord pode banir seu servidor amanhã. Sem aviso. Sem apelação. Sem backup."
2. "O Slack cobra por mensagem que você já enviou. Seu histórico, atrás de um paywall."
3. "O Telegram pode ser bloqueado no seu país inteiro. Uma decisão judicial e sua comunidade some."
4. "O Twitter/X mudou as regras do DM. De novo. Sua rede de contatos, refém de uma empresa."
5. "Seus dados treinam a IA de outra empresa. Suas conversas viram produto."

Parágrafo nostálgico:
"Nos anos 2000, não era assim. Você rodava um servidor de IRC no porão
de casa. Conectava na EFnet, na Undernet, na BrasIRC. Sua comunidade
existia em uma rede que ninguém controlava. Ninguém podia tirar ela
de você."

Parágrafo de transição:
"Depois veio a 'conveniência'. E junto veio o controle."

---

## VI. Seção 3 — A SOLUÇÃO

O que é o Retro Hex Chat. Explicação de alto nível, sem jargão técnico.
Duas janelas lado a lado (no mobile, empilhadas).

```
  ┌───── JANELA ESQUERDA ──────────────────┐  ┌───── JANELA DIREITA ─────────────────┐
  │ ■ O que é o Retro Hex Chat             [─][□][✕]│  │ ■ O que NÃO é              [─][□][✕]│
  ├────────────────────────────────────────┤  ├─────────────────────────────────────┤
  │                                        │  │                                     │
  │  Retro Hex Chat é um software de chat que       │  │  Retro Hex Chat NÃO é um serviço.            │
  │  qualquer pessoa pode instalar e       │  │                                     │
  │  rodar no seu próprio servidor.        │  │  Não tem uma empresa por trás       │
  │                                        │  │  controlando a rede.                │
  │  Cada servidor Retro Hex Chat se conecta        │  │                                     │
  │  com outros servidores Retro Hex Chat,          │  │  Não tem plano "Pro" ou             │
  │  formando uma rede descentralizada.    │  │  "Enterprise".                      │
  │                                        │  │                                     │
  │  Pense como email:                     │  │  Não tem algoritmo decidindo        │
  │  • Você escolhe onde criar sua conta   │  │  o que você vê.                     │
  │  • Pode falar com qualquer pessoa      │  │                                     │
  │    em qualquer servidor                │  │  Não pode ser comprado,             │
  │  • Se não gosta do seu servidor,       │  │  adquirido, ou desligado.           │
  │    muda e leva sua identidade          │  │                                     │
  │                                        │  │  É software livre. É um protocolo.  │
  │  É isso. Simples assim.               │  │  É da comunidade.                   │
  │                                        │  │                                     │
  ├────────────────────────────────────────┤  ├─────────────────────────────────────┤
  │  ✓ Pronto                              │  │  ✓ Pronto                           │
  └────────────────────────────────────────┘  └─────────────────────────────────────┘
```

Abaixo das duas janelas, uma terceira janela com a analogia visual:

```
  ┌───────────────────────────────────────────────────────────────┐
  │ ■ Como email, mas para chat                       [─][□][✕]  │
  ├───────────────────────────────────────────────────────────────┤
  │                                                               │
  │   Você entende email? Então você entende Retro Hex Chat.               │
  │                                                               │
  │   ┌──────────────────────────────────────────────────────┐    │
  │   │                                                      │    │
  │   │  EMAIL                          RETRO HEX CHAT                │    │
  │   │                                                      │    │
  │   │  alice@gmail.com                @alice@alpha.chat    │    │
  │   │  bob@outlook.com                @bob@beta.chat       │    │
  │   │                                                      │    │
  │   │  Gmail não controla o email.    alpha.chat não       │    │
  │   │  Outlook não controla o email.  controla o Retro Hex Chat.    │    │
  │   │  O protocolo é de todos.        O protocolo é de     │    │
  │   │                                 todos.               │    │
  │   │                                                      │    │
  │   │  alice@gmail manda email        @alice@alpha.chat    │    │
  │   │  para bob@outlook.              manda mensagem para  │    │
  │   │  Funciona.                      @bob@beta.chat.      │    │
  │   │                                 Funciona.            │    │
  │   │                                                      │    │
  │   └──────────────────────────────────────────────────────┘    │
  │                                                               │
  │   A diferença? Retro Hex Chat é em tempo real. Com canais.             │
  │   Com presença. Com reações. Com tudo que você espera         │
  │   de um chat moderno.                                         │
  │                                                               │
  ├───────────────────────────────────────────────────────────────┤
  │  ✓ Entendi                                                    │
  └───────────────────────────────────────────────────────────────┘
```

---

## VII. Seção 4 — COMO FUNCIONA

Seção mais técnica, mas ainda acessível. Usa abas do 98.css para
separar conceitos.

```
  ┌───────────────────────────────────────────────────────────────┐
  │ ■ Como funciona                                   [─][□][✕]  │
  ├───────────────────────────────────────────────────────────────┤
  │                                                               │
  │  ┌──────────┬────────────┬────────────┬──────────────────┐    │
  │  │Servidores│ Federação  │ Identidade │ Segurança        │    │
  │  └──────────┴────────────┴────────────┴──────────────────┘    │
  │  ┌───────────────────────────────────────────────────────┐    │
  │  │                                                       │    │
  │  │                   (conteúdo da aba ativa)             │    │
  │  │                                                       │    │
  │  └───────────────────────────────────────────────────────┘    │
  │                                                               │
  ├───────────────────────────────────────────────────────────────┤
  │  📖 4 conceitos │ 2 min de leitura                            │
  └───────────────────────────────────────────────────────────────┘
```

### Aba 1: Servidores

```
  ┌── ABA: Servidores ───────────────────────────────────────────┐
  │                                                              │
  │  Cada servidor Retro Hex Chat é independente.                         │
  │                                                              │
  │  ┌─────────┐     ┌─────────┐     ┌─────────┐               │
  │  │ alpha   │     │  beta   │     │  gamma  │               │
  │  │  .chat  │     │  .chat  │     │  .community             │
  │  │         │     │         │     │         │               │
  │  │ 👥 342  │     │ 👥 1.2k │     │ 👥 89  │               │
  │  │ 📢 12ch │     │ 📢 34ch │     │ 📢 7ch │               │
  │  └─────────┘     └─────────┘     └─────────┘               │
  │                                                              │
  │  Qualquer pessoa pode rodar um servidor.                     │
  │  Cada um tem seus usuários, canais, e regras.                │
  │  O dono do servidor decide tudo sobre o seu servidor.        │
  │                                                              │
  │  Públicos: aparecem no diretório, qualquer um entra.         │
  │  Privados: por convite, para sua empresa ou grupo.           │
  │                                                              │
  └──────────────────────────────────────────────────────────────┘
```

### Aba 2: Federação

```
  ┌── ABA: Federação ────────────────────────────────────────────┐
  │                                                              │
  │  Servidores se conectam entre si. Isso é federação.          │
  │                                                              │
  │  ┌─────────┐ ←── #elixir ──→ ┌─────────┐                   │
  │  │  alpha  │                  │  beta   │                   │
  │  │  .chat  │ ←── #phoenix ──→ │  .chat  │                   │
  │  └─────────┘                  └─────────┘                   │
  │       │                                                      │
  │       └──── #linux ──→ ┌─────────┐                          │
  │                        │  gamma  │                          │
  │                        │ .community                         │
  │                        └─────────┘                          │
  │                                                              │
  │  O canal #elixir existe em alpha E em beta.                  │
  │  Quando alguém fala no #elixir do alpha, a mensagem          │
  │  aparece automaticamente no #elixir do beta. E vice-versa.   │
  │                                                              │
  │  É como se fosse o mesmo canal, mas cada servidor            │
  │  guarda suas próprias mensagens.                             │
  │                                                              │
  │  O admin de cada servidor decide com quem federar.           │
  │  Não quer? Não federa. Simples.                              │
  │                                                              │
  └──────────────────────────────────────────────────────────────┘
```

### Aba 3: Identidade

```
  ┌── ABA: Identidade ───────────────────────────────────────────┐
  │                                                              │
  │  Sua identidade inclui o servidor onde você está.            │
  │                                                              │
  │  ┌──────────────────────────────────────────────────────┐   │
  │  │                                                      │   │
  │  │   @alice           →  Alice no servidor local        │   │
  │  │   @alice@alpha.chat →  Alice de qualquer lugar       │   │
  │  │                                                      │   │
  │  └──────────────────────────────────────────────────────┘   │
  │                                                              │
  │  No seu servidor, você é só @alice.                          │
  │  Para o resto da rede, você é @alice@alpha.chat.             │
  │                                                              │
  │  Você pode:                                                  │
  │  • Conversar em canais federados com pessoas de              │
  │    qualquer servidor                                         │
  │  • Enviar mensagens diretas para qualquer usuário            │
  │  • Seguir pessoas de outros servidores                       │
  │  • Ter um perfil visível em toda a rede                      │
  │                                                              │
  └──────────────────────────────────────────────────────────────┘
```

### Aba 4: Segurança

```
  ┌── ABA: Segurança ────────────────────────────────────────────┐
  │                                                              │
  │  Cada mensagem entre servidores é assinada                   │
  │  criptograficamente.                                         │
  │                                                              │
  │  ┌──────────────────────────────────────────────────────┐   │
  │  │                                                      │   │
  │  │  Alice envia "Oi!"                                   │   │
  │  │       │                                              │   │
  │  │       ▼                                              │   │
  │  │  alpha.chat ASSINA com sua chave privada             │   │
  │  │       │                                              │   │
  │  │       ▼                                              │   │
  │  │  beta.chat VERIFICA com a chave pública              │   │
  │  │  de alpha.chat                                       │   │
  │  │       │                                              │   │
  │  │       ▼                                              │   │
  │  │  ✓ Mensagem é genuína → entrega para os             │   │
  │  │    usuários de beta                                  │   │
  │  │                                                      │   │
  │  └──────────────────────────────────────────────────────┘   │
  │                                                              │
  │  Ninguém pode forjar mensagens de outro servidor.            │
  │  Ninguém pode ler mensagens no caminho.                      │
  │  Cada servidor prova quem é com criptografia,                │
  │  não com confiança cega.                                     │
  │                                                              │
  └──────────────────────────────────────────────────────────────┘
```

---

## VIII. Seção 5 — FEATURES

Janela com abas mostrando as funcionalidades. Cada aba tem um
mini-mockup demonstrativo.

```
  ┌───────────────────────────────────────────────────────────────┐
  │ ■ O que você pode fazer                           [─][□][✕]  │
  ├───────────────────────────────────────────────────────────────┤
  │                                                               │
  │  ┌──────┬──────────┬───────┬─────────┬────────┬──────────┐   │
  │  │ Chat │ Canais   │ Rede  │ Social  │ Admin  │ Comandos │   │
  │  └──────┴──────────┴───────┴─────────┴────────┴──────────┘   │
  │                                                               │
  │  (conteúdo da aba ativa abaixo)                               │
  │                                                               │
  └───────────────────────────────────────────────────────────────┘
```

### Aba: Chat

```
  ┌── ABA: Chat ─────────────────────────────────────────────────┐
  │                                                              │
  │  Chat em tempo real. Zero refresh. Zero loading.             │
  │                                                              │
  │  ┌──────────────────────────────────────────────────────┐   │
  │  │  #elixir@alpha.chat                                  │   │
  │  │  ─────────────────                                   │   │
  │  │                                                      │   │
  │  │  ● alice                             10:23           │   │
  │  │    Bom dia! Alguém testou o Phoenix 1.8?             │   │
  │  │                                                      │   │
  │  │  ● bob@beta.chat             [beta]  10:24           │   │
  │  │    Sim! O LiveView tá muito bom                      │   │
  │  │    👍 2  🎉 1                                        │   │
  │  │                                                      │   │
  │  │  ● carol@gamma          [gamma]  10:25               │   │
  │  │    Concordo, a performance melhorou demais            │   │
  │  │    └─ alice: top! vou testar hoje                    │   │
  │  │                                                      │   │
  │  │  ────────────────────────────────────────────        │   │
  │  │  [  Mensagem...                      ] [Enviar]      │   │
  │  └──────────────────────────────────────────────────────┘   │
  │                                                              │
  │  • Mensagens em tempo real via WebSocket                     │
  │  • Reações em emoji                                          │
  │  • Threads (respostas encadeadas)                            │
  │  • Usuários de outros servidores com badge                   │
  │  • Markdown nas mensagens                                    │
  │  • Upload de arquivos e imagens                              │
  │                                                              │
  └──────────────────────────────────────────────────────────────┘
```

### Aba: Canais

```
  ┌── ABA: Canais ───────────────────────────────────────────────┐
  │                                                              │
  │  Canais são salas de conversa. Públicos, privados,           │
  │  ou federados com outros servidores.                         │
  │                                                              │
  │  ┌──────────────────────────────────────────────────────┐   │
  │  │  MEUS CANAIS                                         │   │
  │  │  ──────────                                          │   │
  │  │  📢 #general          12 online                      │   │
  │  │  📢 #elixir      🔗   34 online   (federado)        │   │
  │  │  📢 #random            8 online                      │   │
  │  │  🔒 #equipe            5 online   (privado)          │   │
  │  │                                                      │   │
  │  │  CANAIS FEDERADOS                                    │   │
  │  │  ────────────────                                    │   │
  │  │  📢 #rust@delta.org        89 online                 │   │
  │  │  📢 #linux@gamma.community 201 online                │   │
  │  └──────────────────────────────────────────────────────┘   │
  │                                                              │
  │  • Crie quantos canais quiser                                │
  │  • Públicos: qualquer pessoa entra                           │
  │  • Privados: só por convite                                  │
  │  • Federados: conectados com canais de outros servidores     │
  │  • Topic, modos, slow mode — você controla                   │
  │                                                              │
  └──────────────────────────────────────────────────────────────┘
```

### Aba: Rede

```
  ┌── ABA: Rede ─────────────────────────────────────────────────┐
  │                                                              │
  │  Descubra servidores. Explore a rede. Encontre               │
  │  comunidades.                                                │
  │                                                              │
  │  ┌──────────────────────────────────────────────────────┐   │
  │  │  DIRETÓRIO DE SERVIDORES                             │   │
  │  │  [🔍 Buscar...                                  ]    │   │
  │  │                                                      │   │
  │  │  🟢 beta.chat                                        │   │
  │  │     "Comunidade Brasileira de Elixir"                │   │
  │  │     👥 342  📢 12 canais  🔗 8 federações            │   │
  │  │                                                      │   │
  │  │  🟢 gamma.community                                  │   │
  │  │     "Open Source & Linux Brasil"                      │   │
  │  │     👥 1.2k  📢 34 canais  🔗 15 federações          │   │
  │  │                                                      │   │
  │  │  🔒 delta.internal                                    │   │
  │  │     "Servidor Privado"                                │   │
  │  │                                                      │   │
  │  └──────────────────────────────────────────────────────┘   │
  │                                                              │
  │  • Servidores se descobrem automaticamente via gossip         │
  │  • Diretório público listando toda a rede                    │
  │  • Servidores privados: visíveis mas com conteúdo protegido  │
  │  • Busca por nome, descrição, ou canais                      │
  │                                                              │
  └──────────────────────────────────────────────────────────────┘
```

### Aba: Social

```
  ┌── ABA: Social ───────────────────────────────────────────────┐
  │                                                              │
  │  Não é só IRC. É uma rede social descentralizada.            │
  │                                                              │
  │  ┌──────────────────────────────────────────────────────┐   │
  │  │  FEED DE ATIVIDADE                                   │   │
  │  │  ─────────────────                                   │   │
  │  │                                                      │   │
  │  │  🟢 bob@beta.chat está online                   2min │   │
  │  │                                                      │   │
  │  │  💬 carol@gamma em #elixir:                     5min │   │
  │  │     "Alguém já usou Nx com GPU?"                     │   │
  │  │                                                      │   │
  │  │  👋 dave@epsilon entrou em #rust             1h      │   │
  │  │                                                      │   │
  │  │  🔗 Novo servidor: omega.community           3h      │   │
  │  │     "Comunidade de Open Source PT-BR"                │   │
  │  └──────────────────────────────────────────────────────┘   │
  │                                                              │
  │  • Siga pessoas de qualquer servidor                         │
  │  • Feed com atividade de quem você segue                     │
  │  • Perfis públicos federados                                 │
  │  • Mensagens diretas cross-server                            │
  │  • Status e presença em tempo real                           │
  │                                                              │
  └──────────────────────────────────────────────────────────────┘
```

### Aba: Admin

```
  ┌── ABA: Admin ────────────────────────────────────────────────┐
  │                                                              │
  │  Administre pelo chat. Como nos velhos tempos do IRC.        │
  │                                                              │
  │  ┌──────────────────────────────────────────────────────┐   │
  │  │  > /admin unlock                                     │   │
  │  │  🔒 Modo admin ativado. Expira em 30 min.           │   │
  │  │                                                      │   │
  │  │  > /admin federation peer list                       │   │
  │  │  🟢 beta.chat        3 links  ★ confiável           │   │
  │  │  🟢 gamma.community  2 links                        │   │
  │  │  🟡 epsilon.org      1 link   (2h atrás)            │   │
  │  │  🔴 omega.net        offline  (3 dias)              │   │
  │  │                                                      │   │
  │  │  > /admin federation link accept fed_7a3b            │   │
  │  │  ✓ Federação aceita! #elixir ↔ #elixir@beta.chat    │   │
  │  │                                                      │   │
  │  │  > /admin user ban @spammer --reason "spam"          │   │
  │  │  ✓ @spammer banido permanentemente.                  │   │
  │  └──────────────────────────────────────────────────────┘   │
  │                                                              │
  │  • Comandos IRC-style para tudo                              │
  │  • Dashboard visual opcional                                 │
  │  • Controle granular de federação                            │
  │  • Moderação com audit log completo                          │
  │  • Permissões por papel (admin, mod, op)                     │
  │                                                              │
  └──────────────────────────────────────────────────────────────┘
```

### Aba: Comandos

```
  ┌── ABA: Comandos ─────────────────────────────────────────────┐
  │                                                              │
  │  O poder está nos seus dedos.                                │
  │  (com autocomplete, claro)                                   │
  │                                                              │
  │  ┌──────────────────────────────────────────────────────┐   │
  │  │                                                      │   │
  │  │  PARA TODOS:                                         │   │
  │  │  /join #canal         Entrar em canal                │   │
  │  │  /msg @nick texto     Mensagem direta                │   │
  │  │  /follow @nick@dom    Seguir alguém                  │   │
  │  │  /whois @nick         Ver perfil                     │   │
  │  │  /search termo        Buscar mensagens               │   │
  │  │                                                      │   │
  │  │  PARA OPs:                                           │   │
  │  │  /kick @nick          Expulsar do canal              │   │
  │  │  /ban @nick           Banir do canal                 │   │
  │  │  /topic texto         Mudar topic                    │   │
  │  │  /mode +m             Canal moderado                 │   │
  │  │                                                      │   │
  │  │  PARA ADMINS:                                        │   │
  │  │  /admin unlock        Ativar modo admin              │   │
  │  │  /admin federation ..  Gerenciar federação           │   │
  │  │  /admin user ...      Gerenciar usuários             │   │
  │  │  /admin server ...    Configurar servidor            │   │
  │  │                                                      │   │
  │  └──────────────────────────────────────────────────────┘   │
  │                                                              │
  │  Todos os comandos têm autocomplete inteligente.             │
  │  Digite / e deixe o Retro Hex Chat te guiar.                          │
  │                                                              │
  └──────────────────────────────────────────────────────────────┘
```

---

## IX. Seção 6 — A REDE (Visualização)

Uma representação visual interativa da rede real de servidores.
Se possível, animada com nós pulsando.

```
  ┌───────────────────────────────────────────────────────────────┐
  │ ■ A Rede Retro Hex Chat — ao vivo                          [─][□][✕]  │
  ├───────────────────────────────────────────────────────────────┤
  │                                                               │
  │  47 servidores. 12.000 usuários. 342 canais federados.       │
  │  E crescendo.                                                 │
  │                                                               │
  │  ┌───────────────────────────────────────────────────────┐    │
  │  │                                                       │    │
  │  │        (alpha)──────────(beta)                        │    │
  │  │         / \               |  \                        │    │
  │  │        /   \              |   \                       │    │
  │  │    (gamma)  (delta)   (epsilon) (zeta)                │    │
  │  │       |       |          |                            │    │
  │  │       |       |          |                            │    │
  │  │    (eta)   (theta)    (iota)──(kappa)                 │    │
  │  │              |                   |                    │    │
  │  │           (lambda)            (mu)                    │    │
  │  │                                                       │    │
  │  │  ● = servidor ativo  ○ = offline  ─ = link federado   │    │
  │  │                                                       │    │
  │  │  Cada ponto é um servidor independente.               │    │
  │  │  Cada linha é uma federação entre canais.             │    │
  │  │  Nenhum ponto é mais importante que outro.            │    │
  │  │                                                       │    │
  │  └───────────────────────────────────────────────────────┘    │
  │                                                               │
  │  Hover em um nó para ver detalhes.                            │
  │  Esta visualização mostra a rede real, em tempo real.         │
  │                                                               │
  ├───────────────────────────────────────────────────────────────┤
  │  🟢 Rede saudável │ Última atualização: agora                │
  └───────────────────────────────────────────────────────────────┘

  NOTA DE IMPLEMENTAÇÃO:
  ──────────────────────
  O grafo pode ser renderizado com:
  ─ Canvas simples com nós e arestas
  ─ Ou SVG com animação CSS (nós pulsando)
  ─ Dados puxados do endpoint público de saúde da rede
  ─ Cada nó ao hover mostra: nome, descrição, nº de usuários
  ─ Estética: nós como ícones de "computador" pixelados (Win98),
    linhas pontilhadas conectando
```

---

## X. Seção 7 — RODE O SEU

Para quem quer hospedar um servidor. Tom: empoderador, prático.

```
  ┌───────────────────────────────────────────────────────────────┐
  │ ■ C:\SETUP.EXE — Rode o seu servidor              [─][□][✕] │
  ├───────────────────────────────────────────────────────────────┤
  │                                                               │
  │  Quer seu próprio servidor? Três passos.                      │
  │                                                               │
  │  ┌─ fieldset ────────────────────────────────────────────┐    │
  │  │  Passo 1: Instalar                                    │    │
  │  │                                                       │    │
  │  │  ┌────────────────────────────────────────────────┐   │    │
  │  │  │ $ git clone https://github.com/retro-hex-chat/retro_hex_chat    │   │    │
  │  │  │ $ cd retro_hex_chat                                     │   │    │
  │  │  │ $ mix deps.get                                 │   │    │
  │  │  │ $ mix ecto.setup                               │   │    │
  │  │  └────────────────────────────────────────────────┘   │    │
  │  └───────────────────────────────────────────────────────┘    │
  │                                                               │
  │  ┌─ fieldset ────────────────────────────────────────────┐    │
  │  │  Passo 2: Configurar                                  │    │
  │  │                                                       │    │
  │  │  ┌────────────────────────────────────────────────┐   │    │
  │  │  │ $ mix retro_hex_chat.setup                              │   │    │
  │  │  │                                                │   │    │
  │  │  │ Nome do servidor: Alpha Chat                   │   │    │
  │  │  │ Domínio: alpha.chat                            │   │    │
  │  │  │ Tipo: (x) Público ( ) Privado                  │   │    │
  │  │  │ ✓ Configuração salva!                          │   │    │
  │  │  └────────────────────────────────────────────────┘   │    │
  │  └───────────────────────────────────────────────────────┘    │
  │                                                               │
  │  ┌─ fieldset ────────────────────────────────────────────┐    │
  │  │  Passo 3: Subir e pronto                              │    │
  │  │                                                       │    │
  │  │  ┌────────────────────────────────────────────────┐   │    │
  │  │  │ $ mix phx.server                               │   │    │
  │  │  │                                                │   │    │
  │  │  │ Retro Hex Chat rodando em https://alpha.chat            │   │    │
  │  │  │ Conectando à rede... 3 peers descobertos.      │   │    │
  │  │  │ 🟢 Servidor online e federado.                 │   │    │
  │  │  └────────────────────────────────────────────────┘   │    │
  │  └───────────────────────────────────────────────────────┘    │
  │                                                               │
  │                                                               │
  │  Requisitos mínimos:                                          │
  │  ─ Elixir 1.17+ e PostgreSQL 16+                             │
  │  ─ 512MB RAM (mínimo), 2GB (recomendado)                     │
  │  ─ Domínio com HTTPS (Let's Encrypt funciona)                │
  │  ─ VPS de $5/mês roda tranquilo para comunidades pequenas    │
  │                                                               │
  │  ┌──────────────────┐   ┌──────────────────────────────┐     │
  │  │  📖 Documentação │   │  ▶ Deploy em 1 click (Fly.io)│     │
  │  └──────────────────┘   └──────────────────────────────┘     │
  │                                                               │
  ├───────────────────────────────────────────────────────────────┤
  │  💾 Open source │ MIT License │ GitHub ★ 2.3k                 │
  └───────────────────────────────────────────────────────────────┘
```

---

## XI. Seção 8 — FAQ

Formato de tree-view do 98.css. Cada pergunta expande.

```
  ┌───────────────────────────────────────────────────────────────┐
  │ ■ Perguntas frequentes                            [─][□][✕]  │
  ├───────────────────────────────────────────────────────────────┤
  │                                                               │
  │  📁 Perguntas frequentes                                      │
  │  ├─ 📄 Preciso rodar meu próprio servidor?                   │
  │  │     Não! Você pode criar uma conta em qualquer servidor   │
  │  │     público da rede. É como email: você não precisa ter   │
  │  │     um servidor de email para usar email. Só precisa de   │
  │  │     uma conta em algum servidor.                          │
  │  │                                                           │
  │  ├─ 📄 Posso falar com pessoas de outros servidores?         │
  │  │     Sim! Esse é o ponto principal. Se o canal em que      │
  │  │     você está é federado com outro servidor, as           │
  │  │     mensagens fluem automaticamente. Você também pode     │
  │  │     enviar DMs para qualquer pessoa: @nick@servidor.      │
  │  │                                                           │
  │  ├─ 📄 O que acontece se meu servidor sair do ar?            │
  │  │     Suas mensagens ficam salvas no banco de dados do      │
  │  │     seu servidor. Quando ele voltar, tudo estará lá.      │
  │  │     Mensagens enviadas enquanto ele estava offline são    │
  │  │     sincronizadas automaticamente quando ele reconectar.  │
  │  │                                                           │
  │  ├─ 📄 É seguro?                                             │
  │  │     Toda comunicação entre servidores usa criptografia    │
  │  │     e assinaturas digitais. Ninguém pode forjar           │
  │  │     mensagens de outro servidor. As conexões são HTTPS.   │
  │  │                                                           │
  │  ├─ 📄 Qual a diferença para Matrix/Mastodon?                │
  │  │     Matrix é excelente mas complexo. Mastodon é para      │
  │  │     microblogging, não chat. Retro Hex Chat pega o melhor dos      │
  │  │     dois mundos: a federação de Matrix/Mastodon com a     │
  │  │     simplicidade e foco em chat do IRC. Com UX moderna.   │
  │  │                                                           │
  │  ├─ 📄 Posso usar para minha empresa?                        │
  │  │     Sim! Rode um servidor privado (só por convite),       │
  │  │     configure sua allowlist, e pronto. Você tem um        │
  │  │     Slack-like onde VOCÊ controla os dados.               │
  │  │     E se quiser, ainda pode federar canais específicos    │
  │  │     com parceiros e comunidades externas.                 │
  │  │                                                           │
  │  ├─ 📄 É de graça?                                           │
  │  │     O software é 100% open source e gratuito (MIT).       │
  │  │     Você só paga pela infraestrutura se rodar seu         │
  │  │     servidor (uma VPS de $5/mês é suficiente). Ou use     │
  │  │     um servidor público existente sem pagar nada.         │
  │  │                                                           │
  │  ├─ 📄 Tem app mobile?                                       │
  │  │     A interface web funciona bem no celular (é            │
  │  │     responsiva). Um app nativo está no roadmap.           │
  │  │     Enquanto isso, você pode adicionar à tela inicial     │
  │  │     como PWA.                                             │
  │  │                                                           │
  │  └─ 📄 Posso migrar minha comunidade do Discord?             │
  │        Estamos desenvolvendo ferramentas de importação.      │
  │        Em breve será possível importar histórico de          │
  │        mensagens e lista de membros. Enquanto isso, o        │
  │        bridge Discord está no roadmap para permitir          │
  │        comunicação entre Retro Hex Chat e Discord durante a           │
  │        transição.                                            │
  │                                                              │
  ├───────────────────────────────────────────────────────────────┤
  │  9 perguntas │ Não achou? Pergunte em #help@hub.retrohexchat.net    │
  └───────────────────────────────────────────────────────────────┘

  IMPLEMENTAÇÃO:
  ──────────────
  Usar o componente tree-view do 98.css.
  Cada item começa colapsado (só mostra a pergunta).
  Ao clicar, expande e mostra a resposta.
  A interação é click para toggle (não accordion).
  Múltiplas perguntas podem estar abertas ao mesmo tempo.
```

---

## XII. Seção 9 — FOOTER

```
  ┌───────────────────────────────────────────────────────────────┐
  │ ■ Sobre                                           [─][□][✕]  │
  ├───────────────────────────────────────────────────────────────┤
  │                                                               │
  │  Retro Hex Chat é software livre, licenciado sob MIT.                  │
  │  Feito com Elixir, Phoenix, e LiveView.                       │
  │  Inspirado pelo IRC dos anos 2000 e pela liberdade            │
  │  que ele representava.                                        │
  │                                                               │
  │  ┌─────────────────┬───────────────┬───────────────────┐      │
  │  │ PROJETO         │ COMUNIDADE    │ CONECTE           │      │
  │  │                 │               │                   │      │
  │  │ GitHub          │ #help         │ Mastodon          │      │
  │  │ Documentação    │ #dev          │ Twitter/X         │      │
  │  │ Roadmap         │ #general      │ Blog              │      │
  │  │ Changelog       │ Status da rede│ RSS               │      │
  │  │ Licença (MIT)   │ Diretório     │                   │      │
  │  └─────────────────┴───────────────┴───────────────────┘      │
  │                                                               │
  │  "A internet é uma rede de redes.                             │
  │   O chat deveria ser também."                                 │
  │                                                               │
  ├───────────────────────────────────────────────────────────────┤
  │  v0.1.0 │ Feito por humanos │ 2025-2026                      │
  └───────────────────────────────────────────────────────────────┘

  ABAIXO DO FOOTER, a "taskbar" do Windows 98:

  ┌───────────────────────────────────────────────────────────────┐
  │ [🖥 Retro Hex Chat]                                         4:20 PM   │
  └───────────────────────────────────────────────────────────────┘

  A taskbar mostra a hora real do relógio do visitante.
  O botão [Retro Hex Chat] faz scroll to top.
  Opcional: ao clicar, abre um "menu Start" com os links.
```

---

## XIII. Tela de Login

Acessada ao clicar "Entrar" na taskbar ou no CTA do hero.
Aparece como uma janela de diálogo modal sobre o desktop.

```
  ┌─ BACKGROUND: desktop teal com blur/dim ──────────────────────┐
  │                                                               │
  │                                                               │
  │         ┌───────────────────────────────────────┐             │
  │         │ ■ Entrar — Retro Hex Chat              [✕]     │             │
  │         ├───────────────────────────────────────┤             │
  │         │                                       │             │
  │         │  Servidor:                            │             │
  │         │  ┌────────────────────────────────┐   │             │
  │         │  │ alpha.chat                     │   │             │
  │         │  └────────────────────────────────┘   │             │
  │         │  (este servidor)                      │             │
  │         │                                       │             │
  │         │  Nickname ou email:                   │             │
  │         │  ┌────────────────────────────────┐   │             │
  │         │  │                                │   │             │
  │         │  └────────────────────────────────┘   │             │
  │         │                                       │             │
  │         │  Senha:                               │             │
  │         │  ┌────────────────────────────────┐   │             │
  │         │  │                                │   │             │
  │         │  └────────────────────────────────┘   │             │
  │         │                                       │             │
  │         │  [✓] Lembrar de mim                   │             │
  │         │                                       │             │
  │         │  ┌─────────────┐  ┌──────────────┐   │             │
  │         │  │   Entrar    │  │   Cancelar   │   │             │
  │         │  └─────────────┘  └──────────────┘   │             │
  │         │                                       │             │
  │         │  ─────────────────────────────────    │             │
  │         │  Não tem conta? Criar uma             │             │
  │         │  Esqueceu a senha? Recuperar          │             │
  │         │                                       │             │
  │         ├───────────────────────────────────────┤             │
  │         │  🔒 Conexão segura (HTTPS)            │             │
  │         └───────────────────────────────────────┘             │
  │                                                               │
  └───────────────────────────────────────────────────────────────┘

  COMPORTAMENTO:
  ──────────────
  ─ Campo "Servidor" vem preenchido com o domínio atual
  ─ Pode ser alterado para logar em outro servidor (redireciona)
  ─ Nickname ou email: aceita ambos
  ─ Enter no campo de senha = submit
  ─ Animação de "loading" no botão Entrar ao submeter
  ─ Erro: caixa de diálogo Win98 com ícone ⚠

  ERRO (exemplo):
  ┌──────────────────────────────────────┐
  │  ⚠ Erro de login                    │
  ├──────────────────────────────────────┤
  │                                      │
  │  ⚠  Nickname ou senha incorretos.   │
  │                                      │
  │              ┌──────────┐            │
  │              │    OK    │            │
  │              └──────────┘            │
  └──────────────────────────────────────┘
```

---

## XIV. Tela de Registro

Acessada ao clicar "Criar conta". Também janela modal.

```
  ┌─ BACKGROUND: desktop teal com blur/dim ──────────────────────┐
  │                                                               │
  │      ┌─────────────────────────────────────────────┐          │
  │      │ ■ Criar conta — Retro Hex Chat                  [✕]  │          │
  │      ├─────────────────────────────────────────────┤          │
  │      │                                             │          │
  │      │  Bem-vindo! Crie sua conta em alpha.chat    │          │
  │      │                                             │          │
  │      │  Escolha seu nickname:                      │          │
  │      │  ┌───────────────────────────────────────┐  │          │
  │      │  │ alice                                 │  │          │
  │      │  └───────────────────────────────────────┘  │          │
  │      │  Você será @alice@alpha.chat na rede.       │          │
  │      │                                             │          │
  │      │  Email:                                     │          │
  │      │  ┌───────────────────────────────────────┐  │          │
  │      │  │ alice@email.com                       │  │          │
  │      │  └───────────────────────────────────────┘  │          │
  │      │                                             │          │
  │      │  Senha:                                     │          │
  │      │  ┌───────────────────────────────────────┐  │          │
  │      │  │ ••••••••••••                          │  │          │
  │      │  └───────────────────────────────────────┘  │          │
  │      │                                             │          │
  │      │  Confirmar senha:                           │          │
  │      │  ┌───────────────────────────────────────┐  │          │
  │      │  │ ••••••••••••                          │  │          │
  │      │  └───────────────────────────────────────┘  │          │
  │      │                                             │          │
  │      │  ┌──────────────────────────────────────┐   │          │
  │      │  │         ▶ Criar minha conta          │   │          │
  │      │  └──────────────────────────────────────┘   │          │
  │      │                                             │          │
  │      │  ─────────────────────────────────────────  │          │
  │      │  Já tem conta? Entrar                       │          │
  │      │                                             │          │
  │      ├─────────────────────────────────────────────┤          │
  │      │  💾 Seus dados ficam em alpha.chat           │          │
  │      └─────────────────────────────────────────────┘          │
  │                                                               │
  └───────────────────────────────────────────────────────────────┘

  VALIDAÇÃO EM TEMPO REAL:
  ─────────────────────────
  ─ Nickname: enquanto digita, verifica disponibilidade
    ✓ alice — disponível!
    ✕ bob — já existe neste servidor

  ─ Feedback do domínio: ao digitar o nick, mostra abaixo
    em tempo real: "Você será @alice@alpha.chat na rede."

  ─ Senha: barra de progress do 98.css mostrando "força"
    ┌──────────────────────────────────────┐
    │ Força: ████████░░░░░░░ Boa           │
    └──────────────────────────────────────┘

  ─ Confirmar senha: check visual se combina
    ✓ Senhas combinam
    ✕ Senhas não combinam

  NOTA SOBRE CONVITE:
  Se o servidor exige convite, um campo adicional aparece:

    Código de convite:
    ┌───────────────────────────────────────┐
    │                                       │
    └───────────────────────────────────────┘
    Esse servidor aceita registro apenas por convite.
```

---

## XV. Tela de Onboarding (Pós-Registro)

Após criar a conta, o usuário passa por um onboarding rápido antes
de cair no chat. São janelas sequenciais estilo "wizard" do Win98.

### Passo 1: Personalizar Perfil

```
  ┌─────────────────────────────────────────────────────────────┐
  │ ■ Bem-vindo ao Retro Hex Chat — Configurar perfil (1/3)   [─][□][✕] │
  ├─────────────────────────────────────────────────────────────┤
  │                                                             │
  │  Olá, @alice! Vamos personalizar sua conta.                 │
  │                                                             │
  │  ┌──────────────────────────────────────────────────────┐   │
  │  │                                                      │   │
  │  │  ┌────────┐   Nome de exibição:                     │   │
  │  │  │        │   ┌──────────────────────────────┐      │   │
  │  │  │ avatar │   │ Alice                        │      │   │
  │  │  │        │   └──────────────────────────────┘      │   │
  │  │  │        │                                         │   │
  │  │  └────────┘   Bio (opcional):                       │   │
  │  │  [Escolher    ┌──────────────────────────────┐      │   │
  │  │   avatar]     │ Dev Elixir, gamer, gatos 🐱 │      │   │
  │  │               └──────────────────────────────┘      │   │
  │  │                                                      │   │
  │  └──────────────────────────────────────────────────────┘   │
  │                                                             │
  │  Visibilidade do perfil na rede:                            │
  │    (●) Público — qualquer pessoa pode ver                   │
  │    ( ) Apenas seguidores                                    │
  │    ( ) Privado — só quem está neste servidor                │
  │                                                             │
  │                                                             │
  │  [Pular]                                     [Próximo ►]   │
  │                                                             │
  ├─────────────────────────────────────────────────────────────┤
  │  Passo 1 de 3  ████░░░░░░░░                                │
  └─────────────────────────────────────────────────────────────┘

  NOTA SOBRE AVATARES:
  ────────────────────
  Ao clicar "Escolher avatar", abre uma sub-janela com:
  ─ Upload de imagem própria
  ─ OU galeria de avatares pixelados pré-feitos (tema Win98):
    smiley faces, animais pixel, ícones clássicos do PC
  ─ O avatar é exibido como 32x32 ou 48x48 pixel art style
```

### Passo 2: Entrar em Canais

```
  ┌─────────────────────────────────────────────────────────────┐
  │ ■ Bem-vindo ao Retro Hex Chat — Escolher canais (2/3)     [─][□][✕] │
  ├─────────────────────────────────────────────────────────────┤
  │                                                             │
  │  Escolha alguns canais para começar.                        │
  │  Você pode entrar em mais canais depois.                    │
  │                                                             │
  │  ┌─ Canais deste servidor (alpha.chat) ──────────────────┐  │
  │  │                                                       │  │
  │  │  [✓] #general        Conversa geral           12 on  │  │
  │  │  [✓] #elixir    🔗   Tudo sobre Elixir        34 on  │  │
  │  │  [ ] #random          Qualquer assunto          8 on  │  │
  │  │  [ ] #rust       🔗   Linguagem Rust           23 on  │  │
  │  │  [ ] #gaming          Games e esports          15 on  │  │
  │  │  [ ] #musica          Música e recomendações    7 on  │  │
  │  │  [ ] #dev             Programação geral        19 on  │  │
  │  │                                                       │  │
  │  │  🔗 = federado com outros servidores                  │  │
  │  │                                                       │  │
  │  └───────────────────────────────────────────────────────┘  │
  │                                                             │
  │  ☐ Me inscrever nos canais populares de outros servidores   │
  │    (você poderá explorar o diretório depois)                │
  │                                                             │
  │                                                             │
  │  [◄ Voltar]                                  [Próximo ►]   │
  │                                                             │
  ├─────────────────────────────────────────────────────────────┤
  │  Passo 2 de 3  ████████░░░░                                │
  └─────────────────────────────────────────────────────────────┘

  DETALHES:
  ─────────
  ─ #general e #elixir vêm pré-selecionados (recomendados)
  ─ O 🔗 indica canais federados
  ─ "N on" mostra usuários online agora
  ─ Checkboxes são componentes nativos do 98.css
  ─ A barra de progresso é o componente <progress> do 98.css
```

### Passo 3: Primeiros Passos

```
  ┌─────────────────────────────────────────────────────────────┐
  │ ■ Bem-vindo ao Retro Hex Chat — Tudo pronto! (3/3)        [─][□][✕] │
  ├─────────────────────────────────────────────────────────────┤
  │                                                             │
  │                                                             │
  │              ✓ Conta criada!                                │
  │              ✓ Perfil configurado!                          │
  │              ✓ 2 canais escolhidos!                         │
  │                                                             │
  │  Dicas rápidas:                                             │
  │                                                             │
  │  ┌──────────────────────────────────────────────────────┐   │
  │  │                                                      │   │
  │  │  Digite / para ver comandos disponíveis              │   │
  │  │                                                      │   │
  │  │  /join #canal       para entrar em canais            │   │
  │  │  /msg @nick texto   para mensagem direta             │   │
  │  │  /follow @nick@dom  para seguir alguém               │   │
  │  │  /help              para ver todos os comandos       │   │
  │  │                                                      │   │
  │  │  Tudo tem autocomplete. Só comece a digitar!         │   │
  │  │                                                      │   │
  │  └──────────────────────────────────────────────────────┘   │
  │                                                             │
  │                                                             │
  │              ┌──────────────────────────────────┐           │
  │              │    ▶ Entrar no chat              │           │
  │              └──────────────────────────────────┘           │
  │                                                             │
  │  [ ] Não mostrar dicas novamente                            │
  │                                                             │
  ├─────────────────────────────────────────────────────────────┤
  │  Passo 3 de 3  ████████████  Concluído!                    │
  └─────────────────────────────────────────────────────────────┘
```

---

## XVI. Micro-Interações e Easter Eggs

Detalhes que tornam a experiência memorável.

```
  MICRO-INTERAÇÕES:
  ─────────────────

  1. SOM DE CLICK DO WINDOWS 98
     ─ Opcional (toggle no footer: "🔊 Sons retrô")
     ─ Click em botão: som de click do Win98
     ─ Abrir janela: som de "ding" do Win98
     ─ Erro: som de "critical stop" do Win98
     ─ Sucesso no registro: som do "tada.wav"

  2. CURSOR CUSTOMIZADO
     ─ Cursor padrão do Win98 (seta branca)
     ─ Loading: ampulheta do Win98
     ─ Links: mãozinha do Win98
     ─ Texto: cursor I-beam do Win98

  3. ANIMAÇÃO DE JANELA
     ─ Janelas "abrem" como no Win98: surgem do centro
       com uma animação rápida de expand
     ─ Ao scrollar para uma nova seção, a janela "aparece"
       com essa animação
     ─ O [✕] faz a janela "minimizar" (animação de shrink)

  4. ÍCONES DO DESKTOP
     ─ Os ícones decorativos no hero são clicáveis:
       [📁 Meus Chats]   → scroll para seção de features
       [🌐 Rede]         → scroll para seção da rede
       [📝 README.txt]   → abre uma janela com o manifesto
       [🗑 Lixeira]      → easter egg (abre janela vazia
                            com mensagem "Aqui não tem
                            lixo. Só código limpo.")

  5. TASKBAR RELÓGIO
     ─ O relógio na taskbar mostra a hora real
     ─ Ao clicar, abre um calendário (como no Win98)
       com a data de lançamento do Retro Hex Chat destacada

  6. README.txt EASTER EGG
     Ao clicar no ícone README.txt no desktop:

     ┌───────────────────────────────────────────┐
     │ ■ README.txt — Bloco de Notas  [─][□][✕] │
     ├───────────────────────────────────────────┤
     │                                           │
     │  Nos anos 2000, a internet era nossa.     │
     │                                           │
     │  Tínhamos IRC, fóruns, blogs, e uma       │
     │  liberdade que não sabíamos que podíamos   │
     │  perder. Rodávamos servidores no porão.    │
     │  Montávamos redes com amigos. O código     │
     │  era livre. A web era descentralizada.     │
     │                                           │
     │  Depois trocamos isso por conveniência.    │
     │  E quando percebemos, a internet era de    │
     │  cinco empresas.                           │
     │                                           │
     │  Retro Hex Chat é um lembrete de que podemos        │
     │  ter os dois: a conveniência de 2026       │
     │  e a liberdade de 2000.                    │
     │                                           │
     │  Rode seu servidor. Conecte com outros.    │
     │  A rede é de todos nós.                    │
     │                                           │
     │  — Os criadores do Retro Hex Chat                   │
     │                                           │
     ├───────────────────────────────────────────┤
     │  Ln 1, Col 1                              │
     └───────────────────────────────────────────┘

  7. KONAMI CODE
     ─ Se o visitante digitar ↑↑↓↓←→←→BA na landing:
       O desktop muda para o wallpaper "Bliss" do WinXP
       por 5 segundos e volta pro teal.
```

---

## XVII. SEO e Meta Tags

```
  TÍTULO:
  Retro Hex Chat — Chat federado, como nos velhos tempos

  DESCRIÇÃO:
  Rode seu próprio servidor de chat. Conecte com outros.
  Sem empresa no meio. Open source, descentralizado,
  e livre como o IRC dos anos 2000.

  OG TAGS:
  og:title       → Retro Hex Chat — Chat federado descentralizado
  og:description → Seus dados. Suas regras. Sua comunidade.
                   Chat em tempo real com federação entre
                   servidores independentes.
  og:image       → Preview do desktop Win98 com a janela hero
  og:type        → website

  TWITTER CARD:
  card           → summary_large_image
  title          → Retro Hex Chat — Chat federado
  description    → Como email, mas para chat em tempo real.
                   Open source e descentralizado.
  image          → Mesmo do og:image

  FAVICON:
  Ícone pixelado do Retro Hex Chat (16x16), estilo ícone Win98
```

---

## XVIII. Performance e Acessibilidade

```
  PERFORMANCE:
  ────────────
  ─ 98.css é TINY (~10kb gzipped) — quase zero overhead
  ─ Nenhum framework JS pesado na landing (apenas LiveView ou
    vanilla JS para interações)
  ─ Imagens: pixel art é leve por natureza
  ─ Fontes: usar system fonts (98.css já faz isso)
  ─ Grafo da rede: canvas leve ou SVG simples
  ─ Sons: lazy load, só carrega se ativado

  ACESSIBILIDADE:
  ────────────────
  ─ 98.css já tem bom suporte a aria labels
  ─ Contraste: Win98 tem alto contraste natural
    (texto preto em fundo cinza claro)
  ─ Tab navigation: todas as janelas e botões são focáveis
  ─ Screen reader: title-bar-text serve como heading
  ─ Reduzir animações: respeitar prefers-reduced-motion
  ─ Sons: desabilitados por padrão, toggle explícito
  ─ Alt text em todos os ícones decorativos
  ─ Semântica: window é <section>, title-bar é <header>,
    window-body é <main> ou <article>
```

---

## XIX. Resumo de Todos os Textos

Para facilitar a extração de copy por quem for implementar:

```
  HERO:
  ─────
  Título:      "RETRO HEX CHAT"
  Subtítulo:   "Chat federado. Como nos velhos tempos.
                Mas com a tecnologia de hoje."
  Descrição:   "Rode seu próprio servidor. Conecte com outros.
                Sem empresa no meio. Sem algoritmos. Sem permissão.
                Seus dados. Suas regras. Sua comunidade."
  CTA 1:       "Criar conta"
  CTA 2:       "Entrar no servidor"
  Proof:       "Já existe uma rede. {N} servidores. {N} usuários."

  O PROBLEMA:
  ───────────
  Headline:    "Sua comunidade não é sua."
  Nostalgia:   "Nos anos 2000, não era assim..."
  Transição:   "Depois veio a conveniência. E junto veio o controle."

  A SOLUÇÃO:
  ──────────
  Esquerda:    "Retro Hex Chat é um software de chat que qualquer pessoa
                pode instalar e rodar no seu próprio servidor..."
  Direita:     "Retro Hex Chat NÃO é um serviço..."
  Analogia:    "Você entende email? Então você entende Retro Hex Chat."

  COMO FUNCIONA:
  ──────────────
  Servidores:  "Qualquer pessoa pode rodar um servidor..."
  Federação:   "Servidores se conectam entre si..."
  Identidade:  "Sua identidade inclui o servidor onde você está."
  Segurança:   "Cada mensagem é assinada criptograficamente."

  RODE O SEU:
  ───────────
  Headline:    "Quer seu próprio servidor? Três passos."
  Requisitos:  "VPS de $5/mês roda tranquilo."

  FOOTER:
  ───────
  Quote:       "A internet é uma rede de redes.
                O chat deveria ser também."

  README.txt:
  ───────────
  "Nos anos 2000, a internet era nossa..."
```
