# Handover — superfícies compartilháveis

Escrito em 2026-08-28, atualizado em 2026-08-31 (fim da onda 5) para retomar o
trabalho com contexto zerado. Apagar quando a onda 6 fechar.

---

## 1. Leia nesta ordem

1. [`README.md`](README.md) — a análise, as decisões travadas (P1–P7 produto,
   D1–D6 arquitetura) e o mapa das ondas.
2. [`ux.md`](ux.md) — **o desenho de todas as telas**. Quando uma onda e este
   arquivo discordarem, o arquivo está errado e é ele que muda primeiro.
3. [`PROGRESS.md`](PROGRESS.md) — vinte e uma iterações registradas, com os
   erros. Leia pelo menos as iterações 7, 8, 10, 13, 14, 15, 17, 18 e 21: são
   armadilhas que vão voltar.
4. O arquivo da onda em que você vai mexer.

E antes de tocar código: `AGENTS.md`, `CLAUDE.md` e as regras em
`.claude/rules/` que o caminho do arquivo disparar.

---

## 2. Estado em 2026-08-31 (fim da onda 5)

Working tree limpo. `main` está **22 commits à frente de `origin/main`** — nada
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
| `725de14b` | Onda 4B — `P2PLive` nos dois hosts, `/p2p/:token`, a sala de partida e o takeover |
| `132affdf` | Onda 4B — o handover aponta para a onda 5 |
| `04f8575f` | Onda 4B — o portão de identificação, o `p2p-surface.spec.ts` e o epoch por página; **onda 4 fechada** |
| `20f1df60` | Onda 4 — o handover carrega o mapa e a ordem |
| `ecf42368` | Onda 5 — o lobby aberto no domínio: `peer_id` nulo, escrita condicional, job de expiração |
| `de125b99` | Onda 5 — a partida ganha endereço, o card ganha "vaga preenchida", o Arcade vira âncora |
| _(este)_ | Onda 5 — o diário e o handover; **onda 5 fechada** |

| Onda | Estado |
|---|---|
| 0 — identidade + `/play` | ✅ fechada |
| 1 — `/join/:slug` + card | ✅ fechada |
| 2 — conferência | ✅ fechada |
| 3 — space | ✅ fechada |
| 4A — P2P: o fio vira channel | ✅ fechada |
| 4B — `/p2p/:token` + sala de partida | ✅ fechada |
| **5 — jogos / lobby aberto** | ✅ **fechada** — as 13 linhas da tabela de TDD, `make ci` 17/17 com Dialyzer |
| **6 — coordenação entre abas + bundle** | ⬜ **próxima** |

**O que dá para testar à mão hoje:**

* **Conferência:** canal → **Chamada** → antessala na janela com quem já está
  dentro → entrar; **Share** cria o link; o resumo ao lado de Chamada tem
  **Abrir em uma aba** → `/call/:token`.
* **Space:** canal → aba **Space** → o seletor de personagem mostra **"Lá dentro
  agora"**, **Compartilhar** e **Abrir em uma aba** → `/space/<slug>`, onde o
  mapa ocupa a janela inteira, sem botão de tela cheia, com `← Chat` e a
  contagem na barra de status.
* **P2P:** `/p2p <nick>` manda o convite na hora e abre a **sala de partida** —
  quem está na sala, a prévia da câmera, os dispositivos, `[Pronto]`, e
  `[Iniciar]` só para quem convidou. Do lado do convidado, **Entrar** no
  cabeçalho da PM leva à mesma sala. Depois do `[Iniciar]` vem o console de
  sempre. Na sala há **Compartilhar** e **Abrir em uma aba** → `/p2p/<token>`;
  abrir a sessão numa segunda janela a **move** para lá, e a que perdeu mostra
  "esta sessão está aberta em outra janela sua" com **Trazer de volta pra cá**.
  O endereço exige registrado **e** identificado, e recusa quem não é
  participante — com a frase da política, não uma tela genérica.
