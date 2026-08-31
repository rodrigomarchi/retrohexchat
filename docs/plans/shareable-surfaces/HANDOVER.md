# Handover — superfícies compartilháveis

Escrito em 2026-08-28, atualizado em 2026-08-30 (fim da onda 4) para retomar o
trabalho com contexto zerado. Apagar quando a onda 6 fechar.

---

## 1. Leia nesta ordem

1. [`README.md`](README.md) — a análise, as decisões travadas (P1–P7 produto,
   D1–D6 arquitetura) e o mapa das ondas.
2. [`ux.md`](ux.md) — **o desenho de todas as telas**. Quando uma onda e este
   arquivo discordarem, o arquivo está errado e é ele que muda primeiro.
3. [`PROGRESS.md`](PROGRESS.md) — dezessete iterações registradas, com os erros.
   Leia pelo menos as iterações 7, 8, 10, 13, 14, 15, 16 e 17: são armadilhas que
   vão voltar.
4. O arquivo da onda em que você vai mexer.

E antes de tocar código: `AGENTS.md`, `CLAUDE.md` e as regras em
`.claude/rules/` que o caminho do arquivo disparar.

---

## 2. Estado em 2026-08-30

Working tree limpo. `main` está **15 commits à frente de `origin/main`** — nada
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
| `725de14b` | Onda 4B — `P2PLive` nos dois hosts, `/p2p/:token`, a sala de partida e o takeover; onda 4 fechada |

| Onda | Estado |
|---|---|
| 0 — identidade + `/play` | ✅ fechada |
| 1 — `/join/:slug` + card | ✅ fechada |
| 2 — conferência | ✅ fechada |
| 3 — space | ✅ fechada |
| 4A — P2P: o fio vira channel | ✅ fechada |
| **4B — `/p2p/:token` + sala de partida** | ✅ **fechada** (`make ci` 17/17) |
| **5 — jogos / lobby aberto** | ⬜ **próxima** |
| 6 — coordenação entre abas + bundle | ⬜ |

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
* **Links:** qualquer um dos três colado numa conversa vira card; aberto sem
  sessão mostra o card público.

---

## 3. O próximo passo, concreto

**Onda 5 — jogos** ([`wave-5-games-surfaces.md`](wave-5-games-surfaces.md)).

A onda 4 fechou, e com ela as três superfícies difíceis. O que a 5 pede é a
mesma receita sobre a base que agora existe: `/play/:game` já é uma superfície
desde a onda 0, e o que falta é o multiplayer — um jogo entre duas pessoas roda
sobre a `RTCPeerConnection` da sessão P2P, que agora tem endereço próprio.

### O que a onda 4 deixou pronto e a 5 herda

* **`RetroHexChatWeb.Live.SurfaceHost`** — os quatro verbos (`error`, `system`,
  `focus`, `close`, mais `geometry`) e o `publish/2` que entrega ao host o pouco
  que ele desenha. Cada mensagem carrega a *tag* da superfície, porque o chat já
  hospeda duas ao mesmo tempo. Uma superfície nova declara `surface_tag:` no
  mount e não escreve mais nada disso.
* **A sala de partida** (`Components.UI.P2P.StartingRoom`) é o desenho de P1 para
  um **evento**: host, `[Pronto]`, `[Iniciar]`, e o roster que diz por quem se
  está esperando. Um jogo multiplayer é o outro consumidor previsto dela — mas
  ela hoje é específica de P2P (prévia de câmera, dispositivos). Antes de
  generalizar, ler §2.5 do `ux.md` e decidir o que é comum de verdade: o roster e
  os dois botões, provavelmente; os dispositivos, não.
* **O takeover** — `Lobby.join_session/3` com `takeover: true`. Se o jogo ganhar
  a própria sessão, herda o mesmo contrato de graça.
