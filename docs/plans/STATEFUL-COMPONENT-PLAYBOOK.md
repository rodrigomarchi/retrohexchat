# Stateful Component Extraction — Playbook

Receita reutilizavel para extrair um island stateful do `ChatLive` para um
`Phoenix.LiveComponent`. Destilada do plano 09 (primeiro LiveComponent stateful
do app). **Os 50+ pontos restantes seguem este mesmo padrao** — leia isto antes
de cada extracao para nao redescobrir as mesmas armadilhas.

> Atualize este arquivo sempre que um loop descobrir algo novo. Cada aprendizado
> aqui economiza um ciclo de `make ci` (~2min) nos proximos pontos.

## 0a-pre. CLASSIFIQUE antes de pegar (mecânico? dependências?)

> **Leia o `## Classificação para execução (agentes)` no topo do plano + o
> "Mapa de Classificação & Dependências" no `PROGRESS.md` ANTES de começar.**
> Não pegue um plano fora de ordem de dependência (ex.: 11/12/56 dependem de 10;
> 15/16 dependem de 14; 20 depende de 05; 21 depende de 13).

**Checklist "totalmente mecânico" (faça estes primeiro — baixo risco):**
1. **0 sub-forms modal-in-modal** no UI: `grep -c "fixed inset-0"` no
   `components/ui/dialogs/<x>.ex` deve ser **0**. (Se >0 e tiver `<input>` digitado,
   é o anti-padrão de clobber — ver §0a-anti.)
2. **Sem estado compartilhado** com outro dialog (ex.: notify 30 ↔ address-book 31).
3. **Sem async próprio** no events module (`start_async`/`handle_info`); carga
   async vem de fora → vira **passthrough** (ok).
4. **Não é gigante** (≤ ~12 assigns, ≤ ~1 nível de tab).
   Se passar nos 4 → é mecânico (ex.: 32 channel-list, 17 emoji, 44+45, 26, 07, 55).

## 0a-anti. ⚠️ ANTI-PADRÃO: sub-form modal-in-modal com input não-controlado

**Sintoma:** ao envolver um dialog num LiveComponent, um input digitado num
sub-form (overlay `fixed inset-0`) **perde o valor** num re-render disparado por
outro evento (ex.: color-pick) → o submit manda campo vazio → `required` bloqueia
→ o sub-dialog não fecha. **Provado no plano 41 (highlight), 3× em E2E, mesmo com
passthrough puro.** Causa: o sub-form **submete ao PARENT** (`phx-submit` sem
target) mas vive no **DOM do componente** → mismatch de cid quebra a preservação
de valor de input do LiveView.

**Detecção:** `grep "fixed inset-0"` no UI + inputs `<.input>` sem `value=` dentro
do form. Afeta **41 (bloqueado), 30 notify, 31 address-book, 35 perform**.

**Como resolver — REFERÊNCIA: plano 40 channel-central (2026-06-30).** O padrão
canônico (todos os outros — 30/31/35/41 — nascem assim):
1. **Ilha de posse TOTAL:** TODO o dialog vira `@myself`. Em vez de threadar
   `phx-target` elemento-a-elemento, adicione UM `attr :target` ao function-component
   de design-system e aplique `phx-target={@target}` em CADA `phx-click`/`phx-submit`
   (script: `re.sub(r'(phx-(?:click|submit)=(?:\{[^}]*\}|"[^"]*"))', r'\1 phx-target={@target}')`),
   threadando `target` por todos os sub-componentes (tabs/sub-forms). O LiveComponent
   passa `target={@myself}`. Assim os 4 sub-forms `fixed inset-0` submetem ao componente
   que possui o DOM deles → cid casa → o input não-controlado NÃO é clobberado no
   re-render de PubSub. **Não precisa de input controlado nem `phx-update=ignore`** —
   o `target` correto resolve a causa-raiz.
2. **Trabalho privilegiado roda NO componente** (`Server.*`/`ChanServ.*` são context
   calls — um LiveComponent pode chamá-los). Só efeitos da SUPERFÍCIE do chat (linha de
   sistema via `error_event`, que muta o stream do parent) sobem por `send(self(),
   {:cc_system_error, msg})` → `handle_info` no parent. Erros do PRÓPRIO dialog ficam
   inline (`cs_error`/`transfer_error`/`notice`).
3. **Abertura** = adapter mínimo no parent (`send_update(Comp, open: channel)`) — o menu/
   toolbar emite um evento global; o componente carrega o snapshot + gate no `update/2`.
   **Fechar** = adapter `send_update(Comp, close: true)` (o `<.dialog on_cancel>` faz
   `JS.push("close_x")` SEM target → cai no parent; a Close button e o X idem). Tira a
   entrada do `keyboard_events` dismissal — o `<.dialog>` já trata o próprio Escape
   (igual admin/bot).
4. **PubSub** que atualizava o dialog (`maybe_refresh_cc` em 2 handlers) vira
   `send_update(Comp, refresh: channel)`; o componente **self-guarda** (`show and channel
   == aberto`) e no-opa fechado.
5. **Tabs JS-driven** (`tabs_trigger`) embrulham o evento em `JS.push` SEM target → passe
   `on_tab={JS.push("...", target: @myself)}` (não a string). Nos testes, selecione a tab
   por `#dialog-tabs .tabs-trigger[data-target='X']` (escopado — outro dialog pode ter a
   mesma tab) e dispare component-events por `[phx-click='evento'][phx-value-k='v']`;
   `open`/`close` (adapters async) precisam de `render(view)` flush.

Alternativas mais baratas, se a posse total não couber: input **controlado**
(`value={@draft}` + `phx-change` `@myself`) OU `phx-update="ignore"` no container.
Se nada couber no tempo, **mantenha o dialog inline** (function component) e marque
`blocked` no board — é mais barato que um wrapper quebrado.

## 0a. TRIAGE: este dialog precisa de LiveComponent?

Antes de aplicar a receita, decida se o componente stateful e necessario:

- **JS-only (NAO faca LiveComponent):** o dialog e **stateless** (sem draft/
  selecao/dados dinamicos) E ja e aberto/fechado por `show_modal`/`hide_modal`
  (client-side). Os `<.dialog>` do design system **renderizam o conteudo SEMPRE**
  (so alternam a classe `hidden` + um `#{id}-show-trigger` server). Entao um
  assign `show_*` pode ser **vestigial**. Acao: remova o assign + handler server
  e renderize `<.dialog show={false} />`. Ex.: plano 25 (About) — aberto pelo
  logo e pelo menu via `show_modal`, `show_about` so era usado pelo teste.
  > Cheque quem REALMENTE dispara o evento de abrir: se o item de menu usa
  > `on_click={show_modal(...)}` (e nao `on_action`), o evento server e morto.
- **LiveComponent (use a receita abaixo):** o dialog tem estado proprio (draft,
  selecao, target, erro, paginacao) OU precisa de abertura server-driven
  observavel. Ex.: mute (target), delete (target), nick-change (draft+validacao).

## 0. Decisao: o que e do componente vs. do parent

- **Vai para o componente:** estado de **conteudo/draft** auto-contido (query,
  inputs, selecionados, erros locais, indices, resultados, paginacao local).
- **Fica no parent (orquestrador):** estado de **coordenacao global**, em
  especial os flags `*_visible` / `show_*` que o mapa de Escape-dismissal e o
  stacking de overlays em `keyboard_events.ex` (`topmost_dismissals` /
  `secondary_dismissals`) leem por `Map.get(socket.assigns, key)`. **Nao lute
  com isso** — mover esse flag para o componente quebra a coordenacao de Escape.

Regra pratica: se um assign e lido por outro subsistema (keyboard, core_events,
menu), ele e coordenacao → fica (ou espelha) no parent. Se so a UI daquele
island le, vai para o componente.

## 1. Padrao de eventos: ADAPTER (default) vs phx-target

**Default = ADAPTER.** Mantenha os nomes de evento legados disparando no parent
(o modulo `*_events.ex` vira um adaptador fino) e encaminhe para o componente:

```elixir
send_update(MyComponent, id: MyComponent.id(), action: {:input, value})
```

Por que adapter e nao `phx-target={@myself}`:

- Preserva **todos** os contratos de LiveViewTest (testes disparam evento na
  `view`, nao no elemento) e os `data-testid`.
- Preserva JS hooks que dao `pushEvent(...)` para a LiveView raiz (ex.: um hook
  na lista de mensagens que reporta contagem).
- Preserva gatilhos externos (menubar, toolbar, atalhos de teclado) que abrem/
  fecham o island — eles continuam chamando funcoes do adapter.
- **Page Object e specs Playwright NAO mudam** (zero churn de selector).

Use `phx-target={@myself}` apenas quando o componente e 100% dono dos seus
eventos, nenhum hook/gatilho externo depende deles, e voce vai atualizar os
testes para mirar o elemento. (Fase 3 "remocao de legado", normalmente depois.)

Exponha helpers reutilizaveis no adapter (`open/1`, `close/1`) e faca os
gatilhos externos (keyboard/menu/core) delegarem a eles em vez de duplicar
logica de `assign`.

**⚠️ Para um evento mutador que sobe pro parent num form (`phx-submit`), NAO use
`JS.push("evt", value: %{...})` se o dialog vai ter feature test LiveViewTest:**
`view |> element(form) |> render_submit(params)` NAO despacha esse `JS.push`-value
pro parent (so o browser/E2E despacha; disparar por nome tambem funciona, mas
element-click nao). Em vez disso carregue o discriminador via
`<input type="hidden" name="x" :if={@x}>` no form + `phx-value-x` nos botoes de
acao, e deixe o `phx-submit`/`phx-click` como evento STRING simples. Funciona em
`render_submit` E no browser. (Ver Historico 2026-06-29 (a).)

## 2. ⚠️ `send_update/2` e ASSINCRONO sob LiveViewTest

`send_update` dentro de `handle_event` NAO e aplicado antes do `render_click` /
`render_change` retornar. O retorno desses helpers reflete o estado do parent,
**nao** o do componente.

**Fix nos testes:** dispare o evento e leia o resultado com um `render(view)`
separado (a msg de `send_update` e processada antes do novo `render` — mailbox
FIFO):

```elixir
render_click(view, "search_next")
assert render(view) =~ "2/3"      # NAO: assert render_click(...) =~ "2/3"
```

E2E (Playwright) **nao** e afetado — o cliente real aplica os diffs do
`send_update` normalmente.

**⚠️ Generalização (plano 11) — isto também engole `assert_push_event`.** Quando a
lista/stream sai do template do parent (foi pra um island), o render do parent
*depois* do handler vira um **diff vazio** (a mudança foi pro filho via
`send_update`). O LiveViewTest só entrega `push_event`s bufferizados quando um diff
é de fato enviado — então um `push_event` que o handler empurrou (som, title-flash)
NÃO chega ao mailbox do teste sem um `render(view)`. O `push_event` É gerado (dá pra
provar com um `IO.inspect` temporário no ponto do push) — é só entrega. Portanto:
**qualquer assert logo após um `send(view.pid, …)`/evento que agora roteia por um
island precisa de `render(view)` — vale tanto pra assert de DOM/texto quanto pra
`assert_push_event`.** Fix central: se os testes usam helpers tipo `send_new_message`/
`send_user_joined`, ponha o `render(view)` no fim do helper (um render extra é no-op
nos testes que já passam). Sintoma: `assert_receive {^ref, {:push_event, "play_sound",
…}}, ... no matching message after 100ms`, com o evento ausente do mailbox.

## 3. Montagem e contexto do componente

- **Sempre** monte o `<.live_component ...>` no template (NUNCA dentro de
  `:if`). Gate a visibilidade DENTRO do componente. Isso garante que
  `send_update` sempre encontre o componente, mesmo "fechado".
