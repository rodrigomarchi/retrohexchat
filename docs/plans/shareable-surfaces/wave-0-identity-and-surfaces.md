# Onda 0 — identidade multi-aba e a primeira superfície satélite

**Depende de:** nada. É o pré-requisito de todas as outras.

**Entrega:** uma segunda aba do app deixa de matar a primeira, e `/play/:game`
prova isso ponta a ponta com um link que já dá pra mandar pra alguém.

---

## 1. O bloqueio, exatamente onde ele está

`ChatLive.mount/3` transmite `{:force_disconnect, …}` em `Topics.inbox(nickname)`
antes de se inscrever no tópico, e espera o ack:

```
live/app/chat_live.ex:139-150   broadcast {:force_disconnect, %{takeover_ack: …}}
live/app/chat_live.ex:256       wait_for_takeover_cleanup/1
live/chat_live/pubsub_handlers/membership.ex:211   quem recebe, morre
```

O mesmo tópico e a mesma mensagem carregam **dois significados diferentes**:

1. "outra aba assumiu esta conversa" (takeover) — deve matar só o chat anterior;
2. "você foi banido / o servidor foi zerado"
   (`pubsub_handlers/server_messages.ex:121`) — deve matar **tudo** que a pessoa
   tem aberto.

Hoje eles são indistinguíveis, então qualquer superfície nova que escute a caixa
de entrada morre em todo login, e qualquer superfície que não escute sobrevive a
um ban. Separar esses dois significados é o trabalho desta onda.

## 2. O que muda

### 2.1 Escopo na desconexão forçada

1. `RetroHexChat.Topics` ganha `surfaces/1` → `"user:#{nickname}:surfaces"`.
   Construir sempre por `Topics`, nunca com string literal (`AGENTS.md`).
2. O payload de `:force_disconnect` ganha `:scope` — `:chat` ou `:all`.
3. Um único ponto de fan-out no domínio (`RetroHexChat.Accounts` ou
   `Presence`, o que o `Policy`/`Queries` local indicar): `:chat` publica só em
   `Topics.inbox/1`; `:all` publica em `Topics.inbox/1` **e**
   `Topics.surfaces/1`. Ninguém mais transmite essa mensagem à mão.
4. `ChatLive` continua transmitindo takeover com `scope: :chat` — o comportamento
   dele não muda em nada, e `e2e/tests/multi-tab-takeover.spec.ts` continua verde
   sem edição.
5. Ban de servidor e nuke passam a usar `scope: :all`
   (`pubsub_handlers/server_messages.ex:121` hoje reencaminha para o handler de
   `Membership` — o reencaminhamento fica, o escopo entra no payload).

Sem catch-all comendo mensagem: a superfície satélite assina **só**
`Topics.surfaces/1`, que carrega exclusivamente eventos de ciclo de vida. Ela não
assina a caixa de entrada, então não precisa de cláusula que ignora PM.

### 2.2 `RetroHexChatWeb.Live.Surface` — o `on_mount` das satélites

Um `on_mount` compartilhado por toda superfície satélite. Ele faz, e só faz:

* lê `chat_nickname` da sessão HTTP; ausente → `push_navigate` para `/connect`;
* `ServerBans.banned?/1` → `/connect?reason=banned` (mesma checagem de
  `chat_live.ex:101`, agora num lugar só);
* assina `Topics.surfaces(nickname)`;
* resolve timezone e `client_info` reusando `App.SessionHelpers`;
* atribui `:surface_nickname`, `:surface_identified`, `:timezone`, `:client_info`.

O que ele **não** faz, e cada "não" aqui é um bug que já existiria sem ele:

* **não** transmite `force_disconnect` — é o que deixa a aba coexistir;
* **não** chama `Tracker.track/…` nem `safe_untrack_user/…` — presença global
  continua sendo propriedade exclusiva da sessão de chat, senão fechar a aba da
  chamada derruba a presença de quem ainda está no chat;
* **não** escreve `ReconnectState`, `WhowasCache` nem `last_seen` — isso é
  `ChatLive.terminate/2` (`chat_live.ex:281`) e continua sendo.

**Decisão de presença registrada aqui:** ficar só na aba da chamada não te deixa
"online" no chat. A verdade sobre quem está numa chamada é a lista de
participantes da sala (`GroupCall.Queries`), não a presença global. Alternativa
rejeitada: uma segunda fonte de presença, que é forkar o conceito.

**O que ele vai fazer, mas ainda não:** registrar a superfície aberta num
registro por nickname. Esse registro é o que mantém a filiação a canal viva
depois que a aba do chat fecha ([onda 2 §2.6](wave-2-conference-surface.md)) e o
que a onda 6 usa para decidir entre "abrir" e "focar". `/play` não precisa dele
(jogo solo não depende de canal), então ele nasce na onda 2 — mas nasce **dentro
do `Live.Surface`**, não num módulo paralelo. Deixar o gancho previsto aqui.

