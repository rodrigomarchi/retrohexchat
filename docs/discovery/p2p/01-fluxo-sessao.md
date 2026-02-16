# Fluxo da Sessão P2P

## Ciclo de Vida, Lobby e Aceite Mútuo

---

## I. Visão Geral do Ciclo de Vida

Uma sessão P2P no RetroHexChat segue um ciclo de vida bem definido, inspirado
no DCC do mIRC mas com melhorias significativas de UX e segurança.

```
  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
  │ Criação  │───▶│  Lobby   │───▶│  Aceite  │───▶│  Ativa   │───▶│   Fim    │
  │          │    │          │    │  Mútuo   │    │          │    │          │
  └──────────┘    └──────────┘    └──────────┘    └──────────┘    └──────────┘
       │               │               │               │               │
   /p2p nick      Chat temp.      Ambos aceitam   WebRTC ativo    Encerramento
   Token gerado   Negociação      Handshake        Mídia/dados    graceful ou
   Convite        prévia          WebRTC inicia    fluindo        timeout
```

### Estados da sessão

| Estado | Descrição | Timeout |
|--------|-----------|---------|
| `pending` | Convite enviado, aguardando o peer abrir o lobby | 5 min |
| `lobby` | Ambos presentes no lobby, chat ativo | 15 min sem atividade |
| `connecting` | Aceite mútuo dado, handshake WebRTC em progresso | 30 seg |
| `active` | Conexão P2P estabelecida, mídia/dados fluindo | Sem timeout (heartbeat) |
| `closed` | Encerrado gracefully por qualquer peer | — |
| `expired` | Timeout atingido em qualquer estado anterior | — |
| `failed` | Handshake WebRTC falhou após retries | — |

## II. Criação da Sessão

O fluxo inicia quando um usuário registrado executa um comando no chat:

```
/p2p nickname         → Sessão genérica (lobby para decidir o que fazer)
/call nickname        → Sessão com intenção de chamada de áudio/vídeo
/sendfile nickname    → Sessão com intenção de transferência de arquivo
```

**O que acontece no servidor:**

1. Valida que o iniciador é usuário registrado (não guest)
2. Valida que o nickname alvo existe e está online
3. Valida que não existe sessão P2P ativa entre os mesmos peers
4. Gera token único da sessão (`Phoenix.Token.sign/4`)
5. Cria registro `p2p_sessions` no banco (estado `pending`)
6. Inicia GenServer da sessão via DynamicSupervisor
7. Envia notificação ao peer alvo via PubSub (`"user:#{nickname}"`)
8. Retorna URL do lobby ao iniciador: `/p2p/:token`

**Notificação ao peer alvo:**

```
╔══════════════════════════════════════════╗
║  🔗 Solicitação P2P                     ║
║                                          ║
║  rodrigo quer iniciar uma sessão P2P     ║
║  com você.                               ║
║                                          ║
║  [Aceitar]  [Recusar]  [Ignorar]        ║
╚══════════════════════════════════════════╝
```

A notificação aparece como toast no sistema de notificações existente (feature 032).
"Aceitar" abre `/p2p/:token` em nova aba. "Recusar" envia rejeição. "Ignorar"
deixa expirar.

## III. O Lobby — Sala de Espera

O lobby é o coração da experiência P2P. É uma URL dedicada (`/p2p/:token`) fora
do shell principal do chat, renderizada por `P2PSessionLive`.

### Por que uma URL separada?

1. **Isolamento de estado** — a sessão P2P tem seu próprio ciclo de vida,
   independente dos canais
2. **Pode abrir em nova aba** — o usuário não perde o contexto do chat principal
3. **URL compartilhável** — em caso de reconexão, o token na URL permite retomar
4. **Simplicidade** — sem modal complexo dentro do ChatLive

### Funcionalidades do lobby

```
┌─────────────────────────────────────────────────────────┐
│ [■] Sessão P2P — rodrigo ↔ maria          [─][□][✕]    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │ *** Sessão P2P criada por rodrigo               │    │
│  │ *** Aguardando maria entrar no lobby...         │    │
│  │ *** maria entrou no lobby                       │    │
│  │ <rodrigo> opa, quero te mandar aquele arquivo   │    │
│  │ <maria> manda aí!                               │    │
│  │                                                 │    │
│  └─────────────────────────────────────────────────┘    │
│                                                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │ Ações disponíveis:                                │  │
│  │                                                   │  │
│  │  [📁 Enviar Arquivo]  [📞 Chamada de Voz]        │  │
│  │  [📹 Chamada de Vídeo]                            │  │
│  │                                                   │  │
│  │  Status: Ambos no lobby ✓                         │  │
│  └───────────────────────────────────────────────────┘  │
│                                                         │
│  ┌─────────────────────────────────────────┐            │
│  │ mensagem...                      [Send] │            │
│  └─────────────────────────────────────────┘            │
└─────────────────────────────────────────────────────────┘
```

