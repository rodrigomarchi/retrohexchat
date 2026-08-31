# Superfícies compartilháveis — plano de execução

Hoje toda a plataforma cabe numa aba: `/chat` monta um LiveView, um desktop
Win98 e N janelas. Este plano tira **conferência, space, P2P e jogos** de dentro
dessa janela única e dá a cada um deles uma **URL própria e compartilhável**, sem
duplicar nenhuma implementação.

Apagar este diretório quando a última onda shippar; mover as regras duráveis para
[`guide/webrtc-p2p.md`](../../guide/webrtc-p2p.md),
[`guide/windowed-desktop.md`](../../guide/windowed-desktop.md) e
[`AGENT-GUIDE.md`](../../AGENT-GUIDE.md) **antes** de apagar.

| | Arquivo | Entrega |
|---|---|---|
| **retomada** | [`HANDOVER.md`](HANDOVER.md) | **Estado atual, próximo passo e as armadilhas. Leia primeiro ao retomar.** |
| **desenho** | [`ux.md`](ux.md) | O modelo de produto e todas as telas |
| **diário** | [`PROGRESS.md`](PROGRESS.md) | O que aconteceu a cada iteração, com os erros |
| 0 | [`wave-0-identity-and-surfaces.md`](wave-0-identity-and-surfaces.md) | Uma segunda aba deixa de matar a primeira |
| 1 | [`wave-1-join-resolver.md`](wave-1-join-resolver.md) | `/join/:slug` — o link que dá pra postar, e o card ao vivo na conversa |
| 2 | [`wave-2-conference-surface.md`](wave-2-conference-surface.md) | `/call/:token` — conferência em aba própria |
| 3 | [`wave-3-space-surface.md`](wave-3-space-surface.md) | `/space/:token` — o renderer isométrico sai do event loop do chat |
| 4 | [`wave-4-p2p-channel-and-surface.md`](wave-4-p2p-channel-and-surface.md) | `P2PChannel` + `/p2p/:token` |
| 5 | [`wave-5-games-surfaces.md`](wave-5-games-surfaces.md) | `/play/:game/:token` — o lobby aberto e a partida compartilhável |
| 6 | [`wave-6-cross-tab-and-bundle.md`](wave-6-cross-tab-and-bundle.md) | Coordenação entre abas + split de bundle medido |

---

## 1. O que existe hoje

### 1.1 A identidade é uma sessão só, e ela expulsa a anterior

`chat_nickname` é um valor do cookie de sessão do Plug
(`controllers/app/session_controller.ex:23`). `ChatLive.mount/3` transmite
`{:force_disconnect, …}` no tópico `user:<nick>` **antes** de se inscrever nele
(`live/app/chat_live.ex:139-150`) e espera o ack da sessão anterior
(`chat_live.ex:256`). Quem recebe derruba a própria sessão
(`live/chat_live/pubsub_handlers/membership.ex:211`).

Consequência: **abrir `/chat` numa segunda aba encerra a primeira**, e existe um
teste que garante exatamente isso (`e2e/tests/multi-tab-takeover.spec.ts`). Não
existe hoje nenhuma superfície que possa coexistir com o chat na mesma origem.

Isto é o bloqueio número um. Nenhuma onda posterior funciona sem a onda 0.

### 1.2 As quatro features, e como cada uma fala com o servidor

