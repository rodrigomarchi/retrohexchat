# Retro Hex Chat — Uma Rede Federada de Chat em Elixir

## Documento de Arquitetura, Motivação e Visão

---

## I. Motivação — Por que estamos construindo isso?

### A Internet que perdemos

Nos anos 90 e início dos 2000, a internet era uma rede de redes. Ninguém "possuía"
o chat. Você podia rodar seu próprio servidor de IRC no porão de casa, conectá-lo
à rede EFnet ou Undernet, e de repente seus amigos estavam conversando com pessoas
do outro lado do planeta. Sem termos de serviço de 47 páginas. Sem algoritmos
decidindo o que você via. Sem uma empresa podendo deletar sua comunidade da noite
pro dia.

O mIRC, o XChat, o BitchX — eram janelas para um mundo onde a infraestrutura era
das pessoas. Cada servidor era mantido por um voluntário, uma universidade, um
entusiasta. A rede era a soma desses esforços individuais.

Depois veio a centralização. MSN Messenger. Google Talk. Facebook Chat. Discord.
Slack. Cada um criou seu jardim murado. Suas comunidades ficaram presas. Seus dados
ficaram presos. Sua identidade ficou presa. O Discord pode banir seu servidor
amanhã e você perde tudo — mensagens, comunidade, história.

### O que queremos de volta

Não é nostalgia. É um modelo que funcionava e que a tecnologia atual permite fazer
MELHOR do que nos anos 2000:

    ┌─────────────────────────────────────────────────────────┐
    │                                                         │
    │   ANOS 2000                    HOJE (Retro Hex Chat)             │
    │                                                         │
    │   IRC puro texto        →   Rich text, embeds, reações │
    │   Sem histórico         →   Histórico persistente       │
    │   Netsplits destrutivos →   CRDTs, eventual consistency │
    │   Trust total entre     →   Assinaturas criptográficas  │
    │     servidores                por mensagem              │
    │   Sem identidade        →   Identidade federada         │
    │     persistente               (@user@server)            │
    │   UI dos anos 90        →   LiveView, tempo real,       │
    │                               mobile-ready              │
    │   Federação fechada     →   Federação aberta com        │
    │     (só admins)               controles granulares      │
    │                                                         │
    └─────────────────────────────────────────────────────────┘

### Os princípios

1. **Qualquer pessoa pode rodar um servidor.** Instalar, subir, estar na rede.
   Ponto. Não precisa pedir permissão a ninguém.

2. **Nenhum servidor é especial.** Não existe servidor central, master, root.
   Existem seeds de bootstrap, mas são substituíveis.

3. **Você é dono dos seus dados.** Suas mensagens ficam no servidor que você
   escolheu. Se o servidor cair, você migra e leva sua identidade.

4. **Federação é opt-in e granular.** O dono do servidor decide com quem federar.
   O dono do canal decide se quer federar. O usuário decide quem seguir.

5. **Privacidade como padrão.** Servidores privados existem e são cidadãos de
   primeira classe. Nem tudo precisa ser público.

---

## II. Conceitos Fundamentais

### O que é um "Servidor Retro Hex Chat"?

Uma única aplicação Phoenix que faz TUDO:

    ┌─────────────────────────────────────────┐
    │           SERVIDOR RETRO HEX CHAT                │
    │         (uma app Phoenix)               │
    │                                         │
    │  ┌───────────┐    ┌──────────────────┐  │
    │  │           │    │                  │  │
    │  │  UI WEB   │    │  SERVIDOR IRC    │  │
    │  │ (LiveView)│    │  FEDERADO (S2S)  │  │
    │  │           │    │                  │  │
    │  │  - Chat   │    │  - Inbox HTTP    │  │
    │  │  - Admin  │    │  - Outbox HTTP   │  │
    │  │  - Perfis │    │  - Discovery     │  │
    │  │  - Feed   │    │  - Sync          │  │
    │  │           │    │                  │  │
    │  └─────┬─────┘    └────────┬─────────┘  │
    │        │                   │             │
    │        └─────────┬─────────┘             │
    │                  │                       │
    │          ┌───────┴────────┐              │
    │          │   PostgreSQL   │              │
    │          │   + PubSub     │              │
    │          └────────────────┘              │
    │                                         │
    └─────────────────────────────────────────┘

Não existe separação entre "client" e "server". Quando você acessa alpha.chat no
navegador, você está falando com o servidor alpha.chat. Quando alpha.chat precisa
entregar uma mensagem para beta.chat, ele fala diretamente server-to-server via
HTTP assinado.

### Identidades

Tudo no sistema tem um endereço federado:

    USUÁRIOS         @alice@alpha.chat
                     @bob@beta.internal
                     @carol@gamma.community

    CANAIS           #elixir@alpha.chat
                     #general@beta.internal
                     #musica@gamma.community

    SERVIDORES       alpha.chat
                     beta.internal
                     gamma.community

Quando um usuário está no seu próprio servidor, o @domínio é opcional. Alice em
alpha.chat vê apenas "@bob" para outros usuários de alpha.chat, mas vê
"@carol@gamma.community" para usuários remotos. Igual email.

### Os Três Tipos de Servidor

    ┌─────────────────────────────────────────────────────┐
    │                                                     │
    │  PÚBLICO          UNLISTED           PRIVADO        │
    │                                                     │
    │  - Aparece no     - NÃO aparece      - NÃO aparece │
    │    diretório        no diretório       no diretório │
    │  - Aceita peers   - Aceita peers     - SÓ aceita   │
    │    livremente       livremente         peers da     │
    │  - Canais podem   - Canais podem       allowlist   │
    │    ser listados     ser listados     - Canais       │
    │    publicamente     publicamente       internos     │
    │  - Registro        - Registro        - Registro    │
    │    aberto            aberto ou          por convite │
    │                      por convite                    │
    │                                                     │
    │  Ex: comunidade   Ex: servidor de    Ex: empresa,   │
    │      de Elixir        amigos         escola, time   │
    │                                                     │
    └─────────────────────────────────────────────────────┘

IMPORTANTE: servidores privados SÃO listados na rede (outros servidores sabem
que existem), mas seus canais, usuários e conteúdo NÃO são visíveis externamente.
Pense como uma conta privada no Instagram — você sabe que existe, mas não vê o
conteúdo sem permissão.

---

## III. Modelo de Dados

### Diagrama de Entidades

