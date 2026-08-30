# Progresso e aprendizados

Registro por iteração. O plano diz o que fazer; este arquivo diz o que
aconteceu quando fizemos — em especial **o que o plano errou**.

Quando o plano e a realidade discordarem, a realidade ganha: corrigir o arquivo
de onda no mesmo commit e anotar aqui por quê.

**Estado atual:** ondas 0 a 3 fechadas.

| Onda | Estado |
|---|---|
| 0 — identidade multi-aba + `/play/:game` | ✅ `make ci` 17/17 |
| 1 — `/join/:slug` + card na conversa | ✅ commitada (`f0898719`) + card |
| 2 — conferência | ✅ fechada: `CallLive` em dois hosts, `/call/:token`, filiação com contagem de superfícies |
| 3 — space | ✅ fechada: `SpaceLive` em dois hosts, `/space/:slug`, roster na antessala |
| 4 — P2P channel + superfície | ⬜ |
| 5 — jogos / lobby aberto | ⬜ |
| 6 — coordenação entre abas + bundle | ⬜ |

---

## Iteração 1 — o escopo da desconexão forçada

**Objetivo:** separar "outra aba assumiu o chat" de "você foi banido", para que
uma superfície satélite possa coexistir com o chat sem morrer no login seguinte
e sem sobreviver a um ban.

### Levantamento antes de escrever código

Sete produtores de `{:force_disconnect, …}` no repositório. Classificados:

| Produtor | O que é | Escopo |
|---|---|---|
| `chat_live.ex:142` | takeover de aba | **`:chat`** |
| `admin.ex:49` | ban de servidor | `:all` |
| `admin.ex:92` | kick de admin | `:all` |
| `admin.ex:200` | drop de nick registrado | `:all` |
| `admin.ex:660` | nuke, por nickname | `:all` |
| `nick_serv.ex:422` | `/ns ghost` | `:all` |
| `admin.ex:668` e `trusted_devices.ex:1258` | por `chat_device_session:<ref>` | — |

**Descoberta:** a divisão é mais limpa do que o plano supôs. **Todo** produtor
de domínio é `:all`; o único `:chat` é o takeover do `ChatLive`. Não existe caso
ambíguo, e por isso o escopo não precisa ser um parâmetro que cada chamador
escolhe pensando: `SessionControl.disconnect/2` é `:all` por padrão e só o
takeover passa `:chat`.

**Segunda descoberta:** os dois últimos da tabela não usam o tópico da pessoa —
eles publicam em `chat_device_session:<ref>`, que endereça **uma sessão de
dispositivo**, não um nickname. Uma superfície satélite não abre sessão de
dispositivo (decisão da onda 0 §2.2: ela não escreve `TrustedDevices`), então
ela não escuta esse tópico e não é afetada. Isso significa que "revogar um
terminal confiável" hoje derruba a aba do chat e **não** derruba a aba da
chamada. Está anotado como dívida da onda 2, quando existir uma satélite de
verdade para derrubar — não vale inventar sessão de dispositivo por superfície
agora.

### O que foi feito

- `RetroHexChat.Topics.surfaces/1` → `"user:<nick>:surfaces"`.
- `RetroHexChat.SessionControl` — o único lugar que transmite desconexão
  forçada de uma pessoa, com escopo.
- Os cinco produtores de domínio passaram a chamá-lo.
- `ChatLive` passou a chamá-lo com `:chat`.

### Testes escritos primeiro

- `topics_test.exs` — o tópico de superfícies e a caixa de entrada.
- `session_control_test.exs` — `:chat` entrega só na caixa; `:all` entrega nas
  duas. **Cada teste assina exatamente um tópico**, para que a asserção diga
  qual tópico entregou e não apenas quantas mensagens chegaram.

### Aprendizado: o teste achou uma colisão de verdade

`Topics.inbox("Alice:surfaces")` e `Topics.surfaces("Alice")` são **a mesma
string**. O primeiro instinto foi trocar o separador; a resposta certa era
outra: `NicknameValidator` não permite `:` num nickname
(`nickname_validator.ex:11`), então a colisão é inalcançável.

Mas isso era uma dependência **implícita** entre dois módulos que não se citam.
O teste passou a asserir a garantia real — que o validador recusa o nickname que
colidiria — e o `@moduledoc` de `Topics` passou a dizer que alargar o charset de
nickname significa voltar neste arquivo. Trocar o separador teria sido inventar
defesa contra uma entrada que o validador já proíbe, e teria deixado a
dependência implícita de pé.

### Resultado

`make ci`-relevante: `mix credo --strict` limpo, `mix compile
--warnings-as-errors` limpo, 188 testes de `admin`/`services` verdes,
`chat_takeover_test.exs` verde **sem edição** — o takeover do chat não regrediu,
que era o critério.

---

## Iteração 2 — `Live.Surface` e a primeira superfície satélite

**Objetivo:** um `on_mount` que dá identidade a uma superfície que não é o chat,
e `/play/:game` para provar a coexistência de abas.

### Correção do plano

A onda 0 listava `Live.Surface` e `/play/:game` como passos separados. Não são:
um `on_mount` sem ponto de montagem não tem comportamento observável, e testá-lo
com um socket sintético testaria a assinatura, não a regra. Os dois viraram uma
iteração só, e as regras do `Surface` são asseridas **através** do `PlayLive`.

### Desvio de escopo assumido: `PathHelpers` → `App.Paths`

`RetroHexChatWeb.ChatLive.Helpers.PathHelpers` tinha 6 chamadores, todos no
chat. O `Surface` era o primeiro de fora, e ele precisa das mesmas duas rotas:
para onde vai uma sessão limpa, e para onde vai quem não tem sessão.

Duas saídas: aliasar um módulo do namespace do chat a partir de uma superfície
que não é o chat, ou mover. Mover — porque a primeira opção seria copiada por
mais quatro ondas, e porque a alternativa real seria uma segunda cópia da string
`/chat/session/clear`, que ninguém pensaria em manter em sincronia.

Virou `RetroHexChatWeb.App.Paths`. Custo: 6 arquivos, e reordenar quatro blocos
de `alias` que o Credo pegou. Barato agora, caro na onda 4.

### Aprendizado: o summary de Retro Games era estado morto

Ao portar o `RetroGamesIsland`, a pergunta era como o summary da ilha chegaria
ao host no modo aninhado — um LiveView aninhado manda `send(self(), …)` para si
mesmo, não para o pai.

A resposta é que **não precisa chegar**. `@retro_games` é atribuído em
`chat_live.ex:981` e **nunca lido** — nem no `chat_live.html.heex`, nem em menu,
nem em taskbar. Toda a máquina `summarize/1` → `{:retro_games_summary, …}` →
`assign(:retro_games, …)` alimenta nada.

Grep por nome de assign em todo o `lib/`, não por nome de arquivo — que é
exatamente o que o `guide/testing.md` manda ("0 refs" já foi falso aqui por
causa disso). O port do `PlayLive` deletou a máquina inteira em vez de inventar
um canal PubSub para transportar um valor que ninguém lê.

**Efeito no plano:** a onda 0 §2.3.3 dizia que o summary "passa a subir por
`send(self(), …)` do LiveView aninhado". Está errado e foi corrigido no arquivo
da onda: não sobe nada, porque não desce nada.

### Descoberta que afeta a onda 2: identificação é estado de processo

O portão da conferência é `session.identified` (`group_call_events.ex:751`) —
**um assign do `ChatLive`**, não um fato do domínio. `chat_pre_identified` existe
no cookie, mas quem se identifica *dentro* da sessão não o tem.

Uma aba de chamada não tem como saber se a pessoa está identificada. Três
caminhos, a decidir na onda 2 com o código na frente:

1. o chat, que sabe, assina um token curto ao abrir a aba — é o padrão
   `GroupCall.JoinToken`/`ChannelJoinToken` que já existe, e é coerente com D3.
   Não serve para quem chega por link sem chat aberto — mas essa pessoa também
   não poderia entrar na chamada, então o card explica.
2. identificação vira fato de domínio (presença, ou uma tabela). É provavelmente
   o certo a longo prazo — `session.identified` ser local ao processo é o motivo
   de `ReconnectState` existir — e é grande demais para entrar de contrabando.