* **Partida:** Retro Games → escolha um jogo → **Jogar com alguém**. Você cai
  na **sala de partida do jogo** — o jogo no lugar dos dispositivos, a cadeira
  vazia dizendo "quem entrar / vaga aberta", e `[Compartilhar]`,
  `[Cancelar]` (só do host), `[Pronto]` e `[Iniciar]`. Cole o link numa conversa:
  quem seguir ocupa a vaga, os dois apertam Pronto, e o `[Iniciar]` do host
  começa **o jogo que o link nomeou**, sem aceitar nada. Um terceiro clique no
  mesmo link lê "vaga preenchida". Um link que ninguém segue morre sozinho em
  quinze minutos; `[Cancelar]` mata na hora.
* **Arcade:** Games (ícone do desktop) → **Arcade...** → um jogo → **Start
  Game** abre `/play/arcade/<jogo>` numa aba com `noopener`. Fechar essa aba não
  encerra mais a sessão.
* **Links:** qualquer um dos quatro colado numa conversa vira card; aberto sem
  sessão mostra o card público.

---

## 2.1 O mapa do que existe, para você não ter que grepar

Quatro superfícies, todas o mesmo padrão: **um módulo, dois pontos de montagem**
(raiz numa rota própria, filho via `live_render/3` numa janela do chat).

| Superfície | Rota | Módulo | O que o chat guarda |
|---|---|---|---|
| jogo solo | `/play`, `/play/:game` | `App.PlayLive` | nada |
| conferência | `/call/:token` | `App.CallLive` (+ `CallLive.Events`) | `ChatLive.GroupCallReadModel` |
| space | `/space/:slug` | `App.SpaceLive` | `ChatLive.SpaceReadModel` + `SpaceEvents` |
| sessão P2P | `/p2p/:token` | `App.P2PLive` (+ `P2PLive.Events`) | `ChatLive.P2PReadModel` |
| partida | `/play/:game/:token` | `App.P2PLive` — a **mesma** superfície, aberta na seção de jogo | idem (e nada, enquanto a vaga está aberta) |
| arcade | `/play/arcade/:game` | `App.ArcadeGameController` — redirect, não é LiveView | `@arcade_session` |

As rotas raiz vivem todas no `live_session :app_surface` do router, com
`Live.Surface` no `on_mount` — nickname, ban, tópico de superfícies e o registro
em `RetroHexChat.Surfaces` que mantém a filiação a canal viva quando o chat
fecha. **Um `live_render/3` aninhado não passa pelo `on_mount`**, então a janela
do chat não é uma superfície: só a rota é.

A régua que separou cada read-model, aplicada quatro vezes e válida para a
quinta: **se o dado existe para quem só está olhando a conversa, ele fica no
chat; se só existe enquanto você está dentro, vai para a superfície.**

O que diverge entre os dois hosts passa por `Live.SurfaceHost`, e é sempre a
mesma lista curta: um aviso, a janela, a geometria, e o que o host desenha.

**Sinalização:** conferência (`group_call:<token>`), space (`space:*`) e P2P
(`p2p:<session_token>`) são Phoenix Channels crus, autenticados por token
assinado com salt próprio. Nenhuma passa pelo socket do LiveView. O que fica no
LiveView é o que carrega política de transporte — `ice_servers`, `role`,
`turn_only` — e o ciclo de vida da sessão.

**Links:** `RetroHexChat.ShareLinks` minta um slug opaco por superfície;
`/join/:slug` é a única rota pública, roda no pipeline do landing e resolve o
slug para "que sala é esta" — nunca para autorização (D1). Os kinds hoje são
`call`, `space`, `p2p` e `play`; um `play` com `session_token` no alvo é uma
**partida**, e é o único kind que morre por sucesso (`Liveness` pergunta se a
cadeira ainda está vazia).

