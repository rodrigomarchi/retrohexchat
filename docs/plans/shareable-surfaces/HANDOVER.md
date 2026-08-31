# Handover — superfícies compartilháveis

Escrito em 2026-08-28, atualizado em 2026-08-30 (fim da fase 4A) para retomar o
trabalho com contexto zerado. Apagar quando a onda 6 fechar.

---

## 1. Leia nesta ordem

1. [`README.md`](README.md) — a análise, as decisões travadas (P1–P7 produto,
   D1–D6 arquitetura) e o mapa das ondas.
2. [`ux.md`](ux.md) — **o desenho de todas as telas**. Quando uma onda e este
   arquivo discordarem, o arquivo está errado e é ele que muda primeiro.
3. [`PROGRESS.md`](PROGRESS.md) — dezesseis iterações registradas, com os erros.
   Leia pelo menos as iterações 7, 8, 10, 13, 14, 15 e 16: são armadilhas que
   vão voltar.
4. O arquivo da onda em que você vai mexer.

E antes de tocar código: `AGENTS.md`, `CLAUDE.md` e as regras em
`.claude/rules/` que o caminho do arquivo disparar.

---

## 2. Estado em 2026-08-30

Working tree limpo. `main` está **13 commits à frente de `origin/main`** — nada
foi empurrado, e empurrar é decisão do usuário.

| Commit | O quê |
|---|---|
| `3076e54e` | Onda 0 — identidade multi-aba, `Live.Surface`, `/play/:game` |
| `f0898719` | Onda 1 — `ShareLinks`, `/join/:slug`, `App.ReturnTo` |
| `ba197d38` | Onda 1 — o card na conversa |
| `b33e0963` | Onda 1 — traduções do domínio `share` nos 13 locales |
| `7dc8245a` | Onda 2 — passo 0: `App.GroupCallShape` extraído |
| `0b665bb2` | Onda 2 — passo 1: read-model de canal separado do estar-dentro |
| `5bb4091e` | Onda 2 — `CallLive` em dois hosts + `/call/:token` |
| `8bf8b202` | Onda 2 — filiação com contagem de superfícies; onda 2 fechada |
| `6b66872f` | Onda 3 — `SpaceLive` em dois hosts, `/space/:slug`, roster na antessala |
| `58c8fde5` | Onda 4A — `P2PChannel`: o fio de sinalização sai do socket do LiveView |

| Onda | Estado |
|---|---|
| 0 — identidade + `/play` | ✅ fechada |
| 1 — `/join/:slug` + card | ✅ fechada |
| 2 — conferência | ✅ fechada |
| 3 — space | ✅ fechada |
| **4A — P2P: o fio vira channel** | ✅ **fechada** (`make ci` 17/17) |
| **4B — `/p2p/:token` + sala de partida** | ⬜ **próxima** |
| 5 — jogos / lobby aberto | ⬜ |
| 6 — coordenação entre abas + bundle | ⬜ |

**O que dá para testar à mão hoje:**

* **Conferência:** canal → **Chamada** → antessala na janela com quem já está
  dentro → entrar; **Share** cria o link; o resumo ao lado de Chamada tem
  **Abrir em uma aba** → `/call/:token`.
* **Space:** canal → aba **Space** → o seletor de personagem mostra **"Lá dentro
  agora"**, **Compartilhar** e **Abrir em uma aba** → `/space/<slug>`, onde o
  mapa ocupa a janela inteira, sem botão de tela cheia, com `← Chat` e a
  contagem na barra de status.
* **P2P:** exatamente como antes da 4A — essa fase foi invisível de propósito. O
  que mudou está no DevTools: a sinalização anda num WebSocket de
  `p2p:<session_token>`, não mais no socket do LiveView.
* **Links:** qualquer um dos três colado numa conversa vira card; aberto sem
  sessão mostra o card público.

---

## 3. O próximo passo, concreto

**Fase 4B — `/p2p/:token` e a sala de partida**
([`wave-4-p2p-channel-and-surface.md`](wave-4-p2p-channel-and-surface.md),
seção "Fase 4B").

A 4A pagou o risco: o fio de sinalização já é um channel
(`RetroHexChatWeb.P2PChannel`, `p2p:<session_token>`, `Lobby.JoinToken`), e os
specs de P2P ficaram verdes sem edição. O que sobrou é a receita das ondas 2 e 3
aplicada ao P2P — com uma diferença de produto que muda o desenho.

### A ordem