* **`ChatLive.P2PReadModel`** — a terceira aplicação da mesma régua ("o que
  existe para quem só olha a conversa fica no chat"). A quarta é a sua.

### O que ainda não existe e a onda 5 vai precisar decidir

`/play/:game/:token` (multiplayer sobre a sessão P2P) é a rota que o README §5
prevê e ninguém escreveu. A pergunta aberta é se um jogo entre dois é uma
**sessão P2P com um jogo dentro** (é o que o código faz hoje, via
`P2PGameIsland`) ou uma **sessão própria**. A resposta barata é a primeira, e ela
já funciona; o que a onda 5 acrescenta é o endereço.

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

4. **Três testes Playwright estão vermelhos desde antes desta sessão.** Duas
   famílias, ambas verificadas com `git stash` — falham iguais no `HEAD`
   anterior:
   * *a janela maximizada cobre a barra de status do chat e o clique não
     alcança* — `chat-p2p.spec.ts` "the inviter cancels a pending invite from
     the status bar" e o par do group call. Trabalho de z-index, vale um commit
     próprio.
   * *recuperação de mídia depois de um reload no meio do primeiro offer* —
     `chat-call-fault-injection.spec.ts` "P2P answerer reloads while applying
     the initial offer". Metade da causa foi corrigida na iteração 18 (o epoch
     é por página, e uma página nova começa do um), mas o teste continua
     vermelho: sobra mais coisa nesse caminho. **A mesma limitação vale para
     assumir uma sessão já conectada numa segunda aba:** o assento se move e a
     janela deslocada avisa, mas a mídia não volta sozinha — `[Trazer de volta
     pra cá]` devolve o assento, então não é um beco.

   Playwright não está no `make ci`, então a suíte derivou. Não perca tempo
   achando que foi você.

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
retro_hex_chat. As ondas 0 a 4 fecharam; começa a onda 5.

Leia, nesta ordem:
1. docs/plans/shareable-surfaces/HANDOVER.md  — estado, próximo passo, armadilhas
2. docs/plans/shareable-surfaces/README.md    — decisões travadas (P1–P7, D1–D6)
3. docs/plans/shareable-surfaces/ux.md        — o desenho de todas as telas
4. docs/plans/shareable-surfaces/wave-5-games-surfaces.md — o alvo
5. docs/plans/shareable-surfaces/PROGRESS.md  — pelo menos as iterações 7, 8,
   10, 13, 14, 15, 16 e 17: são armadilhas que vão voltar

E antes de tocar código: AGENTS.md, CLAUDE.md e as regras em .claude/rules/ que
o caminho do arquivo disparar.

O próximo passo está na seção 3 do HANDOVER. As três superfícies difíceis já
existem e compartilham uma base: Live.SurfaceHost (com a tag por superfície),
a régua do read-model aplicada quatro vezes, e a sala de partida como o desenho
de P1 para um evento. A onda 5 é jogos: /play/:game já é superfície desde a
onda 0, e o que falta é o endereço do multiplayer sobre a sessão P2P.

Duas coisas específicas desta onda:
- decida com o código na frente se um jogo entre dois é uma sessão P2P com um
  jogo dentro (é o que o código faz hoje) ou uma sessão própria — e não
  generalize a sala de partida antes de ver o que é comum de verdade: o roster
  e os dois botões, provavelmente; a prévia de câmera e os dispositivos, não;
- /play/:game/:token é a rota que o README §5 prevê e ninguém escreveu.

Como trabalhar, e isto não é negociável:
- Não pare para pedir permissão entre passos. Implemente até haver algo
  testável de ponta a ponta pelo usuário.
- Registre cada iteração no PROGRESS.md, incluindo os erros e como foram
  recuperados.
- Toda tela nova ganha screenshot (spec Playwright descartável) antes de
  você dizer que fechou.
- Sequência fixa antes do gate: mix format → make i18n.gettext.extract →
  make ci. Leia a linha "Results:" do log, não o exit code do shell.
- Commit direto na main, com git fetch + pull --ff-only antes e staging de
  caminhos exatos. Não faça push.
```