| Feature | Domínio | Transporte de sinalização | Autorização | Onde aparece |
|---|---|---|---|---|
| Conferência (SFU) | `RetroHexChat.GroupCall` | **Phoenix Channel cru** `group_call:<room_token>` (`channels/group_call_channel.ex:22`) | `GroupCall.JoinToken` assinado + `Policy` (registrado + membro do canal) | janela `group-call` (`chat_live.html.heex:584`) |
| Space | `RetroHexChat.VirtualSpace` | **Phoenix Channel cru** `space:*` (`channels/space_channel.ex:22`) | `VirtualSpace.ChannelJoinToken` assinado | *aba* dentro da conversa (`chat_live.html.heex:192`) |
| P2P 1:1 | `RetroHexChat.Lobby` | **socket do LiveView** — `pushEvent` → `ChatLive.handle_event` → PubSub `lobby:<token>` → LiveView do par → `push_event` | token de sessão + `Policy` (ambos registrados, identificados e online) | janela `p2p-call` (`chat_live.html.heex:546`) |
| Retro Games | `RetroHexChat.Games` | nenhum (solo, canvas local) | nenhuma | janela `retro-games` (`chat_live.html.heex:605`) |
| Arcade (WASM) | `RetroHexChat.Arcade` | nenhum | registrado | janela + **`window.open` numa aba separada** (`hooks/games/arcade_session_hook.js:29`) |

Duas coisas saltam daqui:

1. **Conferência e space já estão prontos para sair da aba.** Ambos entram por um
   channel cru autenticado por token assinado (`RetroHexChat.SignedToken`), e o
   `UserSocket` é anônimo de propósito — "authorization happens per channel via a
   signed join token" (`channels/user_socket.ex:6`). Uma página nova só precisa do
   token; ela não precisa de `ChatLive` para nada.
2. **P2P não está.** A sinalização dele mora dentro do `ChatLive`, em
   `live/chat_live/p2p_session_events.ex` (2.258 linhas). Tirar o P2P da aba
   exige antes mover a sinalização para um channel cru — é o trabalho central
   da onda 4, e é por isso que ela vem por último entre as features.
3. **O Arcade já faz isso.** `window.open` para o jogo WASM existe e funciona em
   produção. O precedente de "feature fora da aba" já está no repositório.

### 1.3 O custo que isso tem no `ChatLive`

`group_call_events.ex` (2.603) + `p2p_session_events.ex` (2.258) = **4.861 linhas
de adaptador de evento** carregadas em todo processo `ChatLive`, inclusive o de
quem nunca abriu uma chamada. `chat_live.html.heex` tem 1.250 linhas; `chat_live.ex`,
1.217.

Isto não é só peso: é acoplamento. Um bug de renegociação de SDP hoje mora no
mesmo módulo que decide se a janela de chamada abre.

---

## 2. A proposta, avaliada honestamente

Você deu três motivos. Eles não têm o mesmo tamanho, e o plano fica melhor se
isso estiver escrito.

### 2.1 Links compartilháveis — o motivo forte, e o único que hoje é zero

Não existe **nenhuma** URL que signifique "entre nesta chamada". `/lobby/:token`
sobreviveu apenas como redirect para `/chat`
(`controllers/app/lobby_redirect_controller.ex`), e o convite P2P ainda carrega
esse caminho dentro do texto da PM por compatibilidade
(`live/chat_live/helpers/lobby_invite.ex:88`).

Isto é uma capacidade de produto ausente, não uma otimização. É o motivo pelo
qual este plano existe e é o que ordena as ondas.

**Mas há uma consequência de política que precisa de decisão** (ver §3, D1): um
link postado numa rede social chega a gente não registrada, e hoje a conferência
exige registro **e** ser membro do canal (`group_call/policy.ex:22-27`). Link
compartilhável sem responder isso é um link que dá 403 para todo mundo que
clicar.

### 2.2 Dividir o bundle JS — real, mas bem menor do que parece

O split por feature **já existe**. `lazy_feature_hooks.js` declara 12 hooks
carregados por `import()` dinâmico; quem nunca abre uma chamada nunca baixa o
chunk do SFU (85 KB de orçamento), quem nunca entra no space nunca baixa o
renderer isométrico (120 KB). Isso é enforced por `make lint.bundle`
(`assets/scripts/bundle_budget.cjs`).

O que uma página separada realmente economizaria é o **entry** `app.js`
(orçamento 470 KB / 130 KB gzip): LiveSocket + hooks críticos + toda a cola do
chat. Uma superfície de chamada não precisa da maior parte disso.

