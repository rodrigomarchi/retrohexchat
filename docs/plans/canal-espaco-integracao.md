# Canal = Espaço — integração do Virtual Space ao chat

> Fase seguinte ao ship da nova Elfic Forest (mapa composto, v4). Este plano é
> para revisão conjunta antes de qualquer código.

## 1. Visão

O virtual space deixa de ser uma sala efêmera criada por comando e passa a ser
**uma dimensão permanente de todo canal**. Entrar no canal é entrar no espaço;
quem está no canal (pessoas e bots) existe como avatar no mapa. A janela do
canal ganha duas abas — **Chat** e **Espaço** — sobre a mesma conversa: o chat
do jogo É o chat do canal, público, uma única fonte de mensagens.

```
┌─ #retro ────────────────────────────────┐
│ [ Chat ] [ Espaço ]                      │  ← toggle tipo tab
│                                          │
│  (aba Chat: log + composer atuais)       │
│  (aba Espaço: canvas da vila; mesmas     │
│   mensagens viram balões nos avatares;   │
│   composer é o mesmo componente)         │
└──────────────────────────────────────────┘
```

## 2. Decisões já tomadas (pedido do Rodrigo)

| # | Decisão |
|---|---------|
| D1 | Todo canal é virtual space **por default**, **sem expiração** |
| D2 | Presença espelhada: quem está no canal (usuários **e bots**) aparece no espaço |
| D3 | Todos nascem em volta de um lugar do mapa — **a praça do mercado** (o spawn atual do v4 já é ela) |
| D4 | **Sem limite de participantes** (era 20; "infinito por hora") |
| D5 | Remover a lógica de "lobby" do espaço: sem `/space`, sem invite card, sem token/TTL, sem página própria — o espaço vive dentro da janela do canal |
| D6 | Chat unificado: mensagem no espaço = mensagem no canal (pública), e vice-versa |

## 3. Modelo alvo

### 3.1 Ciclo de vida — espaço por canal, runtime-only

- `SessionServer` passa a ser **registrado por nome de canal** (Registry key
  `{:channel_space, "#retro"}`), iniciado on-demand no primeiro join e
  hibernando/terminando quando o canal esvazia (estado é descartável — posições
  não persistem entre "gerações" do processo; ver P2).
- **Sem banco**: a tabela `virtual_space_sessions` (token, TTL, status, cap)
  perde a razão de existir para canais. Fica só runtime + PubSub
  (`space:#{channel}` em vez de `space:#{token}`).
- Mapa: `elfic_forest` para todos os canais (config futura por canal é
  não-objetivo desta fase).

### 3.2 Presença espelhada

- Fonte de verdade: a presença do canal que já existe (`RetroHexChat.Presence`,
  tópico `channel:#{name}`). O espaço **assina** a presença: entrou no canal →
  avatar surge na praça; saiu/timeout → avatar some.
- Estar com a aba Chat aberta ≠ ausente: o avatar existe do mesmo jeito
  (parado onde estava). Movimento só acontece com a aba Espaço ativa e focada.
- **Bots**: avatares como os demais. v1: cada bot recebe um posto fixo temático
  determinístico (hash do nome → um ponto de interesse: banca do mercado,
  forja, poço...). Comportamento (perambular, falar via balão quando posta no
  canal) já sai de graça pelo chat unificado; movimento de bot fica para
  fase posterior.
- **Convidados (guests)**: mesmas regras — presença no canal manda.

### 3.3 Spawn na praça (D3) sem colisão

- Spawn base: praça do mercado (células 41-44 × 26-27 do v4).
- Com N ilimitado, o join usa **busca em espiral** a partir da praça pela
  primeira célula livre e desbloqueada — determinística, sem RNG no servidor.
- Avatares NÃO colidem entre si (já é assim hoje? verificar; se colidem,
  desligar colisão avatar-avatar — com N grande a praça vira gargalo).

### 3.4 Chat unificado (D6)

- **Uma fonte**: `Chat.create_message/…` do canal. A aba Espaço não tem
  armazenamento próprio nem rate limit próprio — o composer do espaço é o
  mesmo `Composer` (ele já é capability-driven) publicando no canal.
- No canvas, mensagem de canal de um participante presente vira **balão** sobre
  o avatar (o renderer já tem speech bubble). Mensagens de quem não está no
  espaço (ex.: serviços) aparecem só no log.
- Comandos `/` continuam funcionando dos dois lados (mesmo pipeline).
- O log da aba Chat é o mesmo LiveView de hoje — zero mudança de modelo.

### 3.5 UI — o toggle (D5)

- A janela do canal no desktop win98 ganha **tab strip** (Chat | Espaço).
- Aba Espaço monta o hook JS do engine existente (canvas, atlas, câmera) —
  o engine já é isolado (`js/lib/space/*`); muda o transporte: o canal
  Phoenix passa a ser `space:#{channel}` e o `space_init` vem no join da aba.
- **Contrato de foco**: canvas focado → setas movem o avatar; composer focado
  → setas editam texto. Sem roubo de foco (regra WM da memória: nada de
  geometria/foco mudando sob o ponteiro).