**Lobby aberto:** uma sessão `open` é uma linha e um prazo — **sem GenServer**.
A cadeira é tomada por *uma escrita condicional* (`Queries.claim_open_session/3`),
o processo nasce na reivindicação, e `Jobs.OpenLobbyExpiryWorker` varre a cada
cinco minutos o que ninguém reivindicou. `docs/guide/webrtc-p2p.md` §8.1 é a
descrição durável disso.

---

## 3. O próximo passo, concreto

**Onda 6 — coordenação entre abas, bundle medido, e fechar o plano**
([`wave-6-cross-tab-and-bundle.md`](wave-6-cross-tab-and-bundle.md)).

### A ordem, se você não tiver motivo para outra

1. **A coordenação entre abas**, que é a que desbloqueia tudo o que ficou meio
   feito. `RetroHexChat.Surfaces` já conta superfícies abertas por nickname
   desde a onda 2 §2.6 — ele **é** a fonte da verdade, e `BroadcastChannel`
   entra só para *tentar* trazer a aba pra frente. Leia a §1.1 da onda antes de
   escrever: o contrato já está escrito, incluindo o que fazer quando
   `window.focus()` é bloqueado (é, com frequência).
2. **O que isso conserta de verdade**, e que hoje é dívida em três lugares:
   * o `← Chat` de toda superfície navega para `/chat` em vez de focar a aba que
     já existe — está escrito assim, com o porquê, em três módulos;
   * `clipboard_copy` só existe no chat, então a `share_bar` mostra um campo
     readonly em vez de um botão Copiar (§4.5 abaixo);
   * o fim de uma sessão de arcade deixou de ter aviso quando a aba do jogo
     fecha (onda 5 trocou o poll por `noopener`).
3. **O bundle, com o número na mão** (§2 da onda). "Não dividir" é resultado
   legítimo e precisa ser aceitável **antes** de medir, senão a medição é
   teatro.
4. **O Start menu nas satélites** (§2.3): +177 nós por tela × quatro satélites.
   A recomendação escrita é "satélite carrega só o que alcança"; decidir e
   escrever a exceção.
5. **A convergência** (§3.1): grep por **símbolo**, nunca por nome de arquivo —
   "0 referências" já foi falso neste repositório exatamente por isso.
6. **Mover as regras duráveis para os guias, e só então apagar este diretório.**
   A tabela da §3.2 diz o que vai para onde. A linha de `guide/webrtc-p2p.md`
   §8.1 sobre o estado `open` **já foi feita** na onda 5.

### O que a onda 5 deixou pronto e a 6 herda

* **`Surfaces` já conta**, e o teste que prova é `surfaces_test.exs`. A onda 6
  não constrói o registro: ela o **lê** para decidir abrir contra focar.
* **`noopener` está em todo lugar agora**, incluindo o Arcade. Isso é o que
  torna `BroadcastChannel` a única opção — e é também o que tirou o
  `arcade_session_hook.js` do repositório, item da §3.1 já cumprido.
* **Um lobby aberto não tem processo.** Se a onda 6 for contar "o que você tem
  aberto", uma partida esperando por alguém é uma linha no banco e não uma
  superfície — o `P2PReadModel` já pula `open` no mount por esse motivo.
* **Os quatro `PerfBudgets` estão medidos** (`:play`, `:call`, `:space`,
  `:p2p`), que é a mesa que a decisão do Start menu precisa.

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
   answer volta, ninguém recusado) roda nos dois motores. Foi o que a 4A fez.
   ICE/DTLS no Firefox continua sem cobertura.