1. **Separar o read-model de conversa.** O que fica no `ChatLive` é *saber que
   existe uma sessão*: o glifo na aba de PM, o badge na sidebar,
   `@p2p_pm_sessions`, o `p2p_peer_entry`, e o **convite inteiro** — que é uma
   PM de verdade, persistida, e conversa é do chat (`LobbyInvite`,
   `webrtc-p2p.md` §8.1). Vai tudo o que só existe enquanto você está na chamada.
2. **`P2PLive` nos dois hosts de uma vez.** Aninhado na janela `p2p-call` do
   chat e raiz em `/p2p/:token`. Migram: `P2PSessionConsole` e suas quatro
   seções, `App.P2PStats`, `P2PConfirmDialog` e o `p2p_setup_dialog` — que, como
   o pré-join da onda 2, vira o **primeiro estado da página** em vez de um
   diálogo do chat.
3. **A rota `/p2p/:token`** no `live_session :app_surface`, e o `kind: "p2p"`
   ligado no `JoinLive` (o domínio já aceita o kind; falta `surface_path/1` e o
   subject).

### Os três eventos que a 4A deixou para esta fase

`lobby_start_offer`, `lobby_start_answer` e `lobby_restart` continuam saindo do
LiveView, porque o payload deles carrega `ice_servers`, `role` e **`turn_only`** —
política de transporte que o host guarda e persiste. **Eles se mudam para o
channel quando o host virar o `P2PLive`**, que existe nos dois pontos de
montagem. Fazer isso é o que fecha a 4B de verdade: aí a mídia sobrevive a um
reconnect do LiveView inteiro.

`lobby_webrtc_ready` e `lobby_connected` **ficam no host para sempre**: o
primeiro carrega o handshake de reattach (estado do host), o segundo é ciclo de
vida de sessão. O motivo completo está no `wave-4` §4A.1 e na iteração 16.

### A sala de partida conserta uma ordem que hoje é invisível

Desenho: [`ux.md` §2.5](ux.md). Por P1/P7 a sessão P2P ganha host, `[Pronto]` e
`[Iniciar]`. Parece cerimônia a mais e não é: o moduledoc de
`p2p_session_events.ex` diz em maiúsculas que a sinalização só pode começar
**depois que os dois hooks reportarem ready**. O produto já tem esse momento; ele
só não tem nome, nem tela, nem forma de a pessoa saber que está esperando.

| UI | Significado técnico |
|---|---|
| `[Pronto]` de cada um | dispositivos escolhidos **e** hook de WebRTC montado |
| `[Iniciar]` do host | libera o primeiro offer — o criador é sempre o ofertante |
| "aguardando bob" | o estado em que a pessoa hoje fica sem saber por quê |

### A decisão que a onda 4 §6 deixou aberta e você vai precisar tomar

**Duas abas na mesma sessão P2P.** Diferente do SFU, não existe `rejoin` por
`previous_participant_id` aqui. A segunda aba assume ou é recusada? A
recomendação escrita é *assume*, com a primeira recebendo um aviso — mesmo
contrato do takeover de chat. Decidir com o código na frente e **testar**: o
caminho de `reattach_pending` já existe e é o mais frágil do produto.

### O `Host` finalmente se decide

A onda 2 criou `CallLive.Host` para os três desvios entre hosts (um aviso, uma
janela, e o que o host desenha). A onda 3 **não** o promoveu, porque o space não
tinha nenhum dos três — seria um módulo compartilhado com um usuário. **O P2P
tem os três.** É aqui que a decisão se paga, com três pontos de dado: ou
`CallLive.Host` sobe para `Live.SurfaceHost`, ou ganha um irmão. Não copiar.

### O que já está pronto e não se reinventa

* `RetroHexChatWeb.Live.Surface` — nickname, ban, tópico de superfícies, e o
  registro em `RetroHexChat.Surfaces` que mantém a filiação a canal viva.
* `RetroHexChatWeb.P2PChannel` + `Lobby.JoinToken` — o fio, já verde.
* `RetroHexChatWeb.SpaceRef` — como um id vira segmento de caminho **e** id de
  elemento, numa codificação só. `/p2p/:token` usa o token direto, então aqui
  serve de modelo e não de dependência.
* `RetroHexChatWeb.ChatLive.SpaceEvents` — o padrão menor, para uma superfície
  que só precisa mandar duas mensagens para cima.
* `RetroHexChatWeb.ChatLive.SpaceReadModel` e `GroupCallReadModel` — a régua
  aplicada duas vezes.