### 2.3 `/play/:game` — o canário

Superfície mínima real: jogo solo, sem token, sem política, sem sinalização.
Serve para provar a coexistência de abas com o menor risco possível, e já entrega
valor (um link direto para um jogo é compartilhável hoje).

Aplicando D2 (um módulo, dois hosts) na sua menor forma:

1. Criar `RetroHexChatWeb.App.PlayLive` — LiveView que compõe o componente
   existente `Components.UI.Games.RetroGamesPanel`. Nenhuma marcação nova: a
   regra §9 do `AGENT-GUIDE` vale igual aqui.
2. `PlayLive` monta em dois lugares:
   * root, em `/play/:game` (e `/play` para a biblioteca);
   * nested, via `live_render/3` dentro do slot da janela `retro-games` em
     `chat_live.html.heex:605`.
3. **Deletar** `ChatLive.Components.RetroGamesIsland` e
   `ChatLive.RetroGamesEvents` — o `pushEvent` do `RetroGameCanvasHook` passa a
   chegar no `PlayLive` aninhado.

   O summary que a ilha mandava para o host **não** precisa de substituto:
   `@retro_games` (`chat_live.ex:981`) é atribuído e nunca lido — nem no
   template, nem em menu, nem na taskbar. A máquina inteira sai junto. Medido na
   [iteração 2](PROGRESS.md), não suposto.
4. O ícone/menu do chat que abre Retro Games ganha, no desktop, um segundo
   caminho: abrir em aba. `desktop_icon/1` já aceita `href`
   (`components/ui/layout/desktop.ex:127`), então isso é uma âncora com
   `target="_blank" rel="noopener"` — **zero JS**, e `noopener` é o que dá
   processo de renderer próprio (ver §2.4).
5. O shell de `/play` reusa `desktop/1` com `persist_key="play"` — chave única
   por LiveView é regra (`guide/windowed-desktop.md`).

### 2.4 A medição que essa onda existe para fazer — feita

**Pergunta:** duas abas da mesma origem compartilham a main thread?

**Método:** perguntar direto em vez de inferir. Um amostrador de
`requestAnimationFrame` na aba do chat registra o intervalo entre frames;
a aba satélite então bloqueia a própria thread por 1.200 ms com um laço
síncrono. Thread compartilhada → o intervalo na aba do chat **é** o bloqueio.
Processos separados → ~16 ms.

**Resultado** (Chromium do Playwright, 2026-08-28, spec descartável):

| Como a aba foi aberta | Maior intervalo entre frames na aba do chat |
|---|---|
| `window.open(url, "_blank")` | **1203 ms** |
| `window.open(url, "_blank", "noopener")` | **12 ms** |

**O argumento de event loop é real, e é inteiramente condicional a `noopener`.**
Sem ele o ganho é exatamente zero: o bloqueio atravessa inteiro. Com ele a aba
do chat não sente nada.

Consequência que já existe no produto: o Arcade abre a janela do jogo **sem**
`noopener` (`arcade_session_hook.js:30`), então hoje ele não tem isolamento
nenhum. Corrigir não é uma linha — o hook faz polling em `_gameWindow.closed`,
e `noopener` devolve `null`. É a onda 5 §2.5.

---

## 3. TDD — escrever nesta ordem, antes do código

### 3.1 Domínio (`:unit`, sem DB)

| Arquivo | Asserção |
|---|---|
| `apps/retro_hex_chat/test/retro_hex_chat/topics_test.exs` | `Topics.surfaces("bob") == "user:bob:surfaces"`; não colide com `inbox/1` |
| `.../accounts/force_disconnect_test.exs` (novo) | `scope: :chat` entrega **só** em `inbox`; `scope: :all` entrega nos dois; `refute_receive` no outro tópico em cada caso |

### 3.2 Web (`:liveview`)

| Arquivo | Asserção |
|---|---|
| `apps/retro_hex_chat_web/test/.../live/app/play_live_test.exs` (novo) | monta com nickname de sessão; jogo desconhecido redireciona; sem sessão → `/connect`; nick banido → `/connect?reason=banned` |
| idem | **o mount NÃO transmite takeover**: o processo de teste assina `Topics.inbox(nick)`, monta `PlayLive`, `refute_receive {:force_disconnect, _}` |
| idem | **o mount NÃO trackeia presença**: `refute Tracker.online?(Topics.presence(), nick)` depois do mount |
| idem | `scope: :all` no tópico de superfícies encerra a superfície; `scope: :chat` não |
| `apps/retro_hex_chat_web/test/.../live/app/chat_live_*_test.exs` | a janela `retro-games` renderiza o `PlayLive` aninhado (`has_element?` no testid do painel) e o summary de taskbar continua chegando no host |
| existente | `multi-tab-takeover` a nível de LiveView continua igual — takeover não regrediu |