```
┌──────────────┐       ┌───────────────────┐       ┌──────────────┐
│    SERVER     │       │   CHANNEL         │       │    USER      │
│ (self/peers)  │       │                   │       │              │
├──────────────┤       ├───────────────────┤       ├──────────────┤
│ domain    PK │───┐   │ id            PK  │   ┌───│ id       PK  │
│ display_name │   │   │ name              │   │   │ nickname     │
│ description  │   ├──►│ domain        FK  │   │   │ domain   FK  │
│ visibility   │   │   │ topic             │   │   │ display_name │
│ public_key   │   │   │ description       │   │   │ bio          │
│ inbox_url    │   │   │ visibility        │   │   │ avatar_url   │
│ status       │   │   │ owner_id      FK ─┼───┘   │ public_key   │
│ software_ver │   │   │ federated?        │       │ private_key  │
│ stats (json) │   │   │ modes (json)      │       │ local?       │
│ capabilities │   │   │ max_members       │       │ discoverable │
│ last_seen_at │   │   │                   │       │ role         │
└──────┬───────┘   │   └─────────┬─────────┘       └──────┬───────┘
       │           │             │                         │
       │           │             │                         │
       │   ┌───────┴─────────────┴─────────────────────────┤
       │   │                                               │
       │   │         ┌─────────────────────┐               │
       │   │         │   MEMBERSHIP        │               │
       │   │         ├─────────────────────┤               │
       │   │         │ id             PK   │               │
       │   │         │ channel_id     FK ──┼───────────────┘
       │   │         │ user_id        FK ──┘  (via channel + user)
       │   │         │ role                │
       │   │         │   (owner|op|        │
       │   │         │    voice|member)    │
       │   │         │ joined_at           │
       │   │         │ notifications       │
       │   │         └─────────────────────┘
       │   │
       │   │         ┌─────────────────────┐
       │   │         │   MESSAGE           │
       │   │         ├─────────────────────┤
       │   │         │ id             PK   │
       │   │         │ channel_id     FK   │
       │   │         │ user_id        FK   │
       │   │         │ content             │
       │   │         │ content_type        │
       │   │         │   (text|markdown|   │
       │   │         │    embed|file)      │
       │   │         │ reply_to_id    FK   │  ← threads
       │   │         │ remote?             │
       │   │         │ origin_domain       │
       │   │         │ origin_id           │  ← ID original no servidor de origem
       │   │         │ signature           │  ← assinatura do autor
       │   │         │ edited_at           │
       │   │         │ deleted_at          │  ← soft delete
       │   │         └─────────────────────┘
       │
       │
       │             ┌──────────────────────────┐
       │             │   CHANNEL_LINK           │
       │             │   (federação de canais)  │
       │             ├──────────────────────────┤
       └────────────►│ id                  PK   │
                     │ local_channel_id    FK   │
                     │ peer_domain         FK   │
                     │ remote_channel_id        │  ← URI do canal remoto
                     │ remote_channel_name      │
                     │ status                   │
                     │   (pending_sent|         │
                     │    pending_received|     │
                     │    active|paused|        │
                     │    rejected)             │
                     │ sync_direction           │
                     │   (both|in|out)          │
                     │ sync_since               │
                     │ config (json)            │
                     │   .sync_messages         │
                     │   .sync_topic            │
                     │   .sync_members          │
                     │   .sync_moderation       │
                     │   .bridge_nicknames      │
                     └──────────────────────────┘


┌─────────────────────┐         ┌─────────────────────┐
│   FOLLOW            │         │   FEDERATION_LOG     │
├─────────────────────┤         ├─────────────────────┤
│ id             PK   │         │ id             PK   │
│ follower_id    FK   │         │ peer_domain         │
│ followed_id    FK   │         │ direction (in|out)  │
│ mutual?             │         │ message_type        │
│ created_at          │         │ payload_hash        │
└─────────────────────┘         │ status (ok|error)   │
                                │ error_detail        │
                                │ created_at          │
┌─────────────────────┐         └─────────────────────┘
│   BLOCK             │
├─────────────────────┤
│ id             PK   │
│ blocker_id     FK   │  ← pode ser user ou server
│ blocked_type        │  ← "user" | "server" | "channel"
│ blocked_ref         │  ← @user@dom | domain | #chan@dom
│ reason              │
└─────────────────────┘
```

### Relações-Chave

- Um SERVER tem muitos USERS e muitos CHANNELS
- Um CHANNEL pertence a um SERVER e tem um OWNER (user)
- MEMBERSHIP é a junção entre USER e CHANNEL com papel (role)
- MESSAGE pertence a um CHANNEL e a um USER
- CHANNEL_LINK conecta um canal local a um canal remoto (em outro server)
- FOLLOW conecta dois USERS (podem ser de servidores diferentes)
- BLOCK funciona em múltiplos níveis (user, server, channel)

---

## IV. Discovery — Como a Rede se Forma

### Bootstrap Inicial

Quando um servidor novo sobe pela primeira vez, ele não conhece ninguém. O
administrador configura uma lista de "seeds" — servidores conhecidos para o
contato inicial. Isso é idêntico a como redes P2P como BitTorrent funcionam.

    SERVIDOR NOVO (delta.chat)                 REDE EXISTENTE
    ═══════════════════════════                ═══════════════

    ┌─────────────┐
    │ delta.chat   │
    │ (acabou de   │
    │  subir)      │
    └──────┬──────┘
           │
           │  1. GET alpha.chat/.well-known/retro-hex-chat-federation
           │─────────────────────────────────────────────────►  ┌─────────┐
           │                                                     │ alpha   │
           │  2. Recebe: info do alpha + lista de peers          │  .chat  │
           │     [beta.chat, gamma.community]                    └────┬────┘
           │◄────────────────────────────────────────────────────     │
           │                                                          │
           │  3. GET beta.chat/.well-known/retro-hex-chat-federation           │
           │──────────────────────────────────►  ┌─────────┐         │
           │                                      │  beta   │         │
           │  4. Recebe: info + peers              │  .chat  │◄────────┘
           │     [alpha.chat, epsilon.org]         └─────────┘    (já conectados)
           │◄─────────────────────────────────
           │
           │  5. POST alpha.chat/federation/inbox
           │     "Oi, eu sou delta.chat, aqui está minha info"
           │──────────────────────────────────────────────────►
           │
           │  6. POST beta.chat/federation/inbox
           │     "Oi, eu sou delta.chat, aqui está minha info"
           │──────────────────────────────────────────────────►
           │
           │  DELTA AGORA CONHECE: alpha, beta, gamma, epsilon
           │  ALPHA E BETA AGORA CONHECEM: delta
           ▼

### Gossip Contínuo

Após o bootstrap, os servidores trocam listas de peers periodicamente:

    A cada 5 minutos:

    ┌─────────┐  "Eu conheço: B, C, D"   ┌─────────┐
    │    A    │──────────────────────────►│    E    │
    │         │                           │         │
    │         │  "Eu conheço: F, G, A"    │         │
    │         │◄──────────────────────────│         │
    └─────────┘                           └─────────┘

    Resultado: A agora conhece B, C, D, E, F, G
               E agora conhece A, B, C, D, F, G

    Cada rodada, cada servidor seleciona 3-5 peers aleatórios
    para trocar listas. Em poucas rodadas, toda a rede converge.

    Este é o protocolo de GOSSIP — não precisa de servidor central.
    Funciona mesmo que servidores entrem e saiam da rede a qualquer
    momento.