4. **Cinco testes Playwright estão vermelhos, e nenhum é desta sessão.**
   Medidos em 2026-08-31 e **verificados no commit `0e052ba9`** (o estado em que
   esta sessão começou), rodando os mesmos specs lá: falham iguais.

   | Spec | Teste | Família |
   |---|---|---|
   | `chat-group-call.spec.ts` | two identified channel users join the same SFU call | mídia/z-index |
   | `chat-group-call.spec.ts` | pre-join can enter with microphone and camera disabled | pré-join |
   | `chat-group-call.spec.ts` | pre-join permission denial can retry and still enter receive-only | pré-join |
   | `chat-p2p.spec.ts` | the inviter cancels a pending invite from the status bar | z-index |
   | `chat-call-fault-injection.spec.ts` | P2P answerer reloads while applying the initial offer | recuperação |

   Duas causas conhecidas: **a janela maximizada cobre a barra de status do
   chat** e o clique não alcança (trabalho de z-index, vale um commit próprio);
   e **recuperação de mídia depois de um reload no meio do primeiro offer** —
   metade dessa foi corrigida na iteração 18 (o epoch é por página), mas sobra
   coisa. A iteração 13 já registrava um helper de pré-join procurando uma chave
   de `localStorage` que **não existe em lugar nenhum do repositório**.

   **A mesma limitação de recuperação vale para assumir uma sessão já conectada
   numa segunda aba:** o assento se move e a janela deslocada avisa, mas a mídia
   não volta sozinha. `[Trazer de volta pra cá]` devolve o assento, então não é
   um beco — é uma renegociação que ainda não fecha.

   Playwright não está no `make ci`, então a suíte derivou. Não perca tempo
   achando que foi você; use a receita da §7 antes de caçar.

5. **`clipboard_copy` só existe no chat.** É tratado pelo `chat_viewport_hook`;
   um `push_event` desses numa aba satélite não tem quem receba. Copiar de
   verdade precisa de um hook agnóstico de superfície — a lib de coordenação da
   onda 6 é o lugar. Por isso a `share_bar` mostra um campo readonly em vez de
   um botão Copiar.

6. **Dois specs de jogos estavam vermelhos por seletor velho, e foram
   consertados na onda 5.** `Games` saiu da barra de menus e virou **pasta no
   desktop**, então `app-menu-games`, `desktop-shortcut-retro-games` e
   `desktop-shortcut-arcade` não existiam mais. O `ChatPage` ganhou
   `openGamesFolder()`. Registro porque a lição é geral: **quando um spec falha
   no primeiro clique, suspeite do seletor antes da feature** — e meça no `HEAD`
   com `git stash push -u` antes de caçar.

7. **`i18n.catalog.check` reprova no `HEAD` e não está no `make ci`.** 74
   arquivos com entradas vazias em 2026-08-31 (eram 88 antes da onda 5). O que
   o gate cobra é `i18n.gettext.check` — `.pot` fresco — mais `i18n Quality`.
   Mesclar um domínio traz a deriva alheia dele para dentro do `.po` como
   entradas vazias: **é o preço de mesclar**, e o mínimo a pagar são as que
   carregam `%{...}`, porque `i18n_placeholder_check` reprova essas.

8. **Fim de sessão de arcade não tem mais aviso quando a aba do jogo fecha.**
   `noopener` não deixa referência para pollar; é o custo aceito, escrito na
   onda 5 §2.5. A sessão termina por **End Session** ou pelo timeout de
   inatividade do `SoloSessionServer`. A coordenação da onda 6 é onde isso
   volta a ser possível, se valer a pena.

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

**Um `.po` parado vira dívida sua no momento em que você mescla o domínio.**
`gettext.merge` é por domínio, não por msgid: mesclar `p2p` trouxe vinte e duas
entradas que estavam no `.pot` havia meses e nunca tinham sido mescladas, todas
vazias — e o `i18n Placeholder` reprovou nas que tinham `%{...}`. Traduzir o que
o merge trouxe é o preço de mesclar, e é o que a iteração 13 já tinha pago para
o `group_call`.