3. o satélite faz o mesmo `resolve_user_id/1` e trata "segurar o nick" como
   prova. É o que a política já faz na prática, e é o mais frágil.

Registrado nos riscos da onda 2. **Não decidido aqui.**

### O que foi feito

- `RetroHexChatWeb.Live.Surface` — `on_mount` com as duas recusas (sem sessão,
  banido), a assinatura de `Topics.surfaces/1`, e três coisas que ele
  deliberadamente **não** faz, cada uma documentada com o bug que existiria sem
  ela.
- `RetroHexChatWeb.App.PlayLive` — Retro Games como LiveView, montável root.
- `live_session :app_surface` no router (on_mount diferente exige sessão
  própria), com `/play` e `/play/:game`.
- `App.Paths.connect_path/2` para o redirect com motivo.

### Verificação: revertido uma vez para ver vermelho

Verde não prova nada sozinho. Duas reversões deliberadas:

| Quebra | Teste que ficou vermelho |
|---|---|
| `Topics.surfaces` → `Topics.inbox` no `Surface` | "a chat takeover leaves it running" |
| checagem de ban removida | "a banned nickname goes to connect saying so" |

São exatamente os dois testes que carregam o sentido da onda.

### Estado

10 testes de `play_live_test.exs` verdes, `mix credo --strict` limpo em 1523
arquivos, `mix compile --warnings-as-errors` limpo, `mix audit.styles --strict`
com 0 LOW/MEDIUM/HIGH.

**Ainda falta na onda 0:** montar o `PlayLive` aninhado na janela do chat,
deletar `RetroGamesIsland` e `RetroGamesEvents`, `PerfBudgets` para `:play`,
help topic, i18n, o spec Playwright de multi-aba e a medição de long task.

---

## Iteração 3 — um módulo, dois hosts (D2 na sua menor forma)

**Objetivo:** o chat passa a renderizar o mesmo `PlayLive` da aba, e a ilha
antiga some.

### O que foi feito

- `PlayLive` ganhou dois renders: `render(%{embedded?: true})` devolve só o
  corpo; o outro devolve desktop + janela + corpo. O modo vem de
  `session["embedded"]`, passado pelo `live_render/3` do chat.
- `chat_live.html.heex` troca o `live_component` por
  `live_render(@socket, App.PlayLive, id: "retro-games-live", session: %{"embedded" => true})`,
  dentro da mesma `desktop_window`.
- **Deletados:** `ChatLive.Components.RetroGamesIsland`,
  `ChatLive.RetroGamesEvents`, o registro nos dois dispatchers e o assign
  `retro_games`.
- `/play` ganhou um link `← Chat` na barra de status da janela.

### Aprendizado: o opener virou client-side, e o evento sumiu com ele

`open_retro_games` existia porque a ilha precisava de um host que abrisse a
janela. `guide/windowed-desktop.md` §7.1 diz que um item de Start menu só
precisa ser `app_item` (servidor) **quando abrir implica carregar dado** — e
agora não implica: o `PlayLive` carrega o próprio catálogo no próprio `mount`.

Então Start menu e desktop launcher passaram a `window_item` / `window(...)`,
que carregam `data-window-open` e o window manager resolve no cliente. O evento
de servidor deixou de existir, e com ele o último motivo de o `RetroGamesEvents`
existir. Uma regra do guia decidiu isso — não uma preferência.

### Aprendizado: a capacidade "abrir com um jogo escolhido" mudou de lugar

`open_retro_games` aceitava `game-id`, mas **nenhuma UI passava** — só um teste.
Era capacidade sem porta.

Em vez de construir um canal pai→filho (via `socket.parent_pid`) para
transportá-la até o LiveView aninhado, ela foi para onde uma pessoa alcança:
`/play/:game`. O teste que a asseria pelo `toolbar_action` foi substituído por
`play_live_test.exs` — "a known game in the path opens it". Não é capacidade
removida: é capacidade que ganhou endereço.

### Armadilha de i18n: o `.po` deste repo não tem formato canônico único

O `mix gettext.merge` **desembrulha os `msgid`**, e o diff de `help_games.po`
veio com −4.000 linhas líquidas em 13 locales. A memória do projeto dizia "PO
files are polib-canonical", então a primeira tentativa foi recanonizar com
polib.

**Piorou** (10.868 → 20.933 inserções). Motivo: `games.po` no HEAD já estava
**desembrulhado** (último a escrever foi o `gettext.merge`) e `help_games.po`
estava **embrulhado** (último a escrever foi o polib). Os dois formatos coexistem
no repositório, arquivo a arquivo, conforme a última ferramenta que passou.

Segundo erro, pior: para desfazer, rodei `merge` em todos os domínios cujo
`.pot` tinha mudado — mas a maioria só tinha **drift de `#:`**, e isso reescreveu
150 arquivos. Recuperado com `git stash push -- <paths de gettext>` (a forma
recuperável que o `AGENTS.md` manda usar em vez de `git checkout`), depois
`extract` + `merge` só nos três domínios com `msgid` novo.

**Regra tirada disto:** mesclar **apenas** os domínios que ganharam ou perderam
`msgid`. Um `.pot` que mudou só por referência de linha não precisa de merge, e
mesclá-lo custa um arquivo reescrito por locale por domínio.

### Onde a tradução ficou

7 `msgid` novos (2 em `games`, 4+1 em `help_games`, 2 keywords em `help`) estão
vazios nos 13 locales — fallback para inglês.

Isso **não** reprova o `make ci`: o gate de i18n do CI é
`i18n.gettext.check` (frescor de `.pot`) e `i18n_quality_check.py`, não
`i18n.catalog.check` (cobertura de `.po`). Medido: `i18n.catalog.check` já
falhava no HEAD limpo, com vazios pré-existentes em `chat.po`, `help_bots.po`,
`help_features.po` e `help.po`.

Traduzir exige o venv com Argos Translate e os modelos dos 13 locales, que não
está instalado nesta máquina. Fica como dívida explícita da onda 0 — não como
algo que passou despercebido.

### Estado

| | |
|---|---|
| `play_live_test.exs` | 10 verdes |
| `retro_games_window_test.exs` (novo, substitui o da ilha) | 4 verdes |
| `payload_budget_test.exs` com `/play` | 10 verdes |
| `mix credo --strict` | limpo |
| `mix format --check-formatted` | limpo |
| `mix audit.styles --strict` | 0 LOW / 0 MEDIUM / 0 HIGH |
| `/play` dead render | 39.284 B raw, 3.566 B gzip, 267 nós, todos os ícones via `<use>` |

**Ainda falta na onda 0:** o spec Playwright de multi-aba, a medição de long
task com e sem `noopener`, e a tradução dos 7 `msgid`.

---

## Iteração 4 — o navegador de verdade, e a medição

**Objetivo:** provar a coexistência num browser, e responder com número se abas
separam mesmo o event loop.

### O E2E achou um bug que o ExUnit não podia achar

`/play` renderizava, o window manager rodava, o `u-hidden` era removido — e a
janela media **1280×0**. O `desktop/1` é `flex flex-1 flex-col`: ele só tem
altura porque alguém acima dele tem. O chat envolve o seu num
`fixed inset-0`; showcase e landing usam `flex h-screen flex-col` com
`class="flex-1"` no desktop. O `PlayLive` não envolvia em nada.

Dez testes de LiveView passavam, porque `render/1` devolve markup e markup não
tem altura. É literalmente a regra do `guide/testing.md`: "green tests prove
nothing on their own". Diagnosticado com um spec descartável que despeja
`getBoundingClientRect` e erros de console — não com leitura de código.

Corrigido reusando o mesmo shell das outras telas, não copiando a string de
classes do chat.

### A medição: o argumento de event loop é real e é condicional

Em vez de inferir de long tasks de um jogo rodando, perguntei direto: um
amostrador de `requestAnimationFrame` na aba do chat, e um bloqueio síncrono de
1.200 ms na aba satélite.

| Abertura | Maior intervalo entre frames na aba do chat |
|---|---|
| `window.open(url, "_blank")` | **1203 ms** |
| `window.open(url, "_blank", "noopener")` | **12 ms** |

Sem `noopener` o bloqueio atravessa **inteiro** — as duas abas são a mesma
thread. Com `noopener`, a aba do chat não sente nada.