- **⚠️ Raiz: UMA tag HTML estatica.** O `render/1` de um LiveComponent stateful
  precisa de **uma unica tag HTML estatica na raiz**. Renderizar a chamada de um
  function component direto na raiz (`~H"<.some_dialog .../>"`) quebra com
  `ArgumentError: Stateful components must have a single static HTML tag at the
  root`. **Envolva sempre** o function component reaproveitado:
  `~H"<div id={"#{@id}-mount"}>\n  <.some_dialog ... />\n</div>"`.
- **⚠️ Atribua `:id` no `mount/1`** (para singletons com id constante) ou faca o
  merge do `:id` recebido no `update/2`. Se voce sobrescreve `update/2` com uma
  clausula `update(%{action: a}, socket)` que NAO reatribui as assigns
  recebidas, o `:id` some e o `render` estoura `KeyError key :id not found` nos
  `send_update` so-de-acao. Padrao: `assign(socket, id: @id, ...)` no mount.
- O componente recebe o contexto do parent a cada render (visible, identidade,
  canal ativo...). Reatribua com defaults para nao perder contexto quando o
  `send_update` for **so de acao**:

```elixir
defp assign_context(socket, assigns) do
  assign(socket,
    visible: Map.get(assigns, :visible, socket.assigns.visible),
    active_channel: Map.get(assigns, :active_channel, socket.assigns.active_channel)
  )
end
```

- Protocolo de acao limpo: `update(%{action: a} = assigns, socket)` aplica
  contexto + despacha `a`; `update(assigns, socket)` so aplica contexto.

## 4. Trabalho pesado → `start_async/3` no componente

Nunca rode query/DB pesada de forma sincrona num handler de digitacao.

```elixir
start_async(socket, :history_count, fn ->
  {query, Search.count_matches(channel, query, opts)}   # tag com o input
end)

def handle_async(:history_count, {:ok, {query, count}}, socket) do
  # guarda de resultado obsoleto: aplique so se ainda relevante
  socket = if socket.assigns.query == query and socket.assigns.history,
    do: assign(socket, history_count: count) |> recount(), else: socket
  {:noreply, socket}
end
def handle_async(:history_count, {:exit, _}, socket), do: {:noreply, socket}
```

- **Nunca capture `socket`** dentro da task — passe dados puros (strings, opts).
- **Stale-guard sempre**: marque o retorno com o input e descarte se o estado
  mudou (query nova, filtro desligado).
- `handle_async/3` funciona em LiveComponent.
- **Teste em Elixir** com `render_async(view)` — sem JS, o estado derivado vem
  puramente do caminho async, o que isola e prova o comportamento.

## 5. Limpe estado morto ao extrair

Antes de portar um assign, confirme que ele e realmente renderizado
(`grep` nos `.heex`/componentes). No plano 09, `search_results`/`search_messages`
nunca eram renderizados — removidos (ganho de perf: eliminou uma query inutil).
Estado morto descoberto que nao da pra remover agora → registre no plano 54.

## 6. Receita de validacao por slice (gate real)

1. `mix compile --warnings-as-errors` (limpo).
2. Testes Elixir focados do dominio — atualize-os ao padrao `render(view)` do §2.
3. Teste de componente novo (`render_component/2` smoke: visivel/oculto, raiz
   estavel). Comportamento com eventos fica no feature test (integration).
4. **`make ci` → 9/9** (compile, js lint/test, format, credo, css, tests,
   feature tests, dialyzer). **Este e o gate de completude.** Playwright NAO
   faz parte do `scripts/ci.exs`.
5. E2E focado do island (`npx playwright test tests/<spec>.spec.ts`). Qualquer
   falha: prove regressao vs. baseline com `git stash` dos `.ex` +
   `MIX_ENV=e2e mix compile` + rodar o spec. Falha identica no `main` limpo =
   pre-existente (registre na tabela do `57-testing-strategy.md`); passa no
   baseline e falha no branch = regressao real.

> ⚠️ **NUNCA use `git checkout <arquivo>` para desfazer suas edições durante o
> trabalho não-commitado.** Todo o trabalho dos lotes está NÃO-COMMITADO; `git
> checkout` reverte o arquivo para **HEAD** e apaga TODAS as edições não-commitadas
> nele (não só as suas — as dos lotes anteriores também). Para desfazer, use Edit
> para reverter linhas específicas, ou `git stash push <arquivo>` (recuperável).
> Se já apagou: recupere de stashes dropados via
> `git fsck --no-reflog | grep "dangling commit"` → inspecione com
> `git show <sha>:<path>` → restaure com `git show <sha>:<path> > <path>`.
> Para o E2E baseline, prefira `git stash push -- <arquivos>` (não `checkout`).

## 7. Gotchas de lint/typing (recorrentes)

- **Credo "Nested modules could be aliased":** nao chame
  `Fully.Qualified.Module.fun()` inline — adicione `alias` no topo.
- **Format:** linhas longas de `start_async`/pipes quebram o `mix format` →
  rode `mix format` antes do `make ci`.
- **Dialyzer/`@spec`:** toda funcao publica precisa de `@spec`, incluindo
  callbacks do componente: `mount/1`, `update/2`, `render/1`, `handle_async/3`,
  e helpers publicos (`id/0`, `open/1`, `close/1`).
- `dgettext` esta disponivel no componente via `use RetroHexChatWeb, :live_component`.
- `push_event/3` e `start_async/3` estao disponiveis no LiveComponent sem import
  extra.
- **handle_event agrupado:** ao adicionar funcoes privadas num modulo de eventos
  (`*_events.ex`), coloque-as na secao de helpers (fim do modulo), NUNCA entre
  clausulas `handle_event/3` — senao `-W0` quebra com "clauses with the same name
  and arity should be grouped together".
- **Confirm dialog COM target:** o componente e dono do target; o botao confirm
  carrega o id ao parent via `JS.push("evt", value: %{id: @id})` e o parent le de
  params (com clausula fallback `handle_event("evt", _p, socket)`). Inteiros
  sobrevivem ao round-trip JSON. Use quando o parent precisa do target no confirm
  mas o estado e do componente (mesma ideia do hidden input do mute, sem form).

## 7b. Convenções do projeto (CHECKLIST OBRIGATÓRIO — o código já segue, os planos não diziam)

Estas são regras da `CLAUDE.md` + `.specify/memory/constitution.md` que **todo componente
migrado já cumpre**, mas que um agente seguindo só o plano pode esquecer e só descobrir no
`make ci` (gastando um ciclo). Verifique ANTES de declarar complete:

- **`@moduletag :unit` no teste do componente** (Principle IV). O CI separa testes por tag
  (`mix test --only unit` < 10s) — sem a tag o teste não roda no worker certo. Todos os 17
  testes de componente migrados usam `use RetroHexChatWeb.ConnCase, async: true` + `@moduletag :unit`.
- **`@moduledoc` + `@spec` em toda função pública** (Principle VI), incluindo callbacks
  (`mount/1`, `update/2`, `render/1`, `handle_async/3`) e helpers (`id/0`, `open/1`, `close/1`).
  O `@moduledoc` deve explicar a decisão de ownership (passthrough vs. owned, e por quê) —
  veja `FloodProtectionDialog` como modelo.
- **SEM `<svg>` inline** (CLAUDE.md SVG architecture, enforçado por `lint.css`). Ao copiar
  markup do dialog UI, mantenha os `<Icons.* />` — NUNCA cole um `<svg>` cru. Ícone novo →
  módulo em `components/icons/` + `defdelegate` na facade `Icons`.
- **SEM cor hardcoded / `style=` estático** (CLAUDE.md CSS, enforçado por
  `mix audit.styles --strict` = 0 findings). `style=` inline só é permitido para `left`/`top`
  dinâmico e custom properties. Cores vivem no CSS (Tailwind), nunca no Elixir/HEEx.
- **Tópicos PubSub seguem a convenção** (Principle VII): `channel:#{name}`, `user:#{nick}`,
  `p2p:#{token}`, `game:#{token}`, `service:nickserv`. Relevante para planos que tocam PubSub
  (32 join/knock, 48 kick). Não invente tópico novo numa migração.
- **Help docs (Principle XI):** migração **preserva comportamento → NÃO precisa de help topic
  novo**. Exceção: se a migração mudar UI visível, atalho de teclado ou texto user-facing,
  atualize `HelpTopics`. Na dúvida, é preservação → pule.
- **Testes async:** componentes com `start_async/3` testam com `render_async`; mocks só via
  Mox sobre behaviours (mock direto de módulo é proibido); factories via ExMachina.

> **Decisão consciente sobre cobertura (não é violação do Principle IV):** eventos
> component-local (`@myself`) e o caminho modal-in-modal NÃO são alcançáveis por `LiveViewTest`
> (`render_click(view, "evt")` bate no parent, não no componente). Para esses, o teste de
> componente cobre id/render/passthrough e a **interação real fica no E2E dedicado**. Isso é
> intencional e alinhado com "LiveView tests minimal, UI-critical" — registre no Progress Log
> do plano quando um caminho ficar só sob E2E, nunca deixe implícito.

## 8. Ordem de um loop (resumo)

1. `PROGRESS.md` → escolher plano, marcar `in_progress`, log no plano.
2. Ler codigo do island + onde o estado e lido por outros subsistemas (§0).
3. Criar o LiveComponent (mount defaults, update/contexto, render reaproveitando
   o function component existente, dispatch de acoes).
4. Transformar o `*_events.ex` em adapter (`send_update`), expor `open/close`,
   apontar gatilhos externos para eles.
5. Tirar os assigns de conteudo do `assign_defaults`; trocar o template para
   `<.live_component>` sempre montado; remover imports/estado mortos.
6. Atualizar testes (padrao `render(view)`), adicionar teste de componente,
   adicionar teste async se houver `start_async`.
7. `make ci` 9/9 + E2E focado com baseline-check.
8. Atualizar checklists do plano, `PROGRESS.md`, **e este playbook** se aprendeu
   algo novo.

## 1d. Componente dono de STREAM (lista com `stream/4`)

Quando o island renderiza uma LISTA grande/quente (nicklist, viewport, sidebar) e
o objetivo é parar de reatribuir/re-renderizar a lista inteira, o componente vira
dono de um `stream(:items)`. Receita (validada no plano 13, nicklist):

- **O parent pode CONTINUAR dono da lista materializada** se outros subsistemas a
  leem de forma síncrona (no plano 13, `channel_users` é lido pelo tab-complete em
  `MenuToolbarEvents`, pelo context menu via `channel_user_op?/voiced?/muted?`, e
  por core/session). NÃO refatore os leitores. O componente é dono só do `stream`
  de RENDER; o parent empurra deltas. Isso NÃO é "duas formas de fazer a mesma
  coisa": é read-model (lista p/ lógica) + render-model (stream p/ DOM).
- **O ganho dominante é a ISOLAÇÃO por change-tracking, não o delta.** Hoje o `:for`
  da lista mora no template do PARENT → re-renderiza a cada re-render do parent
  (cada msg de chat, digitação, lag). Ao mover o `:for` p/ um LiveComponent, ele só
  re-renderiza quando UMA assign dele muda. Esse é o maior ganho — vem de graça com
  a extração, mesmo que todo delta seja `{:reset, list}`.
- **Protocolo de delta** (helpers no componente que recebem socket e retornam socket,
  chamando `send_update`): `{:reset, items}` (troca de contexto / mudança em massa),
  `{:upsert, item}` (1 item entrou/mudou → `stream_insert`), `{:remove, key}`
  (1 item saiu → `stream_delete_by_dom_id`). Use per-row nos eventos FREQUENTES
  (join/part/kick) e `:reset` nos raros/em-massa (mode/away/rename/mute) — sem
  regressão (reset = o comportamento de hoje) e com ganho onde importa.