### Health Checking

    A cada 15 minutos, cada servidor faz ping nos peers conhecidos:

    ┌─────────┐
    │  alpha   │───── GET beta/.well-known/retro-hex-chat-federation
    │         │      │
    │         │      ├── 200 OK → status: active, reset failure_count
    │         │      ├── timeout → failure_count + 1
    │         │      └── 3+ falhas → status: unreachable
    └─────────┘           │
                          └── Após 24h unreachable:
                              │
                              ├── Pausa federation links com esse peer
                              ├── Continua tentando (backoff exponencial)
                              └── Se voltar: retoma links, sync delta

---

## V. Federação de Canais — O Fluxo Completo

### Passo a Passo

```
FASE 1: SOLICITAÇÃO

    Admin de alpha.chat quer federar #elixir com beta.chat

    ┌──────────────────┐                    ┌──────────────────┐
    │   alpha.chat      │                    │   beta.chat      │
    │                   │                    │                   │
    │  Admin abre       │                    │                   │
    │  painel de        │                    │                   │
    │  federação,       │                    │                   │
    │  seleciona        │                    │                   │
    │  #elixir,         │                    │                   │
    │  digita           │  ChannelFederate   │                   │
    │  "beta.chat"      │  Request           │                   │
    │  e clica          │ ──────────────────►│  Notificação no  │
    │  "Solicitar"      │                    │  painel admin    │
    │                   │                    │                   │
    │  Link criado:     │                    │  Link criado:    │
    │  status =         │                    │  status =        │
    │  pending_sent     │                    │  pending_received│
    └──────────────────┘                    └──────────────────┘


FASE 2: ACEITAÇÃO

    Admin de beta.chat revisa e aceita

    ┌──────────────────┐                    ┌──────────────────┐
    │   alpha.chat      │                    │   beta.chat      │
    │                   │                    │                   │
    │                   │  ChannelFederate   │  Admin revisa:   │
    │  Recebe accept,   │  Accept            │  - Qual canal?   │
    │  link muda para   │ ◄────────────────  │  - De quem?      │
    │  status: active   │                    │  - Config de     │
    │                   │                    │    sync?          │
    │                   │                    │  Clica "Aceitar" │
    │                   │                    │                   │
    │                   │                    │  Link muda para  │
    │                   │                    │  status: active  │
    └──────────────────┘                    └──────────────────┘


FASE 3: SINCRONIZAÇÃO INICIAL

    Os dois servidores trocam histórico recente

    ┌──────────────────┐                    ┌──────────────────┐
    │   alpha.chat      │                    │   beta.chat      │
    │                   │                    │                   │
    │  "Aqui estão as   │  ChannelSync       │                   │
    │   últimas 500     │ ──────────────────►│  Persiste as     │
    │   mensagens de    │                    │  mensagens como  │
    │   #elixir"        │                    │  remote=true     │
    │                   │                    │                   │
    │                   │  ChannelSync       │  "Aqui estão as  │
    │  Persiste as      │ ◄────────────────  │   últimas 500    │
    │  mensagens como   │                    │   mensagens de   │
    │  remote=true      │                    │   #elixir"       │
    └──────────────────┘                    └──────────────────┘


FASE 4: OPERAÇÃO CONTÍNUA

    A partir daqui, toda mensagem é propagada

    ┌──────────────────┐                    ┌──────────────────┐
    │   alpha.chat      │                    │   beta.chat      │
    │                   │                    │                   │
    │  Alice diz:       │  MessageCreate     │                   │
    │  "Oi pessoal!"    │ ──────────────────►│  Usuários de     │
    │                   │                    │  beta veem:      │
    │  Usuários de      │                    │  [alpha] Alice:  │
    │  alpha veem:      │                    │  "Oi pessoal!"   │
    │  Alice:           │                    │                   │
    │  "Oi pessoal!"    │                    │                   │
    │                   │  MessageCreate     │                   │
    │  Usuários de      │ ◄────────────────  │  Bob diz:        │
    │  alpha veem:      │                    │  "Fala Alice!"   │
    │  [beta] Bob:      │                    │                   │
    │  "Fala Alice!"    │                    │                   │
    └──────────────────┘                    └──────────────────┘
```

### Multi-Server Federation

Um canal pode ser federado com MÚLTIPLOS servidores. Cada servidor propaga
apenas para seus links diretos — não faz relay.

```
         alpha.chat (#elixir)
           /              \
     federado           federado
        /                    \
  beta.chat              gamma.community
  (#elixir)               (#elixir)

  Alice@alpha diz "oi"
    → propaga para beta (link direto)
    → propaga para gamma (link direto)
    → beta NÃO repropaga para gamma (evita duplicação)

  Bob@beta diz "fala"
    → propaga para alpha (link direto)
    → alpha NÃO repropaga para gamma
    → SE beta TAMBÉM tem link com gamma, propaga direto

  Regra: cada servidor só propaga para seus links diretos.
  O campo origin_id na mensagem evita duplicatas.
```

### Configurações de Sync por Link

Cada federação entre dois canais tem configurações independentes:

```
┌──────────────────────────────────────────────────────┐
│              CONFIG DE FEDERATION LINK                │
├──────────────────────────────────────────────────────┤
│                                                      │
│  Direção do sync:                                    │
│    ○ Bidirecional (ambos enviam e recebem)           │
│    ○ Só receber (espelho read-only)                  │
│    ○ Só enviar (broadcast)                           │
│                                                      │
│  O que sincronizar:                                  │
│    ☑ Mensagens                                       │
│    ☑ Mudanças de topic                               │
│    ☐ Lista de membros                                │
│    ☐ Ações de moderação (ban/kick)                   │
│    ☑ Reações                                         │
│    ☐ Arquivos/uploads                                │
│                                                      │
│  Apresentação:                                       │
│    ☑ Mostrar badge [servidor] antes do nick          │
│    ☐ Prefixar nicks remotos com servidor_            │
│                                                      │
│  Limites:                                            │
│    Histórico máximo para sync: [30 dias      ]       │
│    Rate limit de mensagens: [100/min         ]       │
│                                                      │
└──────────────────────────────────────────────────────┘
```

---

## VI. Segurança e Confiança

### Como Servidores se Autenticam

Toda comunicação server-to-server usa HTTP Signatures. Isso significa que cada
request é assinado com a chave privada do servidor remetente e verificado com
a chave pública pelo receptor.

```
  ALPHA quer enviar mensagem para BETA

  1. Alpha monta o request HTTP (POST /federation/inbox)

  2. Alpha calcula:
     - Hash SHA-256 do body
     - String de assinatura = método + path + host + date + hash
     - Assina a string com sua chave PRIVADA

  3. Alpha envia com headers:
     Signature: keyId="https://alpha.chat#main-key",
                algorithm="ed25519",
                headers="(request-target) host date digest",
                signature="base64..."
     Digest: SHA-256=base64...
     Date: Thu, 12 Feb 2026 10:30:00 GMT

  4. Beta recebe e:
     - Extrai keyId do header Signature
     - Faz GET https://alpha.chat/.well-known/retro-hex-chat-federation
       para obter a chave PÚBLICA (com cache)
     - Reconstrói a signing string
     - Verifica a assinatura

  5. Se válido: processa. Se inválido: rejeita com 401.
```