* A âncora `#lobby-webrtc` **mantém esse id exato**: os hooks de mídia, jogo e
  transferência de arquivo localizam a `RTCPeerConnection` compartilhada por
  ele. Ela muda de página, não de nome.

### As coisas que vão se repetir

* **`live_render/3` embrulha o filho numa div sem altura.** Passe
  `container: {:div, class: …}` com a cadeia de flex/altura que o pai espera.
* **Dois hosts na tela ao mesmo tempo precisam de ids diferentes.**
* **Um clique num filho tem que ser mirado no filho.** `has_element?(pai, …)`
  enxerga o markup do filho, mas `render_click(pai, …)` não chega aos handlers
  dele — pegue o `live_children/1` do módulo.
* **Nunca asserir num `render/1` depois de um salto assíncrono.** Espere a
  mensagem (`assert_receive` no tópico) e depois drene o processo com
  `:sys.get_state`. Um teste assim passa cinco vezes local e cai no `make ci`,
  que roda partições em paralelo — foi o que aconteceu na iteração 16.

E as da §5, que não são desta onda mas mordem em todas: a sequência fixa antes do
gate, o `grep -c ', fuzzy'` depois de todo merge de gettext, e o Dialyzer que só
olha quando o PLT está quente.

---

## 4. O que ainda morde

1. ~~**Identificação é um assign do `ChatLive`.**~~ **Resolvido** (iteração 13):
   `Services.NickServ.identified?/1` mantém o conjunto em runtime e o assign do
   chat é espelho dele, então a superfície pergunta ao domínio.

2. ~~**A filiação a canal some quando o chat fecha.**~~ **Resolvido**
   (iteração 14): `RetroHexChat.Surfaces` conta as superfícies abertas por
   nickname e o chat entrega a saída dos canais quando não é a última. Duas
   coisas para não reaprender: um `live_render/3` aninhado **não** passa pelo
   `on_mount` do `live_session`, então a janela do chat não é uma superfície; e
   um chat que quebra nunca entrega nada, o que está escrito no `@moduledoc` em
   vez de corrigido.

3. **A suíte de P2P não roda em Firefox — e o motivo não é o produto.**
   `browser.newContext({ permissions: ["microphone"] })` responde `Unknown
   permission: microphone` no Playwright/Firefox, então os 9 testes de mídia de
   `chat-p2p.spec.ts` morrem em 57 ms cada, antes de abrir uma página. A suíte é
   Chromium **por construção**.
   O que dá para verificar sem permissão de mídia é o transporte: um spec
   descartável que observa os frames do WebSocket (join no canal, offer sai,
   answer volta, ninguém recusado) roda nos dois motores. Foi o que a 4A fez, e
   é o que a 4B deve repetir. ICE/DTLS no Firefox continua sem cobertura.

4. **Dois testes Playwright estão vermelhos desde antes desta sessão.**
   `chat-p2p.spec.ts` "the inviter cancels a pending invite from the status bar"
   e o par do group call: a janela maximizada cobre a barra de status do chat e
   o clique não alcança. Verificado com `git stash` nas duas ondas — falham
   iguais no `HEAD` anterior. Playwright não está no `make ci`, então a suíte
   derivou. Não perca tempo achando que foi você; se quiser consertar, é um
   trabalho de z-index e vale um commit próprio.

5. **`clipboard_copy` só existe no chat.** É tratado pelo `chat_viewport_hook`;
   um `push_event` desses numa aba satélite não tem quem receba. Copiar de
   verdade precisa de um hook agnóstico de superfície — a lib de coordenação da
   onda 6 é o lugar. Por isso a `share_bar` mostra um campo readonly em vez de
   um botão Copiar.

---

## 5. Armadilhas que já custaram tempo neste plano

**Sequência fixa antes do gate.** Três sessões caíram na mesma:

```
mix format  →  make i18n.gettext.extract  →  make ci
```

`extract` vai **sempre**, inclusive quando "só movi código" — mover código muda
as referências `#:` do `.pot` e reprova `i18n Catalog Coverage`.

**Merge de gettext só em domínio com msgid novo ou removido.** Mesclar um
domínio que só tem drift de referência reescreve um arquivo por locale e o
fuzzy matching **inventa traduções erradas** — foi assim que `%{count} charts`
recebeu a tradução de `%{count} cores` em 9 locales. Recuperação:
`git stash push -- <paths>`, nunca `git checkout`.