- Redimensionamento da janela → canvas resize (camera reaproveita).

### 3.6 Sem limite (D4) — e honestidade sobre escala

- Remover `max_participants` do join (`policy.ex:67`).
- Riscos com N grande (aceitos "por hora", mitigação em fase 6):
  - broadcast de delta é fanout O(N) por passo de movimento → N² msgs/s no pior caso;
  - `space_init` cresce com N participantes;
  - canvas com centenas de sprites + labels.
- Fase 6 (futura, não bloqueia): interest management por viewport, batch de
  deltas por tick, culling de labels.

## 4. O que morre (D5)

| Item | Ação |
|------|------|
| `/space` (handler + registry + help topic) | remover |
| Invite cards de espaço no chat (`session_cards`) | remover |
| `SpaceLive` + rota `/space/:token` | remover |
| `join_token.ex` | remover |
| TTL/`expires_at`/`cleanup_task.ex`/status pending→expired | remover |
| `Schema.Session` + tabela `virtual_space_sessions` | migração de drop (ou soft: parar de usar e dropar depois — decidir na revisão) |
| `policy.ex` (cap, criador, permissões de sessão) | reduzir ao que sobrar (kick de admin do canal?) |

**⚠️ Escopo a confirmar**: "remover toda a lógica de lobby" — este plano remove
o fluxo de sessão do *espaço* (acima). O **LobbyLive P2P** (chamadas, jogos,
transferência de arquivo) é outra feature e **não** é tocado aqui. Se a
intenção é aposentá-lo também, vira fase própria (o chat dele seria absorvido
pelo canal, mas jogos/chamadas precisam de novo lar). → responder na revisão.

## 5. Fases

### F1 — Espaço por canal no domínio
`SessionServer`/`Registry`/`Supervisor` chaveados por canal; join/leave dirigidos
pela presença do canal; spawn em espiral; cap removido; sem DB/TTL.
**Testes**: unit (spawn espiral, mirror join/leave), integração (presença do
canal cria/destroi avatar), movement/office adaptados.
**Aceite**: entrar no canal pelo chat faz o avatar aparecer para quem está na
aba Espaço, sem nenhum comando.

### F2 — Chat unificado
Composer do espaço → mensagem de canal; mensagem de canal → balão no avatar.
Remoção do chat próprio do espaço (se existir hoje) e do rate limit paralelo.
**Testes**: integração canal↔espaço nos dois sentidos; LiveView do log inalterado.

### F3 — Tab na janela do canal
Tab strip Chat|Espaço; embed do engine; contrato de foco; resize; `space_init`
no join da aba; sair da aba não sai do espaço.
**Testes**: LiveView (toggle, foco), E2E pontual (andar + ver balão).

### F4 — Bots na vila
Bots do canal viram avatares com postos temáticos determinísticos.
**Testes**: unit (atribuição de posto), integração (bot presente → avatar).

### F5 — Remoções + docs
Tudo da seção 4; migração DB; **help topics** (atualizar "Virtual Spaces",
remover `/space` de Commands, atualizar atalhos com o toggle); i18n dos textos
novos (regra da memória: só os catálogos do domínio afetado).
**Aceite**: `make ci` 9/9; nenhuma referência morta a token/lobby de espaço.

### F6 — (futura) Escala de verdade
Interest management, tick batching, culling. Fora do escopo desta entrega.

## 6. Riscos

| Risco | Mitigação |
|-------|-----------|
| Fanout de deltas com N grande | aceito por hora (D4); F6 |
| Praça congestionada no spawn | espiral + sem colisão avatar-avatar |
| Foco de teclado (jogar vs digitar) | contrato explícito de foco na F3; testar no E2E |
| Duas abas = dois estados de scroll/stream do chat | aba Chat permanece o LiveView atual intocado; Espaço só assina os mesmos eventos |
| Bots "fantasmas" (presença de bot difere da humana) | tratar fonte de presença de bot na F4 antes de generalizar |
| Drop da tabela quebra histórico/admin | decidir soft-drop vs drop na revisão |

## 7. Perguntas abertas (responder na revisão)

- **P1**: LobbyLive P2P fica ou também sai? (seção 4)
- **P2**: posição do avatar persiste entre visitas (por canal), ou sempre
  renasce na praça? (proposta: renasce; persistência é estado novo sem dono claro)
- **P3**: o espaço roda mesmo com zero gente na aba Espaço (avatares "parados"
  processando), ou o servidor hiberna e materializa tudo do presence no
  primeiro espectador? (proposta: hibernar — mais barato, mesmo resultado visual)
- **P4**: kick/moderação dentro do espaço segue as permissões do canal (op/admin)?
- **P5**: DM/whisper aparece como balão? (proposta: não — só mensagens públicas
  do canal viram balão)

## 8. Telemetria

PromEx: gauge de participantes por canal-espaço, taxa de passos/s, latência de
delta — antes de F6 para decidir quando ela vira necessidade.