Isso garante:
- **Autenticidade:** a mensagem realmente veio de alpha.chat
- **Integridade:** o body não foi alterado no caminho
- **Não-repúdio:** alpha.chat não pode negar que enviou

### Modelo de Confiança em Camadas

```
╔══════════════════════════════════════════════════════════════════╗
║                    CAMADAS DE CONTROLE                          ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  NÍVEL 1: ADMINISTRADOR DO SERVIDOR                             ║
║  ┌────────────────────────────────────────────────────────┐     ║
║  │  • Define modo do servidor (aberto / allowlist / block)│     ║
║  │  • Suspende servidores inteiros                        │     ║
║  │  • Aceita/rejeita pedidos de federação                 │     ║
║  │  • Define regras globais do servidor                   │     ║
║  │  • Pode forçar defederação de qualquer canal           │     ║
║  └────────────────────────────────────────────────────────┘     ║
║                          │                                       ║
║                          ▼                                       ║
║  NÍVEL 2: DONO DO CANAL (op)                                    ║
║  ┌────────────────────────────────────────────────────────┐     ║
║  │  • Decide se o canal aceita federação                  │     ║
║  │  • Escolhe com quais servidores federar                │     ║
║  │  • Configura sync (direção, o que sincronizar)         │     ║
║  │  • Modera seu canal (ban, kick, mute)                  │     ║
║  │  • Decide se moderação propaga para peers              │     ║
║  └────────────────────────────────────────────────────────┘     ║
║                          │                                       ║
║                          ▼                                       ║
║  NÍVEL 3: USUÁRIO                                               ║
║  ┌────────────────────────────────────────────────────────┐     ║
║  │  • Bloqueia usuários individuais (locais ou remotos)   │     ║
║  │  • Silencia servidores inteiros (não vê mensagens)     │     ║
║  │  • Controla visibilidade do próprio perfil             │     ║
║  │  • Denuncia conteúdo (report vai para admin local      │     ║
║  │    e opcionalmente para admin do servidor de origem)   │     ║
║  └────────────────────────────────────────────────────────┘     ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

### Modos de Federação do Servidor

```
MODO ABERTO (padrão para servidores públicos)
─────────────────────────────────────────────
  Qualquer servidor pode:
    ✓ Descobrir este servidor via gossip
    ✓ Ver canais públicos
    ✓ Solicitar federação de canais
    ✓ Resolver usuários via WebFinger
  Admin ainda precisa aprovar:
    • Pedidos de federação de canal (se require_approval = true)


MODO ALLOWLIST (para servidores semi-privados)
──────────────────────────────────────────────
  Apenas servidores na allowlist podem:
    ✓ Ver canais públicos
    ✓ Solicitar federação
    ✓ Resolver usuários
  Outros servidores:
    ✗ Recebem 403 em todos os endpoints de federação
    ✓ Sabem que o servidor existe (via gossip)


MODO BLOCKLIST (aberto com exceções)
─────────────────────────────────────
  Igual ao modo aberto, exceto que servidores
  na blocklist são completamente ignorados:
    ✗ Requests recebem 403
    ✗ Não aparecem no gossip relay
    ✗ Mensagens federadas são descartadas
```

---

## VII. Funcionalidades Sociais

### Follow de Usuários Cross-Server

Além do modelo IRC de canais, o Retro Hex Chat adiciona funcionalidades de rede social:

```
  Alice@alpha segue Bob@beta

  ┌─────────────┐                    ┌─────────────┐
  │  alpha.chat  │                    │  beta.chat   │
  │              │                    │              │
  │  Alice clica │   UserFollow       │              │
  │  "Seguir"    │──────────────────►│  Bob recebe  │
  │  no perfil   │                    │  notificação │
  │  de Bob      │                    │              │
  │              │                    │  Bob pode:   │
  │  Follow      │                    │  • Aceitar   │
  │  criado:     │                    │  • Recusar   │
  │  pending     │                    │  • Seguir de │
  │              │   UserAccept       │    volta     │
  │  Follow      │◄──────────────────│  (mutual)    │
  │  status:     │                    │              │
  │  active      │                    │              │
  └─────────────┘                    └─────────────┘
```

### O que o Follow permite:

```
  SEM FOLLOW                           COM FOLLOW
  ──────────                           ──────────
  • Vê mensagens em canais             • Tudo do "sem follow" +
    federados que ambos                • Vê status online/away/offline
    participam                         • Recebe notificações de
  • Pode enviar DM (se o                 menções em canais públicos
    destinatário permitir)             • Aparece no feed de atividade
  • Vê perfil público                  • Pode ver bio estendida
                                       • DMs com prioridade (não
                                         vão para "solicitações")
```

### Feed de Atividade

Cada usuário tem um feed que agrega atividade relevante:

```
┌────────────────────────────────────────────────────────┐
│  FEED DE ATIVIDADE                                     │
├────────────────────────────────────────────────────────┤
│                                                        │
│  🟢 Bob@beta.chat está online                     2min │
│                                                        │
│  💬 Carol@gamma.community em #elixir:             5min │
│     "Alguém já usou o Nx com GPU?"                     │
│                                                        │
│  📢 #rust@delta.org federou com #rust@alpha.chat  1h   │
│                                                        │
│  👋 Dave@epsilon.net entrou em #elixir@alpha.chat 2h   │
│                                                        │
│  💬 Bob@beta.chat em #general:                    3h   │
│     "Bom dia galera"                                   │
│                                                        │
│  🔗 Novo servidor na rede: omega.community        5h   │
│     "Comunidade de Open Source em PT-BR"               │
│                                                        │
└────────────────────────────────────────────────────────┘

  O feed inclui:
  • Mensagens em canais que você participa
  • Atividade de usuários que você segue
  • Menções a você de qualquer servidor federado
  • Novos servidores na rede (opcional)
  • Eventos de federação dos seus canais