**Um domínio gettext novo precisa ser semeado.** O script de merge casa `.po`
existente com `.pot` e pula um domínio inédito. Receita: copiar o bloco de
cabeçalho do `ui.po` de cada locale para o `<novo>.po`, mesclar, e **corrigir a
primeira linha de comentário**, que vem apontando para `ui.pot`.

**Toda rota pública vai dentro do laço de locales do router.** `/join/:slug`
nasceu só sem prefixo e deu `NoRouteError` em `/pt-BR/join/...`. Dezesseis testes
não pegaram porque todos construíam o caminho do mesmo jeito que o código.
`App.ReturnTo` e `ShareLinkRef` leem `SEO.localized_locale_segments/0` pelo mesmo
motivo.

**O exit code do `make ci` não é o do job em background.** Um `; grep` no fim da
cadeia devolve o status do `grep`. Ler `CI_EXIT` do log, sempre.

**Dialyzer só roda com o PLT quente, e ele vê o que o compilador não vê.** Ele
apareceu como `○ Dialyzer` (skipped) em três `make ci` seguidos e, quando
finalmente rodou, pegou duas cláusulas inalcançáveis na 4A — um guard e um
catch-all que os tipos garantiam que nunca seriam alcançados. Um `make ci` que
pulou o Dialyzer não olhou para isso ainda.

**Um teste que passa cinco vezes local pode cair no `make ci`.** O gate roda
partições em paralelo, e foi assim que um `render/1` logo depois de três saltos
assíncronos caiu. Espere a mensagem (`assert_receive` no tópico) e depois drene
o processo com `:sys.get_state`.

**Depois de todo `gettext.merge`: `grep -c ', fuzzy'`.** O merge relata
"0 reworded (fuzzy)" e mesmo assim marca entradas novas como fuzzy com a
tradução de uma frase parecida. Na onda 3, `A space on RetroHexChat` virou "Um
jogo no RetroHexChat" em 13 locales.

**Um script que preenche `.po` tem que preservar a última quebra de linha.**
Reescrever o arquivo sem ela produz `\ No newline at end of file` em 84
arquivos e polui o diff inteiro.

**`live_render` embrulha o filho numa div sem altura.** Um `h-full` dentro dela
resolve contra ela, não contra o corpo da janela: passe
`container: {:div, class: "h-full min-h-0"}`. Nenhum teste vê isso; só o
screenshot.

**Dois hosts renderizando o mesmo LiveComponent precisam de ids diferentes.**
Ids são únicos no documento, não por LiveView, e a chamada embutida põe os dois
na tela ao mesmo tempo. Derive os `data-testid` internos do `id` em vez de
escrevê-los literais.

---

## 6. Como o usuário quer que se trabalhe

Instruções que ele deu explicitamente, além do `AGENTS.md`:

* **Não parar para perguntar.** Implementar até haver algo que ele possa testar
  de ponta a ponta. Numa sessão anterior ele teve que repetir "prosseguir"
  quatro vezes; não repita isso. Uma fase inteira (transporte + testes + docs +
  gate + commit) é a unidade, não um passo dela.
* **Registrar progresso e aprendizados a cada iteração** no `PROGRESS.md`,
  incluindo os erros e como foram recuperados.
* **Tela nova ganha screenshot antes de dizer que fechou.** Regra criada depois
  de ele reclamar que o card estava "horrivelmente feio, sem ícones". Um spec
  Playwright descartável, ler as imagens, apagar o spec. Já pegou seis defeitos
  que teste nenhum pegaria — a janela de altura zero, o card duplicado, a
  antessala ocupando metade da janela, a barra Share solta no canto, o botão
  Compartilhar e o link "Abrir em uma aba" com alturas diferentes, e a URL que
  some junto com a antessala.
  **A 4B tem tela nova** (a sala de partida), então esta regra vale inteira.
* **Commit direto na `main`**, com `git fetch` + `pull --ff-only` antes e
  staging de caminhos exatos. Push só quando ele pedir.

---

## 7. Comandos que você vai usar

```sh
make ci                      # gate final; ler CI_EXIT do log, não o do shell
mix test <arquivo>           # iteração
make e2e.catalog             # depois de criar spec Playwright com @flow

# E2E direcionado (nunca a suíte inteira):
MIX_ENV=e2e PGPORT=5433 E2E_PORT=4003 mix assets.build
lsof -ti:4003 | xargs kill -9
cd e2e && MIX_ENV=e2e PGPORT=5433 E2E_PORT=4003 \
  E2E_BASE_URL=http://localhost:4003 BASE_URL=http://localhost:4003 \
  PUBLIC_ORIGIN=http://localhost:4003 npx playwright test tests/<spec> --retries=0
```

