# Retro Hex Chat — Camada de Administração e Comandos

## Documento de Modelagem Profunda

---

## I. Filosofia: Admin como Cidadão do Chat

A administração do Retro Hex Chat acontece DENTRO do chat, não em uma interface separada.
Assim como no IRC clássico, o poder vem de comandos. O admin não sai do contexto
de conversa para administrar — ele digita comandos no mesmo lugar onde conversa.

Isso significa:

    ┌─────────────────────────────────────────────────────────────┐
    │                                                             │
    │   NÃO QUEREMOS                    QUEREMOS                  │
    │                                                             │
    │   Dashboard React separado   →   Comandos inline no chat   │
    │   URL /admin com forms       →   /admin unlock → comandos  │
    │   Cliques em menus           →   Autocompletar inteligente │
    │   Contexto perdido           →   Admin VÊ o chat enquanto  │
    │                                   administra               │
    │                                                             │
    │   MAS TAMBÉM:                                               │
    │                                                             │
    │   Só terminal hostil         →   Painel visual OPCIONAL    │
    │   Sem feedback visual        →   Respostas ricas inline    │
    │   Decorar 200 comandos       →   Autocomplete + /help      │
    │                                                             │
    └─────────────────────────────────────────────────────────────┘

O modelo é DUAL: comandos IRC-style como interface primária, com um painel
visual (/admin) que é apenas uma camada de conveniência que executa os mesmos
comandos por baixo.

---

## II. Modelo de Permissões

### Papéis no Sistema

```
╔═══════════════════════════════════════════════════════════════════╗
║                    HIERARQUIA DE PAPÉIS                          ║
╠═══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  ROOT OWNER (1 único por servidor)                                ║
║  ├── Criou o servidor ou foi designado no config                 ║
║  ├── Não pode ser removido por ninguém                           ║
║  ├── Pode tudo, incluindo promover/demover admins                ║
║  └── Acesso ao /admin sem senha (autenticado pelo sistema)       ║
║      │                                                            ║
║      ▼                                                            ║
║  ADMIN (N por servidor)                                           ║
║  ├── Promovido pelo root owner ou outro admin                    ║
║  ├── Precisa fazer /admin <senha> para desbloquear               ║
║  ├── Gerencia: federação, usuários, canais, regras               ║
║  ├── NÃO pode: remover root owner, alterar config de sistema    ║
║  └── Pode ter permissões granulares (scoped admin)               ║
║      │                                                            ║
║      ▼                                                            ║
║  MODERATOR (N por servidor ou por canal)                          ║
║  ├── Promovido por admin ou root owner                           ║
║  ├── NÃO precisa de /admin — usa /mod commands                   ║
║  ├── Gerencia: kick, ban, mute, slow mode                        ║
║  ├── Escopo: servidor inteiro OU canais específicos              ║
║  └── NÃO pode: federar, alterar servidor, promover outros       ║
║      │                                                            ║
║      ▼                                                            ║
║  CHANNEL OWNER (1 por canal)                                      ║
║  ├── Criou o canal                                                ║
║  ├── Controle total sobre SEU canal                               ║
║  ├── Pode aceitar/rejeitar federação DO SEU canal                ║
║  ├── Promove ops e voices no canal                                ║
║  └── NÃO pode: administrar servidor ou outros canais             ║
║      │                                                            ║
║      ▼                                                            ║
║  CHANNEL OP (N por canal)                                         ║
║  ├── Promovido pelo channel owner                                ║
║  ├── Modera o canal: kick, ban, topic, modos                     ║
║  └── NÃO pode: federar o canal, deletar o canal                 ║
║      │                                                            ║
║      ▼                                                            ║
║  VOICE (N por canal)                                              ║
║  ├── Pode falar em canais moderados (+m)                          ║
║  └── Sem poder de moderação                                       ║
║      │                                                            ║
║      ▼                                                            ║
║  USER (todos os registrados)                                      ║
║  ├── Entra em canais, envia mensagens, DMs                        ║
║  └── Bloqueia usuários, reporta conteúdo                          ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
```

### Scoped Admins (Admins com Escopo Limitado)

Nem todo admin precisa ter acesso a tudo. O root owner pode criar admins
com permissões granulares:

```
  /admin grant @dave federation        ← só gerencia federação
  /admin grant @eve users              ← só gerencia usuários
  /admin grant @frank channels,users   ← canais E usuários
  /admin grant @grace *                ← admin completo

  ESCOPOS DISPONÍVEIS:
  ┌──────────────┬─────────────────────────────────────────────┐
  │ Escopo       │ Permite                                     │
  ├──────────────┼─────────────────────────────────────────────┤
  │ users        │ Gerenciar usuários (ban, roles, reset)      │
  │ channels     │ Gerenciar canais (criar, deletar, modos)    │
  │ federation   │ Gerenciar peers e links de federação        │
  │ moderation   │ Moderar conteúdo (reports, bans globais)    │
  │ server       │ Configurações do servidor (nome, regras)    │
  │ *            │ Tudo (admin completo)                       │
  └──────────────┴─────────────────────────────────────────────┘
```

---

## III. Fluxo de Autenticação Admin

### Desbloquear o Modo Admin

```
  ESTADO NORMAL: Alice está no chat como usuária comum
  ═══════════════════════════════════════════════════

  ┌──────────────────────────────────────────────────┐
  │  #general                                        │
  │                                                  │
  │  bob: alguém viu o jogo ontem?                   │
  │  carol: foi demais!                              │
  │  alice: concordo haha                            │
  │                                                  │
  │  [  /admin unlock                        ] [▶]   │
  └──────────────────────────────────────────────────┘

  Alice digita "/admin unlock" e tecla Enter.

  ┌──────────────────────────────────────────────────┐
  │  #general                                        │
  │                                                  │
  │  bob: alguém viu o jogo ontem?                   │
  │  carol: foi demais!                              │
  │  alice: concordo haha                            │
  │                                                  │
  │  ┌────────────────────────────────────────────┐  │
  │  │  🔒 ADMIN: Digite a senha de admin         │  │
  │  │  ┌──────────────────────────────────────┐  │  │
  │  │  │ ••••••••••••                         │  │  │
  │  │  └──────────────────────────────────────┘  │  │
  │  │  [Cancelar]              [Desbloquear]     │  │
  │  └────────────────────────────────────────────┘  │
  └──────────────────────────────────────────────────┘

  O input de senha aparece como modal inline — NÃO vai para outra
  tela. NÃO aparece no histórico do chat. NÃO é visível para outros.

  Após digitar a senha correta:

  ┌──────────────────────────────────────────────────┐
  │  #general                                        │
  │                                                  │
  │  bob: alguém viu o jogo ontem?                   │
  │  carol: foi demais!                              │
  │  alice: concordo haha                            │
  │                                                  │
  │  ⚙ Modo admin ativado. Expira em 30 min.        │
  │    Digite /admin help para ver comandos.         │
  │    Digite /admin lock para bloquear.             │
  │                                                  │
  │  [  /admin _                             ] [▶]   │
  └──────────────────────────────────────────────────┘

  IMPORTANTE: A mensagem do sistema é ephemeral — só Alice vê.
  Os outros usuários NÃO veem que ela desbloqueou o admin.
```

### Sessão Admin