```

---

## VIII. Wireframes das Telas

### Tela Principal — Chat

```
┌────────────────────────────────────────────────────────────────────┐
│  Retro Hex Chat  alpha.chat                              @alice ● online   │
├────────┬───────────────────────────────────────────────┬───────────┤
│        │  #elixir@alpha.chat                          │ MEMBROS   │
│ CANAIS │  ─────────────────                           │ ────────  │
│ ────── │  Federado com: beta.chat, gamma.community    │           │
│        │  Topic: Tudo sobre Elixir e Phoenix          │ LOCAIS    │
│ #geral │  ───────────────────────────────────────     │ ● alice   │
│ #elixir│                                              │ ● dave    │
│ #random│  ● alice                         10:23       │ ● eve     │
│        │    Bom dia! Alguém testou o Phoenix 1.8?     │           │
│ FEDERA │                                              │ BETA.CHAT │
│ ────── │  ● bob@beta.chat          [beta] 10:24       │ ● bob     │
│ #rust  │    Sim! O LiveView está muito bom            │ ● frank   │
│  @delta│                                              │           │
│ #go    │  ● carol@gamma.community [gamma] 10:25       │ GAMMA     │
│  @eps  │    Concordo, a performance melhorou demais   │ ● carol   │
│        │                                              │           │
│ DMs    │  ● alice                         10:26       │           │
│ ────── │    @bob@beta.chat legal! Tá usando           │           │
│ bob    │    em produção?                              │           │
│ carol  │                                              │           │
│        │  ● bob@beta.chat          [beta] 10:27       │           │
│        │    Sim, migrei do Node semana passada        │           │
│        │                                              │           │
│ ────── │                                              │           │
│ REDE   │                                              │           │
│ ────── │                                              │           │
│ Feed   │                                              │           │
│ Diretó-│──────────────────────────────────────────────│           │
│  rio   │  [  Mensagem...                    ] [Enviar]│           │
└────────┴──────────────────────────────────────────────┴───────────┘
```

### Tela de Diretório de Servidores

```
┌────────────────────────────────────────────────────────────────────┐
│  Retro Hex Chat  alpha.chat                              @alice ● online   │
├────────┬───────────────────────────────────────────────────────────┤
│        │                                                          │
│ (nav)  │  DIRETÓRIO DE SERVIDORES                                 │
│        │  ═══════════════════════                                 │
│        │                                                          │
│        │  Servidores conhecidos na rede: 47                       │
│        │  [🔍 Buscar servidor...                              ]   │
│        │                                                          │
│        │  ┌─────────────────────────────────────────────────────┐ │
│        │  │  🟢 beta.chat                                       │ │
│        │  │  "Comunidade Brasileira de Elixir"                  │ │
│        │  │  👥 342 ativos  📢 12 canais públicos  🔗 8 feder. │ │
│        │  │  Canais: #elixir #phoenix #nerves #liveview         │ │
│        │  │  [Ver canais]  [Solicitar federação]                │ │
│        │  └─────────────────────────────────────────────────────┘ │
│        │                                                          │
│        │  ┌─────────────────────────────────────────────────────┐ │
│        │  │  🟢 gamma.community                                 │ │
│        │  │  "Open Source & Linux Brasil"                        │ │
│        │  │  👥 1.2k ativos  📢 34 canais públicos  🔗 15 fed. │ │
│        │  │  Canais: #linux #rust #go #python #elixir #devops   │ │
│        │  │  [Ver canais]  [Solicitar federação]                │ │
│        │  └─────────────────────────────────────────────────────┘ │
│        │                                                          │
│        │  ┌─────────────────────────────────────────────────────┐ │
│        │  │  🔒 delta.internal                                  │ │
│        │  │  "Servidor Privado"                                 │ │
│        │  │  Canais e membros não visíveis                      │ │
│        │  │  [Solicitar acesso]                                 │ │
│        │  └─────────────────────────────────────────────────────┘ │
│        │                                                          │
│        │  ┌─────────────────────────────────────────────────────┐ │
│        │  │  🟡 epsilon.org                    (última vez: 2h) │ │
│        │  │  "Hackerspace São Paulo"                            │ │
│        │  │  👥 89 ativos  📢 7 canais públicos  🔗 3 feder.   │ │
│        │  │  [Ver canais]  [Solicitar federação]                │ │
│        │  └─────────────────────────────────────────────────────┘ │
│        │                                                          │
│        │  ◄ 1  2  3  4  5 ►                                      │
│        │                                                          │
└────────┴──────────────────────────────────────────────────────────┘
```

### Tela de Perfil Federado

```
┌────────────────────────────────────────────────────────────────────┐
│  Retro Hex Chat  alpha.chat                              @alice ● online   │
├────────┬───────────────────────────────────────────────────────────┤
│        │                                                          │
│ (nav)  │  ┌──────┐  bob                                          │
│        │  │avatar │  @bob@beta.chat                               │
│        │  │      │  ───────────────                               │
│        │  └──────┘  "Full stack dev, Elixir enthusiast"           │
│        │                                                          │
│        │  🏠 Servidor: beta.chat                                  │
│        │  📅 Membro desde: Jan 2025                               │
│        │  👥 42 seguidores · 38 seguindo                          │
│        │                                                          │
│        │  [✓ Seguindo]  [Enviar DM]  [Bloquear ▼]                │
│        │                                                          │
│        │  CANAIS EM COMUM                                         │
│        │  ─────────────────                                       │
│        │  #elixir@alpha.chat (federado com beta)                  │
│        │  #phoenix@beta.chat (federado com alpha)                 │
│        │                                                          │
│        │  ATIVIDADE RECENTE                                       │
│        │  ─────────────────                                       │
│        │  💬 em #elixir: "O LiveView está muito bom"     10:24   │
│        │  💬 em #phoenix: "Nova versão saiu!"            ontem   │
│        │  👋 entrou em #nerves@beta.chat                 3 dias  │
│        │                                                          │
└────────┴──────────────────────────────────────────────────────────┘
```

### Painel Admin — Federação

```
┌────────────────────────────────────────────────────────────────────┐
│  Retro Hex Chat  alpha.chat  [ADMIN]                     @alice ● online   │
├────────┬───────────────────────────────────────────────────────────┤
│        │                                                          │
│ ADMIN  │  PAINEL DE FEDERAÇÃO                                     │
│ ────── │  ═══════════════════                                     │
│        │                                                          │
│ Geral  │  Modo: [● Aberto ○ Allowlist ○ Blocklist]               │
│ Usuá-  │  Aprovação manual: [✓]                                   │
│  rios  │  Auto-aceitar de: beta.chat, gamma.community             │
│ Canais │                                                          │
│►Federa-│  ─── PEERS CONHECIDOS (47) ─────────────────────────     │
│  ção   │                                                          │
│ Regras │  │ Servidor           │ Status │ Links │ Última vez │    │
│ Logs   │  ├────────────────────┼────────┼───────┼────────────┤    │
│        │  │ 🟢 beta.chat       │ ativo  │   3   │   agora    │    │
│        │  │ 🟢 gamma.community │ ativo  │   2   │   1 min    │    │
│        │  │ 🟡 epsilon.org     │ ativo  │   1   │   2 horas  │    │
│        │  │ 🔴 omega.net       │ unreach│   0   │   3 dias   │    │
│        │  │ ⛔ spam.server     │ suspen │   0   │   blocked  │    │
│        │  └────────────────────┴────────┴───────┴────────────┘    │
│        │  [+ Adicionar peer manual]                               │
│        │                                                          │
│        │  ─── SOLICITAÇÕES PENDENTES (2) ─────────────────────    │
│        │                                                          │
│        │  ┌───────────────────────────────────────────────────┐   │
│        │  │  delta.org quer federar #rust com seu #rust       │   │
│        │  │  Sync: bidirecional · Mensagens + Topic           │   │
│        │  │  [Aceitar]  [Rejeitar]  [Ver servidor]            │   │
│        │  └───────────────────────────────────────────────────┘   │
│        │                                                          │
│        │  ┌───────────────────────────────────────────────────┐   │
│        │  │  zeta.chat quer federar #general com seu #general │   │
│        │  │  Sync: só receber · Apenas mensagens              │   │
│        │  │  [Aceitar]  [Rejeitar]  [Ver servidor]            │   │
│        │  └───────────────────────────────────────────────────┘   │
│        │                                                          │
│        │  ─── LINKS ATIVOS (6) ──────────────────────────────     │
│        │                                                          │
│        │  │ Canal local │ Peer            │ Canal remoto │ Sync │ │
│        │  ├─────────────┼─────────────────┼──────────────┼──────┤ │
│        │  │ #elixir     │ beta.chat       │ #elixir      │ ↔    │ │
│        │  │ #elixir     │ gamma.community │ #elixir      │ ↔    │ │
│        │  │ #phoenix    │ beta.chat       │ #phoenix     │ ↔    │ │
│        │  │ #rust       │ delta.org       │ #rust        │ ← in │ │
│        │  │ #general    │ gamma.community │ #general     │ ↔    │ │
│        │  │ #news       │ epsilon.org     │ #noticias    │ → out│ │
│        │  └─────────────┴─────────────────┴──────────────┴──────┘ │
│        │                                                          │
│        │  [+ Nova federação]                                      │
│        │                                                          │
└────────┴──────────────────────────────────────────────────────────┘
```

### Tela de Nova Federação

```
┌────────────────────────────────────────────────────────────────────┐
│                                                                    │
│  SOLICITAR FEDERAÇÃO DE CANAL                                      │
│  ════════════════════════════                                      │
│                                                                    │
│  Canal local:                                                      │
│  ┌──────────────────────────────────────────────────┐              │
│  │ #elixir                                      [▼] │              │
│  └──────────────────────────────────────────────────┘              │
│                                                                    │
│  Servidor remoto:                                                  │
│  ┌──────────────────────────────────────────────────┐              │
│  │ beta.chat                                        │              │
│  └──────────────────────────────────────────────────┘              │
│  🟢 Servidor encontrado: "Comunidade BR de Elixir"                │
│                                                                    │
│  Canal remoto:                                                     │
│  ┌──────────────────────────────────────────────────┐              │
│  │ #elixir                                      [▼] │              │
│  └──────────────────────────────────────────────────┘              │
│  Canais disponíveis: #elixir #phoenix #nerves #liveview            │
│                                                                    │
│  ─── CONFIGURAÇÃO DE SYNC ───                                      │
│                                                                    │
│  Direção:                                                          │
│    (●) Bidirecional — ambos enviam e recebem                       │
│    ( ) Só receber — espelho read-only do canal remoto              │
│    ( ) Só enviar — broadcast do canal local                        │
│                                                                    │
│  Sincronizar:                                                      │
│    [✓] Mensagens                                                   │
│    [✓] Mudanças de topic                                           │
│    [ ] Lista de membros                                            │
│    [ ] Ações de moderação                                          │
│    [✓] Reações                                                     │
│                                                                    │
│  Visual:                                                           │
│    [✓] Mostrar badge [servidor] antes do nick remoto               │
│                                                                    │
│  Histórico:                                                        │
│    Sincronizar mensagens dos últimos [30] dias                     │
│                                                                    │
│  Mensagem para o admin remoto (opcional):                          │
│  ┌──────────────────────────────────────────────────┐              │
│  │ Oi! Somos a comunidade alpha.chat, gostaríamos   │              │
│  │ de federar nosso #elixir com o de vocês.          │              │
│  └──────────────────────────────────────────────────┘              │
│                                                                    │
│  [Cancelar]                          [Enviar solicitação]          │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