**Firefox não é um project do `playwright.config.ts`.** Para rodar um spec
descartável nele, adicione um project temporário e **restaure o arquivo depois**:

```js
{ name: "firefox", testIgnore: /.*mobile.*\.spec\.ts/, use: { ...devices["Desktop Firefox"] } },
```

**Verificar se uma falha de E2E é sua:** `git stash push -u`, rodar o mesmo spec,
`git stash pop`. Duas ondas já usaram isso para provar que a falha era
pré-existente — vale os dois minutos antes de caçar um bug que não é seu.

---

## 8. O que continua em aberto para o usuário decidir

1. **Guest pass** — hoje o link carrega identidade da sala, nunca autorização
   (D1). Um link de conferência só funciona para quem já é membro do canal, o
   que limita muito o alcance social. Merece plano próprio, com moderação junto.
2. **Start menu nas satélites** — hoje toda tela do WM carrega a lista inteira,
   +177 nós por tela. `/play` nasceu sem taskbar nenhuma; decidir na onda 6.
3. **Rate limit de criação de share link** — deixado de fora de propósito: já
   existem três cópias da janela deslizante em ETS no repositório, e a quarta
   seria o fork que o Princípio XII proíbe. Entra junto com a extração da comum.

---

## 9. O prompt para abrir a próxima sessão

Cole isto numa sessão com o contexto limpo. Ele é curto de propósito: o que ele
precisa dizer está neste arquivo, e o resto é a ordem de leitura.

```
Retomando a implementação do plano de superfícies compartilháveis no
retro_hex_chat. As ondas 0 a 3 e a fase 4A fecharam; começa a fase 4B.

Leia, nesta ordem:
1. docs/plans/shareable-surfaces/HANDOVER.md  — estado, próximo passo, armadilhas
2. docs/plans/shareable-surfaces/README.md    — decisões travadas (P1–P7, D1–D6)
3. docs/plans/shareable-surfaces/ux.md        — o desenho de todas as telas
4. docs/plans/shareable-surfaces/wave-4-p2p-channel-and-surface.md — a seção
   "Fase 4B" é o alvo; leia a 4A também, porque ela explica o que já saiu do
   LiveView e o que ficou de propósito
5. docs/plans/shareable-surfaces/PROGRESS.md  — pelo menos as iterações 7, 8,
   10, 13, 14, 15 e 16: são armadilhas que vão voltar

E antes de tocar código: AGENTS.md, CLAUDE.md e as regras em .claude/rules/ que
o caminho do arquivo disparar.

O próximo passo está na seção 3 do HANDOVER. A 4A já tirou a sinalização do
socket do LiveView (P2PChannel em p2p:<session_token>), então a 4B é a receita
das ondas 2 e 3: separar o read-model de conversa (o convite inteiro FICA no
chat — é uma PM de verdade), depois P2PLive nos dois hosts de uma vez com o
p2p_setup_dialog virando o primeiro estado da página, depois a rota /p2p/:token
e o kind "p2p" no JoinLive.

Três coisas específicas desta fase, todas na seção 3 do HANDOVER:
- lobby_start_offer / lobby_start_answer / lobby_restart se mudam para o
  channel agora, junto com o host que é dono do turn_only;
- a antessala é uma SALA DE PARTIDA (host, [Pronto], [Iniciar]) e ela dá nome a
  uma regra que hoje é invisível: a sinalização só começa quando os dois hooks
  reportam ready;
- decida com o código na frente o que acontece com duas abas na mesma sessão
  P2P (a recomendação escrita é "a segunda assume"), e teste — reattach_pending
  é o caminho mais frágil do produto.

Como trabalhar, e isto não é negociável:
- Não pare para pedir permissão entre passos. Implemente até haver algo
  testável de ponta a ponta pelo usuário.
- Registre cada iteração no PROGRESS.md, incluindo os erros e como foram
  recuperados.
- Toda tela nova ganha screenshot (spec Playwright descartável) antes de
  você dizer que fechou. A sala de partida é tela nova.
- Sequência fixa antes do gate: mix format → make i18n.gettext.extract →
  make ci. Leia a linha "Results:" do log, não o exit code do shell.
- Commit direto na main, com git fetch + pull --ff-only antes e staging de
  caminhos exatos. Não faça push.
```