```
  ┌────────────────────────────────────────────────────┐
  │                SESSÃO ADMIN                        │
  ├────────────────────────────────────────────────────┤
  │                                                    │
  │  Duração padrão: 30 minutos                        │
  │  Renovável: sim, com /admin renew                  │
  │  Timeout por inatividade: 10 minutos               │
  │  Bloqueio manual: /admin lock                      │
  │                                                    │
  │  Enquanto ativa:                                   │
  │  • Comandos /admin ficam disponíveis               │
  │  • Badge sutil no canto (só o admin vê)            │
  │  • Autocomplete mostra comandos admin              │
  │  • Chat continua funcionando normalmente           │
  │                                                    │
  │  Ao expirar:                                       │
  │  • Mensagem ephemeral: "Sessão admin expirou"      │
  │  • Comandos /admin param de funcionar              │
  │  • Precisa /admin unlock de novo                   │
  │                                                    │
  │  Log:                                              │
  │  • Toda ação admin é registrada em audit log       │
  │  • Timestamp, quem, o quê, resultado               │
  │  • Acessível via /admin log                        │
  │                                                    │
  └────────────────────────────────────────────────────┘
```

### Diagrama de Estados

```
                    ┌──────────┐
                    │  LOCKED  │ ◄──────────────────────┐
                    │ (normal) │                         │
                    └────┬─────┘                         │
                         │                               │
                    /admin unlock                   /admin lock
                         │                          OU timeout
                         ▼                          OU expiração
                ┌────────────────┐                      │
                │ PASSWORD_PROMPT│                       │
                │  (modal inline)│                       │
                └───┬────────┬──┘                       │
                    │        │                          │
               correto    errado                        │
                    │        │                          │
                    │        ▼                          │
                    │  ┌───────────┐                    │
                    │  │  LOCKED   │  (3 tentativas     │
                    │  │ +cooldown │   → cooldown 5min) │
                    │  └───────────┘                    │
                    │                                   │
                    ▼                                   │
              ┌──────────┐                              │
              │ UNLOCKED │──────────────────────────────┘
              │ (admin)  │
              │ TTL: 30m │
              └──────────┘
                    │
                    │ a cada ação:
                    │ renova inactivity timer
                    │
                    │ /admin renew:
                    │ renova TTL para +30 min
                    │
```

---

## IV. Catálogo Completo de Comandos

### Estrutura de Comando

```
  Todos os comandos seguem o padrão:

  /admin <categoria> <ação> [argumentos] [--flags]

  Exemplos:
    /admin server info
    /admin user ban @spammer --reason "spam" --duration 7d
    /admin federation peer list --status active
    /admin channel #elixir set topic "Bem-vindos!"
```

### Mapa Completo de Comandos

```
/admin
├── unlock                          Desbloquear modo admin
├── lock                            Bloquear modo admin
├── renew                           Renovar sessão (+30 min)
├── help [comando]                  Ajuda geral ou de um comando
├── log [--last N] [--user X]       Ver audit log
│
├── server/                         ═══ CONFIGURAÇÃO DO SERVIDOR ═══
│   ├── info                        Informações do servidor
│   ├── set name <nome>             Alterar nome de exibição
│   ├── set description <desc>      Alterar descrição
│   ├── set welcome <msg>           Mensagem de boas-vindas
│   ├── set rules <texto>           Regras do servidor
│   ├── set visibility <pub|priv|unl>  Visibilidade na rede
│   ├── set registration <open|invite|closed>  Modo de registro
│   ├── set max-users <N>           Limite de usuários
│   ├── set max-channels <N>        Limite de canais
│   ├── set password <nova-senha>   Alterar senha admin
│   ├── stats                       Estatísticas do servidor
│   ├── motd <texto>                Message of the day
│   ├── announce <msg>              Enviar anúncio para todos
│   └── shutdown [--delay Ns]       Desligar servidor (com aviso)
│
├── user/                           ═══ GESTÃO DE USUÁRIOS ═══
│   ├── list [--role X] [--search Q]  Listar usuários
│   ├── info @nick                  Detalhes de um usuário
│   ├── ban @nick [--reason R]      Banir do servidor
│   │        [--duration D]
│   ├── unban @nick                 Remover ban
│   ├── banlist [--search Q]        Ver lista de bans
│   ├── kick @nick [--reason R]     Desconectar usuário
│   ├── mute @nick [--duration D]   Silenciar globalmente
│   ├── unmute @nick                Remover silenciamento
│   ├── warn @nick <mensagem>       Enviar aviso oficial
│   ├── role @nick <role>           Alterar papel
│   │        (admin|mod|user)
│   ├── grant @nick <escopos>       Dar permissões de admin
│   ├── revoke @nick <escopos>      Remover permissões
│   ├── rename @nick <novo-nick>    Forçar troca de nick
│   ├── verify @nick                Marcar como verificado
│   ├── reset-password @nick        Forçar reset de senha
│   ├── sessions @nick              Ver sessões ativas
│   ├── kill-session @nick [--all]  Encerrar sessões
│   ├── invite <email>              Gerar convite
│   │        [--role R] [--channels C]
│   ├── invites [--status S]        Listar convites
│   └── revoke-invite <código>      Revogar convite
│
├── channel/                        ═══ GESTÃO DE CANAIS ═══
│   ├── list [--search Q]           Listar canais
│   │        [--federated] [--empty]
│   ├── info #canal                 Detalhes de um canal
│   ├── create #canal [--desc D]    Criar canal
│   ├── delete #canal [--confirm]   Deletar canal
│   ├── set #canal topic <texto>    Alterar topic
│   ├── set #canal desc <texto>     Alterar descrição
│   ├── set #canal visibility       Alterar visibilidade
│   │        <public|private|secret>
│   ├── set #canal slow <segundos>  Modo lento
│   ├── set #canal max-members <N>  Limite de membros
│   ├── mode #canal +m              Canal moderado
│   ├── mode #canal +i              Somente convite
│   ├── mode #canal +n              Sem mensagens externas
│   ├── mode #canal +s              Canal secreto
│   ├── mode #canal -m              Remover moderação
│   ├── op #canal @nick             Dar op no canal
│   ├── deop #canal @nick           Remover op
│   ├── voice #canal @nick          Dar voice
│   ├── devoice #canal @nick        Remover voice
│   ├── transfer #canal @nick       Transferir ownership
│   ├── kick #canal @nick [--reason]  Kick de canal
│   ├── ban #canal @nick [--reason] Ban de canal
│   │        [--duration D]
│   ├── unban #canal @nick          Remover ban de canal
│   ├── banlist #canal              Bans do canal
│   ├── purge #canal [--before D]   Limpar mensagens
│   │        [--from @nick]
│   └── freeze #canal               Impedir novas mensagens
│
├── federation/                     ═══ FEDERAÇÃO ═══
│   │
│   ├── status                      Status geral da federação
│   │
│   ├── peer/                       ─── GESTÃO DE PEERS ───
│   │   ├── list [--status S]       Listar peers conhecidos
│   │   ├── info <domain>           Detalhes de um peer
│   │   ├── add <domain>            Adicionar peer manualmente
│   │   ├── remove <domain>         Remover peer da lista
│   │   ├── trust <domain>          Marcar como confiável
│   │   │                             (auto-aceitar requests)
│   │   ├── untrust <domain>        Remover confiança
│   │   ├── suspend <domain>        Suspender peer
│   │   │        [--reason R]         (bloqueia tudo)
│   │   ├── unsuspend <domain>      Reativar peer
│   │   ├── refresh <domain>        Forçar re-fetch de info
│   │   └── ping <domain>           Testar conectividade
│   │
│   ├── link/                       ─── LINKS DE CANAL ───
│   │   ├── list [--channel C]      Listar links ativos
│   │   │        [--peer P]
│   │   ├── info <link-id>          Detalhes de um link
│   │   ├── request #canal          Solicitar federação
│   │   │        <domain> [#remoto]
│   │   │        [--direction D]
│   │   │        [--message M]
│   │   ├── accept <link-id>        Aceitar solicitação
│   │   │        [--direction D]
│   │   ├── reject <link-id>        Rejeitar solicitação
│   │   │        [--reason R]
│   │   ├── pending                 Listar pendentes
│   │   ├── pause <link-id>         Pausar link
│   │   ├── resume <link-id>        Retomar link
│   │   ├── config <link-id>        Ver config do link
│   │   ├── config <link-id> set    Alterar config
│   │   │        <chave> <valor>
│   │   ├── sync <link-id>          Forçar sync agora
│   │   │        [--since DATE]
│   │   └── destroy <link-id>       Desfederar
│   │            [--confirm]          (remove link e dados)
│   │
│   ├── allowlist/                  ─── CONTROLE DE ACESSO ───
│   │   ├── show                    Ver lista atual
│   │   ├── add <domain>            Adicionar à allowlist
│   │   ├── remove <domain>         Remover da allowlist
│   │   └── mode <open|allow|block> Mudar modo de federação
│   │
│   ├── blocklist/                  ─── BLOQUEIO ───
│   │   ├── show                    Ver lista atual
│   │   ├── add <domain> [--reason] Bloquear servidor
│   │   └── remove <domain>         Desbloquear servidor
│   │
│   ├── discovery/                  ─── DISCOVERY ───
│   │   ├── status                  Status do discovery
│   │   ├── seeds                   Ver seeds configurados
│   │   ├── seed add <domain>       Adicionar seed
│   │   ├── seed remove <domain>    Remover seed
│   │   ├── gossip now              Forçar rodada de gossip
│   │   └── health                  Relatório de saúde
│   │
│   └── log/                        ─── LOG DE FEDERAÇÃO ───
│       ├── show [--peer P]         Ver log de atividades S2S
│       │        [--type T] [--last N]
│       ├── errors [--last N]       Ver erros de delivery
│       └── stats [--peer P]        Estatísticas de tráfego
│
├── mod/                            ═══ MODERAÇÃO ═══
│   ├── reports                     Ver reports pendentes
│   │        [--status S]
│   ├── report info <id>            Detalhes de um report
│   ├── report resolve <id>         Resolver report
│   │        <action> [--note N]
│   ├── report dismiss <id>         Descartar report
│   │        [--note N]
│   ├── report forward <id>         Encaminhar para peer
│   │        <domain>
│   ├── queue                       Fila de moderação
│   ├── filter add <padrão>         Adicionar filtro de conteúdo
│   │        [--action A]
│   ├── filter list                 Listar filtros
│   ├── filter remove <id>          Remover filtro
│   ├── antispam [on|off|status]    Controle de antispam
│   └── ratelimit <contexto>        Configurar rate limits
│            <valor>
│
└── debug/                          ═══ DIAGNÓSTICO ═══
    ├── connections                  Conexões WebSocket ativas
    ├── processes                    GenServers de canais ativos
    ├── memory                      Uso de memória
    ├── queues                      Status das filas Oban
    ├── pubsub                      Tópicos PubSub ativos
    └── cluster                     Status do cluster BEAM
```

