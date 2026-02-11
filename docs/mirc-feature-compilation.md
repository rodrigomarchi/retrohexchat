# 🔬 Compilado Completo de Features do mIRC / IRC

> Pesquisa extensiva sobre todas as funcionalidades do mIRC clássico e do protocolo IRC.
> Cada item está marcado como ✅ (já no spec) ou 🆕 (novo, candidato a implementação).

---

## CATEGORIA A — FORMATAÇÃO DE TEXTO E CORES

| # | Feature | Status | Descrição |
|---|---------|--------|-----------|
| A1 | Cores de nickname por hash | ✅ | Cada nick recebe cor fixa baseada em hash (~12 cores) |
| A2 | Cores IRC inline (Ctrl+K) | 🆕 | Suporte a códigos de cor mIRC no texto: foreground/background com 16 cores padrão. Usuário insere via Ctrl+K + número da cor |
| A3 | Texto bold (Ctrl+B) | 🆕 | Toggle de negrito no texto enviado, renderizado para todos |
| A4 | Texto italic (Ctrl+I) | 🆕 | Toggle de itálico no texto enviado |
| A5 | Texto underline (Ctrl+U) | 🆕 | Toggle de sublinhado no texto |
| A6 | Texto strikethrough | 🆕 | Toggle de riscado no texto |
| A7 | Texto reverse (Ctrl+R) | 🆕 | Inverte foreground/background |
| A8 | Reset de formatação (Ctrl+O) | 🆕 | Remove toda formatação do ponto em diante |
| A9 | Strip codes option | 🆕 | Opção para remover/ignorar todos os códigos de formatação nas mensagens recebidas |
| A10 | Barra de formatação visual | 🆕 | Toolbar acima do input com botões B/I/U/cor para aplicar formatação sem decorar atalhos |

---

## CATEGORIA B — NOTIFY LIST / BUDDY LIST

| # | Feature | Status | Descrição |
|---|---------|--------|-----------|
| B1 | Notify list (buddy list) | 🆕 | Lista de nicknames "amigos" — notifica quando entram/saem da rede. Equivalente a buddy list |
| B2 | Notify com sons customizados | 🆕 | Som diferente quando um amigo entra/sai |
| B3 | Notify com nota por nick | 🆕 | Campo de anotação pessoal por nickname na lista |
| B4 | Auto-whois on notify | 🆕 | Quando alguém da notify list entra, faz /whois automático |
| B5 | Notify list window | 🆕 | Janela dedicada (98.css Window) mostrando status online/offline de cada amigo |

---

## CATEGORIA C — ADDRESS BOOK (Livro de Endereços)

| # | Feature | Status | Descrição |
|---|---------|--------|-----------|
| C1 | Address Book básico | 🆕 | Armazena info sobre usuários: nickname, notas pessoais, data de primeiro contato |
| C2 | Aba Notify no Address Book | 🆕 | Gerenciamento da notify list dentro do address book |
| C3 | Aba Nick Colors | 🆕 | Permite atribuir cores customizadas a nicknames específicos (override do hash automático) |
| C4 | Aba Control (ignore list) | 🆕 | Gerencia lista de ignorados com tipos de ignore (mensagens, CTCPs, convites, etc.) |
| C5 | Acesso via Alt+B ou toolbar | 🆕 | Atalho de teclado e ícone na toolbar para abrir o address book |

---

## CATEGORIA D — HIGHLIGHT / MENÇÕES

| # | Feature | Status | Descrição |
|---|---------|--------|-----------|
| D1 | Highlight do próprio nick | 🆕 | Quando alguém menciona seu nickname no chat, a mensagem é destacada com cor diferente |
| D2 | Highlight words customizáveis | 🆕 | Lista de palavras configuráveis que, quando aparecem no chat, destacam a linha inteira |
| D3 | Highlight com som | 🆕 | Som de notificação quando um highlight é ativado |
| D4 | Highlight com flash na taskbar | 🆕 | O treebar/switchbar pisca quando há highlight em canal não-ativo |
| D5 | Configuração de cores por highlight | 🆕 | Cada palavra de highlight pode ter cor diferente (foreground + background) |

---

## CATEGORIA E — URL CATCHER