Isso promove `rel="noopener"` de detalhe a **requisito de arquitetura** deste
plano, e revela que o Arcade, que já abre aba hoje, não tem isolamento nenhum
(`arcade_session_hook.js:30`). Não é correção de uma linha: o hook faz polling
em `_gameWindow.closed` e `noopener` devolve `null`. Continua sendo onda 5.

Registrado no `README.md` §2.3 e na onda 0 §2.4. Os dois specs de medição eram
descartáveis e foram apagados; o que ficou é o número.

### O `Live.Surface` emagreceu antes de ganhar consumidores

Ele atribuía `timezone` e `client_info` "porque as ondas 2–4 vão precisar".
Ninguém lia. É a mesma forma do `@retro_games` que a iteração 2 deletou, só que
recém-escrita — e a lição estava a duas horas de distância.

Ficou só `surface_nickname`, que é a identidade que o hook existe para
estabelecer. Timezone e client info voltam quando uma superfície os ler, e aí
com um teste que prova que lê.

Também: `push_navigate` e `redirect` passaram a ser importados em vez de
qualificados, como o resto das funções de LiveView no módulo.

### Armadilha: o `.pot` tem que ser o último passo

O primeiro `make ci` completo reprovou em **i18n Catalog Coverage**:
`mix gettext.extract --check-up-to-date`. Motivo bobo e caro — editei
`play_live.ex` **depois** do último extract, e as referências `#:` do `.pot`
ficaram velhas. Nenhum `msgid` mudou; só números de linha.

Regra: `make i18n.gettext.extract` é o **último** passo antes do gate, depois de
`mix format`. Ordem: código → format → extract → (merge só se houver `msgid`
novo) → `make ci`.

E a armadilha do `AGENTS.md` sobre o exit code apareceu de outro jeito: a
notificação do job de background disse "exit code 0", que era do `grep` no fim
da cadeia. O `CI_EXIT=2` só estava no log. Ler o log, sempre.

### Estado

- `e2e/tests/surface-multi-tab.spec.ts` — 2 verdes (K2 e K3), catálogo
  regenerado.
- `make ci.quick` — **16/16**, `CI_EXIT=0`.
- `make ci` completo — 1ª tentativa `CI_EXIT=2` (`.pot` velho), corrigido e
  reexecutado: **17/17, `CI_EXIT=0`**, dialyzer incluído.

### Saldo da onda 0

17 arquivos de aplicação tocados: **123 inserções contra 359 deleções**. Três
módulos novos somam 395 linhas (`SessionControl` 68, `Live.Surface` 80,
`PlayLive` 247). A onda que adicionou uma superfície deixou o repositório menor,
porque `RetroGamesIsland`, `RetroGamesEvents`, o assign `retro_games` e o evento
`open_retro_games` saíram inteiros.

**Dívida aberta:** os 7 `msgid` novos estão em inglês nos 13 locales. O gate de
i18n do `make ci` é frescor de `.pot`, não cobertura de `.po`, então isto passa —
mas é dívida, não vitória. Traduzir precisa do venv de Argos Translate, ausente
nesta máquina.

**Ainda falta na onda 0:** `make ci` completo (com dialyzer) e a tradução dos 7
`msgid` (precisa do venv de Argos, ausente nesta máquina).

---

## Iteração 5 — o domínio `ShareLinks`

**Objetivo:** o registro que transforma um slug opaco numa superfície, sem que o
slug conceda nada.

### O que foi feito

- `ShareLinks.Slug` — alfabeto de 31 caracteres (sem `0`/`o`, `1`/`l`/`i`),
  comprimento 10. Os dois números estão no `@moduledoc` **e** num teste, porque
  encurtar o slug é uma decisão de segurança e não pode passar como ajuste
  cosmético: 31^10 ≈ 8,2 × 10^14.
- `Schema.Link` + migração `share_links` — slug único, `kind` de quatro valores,
  `target` mapa, `revoked_at`/`revoked_by`, `resolve_count`.
- `Queries`, `Liveness`, `Service`, e a fachada `RetroHexChat.ShareLinks`.

### Aprendizado: o teste pegou o alfabeto escrito duas vezes

`valid?/1` usava a classe `[a-z2-9]` escrita à mão, que **aceita** `i`, `l` e
`o` — os três caracteres que `generate/0` existe para excluir. Um slug com `l`
passaria na validação e nunca poderia ter sido gerado.

O reflexo foi afrouxar o teste. A correção certa foi derivar a regex da
constante `@alphabet`, para que as duas definições não possam divergir de novo.

### Decisões tomadas com o código na frente

**`live?` é derivado, nunca persistido.** Um campo `live` no banco seria uma
segunda fonte de verdade sobre o estado de uma sala — a mesma razão pela qual o
P2P checa sessão duplicada com query e não com lookup no Registry. Um space é
sempre live: ele é um lugar, não um evento.

**`record_resolution/1` é `update_all` com `inc:`**, não read-modify-write. Duas
pessoas abrindo o mesmo link ao mesmo tempo escreveriam cada uma a contagem que
leu, e uma das visitas sumiria.

**O rate limit ficou de fora, de propósito.** Já existem **três** cópias da
janela deslizante em ETS no repositório (`P2P.RateLimiter`,
`P2P.SignalingRateLimit.ETS`, `GroupCall.RateLimiter`). Fazer a quarta é
exatamente o fork que o Princípio XII proíbe, e extrair a comum agora seria
construir mecanismo antes do consumidor. Entra na iteração que expõe a criação
na UI, junto com a extração — mesma disciplina que cortou `timezone` e
`client_info` do `Live.Surface`.

### Verificação: revertido duas vezes

| Quebra | Teste vermelho |
|---|---|
| `check_open` deixando de recusar revogado | "a revoked link says so" |
| `resolve` sem a validação de shape do slug | "refuses a slug the generator could not have produced" |

### Estado

27 testes verdes (`:unit` do slug e do schema, `:integration` do serviço),
`mix credo --strict` limpo, `mix format --check-formatted` limpo.

**Falta na onda 1:** `/join/:slug` com os quatro estados, `return_to` no connect
(com o teste negativo de open redirect), o card ao vivo na conversa, e o botão
Compartilhar.

---

## Iteração 6 — o laço completo: mintar, compartilhar, entrar

**Objetivo:** algo que dá para testar à mão de ponta a ponta.

### O que foi feito

- `RetroHexChatWeb.App.ReturnTo` — a única superfície de open redirect que o
  plano cria, com tabela de 17 casos negativos (scheme-relative, absoluto,
  barra invertida, traversal, `javascript:`, não-string, comprimento).
  `return_to` atravessa connect → form escondido → `SessionController`.
- `RetroHexChatWeb.JoinLive` em `/join/:slug`, no **pipeline landing**: quem
  segue um link pode não ter sessão nenhuma, e não pode pagar o bundle do app
  inteiro para descobrir o que lhe mandaram.
- `Components.UI.JoinCard` — três estados (`:ready`, `:needs_session`, `:gone`).
- `Components.UI.ShareBar` — o botão que minta o link, reusável pelas ondas 2–5.
- Domínio gettext novo: `share`.

### O laço, testável à mão

1. `/play/hex_pong` com nick registrado → **Share**
2. copiar a URL `…/join/xxxxxxxxxx`
3. abrir em outro navegador sem sessão → card público
4. **Conectar e entrar** → `/connect?return_to=…` → registrar
5. volta no card, agora com **Entrar** → cai no jogo

Coberto por `e2e/tests/share-link-join.spec.ts` (K4), verde em dois contextos de
browser separados.

### Decisões tomadas com o código na frente

**Um card morto e um slug inexistente leem igual.** Distinguir os dois é um
oráculo para saber se uma sala existe. O `JoinLive` cai no mesmo `:gone` para
`:not_found`, `:revoked`, `:expired` e para um link vivo cujo alvo sumiu.

**Sem botão de copiar.** `clipboard_copy` é tratado pelo `chat_viewport_hook`,
que só existe no chat — um `push_event` desses numa aba `/play` não teria quem o
recebesse, que é a forma de "no silent catch" do lado do cliente. A barra usa um
input readonly, sem JS, e funciona igual nos dois hosts. Um copiar de verdade
precisa de um hook agnóstico de superfície; a lib de coordenação da onda 6 é o
lugar natural.

**Mintar é ato deliberado.** Abrir um jogo não cria link — o botão cria. Um link
por janela aberta encheria a tabela de endereços que ninguém mandou.