---

## V. Detalhamento dos Comandos de Federação

Os comandos de federação são os mais críticos e complexos. Vamos detalhar
cada fluxo.

### /admin federation peer add

```
  CENÁRIO: Admin quer adicionar manualmente um peer que não
  foi descoberto via gossip.

  ┌─────────────────────────────────────────────────────────┐
  │                                                         │
  │  alice: /admin federation peer add nova.community       │
  │                                                         │
  │  ⚙ Buscando informações de nova.community...           │
  │                                                         │
  │  ⚙ Servidor encontrado:                                │
  │    Nome: Nova Community                                 │
  │    Descrição: Comunidade Nova de Tecnologia             │
  │    Versão: Retro Hex Chat 0.3.0                                  │
  │    Visibilidade: público                                │
  │    Usuários ativos: 234                                 │
  │    Canais públicos: 15                                  │
  │    Capabilities: channel_federation, user_federation,   │
  │                  message_sync, reactions, threads        │
  │                                                         │
  │  ⚙ Peer adicionado com status: discovered              │
  │    Para federar canais: /admin federation link request   │
  │                                                         │
  └─────────────────────────────────────────────────────────┘


  CENÁRIO: Servidor não encontrado

  ┌─────────────────────────────────────────────────────────┐
  │                                                         │
  │  alice: /admin federation peer add inexiste.xyz         │
  │                                                         │
  │  ⚙ Buscando informações de inexiste.xyz...             │
  │  ✗ Erro: Não foi possível conectar a inexiste.xyz      │
  │    - Verifique se o domínio está correto                │
  │    - O servidor pode estar offline                      │
  │    - O servidor pode não ter Retro Hex Chat instalado            │
  │                                                         │
  │    Use /admin federation peer ping inexiste.xyz         │
  │    para testar conectividade.                           │
  │                                                         │
  └─────────────────────────────────────────────────────────┘
```

### /admin federation link request

```
  CENÁRIO: Admin quer federar #elixir com outro servidor.

  ┌─────────────────────────────────────────────────────────┐
  │                                                         │
  │  alice: /admin federation link request #elixir          │
  │         beta.chat                                       │
  │                                                         │
  │  ⚙ Buscando canais públicos de beta.chat...            │
  │                                                         │
  │  ⚙ Canais disponíveis em beta.chat:                    │
  │    #elixir     (142 membros, "Tudo sobre Elixir")       │
  │    #phoenix    (89 membros, "Phoenix Framework")        │
  │    #nerves     (34 membros, "IoT com Elixir")           │
  │    #general    (201 membros, "Conversa geral")          │
  │                                                         │
  │  ⚙ Vincular #elixir local com qual canal remoto?       │
  │    [1] #elixir@beta.chat (sugerido: mesmo nome)         │
  │    [2] Outro canal (digitar nome)                       │
  │    [3] Cancelar                                         │
  │                                                         │
  └─────────────────────────────────────────────────────────┘

  Alice seleciona [1]:

  ┌─────────────────────────────────────────────────────────┐
  │                                                         │
  │  ⚙ Configuração do link:                               │
  │                                                         │
  │    Direção:                                             │
  │    [1] ↔ Bidirecional (recomendado)                     │
  │    [2] ← Só receber                                     │
  │    [3] → Só enviar                                      │
  │                                                         │
  └─────────────────────────────────────────────────────────┘

  Alice seleciona [1]:

  ┌─────────────────────────────────────────────────────────┐
  │                                                         │
  │  ⚙ O que sincronizar?                                  │
  │    [M] Mensagens         ✓ (obrigatório)                │
  │    [T] Topic             (s/N): s                       │
  │    [R] Reações           (s/N): s                       │
  │    [E] Lista de membros  (s/N): n                       │
  │    [D] Moderação         (s/N): n                       │
  │                                                         │
  │  ⚙ Histórico: sincronizar últimos quantos dias? [30]:  │
  │                                                         │
  │  ⚙ Mensagem para o admin de beta.chat (opcional):      │
  │    > Olá! Gostaríamos de federar nosso #elixir.         │
  │                                                         │
  └─────────────────────────────────────────────────────────┘

  Confirmação:

  ┌─────────────────────────────────────────────────────────┐
  │                                                         │
  │  ⚙ RESUMO DA SOLICITAÇÃO:                              │
  │  ┌───────────────────────────────────────────────────┐  │
  │  │  Local:    #elixir@alpha.chat                     │  │
  │  │  Remoto:   #elixir@beta.chat                      │  │
  │  │  Direção:  ↔ Bidirecional                         │  │
  │  │  Sync:     mensagens, topic, reações              │  │
  │  │  Histórico: 30 dias                               │  │
  │  └───────────────────────────────────────────────────┘  │
  │                                                         │
  │  Confirmar? (s/n): s                                    │
  │                                                         │
  │  ✓ Solicitação enviada para beta.chat                   │
  │    Status: pending_sent                                 │
  │    Link ID: fed_link_7a3b2c                             │
  │    O admin de beta.chat precisa aceitar.                │
  │                                                         │
  └─────────────────────────────────────────────────────────┘
```