| # | Feature | Status | Descrição |
|---|---------|--------|-----------|
| E1 | Detecção automática de URLs | 🆕 | Links no chat são detectados e ficam clicáveis (abre em nova aba) |
| E2 | URL Catcher / Lista de URLs | 🆕 | Todas as URLs mencionadas no chat são capturadas e armazenadas numa lista dedicada |
| E3 | URL list window | 🆕 | Janela dedicada (98.css Window) listando todas as URLs capturadas com timestamp, canal e quem postou |
| E4 | Link preview inline | 🆕 | Preview básico (título da página) mostrado ao lado/abaixo do link no chat |

---

## CATEGORIA F — IGNORE SYSTEM

| # | Feature | Status | Descrição |
|---|---------|--------|-----------|
| F1 | /ignore básico | 🆕 | Ignora todas as mensagens de um usuário específico |
| F2 | Ignore por tipo | 🆕 | Ignorar seletivamente: mensagens de canal, PMs, convites, ações (/me) |
| F3 | Ignore temporário | 🆕 | Ignore com timer automático (ex: ignorar por 5 minutos) |
| F4 | Ignore list gerenciável | 🆕 | Dialog para visualizar/adicionar/remover ignores (via menu ou Address Book) |
| F5 | /unignore | 🆕 | Comando para remover ignore |

---

## CATEGORIA G — CHANNEL CENTRAL DIALOG

| # | Feature | Status | Descrição |
|---|---------|--------|-----------|
| G1 | Channel Central window | 🆕 | Janela dedicada (98.css Dialog) mostrando todas as informações do canal: tópico, modos, ban list, criador |
| G2 | Edição de tópico no dialog | 🆕 | Campo editável para o tópico diretamente no Channel Central |
| G3 | Ban list visual | 🆕 | Lista visual de todos os bans do canal com quem baniu e quando, com botões add/remove |
| G4 | Modos como checkboxes | 🆕 | Cada modo de canal (+m, +i, +t, etc.) como checkbox visual no dialog |
| G5 | Ban exceptions list (+e) | 🆕 | Lista de exceções a bans (hostmasks que podem entrar mesmo com ban ativo) |
| G6 | Invite exceptions list (+I) | 🆕 | Lista de exceções ao invite-only (hostmasks que podem entrar sem invite) |

---

## CATEGORIA H — LOGGING SYSTEM

| # | Feature | Status | Descrição |
|---|---------|--------|-----------|
| H1 | Auto-logging de canais | 🆕 | Salvar automaticamente todo o histórico de canais (já temos persistência no DB, mas exportar como log acessível ao user) |
| H2 | Auto-logging de PMs | 🆕 | Salvar histórico de PMs exportável |
| H3 | Log viewer dialog | 🆕 | Janela dedicada para buscar e visualizar logs passados, com filtro por data/canal/nick |
| H4 | Formatos de log configuráveis | 🆕 | Escolher formato do timestamp, incluir/excluir eventos (joins, parts, mode changes) |
| H5 | Exportar logs como arquivo | 🆕 | Download de log como .txt ou .html |

---

## CATEGORIA I — PERFORM / AUTO-COMMANDS

| # | Feature | Status | Descrição |
|---|---------|--------|-----------|
| I1 | Perform on connect | 🆕 | Lista de comandos executados automaticamente ao conectar (ex: /ns identify, /join canais) |
| I2 | Auto-join channels | 🆕 | Lista de canais para entrar automaticamente ao conectar |
| I3 | Auto-identify NickServ | 🆕 | Se nick registrado e senha salva, identificar automaticamente |
| I4 | Auto-reconnect | 🆕 | Reconectar automaticamente se perder conexão (com retry backoff) |
| I5 | Reconnect to channels | 🆕 | Ao reconectar, re-entrar nos canais que estava antes |

---

## CATEGORIA J — INVITE SYSTEM

| # | Feature | Status | Descrição |
|---|---------|--------|-----------|
| J1 | /invite command | 🆕 | Convidar um usuário para um canal invite-only (+i) |
| J2 | Invite notification | 🆕 | Receber notificação visual quando alguém te convida para um canal |
| J3 | Auto-join on invite | 🆕 | Opção para entrar automaticamente quando convidado (configurável) |
| J4 | Invite dialog | 🆕 | Dialog popup quando recebe convite: "User X invited you to #channel — Join / Ignore" |

---

## CATEGORIA K — DCC (Direct Client-to-Client)