- **`dom_id` estável**: passe `dom_id: &row_dom_id/1` no `stream/4` do `mount` E em
  todo `:reset`; `stream_delete_by_dom_id(socket, :items, dom_id(key))` p/ remover.
- **Mantenha o container montado quando "escondido"** (classe CSS `hidden`, NÃO
  `:if`) p/ o stream nunca ser destruído/reconstruído no toggle. Visibilidade que
  outro subsistema lê (`show_nicklist`) fica no parent e chega como `visible`.
- **⚠️ Stream não re-estiliza linhas existentes num re-render comum.** Se uma assign
  de estilo por-item muda (ex.: `nick_color_fn` numa edição de paleta), as linhas já
  no DOM NÃO mudam só porque o componente re-renderizou — você precisa re-`stream`
  (mande `{:reset, items}` de onde a função/paleta é reconstruída).
- **⚠️ Raw Tailwind em LiveComponent fora de `@tailwind_paths`.** O
  `lint.css_consistency` PULA `components/ui/`, `live/app/`, etc., mas NÃO pula
  `live/chat_live/components/`. Markup com classes Tailwind cruas (chrome do sidebar)
  no LiveComponent → "Missing CSS classes". Fix component-first: mova o chrome p/ um
  function component em `components/ui/` (ex.: `nicklist_sidebar/1`) e encaminhe
  globais (`id`/`phx-hook`/`phx-update`) via `attr :rest, :global`. NÃO enfraqueça o
  linter.
- **⚠️ Stream NÃO é sempre a ferramenta certa — às vezes é passthrough puro.** Se a
  lista é PEQUENA **e** o estilo por-linha muda com frequência (badge unread, flash,
  highlight), um stream OBRIGA re-push da linha a cada mudança de estilo (streams não
  re-estilizam num re-render comum). Aí o melhor é: componente recebe os MAPAS CRUS
  como assigns (passthrough), deriva as listas/classes DENTRO do `render/1`, e renderiza
  via `:for` normal. O ganho de isolação (não re-renderizar no hot-path do parent) vem
  de graça via change-tracking — desde que você passe REFERÊNCIAS ESTÁVEIS (o mapa cru,
  não uma comprehension nova a cada render do parent: uma `for ...` inline no template do
  parent cria lista nova toda vez → change-tracking vê "mudou" sempre → re-render sempre.
  Mova a comprehension pra dentro do componente). Validado no plano 05 (conversations):
  zero stream, zero delta, eventos seguem adapters — só extração + derive-inside.
  **Regra:** stream p/ lista grande/append-heavy (viewport, nicklist); passthrough p/
  lista pequena com estilo churny (conversations).
- **⚠️ Read-model NA PRÁTICA quase nunca migra — só o render-model (validado no pior
  caso, plano 10/viewport).** Mesmo no hot-path de mensagens (~30 callsites de stream),
  o parent continuou dono de TODA a paginação/scroll/reconciliação
  (`oldest_message_id`/`has_more`/`pending_channel_msg_id`/`cleared_channel_cutoffs` +
  o swap pending→real e os cutoffs por canal) e o componente ficou dono só do
  `stream(:chat_messages)`. Tentar mover a paginação p/ dentro do componente (o que o
  plano pedia ao pé da letra) significaria reescrever lógica intrincada sem ganho — o
  ganho de isolação já vem de tirar o `:for` do template do parent. **Default: mova o
  render-model, deixe o read-model onde está.**
- **⚠️ Callsite de stream PERDIDO não falha no compile — falha em runtime.**
  `stream_insert(socket, :chat_messages, …)` continua compilando se aquele módulo ainda
  importar `stream_insert/3` (ou for outro stream). Logo um site esquecido vira um erro
  de runtime "stream :chat_messages not found", não um erro de compile. Em refactor de
  muitos sites, o gate de completude é `grep -rn ":chat_messages"` (não o compile).
  Depois remova `import Phoenix.LiveView, only: [stream*]` de cada módulo e deixe o
  `-W0` apontar imports órfãos remanescentes (inclusive `Phoenix.HTML` `raw/1` se você
  moveu o `render_message/1` que o usava).
- **load-more com reconciliação usa `{:reset, items}`, não `at: 0`.** Se a paginação
  atual já reconstrói a janela inteira no load-more (reordena/reconcilia), o delta
  correto é `reset(stream_items)` — idêntico ao comportamento de hoje. `limit: -N` /
  janela de DOM ficam p/ quando a ownership de scroll migrar de fato (no nosso caso,
  plano 56).
- **Teste de componente com stream:** `render_component(Comp, id:, action: {:reset, items})`
  popula o stream e renderiza as linhas (mount → update(action) → render num só passo);
  asserte os `id={dom_id}` e `data-*`. Feature tests existentes que disparam um evento
  de membership e leem a nicklist passam sem flush porque o join ocorre no mount
  conectado (o `send_update` já foi processado quando o assert roda) — mas mantenha o
  §2 em mente se um teste falhar.

## 9. Ilha que vive numa janela (lobby / desktop Win98)

Aplicável quando o LiveView é um **desktop de janelas** (`Desktop`/`desktop_window` +
`WindowManagerHook`), como o `LobbyLive`. Ver a série `docs/plans/lobby/`.

- **A janela é chrome client-side.** O `WindowManagerHook` é dono de posição/tamanho/
  z-order/min-max/open via localStorage. O `desktop_window` é estático e embrulha o
  conteúdo da feature. A ilha é só o **corpo** da janela — montar o `live_component`
  dentro do slot do `desktop_window`. Change-tracking atualiza só o corpo; o chrome
  não re-renderiza.
- **A ilha dirige a PRÓPRIA janela (regra C3).** `push_event("window_command",
  %{action: "open"|"close"|"flash", id: "<janela>"})` **funciona de dentro de um
  LiveComponent** — o `this.handleEvent("window_command", ...)` do hook
  (`window_manager_hook.js`) não é escopado a um elemento, então capta o push de
  qualquer LiveComponent. Logo a ilha abre/fecha/pisca a própria janela sem rotear
  pelo pai.
- **Eventos `on_close` da janela viram adapter (regra §1).** Um `on_close="end_call"`
  no `desktop_window` dispara no pai por padrão; mantenha-o como adapter fino →
  `send_update(Ilha, ...)` para preservar `data-testid`/contrato Playwright (ou use
  `phx-target` direto na ilha se o testid for preservado).
- **Taskbar + janela agregadora ficam no pai (read-model, regra C2).** Badges da
  taskbar e qualquer "janela de status" que lê várias features são **leitores
  cross-cutting** → ficam no template do pai. A ilha espelha um **resumo mínimo** via
  `send(self(), {:feature_summary, key, summary})` (em LiveComponent `self()` é o pid
  do pai); o pai guarda só o resumo. Zero refactor dos leitores. NÃO extraia a janela
  agregadora para uma ilha.
  - ⚠️ **O bubble por TUPLA é silenciosamente engolido pelo catch-all do pai** se este
    tiver `handle_info(_msg, socket)` e as demais cláusulas casarem outro shape (ex.:
    `%{event:...}` de PubSub). É a classe do bug do plano 41. **Adicione a cláusula
    `handle_info({:feature_summary, ...})` explícita ACIMA do catch-all** e teste que o
    resumo chega (badge/strip muda). Vale para QUALQUER `send(self(), tupla)` ilha→pai.
- **Sink compartilhado (mensagens de sistema, regra C1):** se uma lista (ex.: chat) é
  alimentada por várias features, a ilha dona da lista expõe um `update/2` que aceita
  `{:system_message, txt}`; as outras ilhas/pai fazem `send_update(... system_message:)`.
  Mesmo shape do "PubSub notification queue (kick, plano 48)".
- **Hook persistente ⇒ ilha sempre montada.** Se a feature tem um hook que precisa
  ficar vivo a conexão inteira (WebRTC/file/game data channel), a ilha é **sempre**
  montada (nunca dentro de `:if` da janela); visibilidade da janela é client-side. O
  latch tipo `ever_connected`→`mounted` continua no pai e chega como assign
  passthrough. Fechar a janela (X) só esconde — não desmonta a ilha nem mata a feature.
- **PubSub fica no host.** Mantenha a assinatura do tópico (`lobby:#{token}`) no pai;
  os `handle_info` de feature viram adapters finos → `send_update(Ilha, ...)`. Uma
  assinatura, estado na ilha.

## Historico de aprendizados

- **2026-06-28 (plano 09):** padrao adapter + `send_update` async + flush via
  `render(view)`; sempre montar o live_component; `start_async` com stale-guard
  validado por `render_async`; remocao de estado morto (`search_results`);
  baseline E2E via `git stash`. Primeiro componente e o mais caro (sem
  precedente); os proximos seguem esta receita.
- **2026-06-28 (plano 22, primeiro dialog):** confirmou que a receita escala
  para dialogs com baixissimo esforco (componente de ~55 linhas, 1 slice, `make
  ci` 9/9 + E2E verde de primeira no fluxo real). Dois gotchas NOVOS que valem
  para todo dialog (ja incorporados no §3): (1) **raiz precisa de uma tag
  estatica** — envolver o function component num `<div>`; (2) **atribuir `:id`
  no `mount`** senao `send_update` so-de-acao quebra com `KeyError :id`. Tambem:
  dialogs do design system renderizam o conteudo sempre (escondem via CSS
  `hidden`, nao `:if`) — teste de componente deve cobrir o estado ABERTO via
  `render_component(Comp, action: {:open, ...})`, nao `refute` texto no fechado.
  O fluxo do dialog: abrir via `send_update` do context-menu/menu; submit
  continua no parent (precisa de session/`Server`) e manda `:close` de volta.
- **2026-06-28 (plano 27, confirm dialog):** recipe quase mecanico (3o
  componente). Criterio JS-only vs LiveComponent: se o trigger de abertura vem
  do **dispatch generico de menu/toolbar** (que emite um evento server, ex.
  `disconnect`), prefira LiveComponent+adapter — JS-only exigiria special-case no
  dispatch. Confirm dialogs: mantenha o evento server de confirmacao no parent;
  open/close viram adapters. O `<.dialog>` do design system ja trata Escape
  (`phx-key=escape` -> `on_cancel`), entao confirm dialogs nao precisam entrar no
  mapa de Escape do `keyboard_events`. Flake conhecido de E2E: a **primeira
  abertura da menubar** logo apos connect e instavel (`openFileMenu`) — 1 retry
  resolve; nao confundir com regressao da sua mudanca.
- **2026-06-28 (plano 28, delete confirm):** 4o componente. Introduziu o
  sub-padrao "confirm COM target" (`JS.push` value carrega `message_id`; parent
  faz o `Service` delete). E2E real (O10/R10) validou o round-trip do inteiro.
  Gotcha: helpers privados fora das clausulas `handle_event`. Tambem: ANTES de
  escolher um dialog, cheque entanglement — notify-list (30) compartilha estado
  com address-book (31) (`selected_notify_note`/`show_notify_*` renderizados nos
  dois); fazer juntos. Escolha dialogs self-contained + fora do mapa de Escape.
- **2026-06-28 (plano 25, About — JS-only):** licao de TRIAGE (novo §0a). Nem
  todo dialog vira LiveComponent. About e stateless e ja aberto via `show_modal`
  (logo + menu), entao o `show_about` era vestigial — a solucao certa foi DELETAR
  o assign/handler e deixar function component, NAO criar componente. Comecei
  errado (reflexo da receita) e reverti. Sempre rode a triage §0a antes.
