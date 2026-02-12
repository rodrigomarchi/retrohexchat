# 🎯 CATEGORIA X — UX MODERNA COM ESTÉTICA RETRO

> Esta é a categoria mais importante de todas.
> Ela não é "uma feature" — é a **filosofia** que permeia cada pixel da aplicação.
> O princípio: **parecer 1998, funcionar como 2026.**

---

## PRINCÍPIO CENTRAL

O usuário nunca deve se sentir perdido, frustrado ou confuso. IRC/mIRC histórico tinha uma curva de aprendizado brutal — dezenas de comandos /, atalhos obscuros, configurações enterradas em submenus. RetroHexChat resolve isso com:

1. **Discoverability progressiva** — features se revelam conforme você precisa delas
2. **Zero-frustration input** — o campo de texto é inteligente e te guia
3. **Feedback visual imediato** — toda ação tem resposta clara
4. **Consistência obsessiva** — mesmos padrões em toda a app

---

## X1 — COMMAND AUTOCOMPLETE PROFUNDO

### O que é
Quando o usuário digita `/` no input, aparece um dropdown (98.css styled) com TODOS os comandos disponíveis, com busca fuzzy conforme digita.

### Comportamento detalhado

```
Estado 1: Usuário digita "/"
┌─────────────────────────────────────┐
│ 📋 Comandos Disponíveis             │
├─────────────────────────────────────┤
│ /join     Entrar num canal          │
│ /part     Sair do canal atual       │
│ /msg      Enviar mensagem privada   │
│ /me       Enviar ação (/me dança)   │
│ /nick     Trocar nickname           │
│ /topic    Ver/mudar tópico          │
│ /kick     Expulsar usuário          │
│ /ban      Banir usuário             │
│ /whois    Info sobre usuário        │
│ /ignore   Ignorar usuário           │
│ ... (scroll)                        │
│                                     │
│ ↑↓ navegar  Tab confirmar  Esc sair │
└─────────────────────────────────────┘

Estado 2: Usuário digita "/jo"
┌─────────────────────────────────────┐
│ 🔍 Resultados para "jo"             │
├─────────────────────────────────────┤
│ /join     Entrar num canal          │
│ /autojoin Gerenciar auto-join       │
│                                     │
│ ↑↓ navegar  Tab confirmar  Esc sair │
└─────────────────────────────────────┘

Estado 3: Usuário seleciona /join (Tab ou click)
O input fica: "/join "
E aparece INLINE HINT:

┌─────────────────────────────────────┐
│ /join #canal [senha]                │
│                                     │
│ 💡 Digite o nome do canal.          │
│    Canais começam com #             │
│    Ex: /join #brasil                │
│    Ex: /join #secret minhasenha     │
└─────────────────────────────────────┘

Estado 4: Ao digitar "/join #" aparece lista de canais sugeridos
┌─────────────────────────────────────┐
│ 📺 Canais Sugeridos                 │
├─────────────────────────────────────┤
│ #general     12 usuários            │
│ #brasil      8 usuários             │
│ #dev         5 usuários             │
│ #music       3 usuários             │
│                                     │
│ (canais do servidor atual)          │
└─────────────────────────────────────┘
```

### Contexto-awareness do autocomplete
- Após `/msg ` → sugere **nicknames** dos usuários visíveis
- Após `/join ` → sugere **canais** disponíveis
- Após `/kick ` → sugere **nicknames do canal atual**
- Após `/ban ` → sugere **nicknames do canal atual**
- Após `/ignore ` → sugere **nicknames visíveis**
- Após `/mode #canal +` → sugere **modos** com explicação de cada um

### Spec técnico
- **Trigger**: primeiro caractere `/` no input vazio, ou `/` após newline
- **Navegação**: ↑↓ para mover, Tab/Enter para confirmar, Esc para fechar
- **Busca**: fuzzy match (não precisa começar com a letra certa)
- **Categorias no dropdown**: Básicos, Canal, Usuário, Configuração, Avançado
- **Persistence**: últimos 5 comandos usados aparecem primeiro ("Recentes")
- **Visual**: 98.css dropdown com borda inset, ícone por categoria, texto mono

---

## X2 — NICK AUTOCOMPLETE (@mention)