| # | Feature | Status | Descrição |
|---|---------|--------|-----------|
| K1 | DCC Chat | 🆕 | Chat privado ponto-a-ponto (via WebRTC no nosso caso, sem servidor) |
| K2 | File Send/Receive | 🆕 | Envio/recebimento de arquivos entre usuários (via upload no servidor) |
| K3 | File transfer progress | 🆕 | Barra de progresso (98.css Progress Indicator) durante transferência |
| K4 | File transfer resume | 🆕 | Retomar transferência interrompida |
| K5 | Accept/Reject dialog | 🆕 | Dialog popup quando recebe arquivo: "User X wants to send file.zip (2.5MB) — Accept / Reject" |
| K6 | File server (fserve) | 🆕 | Listar arquivos disponíveis para download |

---

## CATEGORIA L — NOTICES

| # | Feature | Status | Descrição |
|---|---------|--------|-----------|
| L1 | /notice command | 🆕 | Enviar notice para usuário (mensagem especial, não abre query window) |
| L2 | Notice rendering diferenciado | 🆕 | Notices aparecem com formatação diferente (prefixo, cor, ou área dedicada) |
| L3 | Notice para canal | 🆕 | /notice #canal mensagem — envia notice para todos no canal |
| L4 | Notice routing | 🆕 | Opção de mostrar notices na janela ativa, status window, ou janela do remetente |

---

## CATEGORIA M — CTCP (Client-to-Client Protocol)

| # | Feature | Status | Descrição |
|---|---------|--------|-----------|
| M1 | CTCP PING | 🆕 | Medir latência entre você e outro usuário |
| M2 | CTCP VERSION | 🆕 | Requisitar versão do cliente IRC do outro usuário |
| M3 | CTCP TIME | 🆕 | Requisitar hora local do outro usuário |
| M4 | CTCP FINGER | 🆕 | Requisitar info do perfil (finger reply customizável) |
| M5 | CTCP reply customizável | 🆕 | Configurar as respostas que seu cliente dá para CTCPs |

---

## CATEGORIA N — FLOOD PROTECTION

| # | Feature | Status | Descrição |
|---|---------|--------|-----------|
| N1 | Rate limit básico | ✅ | Já definido: 5 msgs/segundo por usuário |
| N2 | CTCP flood protection | 🆕 | Limitar respostas automáticas a CTCPs para evitar flood |
| N3 | Flood protection configurável | 🆕 | Dialog para configurar: bytes/tempo, max buffer, ignore time para flooders |
| N4 | Auto-ignore flooders | 🆕 | Ignorar automaticamente quem exceder o rate limit por X segundos |
| N5 | Anti-spam filter | 🆕 | Filtro configurável para bloquear mensagens repetidas ou padrões de spam |

---

## CATEGORIA O — SOUNDS & NOTIFICATIONS

| # | Feature | Status | Descrição |
|---|---------|--------|-----------|
| O1 | Sons de eventos básicos | ✅ | Já definido: new message, PM, user joined (wavs Windows 98) |
| O2 | Sons configuráveis por evento | 🆕 | Escolher qual som toca para cada tipo de evento (join, part, PM, highlight, etc.) |
| O3 | Som para connect/disconnect | 🆕 | Som quando conecta ou desconecta do servidor |
| O4 | Sound mute toggle | 🆕 | Botão global para mutar/desmutar todos os sons |
| O5 | Visual flash/blink | 🆕 | Flash visual no treebar + title bar quando há atividade em janela não-ativa |
| O6 | Typing indicator | 🆕 | Indicador em PMs de que o outro usuário está digitando (feature moderna, não existia no mIRC original) |

---

## CATEGORIA P — FAVORITES / BOOKMARKS

| # | Feature | Status | Descrição |
|---|---------|--------|-----------|
| P1 | Favorite channels | 🆕 | Salvar canais favoritos com descrição e senha |
| P2 | Favorites menu | 🆕 | Menu "Favorites" na menu bar com lista de canais salvos |
| P3 | Add to favorites dialog | 🆕 | Opção "Add to Favorites" no context menu de canal ou via menu |
| P4 | Auto-join favorites | 🆕 | Opção para entrar automaticamente nos favoritos ao conectar |
| P5 | Organize favorites | 🆕 | Dialog para gerenciar, reordenar e editar favoritos |

---

## CATEGORIA Q — USER INFORMATION

| # | Feature | Status | Descrição |
|---|---------|--------|-----------|
| Q1 | /whois dialog | ✅ | Já definido: dialog mostrando info do usuário |
| Q2 | /whowas command | 🆕 | Mostra info sobre um nick que acabou de sair |
| Q3 | User Central dialog | 🆕 | Dialog expandido com mais info: canais em comum, tempo online, away message, info registrada |
| Q4 | User profile/bio | 🆕 | Usuários podem definir uma mini-bio / info pessoal acessível via /whois |
| Q5 | Idle time tracking | 🆕 | Mostrar há quanto tempo o usuário está idle (sem enviar mensagens) |