### /admin federation link accept / reject

```
  CENÁRIO: Beta.chat recebeu solicitação de alpha.chat

  O admin de beta recebe uma NOTIFICAÇÃO (ephemeral) ao entrar
  no modo admin:

  ┌─────────────────────────────────────────────────────────┐
  │                                                         │
  │  ⚙ 2 solicitações de federação pendentes.              │
  │    Use /admin federation link pending para ver.         │
  │                                                         │
  └─────────────────────────────────────────────────────────┘

  bob: /admin federation link pending

  ┌─────────────────────────────────────────────────────────┐
  │                                                         │
  │  ⚙ SOLICITAÇÕES PENDENTES:                             │
  │                                                         │
  │  [1] fed_link_7a3b2c  (há 2 horas)                     │
  │      De: alpha.chat                                     │
  │      Canal deles: #elixir → Canal nosso: #elixir        │
  │      Direção: ↔ Bidirecional                            │
  │      Sync: mensagens, topic, reações                    │
  │      Msg: "Olá! Gostaríamos de federar nosso #elixir."  │
  │                                                         │
  │  [2] fed_link_9d4e1f  (há 5 horas)                     │
  │      De: gamma.community                                │
  │      Canal deles: #programacao → Canal nosso: #general   │
  │      Direção: ← Só enviar para nós                      │
  │      Sync: apenas mensagens                             │
  │      Msg: (nenhuma)                                     │
  │                                                         │
  │  Ações:                                                 │
  │    /admin federation link accept <id>                   │
  │    /admin federation link reject <id> [--reason R]      │
  │    /admin federation peer info <domain>                 │
  │                                                         │
  └─────────────────────────────────────────────────────────┘

  bob: /admin federation link accept fed_link_7a3b2c

  ┌─────────────────────────────────────────────────────────┐
  │                                                         │
  │  ✓ Federação aceita!                                    │
  │                                                         │
  │    #elixir@beta.chat ↔ #elixir@alpha.chat               │
  │    Status: active                                       │
  │    Sync iniciado: baixando últimos 30 dias...           │
  │                                                         │
  │  ⚙ Sync: 127/500 mensagens importadas...               │
  │  ⚙ Sync: 389/500 mensagens importadas...               │
  │  ✓ Sync completo: 500 mensagens importadas.            │
  │                                                         │
  └─────────────────────────────────────────────────────────┘

  bob: /admin federation link reject fed_link_9d4e1f
       --reason "Canais incompatíveis"

  ┌─────────────────────────────────────────────────────────┐
  │                                                         │
  │  ✓ Solicitação rejeitada.                               │
  │    Motivo enviado para gamma.community:                 │
  │    "Canais incompatíveis"                               │
  │                                                         │
  └─────────────────────────────────────────────────────────┘
```

### /admin federation peer suspend

```
  CENÁRIO: Um servidor está enviando spam. Admin quer bloquear tudo.

  alice: /admin federation peer suspend spam.server
         --reason "Spam massivo em canais federados"

  ┌─────────────────────────────────────────────────────────┐
  │                                                         │
  │  ⚠ SUSPENDER spam.server                               │
  │                                                         │
  │  Isso irá:                                              │
  │  • Pausar 3 links de federação ativos                   │
  │  • Bloquear todas as mensagens de entrada               │
  │  • Parar de entregar mensagens para esse peer           │
  │  • Manter dados existentes (não deleta)                 │
  │                                                         │
  │  Links afetados:                                        │
  │  • #crypto@alpha.chat ↔ #crypto@spam.server             │
  │  • #trading@alpha.chat ↔ #trading@spam.server           │
  │  • #general@alpha.chat ↔ #general@spam.server           │
  │                                                         │
  │  Confirmar suspensão? (s/n): s                          │
  │                                                         │
  │  ✓ spam.server suspenso.                                │
  │    3 links pausados.                                    │
  │    Motivo registrado no log.                            │
  │                                                         │
  │    Para reativar: /admin federation peer unsuspend       │
  │    Para remover dados: /admin federation link destroy    │
  │                                                         │
  └─────────────────────────────────────────────────────────┘
```

---

## VI. Autocomplete e Ajuda Contextual

### Autocomplete Progressivo

O autocomplete funciona em cascata. A cada espaço digitado, as opções
se refinam:

```
  DIGITOU              AUTOCOMPLETE MOSTRA
  ────────             ──────────────────────────────────────

  /ad                  /admin

  /admin               unlock | lock | renew | help | log
                       server | user | channel | federation
                       mod | debug

  /admin f             federation

  /admin federation    peer | link | allowlist | blocklist
                       discovery | log | status

  /admin federation p  peer

  /admin federation peer
                       list | info | add | remove | trust
                       untrust | suspend | unsuspend
                       refresh | ping

  /admin federation peer s
                       suspend | ...

  /admin federation peer suspend
                       <tab>: lista peers conhecidos
                       alpha.chat | beta.chat | gamma.community

  /admin federation peer suspend beta.chat
                       --reason | --confirm
```

### Visualização do Autocomplete

```
  ┌────────────────────────────────────────────────────────┐
  │  #general                                              │
  │                                                        │
  │  (conversa normal acima)                               │
  │                                                        │
  │  ┌──────────────────────────────────────────────────┐  │
  │  │ federation  peer  link  allowlist  blocklist     │  │
  │  │ discovery   log   status                         │  │
  │  └──────────────────────────────────────────────────┘  │
  │  [  /admin _                                   ] [▶]   │
  └────────────────────────────────────────────────────────┘

  Após digitar "peer":

  ┌────────────────────────────────────────────────────────┐
  │  ┌──────────────────────────────────────────────────┐  │
  │  │ list  info  add  remove  trust  untrust          │  │
  │  │ suspend  unsuspend  refresh  ping                │  │
  │  └──────────────────────────────────────────────────┘  │
  │  [  /admin federation peer _                   ] [▶]   │
  └────────────────────────────────────────────────────────┘

  Após digitar "info":

  ┌────────────────────────────────────────────────────────┐
  │  ┌──────────────────────────────────────────────────┐  │
  │  │ 🟢 beta.chat    🟢 gamma.community              │  │
  │  │ 🟡 epsilon.org  🔴 omega.net                     │  │
  │  └──────────────────────────────────────────────────┘  │
  │  [  /admin federation peer info _              ] [▶]   │
  └────────────────────────────────────────────────────────┘
```

### /admin help