---

## IX. Fluxo de Mensagens — Diagrama Completo

### Mensagem Local (sem federação)

```
  USUÁRIO          LIVEVIEW        CHANNEL        PUBSUB         DB
    │                │             SERVER           │             │
    │  "oi mundo"    │               │              │             │
    │───────────────►│               │              │             │
    │                │  cast(:msg)   │              │             │
    │                │──────────────►│              │             │
    │                │               │   INSERT     │             │
    │                │               │─────────────────────────►  │
    │                │               │              │             │
    │                │               │  broadcast   │             │
    │                │               │─────────────►│             │
    │                │               │              │             │
    │                │  handle_info  │              │             │
    │                │◄─────────────────────────────│             │
    │  stream_insert │               │              │             │
    │◄───────────────│               │              │             │
    │  (vê mensagem) │               │              │             │
```

### Mensagem com Federação

```
  USUÁRIO    LIVEVIEW    CHANNEL     PUBSUB    DB     OBAN      PEER
    │          │         SERVER        │       │       │       (beta)
    │ "oi"     │           │           │       │       │         │
    │─────────►│           │           │       │       │         │
    │          │  cast     │           │       │       │         │
    │          │──────────►│           │       │       │         │
    │          │           │  INSERT   │       │       │         │
    │          │           │──────────────────►│       │         │
    │          │           │           │       │       │         │
    │          │           │ broadcast │       │       │         │
    │          │           │──────────►│       │       │         │
    │          │           │           │       │       │         │
    │          │ handle_   │           │       │       │         │
    │          │◄──────────────────────│       │       │         │
    │ (vê msg) │           │           │       │       │         │
    │◄─────────│           │           │       │       │         │
    │          │           │           │       │       │         │
    │          │           │  enqueue job      │       │         │
    │          │           │──────────────────────────►│         │
    │          │           │           │       │       │         │
    │          │           │           │       │  POST /inbox    │
    │          │           │           │       │       │────────►│
    │          │           │           │       │       │         │
    │          │           │           │       │       │  200 OK │
    │          │           │           │       │       │◄────────│
    │          │           │           │       │       │         │
    │          │           │           │       │    (beta agora  │
    │          │           │           │       │     faz broadcast
    │          │           │           │       │     para seus   │
    │          │           │           │       │     LiveViews)  │
```

### Mensagem Recebida de Peer

```
  PEER       INBOX        FEDERATION      CHANNEL     PUBSUB    LIVEVIEW
 (alpha)   CONTROLLER     HANDLER         SERVER        │          │
    │          │              │              │           │          │
    │ POST     │              │              │           │          │
    │ /inbox   │              │              │           │          │
    │─────────►│              │              │           │          │
    │          │              │              │           │          │
    │          │ 1. Verifica  │              │           │          │
    │          │    HTTP Sig  │              │           │          │
    │          │              │              │           │          │
    │          │ 2. Dispatch  │              │           │          │
    │          │─────────────►│              │           │          │
    │          │              │              │           │          │
    │          │              │ 3. Encontra  │           │          │
    │          │              │    canal     │           │          │
    │          │              │    local     │           │          │
    │          │              │    pelo link │           │          │
    │          │              │              │           │          │
    │          │              │ 4. cast      │           │          │
    │          │              │─────────────►│           │          │
    │          │              │              │           │          │
    │          │              │              │ 5. INSERT │          │
    │          │              │              │   (remote │          │
    │          │              │              │    =true) │          │
    │          │              │              │           │          │
    │          │              │              │ broadcast │          │
    │          │              │              │──────────►│          │
    │          │              │              │           │          │
    │          │              │              │           │ handle_  │
    │          │              │              │           │ info     │
    │          │              │              │           │─────────►│
    │          │              │              │           │          │
    │  202     │              │              │           │  (user   │
    │◄─────────│              │              │           │   vê a   │
    │ accepted │              │              │           │   msg)   │
    │          │              │              │           │          │
    │          │   IMPORTANTE: NÃO re-propaga para outros peers    │
    │          │   (evita loop infinito e duplicação)               │
```