---

## CATEGORIA R — WINDOW MANAGEMENT

| # | Feature | Status | Descrição |
|---|---------|--------|-----------|
| R1 | MDI básico | ✅ | Já definido: layout com treebar, chat, nicklist |
| R2 | Detach/float windows | 🆕 | Destacar uma janela de canal/PM como popup separado |
| R3 | Tile/Cascade windows | 🆕 | Organizar janelas abertas em tile (lado a lado) ou cascade (sobrepostas) |
| R4 | Minimize to switchbar | 🆕 | Minimizar janelas individuais mantendo-as na switchbar |
| R5 | Custom window layouts | 🆕 | Salvar e restaurar arranjos de janelas |
| R6 | Compact mode (treebar only) | 🆕 | Modo compacto com apenas treebar sem switchbar |
| R7 | Status Window | 🆕 | Janela dedicada para mensagens do servidor (MOTD, raw numerics, notices do server, pings) |

---

## CATEGORIA S — SCRIPTING & ALIASES (Simplificado)

| # | Feature | Status | Descrição |
|---|---------|--------|-----------|
| S1 | Custom aliases | 🆕 | Permitir que o usuário crie aliases simples: `/hi` → `/me says hello everyone!` |
| S2 | Alias editor | 🆕 | Dialog para criar/editar/remover aliases personalizados |
| S3 | Custom popup menus | 🆕 | Permitir adicionar itens customizados ao context menu (nicklist, canal) |
| S4 | Auto-respond events | 🆕 | Configurar respostas automáticas simples (ex: auto-greet quando alguém junta) |
| S5 | Timer commands | 🆕 | /timer para executar comandos em intervalos (ex: reminder a cada 30min) |

---

## CATEGORIA T — CHANNEL FEATURES AVANÇADOS

| # | Feature | Status | Descrição |
|---|---------|--------|-----------|
| T1 | /knock command | 🆕 | "Bater na porta" de canal invite-only: envia pedido para os ops verem |
| T2 | Half-operator (+h) | 🆕 | Nível intermediário entre voice e op, com poderes limitados (kick mas não ban) |
| T3 | Channel owner (+q) | 🆕 | Nível acima de op, super-poder sobre o canal |
| T4 | +n mode (no external) | 🆕 | Bloquear mensagens de fora do canal (default em muitas redes) |
| T5 | +s mode (secret channel) | 🆕 | Canal não aparece no /list e não é mostrado no /whois dos membros |
| T6 | +p mode (private channel) | 🆕 | Similar a secret mas com sutilezas diferentes |
| T7 | +c mode (strip colors) | 🆕 | Remove automaticamente códigos de cor das mensagens no canal |
| T8 | +R mode (registered only) | 🆕 | Apenas usuários registrados no NickServ podem entrar |
| T9 | Channel flood protection modes | 🆕 | Modos como +f (join throttle), +j (joins/tempo) para proteção automática |

---

## CATEGORIA U — MENSAGENS ESPECIAIS

| # | Feature | Status | Descrição |
|---|---------|--------|-----------|
| U1 | MOTD (Message of the Day) | 🆕 | Mensagem do dia exibida ao conectar (configurável pelo admin do servidor) |
| U2 | Welcome message por canal | 🆕 | Mensagem automática exibida ao entrar num canal (definida pelo op/founder) |
| U3 | /wallops (wall messages) | 🆕 | Mensagem broadcast para todos os operadores da rede |
| U4 | Global announcements | 🆕 | Mensagem de administrador enviada para TODOS os usuários conectados |

---

## CATEGORIA V — CONFIGURAÇÕES E OPTIONS DIALOG