**Um `data-testid` literal num componente que dois hosts renderizam é um
duplicado esperando.** Aconteceu com o diálogo de confirmação do P2P exatamente
como com os ids internos do group call na iteração 13. Derive do `id`.

**Markup que muda de dono continua falando o nome antigo.** O botão End do
console empurrava `p2p_statusbar_stop` — evento do chat — depois de o console
passar a viver dentro da superfície. Nada quebra em compilação, nada quebra no
ExUnit; o clique simplesmente não faz nada. Ao mover markup entre processos,
listar os eventos que ele emite e conferir quem os trata agora.

**O `signalingEpoch` do WebRTC é por página, e uma aba nova começa do um.**
`isStaleEpoch(current, epoch) = epoch && current > 0 && epoch < current`. O par
que ficou de pé já avançou o dele, então **toda** oferta de uma página
recém-aberta lia como stale, para sempre — é o que fazia o takeover não trazer a
mídia de volta. Um `offer` com `connection_reset: true` agora atravessa a
guarda, e quem começa dentro de uma sessão que já corre anuncia o rebuild. Se
mexer nessa parte: o vitest de `lobby_connection.js` é onde isso está fixado.

**Um spec pode provar o que o plano não pediu, e falhar por isso.** A primeira
versão do `p2p-surface.spec.ts` conectava no chat e migrava a chamada a quente
para o endereço; a onda pedia mídia/arquivo/jogo **na superfície**. Escrito na
forma que a pessoa realmente encontra (abrir o endereço **antes** de iniciar),
ficou verde na primeira tentativa. Antes de caçar um bug, reler a linha da
tabela de TDD que você está tentando satisfazer.

**"Registrado" e "identificado" não são a mesma pergunta.** `/p2p/:token` exigia
registrado e participante — e ser participante é gravado como um id de
`registered_nicks`, então quem apenas segurasse o apelido entrava na sessão de
quem é dono dele. Toda superfície nova faz as três perguntas em ordem: existe,
quem é você (registrado → identificado), e o que a política do domínio diz.

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
  Playwright descartável, ler as imagens, apagar o spec. Já pegou nove defeitos
  que teste nenhum pegaria — a janela de altura zero, o card duplicado, a
  antessala ocupando metade da janela, a barra Share solta no canto, o botão
  Compartilhar e o link "Abrir em uma aba" com alturas diferentes, a URL que
  some junto com a antessala, a prévia de câmera esticada em 440 px de preto, o
  rodapé flutuando numa janela maximizada quase vazia, e a barra de título
  dizendo "Joining… / Ready" sobre uma conexão que ainda não existia.
* **Conferir a tabela de TDD da onda antes de dizer que ela fechou.** Ele
  perguntou "podemos declarar concluída de fato?" no fim da onda 4, e a resposta
  honesta era não: 11 das 13 linhas estavam feitas. Uma das quatro que faltavam
  era um buraco de autorização, não um teste. Conferir linha por linha custa
  cinco minutos e é a diferença entre fechar e dizer que fechou.
* **Commit direto na `main`**, com `git fetch` + `pull --ff-only` antes e
  staging de caminhos exatos. Push só quando ele pedir.

---

## 7. Comandos que você vai usar

