# Canal = Espaço — integração do Virtual Space ao chat

> Fase seguinte ao ship da nova Elfic Forest (mapa composto, v4). Este plano é
> para revisão conjunta antes de qualquer código.

## 1. Visão

O virtual space deixa de ser uma sala efêmera criada por comando e passa a ser
**uma dimensão permanente de todo canal**. Entrar no canal é entrar no espaço;
quem está no canal existe como avatar no mapa. A janela do canal ganha duas abas
— **Chat** e **Espaço** — sobre a mesma conversa: o chat do jogo É o chat do
canal, público, uma única fonte de mensagens.

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
| D2 | Presença espelhada: usuários presentes no canal aparecem no espaço; bots/NPCs ficam fora do escopo atual |
| D3 | Todos nascem em volta de um lugar do mapa — **a praça do mercado** (o spawn atual do v4 já é ela) |
| D4 | **Sem limite de participantes** (era 20; "infinito por hora") |
| D5 | Remover a lógica de "lobby" do espaço: sem `/space`, sem invite card, sem token/TTL, sem página própria — o espaço vive dentro da janela do canal |
| D6 | Chat unificado: mensagem no espaço = mensagem no canal (pública), e vice-versa |
| D7 | Entrega inicial **side-by-side**: fazer funcionar dentro do chat antes de remover o fluxo legado de `/space` |
| D8 | O chat textual do espaço de canal fica **100% LiveView**: o canvas usa canal Phoenix só para movimento/interações e balões derivados do chat público |
| D9 | **LobbyLive P2P fica fora** desta mudança; chamadas, jogos e transferência de arquivo não entram no escopo |

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
- **Bots/NPCs**: fora do escopo atual por decisão de 2026-07-08. O espaço por
  canal deve funcionar sem depender de presença, postos temáticos ou movimento
  de bots; se isso voltar, entra como plano próprio.
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
**Status 2026-07-08**: implementado side-by-side. `SessionServer` aceita modo
runtime por canal (`{:channel_space, "#canal"}`), materializa membros atuais do
canal, espelha join/part/kick/nick change, usa `elfic_forest`, spawn em espiral
e hiberna quando não há espectadores da aba Espaço.

### F2 — Chat unificado
Composer do espaço → mensagem de canal; mensagem de canal → balão no avatar.
Remoção do chat próprio do espaço (se existir hoje) e do rate limit paralelo.
**Testes**: integração canal↔espaço nos dois sentidos; LiveView do log inalterado.
**Status 2026-07-08**: implementado para canal-espaço. O composer continua sendo
o componente LiveView do chat; `chat_bubble` do espaço de canal é no-op para não
criar transporte paralelo. Mensagens públicas do canal viram balões no canvas;
system/service/PM ficam fora dos balões.

### F3 — Tab na janela do canal
Tab strip Chat|Espaço; embed do engine; contrato de foco; resize; `space_init`
no join da aba; sair da aba não sai do espaço.
**Testes**: LiveView (toggle, foco), E2E pontual (andar + ver balão).
**Status 2026-07-08**: implementado no fluxo principal do chat. O toggle
Chat/Space fica na linha do tópico, antes do texto do tópico, com botões
maiores, ícones SVG e texto. A aba Espaço monta `SpaceCanvasHook` usando
`space:#canal`; a aba Chat e o composer permanecem montados pelo LiveView.

### F4 — Remoções + docs
Tudo da seção 4; migração DB; **help topics** (atualizar "Virtual Spaces",
remover `/space` de Commands, atualizar atalhos com o toggle); i18n dos textos
novos (regra da memória: só os catálogos do domínio afetado).
**Aceite**: `make ci` 9/9; nenhuma referência morta a token/lobby de espaço.
**Status 2026-07-08**: em andamento. A superfície pública de `/space` e a criação
de `space_invite` já foram removidas; o runtime legado de sessão/token fica por
enquanto para permitir a remoção em camadas.

#### Backlog executável da F4

- [x] Despublicar `/space` da superfície de comandos e help, mantendo o código
  legado apenas enquanto existirem dependências internas.
- [x] Remover criação de invite card (`:space_invite`) e os helpers/cards de
  renderização ligados a `/space/<token>`.
- [x] Remover `SpaceLive` e a rota `/space/:token` depois que o convite legado não
  for mais criado.
- [x] Substituir o `join_token.ex` por um contrato específico do canal-espaço, ou
  renomeá-lo antes de remover o join legado por token.
- [ ] Aposentar `Schema.Session`, `virtual_space_sessions`, TTL/status/cleanup e a
   política de capacidade/criador quando o fluxo legado não tiver chamadas vivas.
- [ ] Atualizar docs/help/i18n para explicar que o espaço é uma aba do canal e não
   um comando separado.
- [ ] Rodar `make ci` e registrar aprendizados/decisões antes de apagar a próxima
   camada.

### F5 — (futura) Escala de verdade
Interest management, tick batching, culling. Fora do escopo desta entrega.

## 6. Riscos