### O que é
Ao digitar `@` ou as primeiras letras de um nick, sugere nicknames com Tab-completion.

### Comportamento

```
Usuário digita: "ei @ma"
┌──────────────────────────────┐
│ 👤 Usuários                   │
├──────────────────────────────┤
│ @Mario     — Online          │
│ @Marcelo   — Away            │
│ @MasterDev — Online          │
└──────────────────────────────┘

Tab → completa para "ei @Mario "
Tab Tab → cicla para próximo match
```

### Também funciona sem @
- Digitar as primeiras letras no INÍCIO da mensagem + Tab = completa nick
- Comportamento clássico de IRC: `Mar<Tab>` → `Mario: ` (com dois-pontos)
- No meio da frase: `Mar<Tab>` → `Mario ` (sem dois-pontos)

### Visual
- Nick aparece com a COR que o usuário tem no chat
- Ícone de status (online/away/op) ao lado
- Popup segue estilo 98.css dropdown

---

## X3 — CHANNEL AUTOCOMPLETE

### O que é  
Ao digitar `#` em qualquer contexto, sugere canais.

### Comportamento
```
Usuário digita: "entra no #de"
┌──────────────────────────────┐
│ 📺 Canais                     │
├──────────────────────────────┤
│ #dev          5 usuários     │
│ #design       3 usuários     │
│ #debian       12 usuários    │
└──────────────────────────────┘
```