```sh
make server                  # Phoenix em :4000, para olhar a coisa funcionando
make ci                      # gate final; ler CI_EXIT do log, não o do shell
mix test <arquivo>           # iteração
make e2e.catalog             # depois de criar spec Playwright com @flow
cd apps/retro_hex_chat_web/assets && npx vitest run test/lib/p2p/   # o JS de P2P

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

**Verificar se uma falha de E2E é sua.** Duas receitas, e a diferença importa:

* **Trabalho ainda não commitado:** `git stash push -u`, rodar o spec,
  `git stash pop`.
* **Trabalho já commitado:** o stash não faz nada — a árvore já está no seu
  commit, e o teste roda *com* a sua mudança. Use um checkout destacado no
  commit em que a sessão começou:

  ```sh
  git switch --detach <commit-base>     # `git checkout` é bloqueado por um hook
  MIX_ENV=e2e PGPORT=5433 E2E_PORT=4003 mix assets.build
  # rodar o spec
  git switch main
  MIX_ENV=e2e PGPORT=5433 E2E_PORT=4003 mix assets.build   # NÃO esquecer
  ```

  Eu caí na primeira versão nesta sessão e quase escrevi "verificado" sobre uma
  medição que não mediu nada. **Rebuildar os assets nos dois sentidos** — voltar
  para `main` com os assets do commit antigo servidos é a armadilha do
  `:4003` que a §5 já registra em outra forma.

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
   **A onda 5 força a mão:** um lobby aberto sem rate limit de criação é spam de
   sessão, e a própria onda lista isso como mitigação obrigatória desde o
   primeiro commit. Ou a comum sai antes, ou a decisão volta para a mesa.

---

## 9. O prompt para abrir a próxima sessão

Cole isto numa sessão com o contexto limpo. Ele é curto de propósito: o que ele
precisa dizer está neste arquivo, e o resto é a ordem de leitura.

```
Retomando a implementação do plano de superfícies compartilháveis no
retro_hex_chat. As ondas 0 a 5 fecharam; começa a onda 6, que é a última.

Leia, nesta ordem:
1. docs/plans/shareable-surfaces/HANDOVER.md  — estado, mapa, próximo passo, armadilhas
2. docs/plans/shareable-surfaces/README.md    — decisões travadas (P1–P7, D1–D6)
3. docs/plans/shareable-surfaces/ux.md        — o desenho de todas as telas
4. docs/plans/shareable-surfaces/wave-6-cross-tab-and-bundle.md — o alvo, inteiro
5. docs/plans/shareable-surfaces/PROGRESS.md  — pelo menos as iterações 7, 8,
   10, 13, 14, 15, 17, 18 e 21: são armadilhas que vão voltar

E antes de tocar código: AGENTS.md, CLAUDE.md e as regras em .claude/rules/ que
o caminho do arquivo disparar.

A seção 2.1 do HANDOVER é o mapa do que já existe — use-o em vez de grepar. A
seção 3 tem a ordem de ataque; siga-a se não tiver motivo para outra.

Três coisas específicas desta onda:
- a fonte da verdade de "o que você tem aberto" é RetroHexChat.Surfaces, que já
  existe desde a onda 2 — BroadcastChannel entra só para TENTAR trazer a aba
  pra frente, e window.focus() de uma aba em segundo plano é bloqueado com
  frequência: degradar bem é o requisito, focar é o bônus;
- "não dividir o bundle" é um resultado legítimo e precisa ser aceitável ANTES
  de medir, senão a medição é teatro;
- esta é a onda que apaga o diretório do plano, e as regras duráveis têm que
  estar movidas para os guias ANTES disso — a tabela da §3.2 da onda diz o que
  vai para onde.

Como trabalhar, e isto não é negociável:
- Não pare para pedir permissão entre passos. Implemente até haver algo
  testável de ponta a ponta pelo usuário.
- Registre cada iteração no PROGRESS.md, incluindo os erros e como foram
  recuperados.
- Toda tela nova ganha screenshot (spec Playwright descartável, ou shot() num
  spec permanente) antes de você dizer que fechou.
- Antes de declarar a onda concluída, confira linha por linha a tabela de TDD
  dela e a lista de obrigações do repositório. Nas ondas 4 e 5 essa conferência
  achou buracos que não eram testes — na 5, um invariante de changeset e uma
  regra de produto (P7) sem caminho pela tela.
- Sequência fixa antes do gate: mix format → make i18n.gettext.extract →
  make ci. Leia a linha "Results:" do log, não o exit code do shell.
- Commit direto na main, com git fetch + pull --ff-only antes e staging de
  caminhos exatos. Não faça push.
```