| Risco | Mitigação |
|-------|-----------|
| Fanout de deltas com N grande | aceito por hora (D4); F6 |
| Praça congestionada no spawn | espiral + sem colisão avatar-avatar |
| Foco de teclado (jogar vs digitar) | contrato explícito de foco na F3; testar no E2E |
| Duas abas = dois estados de scroll/stream do chat | aba Chat permanece o LiveView atual intocado; Espaço só assina os mesmos eventos |
| Bots/NPCs voltarem ao escopo antes do canal-espaço estabilizar | manter fora desta fase; abrir plano próprio se a decisão mudar |
| Drop da tabela quebra histórico/admin | decidir soft-drop vs drop na revisão |

## 7. Perguntas abertas (responder na revisão)

- **P1**: LobbyLive P2P fica ou também sai? **Respondida**: fica fora desta
  mudança.
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

## 9. Registro de execução — 2026-07-08

### Progresso entregue

- Criado caminho side-by-side para espaço por canal sem remover o fluxo legado
  de sessão/token.
- `Registry`, `Supervisor`, `VirtualSpace` e `SessionServer` passaram a suportar
  chave de canal (`{:channel_space, channel_name}`) além de token legado.
- `SpaceChannel` passou a aceitar join em `space:#canal` autorizado por token
  assinado pela LiveView do chat.
- `ChatLive` ganhou modo `:chat | :space` por canal. A aba Espaço monta o canvas
  dentro da janela do chat e mantém o composer LiveView como única entrada de
  texto.
- A barra de tópico ganhou slot de controles; o seletor Chat/Space foi movido
  para a linha do tópico, com ícones SVG e texto.
- Testes cobrem join por canal, rejeição de nick fora do canal, espelhamento de
  join/part/mensagem, spawn além das células iniciais e preservação do composer
  ao alternar para Space.

### Aprendizados

- A separação correta é: LiveView continua dono do chat textual; canal Phoenix
  do espaço fica restrito a movimento, interações e renderização de balões.
- Para canal-espaço, permissões de host/criador do virtual space legado não se
  aplicam. Moderação deve permanecer no canal; `admin_action` do espaço de canal
  responde `:forbidden` por enquanto.
- O estado por canal deve ser materializável a partir da presença. Isso permite
  hibernar o processo quando ninguém está vendo a aba Espaço sem perder a
  semântica visual.
- A chave operacional mais estável para convidados e bots nesta fase é o nick
  normalizado (`nick:<lower>`), não `user_id`.
- O spawn precisa expandir além da praça inicial sem depender de RNG; a espiral
  determinística resolveu o gargalo inicial.
- Bots/NPCs foram removidos do escopo atual. O foco volta para aposentar o
  fluxo legado de `/space`/token/TTL depois que o canal-espaço já funciona no
  chat.
- Primeiro corte da F4 concluído: `/space` saiu do `Commands.Registry`, do índice
  de help e dos templates embutidos.
- Segundo corte da F4 concluído: `RetroHexChat.Commands.Handlers.Space`,
  `SpaceInvite`, `:space_invite` como tipo novo e os cards ricos de `/space/<token>`
  foram removidos. Mensagens antigas desse tipo, se existirem no banco, passam a
  cair como texto comum no renderer.
- Terceiro corte da F4 concluído: `SpaceLive`, rota `/space/:token` e testes
  dedicados da página legada foram removidos. Naquele momento o canal Phoenix
  ainda aceitava o caminho legado `space:<token>` até a substituição do
  `join_token`.
- Quarto corte da F4 concluído: `JoinToken` foi substituído por
  `ChannelJoinToken`; `SpaceChannel` deixou de aceitar `space:<token>` e ficou
  restrito a `space:#canal`. A suíte de channel agora cobre o caminho real de
  canal-espaço.

### Validação registrada

- `rtk mix format` nos arquivos alterados.
- `rtk mix compile`.
- Testes Elixir focados de virtual space, `SpaceChannel` e `ChatDesktopShell`.
- Testes JS focados de `SpaceCanvasHook` e `js/lib/space`.
- `rtk mix test` completo após os ajustes finais: core com 15 properties e 2837
  testes sem falhas; web com 769 testes sem falhas (193 excluídos).
- `rtk git diff --check`.
- Após o primeiro corte da F4: `rtk mix format` nos arquivos alterados; testes
  focados de registry/help/handler e HelpLive; `rtk make ci` completo com 9/9
  checks passando.
- Após o segundo corte da F4: testes focados de `Message`, registry/syntax,
  `SessionCard` helper e componentes de mensagem/card; `rtk make ci` completo
  com 9/9 checks passando.
- Após o terceiro corte da F4: testes focados de `SpaceChannel`, shell do chat,
  HelpLive e domínio `VirtualSpace`; `rtk make ci` completo com 9/9 checks
  passando na rerodada.
- Após o quarto corte da F4: testes focados de `ChannelJoinToken`,
  `SpaceChannel`, `ChatDesktopShell` e JS `SpaceCanvasHook`; `rtk make ci`
  completo com 9/9 checks passando.