```
  alice: /admin help

  ┌─────────────────────────────────────────────────────────┐
  │                                                         │
  │  ⚙ COMANDOS DE ADMINISTRAÇÃO RETRO HEX CHAT                     │
  │  ══════════════════════════════════                     │
  │                                                         │
  │  Sessão:                                                │
  │    /admin unlock          Ativar modo admin             │
  │    /admin lock            Desativar modo admin          │
  │    /admin renew           Renovar sessão (+30min)       │
  │                                                         │
  │  Categorias:                                            │
  │    /admin server ...      Configuração do servidor      │
  │    /admin user ...        Gestão de usuários            │
  │    /admin channel ...     Gestão de canais              │
  │    /admin federation ...  Federação com outros servers  │
  │    /admin mod ...         Moderação e reports           │
  │    /admin debug ...       Diagnóstico do sistema        │
  │                                                         │
  │  Para ajuda de um comando específico:                   │
  │    /admin help <comando>                                │
  │    Exemplo: /admin help federation link request         │
  │                                                         │
  │  Sua sessão expira em: 24 minutos                       │
  │  Seus escopos: * (admin completo)                       │
  │                                                         │
  └─────────────────────────────────────────────────────────┘


  alice: /admin help federation link request

  ┌─────────────────────────────────────────────────────────┐
  │                                                         │
  │  ⚙ /admin federation link request                      │
  │  ─────────────────────────────────                      │
  │                                                         │
  │  Solicita federação de um canal local com um canal      │
  │  em outro servidor. O admin do servidor remoto          │
  │  precisará aceitar a solicitação.                       │
  │                                                         │
  │  Uso:                                                   │
  │    /admin federation link request #canal-local          │
  │      <servidor-remoto> [#canal-remoto]                  │
  │      [--direction <both|in|out>]                        │
  │      [--message "texto"]                                │
  │                                                         │
  │  Argumentos:                                            │
  │    #canal-local     Canal neste servidor                │
  │    <servidor>       Domínio do servidor remoto          │
  │    #canal-remoto    Canal no servidor remoto            │
  │                     (padrão: mesmo nome do local)       │
  │                                                         │
  │  Flags:                                                 │
  │    --direction      both (padrão), in, ou out           │
  │    --message        Mensagem para o admin remoto        │
  │                                                         │
  │  Exemplos:                                              │
  │    /admin federation link request #elixir beta.chat     │
  │    /admin federation link request #dev beta.chat #devs  │
  │    /admin federation link request #news beta.chat       │
  │      --direction out --message "Só enviaremos posts"    │
  │                                                         │
  │  Requer escopo: federation                              │
  │                                                         │
  └─────────────────────────────────────────────────────────┘
```

---

## VII. Painel Visual (/admin dashboard)

Além dos comandos inline, existe um painel visual acessível pelo mesmo
sistema de unlock. Ele é uma LiveView que aparece em uma área lateral
ou em tela cheia, dependendo da escolha do admin.

### /admin dashboard

```
  alice: /admin dashboard

  (Abre o painel visual na lateral ou em tela cheia)

  ┌────────────────────────────────────────────────────────────────┐
  │  ⚙ ADMIN DASHBOARD — alpha.chat                  [X fechar]  │
  ├────────┬───────────────────────────────────────────────────────┤
  │        │                                                      │
  │ MENU   │  VISÃO GERAL                                         │
  │ ────── │  ════════════                                        │
  │        │                                                      │
  │►Visão  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────┐ │
  │ geral  │  │ 👥 1.523 │ │ 📢 87   │ │ 🔗 23   │ │ 🟢 42 │ │
  │        │  │ usuários │ │ canais   │ │ links    │ │ peers  │ │
  │ Usuá-  │  │ 342 on   │ │ 12 ativ. │ │ 6 ativos │ │ 3 off  │ │
  │ rios   │  └──────────┘ └──────────┘ └──────────┘ └────────┘ │
  │        │                                                      │
  │ Canais │  PENDÊNCIAS                                          │
  │        │  ──────────                                          │
  │ Feder- │  ⚠ 2 solicitações de federação pendentes            │
  │ ação   │  ⚠ 5 reports de moderação não resolvidos             │
  │        │  ⚠ 1 peer unreachable há mais de 24h                │
  │ Moder- │                                                      │
  │ ação   │  ATIVIDADE RECENTE                                   │
  │        │  ──────────────────                                  │
  │ Logs   │  10:30  @dave entrou via convite de @alice           │
  │        │  10:15  Link #elixir↔beta.chat: sync OK (23 msgs)   │
  │ Config │  09:45  @eve criou canal #rust                       │
  │        │  09:30  Peer gamma.community: health check OK        │
  │ Diag-  │  09:00  @spammer22 banido por filtro antispam        │
  │ nóst.  │  08:30  Link #go↔delta.org pausado (peer offline)   │
  │        │                                                      │
  │        │  SAÚDE DA FEDERAÇÃO                                  │
  │        │  ──────────────────                                  │
  │        │  Msgs enviadas (24h):     1.247                      │
  │        │  Msgs recebidas (24h):    2.891                      │
  │        │  Falhas de delivery (24h):   12 (0.4%)               │
  │        │  Latência média S2S:       340ms                     │
  │        │                                                      │
  └────────┴──────────────────────────────────────────────────────┘
```

### Aba de Federação no Dashboard

```
  ┌────────────────────────────────────────────────────────────────┐
  │  ⚙ ADMIN DASHBOARD — alpha.chat                  [X fechar]  │
  ├────────┬───────────────────────────────────────────────────────┤
  │        │                                                      │
  │ MENU   │  FEDERAÇÃO                                           │
  │ ────── │  ══════════                                          │
  │        │                                                      │
  │ Visão  │  Modo: [● Aberto ○ Allowlist ○ Blocklist]  [Salvar] │
  │ geral  │  Aprovação manual: [✓]                               │
  │        │                                                      │
  │ Usuá-  │  ┌─── TABS ──────────────────────────────────────┐   │
  │ rios   │  │ [Peers] [Links] [Pendentes] [Bloqueados]      │   │
  │        │  └────────────────────────────────────────────────┘   │
  │ Canais │                                                      │
  │        │  PEERS CONHECIDOS                                    │
  │►Feder- │  ──────────────────                                  │
  │ ação   │  [🔍 Filtrar...                                  ]   │
  │        │                                                      │
  │ Moder- │  ┌────────────────────────────────────────────────┐  │
  │ ação   │  │ 🟢 beta.chat          342 usr  3 links  ★     │  │
  │        │  │    "Comunidade BR de Elixir"                   │  │
  │ Logs   │  │    [Info] [Suspender] [Desfederar tudo]        │  │
  │        │  ├────────────────────────────────────────────────┤  │
  │ Config │  │ 🟢 gamma.community    1.2k usr  2 links       │  │
  │        │  │    "Open Source & Linux"                        │  │
  │ Diag-  │  │    [Info] [Suspender] [Desfederar tudo]        │  │
  │ nóst.  │  ├────────────────────────────────────────────────┤  │
  │        │  │ 🟡 epsilon.org        89 usr   1 link   2h    │  │
  │        │  │    "Hackerspace SP"                             │  │
  │        │  │    [Info] [Suspender] [Desfederar tudo]        │  │
  │        │  ├────────────────────────────────────────────────┤  │
  │        │  │ 🔴 omega.net          ??? usr  0 links  3d    │  │
  │        │  │    unreachable desde 09/02                      │  │
  │        │  │    [Info] [Remover]                             │  │
  │        │  ├────────────────────────────────────────────────┤  │
  │        │  │ ⛔ spam.server        SUSPENSO                 │  │
  │        │  │    Motivo: "Spam massivo"                      │  │
  │        │  │    [Info] [Reativar]                            │  │
  │        │  └────────────────────────────────────────────────┘  │
  │        │                                                      │
  │        │  ★ = confiável (auto-aceita requests)                │
  │        │                                                      │
  │        │  [+ Adicionar peer]  [+ Solicitar federação]         │
  │        │                                                      │
  └────────┴──────────────────────────────────────────────────────┘
```