| # | Feature | Status | Descrição |
|---|---------|--------|-----------|
| V1 | Options dialog completo | 🆕 | Janela de configurações organizada em categorias (como o Alt+O do mIRC) com visual 98.css |
| V2 | Connect options | 🆕 | Configurações de conexão: reconexão, retry, timeouts |
| V3 | IRC messages options | 🆕 | Onde mostrar: whois na ativa, notices na status, queries em janela, etc. |
| V4 | Display options | 🆕 | Configurar toolbar on/off, treebar on/off, switchbar on/off, tamanho de ícones |
| V5 | Font options | 🆕 | Escolher fonte e tamanho para chat (monospace), UI, e cada tipo de janela |
| V6 | Color options | 🆕 | Personalizar paleta de cores do chat: background, text, nick colors, system messages |
| V7 | Key bindings | 🆕 | Configurar atalhos de teclado |
| V8 | Line shading (alternating rows) | 🆕 | Linhas alternadas com fundo levemente diferente para facilitar leitura |

---

## CATEGORIA W — MISCELÂNEA / POLISH

| # | Feature | Status | Descrição |
|---|---------|--------|-----------|
| W1 | About dialog | 🆕 | "Help → About" com créditos, versão, logo pixelado Windows 98 style |
| W2 | IRC commands reference | 🆕 | "Help → IRC Commands" com referência completa acessível dentro da app |
| W3 | Keyboard shortcuts reference | 🆕 | Dialog listando todos os atalhos de teclado disponíveis |
| W4 | Quit message customizável | 🆕 | Configurar a mensagem exibida quando faz /quit |
| W5 | Finger reply customizável | 🆕 | Configurar a resposta do /ctcp finger |
| W6 | Away com mensagem e auto-reply | 🆕 | Quando alguém te manda PM estando away, responde automaticamente com sua away message |
| W7 | Double-click actions | 🆕 | Double-click em nick → abre query. Double-click em canal → entra. Double-click em URL → abre |
| W8 | Right-click copy | 🆕 | Selecionar texto no chat e copiar via right-click ou Ctrl+C |
| W9 | Input editbox history | ✅ | Já definido: ↑↓ para navegar histórico de comandos |
| W10 | Multi-line paste dialog | 🆕 | Ao colar texto com múltiplas linhas, dialog pergunta: "Paste X lines? Send all / Send as file / Cancel" |
| W11 | Character counter | 🆕 | Contador de caracteres no input (mostrando limite IRC de 512 chars) |
| W12 | Emoji/Emoticon support | 🆕 | Suporte a emojis Unicode no chat, com picker opcional |
| W13 | Timestamp format options | 🆕 | Configurar formato do timestamp: [HH:MM], [HH:MM:SS], [DD/MM HH:MM], etc. |
| W14 | Nick column alignment | 🆕 | Alinhar nicknames em coluna fixa para que todas as mensagens comecem na mesma posição horizontal |
| W15 | Image paste/preview in chat | 🆕 | Colar imagem diretamente no chat (upload automático, mostra thumbnail). Feature moderna. |

---

## RESUMO POR PRIORIDADE SUGERIDA

### 🔴 Alto Impacto Visual / UX (faz diferença imediata)
- **D1** Highlight do próprio nick
- **E1** URLs clicáveis no chat
- **W7** Double-click actions
- **W8** Right-click copy
- **A2-A8** Formatação de texto (bold/italic/underline/colors)
- **A10** Barra de formatação visual
- **V1** Options dialog
- **R7** Status Window
- **W14** Nick column alignment

### 🟡 Impacto Médio — Features que completam a experiência IRC
- **B1-B5** Notify list / Buddy list
- **F1-F5** Ignore system
- **G1-G4** Channel Central dialog
- **J1-J4** Invite system
- **L1-L4** Notices
- **P1-P5** Favorites
- **I1-I5** Perform / Auto-commands
- **D2-D5** Highlight words
- **W6** Away com auto-reply
- **W10** Multi-line paste dialog
- **W4** Quit message customizável

### 🟢 Impacto Baixo / Nice-to-have
- **C1-C5** Address Book
- **K1-K6** DCC / File transfer
- **M1-M5** CTCP
- **S1-S5** Scripting/Aliases
- **H1-H5** Log system
- **T1-T9** Channel features avançados
- **U1-U4** Mensagens especiais
- **O2-O6** Sons avançados
- **W12** Emoji picker
- **W15** Image paste

---

## COMO ESCOLHER

Leia as categorias acima e me diga:

1. **Quais categorias inteiras** você quer incluir? (ex: "Categoria D toda", "Categoria E toda")
2. **Quais itens específicos** de categorias parciais? (ex: "B1 e B5 mas não B2-B4")
3. **O que definitivamente NÃO**? (ex: "Nada de DCC nesta fase")

Após sua escolha, vou gerar o comando `/speckit.specify` atualizado com todas as features selecionadas integradas ao spec existente.