---

## X. Resiliência — O que Acontece Quando as Coisas Quebram

### Cenário: Peer fica offline

```
  alpha.chat                                    beta.chat (OFFLINE)
      │                                              ✗
      │  Alice envia msg em #elixir                  ✗
      │                                              ✗
      │  1. Mensagem entregue localmente ✓           ✗
      │  2. Oban job tenta POST para beta            ✗
      │     → timeout                                ✗
      │  3. Job vai para retry                       ✗
      │     tentativa 1: aguarda 1 min               ✗
      │     tentativa 2: aguarda 2 min               ✗
      │     tentativa 3: aguarda 4 min               ✗
      │     ...                                      ✗
      │     tentativa 10: aguarda 8 horas            ✗
      │  4. Após 10 falhas: peer marcado             ✗
      │     como unreachable                         ✗
      │  5. Health checker continua                  ✗
      │     tentando a cada 15 min                   ✗
      │                                              ✗
      │                              ┌───────────────┤
      │                              │ BETA VOLTA!   │
      │                              │               │
      │  6. Health check detecta     │               │
      │     que beta voltou          │◄──────────────│
      │                              │               │
      │  7. Status: active           │               │
      │     Links: retomados         │               │
      │                              │               │
      │  8. Delta sync:              │               │
      │     "Me envie tudo desde     │               │
      │      meu último sync"  ─────────────────────►│
      │                              │               │
      │  9. Beta envia mensagens  ◄──────────────────│
      │     que alpha perdeu         │               │
      │                              │               │
      │  10. Normalidade restaurada  │               │
```

### Cenário: Mensagem duplicada

```
  Mensagem de Alice chega em beta por dois caminhos
  (se beta tem link com alpha E com gamma que re-enviou)

  ALPHA ────── msg ────────► BETA
    │                          │
    └─── msg ──► GAMMA ──────►│  (mesmo origin_id)
                               │
  BETA recebe a mesma mensagem duas vezes?

  SOLUÇÃO: campo origin_id + origin_domain
  ─────────────────────────────────────────
  Cada mensagem tem um ID único no servidor de origem.
  Ao receber uma mensagem federada, beta verifica:

    "Já tenho uma mensagem com
     origin_id=X e origin_domain=alpha.chat?"

     SIM → descarta (idempotente)
     NÃO → persiste e broadcast
```

---

## XI. Tecnologias e Justificativas

```
┌─────────────────────┬────────────────────────────────────────────┐
│ TECNOLOGIA          │ POR QUÊ                                   │
├─────────────────────┼────────────────────────────────────────────┤
│                     │                                            │
│ Elixir + Phoenix    │ Processos leves da BEAM permitem um       │
│                     │ GenServer por canal ativo (milhares        │
│                     │ simultâneos). LiveView dá UI reativa       │
│                     │ sem escrever JavaScript. PubSub nativo.    │
│                     │                                            │
│ Phoenix LiveView    │ Tempo real sem complexidade de SPA.        │
│                     │ Server-rendered com WebSocket.             │
│                     │ Perfeito para chat.                        │
│                     │                                            │
│ PostgreSQL          │ JSONB para metadata flexível. Full-text    │
│                     │ search para busca de mensagens. Confiável. │
│                     │ Ecto facilita migrations e queries.        │
│                     │                                            │
│ Oban                │ Job queue em Postgres — sem Redis.         │
│                     │ Retry com backoff exponencial para         │
│                     │ delivery federada. Dashboard web.          │
│                     │ Garantia de entrega.                       │
│                     │                                            │
│ Horde + libcluster  │ Para escalar UM servidor em múltiplas      │
│                     │ instâncias BEAM. Registry e Supervisor     │
│                     │ distribuídos. CRDTs para consistência.     │
│                     │ NÃO é para federação — é para cluster      │
│                     │ interno do servidor.                       │
│                     │                                            │
│ HTTP Signatures     │ Padrão da indústria (ActivityPub/Mastodon) │
│                     │ para autenticação S2S. Cada request é      │
│                     │ assinado. Sem shared secrets. Sem tokens.  │
│                     │                                            │
│ WebFinger (RFC7033) │ Padrão para discovery de identidades       │
│                     │ federadas. Compatível com o Fediverse.     │
│                     │ Resolve @user@domain para profile URL.     │
│                     │                                            │
│ Ed25519             │ Curvas elípticas para assinatura digital.  │
│                     │ Rápido, chaves pequenas, seguro.           │
│                     │ Usado por SSH, Signal, WireGuard.          │
│                     │                                            │
│ Req (HTTP client)   │ HTTP client moderno para Elixir.           │
│                     │ Usado para requests S2S de saída.          │
│                     │                                            │
│ Cachex              │ Cache em memória para chaves públicas      │
│                     │ de peers, evitando fetch a cada request.   │
│                     │                                            │
└─────────────────────┴────────────────────────────────────────────┘
```

### O que NÃO usamos e por quê

```
┌─────────────────────┬────────────────────────────────────────────┐
│ NÃO USAMOS          │ POR QUÊ NÃO                               │
├─────────────────────┼────────────────────────────────────────────┤
│                     │                                            │
│ Distributed Erlang  │ Funciona apenas dentro de um cluster      │
│ para federação      │ controlado. Requer mesmo cookie, mesma    │
│                     │ versão de código. Não cruza a internet.   │
│                     │ Usamos HTTP para S2S em vez disso.        │
│                     │                                            │
│ Redis               │ Oban usa Postgres como backend.           │
│                     │ Phoenix PubSub usa o PG nativo da BEAM.   │
│                     │ Menos uma dependência para operar.        │
│                     │                                            │
│ ActivityPub puro    │ Projetado para microblogging (posts), não  │
│                     │ para chat em tempo real. Adaptaríamos      │
│                     │ demais. Pegamos as boas ideias (HTTP Sig,  │
│                     │ WebFinger) e criamos protocolo próprio.    │
│                     │                                            │
│ Matrix protocol     │ Complexo demais para o caso de uso.       │
│                     │ DAG de eventos, state resolution rules,   │
│                     │ etc. Queremos algo mais simples e rápido. │
│                     │ Mas a inspiração conceitual é Matrix.     │
│                     │                                            │
│ WebRTC / P2P        │ Queremos servidores com persistência,     │
│                     │ não comunicação efêmera entre browsers.   │
│                     │ Servidores são cidadãos de primeira classe.│
│                     │                                            │
│ Blockchain / DHT    │ Overhead desnecessário. Não precisamos de │
│                     │ consenso global. Eventual consistency com  │
│                     │ CRDTs resolve nosso caso de uso.          │
│                     │                                            │
└─────────────────────┴────────────────────────────────────────────┘
```

---

## XII. Escalabilidade — De 1 a 100.000 Usuários

### Estágio 1: Servidor Único