- **2026-06-28 (BATCH 23+24+29 — 3 dialogs num loop):** primeiro lote de 3 feito
  junto (um `make ci` 9/9 + 3 specs E2E focados 8/8). Batching reduz o overhead
  por dialog e a receita ja e mecanica. Tres refinamentos do §0 (ownership):
  - **(a) Escape-managed decide quem e dono do `show`.** Se o `show_*` esta num
    mapa de Escape do `keyboard_events` (`topmost_/secondary_dismissals`), o
    parent PRECISA mante-lo (e lido la) → o componente recebe como `visible`
    (passthrough) e so e dono do *draft*. Se NAO esta em nenhum mapa de Escape
    (ex. nick-change), o componente e dono de `show` direto (como o
    DeleteConfirmDialog) — zero assign de visibilidade no parent. Lembre de
    atualizar as DUAS copias do `close_*` (event module + `keyboard_events.ex`)
    para fazer `send_update`.
  - **(b) Se o form ja submete o campo, o parent NAO precisa de assign pra ele.**
    Hidden inputs (`name=channel`/`name=target`) e `<select>` ja chegam em params
    no change/submit. Entao todo o draft que e tambem campo de form saiu do parent
    (lido de params; so o `send_update` reflete de volta no componente). Encolhe o
    parent mais do que os loops de 1 dialog.
  - **(c) Eventos component-local (`@myself`) ganham de adapter pra eventos que
    nao coordenam nada.** Keyup de senha e Cancel do nick-change ficam DENTRO do
    componente (`JS.push(..., target: @myself)`): sem handler no parent e
    **sincrono** no LiveViewTest (nao precisa de flush `render(view)`). So o
    Confirm sobe pro parent (NickServ.identify + token + redirect e orquestrador),
    carregando estado via `JS.push(value:)` + `phx-value-*`; o handler do parent
    le tudo de params. Reconfirmado: asserts de feature test logo apos
    `render_click`/`render_change` que dependem de `send_update` precisam de flush
    `render(view)` (3 pontos corrigidos no `channel_membership_feature_test`).
- **2026-06-28 (BATCH 36+37+38 — padrao "inline-edit-list"):** trio ISOMORFICO
  (alias, custom-menus, auto-respond — lista + form de edicao inline:
  select/add/edit/save/delete/cancel + error). Escolher dialogs isomorficos pro
  lote maximiza o "aplique o mesmo transform 3×". O padrao reutilizavel:
  - **Eventos de UI pura (select/add/edit/cancel/tab) → component-local
    (`@myself`).** Nao tocam a session, entao vivem no `handle_event` do proprio
    componente e sao sincronos no LiveViewTest. O componente computa sua lista de
    entries a partir do struct de dominio passado por passthrough
    (`AliasList`/`CustomMenus`/`AutoRespondRules`) — assim o `edit` acha a entry
    selecionada localmente. (tab tambem vira do componente: ele computa
    `entries_for(struct, tab)` e o `tab` sai inteiro do parent.)
  - **Eventos mutadores (save/delete/toggle) → adapters no parent carregando
    `selected` via `JS.push(value:)`.** Num `phx-submit`, o `JS.push("evt",
    value: %{selected: @selected})` MESCLA o value com os campos do form — o parent
    le draft + selected num unico params. Faz add/update/remove + persist e reflete
    via `send_update` (`{:saved, ...}`/`{:error, msg}`/`:deleted`/`:reset` no close).
    Selecao inteira (auto-respond `position`) sobrevive ao round-trip JSON.
  - **Variacoes no mesmo padrao:** toggle (auto-respond enable/disable) fica adapter
    PURO no parent — so muta a session, sem estado de UI → sem `send_update`. Evento
    de runtime que nao e UI do dialog (`custom_menu_execute`) fica intacto no parent.
  - **Teste:** o estado "editing" e alcancado via `handle_event` component-local, que
    `render_component` NAO dispara. Entao o teste de componente cobre id/hidden/render
    de linhas (com struct de dominio real via `Domain.new |> add_entry`); o fluxo
    interativo (add→save→edit→delete) fica pro E2E dedicado (o gate real). O botao
    Save fica DENTRO do form `:if={@editing}` → nao aparece no DOM fechado; asserte no
    delete/toggle (sempre presentes) no teste de componente.
- **2026-06-28 (BATCH 34+42+48 — tres patterns novos):** lote misto (sem trio
  isomorfico limpo restante). Tres patterns reutilizaveis:
  - **(a) Child→parent via `send(self(), msg)` + hook de `handle_info` — pra commitar
    um draft-STRUCT que o componente possui na session do parent.** `JS.push(value:)`
    carrega campos de form simples, mas um struct (ex. o draft de SoundSettings) nao
    cabe num phx-value. Entao Apply/OK sao component-local e o componente entrega o
    struct pra cima com `send(self(), {:commit, draft, mode})`; um hook NOVO em
    `info_hooks` (`{:settings_dialogs_info, &Mod.handle_info/2}`, roda antes de
    timer/pubsub) commita + persiste e, no OK, fecha (`show` false + `send_update
    :close`). `self()` dentro de um LiveComponent E o pid do parent LiveView. Hooks de
    `handle_info` retornam `{:halt|:cont, socket}`; ponha um catch-all `{:cont}`.
  - **(b) `select_item` do design system FORCA evento string.** Seu `on_select` faz
    `JS.push(@on_select, value: @on_select_value)`, e `JS.push/2` rejeita `%JS{}` como
    1o arg — entao qualquer evento roteado por um `select_item` NAO pode ser
    `@myself`; tem que ser string que sobe pro parent (adapter → `send_update`).
    `phx-click={@on_x}` aceita `%JS{}` normalmente. Sintoma se errar:
    `FunctionClauseError ... Phoenix.LiveView.JS.push/2`.
  - **(c) Fila de notificacao via PubSub (kick).** Componente dono da fila inteira +
    deriva visibilidade (nao-vazia); nao Escape-managed. O assign do handler PubSub
    (`queue: ... ++ [event]`) vira um `send_update {:enqueue, event}` de 1 linha (o
    resto do handler fica no parent); dismiss component-local. Ao deletar um events
    module vazio, remova as DUAS registracoes de hook (lista do `attach_all_hooks` E o
    module-attr `@event_hook_fns`). Fila com TIMER + prioridade de Escape (invite) e
    orquestrador — deixe no parent.
  - **(d) Dialog de filter/sort/search (url-catcher).** Componente dono do estado de
    view; a lista de dados (log de captura) fica no parent (passthrough); os helpers
    de filtro/sort migram pra dentro do componente. Se o close legado nao reseta a
    view, nao crie `:reset` (a view persiste entre aberturas).
  - **Mecanica de teste:** eventos component-local NAO podem ser disparados por nome
    via `render_click(view, "evt")` (isso bate no parent LiveView) — o feature test
    tem que clicar o ELEMENTO real (que carrega `phx-target`). Adicione `data-testid`
    nos botoes (ex. footer OK/Apply/Cancel) pra poder clica-los.
- **2026-06-29 (BATCH 39+46+43 — timers, paste-confirm, cheatsheet):**
  - **(a) ⚠️ CRITICO — `render_submit` NAO despacha um form `phx-submit={JS.push("evt",
    value: %{...})}` pro parent sob LiveViewTest.** Disparar por nome
    (`render_submit(view, "evt", params)`) funciona; o browser real / E2E funciona; mas
    `view |> element(form) |> render_submit(params)` num form cujo `phx-submit` e um
    `JS.push(..., value:)` chega em NADA (sem erro, sem efeito). Os batches 1–3
    (alias/custom-menus/autorespond) so escaparam disso por serem **E2E-only** — timers
    e o primeiro com feature test LiveViewTest. **Fix robusto: carregue o discriminador
    via `<input type="hidden" name="selected">` no form + `phx-value-selected` nos botoes
    de acao, e torne save/stop eventos STRING simples (bubble pro parent).** Funciona no
    `render_submit` E no browser. **Prefira hidden-input + evento string a `JS.push(value:)`
    em qualquer dialog que va ter LiveViewTest.** Renderize o hidden input so quando o
    valor existe (`:if={@selected_timer}`) — assim "add" cai no `params["name"]` e nunca
    manda id "" (string vazia e TRUTHY em Elixir, entao `selected || name` daria "").
  - **(b) Timers (39) — inline-edit-list, NAO Escape-managed (componente dono do `show`).**
    O mapa de timers em execucao (`user_timers`) e passthrough. `open` flui por
    `send_update {:open}` de DOIS lugares: o adapter `open_timers_dialog` em
    `timer_events.ex` E o path do comando `/timer` em
    `UiActions.Scripting.handle_ui_action(:open_timers_dialog)` (que tambem fazia
    `assign(show_*: true)`) — nao esqueca o path do comando. save/stop = adapters
    string no parent (ver (a)). Feature test dirige o CRUD por element-clicks.
  - **(c) Paste-confirm (46) — content dialog, NAO Escape-managed.** Componente dono de
    `lines`/`flood_warning`/`send_disabled`; `show = lines != nil`. O `paste_lines` do
    parent (evento de `phx-hook`) vira um `send_update {:set, lines, count>50, count>100}`
    de 1 linha; send/cancel component-local — send agenda
    `Process.send_after(self(), {:paste_next, lines}, 0)` (o `handle_info` que ja existia
    no parent) e limpa, cancel limpa + `push_event("focus_input")`.
  - **(d) Cheatsheet (43) — LiveComponent de CONTEUDO ESTATICO (novo desfecho de triage).**
    O plano marcava como "triage / talvez sem migracao", mas havia ganho real: o parent
    recomputava a tabela inteira de bindings (`KeyBindings.defaults`) **a cada render**
    (cada mensagem nova). Mover esse calculo pro `mount/1` do componente (computado UMA
    vez; change-tracking re-renderiza so quando `visible` muda) elimina o trabalho do
    hot-path. Visibilidade Escape-managed → parent mantem `cheatsheet_visible`, passa como
    `visible`; close sobe pro `toggle_cheatsheet` que ja existia. **Regra de triage
    refinada:** conteudo estatico mas CARO de computar vale um LiveComponent (pra parar de
    recomputar no hot-path do parent) mesmo sem draft state — distinto do About (25), que
    era stateless de verdade + JS-only.
- **2026-06-29 (BATCH 32 channel-list + 17 emoji — 17º/18º stateful):**
  - **Channel-list (32):** parent mantém `show_channel_list` (Escape) + lista crua
    `channel_list_channels` + `loading` (passthrough); componente é dono de
    `search`/`selected` e deriva `filtered`. Eventos = ADAPTERS string
    (filter/select → `send_update`; join/knock/close bubble). 3 caminhos de abertura
    (menu, `/list`, conversations "browse all") unificados num `ChannelListEvents.open/1`
    + `close/1` reusado pelo keyboard. Removidos 4 assigns mortos do parent (incl.
    `channel_list_count`, nunca renderizado). Filter/select tests + 1 membership ajustados
    pro flush `render(view)` (§2).
  - **Emoji (17):** parent mantém `show_emoji_picker` (gatilhos EXTERNOS: botão toolbar +
    `EmojiPickerHook` click-outside/Escape pusham pro ROOT LV; seleção fecha pelo parent) →
    `visible`. Componente é dono de `search`/`category`. **Ganho de perf real (triagem como
    cheatsheet 43):** o set completo de categorias era recomputado no template do parent a
    CADA render do bottom-panel; movido pro `mount/1` (UMA vez). Eventos = adapters string.
  - **⚠️ NOVO — connect-burst first-click race (E2E):** `waitUntilConnected()` só espera
    `liveSocket.isConnected()` (handshake WS), que resolve ANTES do join-render assentar. O
    PRIMEIRO `phx-click` logo após connect pode ser engolido pelo burst → o evento "não faz
    nada" (mesma família do flake de menubar U3). Sintoma: clicar abre na 2ª vez, ou após um
    settle de ~2s. **Não é regressão da migração** — provado falhando no HEAD limpo via
    `git stash -u` baseline. **Fix correto = helper de Page Object idempotente que re-clica se
    o alvo não aparecer em ~2s** (ex.: `ChatPage.openEmojiPicker()`), NÃO um `waitForTimeout`
    espalhado nos specs. Atualize o Page Object + `npx tsc --noEmit` antes dos specs.
  - **⚠️ Cuidado com pipe mascarando exit do `make ci`:** `make ci 2>&1 | tail -20` retorna o
    exit do `tail` (0), não do make. Rode `make ci > log 2>&1; echo $?` ou cheque a linha
    `Results: N/9` no output. (Peguei um Format ✗ que o pipe escondeu como "exit 0".)