Nada aqui pode asserir em `send_update` assíncrono. O summary é verificado por
`:sys.get_state` ou pelo render do host, nunca por espera.

### 3.3 Vitest

| Arquivo | Asserção |
|---|---|
| `assets/test/lib/**` | se o hook do canvas mudar de destino de `pushEvent`, o módulo `lib/` que ele usa continua testado sem LiveView (§15.1) |

### 3.4 Playwright — o teste que é o ponto da onda

`e2e/tests/surface-multi-tab.spec.ts` (novo), com `@flow` para o
`TEST_CATALOG.md`:

1. **mesmo contexto** (mesmo cookie), aba A em `/chat`, conectada;
2. aba B em `/play/hex-pong` — **A continua conectada**: sem `session-alert`,
   `chat-desktop` ainda presente, e B renderiza o canvas;
3. aba C em `/chat` — A morre (takeover), **B sobrevive**;
4. ban do nick por um admin → **A e B morrem**.

O passo 4 é o que prova que o escopo `:all` não virou um buraco de segurança ao
resolver o takeover.

Lembrar: `mix assets.build` antes, e matar o servidor stale da porta do e2e
depois de qualquer mudança em Elixir — senão o spec valida código velho.

---

## 4. Obrigações do repositório

- [ ] **Start menu é superconjunto.** Uma tela nova do window manager herda a
      lista inteira do Start, cinza onde não alcança. Isso custou +17 KB raw /
      +1 KB gzip / **+177 nós** por tela quando a regra entrou
      (`test/support/perf_budgets.ex`, moduledoc). Orçar isso em `/play` desde o
      primeiro commit, não depois.
- [ ] `PerfBudgets.html_bytes(:play)` e `dom_nodes(:play)` com o número medido
      + ~10%.
- [ ] Help topic: como abrir um jogo em aba própria e o que o link `/play/:game`
      faz. É controle acionável, logo é obrigatório (`AGENT-GUIDE` §12).
- [ ] i18n: extract + merge dos domínios tocados.
- [ ] `SURFACE.txt`: eventos de `RetroGamesEvents` que mudarem de dono.
- [ ] `docs/reference/ci-pipeline.md` se a partição de teste mudar de forma.

## 5. Riscos e armadilhas

* **Hooks do chat colados na raiz.** `chat_live.html.heex:1-25` monta
  `DocumentTitleHook`, `SoundHook`, `ShortcutDispatcherHook`,
  `ViewportDetectHook` no shell do chat. A superfície nova precisa decidir um a
  um o que herda; copiar o bloco inteiro traz o título e o som do chat para uma
  aba que não é o chat.
* **`persist_key` colidido** faz a segunda tela restaurar a geometria da
  primeira. Chave única por LiveView.
* **Deletar `RetroGamesIsland` sem migrar o summary** apaga o badge da taskbar
  com a suíte verde — é exatamente o modo de falha que o `WindowRegistry` foi
  escrito para evitar (`window_registry.ex:6-15`). Teste de badge é o canário.
* **A âncora `target="_blank"`** precisa de `rel="noopener"` por decisão de
  arquitetura (§2.4), não por estilo. Sem ele o ganho de processo não acontece e
  a onda 6 fica sem base.

## 6. Pronto quando

Estado em 2026-08-28 — detalhe por iteração em [`PROGRESS.md`](PROGRESS.md).

- [x] `surface-multi-tab.spec.ts` verde (K2 coexistência + takeover, K3 link sem
      sessão).
- [x] `multi-tab-takeover.spec.ts` e `chat_takeover_test.exs` verdes **sem
      edição** — o takeover do chat não regrediu.
- [x] A medição de §2.4 está escrita: 1203 ms com opener, 12 ms com `noopener`.
- [x] `RetroGamesIsland` e `RetroGamesEvents` não existem mais — e o evento
      `open_retro_games` também não.
- [x] `PerfBudgets` para `:play`, help topic, `.pot`/`.po` mesclados.
- [x] `make ci` completo verde — **17/17**, dialyzer incluído.
- [ ] Os 7 `msgid` novos traduzidos — precisa do venv de Argos Translate, ausente
      nesta máquina. Dívida explícita: o `make ci` não cobra cobertura de `.po`,
      então isto não bloqueia, mas o texto novo sai em inglês nos 13 locales.