### Aba de Moderação no Dashboard

```
  ┌────────────────────────────────────────────────────────────────┐
  │  ⚙ ADMIN DASHBOARD — alpha.chat                  [X fechar]  │
  ├────────┬───────────────────────────────────────────────────────┤
  │        │                                                      │
  │ MENU   │  MODERAÇÃO                                           │
  │ ────── │  ══════════                                          │
  │        │                                                      │
  │ Visão  │  ┌─── TABS ──────────────────────────────────────┐   │
  │ geral  │  │ [Reports (5)] [Bans] [Filtros] [Antispam]     │   │
  │        │  └────────────────────────────────────────────────┘   │
  │ Usuá-  │                                                      │
  │ rios   │  REPORTS PENDENTES                                   │
  │        │  ─────────────────                                   │
  │ Canais │                                                      │
  │        │  ┌────────────────────────────────────────────────┐  │
  │►Moder- │  │ #RPT-001  ⏰ há 30 min                        │  │
  │ ação   │  │ Reportado: @troll42@gamma.community            │  │
  │        │  │ Por: @alice (local)                             │  │
  │ Feder- │  │ Canal: #elixir                                  │  │
  │ ação   │  │ Motivo: "Mensagens ofensivas repetidas"         │  │
  │        │  │ Mensagem: "vocês são todos burros lol lol"      │  │
  │ Logs   │  │                                                  │  │
  │        │  │ Ações:                                          │  │
  │ Config │  │  [Ban do canal] [Ban do servidor]               │  │
  │        │  │  [Mute 24h] [Warn] [Descartar]                 │  │
  │ Diag-  │  │  [Encaminhar para gamma.community]              │  │
  │ nóst.  │  └────────────────────────────────────────────────┘  │
  │        │                                                      │
  │        │  ┌────────────────────────────────────────────────┐  │
  │        │  │ #RPT-002  ⏰ há 2h                             │  │
  │        │  │ Reportado: @scammer99@omega.net                 │  │
  │        │  │ Por: @bob (local)                               │  │
  │        │  │ Canal: #trading                                  │  │
  │        │  │ Motivo: "Spam de links suspeitos"                │  │
  │        │  │ Mensagem: "BUY CRYPTO NOW http://scam.link"     │  │
  │        │  │                                                  │  │
  │        │  │ ⚠ omega.net está unreachable — forward           │  │
  │        │  │   não será possível.                             │  │
  │        │  │                                                  │  │
  │        │  │ Ações:                                          │  │
  │        │  │  [Ban do canal] [Ban do servidor]               │  │
  │        │  │  [Suspender omega.net] [Descartar]              │  │
  │        │  └────────────────────────────────────────────────┘  │
  │        │                                                      │
  │        │  ... mais 3 reports                                  │
  │        │                                                      │
  └────────┴──────────────────────────────────────────────────────┘
```

---

## VIII. Comandos de Usuário (Não-Admin)

Além dos comandos /admin, existem comandos para TODOS os usuários:

```
/                               ═══ COMANDOS GERAIS ═══
├── /help                       Lista de comandos
├── /help <comando>             Ajuda de um comando
│
├── /nick <novo-nick>           Mudar apelido
├── /me <ação>                  Ação em terceira pessoa
├── /status <away|online|dnd>   Alterar status
├── /status <mensagem>          Status personalizado
├── /whois @nick                Informações de usuário
├── /whois @nick@domínio        Informações de user remoto
│
├── /join #canal                Entrar em canal local
├── /join #canal@domínio        Entrar em canal federado
├── /part [#canal]              Sair do canal
├── /list [filtro]              Listar canais
├── /list --federated           Listar canais de outros servers
│
├── /msg @nick <texto>          Mensagem direta
├── /msg @nick@dom <texto>      DM para user remoto
├── /reply <texto>              Responder última DM
│
├── /topic [texto]              Ver ou mudar topic (se op)
├── /invite @nick [#canal]      Convidar para canal
│
├── /follow @nick@domínio       Seguir usuário
├── /unfollow @nick@domínio     Deixar de seguir
├── /followers                  Ver seguidores
├── /following                  Ver quem segue
├── /feed                       Ver feed de atividade
│
├── /block @nick                Bloquear usuário
├── /block @nick@domínio        Bloquear user remoto
├── /block domain.com           Silenciar servidor inteiro
├── /unblock <alvo>             Desbloquear
├── /blocklist                  Ver bloqueios
│
├── /report @nick <motivo>      Denunciar usuário
├── /report #canal <motivo>     Denunciar canal
│
├── /search <termo>             Buscar mensagens
├── /search --channel #c <t>    Buscar em canal específico
│
├── /settings                   Abrir configurações
├── /notifications              Configurar notificações
│
└── /clear                      Limpar tela
```

### Comandos de Op (Dono/Operador de Canal)

```
/                               ═══ COMANDOS DE OP ═══
│                               (só em canais onde é op)
│
├── /kick @nick [motivo]        Expulsar do canal
├── /ban @nick [motivo]         Banir do canal
├── /unban @nick                Remover ban
├── /mute @nick [duração]       Silenciar
├── /unmute @nick               Remover silenciamento
├── /slow [segundos]            Modo lento (0 = desligar)
│
├── /op @nick                   Dar op
├── /deop @nick                 Remover op
├── /voice @nick                Dar voice
├── /devoice @nick              Remover voice
│
├── /mode +m                    Canal moderado
├── /mode +i                    Somente convite
├── /mode +n                    Sem mensagens externas
├── /mode -m                    Remover moderação
│
├── /channel set topic <t>      Mudar topic
├── /channel set desc <t>       Mudar descrição
├── /channel set slow <N>       Configurar slow mode
│
├── /channel federate           Solicitar federação
│        <domínio> [#canal]       (abre wizard interativo)
├── /channel defederate         Desfazer federação
│        <link-id>
├── /channel federation         Ver links do canal
│
└── /channel transfer @nick     Transferir ownership
```

---

## IX. Comandos de Moderador de Servidor

```
/mod                            ═══ COMANDOS DE MODERADOR ═══
│                               (não precisa de /admin unlock)
│
├── /mod reports                Ver reports pendentes
├── /mod report <id>            Detalhes de report
├── /mod resolve <id> <ação>    Resolver report
├── /mod dismiss <id>           Descartar report
│
├── /mod ban @nick [motivo]     Ban global (todo o servidor)
│        [--duration D]
├── /mod unban @nick            Remover ban global
├── /mod mute @nick [duração]   Mute global
├── /mod unmute @nick           Remover mute global
├── /mod warn @nick <msg>       Aviso oficial
│
├── /mod kick @nick [motivo]    Desconectar do servidor
├── /mod history @nick          Ver histórico de moderação
│
└── /mod queue                  Fila de itens para moderar
```

---

## X. Sistema de Notificações Admin

### Notificações que o Admin Recebe Automaticamente

