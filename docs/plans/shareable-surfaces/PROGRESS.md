# Progresso e aprendizados

Registro por iteração. O plano diz o que fazer; este arquivo diz o que
aconteceu quando fizemos — em especial **o que o plano errou**.

Quando o plano e a realidade discordarem, a realidade ganha: corrigir o arquivo
de onda no mesmo commit e anotar aqui por quê.

**Estado atual:** onda 0 concluída (`make ci` 17/17), pendente só a tradução dos 7 `msgid` novos. Onda 1 não iniciada.

| Onda | Estado |
|---|---|
| 0 — identidade multi-aba + `/play/:game` | ✅ `make ci` 17/17 |
| 1 — `/join/:slug` + card ao vivo | ⬜ |
| 2 — conferência | ⬜ |
| 3 — space | ⬜ |
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