- **2026-06-29 (BATCH 26 account + 07 topic-bar + 55 toast + audits 53/54 — fim do set mecânico):**
  - **Account (26) — TODOS os eventos viram ADAPTER quando o feature test dispara por nome.** O
    `account_entry_points_feature_test` dispara CADA form por nome (`render_submit(view,
    "account_register_submit", %{...})`), então NENHUM evento pode ser `@myself` (bateria no
    parent). Logo: o componente é dono das 8 assigns de UI e TODOS os handlers ficam adapters no
    parent (fazem NickServ/CommandDispatch/sync_identity) que refletem o resultado de UI de volta
    via `send_update` com um protocolo de ações (`{:open,…}`/`{:auth,…}`/`{:auth_error,…}`/
    `{:auth_reset,…}`/`{:ghost_error,…}`/`{:nick_error,…}`/`{:bio,…}`/`:reset`). Cada assert usa
    `render(view)` fresco = flush do send_update (§2) → 11/11 sem mudar o teste. **Regra:** se o
    feature test dispara por NOME, mantenha adapter + send_update; só use `@myself` quando E2E-only
    ou element-click. Estado de domínio acoplado (`account_registered` via sync_identity, que muta
    a session) FICA no parent (passthrough).
  - **Topic-bar (07) — cleanup sem stateful.** Lógica derivada sai do parent pro function
    component (`mode_badges/2`); parent passa input cru. `attr` que aceita 2 formatos (string crua
    OU lista do showcase) → use `:any`, não `:list`.
  - **Toast (55) — caçar estado morto write-only.** `tips_suppressed` era escrito por um sync
    (`tips_state_sync`) e NUNCA lido → morto. Removido; handler vira swallow `{:halt, socket}`.
    **Cheque `rg "@assign"` por LEITURAS antes de assumir que um assign é necessário — sync
    client→server sem consumidor é morto.**
  - **Audits 53/54 — classificar, não remover por impulso.** `rg` por NOME DE MÓDULO/FUNÇÃO (não
    pelo arquivo — "0 refs" foi falso pq grepei o filename, não `MessageIndicators`/`edited_tag`).
    Saída: showcase-only (channel_dialog, confirm_dialog, chat_layout, tab_bar), pure-em-uso
    (color_picker, message_indicators), owned-em-uso (history_search/scroll_loader/inline_help_card/
    arcade_session_link/p2p_invite_card/message_reply_block — donos sob viewport/row/composer,
    deferidos p/ planos 🔴). ZERO mortos.
- **2026-06-29 (LOTE 5 — flood 33 ✓ / highlight 41 BLOQUEADO + classificação):**
  - **Flood (33):** form NÃO-controlado não tem draft pra extrair (um draft controlado
    adicionaria 1 round-trip por tecla — pior). Logo: LiveComponent **passthrough** puro
    (`visible`+`settings`) com save/reset/cancel STRING bubblando pros adapters existentes;
    parent mantém `show_flood_protection_dialog` (Escape). Zero churn de teste.
  - **Highlight (41) BLOQUEADO** — ver §0a-anti. Modal-in-modal sub-form (Add/Edit) que
    submete ao parent mas vive no DOM do componente → clobber do input digitado. Falhou
    3× em E2E mesmo com passthrough puro. Mantido inline; precisa de sub-forms OWNED.
  - **Lição de processo (custou tempo):** `git checkout <arquivo>` para desfazer edições
    com lotes não-commitados APAGOU o trabalho dos lotes 1–4 no arquivo (revert pra HEAD).
    Recuperado de stash dropado via `git fsck --no-reflog`. Regra agora no §6.
  - **Classificação:** todos os 36 planos pendentes ganharam bloco
    `## Classificação para execução (agentes)` (tier/deps/referência/abordagem/gotchas/
    validação) e o `PROGRESS.md` ganhou o "Mapa de Classificação & Dependências". Set
    mecânico restante: 32, 17, 44+45, 26, 07, 55 (+ audits 53/54).
- **2026-06-29 (plano 10 — viewport, o CORE big-bang):** primeiro stream-owner no
  hot-path de MENSAGENS (nicklist/conversations eram sidebars). Feito como UM refactor
  atômico (~30 callsites em 10 módulos). Confirmou o padrão shared-read-model no pior
  caso: o parent continuou dono de TODA a paginação/scroll/reconciliação e o componente
  ficou só com `stream(:chat_messages)` + `render_message/1`/`message_classes/2`
  (movidos verbatim, com os imports de cards/indicadores). Findings (todos no §1d):
  - **Default: mova só o render-model.** Migrar a paginação pro componente (o pedido
    literal do plano) reescreveria lógica intrincada (swap pending→real, cutoffs por
    canal) SEM ganho — a isolação já vem de tirar o `:for` do template do parent.
  - **Callsite perdido = erro de RUNTIME, não de compile** (`stream_insert` compila se o
    módulo ainda importa). Gate de completude = `grep -rn ":chat_messages"`, não o compile.
  - **load-more usa `{:reset, items}`** (a paginação atual já reconstrói a janela);
    `limit: -N`/janela de DOM ficam pro plano 56.
  - Validação: `make ci` 9/9 (a suíte de 212 feature tests exercita send/edit/delete/
    notice/pm pelo caminho async `send_update` sem falha → LiveViewTest faz flush do
    update do filho dentro do render do feature test). E2E focado 23/23 verde (chat-send,
    -message-rendering, -history-pagination P10 canal+PM sem-dup, -message-actions
    O8–O11, -message-edit-delete-edges R10, -message-retry S10/S11, -notice, -pm).
- **2026-06-29 (plano 11 — status-viewport, o gêmeo):** `StatusViewport` (dono do
  `stream(:status_messages)`, bounded a 500). Trivial porque a inserção tem UM funil
  (`push_status_message/3`) — rerotear 1 chamada migrou ~40 callers. Parent mantém
  `status_unread`/`show_status_tab` (read-model). **Gotcha que custou a depuração
  (agora no §2):** tirar a lista do parent fez o diff do parent pós-handler virar
  vazio → LiveViewTest parou de entregar `push_event`s (som/title-flash) sem
  `render(view)`. 10 testes quebraram afirmando `assert_push_event`/texto logo após um
  `send` cru. O `push_event` É gerado (provado com IO.inspect) — só não é entregue.
  Fix central nos helpers `send_*` + flushes pontuais. NÃO é regressão de produto (E2E
  passa). Também: ao remover o último uso de `<.chat_message>` do parent, o `-W0`
  pegou o import órfão `ChatMessage`. E2E whois-realtime W4 é pré-existente
  (default `:card` vs teste que espera texto — classe J10/J11).
- **2026-06-29 (plano 12 — MessageRow, function component puro):** o renderer de
  linha que o plano 10 moveu verbatim p/ DENTRO do `MessageViewport` saiu p/ um
  function component PURO `Components.MessageRow` (o prompt do plano proíbe um
  LiveComponent por linha — p/ milhares de msgs, function component + stream é bem
  mais barato). `message_row/1` renderiza a LINHA inteira: `<div id={@dom_id}>` +
  classes + `data-*` + o `case` por tipo. **`use RetroHexChatWeb, :html` p/ um módulo
  de HEEx puro** — dá `raw/1` (Phoenix.HTML) + `~p` (verified routes), que
  `RetroHexChatWeb.Component` (o que `components/ui/*` usam) NÃO dá. Um renderer que
  chama `raw(...)`/`~p"..."` precisa de `:html`. **A raiz de um function component
  carrega o `dom_id` do stream**: `<MessageRow.message_row :for={{dom_id, msg} <-
  @streams.x} dom_id={dom_id} .../>` funciona porque o `<div id={@dom_id}>` raiz vira
  o filho direto do `phx-update="stream"` — sem wrapper. Teste com
  `render_component(&MessageRow.message_row/1, assigns)`.