```
  Quando o admin faz /admin unlock, ele recebe um resumo:

  ┌─────────────────────────────────────────────────────────┐
  │                                                         │
  │  ⚙ Modo admin ativado. Resumo:                         │
  │                                                         │
  │  ⚠ Pendências:                                         │
  │    • 2 solicitações de federação aguardando             │
  │    • 5 reports de moderação                             │
  │    • 1 peer unreachable (omega.net, 3 dias)             │
  │                                                         │
  │  📊 Desde seu último acesso (há 6h):                    │
  │    • 3.241 mensagens no servidor                        │
  │    • 847 mensagens federadas (in/out)                   │
  │    • 12 novos usuários registrados                      │
  │    • 0 falhas críticas de federação                     │
  │                                                         │
  │  Sessão expira em 30 minutos.                           │
  │                                                         │
  └─────────────────────────────────────────────────────────┘
```

### Notificações em Tempo Real (Durante Sessão Admin)

Enquanto o modo admin está ativo, o admin recebe notificações
ephemeral inline sobre eventos importantes:

```
  ┌─────────────────────────────────────────────────────────┐
  │  #general                                               │
  │                                                         │
  │  (conversa normal)                                      │
  │                                                         │
  │  ──── notificação admin (só você vê) ──────────────     │
  │  🔔 Nova solicitação de federação de sigma.chat         │
  │     #rust → #rust | Bidirecional                        │
  │     /admin federation link pending                      │
  │  ──────────────────────────────────────────────────     │
  │                                                         │
  │  bob: alguém quer jogar mais tarde?                     │
  │                                                         │
  │  ──── notificação admin (só você vê) ──────────────     │
  │  🔔 Novo report: @troll@gamma.community em #elixir      │
  │     Motivo: "Spam"                                      │
  │     /admin mod reports                                  │
  │  ──────────────────────────────────────────────────     │
  │                                                         │
  │  carol: quero!                                          │
  │                                                         │
  │  [  /admin _                                    ] [▶]   │
  └─────────────────────────────────────────────────────────┘

  As notificações admin são:
  • Ephemeral: só o admin vê
  • Inline: aparecem no fluxo do chat
  • Acionáveis: incluem o comando para resolver
  • Empilháveis: não interrompem a conversa
  • Descartáveis: sumem ao scrollar ou fechar admin
```

---

## XI. Audit Log

### Tudo é Registrado

Cada ação admin gera uma entrada no audit log:

```
  alice: /admin log --last 10

  ┌─────────────────────────────────────────────────────────┐
  │                                                         │
  │  ⚙ AUDIT LOG (últimas 10 ações)                        │
  │                                                         │
  │  10:45 @alice  federation link accept fed_link_7a3b2c   │
  │         → #elixir ↔ #elixir@beta.chat ACTIVE           │
  │                                                         │
  │  10:30 @alice  admin unlock (sessão iniciada)           │
  │                                                         │
  │  09:15 @alice  user ban @spammer22                      │
  │         → reason: "spam" duration: permanent            │
  │                                                         │
  │  09:10 @alice  mod resolve #RPT-003                     │
  │         → action: ban, note: "reincidente"              │
  │                                                         │
  │  08:00 @bob    channel #rust set topic "Rust lang"      │
  │         → (channel op, não admin)                       │
  │                                                         │
  │  07:30 SYSTEM  peer omega.net status → unreachable      │
  │         → failure_count: 4                              │
  │                                                         │
  │  07:00 SYSTEM  federation delivery failed               │
  │         → peer: omega.net, retry: 5/10                  │
  │                                                         │
  │  06:45 @alice  admin lock (sessão encerrada)            │
  │                                                         │
  │  06:30 @alice  server set motd "Bem-vindos ao alpha!"   │
  │                                                         │
  │  06:00 SYSTEM  gossip round: 3 novos peers descobertos  │
  │         → tau.org, upsilon.chat, phi.community          │
  │                                                         │
  │  Filtros:                                               │
  │    /admin log --user @alice                             │
  │    /admin log --type federation                         │
  │    /admin log --last 50                                 │
  │    /admin log --since "2026-02-10"                      │
  │                                                         │
  └─────────────────────────────────────────────────────────┘
```

### Estrutura do Log Entry

```
┌────────────────────────────────┐
│  AUDIT LOG ENTRY               │
├────────────────────────────────┤
│ id                             │
│ timestamp                      │
│ actor_type  (admin|mod|system) │
│ actor_id    (user_id ou nil)   │
│ action      (verbo completo)   │
│ target_type (user|channel|     │
│              peer|link|server) │
│ target_id                      │
│ details     (JSON livre)       │
│ ip_address                     │
│ session_id                     │
│ result      (ok|error)         │
│ error_detail                   │
└────────────────────────────────┘
```

---

## XII. Configuração Inicial do Servidor (Setup Wizard)

Quando o servidor sobe pela PRIMEIRA VEZ, antes de qualquer coisa,
o primeiro usuário a se registrar passa por um wizard:

```
  ┌─────────────────────────────────────────────────────────┐
  │                                                         │
  │  ╔═══════════════════════════════════════════════════╗   │
  │  ║       BEM-VINDO AO RETRO HEX CHAT — SETUP INICIAL         ║   │
  │  ╚═══════════════════════════════════════════════════╝   │
  │                                                         │
  │  Este é o primeiro acesso. Vamos configurar o servidor. │
  │                                                         │
  │  ─── PASSO 1/5: SUA CONTA (ROOT OWNER) ───             │
  │                                                         │
  │  Nickname: [________________]                           │
  │  Email:    [________________]                           │
  │  Senha:    [________________]                           │
  │                                                         │
  │  Você será o Root Owner deste servidor.                 │
  │  Esse papel não pode ser removido.                      │
  │                                                         │
  │                                         [Próximo ►]     │
  │                                                         │
  └─────────────────────────────────────────────────────────┘

  ┌─────────────────────────────────────────────────────────┐
  │                                                         │
  │  ─── PASSO 2/5: IDENTIDADE DO SERVIDOR ───              │
  │                                                         │
  │  Nome do servidor:  [Alpha Chat              ]          │
  │  Descrição:         [Comunidade de Elixir    ]          │
  │  Domínio:           alpha.chat (detectado)              │
  │                                                         │
  │                                         [Próximo ►]     │
  │                                                         │
  └─────────────────────────────────────────────────────────┘

  ┌─────────────────────────────────────────────────────────┐
  │                                                         │
  │  ─── PASSO 3/5: VISIBILIDADE ───                        │
  │                                                         │
  │  Tipo de servidor:                                      │
  │    (●) Público — visível no diretório, aberto a todos   │
  │    ( ) Unlisted — não aparece no diretório, mas aceita  │
  │    ( ) Privado — só aceita peers da allowlist            │
  │                                                         │
  │  Registro de novos usuários:                            │
  │    (●) Aberto — qualquer pessoa pode criar conta        │
  │    ( ) Por convite — apenas com link de convite          │
  │    ( ) Fechado — apenas admin cria contas                │
  │                                                         │
  │                                         [Próximo ►]     │
  │                                                         │
  └─────────────────────────────────────────────────────────┘

  ┌─────────────────────────────────────────────────────────┐
  │                                                         │
  │  ─── PASSO 4/5: FEDERAÇÃO ───                           │
  │                                                         │
  │  Deseja conectar-se à rede Retro Hex Chat?                       │
  │    (●) Sim — descobrir e ser descoberto por outros      │
  │    ( ) Não — servidor isolado (pode ativar depois)      │
  │                                                         │
  │  Seeds (servidores para contato inicial):               │
  │  ┌──────────────────────────────────────────────┐       │
  │  │ hub.retrohexchat.net                          [x]   │       │
  │  │ community.elixir.chat                  [x]   │       │
  │  │ [+ adicionar seed                         ]  │       │
  │  └──────────────────────────────────────────────┘       │
  │                                                         │
  │  Aprovação manual de federações: [✓]                    │
  │  (Recomendado: você aprova cada pedido de federação)    │
  │                                                         │
  │                                         [Próximo ►]     │
  │                                                         │
  └─────────────────────────────────────────────────────────┘

  ┌─────────────────────────────────────────────────────────┐
  │                                                         │
  │  ─── PASSO 5/5: SENHA DE ADMIN ───                      │
  │                                                         │
  │  Defina uma senha para o modo admin.                    │
  │  Essa senha será usada com /admin unlock.               │
  │                                                         │
  │  ⚠ É DIFERENTE da senha da sua conta.                   │
  │  Outros admins que você criar terão a mesma senha admin, │
  │  ou podem usar suas próprias (configurável depois).     │
  │                                                         │
  │  Senha admin:    [________________]                     │
  │  Confirmar:      [________________]                     │
  │                                                         │
  │                                     [Finalizar ✓]       │
  │                                                         │
  └─────────────────────────────────────────────────────────┘

  ┌─────────────────────────────────────────────────────────┐
  │                                                         │
  │  ✓ SERVIDOR CONFIGURADO!                                │
  │                                                         │
  │  alpha.chat está online.                                │
  │                                                         │
  │  Conectando à rede Retro Hex Chat...                             │
  │  ✓ 2 peers descobertos: hub.retrohexchat.net,                  │
  │    community.elixir.chat                                │
  │  ✓ Anúncio enviado para a rede.                         │
  │                                                         │
  │  Canais padrão criados:                                 │
  │  • #general — Conversa geral                            │
  │  • #random — Qualquer assunto                           │
  │                                                         │
  │  Próximos passos:                                       │
  │  • Convide pessoas: /admin user invite <email>          │
  │  • Crie canais: /admin channel create #nome             │
  │  • Federe com outros: /admin federation link request    │
  │  • Ajuda: /admin help                                   │
  │                                                         │
  │                                    [Entrar no chat ►]   │
  │                                                         │
  └─────────────────────────────────────────────────────────┘
```