Porém: uma entry nova é um download a mais para quem veio do chat (cache frio no
primeiro clique), e mais uma linha de orçamento para manter. **Por isso a onda 2
NÃO cria entry nova** — ela reusa `app.js`, ship, e só a onda 6 divide, com
medição do que a superfície realmente importa. Medir antes de orçar é a regra da
casa (`assets/scripts/bundle_budget.cjs:33-36`).

### 2.3 Dividir o event loop — real, e agora medido

Uma aba separada só ganha um processo de renderer próprio se **não** tiver
relação de opener com quem a abriu. Medido na onda 0 (Chromium, 2026-08-28):
bloqueando a thread da aba satélite por 1.200 ms, o maior intervalo entre frames
na aba do chat foi **1203 ms** com `window.open(url, "_blank")` e **12 ms** com
`noopener`.

Ou seja: o ganho é real e é total — e é zero sem `noopener`. Toda abertura de
superfície neste plano usa `rel="noopener"`, e isso é decisão de arquitetura, não
de estilo. O custo é que some `window.opener`, então a coordenação entre abas
passa a ser `BroadcastChannel` (onda 6) — o que é melhor de qualquer jeito.

Nota sobre o que já existe: o Arcade abre a janela do jogo sem `noopener`
(`arcade_session_hook.js:30`), logo hoje não tem isolamento nenhum.

### 2.4 O quarto motivo, que você não citou, e que talvez seja o maior

**Sobrevivência.** Hoje um deploy, um reload ou uma queda do socket do chat
levam a chamada junto. Todo o §8.5 de [`guide/webrtc-p2p.md`](../../guide/webrtc-p2p.md)
existe para mitigar isso ("A hook `destroyed()` is not a voluntary leave",
"Reconnect needs an application-level rehydrate"). Uma chamada em aba própria
sobrevive ao chat inteiro reiniciando.

### 2.5 O custo que o plano assume