- **2026-06-29 (plano 56 — loading/scroll indicators):** o pedido literal ("mover
  `loading_more` p/ o MessageViewport") colidiria com o shared-read-model do plano 10:
  `loading_more` é lido SÍNCRONO pela paginação (`core_events.ex` debounce) e
  `loading_channel` é escrito pelo channel-switch → ambos read-model, **ficam no
  parent**. Só os 2 VISUAIS (`loading_spinner`, `scroll_loader`) migraram p/ dentro do
  `MessageViewport` como passthrough. **`class="contents"` no root do mount do island
  é transparente no layout** → ao relocar irmãos posicionados (spinner/loader) p/
  dentro dele, eles continuam filhos diretos da coluna, mesma ordem → zero layout
  shift. O DOM-window limit (`limit: -N`) continua deferido (exigiria migrar o
  read-model de scroll, que o padrão evita).
- **2026-06-29 (plano 09 tail — hook anchor + adapter por design):**
  - **Re-verifique uma alegação de "blocked" contra o código antes de herdá-la.** O
    tail do 09 estava "bloqueado no viewport", mas metade já estava feita (o componente
    já emitia os `push_event` de highlight) e a outra metade não estava bloqueada (o
    `SearchHighlightHook` nunca esteve na message list — era um `<div>` solto no shell).
  - **⚠️ Generaliza §1d p/ hook anchors:** um `<div phx-hook=... class="hidden">` cru
    num LiveComponent de `chat_live/components/` quebra o `lint.css_consistency`
    ("Missing CSS classes: .hidden") — esse linter varre `chat_live/components/` mas
    PULA `components/ui/`. Fix: embrulhe o markup cru num function component pequeno em
    `components/ui/` (ex. `SearchHighlightAnchor`), igual ao `nicklist_sidebar`.
  - **`push_event` de um JS hook vai p/ o root LV**, não p/ o LiveComponent em que o
    elemento está aninhado (sem `pushEventTo`). Logo um hook que reporta de volta
    (`search_highlight_count`) justifica MANTER um adapter no parent que faz
    `send_update` ao componente — o adapter é o end-state correto, não um shim. Junto
    com eventos que coordenam visibilidade do parent (`search_visible` lido pelo Escape),
    isso é a regra, não exceção.
- **2026-06-29 (plano 52 admin-console — o PRIMEIRO GIANT; lições de "como atacar um gigante"):**
  - **⚠️ NÃO confunda "baixo risco" com "alto valor".** O alvo da decomposição é encolher o
    `assign_defaults` do parent. Wrappers presentacionais (07/55/04/06/08) são baixo risco mas removem
    ~0 assigns; o estado real mora nos GIANTS (admin-console 32, channel-central 17, bot 8), no composer
    (14/15/16) e nos dialogs entangled (30/31). Quando o set mecânico acabar, vá pros giants — não
    invente mais wrappers. **Meça antes de escolher:** `grep -cE "^\s+[a-z_]+:" assign_defaults` +
    contagem por cluster aponta o maior sumidouro.
  - **Funnel-first: um "giant" costuma ser pequeno por dentro.** admin-console = 1185 linhas, ~40
    handlers — MAS os assigns eram funneled por ~8 helpers `assign_*_snapshot`. Converter os HELPERS
    (+ poucos sites diretos = 16 no total) p/ um único `put_console/2` (`send_update`) migrou tudo.
    **Antes de assumir big-bang, `grep` os SITES de `assign(` (não os handlers):** se um punhado de
    helpers concentra os assigns, o trabalho colapsa. Padrão do helper:
    `defp put_console(socket, attrs), do: (send_update(Comp, [id: Comp.id()] ++ attrs); socket)` —
    retorna o socket inalterado, então o fluxo `{:halt, socket}` e o encadeamento `|>` seguem iguais.
  - **Shared read-model detecta-se também por `Map.get(socket.assigns, :key, default)`** (não só por
    acesso `.key`). Getters de filtro (`users_search(socket, params)` que cai no assign anterior quando
    o params não traz o campo) são handlers IRMÃOS lendo o estado de volta p/ preservar filtro entre
    ações → essas chaves (7 no admin-console) FICAM no parent (read-model, passthrough), só o display
    migra. **Generaliza §1d:** um `Map.get(socket.assigns, …)` num handler irmão é o mesmo sinal de
    "leitor síncrono" que tab-complete/paginação — mantém a chave no parent. (O `grep` de read-deps
    precisa cobrir AMBOS `socket.assigns.key` E `Map.get(socket.assigns, :key`.)
  - **Permissões: passe os booleanos crus, derive os `*_can_*` no `render/1`.** Os 10 flags por-controle
    eram `admin_only?(@session)`/`root_admin?(@session)` inline no template; o componente recebe os 3
    booleanos do `ChatContext` e deriva — tira a computação do template do parent.
  - **§2 em escala:** 13/25 feature tests capturavam `html = render_click/submit` e afirmavam sobre
    conteúdo do dialog que agora vive no componente (async `send_update`) → todos precisaram do flush
    `html = render(view)`. Um transform mecânico (evento; depois `html = render(view)`) resolveu em
    bloco; testes `render_component` não são afetados.
- **2026-06-29 (BATCH 04 shell-header + 06 irc-tabs + 08 connection — o set 🟡 wrapper):**
  - **Wrappers presentacionais (sem estado) — o valor é tirar cálculo/import/DOM do parent + memoização
    por change-tracking, NÃO isolação de re-render como LiveComponent.** Function components
    participam do change-tracking: se as assigns passadas não mudam, o render é memoizado (diff vazio).
    Daí passar PRIMITIVOS escopados (não a struct inteira quando dá) é o que destrava o ganho.
  - **⚠️ NOVO (custou 1 ciclo de `make ci`) — utilitário de layout cru (`ml-auto`/`flex-1`) num glue de
    `chat_live/components/` quebra o `lint.css_consistency`.** O linter varre `chat_live/components/`
    e só aceita classes "definidas" (custom + allowlist) — Tailwind cru solto vira "Missing CSS
    classes". (No batch, `class="ml-auto"` no `ChatShell` falhou; antes ele morava no
    `live/app/*.heex`, que o linter PULA.) **Fix = mesmo split do `nicklist_sidebar`/
    `conversations_sidebar`:** mova o CHROME (markup + a classe de layout) p/ um function component em
    `components/ui/` (recebe primitivos + nomes de evento, ZERO domínio) e deixe no glue scanned só a
    DERIVAÇÃO de domínio (`Session.identity_state`, `ChatContext.admin?`, …) + a delegação `<.chrome …/>`
    (sem markup cru). Ex.: `Components.UI.ChatAppHeader` (chrome, dono do `ml-auto`) ⟵
    `Components.ChatShell` (glue, deriva do `Session`). **Regra:** `components/ui/` = apresentação pura
    (sem `RetroHexChat.*`/`live/`); domínio + glue = `chat_live/components/` (sem Tailwind cru).
  - **Triage de wrapper (3 desfechos, todos vistos no batch):** (a) toca domínio → glue em
    `chat_live/components/` + chrome em `components/ui/` (04 shell, 06 tabs); (b) JS-driven sem estado
    server → function component PURO em `components/ui/` com `phx-update="ignore"` (08 connection — NÃO
    LiveComponent); (c) normalizar dados de lista antes do render → `build_tabs/1` no próprio
    component, tirando as comprehensions + `Map.get` do HEEx (06). Eventos legados (`switch_tab`/
    `toolbar_action`/…) seguem adapters via **attr defaults** → contrato + Page Object intactos.
  - **Flake reconfirmado:** `channel_list_dialog_test` deu Ecto Sandbox ownership error (async DB race
    em `load_channel_messages_with_pagination`) no 1º `make ci`, passou 8/8 isolado, sumiu no re-run.
    Não é regressão de render — provado por isolamento, não por baseline-stash (mais barato quando o
    stack do erro é DB puro, sem relação com a mudança).
- **2026-06-29 (plano 18 — HoverCard, a primeira extração TOTAL sem read-model no parent):**
  - **Um read de coordenação PubSub vira uma AÇÃO condicional que a ilha decide.** Ao
    contrário de viewport/nicklist/conversations (que mantiveram read-model no parent
    porque subsistemas SÍNCRONOS leem a lista), os únicos leitores do `hover_card` eram o
    template + 2 handlers PubSub em `membership.ex` (rename→dismiss-se-nick; away→merge).
    PubSub handlers podem ser reescritos p/ DIRIGIR o componente em vez de LER: viraram
    `send_update {:dismiss_if_nick, nick}` / `{:update_away, ...}`, com a lógica de
    match/merge movida VERBATIM p/ o componente (que decide pelo próprio `card.nick`).
    Resultado: zero read-model no parent — o assign saiu inteiro. **Regra: se TODOS os
    leitores de um estado são template + handlers (event/PubSub), a extração é total;
    read-model só fica quando um subsistema SÍNCRONO (tab-complete, paginação, context
    menu) lê o estado no meio de outro fluxo.**
  - **Cuidado com rótulo "async" na classificação — confirme no código.** O plano 18 dizia
    "lookup async, passthrough do resultado", mas `populate_hover_card` era SÍNCRONO
    (Tracker/Registry/NickServ). Sem `start_async`: o adapter (que tem `session`) computa
    o mapa via função pura e manda por `{:set, card}`. Mesma forma passthrough-result, só
    que síncrona. (Releia o código antes de assumir o gotcha do plano.)
  - **`this.handleEvent` de um JS hook é GLOBAL por LiveSocket, não escopado ao elemento.**
    `dismiss_hover_card`/`channel_tooltip` são tratados pelo `ScrollHook` (em
    `#chat-messages`, dentro do MessageViewport) — um `push_event` de QUALQUER
    componente/handler chega lá. Então mover quem-emite não quebra o cliente; um
    LiveComponent pode emitir um push que outro hook (de outra ilha) consome.
- **2026-06-29 (19 + 21 — migre estados ENTRELAÇADOS como UM cluster, não dois):**
  - **Dois subsistemas que leem o view-state UM DO OUTRO → uma ilha só, não `send_update` ping-pong.**
    Os menus de chat (19) e nicklist (21) compartilhavam o color picker: o "Set Color" do chat reusava o
    `context_menu` (x/y) do nicklist (`socket.assigns.chat_context_menu.x` no site `ctx_chat_set_color`).
    Com os DOIS na mesma `Components.UserContextMenus`, o adapter manda um diretivo `set_color_from_chat`
    e o `update/2` copia o PRÓPRIO `chat_context_menu.x/y` — o parent não lê nenhum dos mapas. **Regra:
    quando A lê o estado de B no meio de um fluxo, co-localizar A+B numa ilha transforma o acoplamento em
    estado local.** (Mesma lógica do bot 49/50/51: um events module + estado partilhado = um componente.)
  - **`update/2` com cláusula de diretivo p/ o acoplamento, default `assign(socket, assigns)` p/ o resto.**
    `def update(%{set_color_from_chat: nick}, socket)` faz a cópia interna; a cláusula final repassa as
    chaves cruas dos adapters (mapas dos menus + passthrough `session`/`channel_users`/`nick_color_fn`).
  - **Antes de threadar o target de uma ação, cheque o `phx-value-*` que o controle JÁ tem.**
    `context_pick_color` lia `context_menu.target_nick` do assign, mas o swatch já renderizava
    `phx-value-nick={@target_nick}` → o handler passou a ler `params["nick"]`, zero leitura de assign. Dois
    testes que disparavam o evento SEM o nick (apoiados no estado escondido do parent) tiveram que mandar o
    nick, igual ao que a UI real manda. **O param do alvo costuma já estar no `phx-value`.**
  - **Limpeza pega leftover de migração ANTERIOR:** `Helpers.Session.close_context_menu/1` ainda resetava
    o `conversations_context_menu` (migrado no plano 20!) + o do nicklist, mas tinha ZERO callers vivos (o
    *evento* `close_context_menu` é do events module). O §5 (limpe estado morto) vale retroativo: ao migrar
    um cluster, `grep` os reset-helpers órfãos deixados pelos planos vizinhos.
  - **Gotcha do plano relaxado conscientemente:** o 21 pedia "resolva o target via stream local de
    usuários, NÃO peça `channel_user_op?` ao parent". Sem stream local nesta ilha, a escolha passthrough-
    read-model (igual 05/13/20) é a certa: `channel_users` canônico passa e `is_target_op/voiced/muted`
    derivam no `render/1`. Um gotcha de plano é a intenção; o padrão estabelecido do projeto vence quando
    diverge.
- **2026-06-30 (14+15+16 composer — o HOT-PATH do input; ilha com bubble + form phx-target):**
  - **Adapter pattern vence até num hot path dirigido por JS hook — ZERO mudança de JS.** O
    `AutocompleteHook` continua dando `pushEvent` ao parent; os handlers viram adapters finos
    (`send_update` com os params crus) e o componente recomputa do próprio estado + passthrough. Evitou
    retargetar ~13 sites do hook p/ `pushEventTo` (e o churn dos testes JS). O mapa SUGERIA pushEventTo; o
    adapter (default) foi mais barato e suficiente.
  - **Só os eventos DOM do próprio form precisam de `phx-target={@myself}`.** `input_changed`/`send_input`/
    toggles são `phx-change`/`phx-submit`/`phx-click` em elementos que o componente renderiza → target no
    `@myself` (adicionei attr `target` ao design-system `chat_input`). Os pushEvents do hook IGNORAM
    phx-target (são globais) → ainda chegam aos adapters do parent. Split limpo: form→componente,
    hook→parent.
  - **Trabalho privilegiado fica no parent via BUBBLE.** `send_input` não roda no parent (precisa dos
    modes/reply_to do componente) nem 100% no componente (CommandDispatch/Service mutam o socket do
    PARENT). Solução: o componente aplica o prefixo de modo + atualiza a própria history + se reseta, e
    `send(self(), {:composer_dispatch, text, reply_to})`; o `handle_info` do parent faz Parser/dispatch.
    **Um componente NÃO muta o parent — quando o trabalho privilegiado mora no parent, faça bubble de uma
    mensagem semântica, não tente fazer no componente.** (`reply_to`, antes lido de `socket.assigns` dentro
    do `command_dispatch`, virou param de `send_plain_message/4`.)
  - **Chave "split-brain" fica onde está seu leitor SÍNCRONO.** `edit_mode_message_id` é lido pelo
    MessageViewport (classe `--editing`) → fica no parent; o componente é dono do ESPELHO do input
    (`edit_original_input`) e restaura via diretivo `exit_edit: :restore|:clear`. Parent dono do id,
    componente dono do texto; `enter/exit_edit_mode`/`set_input` continuam pushes globais do hook.
  - **Coordenação de Escape → um booleano-espelho mínimo no parent (`notice_active`), igual `search_visible`
    (09).** O mapa de dismissal do `keyboard_events` não lê o `notice_target` (agora do componente); o
    componente avisa o parent ao entrar/sair de notice e o parent guarda só o booleano p/ a ordem do Escape.
  - **Custo de teste (§2 em escala, previsto):** 39 firings by-name de `send_input` → submits de form
    element-based (`element([data-testid=chat-input-form]) |> render_submit`), que roteiam ao componente e
    LIQUIDAM o bubble dentro do ciclo de render do LiveViewTest (sem flush extra). Os firings by-name de
    autocomplete (adapters → `send_update` async) PRECISARAM do `html = render(view)`. Cuidado com a forma
    PIPED `view |> render_submit("send_input", …)` e nomes de var fora de `view` (`sender`, `view1`) — um
    regex ingênuo `render_submit(view, …)` perde esses.