O lobby permite:

- **Chat temporário** entre os dois peers (mensagens não persistidas no banco,
  vivem apenas no GenServer da sessão)
- **Seleção de ação** — o que querem fazer: transferir arquivo, chamada de
  áudio, chamada de vídeo
- **Indicador de presença** — mostra quando ambos estão no lobby
- **Histórico da sessão** — eventos do sistema (quem entrou, saiu, reconectou)

## IV. Aceite Mútuo — Bilateral Consent

Diferente do DCC original (onde aceitar o convite já iniciava a transferência),
o RetroHexChat exige aceite bilateral explícito para cada ação:

```
  Peer A                    Servidor                    Peer B
    │                          │                          │
    │── clica [Enviar Arquivo] ─▶                         │
    │                          │── "A quer enviar arquivo" ▶
    │                          │                          │
    │                          │◀── [Aceitar] ────────────│
    │◀── "B aceitou" ──────────│                          │
    │                          │                          │
    │── (WebRTC handshake) ────┼──────────────────────────│
    │                          │                          │
```

### Por que aceite mútuo?

1. **Segurança** — ninguém inicia uma chamada de vídeo ou transferência sem
   consentimento explícito do outro lado
2. **Controle** — cada ação dentro da sessão é uma decisão bilateral
3. **UX clara** — não há ambiguidade sobre o que vai acontecer

### Confirmação no lobby

Quando Peer A seleciona uma ação:

```
┌──────────────────────────────────────────────────┐
│  rodrigo quer enviar um arquivo para você.       │
│                                                  │
│  Arquivo: relatorio-2026.pdf (2.4 MB)            │
│                                                  │
│           [Aceitar]    [Recusar]                  │
└──────────────────────────────────────────────────┘
```

## V. Sessão Ativa — WebRTC Estabelecido

Após aceite mútuo, o handshake WebRTC é executado (ver `02-webrtc-fundamentos.md`
e `06-sinalizacao-phoenix.md`). A sessão transita para `active`.

Na sessão ativa:
- **Transferência de arquivo**: barra de progresso, velocidade, ETA
  (ver `04-transferencia-arquivos.md`)
- **Chamada de áudio/vídeo**: controles de mídia, indicadores de qualidade
  (ver `05-audio-video.md`)
- O chat do lobby permanece disponível durante a sessão
- Qualquer peer pode encerrar a qualquer momento

## VI. Encerramento

A sessão pode encerrar por:

1. **Encerramento graceful** — qualquer peer clica "Encerrar sessão"
2. **Navegação** — peer fecha a aba ou navega para outra página
3. **Timeout** — inatividade prolongada (heartbeat falha)
4. **Erro** — falha irrecuperável na conexão WebRTC

**Fluxo de encerramento:**

```
  Peer A                    Servidor                    Peer B
    │                          │                          │
    │── "encerrar sessão" ─────▶                          │
    │                          │── "sessão encerrada" ────▶
    │                          │                          │
    │                          │── atualiza DB (closed) ──│
    │                          │── stop GenServer ────────│
    │                          │                          │
    │◀── redirect /chat ───────│── redirect /chat ────────▶
```

O GenServer da sessão é encerrado. O registro no banco é atualizado para `closed`
com timestamp. Ambos os peers são redirecionados de volta ao chat.

## VII. Timeouts e Expiração

| Fase | Timeout | Ação |
|------|---------|------|
| Convite pendente | 5 min | Sessão expira, GenServer encerra |
| Lobby inativo | 15 min | Aviso aos 10 min, encerra aos 15 |
| Handshake WebRTC | 30 seg | Retry automático (3x), depois falha |
| Sessão ativa | Heartbeat a cada 30 seg | 3 heartbeats perdidos = encerrar |

O GenServer monitora todos os timeouts via `Process.send_after/3`. A expiração
atualiza o banco e notifica os peers.