**Só nick registrado minta.** `creator_id` é FK obrigatória: um link por quem
ninguém pode responder é um link sobre o qual não dá para perguntar nada. Guest
vê o botão desabilitado com o motivo.

**`/join` é `noindex`.** O layout do landing tinha `robots` fixo em
`index, follow`; virou `assigns[:robots] || "index, follow"`. Um convite no
índice do Google é um convite que ninguém estendeu.

### Armadilha: um domínio gettext novo precisa ser semeado

`make i18n.gettext.merge DOMAINS=share` **pulou os 14 locales** —
`scripts/i18n_merge_domain_catalogs.exs` casa `.po` existente com `.pot`, e um
domínio inédito não tem `.po` nenhum. A saída óbvia
(`mix gettext.merge priv/gettext`) é o rebuild global que o repo exige
`CONFIRM_GLOBAL_REBUILD=1` para rodar.

Resolvido semeando `share.po` em cada locale com o bloco de cabeçalho do `ui.po`
daquele locale, e mesclando depois. Detalhe que quase passou: o cabeçalho
copiado carrega um comentário dizendo de qual `.pot` os msgids vêm — os 14
arquivos nasceram apontando para `ui.pot`. Corrigido.

**Receita para a próxima onda que criar domínio:** semear cabeçalho → merge →
corrigir a linha de comentário.

### Estado

- 13 testes em `play_live_test.exs` (inclui o laço mintar→resolver), 7 em
  `join_live_test.exs`, 3 em `return_to_test.exs`, 27 em `share_links/`.
- `share-link-join.spec.ts` (K4) e `surface-multi-tab.spec.ts` (K2, K3) verdes.
- `mix credo --strict` limpo em 1536 arquivos, `mix format --check-formatted`
  limpo, `i18n.gettext.check` e `i18n_quality_check` verdes.

**Falta na onda 1:** o card ao vivo *dentro* da conversa (hoje o link vai como
URL comum, que o chat já renderiza), e o rate limit de criação — que entra junto
com a extração da janela deslizante, para não virar a quarta cópia.

---

## Iteração 7 — dois bugs que só o teste manual encontrou

O usuário abriu `http://localhost:4000/pt-BR/join/9mjc3jvdcf` no Firefox e
recebeu `Phoenix.Router.NoRouteError`. Dezesseis testes verdes e um E2E em dois
contextos de browser não pegaram isso.

### Bug 1 — a rota pública existia só sem prefixo

Toda página pública deste repo existe **sob cada segmento de locale**: o router
tem um `for locale_segment <- @localized_locale_segments` que repete landing e
help em treze prefixos. Eu registrei `/join/:slug` só no escopo sem prefixo.

Por que os testes não pegaram: eles todos usavam `~p"/join/#{slug}"`, que é o
caminho que eu tinha registrado. Um teste que exercita exatamente o que o código
faz não testa nada — foi preciso um navegador com locale pt-BR para revelar.

E é o pior lugar possível para esse defeito: **o endereço é a única coisa de um
link compartilhado que quem recebeu não pode consertar**.

Corrigido com um `live_session` de join dentro do laço de locales. O teste de
regressão itera `SEO.localized_locale_segments()` em vez de listar prefixos à
mão, então um locale novo não pode nascer sem rota.

### Bug 2 — o mesmo defeito, uma camada adiante

`App.ReturnTo` recusava `/pt-BR/join/xxx`: a allowlist casava `/join/`, e o
caminho localizado não começa assim. Um estranho num card em pt-BR conectaria e
cairia em `/chat` em vez de voltar ao card.

Não estava alcançável ainda (o `JoinLive` monta o `return_to` sem prefixo, e
`/connect` também não é localizado), mas é a mesma classe do bug 1 e teria
aparecido no momento em que alguém colasse a URL localizada.

`ReturnTo` agora tira o prefixo antes de casar, lendo os segmentos do **mesmo**
`SEO.localized_locale_segments()` que o router usa — um locale adicionado lá não
pode virar caminho recusado aqui. Só os segmentos registrados contam: um
primeiro segmento arbitrário não é passe livre, e isso é teste.

Nota que sobreviveu à investigação: `Plugs.PutLocale` persiste o locale na
sessão, então a ida ao `/connect` sem prefixo não perde a língua do visitante.

### Verificação

Removido cirurgicamente só o `live_session` localizado: os **dois** testes de
locale ficam vermelhos e os outros sete continuam verdes.

### A lição