```
  1 instância Phoenix + 1 Postgres

  ┌─────────────────────────────┐
  │  Phoenix (1 instância)      │
  │  ┌─────────────────────┐    │
  │  │ GenServer por canal  │    │     ┌──────────┐
  │  │ PubSub local         │────────►│ Postgres │
  │  │ LiveView connections │    │     └──────────┘
  │  └─────────────────────┘    │
  └─────────────────────────────┘

  Capacidade estimada: ~5.000 conexões simultâneas
  Suficiente para a maioria das comunidades.
```

### Estágio 2: Cluster BEAM

```
  Múltiplas instâncias Phoenix + Horde + 1 Postgres

  ┌──────────┐  ┌──────────┐  ┌──────────┐
  │ Phoenix  │  │ Phoenix  │  │ Phoenix  │
  │ node A   │──│ node B   │──│ node C   │   (libcluster)
  └────┬─────┘  └────┬─────┘  └────┬─────┘
       │              │              │
       └──────────────┼──────────────┘
                      │
                ┌─────┴──────┐
                │  Postgres  │
                │ (ou pool)  │
                └────────────┘

  Horde distribui GenServers de canais entre os nós.
  PubSub via pg (Erlang) funciona cross-node automaticamente.

  Capacidade estimada: ~50.000 conexões simultâneas
```

### Estágio 3: Scale-Out Completo

```
  ┌────────────────────────────────────────────┐
  │              LOAD BALANCER                 │
  │         (sticky sessions por WS)           │
  └─────┬──────────┬──────────┬────────────────┘
        │          │          │
  ┌─────┴──┐ ┌────┴───┐ ┌───┴────┐
  │ Node A │ │ Node B │ │ Node C │  ... Node N
  │        │ │        │ │        │
  └───┬────┘ └───┬────┘ └───┬────┘
      │          │          │
      └──────────┼──────────┘
                 │
    ┌────────────┼────────────┐
    │            │            │
  ┌─┴──┐   ┌───┴───┐   ┌───┴────┐
  │ PG │   │ PG    │   │ PG     │
  │ RW │   │ Read  │   │ Read   │
  │    │   │Replica│   │Replica │
  └────┘   └───────┘   └────────┘

  Capacidade estimada: 100.000+ conexões simultâneas
```

---

## XIII. Roadmap de Implementação

```
FASE 1 — CHAT LOCAL (semanas 1-4)
═════════════════════════════════
  □ Setup do projeto Phoenix
  □ Auth (phx.gen.auth) com perfis de usuário
  □ Modelo de dados: users, channels, messages, memberships
  □ GenServer por canal com Horde Registry
  □ LiveView: lista de canais, chat em tempo real
  □ PubSub para broadcast de mensagens
  □ Presença (quem está online)
  □ DMs (mensagens diretas)
  □ Upload de avatar
  □ Papéis: owner, op, voice, member

  ENTREGÁVEL: Um servidor de chat funcional, sem federação.
  ────────────────────────────────────────────────────────


FASE 2 — IDENTIDADE E DISCOVERY (semanas 5-7)
══════════════════════════════════════════════
  □ Geração de par de chaves Ed25519 no setup do servidor
  □ Endpoint /.well-known/retro-hex-chat-federation
  □ Endpoint /.well-known/webfinger
  □ Schema de Peers no banco
  □ GenServer de Discovery (bootstrap + gossip)
  □ Health checker periódico
  □ Tela de diretório de servidores
  □ Config: seeds, modo (open/allowlist/blocklist)

  ENTREGÁVEL: Servidores se descobrem e listam uns aos outros.
  ────────────────────────────────────────────────────────────


FASE 3 — FEDERAÇÃO S2S (semanas 8-12)
══════════════════════════════════════
  □ HTTP Signatures: assinar requests de saída
  □ Plug de verificação de assinatura (requests de entrada)
  □ Cache de chaves públicas (Cachex)
  □ InboxController: receber mensagens S2S
  □ Oban workers para delivery com retry
  □ Schema de ChannelLink
  □ Fluxo: solicitar → aceitar/rejeitar federação
  □ Propagação de mensagens para peers
  □ Recepção de mensagens de peers (sem re-propagação)
  □ Sync inicial (histórico recente)
  □ Deduplicação por origin_id
  □ Painel admin de federação (peers, links, requests)

  ENTREGÁVEL: Dois servidores trocam mensagens em canais federados.
  ──────────────────────────────────────────────────────────────────


FASE 4 — REDE SOCIAL (semanas 13-16)
═════════════════════════════════════
  □ Follow de usuários cross-server
  □ Perfis federados (buscar perfil remoto via WebFinger)
  □ Feed de atividade
  □ Menções cross-server (@user@domain)
  □ Notificações
  □ Bloqueio de usuários e servidores
  □ Presença federada (opt-in)

  ENTREGÁVEL: Aspectos sociais completos. Seguir, feed, perfis.
  ──────────────────────────────────────────────────────────────


FASE 5 — MODERAÇÃO E SEGURANÇA (semanas 17-20)
═══════════════════════════════════════════════
  □ Reports cross-server
  □ Propagação de mod actions (ban/kick) para peers (opt-in)
  □ Allowlist/blocklist de servidores
  □ Rate limiting por peer
  □ Logs de federação (auditoria)
  □ Painel de saúde da rede
  □ Defederação (remover link + limpar dados remotos)
  □ Moderação em massa (suspender peer = suspender todos os links)

  ENTREGÁVEL: Ferramentas robustas para admins e moderadores.
  ──────────────────────────────────────────────────────────


FASE 6 — POLIMENTO E EXTRAS (semanas 21+)
═════════════════════════════════════════
  □ Threads (respostas em mensagens)
  □ Reações (emoji)
  □ Edição e deleção de mensagens (propagada)
  □ File sharing federado
  □ Busca full-text em mensagens
  □ Temas e customização por servidor
  □ Bridge para IRC clássico (RFC 1459)
  □ Bridge para Discord / Matrix
  □ API REST/GraphQL para bots e integrações
  □ App mobile (LiveView Native ou PWA)
  □ E2E encryption (double ratchet)
  □ Cluster BEAM com libcluster (escalar servidor individual)
```

---

## XIV. Resumo da Visão

```
  ╔════════════════════════════════════════════════════════════╗
  ║                                                            ║
  ║   O Retro Hex Chat é uma rede onde cada comunidade roda seu         ║
  ║   próprio servidor, controla seus dados, define suas       ║
  ║   regras — e ainda assim pode conversar com qualquer       ║
  ║   outra comunidade na rede.                                ║
  ║                                                            ║
  ║   Não é um serviço. É um protocolo. É software que         ║
  ║   você instala, configura e opera. A rede é a soma         ║
  ║   de todos os servidores individuais, sem hierarquia,      ║
  ║   sem ponto central de controle, sem single point          ║
  ║   of failure.                                              ║
  ║                                                            ║
  ║   Como email. Como a web. Como o IRC dos anos 2000.        ║
  ║   Mas com a tecnologia de 2026.                            ║
  ║                                                            ║
  ╚════════════════════════════════════════════════════════════╝
```