- Canais onde o usuário já está aparecem primeiro (com ícone ✓)
- Canais clicáveis nas mensagens (clicar em #canal = join)

---

## X4 — INLINE HELP TOOLTIP (Command Syntax Helper)

### O que é
Enquanto o usuário digita um comando, uma tooltip discreta mostra a sintaxe e explicação em tempo real. Funciona como a assinatura de função em IDEs.

### Visual
```
Input: /mode #canal +o Mar█

┌─ Syntax Help ──────────────────────────┐
│ /mode <#canal> <+/-modos> [nick]       │
│                                        │
│ +o nick  — Dar operador (@) ao nick    │
│ +v nick  — Dar voz (+) ao nick         │
│ +b mask  — Banir máscara de endereço   │
│ +i       — Canal invite-only           │
│ +m       — Canal moderado              │
│ +t       — Só ops mudam tópico         │
│                                        │
│ Você está definindo: +o (operador)     │
│ Próximo: nickname do usuário           │
└────────────────────────────────────────┘
```

### Comportamento
- Aparece ACIMA do input, não bloqueando a visão do chat
- Atualiza conforme o usuário digita
- Destaca em **bold** o parâmetro que o usuário está preenchendo
- Desaparece quando: Esc, click fora, ou enviar mensagem
- Toggle global: pode desligar em Settings ("Show command help")
- Nível de detalhe configurável: Beginner (tudo) / Expert (só sintaxe)

---

## X5 — SMART INPUT BAR

### O que é
O campo de input não é apenas uma caixa de texto — é um componente inteligente que se adapta ao contexto.

### Features do input

**5a — Placeholder contextual**
```
No canal #general:  "Mensagem para #general — / para comandos"
Em PM com Mario:    "Mensagem para Mario — / para comandos"
No Status Window:   "Digite um comando — / para lista"
```

**5b — Input expande verticalmente**
- Até 5 linhas visíveis ao digitar texto longo
- Scroll interno após 5 linhas
- Contador de caracteres aparece ao passar de 400 chars: "427/512"

**5c — Multi-line paste detection**
```
Ao colar texto com 3+ linhas:
┌─ Paste Detectado ──────────────────┐
│                                     │
│ Você está colando 15 linhas.        │
│                                     │
│ [ Enviar tudo ] [ Enviar 1 a 1 ]   │
│ [ Preview    ] [ Cancelar       ]   │
│                                     │
└─────────────────────────────────────┘
```

**5d — Formatting bar (toggle)**
```
┌──┬──┬──┬──┬──┬──┬─────────────────────────────┐
│ B│ I│ U│ S│🎨│ ⌨ │  Mensagem aqui...            │
└──┴──┴──┴──┴──┴──┴─────────────────────────────┘
  │  │  │  │  │  │
  │  │  │  │  │  └─ Monospace toggle
  │  │  │  │  └──── Color picker (16 cores IRC)
  │  │  │  └─────── Strikethrough
  │  │  └────────── Underline
  │  └───────────── Italic
  └──────────────── Bold
```
- Visível apenas quando habilitado (toggle em Settings ou ícone no input)
- Cada botão aplica/remove formatação no texto selecionado
- Visual: botões 98.css sunken quando ativo

**5e — History navigation aprimorado**
- ↑↓ no input vazio = navega histórico (como já spec'd)
- Ctrl+↑ / Ctrl+↓ = navega sem apagar texto atual
- Histórico persistido entre sessões (últimos 100 comandos)
- Ctrl+R = busca reversa no histórico (como bash): aparece campo de busca inline

---

## X6 — CONTEXTUAL RIGHT-CLICK MENUS

### O que é
Menus de contexto ricos e contextualmente inteligentes, com ações relevantes em cada elemento.

### Menus por contexto

**Right-click em nickname (no chat ou nicklist):**
```
┌────────────────────────────┐
│ 💬 Mensagem privada        │
│ ℹ️  Whois                   │
│ 📋 Copiar nick              │
├────────────────────────────┤
│ 🔇 Ignorar                 │
│ 📌 Adicionar ao Address Book│
│ 🎨 Definir cor do nick     │
├────────────────────────────┤  ← Só se for Op
│ 👢 Kick                     │
│ 🚫 Ban                      │
│ 🔊 Dar voz (+v)             │
│ ⭐ Dar op (+o)              │
└────────────────────────────┘
```

**Right-click em canal (no treebar ou mencionado no chat):**
```
┌────────────────────────────┐
│ 📺 Entrar no canal          │
│ ⭐ Adicionar aos favoritos  │
│ 📋 Copiar nome do canal     │
│ ℹ️  Info do canal            │
└────────────────────────────┘
```

**Right-click em URL (no chat):**
```
┌────────────────────────────┐
│ 🔗 Abrir link               │
│ 📋 Copiar URL               │
│ 📌 Salvar na URL List       │
└────────────────────────────┘
```

**Right-click em mensagem (área do chat):**
```
┌────────────────────────────┐
│ 📋 Copiar mensagem          │
│ 📋 Copiar texto selecionado │
│ 💬 Responder (quote)        │
│ 🔇 Ignorar remetente       │
│ 📌 Salvar na URL list       │  ← só se tiver URL
└────────────────────────────┘
```

**Right-click no treebar item:**
```
┌────────────────────────────┐
│ 🔔 Marcar como lido         │
│ 🔇 Mutar canal              │
│ ⭐ Favoritar                │
│ 📋 Copiar nome              │
│ 🚪 Sair do canal            │
├────────────────────────────┤
│ ⚙️  Configurações do canal  │
└────────────────────────────┘
```

### Visual
- Estilo 98.css nativo (menu raised, separadores, ícones)
- Atalho de teclado mostrado à direita de cada item
- Items desabilitados em cinza (ex: Kick quando não é Op)

---

## X7 — ONBOARDING / FIRST-RUN EXPERIENCE

### O que é
Na primeira vez que o usuário abre o RetroHexChat, ele é guiado por um fluxo amigável que configura o essencial sem ser invasivo.

### Fluxo

```
Passo 1: Welcome Dialog (98.css wizard)
┌─ Bem-vindo ao RetroHexChat ─────────────────┐
│                                               │
│  [LOGO ASCII ART OU PIXEL ART]               │
│                                               │
│  RetroHexChat é um cliente IRC com visual     │
│  Windows 98 e funcionalidades modernas.       │
│                                               │
│  Vamos configurar o básico:                   │
│                                               │
│  Nickname: [___________]                      │
│                                               │
│  💡 Dica: Seu nick é como seu nome no chat.   │
│     Pode mudar depois com /nick               │
│                                               │
│              [ Próximo > ]                     │
└───────────────────────────────────────────────┘

Passo 2: Servidor
┌─ Conectar a um Servidor ────────────────────┐
│                                               │
│  Servidor: [servidor padrão pré-preenchido]   │
│  Porta:    [6667_____]                        │
│                                               │
│  ☐ Usar conexão segura (SSL/TLS)             │
│                                               │
│  💡 Não sabe o que escolher? Deixe o padrão!  │
│                                               │
│    [ < Voltar ]          [ Conectar > ]        │
└───────────────────────────────────────────────┘

Passo 3 (após conectar): Entrar num canal
┌─ Entrar num Canal ──────────────────────────┐
│                                               │
│  Estes são os canais mais populares:          │
│                                               │
│  ☑ #general        15 pessoas                │
│  ☑ #welcome         8 pessoas                │
│  ☐ #dev             5 pessoas                │
│  ☐ #music           3 pessoas                │
│                                               │
│  Ou digite um canal: [#___________]           │
│                                               │
│    [ < Voltar ]          [ Entrar! > ]         │
└───────────────────────────────────────────────┘
```

### Após o primeiro uso
- NÃO mostra novamente
- Um banner discreto no chat diz: "💡 Dica: digite / para ver comandos disponíveis. Use ↑↓ para navegar o histórico."
- Dicas aparecem contextualmente nos primeiros 5 minutos e depois param

---

## X8 — CONTEXTUAL TIPS & PROGRESSIVE DISCLOSURE

### O que é
Dicas contextuais que aparecem no momento certo, ensinando features conforme o usuário naturalmente as encontra.

### Exemplos de triggers

| Trigger | Dica mostrada |
|---------|---------------|
| Primeira mensagem enviada | "💡 Use ↑ para editar sua última mensagem" |
| Primeiro /join | "💡 Canais que você entra aparecem no painel esquerdo" |
| Primeiro PM recebido | "💡 PMs aparecem como janelas separadas no treebar" |
| Hover em nick pela primeira vez | "💡 Clique com botão direito para ver opções" |
| Ficar 30s sem fazer nada | "💡 Digite /help para ver todos os comandos" |
| Primeiro highlight recebido | "💡 Seu nick foi mencionado! Você pode configurar alertas em Settings" |
| Usar /me pela primeira vez | "💡 Legal! /me envia ações. Ex: /me está feliz" |
| Colar URL no chat | "💡 URLs são automaticamente detectados e ficam clicáveis" |

### Visual
```
┌─ 💡 Dica ────────────────────────────── ✕ ─┐
│ Use Tab para completar nicknames.            │
│ Digite as primeiras letras + Tab.            │
│                                              │
│ ☐ Não mostrar mais dicas    [Entendi!]       │
└──────────────────────────────────────────────┘
```

### Comportamento
- Aparece como toast no canto inferior do chat (não bloqueia)
- Desaparece após 8 segundos ou click em "Entendi!"
- Checkbox "Não mostrar mais" = desliga todas as dicas
- Cada dica aparece NO MÁXIMO uma vez
- Persistido em localStorage qual dica já foi vista
- Configurável em Settings: Dicas (On / Off)

---

## X9 — KEYBOARD SHORTCUTS SYSTEM

### O que é
Sistema completo de atalhos de teclado com cheatsheet acessível.

### Atalhos essenciais

| Atalho | Ação |
|--------|------|
| `Ctrl+K` | Abrir color picker inline |
| `Ctrl+B` | Toggle bold |
| `Ctrl+I` | Toggle italic |
| `Ctrl+U` | Toggle underline |
| `Ctrl+Enter` | Enviar mensagem (alternativo ao Enter) |
| `Ctrl+/` | Abrir cheatsheet de atalhos |
| `Ctrl+F` | Buscar no chat atual |
| `Ctrl+W` | Fechar janela/canal atual |
| `Ctrl+Tab` | Próxima janela |
| `Ctrl+Shift+Tab` | Janela anterior |
| `Alt+↑` / `Alt+↓` | Navegar entre canais no treebar |
| `Alt+1..9` | Ir para janela N |
| `Ctrl+Shift+M` | Toggle mute sons |
| `Esc` | Fechar popup/dropdown/dialog ativo |
| `F1` | Ajuda |
| `F5` | Refresh channel list |
| `Alt+O` | Abrir Options (como mIRC clássico) |
| `Alt+B` | Abrir Address Book |
| `Alt+R` | Abrir Script Editor |
| `Ctrl+L` | Clear buffer do chat |

### Cheatsheet Dialog (Ctrl+/)
```
┌─ Atalhos de Teclado ────────────────── ✕ ──┐
│                                              │
│ ── Navegação ──                              │
│ Ctrl+Tab         Próxima janela              │
│ Ctrl+Shift+Tab   Janela anterior             │
│ Alt+1..9         Ir para janela N            │
│ Alt+↑/↓          Navegar treebar             │
│                                              │
│ ── Chat ──                                   │
│ ↑/↓              Histórico de comandos       │
│ Tab               Autocomplete nick          │
│ Ctrl+F            Buscar no chat             │
│ Ctrl+L            Limpar chat                │
│                                              │
│ ── Formatação ──                             │
│ Ctrl+B            Negrito                    │
│ Ctrl+I            Itálico                    │
│ Ctrl+U            Sublinhado                 │
│ Ctrl+K            Cor                        │
│                                              │
│ ── Sistema ──                                │
│ Alt+O             Configurações              │
│ Ctrl+/            Este dialog                │
│ F1                Ajuda                      │
│                                              │
│                          [ Fechar ]          │
└──────────────────────────────────────────────┘
```

---

## X10 — SEARCH IN CHAT (Ctrl+F)

### O que é
Busca poderosa dentro do histórico do chat, com highlight de resultados.

### Visual
```
Ctrl+F ativa barra de busca acima do chat:

┌─ 🔍 ────────────────────────────────────────┐
│ [Buscar: terraform___] ↑ ↓  3/17  [ ✕ ]    │
│ ☐ Case-sensitive  ☐ Regex  ☐ Só meu nick    │
└─────────────────────────────────────────────┘
```

### Comportamento
- Resultados highlighted no chat com background amarelo
- ↑↓ na barra de busca = navega entre resultados
- Contador: "3/17" = mostrando 3º resultado de 17
- Filtros opcionais: case-sensitive, regex, apenas mensagens para mim
- Esc = fechar busca, remover highlights
- Busca no histórico carregado (e opcionalmente nos logs do DB)

---

## X11 — VISUAL FEEDBACK SYSTEM

### O que é
Cada ação do usuário tem feedback visual claro e imediato.

### Padrões de feedback

| Ação | Feedback |
|------|----------|
| Enviar mensagem | Mensagem aparece instantaneamente no chat (otimistic UI) |
| Mensagem falhou | Ícone ⚠️ vermelho ao lado + tooltip "Falha ao enviar. Clique para reenviar" |
| Entrar em canal | Flash verde no treebar item + mensagem de sistema no chat |
| Ser kickado | Flash vermelho + dialog "Você foi expulso de #canal por User: motivo" |
| Receber PM | Badge numérico no treebar + som + flash |
| Alguém entra/sai | Mensagem discreta no chat (com opção de esconder) |
| Conectando | "Conectando..." com spinner 98.css na status bar |
| Desconectado | Barra vermelha no topo: "⚠️ Desconectado — Reconectando em 5s..." |
| Reconectado | Barra verde temporária: "✓ Reconectado!" (desaparece em 3s) |
| Comando inválido | Mensagem de erro no chat: "⚠️ Comando desconhecido: /xpto. Digite /help para ver comandos." |
| Copiou texto | Toast discreto: "📋 Copiado!" |
| Settings salvas | Toast: "✓ Configurações salvas" |

### Unread indicators no treebar
```
Treebar:
├── 🟢 Status
├── #general        (bold = unread)
│   └── (3)         (badge numérico = mensagens não lidas)
├── #dev
│   └── 🔴          (ponto vermelho = highlight/mention)
├── Mario (PM)
│   └── (1) 🔴      (PM não lido com highlight)
└── #music          (normal = tudo lido)
```

### States visuais do treebar item
- **Normal**: texto regular
- **Unread messages**: texto bold
- **Unread com highlight**: texto bold + badge vermelho
- **Ativo**: background selecionado (98.css active state)
- **Muted**: texto cinza, sem badges
- **Desconectado**: ícone ⚡ + texto cinza

---

## X12 — STATUS BAR INFORMATIVA

### O que é
Barra inferior (como no Windows 98) com informações contextuais úteis.

### Layout
```
┌────────────────────────────────────────────────────────┐
│ #general — 15 usuários | 🟢 Conectado a irc.libera.chat | Lag: 45ms | UTF-8 │
└────────────────────────────────────────────────────────┘
```

### Campos
- **À esquerda**: nome da janela ativa + contagem de usuários (para canais)
- **Centro**: status de conexão + nome do servidor
- **À direita**: latência (lag), encoding, clock

### Estados de conexão
- 🟢 Conectado
- 🟡 Conectando...
- 🔴 Desconectado
- 🔄 Reconectando (3s)

---

## X13 — ACCESSIBLE LINK/CHANNEL/NICK CLICKING

### O que é
Elementos clicáveis no chat que permitem interação sem precisar digitar comandos.

### Comportamento

| Elemento | Single click | Double click | Hover |
|----------|-------------|--------------|-------|
| **URL** | Abre em nova aba | — | Underline + cursor pointer + preview tooltip |
| **#canal** | Join no canal | — | Tooltip: "12 usuários — Clique para entrar" |
| **@nick** | Abre PM | — | Tooltip: "Mario — Online — Clique para PM" |
| **Nick no chat** | Insere nick no input | Abre PM | Tooltip com mini-info |

### Nick hover card (mini whois)
```
Hover sobre "Mario" por 500ms:
┌─────────────────────────┐
│ 👤 Mario                 │
│ mario@host.com           │
│ 🟢 Online há 2h          │
│ Canais: #general, #dev   │
│                          │
│ Click: PM | Right: Menu  │
└─────────────────────────┘
```

---

## X14 — QUOTE/REPLY SYSTEM

### O que é
Capacidade de "responder" a uma mensagem específica com referência visual.

### Como ativar
1. Right-click mensagem → "Responder"
2. Ou: hover na mensagem → botão ↩️ aparece

### Visual no input
```
┌─ Respondendo a Mario ──────────── ✕ ─┐
│ "eu acho que devíamos usar Elixir"    │
├───────────────────────────────────────┤
│ Sua resposta aqui...█                 │
└───────────────────────────────────────┘
```

### Visual na mensagem enviada
```
[14:32] <You> ┌ Mario: "eu acho que devíamos usar Elixir"
              └ Concordo 100%!
```

---

## X15 — MESSAGE EDIT & DELETE

### O que é
Editar ou apagar sua última mensagem (padrão moderno, Discord/Slack-like).

### Comportamento
- **↑ no input vazio** = entra em modo de edição da última mensagem
- Mensagem fica com borda/background diferente indicando edição
- Enter = confirma edição, Esc = cancela
- Mensagem editada mostra "(editado)" discreto
- Delete da própria mensagem: right-click → "Apagar mensagem"
- Mensagem apagada mostra "[mensagem removida]" ou desaparece (config)
- **Limite de tempo**: só pode editar/apagar nos primeiros 5 minutos

---

## X16 — DRAG & DROP

### O que é
Suporte a arrastar coisas na interface.

### Ações de drag
- **Arquivo do desktop → chat** = inicia upload/envio DCC
- **Nick do nicklist → input** = insere nick no texto
- **Canal do treebar → outra posição** = reordena
- **URL do navegador → chat** = cola a URL

---

## X17 — RESPONSIVE STATES & EMPTY STATES

### O que é
Toda tela tem um estado "vazio" amigável que guia o usuário.

### Empty states

**Chat sem mensagens (canal recém-entrado):**
```
┌─────────────────────────────────────────┐
│                                          │
│      Bem-vindo ao #general! 🎉          │
│                                          │
│   Este é o início do canal.              │
│   Diga oi! 👋                           │
│                                          │
│   💡 Dica: /topic para ver o tópico      │
│                                          │
└─────────────────────────────────────────┘
```

**Nicklist vazia (canal sem ninguém):**
```
┌──────────────────┐
│  Ninguém aqui     │
│  Você é o(a)      │
│  primeiro(a)! 🎉  │
└──────────────────┘
```

**Treebar sem canais:**
```
┌──────────────────┐
│ Nenhum canal      │
│                   │
│ /join #canal      │
│ para começar      │
│                   │
│ [Explorar canais] │
└──────────────────┘
```

**URL list vazia:**
```
Nenhuma URL capturada ainda.
URLs mencionadas no chat aparecerão aqui.
```

---

## X18 — ACCESSIBILITY (a11y)

### O que é
Garantir que a app é utilizável por todos.

### Requisitos
- **Keyboard-only navigation**: tudo acessível via teclado
- **Tab order**: lógico (treebar → chat → input → nicklist)
- **ARIA labels**: em todos os elementos interativos
- **Alto contraste**: 98.css já é naturalmente de alto contraste
- **Screen reader**: mensagens do chat com role="log", aria-live
- **Font scaling**: respeitar zoom do browser (rem units)
- **Focus visible**: ring/outline claro em todos os elementos focáveis
- **Reduced motion**: respeitar prefers-reduced-motion (desligar animações)
- **Color não é o único indicador**: usar ícones + cor (ex: status online = 🟢 + texto "Online")

---

## X19 — LOADING STATES

### O que é
Nunca mostrar tela em branco. Sempre ter indicação de progresso.

### Padrões

**Conectando ao servidor:**
```
┌─────────────────────────────────────────┐
│                                          │
│   ⏳ Conectando a irc.libera.chat...     │
│   ████████░░░░░░░░ 50%                  │
│                                          │
│   Resolvendo DNS...                      │
│   ✓ DNS resolvido                        │
│   Conectando na porta 6697...            │
│   ⏳ Aguardando resposta...              │
│                                          │
└─────────────────────────────────────────┘
```

**Carregando histórico de canal:**
```
[Loading messages...]  ← spinner 98.css animado
──────────────────────
mensagens carregadas aparecem aqui
```

**Carregando lista de canais:**
```
Buscando canais no servidor...
████████████░░░░░░ 67%
1,247 canais encontrados...
```

---

## X20 — NOTIFICATION SYSTEM UNIFICADO

### O que é  
Sistema único que gerencia TODAS as notificações da app.

### Tipos de notificação
1. **Badge no treebar** — número de unread
2. **Toast/popup** — canto inferior direito (98.css window mini)
3. **Browser notification** — para quando a aba está em background
4. **Som** — efeito sonoro por tipo de evento
5. **Title bar flash** — "(*) RetroHexChat" quando há unread
6. **Favicon badge** — ponto vermelho no favicon do browser

### Configuração granular (por canal ou global)
```
┌─ Notificações ──────────────────────────┐
│                                          │
│ Global:                                  │
│ ☑ Sons habilitados                       │
│ ☑ Notificações do browser               │
│ ☑ Flash no título                        │
│                                          │
│ Por canal/PM:                            │
│ #general:  🔔 Normal  🔕 Mudo            │
│ #dev:      🔔 Normal  🔕 Mudo            │
│ PMs:       🔔 Sempre  (não pode mutar)   │
│                                          │
│ Notificar quando:                        │
│ ☑ Mencionarem meu nick                   │
│ ☑ Recebi PM                              │
│ ☐ Qualquer mensagem em canal             │
│ ☐ Alguém entrar/sair                     │
│                                          │
└──────────────────────────────────────────┘
```

---

## RESUMO: ITENS DA CATEGORIA X

| # | Feature | Impacto |
|---|---------|---------|
| X1 | Command Autocomplete Profundo | 🔴 Crítico |
| X2 | Nick Autocomplete (@mention) | 🔴 Crítico |
| X3 | Channel Autocomplete (#canal) | 🟡 Alto |
| X4 | Inline Help Tooltip | 🔴 Crítico |
| X5 | Smart Input Bar | 🔴 Crítico |
| X6 | Contextual Right-Click Menus | 🔴 Crítico |
| X7 | Onboarding / First-Run | 🟡 Alto |
| X8 | Contextual Tips & Progressive Disclosure | 🟡 Alto |
| X9 | Keyboard Shortcuts System | 🔴 Crítico |
| X10 | Search in Chat (Ctrl+F) | 🟡 Alto |
| X11 | Visual Feedback System | 🔴 Crítico |
| X12 | Status Bar Informativa | 🟡 Alto |
| X13 | Clickable Links/Channels/Nicks | 🔴 Crítico |
| X14 | Quote/Reply System | 🟡 Alto |
| X15 | Message Edit & Delete | 🟡 Alto |
| X16 | Drag & Drop | 🟢 Médio |
| X17 | Empty States | 🟡 Alto |
| X18 | Accessibility (a11y) | 🔴 Crítico |
| X19 | Loading States | 🟡 Alto |
| X20 | Notification System Unificado | 🔴 Crítico |