O E2E da onda 1 passava porque eu o escrevi derivando o caminho de
`new URL(shareUrl).pathname` — a URL que o meu próprio código gerou. Todo o
teste automatizado estava dentro do mesmo espaço de caminhos que a implementação
assumia. `guide/testing.md` já diz isso de outro jeito ("green tests prove
nothing on their own"); aqui a forma foi **testar só o caminho feliz que o
código constrói**.

Para as ondas 2–5, onde cada superfície ganha rota: verificar o escopo de locale
é item de checklist, não de inspiração.

---

## Iteração 8 — o card estava feio, e eu não tinha planejado consertar

O usuário abriu o card e disse: "horrivelmente feio, sem ícones, triste com cara
de incompleto". Estava certo, e a resposta honesta era que **não havia passe de
refino planejado** — construí um stub e segui.

### Três defeitos, e um explica o resto

1. **`shadow-retro-button` não existe no CSS.** O botão "Entrar" era um `<a>` com
   uma classe inventada por mim; renderizava como texto cru. Nenhum teste olha
   se uma classe existe.
2. **Sem desktop.** Uma caixa centralizada no vazio, enquanto todas as outras
   telas públicas rodam desktop com wallpaper e window manager.
3. **Sem substância.** Ícone genérico, nada sobre o que estava sendo
   compartilhado.

### O que ficou

O card roda o mesmo desktop das páginas públicas (`PublicWindowManagerHook`) e
mostra o jogo de verdade — ícone 32×32 do catálogo, nome e tagline — com quem
compartilhou no meta da barra de título.

Duas melhorias em primitivas compartilhadas, ambas aditivas e ambas coisas que
as ondas 2–5 vão querer:

- **`button` aceita `navigate`/`href`.** Uma ação cujo resultado é outra página
  tem que ser um link: clique do meio, abrir em nova aba e a barra de status vêm
  da âncora, não do estilo. Compartilhar as classes de variante é o que impede
  virar um segundo botão parecido.
- **`desktop_window` aceita `controls`.** A tela não tem taskbar, então
  minimizar seria beco sem saída — e um diálogo Win98 nunca teve esse botão.
  `controls={[]}` é o correto, não uma exceção.

### O gate pegou o que eu quebrei em seguida

`make ci` reprovou em **i18n Quality**: `%{count} charts` e `%{count} cores`
com a mesma tradução em 9 locales.

Causa: mesclei `DOMAINS=share,ui` — e `ui` **não tinha msgid novo meu**. O merge
com fuzzy matching ressuscitou um drift pré-existente (`%{count} object` existia
no `.pot` e não nos `.po`) e o preencheu com a tradução de "cores".

**Quebrei a regra que eu mesmo escrevi duas iterações antes**: mesclar apenas
domínios que ganharam ou perderam msgid. Revertido com
`git stash push -- <paths de ui.po>`; `findings` voltou a 0.

O aprendizado real não é sobre gettext: é que uma regra escrita no `PROGRESS.md`
não me impede de repeti-la. O que impediu foi o gate.

### Mudança de processo

Dois defeitos seguidos na mesma superfície — a rota localizada e a aparência —
e os dois eram invisíveis para os testes, porque **os testes só exercitavam o
que o código já fazia**. O E2E derivava a URL do próprio código; nenhum teste
olha se uma tela está feia.

**Toda tela nova ganha screenshot antes de eu dizer que a onda fechou.** Um spec
descartável, ler as imagens, apagar. Foi assim que os controles de minimizar
apareceram — não estavam em nenhum teste.

---

## Iteração 9 — o card na conversa

**Objetivo:** um link colado numa conversa vira card, sem caminho de postagem
novo.

### A decisão que evitou o acoplamento pai↔filho

O desenho original era um botão "mandar pra conversa" na `ShareBar`. Isso exige
que o `PlayLive` aninhado fale com o `ChatLive` (que sabe qual conversa está
aberta), e numa aba `/play` não existe conversa nenhuma.

A saída foi mais simples **e** mais geral: **qualquer** `/join/:slug` numa
mensagem vira card, não importa como chegou lá. Sem caminho de postagem novo,
sem acoplamento, e funciona para um link que a pessoa recebeu por fora e colou.

### `describe/1` existe porque contar é diferente de resolver

Desenhar um card num canal **não** é alguém seguindo o link. Se as duas coisas
compartilhassem função, um canal movimentado inflaria o único número que
responde se compartilhar link traz gente.

`resolve/1` agora é `describe/1` + contar. `describe_many/1` faz uma query para
a tela inteira — perguntar por mensagem é como o render de uma conversa vira uma
dúzia de round trips.

### `ShareLinkRef`: a forma da URL num lugar só

Montar a URL e reconhecê-la estavam prestes a existir em dois lugares — a
superfície que minta e a conversa que desenha. Duas grafias da mesma forma é
como um link que o app produziu deixa de ser um link que o app reconhece.

O reconhecimento é estreito de propósito: caminho sem host é nosso (alguém
digitou aqui), URL absoluta só se o host for exatamente o nosso. E **exatamente**
— `https://retrohexchat.app.evil.example` começa com o nosso nome e não é a
gente; `https://retrohex` está contido no nosso e também não é. As duas
confusões de host são teste.

Segmentos de locale contam, lidos da mesma lista do router — terceira vez que
essa lista evita um bug nesta onda.

### O screenshot pegou o que 4 testes de componente não pegaram

O card renderizava certo. Mas na tela apareciam **dois** cards sob a mesma
mensagem: o meu, e um preview do scraper, que tinha ido buscar a nossa própria
página `/join/` e montado um card com o título e a descrição do site.

Nenhum teste veria: cada card estava correto isoladamente. `tag_link/1` agora
tira os nossos links da lista de candidatos ao scraper — não há o que buscar, e
a resposta útil é o estado de uma sala, não o título de uma página. Uma mensagem
que também traga o link de outra pessoa continua ganhando aquele preview.

**A regra de processo da iteração 8 pagou na iteração seguinte.**

### O que ficou de fora, e por quê

**O card não atualiza sozinho.** Para `kind: "play"` não existe estado ao vivo —
um link de jogo está sempre válido. Participantes que mudam são coisa de chamada
e de space, então a metade ao vivo nasce na onda 2, com o primeiro consumidor de
verdade. Construir agora seria máquina sem quem a use, pela terceira vez nesta
sessão que essa disciplina evita código.

---

## Iteração 10 — as traduções do card, e um erro de glossário

**Objetivo:** o card que um estranho vê deixa de estar em inglês para um
visitante em pt-BR. Era a dívida mais visível do plano.

### Onde cada string foi parar

- **Rótulos que vão se repetir nas ondas 2–5** (`Share`, `Share link`,
  `Open the chat`, `Link expired`, `Connect and join`) entraram no glossário
  curado (`scripts/i18n/glossary.py`), que é a regra da casa para rótulo curto:
  nunca máquina, sempre curadoria.
- **As 14 frases específicas do domínio** foram escritas direto nos 13
  `share.po`, porque não recorrem em outro lugar.

### O gate pegou um erro de desenho meu

Eu tinha posto `"Enter"` no glossário com o sentido "entrar na sala".
`i18n_quality_check.py` reprovou: **todo outro catálogo já lê `Enter` como a
tecla** — "Entrée" em francês, "Eingabe" em alemão. O glossário é global entre
domínios, então a minha entrada teria reescrito o teclado do app inteiro.

A correção não foi afrouxar o glossário: foi **usar o termo que já existe**.
`Join` já é curado com exatamente o sentido de entrar numa sala, então o botão
passou a ser `Join` e o outro virou `Connect and join`. Reusar o termo curado em
vez de inventar um sinônimo é literalmente para o que serve um glossário.

### Uma nota de memória minha estava errada

Eu carregava que "en é expo-only" e que os catálogos em inglês ficam vazios.
Falso: `en/ui.po` tem `msgstr "Help"`. O `i18n_placeholder_check` reprovou
`en/share.po` porque as entradas vazias perdem os `%{...}`. Preenchido com o
próprio msgid, como os outros domínios fazem.

### Verificação

Screenshot de `/pt-BR/join/<slug>` num contexto com locale pt-BR: título, corpo
e botão todos em português, com o ícone e o nome do jogo.

`i18n_quality_check` e `i18n_placeholder_check` com `findings=0`.

---

## Iteração 11 — onda 2, passo zero: os normalizadores saem primeiro

**Objetivo:** tornar possível mover a conferência para um LiveView próprio, sem
ainda mover nada.

### Por que este passo, e não o `CallLive` direto

`group_call_events.ex` tem 2.604 linhas, 87 `handle_event` e ~150 helpers
privados. O plano manda montar o `CallLive` aninhado primeiro, mas mesmo esse
passo esbarra na forma do módulo: as duas metades que precisam se separar — o
read-model de canal ("existe uma chamada em #retro") e o estar-dentro — **usam os
mesmos normalizadores privados**.

Então a ordem real é: normalizadores primeiro, read-model depois, `CallLive` por
último. Medido, não estimado: 309 linhas em 27 funções puras.

### `RetroHexChatWeb.App.GroupCallShape`

Um `room`, um `participant`, um `track` e um bloco de stats chegam de três
lugares — linha do banco, broadcast do PubSub, hook do browser — e cada um
escreve os campos de um jeito: struct com chave atom, mapa com chave string,
update parcial sem nenhum dos dois. É por isso que `value/2` tenta as duas
grafias.

Elas não decidem nada e não tocam socket. Sendo privadas do adaptador do chat,
**a superfície que vai hospedar a chamada numa aba não poderia usá-las sem
copiar** — e o código mais reusado da feature não tinha teste nenhum.

Agora tem 18, e eles asseriram coisas que ninguém tinha verificado: que a chave
atom ganha da string quando o payload traz as duas, que um participante vazio
ainda tem a forma que um tile lê, que `truthy?` aceita as cinco grafias de "sim"
que o browser manda.

### O compilador reprovou um teste meu

`assert Shape.reaction_emoji("nonsense") != nil` — o Elixir avisou que
`reaction_emoji` sempre devolve binário, então a comparação é sempre verdadeira.
Um teste que não pode falhar.

Trocado por duas asserções reais: as cinco reações nomeadas desenham coisas
**diferentes**, e uma desconhecida cai no coração em vez de ficar em branco —
uma bolha vazia num tile de vídeo lê como bug, não como reação.

### Armadilha do refactor mecânico

O script que converteu `defp` em `def` capturava o nome com
`^  defp ([a-z_0-9]+)`, que **para antes do `?`**. `truthy?/1` virou um `@spec
truthy/1` para uma função que não existe, e `value/2` ficou sem spec. O
compilador pegou os dois. Vale lembrar em qualquer extração futura: nomes de
predicado terminam em `?` e `!`.

### Terceira vez na mesma armadilha

`make ci` reprovou de novo em **i18n Catalog Coverage**: mover
`dgettext("group_call", "Default device")` de arquivo muda a referência `#:` do
`.pot`. Nenhum msgid novo, nenhum merge necessário — só extract.

Já é a terceira vez nesta sessão, e escrever a regra no `PROGRESS.md` não me fez
segui-la. O que funciona é sequência fixa, não lembrança:

    mix format  →  make i18n.gettext.extract  →  make ci

`extract` vai antes do gate **sempre**, mesmo quando "só movi código". Mover
código é justamente o que muda referência.

### Dialyzer pegou dois specs que escrevi por suposição

Ao tornar as 27 funções públicas, escrevi os `@spec` de cabeça. Dois estavam
errados e o Dialyzer os reprovou:

- `normalize_devices/1` devolve `%{String.t() => [map()]}` — um mapa por tipo de
  dispositivo, não uma lista.
- `normalize_console_section/1` devolve `atom()`, não `String.t()`.

Vale registrar porque é o argumento a favor do custo: enquanto essas funções
eram privadas, **ninguém tinha escrito o tipo delas**, e portanto ninguém tinha
verificado. Tornar público forçou dizer o que elas fazem, e o Dialyzer conferiu.
Os dois erros estavam na minha leitura do código, não no código.

### Estado

`group_call_events.ex` foi de 2.604 para 2.346 linhas; `GroupCallShape` tem 359
com specs. 46 testes de group call verdes **sem edição**, 18 novos, credo limpo.

**Próximo:** separar o read-model de canal (o que fica no `ChatLive`) do
estar-dentro (o que vai para o `CallLive`).

---

## Iteração 12 — a régua aplicada: o que fica no chat sai do adaptador

**Objetivo:** separar, dentro de `group_call_events.ex`, o read-model de canal
(saber que existe uma chamada) do estar-dentro (mídia, layout, foco).

### A régua, e o que ela decidiu

"Se o dado só existe enquanto você está na chamada, ele vai; se existe para quem
só está olhando o canal, ele fica." Aplicada função a função, ela dividiu o
módulo em dois lugares e não em dois arquivos:

- **`RetroHexChatWeb.App.GroupCallSummary`** — puro, sem socket: `fetch/1` lê o
  domínio, `normalize/2` faz as três fontes (room server, broadcast com chaves
  string, linha do banco sozinha) lerem igual. Fica em `app/`, ao lado do
  `GroupCallShape`, porque a antessala da onda 2 vai ler exatamente isto.
- **`RetroHexChatWeb.ChatLive.GroupCallReadModel`** — os dois assigns e nada
  mais: `refresh_all/1`, `refresh/2`, `mark_active/3`, `mark_inactive/2` e os
  acessores. Fica em `live/chat_live/`, ao lado do `ConversationsReadModel` que
  já existia — o precedente de nome e de lugar já estava no repositório.

`GroupCallEvents` ficou com o estar-dentro, e os chamadores que só queriam o
read-model (`helpers/channel.ex`, `pubsub_handlers/channel_state.ex`) passaram a
falar com ele direto.

### O único ponto onde as duas metades ainda se tocam

`mark_channel_call_active/3` faz duas coisas: registra o badge **e** funde o
summary no `@group_call` quando é a chamada em que você está. Isso não é
acidente de escrita — é o mesmo dado servindo dois leitores. Ficou no
`GroupCallEvents`, com o porquê no `@doc`, e é ele que some quando o `CallLive`
assinar o próprio tópico.

Duas delegações nasceram mortas e foram apagadas no mesmo passo:
`refresh_channel_call_state/2` e `mark_channel_call_inactive/2` não tinham mais
nenhum chamador externo depois do rewire.

### O teste que passou verde estando errado

`live_summaries/1` devolve os canais com chamada **na ordem em que a sessão os
lista** — a ordem decide qual sala o reconnect reata. Escrevi o teste com
`["#a", "#b", "#c"]`, quebrei a implementação para `Map.to_list/1`, e o teste
**continuou verde**: um mapa pequeno no Erlang guarda as chaves ordenadas, e a
minha lista já estava em ordem alfabética.

Trocado por `["#zulu", "#mike", "#alfa"]`, onde a ordem da sessão e a ordem do
mapa discordam. Com a implementação quebrada, dois testes ficam vermelhos; com
ela de volta, nove verdes.

Vale a nota porque é a mesma classe da iteração 7: **um teste escrito dentro do
espaço que a implementação já ocupa não testa nada**. Lá foi o caminho da URL,
aqui foi a ordem das chaves.

### Verificação

- 36 testes de `group_call_flow_test.exs` verdes **sem uma edição** — é o que
  prova que foi movimentação, não reescrita.
- 9 testes novos no read-model, 6 no summary, e a idempotência de `normalize/2`
  asserida (o caminho de reattach passa um summary já normalizado de volta).
- `mix credo --strict` limpo, `mix format` e `make i18n.gettext.extract` antes do
  commit — a sequência fixa, desta vez sem esquecer.

`group_call_events.ex`: 2.346 → 2.221 linhas.

**Próximo:** `CallLive` montado aninhado na janela `group-call`, via
`live_render/3`. Nada muda para o usuário; é o passo reversível.

---

## Iteração 13 — a conferência ganha endereço próprio

**Objetivo:** `CallLive` — um módulo, dois hosts (aninhado na janela do chat e
raiz em `/call/:token`) — e o pré-join promovido de diálogo a antessala.

### O que decidiu o desenho: três coisas que não podem ser iguais nos dois hosts

O plano dizia "um módulo, dois pontos de montagem". Ao escrever, só três coisas
divergiam de verdade, e todas foram para `CallLive.Host`:

* **um aviso.** Dentro do chat, "você não pode silenciar um operador" pertence à
  conversa, que é onde toda recusa deste produto já aparece. Uma aba aberta por
  link não tem conversa, então diz na própria barra de status.
* **a janela.** Embutido, a janela é do gerenciador do chat e a superfície
  *pede*; sozinha, a janela é a página e não há a quem pedir.
* **o que o host desenha sobre a chamada.** O chat continua com botão de
  taskbar e zona de status, então a superfície entrega o pouco que eles leem —
  canal, estado, apelidos, ids de faixa — e guarda o resto.

O canal entre os dois é o **processo pai**, não PubSub: um `live_render` filho
tem exatamente um host, morre com ele, e um tópico levaria isso para todas as
abas — que é o problema da onda 6.

### A identificação: decidida com o código na frente, como o plano pedia

O risco nº 1 da onda dizia que `session.identified` é um assign do `ChatLive` e
que uma aba satélite não tem como lê-lo. Falso, e a evidência estava a três
greps: `Services.NickServ.identified?/1` mantém o conjunto em runtime, e o
assign do chat é **espelho dele** — `helpers/session.ex:520` e
`account_events.ex:130` leem exatamente essa função para montar o assign. Há
até um comentário no repositório dizendo que restaurar o conjunto importa
porque "downstream checks (virtual spaces, P2P) wrongly deny access".

Então a superfície pergunta ao domínio. Nenhum token novo, nenhum fato novo — o
terceiro dos três caminhos listados no plano já era verdade.

### `Topics.channel_calls/1`: a antessala precisa de um tópico que não seja a conversa

O roster da antessala tem que se mexer sozinho, e as quatro transmissões de
ciclo de vida da chamada saíam em `channel:#nome` — o tópico da conversa. Uma
superfície de chamada assinando ali receberia toda mensagem de um canal
movimentado para desenhar uma lista de nomes.

As seis transmissões passaram para `channel:#nome:calls`. Um publicador, um
tópico, dois assinantes: o chat (que já assina junto com o canal) e a chamada.

### Cinco defeitos que só apareceram rodando

1. **Id duplicado no DOM.** Os dois hosts renderizavam o mesmo
   `GroupCallConfirmDialog` com o mesmo id, e os dois estão na tela ao mesmo
   tempo quando a chamada está embutida. O LiveView levanta erro em teste — e
   estava certo. O diálogo do chat (só a troca de canal) ganhou id próprio, e
   os `data-testid` internos passaram a derivar do id em vez de serem literais.
2. **`update/2` com cláusula nova engoliu o `id`.** Ao aceitar `scope` do host,
   a cláusula `update(%{scope: scope}, socket)` casava o mapa inteiro e
   atribuía só o `scope` — o `id` que o LiveComponent sempre recebe sumia. Todo
   render do chat morria.
3. **O protocolo de comando não casava.** O chat manda
   `{:call_surface_command, {:event, nome}}`; o `CallLive` casava
   `{:call_surface_command, evento}` e passava a tupla para `handle_event/3`,
   que caía no catch-all. O botão de parar da barra de status e a troca de canal
   ficavam mudos — e nenhum erro em lugar nenhum, que é o modo de falha que a
   casa chama de "silent catch".
4. **`live_render` embrulha o filho numa div sem altura.** A antessala tinha
   `h-full` e ficava com 400px numa janela de 660: o `h-full` resolvia contra a
   div que o `live_render` insere. Só o screenshot mostrou isso — nenhum teste
   olha altura. `container: {:div, class: "h-full min-h-0"}`.
5. **O summary do broadcast parou de entrar na chamada.** `mark_channel_call_active`
   fazia duas coisas: o badge e a fusão do roster no `@group_call`. Ao mover o
   read-model para o chat, a segunda metade ficou sem dono e os participantes só
   mudavam pelo hook. Voltou como `Events.apply_summary/3`, no filho, que é onde
   ela pertence.

### O teste que se dividiu, e o `call_view` de duas voltas

`group_call_flow_test.exs` (2.400 linhas, 36 testes) passou a mirar o filho:
`call_view(view)` acha o `live_children` do módulo `CallLive`, e **drena as duas
caixas de mensagem duas vezes** — a primeira volta faz a chamada processar o
controle encaminhado, e o `send_update` que esse controle emite só está na
caixa depois disso. Uma volta só deixava o diálogo de confirmação fechado.

Os 36 testes ficaram verdes com a régua clara: o que a chrome do chat desenha
(`group-call-window`, `-taskbar`, `status-bar-group-call`, `-open`, o popover do
badge) continua no pai; tudo dentro do painel é do filho.

### Três coisas que já estavam vermelhas antes de eu chegar

Registro porque custaram tempo e porque a próxima pessoa vai topar com elas:

* **`chat-group-call.spec.ts` tem dois testes que falham no `HEAD`** —
  "pre-join can enter with microphone and camera disabled" (o helper procura uma
  chave `rhc:group-call:prejoin:` no localStorage que **não existe em lugar
  nenhum do repositório**) e "two identified channel users join…" (a janela
  maximizada da chamada cobre a barra de status do chat, e o clique não alcança).
  Verificado com `git stash`: falham iguais sem as minhas mudanças. Playwright
  não está no `make ci`, então a suíte derivou.
* **`assets/scripts/surface_snapshot.sh --check` já reprova no `HEAD`** — três
  `dataset.*` de outra mudança. Não regenerei: seria assinar a deriva de outra
  pessoa no meu commit.
* **Os catálogos `.po` de `group_call` estavam parados** — 15 msgids existiam no
  `.pot` e nunca tinham sido mesclados em 13 locales. O meu merge trouxe todos,
  vazios. Traduzi os 15 junto com os meus: são rótulos de recuperação de mídia
  (Attempt, Trigger, Rejoining…) e é a mesma feature.

### A armadilha do glossário, quase pela segunda vez

Ia adicionar `"Chat"` ao glossário curado para o link de volta. O glossário é
**global entre domínios**: rodá-lo reescreveu `Gesprek` → `Chat` em nl e
`Rozmowa` → `Czat` em pl em catálogos que já tinham escolhido a palavra. É
exatamente o erro que a entrada `"Enter"` quase cometeu na iteração 10.

Removido do glossário, com o porquê escrito ao lado da nota do `"Enter"`. O
rótulo foi traduzido dentro do domínio `group_call`, onde ele vive.

### Verificação

- 36 testes de `group_call_flow_test.exs` verdes; 10 novos em `call_live_test.exs`
  para a montagem raiz (token morto, não identificado, não membro, a antessala
  no primeiro render, o roster, o `JoinToken` verificável, o reattach de quem
  nunca saiu).
- 1.479 testes web + 401 de feature verdes.
- `PerfBudgets.html_bytes(:call)` = 26.118 B raw / 4.920 B gzip, 233 elementos,
  medidos.
- Screenshots (spec descartável, lida e apagada): a antessala dentro do chat, a
  chamada com a barra Share, o card público em `/join/`, e `/call/:token`
  sozinha. Os dois primeiros passes de screenshot pegaram a altura errada da
  antessala e a barra Share solta no canto — nenhum teste veria.

### O gate pegou o que eu não pensei em procurar

`make ci` reprovou duas vezes antes de passar, e as duas foram consequência de
mudanças que eu tinha julgado internas:

* **`runtime_test.exs` assinava o tópico da conversa** para esperar
  `{:group_call_started, …}`. Mover a transmissão para `channel_calls` deixou
  três testes de domínio sem mensagem nenhuma — o preço honesto de mudar um
  tópico, e a razão de o teste existir.
* **Prettier** reprovou o `e2e/tests/chat-call-fault-injection.spec.ts`, onde eu
  tinha trocado um seletor com `sed`. O e2e não está no `make ci`, mas o
  formatador dele está.

**Próximo:** onda 3 (space) reusa `Live.Surface`, `Host` e o mesmo tópico de
canal. A filiação com contagem de superfícies (onda 2 §2.6) **continua aberta**:
enquanto a chamada é filha do chat ela morre com ele, então o problema ainda não
existe — ele nasce quando alguém fechar a aba do chat com `/call/:token` aberta.

---

## Iteração 14 — a filiação deixa de morrer com a aba do chat

**Objetivo:** o item §2.6 da onda 2, o único que faltava: fechar a aba do chat
com `/call/:token` aberta não pode tirar a pessoa dos canais em que a chamada se
apoia.

### Por que não dá para "quem for o último faz a limpeza"

Foi a primeira ideia e ela não sobrevive a dois fatos:

1. **`on_mount` não tem `terminate`.** `Live.Surface` é um hook de montagem;
   `attach_hook/4` cobre `handle_info`, `handle_event` e `handle_params`, e não
   o encerramento. Uma satélite só rodaria a saída se cada LiveView de
   superfície implementasse o próprio `terminate/2` — a duplicação que a onda 3
   herdaria em seguida.
2. **A satélite não sabe de quais canais sair.** Quem sabe é a sessão do chat, e
   quando a saída precisa acontecer esse processo já morreu.

Então o chat **entrega** a saída antes de ir: `Surfaces.defer_part/3` guarda o
nickname, a lista de canais e o motivo, e o `RetroHexChat.Surfaces` executa
quando a última superfície daquela pessoa cai. Monitor, não `terminate` — um
LiveView que morre de exceção conta igual.

O caminho de sempre não mudou: quando o chat **é** a última superfície, ele faz
a saída ali mesmo, síncrona, como sempre fez. O caminho assíncrono existe só
para o caso novo, e por isso nenhum dos 801 testes de LiveView precisou mudar.

### A janela aninhada não é uma superfície, e isso é de propósito

O `CallLive` que o chat renderiza por `live_render/3` **não** passa pelo
`Live.Surface`: um LiveView aninhado não passa pelo router, então o `on_mount`
do `live_session` não roda nele. Ele não se registra, e está certo — ele é parte
do chat e morre junto. Só a rota `/call/:token` é uma superfície de verdade.

Vale escrever porque a intuição diz o contrário e o contador ficaria errado para
mais, que é o modo de falha que o plano chama de "filiação fantasma".

### O buraco que sobrou, dito em voz alta

Um chat que **quebra** (exceção, não fechamento) nunca chega ao `terminate` e
portanto nunca entrega nada. Se ele quebrar com uma chamada aberta, a filiação
sobrevive às duas. É exatamente o que um chat quebrado já faz hoje sem chamada
nenhuma, e fechar isso significaria manter a lista de canais aqui,
continuamente, para um caso que termina em reload. Está no `@moduledoc`.

### O que a saída virou

`cleanup_channels/2` tinha o corpo da saída dentro de um helper chamado
`ChatLive.Helpers` — nome que deixou de ser verdade no momento em que outra
coisa além do chat passou a poder causá-la. O corpo virou
`RetroHexChat.Channels.Departure.part_all/3`, no domínio, e o helper do chat
delega. Os seis chamadores deliberados (`/quit`, Desconectar do menu, takeover,
limpeza de sessão) continuam imediatos e terminais: §2.6 regra 3, e nenhum deles
passa pelo `terminate`.

### O teste que prova a onda, e as duas vezes que ele ficou vermelho

`call_live_test.exs`, "the call keeps the channel membership it stands on":
monta o chat, entra num canal, abre `/call/:token`, **mata o processo do chat**,
e então exige três coisas — a filiação continua, a chamada não está negada, e um
*reload* de `/call/:token` (o caminho exato que o bug negava) passa pela
política. Só depois de fechar a última superfície é que a saída acontece.

Vermelho verificado nos dois lados: sem o portão em `depart_channels/2` a
primeira asserção cai; sem o `run_deferred` no `Surfaces` a última cai.

### Uma armadilha pequena do teste

Um canal vazio desliga o próprio servidor, então `Server.get_state/1` responde
`{:error, :not_found}` — que é uma das formas que "não tem ninguém dentro"
assume. O primeiro helper `members/1` casava só `{:ok, state}` e explodia
justamente quando a saída tinha funcionado.

### Estado

Onda 2 **fechada**. `make ci` verde, 8 testes novos em `surfaces_test.exs`, 11
em `call_live_test.exs`, 801 de LiveView sem edição.

---

## Iteração 15 — o space ganha endereço, e uma medição desmente o plano

**Objetivo:** onda 3 inteira — separar o read-model de conversa, `SpaceLive` nos
dois hosts, a rota `/space/:slug` e o `kind: "space"` no `JoinLive`.

### A régua da onda 2, aplicada de novo — e o plano listava dois a mais

A onda 3 mandava mover quatro assigns. Com o código na frente, dois ficam, e o
motivo é a própria régua ("se o dado só existe enquanto você está dentro, ele
vai"):

* **`channel_view`** é qual aba da conversa está na tela. Existe para quem está
  olhando a barra de abas, não para quem está dentro. Fica.
* **`space_last_avatar`** é a memória do último personagem — e ela **sobrevive a
  cada visita**. O `SpaceLive` é montado de novo toda vez que a aba abre, então
  uma memória guardada dentro dele duraria uma visita só, e o help promete o
  contrário há meses ("o seletor mostra de novo a cada entrada, com a sua última
  escolha"). Quem sobrevive é o chat, então é o chat que lembra: o filho manda
  `{:space_surface_avatar, avatar}` para cima e o pai devolve na `session` do
  próximo `live_render`.

### Nenhum `Host` novo, e o porquê está escrito

A onda 2 deixou em aberto se o `CallLive.Host` sobe para `Live.SurfaceHost` ou
ganha um irmão. A resposta, com o space na frente: **nenhum dos dois ainda**. O
`Host` existe para os três desvios da chamada — um aviso, uma janela, e o que o
host desenha sobre a chamada — e o space não tem nenhum: ele nunca foi janela,
não emite aviso em runtime, e o chat não desenha nada sobre um space em que não
está. Promover agora seria um módulo compartilhado com um usuário só. A onda 4
decide com três pontos de dado.

O que o space precisa é de duas mensagens para cima, e elas viraram
`ChatLive.SpaceEvents`, um hook de `handle_info` como o do group call.

### O tópico do space é um firehose, e a antessala não podia assinar

O roster da antessala tem que se mexer sozinho. O tópico `space:#canal` carrega
**um delta de movimento por passo de cada personagem** — assinar isso para
desenhar uma lista de nomes é exatamente o erro que a onda 2 corrigiu criando
`channel_calls`.

Então: `Topics.space_roster/1`, publicado de `update_participant_counts/1` — o
único ponto por onde toda mudança de presença do space já passava. Um publicador,
um tópico pequeno, dois assinantes (a antessala agora; o card ao vivo do chat
depois). O teste que prova que vale a pena é o que anda um passo e exige silêncio
no tópico do roster.

### Uma surpresa do domínio que mudou o desenho da antessala

O primeiro teste do roster falhou dizendo que "ana" e "bob" já estavam dentro de
um space que ninguém tinha aberto. Não era bug: **num space de canal, todo membro
do canal é desenhado no mapa**, viewer ou não (`add_channel_member` entra com
`online?: true`). O roster está certo — são exatamente os personagens que você
veria ao entrar.

Isso tem uma consequência boa: `VirtualSpace.roster/1` pode responder para um
space **sem processo nenhum**, lendo os membros do canal. Ligar um mundo só para
perguntar quem está nele seria pior que ler a resposta fria — e sem isso a
antessala dizia "ninguém está aqui ainda" para um canal cheio, que é a primeira
coisa que o teste pegou.

### O endereço: `/space/:slug`, e o slug é o id codificado

Um space não tem token porque não tem sessão: ele não começa nem termina, então o
que um link nomeia é o **lugar**. O id é `#canal` ou `dm:a:b`, e nenhum dos dois
cabe cru num segmento de caminho — `#` é delimitador de fragmento, e um nome de
canal privado lido da barra de endereços vaza o que o `ux.md` §2.2 diz para não
vazar.

`RetroHexChatWeb.SpaceRef` codifica, decodifica, **e** monta o id do elemento —
porque é a mesma codificação, e `space_dom_id/1` é contrato com o
`SpaceCanvasHook` e com quatro specs. Escrevê-la duas vezes é como as duas
divergem em silêncio. Teste próprio, incluindo o round-trip e as três formas de
slug inválido.

### Três defeitos que só apareceram rodando

1. **`members` é lista de tuplas, não mapa.** `Map.has_key?(members, nickname)`
   estourou `BadMapError` no primeiro teste de política. O `CallLive` já fazia
   `Enum.reduce` sobre a mesma forma; eu escrevi a versão que parecia certa.
   Corrigido comparando em minúsculas, que é a comparação que o próprio space faz
   quando o canvas entra.
2. **A barra Share sumia junto com a antessala.** O spec de screenshot tentou ler
   a URL depois de entrar no space e não achou nada — porque a barra vive na
   porta, e depois de entrar a porta não está mais lá. É o desenho certo (uma
   barra sobre o mapa tira pixels da coisa que a pessoa veio ver); o spec é que
   lia tarde.
3. **`Share` e `Abrir em uma aba` com alturas diferentes.** Só o screenshot
   mostrava: um era botão automático e o outro um bloco de largura total. Nenhum
   teste olha isso.

### A medição que desmente o plano

A onda 3 dizia que "o ganho de event loop aqui é o maior de todos". Medido
(Chromium, Apple Silicon, servidor local, 100 mensagens de canal em 8 s):

| | aba própria | mesma aba |
|---|---|---|
| frames desenhados pelo space em 8 s | 2.466 | 2.098 |
| p50 / p95 / máximo do intervalo entre frames | 8 / 9 / 14 ms | 8 / 10 / 16 ms |
| intervalos acima de 50 ms | 0 | 0 |

O isolamento existe — 17,5% mais frames — mas **ninguém sente**: nem um único
intervalo acima de 50 ms nos dois modos, p50 idêntica. O stream do chat não
chega perto de fazer o space engasgar nesta máquina. O ganho de event loop é um
teto, não um alívio; o que justifica a aba própria é o que a onda 0 mediu
(1.203 ms contra 12 ms quando a outra aba trava de verdade), mais o endereço e a
sobrevivência.

Escrito no arquivo da onda em vez de escondido. A intuição estava otimista, e a
medição é quem decide.

### Uma primeira tentativa de medir que não mediu nada

`PerformanceObserver({entryTypes: ["longtask"]})` na aba do chat devolveu zero
long tasks nas três configurações. Não é que não haja custo: é que nada passou de
50 ms, que é o piso da API. Trocado por intervalos entre frames de `rAF`, que
tem resolução para o que estava acontecendo.

Armadilha adjacente: uma aba em segundo plano tem o `rAF` estrangulado pelo
navegador, então medir "a aba do chat enquanto o space roda atrás" mede o
estrangulamento e não o custo. A medição que sobrou põe **o space na frente** nos
dois modos, que é a única comparação justa.

### Um `а` cirílico num apelido de teste

O spec de medição falhou com "element(s) not found" no `/connect`. O prefixo do
apelido era `"ltа"` — com um `а` cirílico que entrou junto do texto. O validador
de apelido recusou, e o erro apareceu três telas adiante.

### Verificação

- 18 testes em `space_live_test.exs` (montagem raiz), 6 em `space_surface_test.exs`
  (a costura com o chat), 6 em `space_ref_test.exs`, 5 em `roster_test.exs`.
- 1.529 testes web e 3.718 de domínio verdes.
- `space_channel_test.exs` **inalterado** — o transporte não foi tocado, que era
  a prova que a onda pedia.
- Os cinco specs Playwright de space existentes, verdes sem edição; três novos
  (`space-surface.spec.ts`, SP6–SP8) verdes em **Chromium e Firefox**.
- `PerfBudgets.html_bytes(:space)` = 12.481 B raw / 2.991 B gzip, 107 elementos —
  a menor superfície do app, porque o mundo que ela abre é um canvas que o
  cliente preenche.
- Screenshots (spec descartável, lida e apagada): a antessala nos dois hosts, o
  space nos dois hosts, e o card público de um link de space.

### O que continua vermelho e não é meu

`assets/scripts/surface_snapshot.sh --check` segue reprovando no `HEAD`, agora
com quatro `dataset.*`. Esta onda **não tocou uma linha de JS**, então nenhum dos
quatro é meu, e regenerar seria assinar a deriva de outra pessoa. Ele não está no
`make ci`.

---