---

## XIII. Senhas Admin — Modelo de Segurança

### Opções de Configuração

```
  O sistema suporta dois modelos de senha admin:

  MODELO A: SENHA ÚNICA (padrão, simples)
  ─────────────────────────────────────────
  Uma única senha admin para o servidor inteiro.
  Todos os admins usam a mesma senha para /admin unlock.

  Prós: Simples de gerenciar
  Contras: Se um admin sair, precisa trocar a senha

  MODELO B: SENHA POR ADMIN (configurável)
  ─────────────────────────────────────────
  Cada admin define sua própria senha de unlock.

  /admin server set admin-password-mode per-user

  Ao promover alguém a admin:
    /admin user role @dave admin
    → Dave recebe prompt para definir sua senha admin

  Prós: Granular, revogação individual
  Contras: Mais complexo

  EM AMBOS OS MODELOS:
  • Senha admin ≠ senha da conta
  • Bcrypt com salt
  • Cooldown após 3 tentativas erradas
  • Log de cada tentativa (sucesso e falha)
  • Sem recovery automático — root owner reseta via config
```

### Diagrama de Segurança

```
                                    ┌─────────────────┐
                                    │  AUDIT LOG      │
                                    │  (tudo é        │
                                    │   registrado)   │
                                    └────────┬────────┘
                                             │
  ┌──────────┐    ┌──────────┐    ┌──────────┴────────┐
  │  Usuário │───►│  Auth    │───►│  Sessão Admin     │
  │  digita  │    │  bcrypt  │    │  - token em memória│
  │  senha   │    │  verify  │    │  - TTL 30 min     │
  └──────────┘    └──┬───┬──┘    │  - renovável      │
                     │   │       │  - bound ao user   │
                   OK│   │FAIL   │  - bound ao IP     │
                     │   │       └───────────┬────────┘
                     │   │                   │
                     │   ▼                   ▼
                     │ ┌────────┐   ┌────────────────┐
                     │ │Cooldown│   │ Admin Commands  │
                     │ │5 min   │   │ disponíveis     │
                     │ │após 3x │   │                 │
                     │ └────────┘   │ Cada comando    │
                     │              │ verifica:       │
                     │              │ 1. Sessão ativa?│
                     │              │ 2. Escopo ok?   │
                     │              │ 3. Log ação     │
                     │              └────────────────┘
                     │
                     ▼
              Sucesso → abrir sessão
```

---

## XIV. Resumo: O que Cada Papel Pode Fazer

```
┌──────────────────┬──────┬───────┬─────┬─────────┬────┬───────┬──────┐
│ AÇÃO             │ ROOT │ ADMIN │ MOD │ CH.OWNER│ OP │ VOICE │ USER │
├──────────────────┼──────┼───────┼─────┼─────────┼────┼───────┼──────┤
│                  │      │       │     │         │    │       │      │
│ Config servidor  │  ✓   │  ✓*   │     │         │    │       │      │
│ Promover admin   │  ✓   │       │     │         │    │       │      │
│ Promover mod     │  ✓   │  ✓    │     │         │    │       │      │
│ Ban global       │  ✓   │  ✓*   │  ✓  │         │    │       │      │
│ Gerenciar peers  │  ✓   │  ✓*   │     │         │    │       │      │
│ Federar canais   │  ✓   │  ✓*   │     │  ✓**    │    │       │      │
│ Aceitar federação│  ✓   │  ✓*   │     │  ✓**    │    │       │      │
│ Suspender peer   │  ✓   │  ✓*   │     │         │    │       │      │
│ Ver audit log    │  ✓   │  ✓    │     │         │    │       │      │
│ Resolver reports │  ✓   │  ✓*   │  ✓  │         │    │       │      │
│ Kick de canal    │  ✓   │  ✓    │  ✓  │  ✓      │ ✓  │       │      │
│ Ban de canal     │  ✓   │  ✓    │  ✓  │  ✓      │ ✓  │       │      │
│ Mudar topic      │  ✓   │  ✓    │  ✓  │  ✓      │ ✓  │       │      │
│ Dar op/voice     │  ✓   │  ✓    │     │  ✓      │    │       │      │
│ Falar em +m      │  ✓   │  ✓    │  ✓  │  ✓      │ ✓  │  ✓    │      │
│ Enviar mensagem  │  ✓   │  ✓    │  ✓  │  ✓      │ ✓  │  ✓    │  ✓   │
│ Reportar         │  ✓   │  ✓    │  ✓  │  ✓      │ ✓  │  ✓    │  ✓   │
│ Bloquear user    │  ✓   │  ✓    │  ✓  │  ✓      │ ✓  │  ✓    │  ✓   │
│ Follow/unfollow  │  ✓   │  ✓    │  ✓  │  ✓      │ ✓  │  ✓    │  ✓   │
│                  │      │       │     │         │    │       │      │
├──────────────────┴──────┴───────┴─────┴─────────┴────┴───────┴──────┤
│  ✓* = depende do escopo do admin (pode ter permissão parcial)      │
│  ✓** = apenas para o canal que possui                               │
└─────────────────────────────────────────────────────────────────────┘
```