- **2026-06-30 (35 perform — clone limpo do plano 40 + o §1d GENUÍNO vs o falso-positivo do admin):**
  - **Full ownership, −8 chaves.** `Components.PerformDialog` é dono do dialog inteiro (`show`/`active_tab`,
    2 seleções, 4 flags de sub-form, todos os eventos `@myself`, lógica `PerformList`/`AutoJoinList`);
    `perform_autojoin_events.ex` 289→~55 linhas (open/close/toggle). Mesmo `target` threading dos 4 sub-forms
    `fixed inset-0` (§0a-anti). Mecânica idêntica a 40/52 — nada novo aí.
  - **⚠️ CORRIGE o §1d do admin (2026-06-29, "as 7 chaves de filtro FICAM no parent"): aquela regra estava
    PELA METADE.** O teste certo do §1d NÃO é "algum handler lê de volta" — é "existe um leitor SÍNCRONO em
    OUTRO subsistema?". No admin os "leitores" eram os handlers IRMÃOS do próprio dialog → mova os eventos
    p/ `@myself` e o read-model vai junto (foi o que o redo fez). No perform é o OPOSTO e LEGÍTIMO: a lista
    perform/autojoin mora no `session`, lido síncrono pelo connect-flow (auto-perform), pelo composer e por
    todo dialog → `session` fica no parent DE VERDADE. **Heurística final:** o leitor é de OUTRO subsistema?
    fica no parent. É só o próprio dialog se relendo? não é §1d — é evento não-convertido.
  - **Mas a MUTAÇÃO roda no componente, mesmo com o estado no parent.** O componente chama
    `PerformList.add_entry/...`, faz `Session.set_perform_list`, e bubbla `{:perform_dialog_session, session,
    kind}` → o parent faz `assign(session:) |> maybe_persist_*`. O componente também assign-a a nova session
    LOCALMENTE (otimista) p/ as entries (derivadas no `render/1`) atualizarem no mesmo ciclo, sem lag. Persist
    é fire-and-forget (Task.start, só-session) → pertence a quem é dono da session = parent.
  - **Matei código morto em vez de "manter por simetria".** O design-system `perform_dialog/1` tinha um attr
    `on_tab` nunca usado no template (tabs trocam por CSS client-side). Em vez de plugar um
    `JS.push(target: @myself)` em coisa nenhuma, removi o attr + o handler `perform_dialog_tab` inalcançável;
    o server só seta o `active_tab` inicial no open. **"Backward compatible" / "por simetria" é cheiro de
    gambiarra — só pode existir UMA forma, a correta.**
  - **Teste:** `perform_dialog_test` (6, `render_component` com `Session` real) + `perform_feature_test`
    27/27. Os testes US2 do dialog viraram element-based; o de "tab switching" agora afirma que AMBOS os
    painéis estão no DOM (troca é client-side, não observável no server); Escape dispara o keydown do próprio
    `<.dialog>` em `#perform-dialog-wrap`. As paths de comando `/perform`+`/autojoin` (US1/US3) ficaram
    intactas (vivem em `ui_actions/perform.ex`, não no dialog).