Isto **não é reverter** o `de1fe324` ("remove the standalone /lobby page — the
chat IS the P2P surface"). Aquela consolidação estava certa pelo motivo dela: o
`/lobby` tinha um **chat próprio** (`LobbyLive.Components.ChatIsland`), ou seja,
uma segunda implementação de conversa. Isso é o Princípio XII ("Never fork a
concept per context") e não volta.

O que volta é só o **host**: a mesma implementação, montada num lugar diferente.
A decisão D2 abaixo é o que garante isso mecanicamente.

---

### 2.6 A descoberta que muda o custo do plano

`ChatLive.terminate/2` chama `cleanup_channels/2` (`live/app/chat_live.ex:303`):
**fechar a aba do chat sai de todos os canais.** E a conferência exige filiação
a canal para entrar (`group_call/policy.ex:35`), para moderar
(`group_call/policy.ex:58`), e o space valida presença no canal no join do
channel.

Ou seja: sem trabalho extra, "chamada em aba própria + chat fechado" produz uma
pessoa numa sala de um canal do qual ela não é mais membro — a chamada segue,
mas o `rejoin` depois de um reload é negado e a moderação fica indefinida.

A correção é filiação com **contagem de superfícies abertas**, detalhada na
[onda 2 §2.6](wave-2-conference-surface.md). Ela é infraestrutura da qual as
ondas 3 e 6 dependem, e é o item que mais facilmente seria descoberto tarde.

---

## 3. Decisões de produto (travadas em conversa, 2026-08-28)

O desenho de cada uma está em [`ux.md`](ux.md). Aqui fica só a decisão e o
porquê.

### P1 — Toda superfície tem antessala, em duas formas

Você não cai dentro da coisa: você chega numa antessala. Ela tem duas formas, e
a diferença é se a coisa é um **lugar** ou um **evento**:

* **sala de chegada** (chamada de canal, space) — mostra quem já está, você
  ajusta câmera/personagem e entra quando quiser. Sem host, sem `[Iniciar]`.
* **sala de partida** (jogo multiplayer, sessão P2P) — host, `[Pronto]`,
  `[Iniciar]`. Começa junto.

Por que não `[Iniciar]` em tudo: hoje uma chamada de canal não tem dono — qualquer
membro abre, qualquer um entra na hora. Um gate de host seria regressão de
comportamento disfarçada de feature.

**Só a sala de partida vira entidade persistida**, e ela é o
`RetroHexChat.Lobby` que já existe. Chamada e space são estado de render: o
roster já vem de `GroupCall.get_summary/1` e `VirtualSpace.snapshot/1`. Isso
também resolve o choque de nomes que o `guide/webrtc-p2p.md` avisa ("lobby is the
DOMAIN, not a page") — continua sendo o domínio, e agora ele tem uma tela que é
exatamente ele.

### P2 — Nenhuma antessala e nenhuma superfície tem chat

`[← ao chat]` está sempre visível, e é isso. A conversa acontece na aba do chat,
onde o card ao vivo já está.

Por que: o `/lobby` foi removido em `de1fe324` por ter chat próprio — uma segunda
superfície de conversa. Um chat de espera no lobby seria a mesma coisa com outro
nome. Princípio XII.

### P3 — O card na conversa é ao vivo

Participantes e estado atualizam sozinhos; ao acabar, o card fica cinza e oferece
a próxima ação plausível, nunca um beco.

Por que vale o custo: um card estático que diz "ao vivo" sobre uma chamada que
acabou é pior do que não ter card. E o custo é menor do que parece — o
`ChatLive` **já** mantém `group_call_channel_summaries` por PubSub. O único
gasto novo é assinar o tópico do space.

### P4 — Depois de começar, o link continua valendo

Chamada e space: quem clica depois pula a antessala de espera e entra (passando
pelo ajuste de dispositivo/personagem). Jogo cheio: o card diz "vaga preenchida".

Por que: um link postado num canal passa a maior parte da vida depois do minuto
zero. Um link que morre ao iniciar é útil por poucos minutos e inútil pelo resto.

### P5 — O seletor de personagem É a antessala do space

Ele já existe e já é o primeiro estado ao entrar (`chat_live.ex:353-357`). Ganha
a lista de quem está dentro e vira a porta. Nenhuma tela nova.

Por que: um space não começa nem termina. Um passo de "sala de espera" antes do
seletor seria cerimônia para entrar num lugar que já está aberto.

### P6 — O link nasce de um botão, não de abrir a feature

Abrir a feature cria a sala; **compartilhar** cria o link. Se todo `Retro Games`
aberto gerasse um `share_link` no banco, a tabela vira lixo em uma semana.

### P7 — Host é quem criou, e a sala fecha se ele sair antes de iniciar

Só vale para a sala de partida (P1). Sem migração de host na primeira versão: é
uma sala que dura minutos, e a recuperação certa é criar outra.

---

## 4. Decisões de arquitetura (travadas — não reabrir sem escrever o porquê aqui)

### D1 — O link carrega *identidade da sala*, nunca *autorização*

`/join/:slug` resolve o slug para "qual sala é esta" e **depois** aplica a
política normal para quem quer que esteja clicando. Um visitante deslogado vê um
card público (com Open Graph) e um botão Connect; um usuário registrado que não
é membro do canal vê "você precisa de convite".

Por quê: um único modelo de autorização. Um link não pode virar porta dos fundos,
e o card pode ser público porque não carrega segredo nenhum.

*Fora de escopo deste plano, com gancho previsto:* um tipo separado de token de
**guest pass** (expira, é revogável, é auditável) que conceda capacidade escopada
a quem não é membro. Isso muda moderação, ban e superfície de abuso — merece
plano próprio.

### D2 — Um módulo, dois hosts: `live_render/3`

Cada superfície é **um** LiveView (`CallLive`, `SpaceLive`, `P2PLive`,
`PlayLive`). Ele é montado de duas formas:

* como **root**, em `/call/:token` — a aba própria, event loop próprio;
* como **nested**, via `live_render(@socket, CallLive, id: …, session: …)`
  dentro do slot da `desktop_window` do chat — para mobile e para quem prefere
  não sair da aba.

Não existe uma segunda implementação: existe um módulo com dois pontos de
montagem. `live_render` nested roda em processo próprio no mesmo socket, então
o modo embutido **não** ganha event loop nem bundle separados — e tudo bem, é
exatamente o trade-off que o modo embutido está aceitando.

Efeito colateral desejado: os hooks passam a fazer `pushEvent` para o LiveView
aninhado, não para o `ChatLive`. Isso é o que permite que
`group_call_events.ex` e `p2p_session_events.ex` (4.861 linhas) saiam do host.

### D3 — Toda sinalização vira Phoenix Channel cru

Conferência e space já são. P2P vira, na onda 4. Motivo: é o que faz a mesma
superfície funcionar idêntica embutida ou standalone, e é o que faz a mídia
sobreviver a um reconnect do LiveView.

### D4 — Nenhuma entry de bundle nova antes de medir

Ondas 2–5 usam `app.js`. A onda 6 mede o que cada superfície realmente importa e
decide entre uma entry `surface.js` compartilhada e nada. Uma entry nova precisa
de linha em `ENTRIES` e de orçamento em `assets/scripts/bundle_budget.cjs` —
número sem justificativa escrita transforma o orçamento em carimbo.

### D5 — Mobile continua embutido

Abrir aba nova em telefone é uma UX ruim. `@mobile_viewport` (já existente no
`ChatLive`) escolhe o modo nested. Mesma decisão para o space, que hoje já é
tab-in-conversa e tem pad virtual próprio (`space_virtual_pad`).

### D6 — Estado durável continua no domínio, nunca na aba

`RoomServer`, `SessionServer`, `ChannelSpaceServer` já são a verdade. A aba é
uma view. Fechar a aba **não** encerra a sala; a saída explícita encerra. Esta é
a regra que já vale hoje para hook `destroyed()`
([`guide/webrtc-p2p.md` §8.5](../../guide/webrtc-p2p.md)) e ela não muda.

---

## 5. Rotas resultantes

```
/join/:slug           público, OG, pipeline :landing_live (bundle pequeno)
/call/:token          app, CallLive root
/space/:token         app, SpaceLive root
/p2p/:token           app, P2PLive root
/play/:game           app, PlayLive root (solo — link direto, sem token)
/play/arcade/:game    app, redirect para onde o bundle WASM mora (o endereço é nosso)
/play/:game/:token    app, P2PLive root — a mesma superfície, aberta no jogo
/lobby/:token         mantém o redirect legado (agora → /join/:slug)
```

Restrição do router que precisa ser respeitada: **não existe catch-all
`/:locale`** (`AGENT-GUIDE` §16) — cada segmento novo é reservado no topo e
precisa não colidir com os segmentos de locale de `config/i18n_locales.exs`.
Nenhum dos cinco colide.

**E toda rota pública precisa ser registrada dentro do laço de locales**, não só
no escopo sem prefixo. `/join/:slug` nasceu só sem prefixo e deu
`NoRouteError` em `/pt-BR/join/...` — achado no navegador, invisível para
dezesseis testes que só exercitavam o caminho que o próprio código constrói
([`PROGRESS.md`](PROGRESS.md), iteração 7). Item de checklist para cada onda que
adiciona rota.

Indexação: só `/join/:slug` é público, e mesmo ele deve ser `noindex` quando o
token não resolve para uma sala viva. As demais herdam `SEO.noindex_content/0`.

---

## 6. TDD — a regra que vale em todas as ondas

Teste primeiro, em todas elas. Pirâmide da casa (`AGENT-GUIDE` §1.4 e
[`guide/testing.md`](../../guide/testing.md)):

| Camada | Onde | O que ela prova aqui |
|---|---|---|
| `:unit` ExUnit | `apps/retro_hex_chat/test/**` | tokens, política, resolução de link, máquina de estados |
| `:integration` ExUnit | idem, com DB | ciclo de vida de sala/sessão atravessando processos |
| `:liveview` / `:liveview_feature` | `apps/retro_hex_chat_web/test/**` | mount root **e** mount nested do mesmo módulo, autorização, redirect |
| Channel test | `apps/retro_hex_chat_web/test/**/channels/**` | join com token válido/expirado/forjado |
| Vitest | `apps/retro_hex_chat_web/assets/test/**` | lógica de `lib/`: coordenação entre abas, resolução de superfície |
| Playwright | `e2e/tests/**` | as duas abas de verdade, com mídia de verdade |

Regras que já custaram caro neste repositório e que se aplicam a tudo aqui:

* **Nunca asserir em `send_update`/stream assíncrono** — asserir estado síncrono
  (`:sys.get_state`), teste de domínio/componente, ou dado persistido. Sem
  `sleep`, sem render-retry.
* **Playwright exige `mix assets.build` antes**, e matar o servidor stale na
  porta do e2e depois de qualquer mudança em Elixir — senão você valida código
  velho.
* **A classe de bug "dado inicial via `send_update` pós-mount"** é invisível
  para o ExUnit e só o E2E pega
  ([`guide/windowed-desktop.md` §7.1](../../guide/windowed-desktop.md)). Toda
  superfície nova carrega seu dado inicial no próprio `mount/3`.
* `make ci` é o único gate final. `make ci.quick` / `ci.changed` / smokes são
  iteração.

---

## 7. Obrigações que cada onda carrega (checklist, não opcional)

- [ ] **Help topics** — toda onda adiciona controle acionável pelo leitor, logo
      atualiza `RetroHexChat.Chat.HelpTopics` (`AGENT-GUIDE` §12). "Como eu
      compartilho o link da chamada" é exatamente uma pergunta de help.
- [ ] **i18n** — string nova = `make i18n.gettext.extract` +
      `make i18n.gettext.merge DOMAINS=<domínio>`. Não usar o rebuild global.
- [ ] **`PerfBudgets`** — superfície nova = entrada em
      `apps/retro_hex_chat_web/test/support/perf_budgets.ex` (`html_bytes/1`,
      `dom_nodes/1`), com o número medido e ~10% de folga.
- [ ] **`SURFACE.txt`** — evento novo de LiveView/channel/dataset =
      `scripts/surface_snapshot.sh --check` reprovando até o snapshot ser
      atualizado.
- [ ] **`bundle_budget.cjs`** — só se a onda 6 criar entry.
- [ ] **`e2e/TEST_CATALOG.md`** — specs novos carregam `@flow` e o catálogo é
      regenerado com `make e2e.catalog`.
- [ ] **`make ci` verde** antes de considerar a onda fechada.

---

## 8. Perguntas em aberto (precisam de você, não do código)

Duas, depois da conversa de 2026-08-28. As outras viraram §3.

1. **Guest pass.** A decisão atual (D1 + P4) é que o link carrega identidade da
   sala, nunca autorização: quem chega de fora escolhe um nick e as regras de
   hoje valem. Na prática, um link de conferência **só funciona pra quem já é
   membro do canal** (`group_call/policy.ex:35`), e um link no Twitter entrega
   um card explicativo, não uma chamada. É a escolha certa para a primeira
   versão e é a que mais limita o alcance social.
   *Recomendação: manter agora, e abrir um plano próprio para o guest pass
   depois da onda 2, com o número real de cliques de fora na mão.* Ele traz
   moderação, ban e abuso junto — não cabe como um item de onda.
2. **O Start menu nas satélites.** Hoje ele é superconjunto em todas as telas do
   window manager, cinza onde a tela não alcança — +177 nós, +17 KB raw por tela
   (`test/support/perf_budgets.ex`). Quatro satélites de propósito único pagariam
   isso quatro vezes.
   *Recomendação: satélite carrega só o que alcança, mais "voltar ao chat", como
   exceção escrita.* Decidido na onda 6 §2.3, mas dá pra antecipar.