## VIII. Críticas ao Fluxo Original

Durante a elaboração deste documento, identificamos melhorias em relação ao
fluxo DCC original e à proposta inicial:

### Problema: DCC original era fire-and-forget

No mIRC, `/dcc send nick file` disparava a transferência. O receptor recebia
uma notificação e podia aceitar ou recusar, mas não havia espaço para
negociação. Se o receptor não estivesse esperando o arquivo, era uma experiência
confusa.

**Melhoria**: O lobby resolve isso. Os peers podem conversar, confirmar o que
querem fazer, e só então iniciar a ação.

### Problema: Exposição de IP no DCC original

O DCC do mIRC expunha o IP real de ambos os peers na mensagem CTCP. Qualquer
pessoa no canal podia ver.

**Melhoria**: WebRTC com TURN-only mode opcional esconde os IPs. O signaling
passa pelo servidor. Ver `07-seguranca.md`.

### Problema: Sem criptografia no DCC

Transferências DCC eram em texto plano. Qualquer intermediário podia
interceptar.

**Melhoria**: WebRTC usa DTLS obrigatório. Toda comunicação é criptografada
ponta-a-ponta por padrão. Não é opcional.

### Problema: Falha silenciosa em NATs restritivos

DCC simplesmente falhava se ambos os peers estivessem atrás de NAT, sem
diagnóstico.

**Melhoria**: ICE framework tenta múltiplos candidatos. Se conexão direta
falha, TURN faz relay. O lobby mostra status de conexão em tempo real.

## IX. Wireframes ASCII Adicionais

### Estado: Aguardando peer

```
┌─────────────────────────────────────────────────────────┐
│ [■] Sessão P2P — rodrigo ↔ maria          [─][□][✕]    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │ *** Sessão P2P criada por rodrigo               │    │
│  │ *** Aguardando maria entrar no lobby...         │    │
│  │                                                 │    │
│  │              ⏳ Expira em 4:32                   │    │
│  │                                                 │    │
│  └─────────────────────────────────────────────────┘    │
│                                                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │ Ações disponíveis:                                │  │
│  │                                                   │  │
│  │  [📁 Enviar Arquivo]  [📞 Chamada de Voz]        │  │
│  │  [📹 Chamada de Vídeo]                            │  │
│  │                                                   │  │
│  │  Status: Aguardando maria... ⏳                   │  │
│  └───────────────────────────────────────────────────┘  │
│                                                         │
│  [Cancelar Sessão]                                      │
└─────────────────────────────────────────────────────────┘
```

### Estado: Transferência em progresso

```
┌─────────────────────────────────────────────────────────┐
│ [■] Sessão P2P — rodrigo ↔ maria          [─][□][✕]    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │ <rodrigo> mandando o relatório                  │    │
│  │ <maria> beleza, recebendo aqui                  │    │
│  └─────────────────────────────────────────────────┘    │
│                                                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │ 📁 Transferência de Arquivo                       │  │
│  │                                                   │  │
│  │  relatorio-2026.pdf                               │  │
│  │  ████████████████░░░░░░░░  67%  1.6/2.4 MB       │  │
│  │  Velocidade: 450 KB/s  ETA: 2s                    │  │
│  │                                                   │  │
│  │  [Cancelar]                                       │  │
│  └───────────────────────────────────────────────────┘  │
│                                                         │
│  ┌─────────────────────────────────────────┐            │
│  │ mensagem...                      [Send] │            │
│  └─────────────────────────────────────────┘            │
└─────────────────────────────────────────────────────────┘
```

### Estado: Chamada de vídeo ativa

```
┌─────────────────────────────────────────────────────────┐
│ [■] Sessão P2P — rodrigo ↔ maria          [─][□][✕]    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │                                                 │    │
│  │              ┌───────────────┐                   │    │
│  │              │               │                   │    │
│  │              │   maria       │                   │    │
│  │              │   (vídeo)     │                   │    │
│  │              │               │                   │    │
│  │              └───────────────┘                   │    │
│  │                        ┌──────┐                  │    │
│  │                        │ eu   │                  │    │
│  │                        └──────┘                  │    │
│  │                                                 │    │
│  └─────────────────────────────────────────────────┘    │
│                                                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │  [🔇 Mute]  [📷 Câmera Off]  [🔴 Encerrar]      │  │
│  │                                                   │  │
│  │  Duração: 03:42  |  Qualidade: Boa ●●●○          │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```