- **2026-06-30 (41 highlight — DESBLOQUEADO + dois bugs de raiz que afetam TODA ilha que faz bubble):**
  - **⚠️⚠️ O BUG MAIS IMPORTANTE deste playbook: `send(self(), {atom, payload})` 2-tuple é ENGOLIDO.** Os
    hooks `:handle_info` `pubsub_handlers.ex` e `presence.ex` tinham `handle_info({_ref, _result}, socket),
    do: {:halt, socket}` p/ engolir resultados órfãos de `Task`. Mas isso casa com QUALQUER 2-tuple → o bubble
    `{:highlight_dialog_session, session}` era halted ANTES de chegar no `handle_info` do LiveView. Sintoma
    traiçoeiro: a UI fica certa (o componente assign-a a session localmente, otimista) mas o **parent nunca
    atualiza** — persistência não roda, e qualquer outro subsistema que lê a session (aqui: o pipeline de
    highlight) não vê a mudança. **Diagnóstico:** instrumentei `put_session` (rodou) e o `handle_info` do
    parent (NÃO rodou) → a mensagem sumia no meio = um hook engoliu. **Fix correto (na raiz):** guard
    `when is_reference(ref)` nos dois clauses — só resultados reais de `Task` são `{ref, result}` com ref
    `reference()`. Isso DESTRAVOU o highlight E consertou os bubbles de erro 2-tuple `{:cc_system_error}`/
    `{:admin_system_error}`/`{:perform_system_error}` que estavam quebrados em SILÊNCIO (o perform-session
    sobreviveu só por acaso: é 3-tuple `{:perform_dialog_session, session, kind}`). **Regra nova:** todo
    bubble ilha→parent deve ser 3-tuple OU passar pelo guard; e SEMPRE verifique o parent (não só a UI) num
    teste — `:sys.get_state(view.pid).socket.assigns` — quando a session/estado tem leitor noutro subsistema.
  - **Modal-in-modal com RE-RENDER intra-componente precisa de `phx-update="ignore"`, não só `phx-target`.**
    O §0a-anti (phx-target) conserta o clobber quando o re-render vem de OUTRO componente (cid mismatch). Mas
    o highlight-add tem um `color_picker` DENTRO do sub-form: clicar um swatch faz `highlight_color_pick` →
    `@myself` → re-render DESTE mesmo componente → o `<input>` não-controlado da palavra é resetado mesmo com
    cid certo. Fix: `phx-update="ignore"` no input (sobrevive a re-renders do próprio componente, mantém o
    valor digitado; o hidden `bg_color` continua controlado e atualiza). Threading: além do dialog, o
    primitivo `color_picker` ganhou `attr :target` + `phx-target` no swatch (só o highlight e o showcase usam
    seu `on_select`; o context-menu rola swatches próprios com `phx-value-action`).
  - **Sem matcher separado.** O pipeline de mensagens (`pubsub_handlers/messages.ex` → `maybe_highlight`) lê
    `session.highlight_words` no momento da mensagem → basta a session do parent atualizar (depois do fix #1).
    O "rebuild matcher" do plano não existe no código.
  - `make ci` 9/9; `highlight_dialog_test` (5) + `chat-highlights.spec.ts` E2E verde (o que estava ⛔). O
    `chat-highlights-persistence` U2 já falha no main (overlay de "Tip" pós-reconnect) — não relacionado.
- **2026-06-30 (30 notify-list — "estado compartilhado" entre dois dialogs era FALSO problema):**
  - **Dois dialogs que leem o MESMO dado não são "estado entrelaçado" se nunca abrem juntos.** O Notify
    standalone e a aba Notify do Address Book compartilhavam `notify_selected`/`show_notify_*_dialog`/
    `selected_notify_note` no parent → o plano marcou como "entangled, coordenar dono único". Mas são CASOS
    DE USO SEPARADOS (nunca abertos ao mesmo tempo). Isolação correta: **cada ilha é dona da SUA seleção/
    draft/sub-dialog (estado de UI); o DADO (`session.notify_list`) e a LÓGICA de mutação são compartilhados.**
    Sem coordenação de "dono único" — só não duplicar o estado de UI. (A regra: pergunte "esses dois podem
    estar abertos juntos?" Se não, não há entanglement — é só estado de UI que precisa virar local em cada um.)
  - **Lógica de mutação compartilhada por 2 ilhas → módulo PURO, não duplicação nem adapter no parent.**
    `NotifyOps` (session in → `{:ok, session, status} | {:error, status}`, sem socket) centraliza
    add/remove/update/toggles. Cada ilha chama e faz seu próprio bubble + efeitos de socket que ELA não pode
    fazer (timer de debounce, abrir PM, persistência ficam no parent via bubble). Evita os dois extremos:
    duplicar ~150 linhas em cada componente, OU manter os handlers no parent (adapter, que o user rejeitou).
  - **Migração ENCADEADA quando um hook serve dois consumidores.** `notify_events.ex` serve o standalone E a
    aba do Address Book (ainda não migrada). Não dá pra deletá-lo no plano 30 → o standalone vira ilha
    (`@myself`), mas `notify_events` continua vivo p/ o Address Book até o plano 31 (aí é removido). Cada
    commit fica verde. Só removi do parent o que é exclusivo do standalone (`show_notify_list`,
    `selected_note`); as chaves compartilhadas saem no 31.
  - **Teste:** o `is_reference/1` fix do plano 41 já estava no lugar, então os bubbles 2-tuple
    (`{:notify_dialog_session, session}`) chegam ao parent. Convertidos 2 testes que disparavam
    `toggle_auto_whois`/`toggle_auto_add_pm` by-name (agora `@myself` na ilha) p/ click element-based no
    checkbox `#notify-list-dialog-auto-*`. `make ci` 9/9; `chat-notify`+`chat-notify-settings` E2E 6/6. O
    `chat-address-book` O16 falha no main (mesmo overlay de "Tip") — não relacionado.
- **2026-06-30 (31 address-book — o ÚLTIMO gigante; `assign_defaults` 87→71, 210→71 no total):**
  - **Padrão "bubble session + kind" pra dialogs muito parent-coupled.** As mutações (contacts/nick-colors/
    ignore/notify) produzem session nova MAS os efeitos colaterais são do parent: rebuild do `nick_color_fn`
    (lido por viewport/nicklist/sidebar), refresh do message stream, timers de ignore, status bar. Solução:
    a ilha roda o op de domínio e bubbla `{:ab_session, session, kind}` — o parent faz assign+persist e os
    efeitos POR KIND (`:nick_colors` → rebuild fn + refresh stream). `{:ab_status, level, msg}` p/ a
    superfície de chat, `{:ab_ignore_timer, op, ...}` p/ os timers. A ilha é dona de TODO o estado de UI;
    só os efeitos parent-owned sobem. (Não é adapter — a lógica de domínio roda na ilha.)
  - **⚠️ Eventos passados: STRING + `phx-target` ganha de `JS.push(target:)` QUANDO há testes.** Tentei
    `JS.push("evento", target: @myself)` pra evitar threadar target nas tabelas/botões — funciona em runtime,
    mas o `phx-click` no DOM vira um BLOB JSON opaco, então `element("[phx-click='evento']")` nos testes
    quebra. Voltei pra eventos string + threadar `phx-target` pelas tabelas/crud_buttons (o seletor
    `[phx-click='evento']` volta a funcionar). EXCEÇÃO: tabs PRECISAM de `JS.push(target:)` (string perde o
    target no `tab_click`), e o teste de tab seleciona por `.tabs-trigger[data-target='X']` (não por
    phx-click), então tabs com JS.push estão OK. Regra: **string+phx-target pros eventos que os testes
    disparam por nome; JS.push só onde o componente de design exige (tabs).**
  - **Dois bugs de seletor no §2 em escala (ilhas que coexistem):** (1) `notify_*` da aba do address-book
    COLIDE com o dialog standalone (mesmo `phx-click`, cid diferente) → escopar o seletor a
    `#address-book-dialog`. (2) Os botões Edit/Remove por-aba ficam `disabled` até `@selected_tab == "aba"`,
    então o teste tem que TROCAR a aba de verdade (clicar o tab trigger, que faz o `JS.push` rotear o
    `address_book_tab` pro componente) — não basta o conteúdo estar sempre no DOM. Helpers:
    `ab_click`/`ab_select` (escopados), `ab_form` (por data-testid), `ab_tab` (por data-target).
  - **Encadeamento concluído:** com o address-book migrado, `notify_events.ex` foi de volta a 31 linhas (só
    o open do standalone) e `address_book_events.ex` 446→44. Padrão da migração encadeada (plano 30→31):
    deixe o hook compartilhado vivo até o ÚLTIMO consumidor migrar, aí aposente.
  - `make ci` 9/9; `address_book_test` 49 + `address_book_feature_test` 21 + component 6; `chat-notify`/
    `chat-ignore-notifications` E2E verdes. `chat-address-book` O16 falha no main (overlay "Tip") — vou
    consertar esse flake pré-existente a seguir.
- **2026-06-30 (47 invite — o ORQUESTRADOR, último plano; migração completa):**
  - **Read-model NÃO migra quando há (a) leitor síncrono em outro subsistema E (b) timers que disparam
    no `handle_info` do pai.** `pending_invites` é lido sincronamente pelo `keyboard_events` (prioridade de
    Escape: dispensa o invite topo ANTES de qualquer dialog) e cada invite tem um timer de expiração
    (`Process.send_after(self(), {:invite_expired, channel}, 300_000)`) que dispara no `handle_info` do
    PROCESSO PAI — e um `LiveComponent NÃO tem handle_info`. Logo a fila fica no pai; só o **render-model**
    (o stack de cards) + os 2 cliques (Join/Ignore) migram. É o **inverso da kick queue (48)**: kick não
    tinha timer/Escape → a fila inteira virou da ilha; invite tem os dois → a orquestração (enqueue +
    timers + Escape) fica no pai. Tentar mover a fila exigiria um ESPELHO de Escape no pai (tipo o
    `notice_active` do composer) + um round-trip de timer (ilha cria timer → pai recebe `{:invite_expired}`
    → pai reenvia `send_update`) = MAIS maquinaria, não menos. O split correto é o de perform/highlight/
    notify: **pai dono da fila + efeitos (session/stream/timers); ilha dona do render + dos cliques.**
  - **Eventos `@myself` que sobem channel cru → `send(self(), {tag, channel})` → parent `handle_info`.**
    Como TUDO de accept/ignore toca estado parent-owned (a lista + session + stream), a ilha não computa
    nada — só bubbla o channel. O ganho não é encolher `assign_defaults` (a fila fica no pai), é (1)
    isolar o render do hot-path e (2) **tirar `invite_events.ex` da cadeia de hooks de TODO evento**
    (removido de `@event_hook_fns` E `attach_all_hooks`). O módulo deixou de ser hook (`handle_event/3`) e
    virou helpers puros `accept/2`/`ignore/2` que o `handle_info` do pai chama.
  - **`JS.push(target: @myself)` é OK quando o dialog NÃO tem seletor Elixir `[phx-click='…']`.** O blob
    opaco do JS.push só quebra testes que selecionam por phx-click (ver 31). Invite é E2E-only e o E2E
    seleciona por `data-testid` (`invite-join-${channel}`) + `phx-value-channel` (que o `JS.push` mescla no
    payload automaticamente) → `on_accept={JS.push("invite_accept", target: @myself)}` preserva tudo, sem
    threadar `attr :target` pelo design-system. Use a forma mais barata (JS.push) quando não há seletor
    phx-click; só thread `attr :target`+string quando os testes disparam por nome (31/40).
  - **Migração COMPLETA.** Todo dialog/queue do ChatLive é uma ilha LiveComponent. Restam só caudas
    não-ilha: 03 hidden-hooks (segue os componentes donos) e os docs de tracking (01/02/57).
- **2026-06-30 (lobby plano 01, Chat — primeira ilha do desktop Win98, valida §9):** a §9 escala limpa.
  Confirmado em runtime: um `live_component` montado dentro do slot de um **function component**
  (`desktop_window`), que por sua vez é chamado pela LiveView (`universal_lobby/1`), funciona — cid e
  change-tracking corretos, sem precisar promover o `desktop_window` a LiveView. **C1 na prática:** a ilha
  dona da lista expõe DOIS shapes de `update/2` — `{:system_message, txt}` (constrói o map de sistema
  DENTRO da ilha, com seu próprio `system_message/1`) e `{:append_message, msg}` (eco cru do PubSub); o pai
  vira só adaptador `send_update(Ilha, id: Ilha.id(), ...)` em N callsites (aqui 6: 1 eco de chat + 5
  produtores de sistema). O `system_message/1` do pai foi REMOVIDO (a ilha é a única dona). **Wrapper de
  raiz precisa de `class="h-full"`** pra preservar a cadeia `h-full` do panel reaproveitado dentro do
  `window_body` (`flex-1`). `live/app/` é pulado pelo `lint.css_consistency` (lista de skip), então
  Tailwind cru na ilha do lobby passa — diferente de `live/chat_live/components/` (§1d). Sem swallow de
  catch-all aqui porque C1 usa `send_update` (não tupla `send(self(), ...)`); essa armadilha entra a partir
  do plano 02 (C2). Único tropeço: linhas longas de `send_update` quebraram o Format no 1º `make ci`
  (Stage 3/Dialyzer foi skipado em cascata) — rode `mix format` antes do gate.
- **2026-06-30 (lobby plano 02, Game — C2 + C3 estabelecidos):** confirma os dois contratos novos da §9.
  **C3 (ilha dirige a própria janela):** `push_event/3` funciona dentro do `update/2` de um LiveComponent,
  não só no `handle_event` — então os PubSub de feature viram adapters de 2 linhas no host
  (`send_update(Ilha, action: ...)`) e a ILHA dispara `window_command {open|close, id}` + os lifecycle do
  hook (aqui `lobby_game_start`/`lobby_game_end`) de dentro do `update/2`. O `on_close` da janela e um
  botão in-panel podem disparar o MESMO evento string (`end_game`) → um único adapter no host cobre os
  dois sem churn. **C2 (read-model → taskbar):** a ilha faz `send(self(), {:feature_summary, key,
  %{active?: ...}})` (em LiveComponent `self()` é o pid do host) e o host guarda `<key>_summary`; o badge
  lê dele. ⚠️ **A cláusula `handle_info({:feature_summary, key, summary})` TEM que estar ACIMA do
  catch-all `handle_info(_msg, socket)`** — a tupla não casa o shape `%{event:...}` do PubSub e é engolida
  em silêncio (classe do bug do plano 41). O **badge da taskbar é o teste-canário**: um teste que entra/sai
  de "ativo" e asserta o glifo do badge (`=~ "●"`) falha imediatamente se a cláusula faltar. **Ownership:**
  eventos fire-and-forget que só chamam o contexto e cujo resultado VOLTA por PubSub (propose/respond)
  ficam no HOST — a ilha não precisa de token/user_id; só estado + render + window-driving + summary
  migram. **Mecânica de teste:** `Process.sleep(50) + render(view)` drena a cadeia assíncrona inteira
  (event → send_update → ilha → `send(self(), feature_summary)` → host → assign) porque o processo da LV
  roda seu próprio loop independente; `assert_push_event` de um push originado por `send_update` precisa de
  `render(view)` antes (flush). Catálogo estático (`Catalog.list_games()`) carregou no `mount` da ilha —
  saiu do host.
- **2026-06-30 (lobby plano 03, File — hook compartilhado + cross-read rico):** duas lições novas que
  refinam a §9. **(1) Um JS hook que faz `pushEvent` empurra para a LiveView RAIZ, não para o
  LiveComponent**, mesmo que o elemento do hook esteja renderizado DENTRO da ilha. Logo os eventos de
  ENTRADA de um hook compartilhado (aqui `FileTransferHook`, reaproveitado do chat) NÃO podem ser
  component-local — ficam no host como adapters finos → `send_update(Ilha, action: {:ft_event, name,
  params})`. Só a SAÍDA server→client (`push_event`/`window_command`) sai da ilha: o `this.handleEvent`
  do hook escuta o socket inteiro e capta o push de qualquer componente (igual ao `window_command` do
  WindowManagerHook). Truque de escala: ~18 handlers `ft_*` viraram **2 adapters** — um pro nome que não
  casa o prefixo (`file_transfer_ready`) + a genérica `def handle_event("ft_" <> _ = event, params,
  socket)` — e a ilha despacha por nome num `handle_ft/3`. Encolheu o host drasticamente. **(2) O resumo
  C2 nem sempre é "mínimo de badge" — é a UNIÃO do que os leitores cross-cutting do host precisam.** Aqui
  a janela agregadora `conn` (que FICA no host) tem uma strip que lê `file_transfer` rico (status,
  sender_nick, percent, speed, file_name); então `file_summary` espelha esses 5 campos via `Map.take`, não
  só o `%` do badge. Antes de decidir o shape do summary, cheque TODOS os leitores no template do host
  (badge + strip + qualquer agregador), não só o badge. **Constraint do hook-sempre-montado** sai de graça
  com a §9: a ilha é montada via `live_component` (nunca `:if`), então fechar a janela (X→`ft_cancel`)
  só esconde — um teste assertando `phx-hook="FileTransferHook"` ainda no DOM após o cancel prova que o
  data channel não morre. ⚠️ Flake de E2E conhecido: `delivers video both ways` (RTP real, bidirecional)
  falha ~1/2 sob carga e passa quando isolada (`-g`) — é timing de WebRTC headless, NÃO regressão; ao ver
  1 falha de mídia num plano que não toca mídia, isole o teste antes de investigar.
- **2026-06-30 (lobby plano 04, Media — a gigante; série de ilhas do lobby concluída):** a ilha mais
  entrelaçada (PubSub + windowing + sink + devices + `surface_peer_media`) migrou repetindo 02/03 — a
  receita §9 escala até o pior caso. Três refinamentos finais. **(1) Self-contained quando estado e efeito
  são inseparáveis.** No Game os context-calls fire-and-forget (propose/respond) ficaram no host; no Media
  cada `Lobby.set_media`/`broadcast` vem JUNTO de uma transição de `call`/mute/camera, então a ilha recebe
  `token`/`user_id` e chama o contexto + faz `broadcast` ela mesma — partir isso entre host e ilha
  duplicaria a extração de params. A assinatura PubSub continua no host (adapters inbound). Regra: mantenha
  o efeito no host quando ele é independente do estado da ilha; mova-o p/ a ilha quando ele é a OUTRA
  metade de uma transição de estado que a ilha possui. **(2) ⚠️ O `id` da raiz da ilha não pode colidir
  com nenhum `id=` que o function-component renderiza dentro dela.** O `media_panel` já usa
  `id="lobby-media"` (o elemento do `phx-hook`), então a ilha precisou ser `lobby-media-island` — senão
  "Duplicate id found while testing LiveView" em runtime. Cheque os `id=` internos do panel antes de
  escolher o `@id` da ilha; e o `live_component id=` na montagem TEM que casar com `Ilha.id()` (senão o
  `send_update` não acha o componente). **(3) Resumo C2 que muda por segundo (duration tick) → o
  `handle_info({:feature_summary, ...})` só guarda (barato), nada de recomputar.** Single-offerer/signaling
  intocados — a ilha só pede mídia via push ao hook; o backbone WebRTC é do host. **Resultado da série:**
  `LobbyLive` virou orquestrador/agregador puro (backbone + presença + lifecycle + janela Statistics +
  taskbar read-model); as 4 features são ilhas LiveComponent. Os 3 contratos (C1 sink, C2 read-model, C3
  window self-drive) provados e reutilizados nas 4. Gate por tier: `make ci` 9/9 + `chat-lobby` 20/20 cada.
