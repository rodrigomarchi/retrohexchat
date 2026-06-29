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

**Como resolver (NÃO é wrapper):**
- input **controlado** (`value={@draft}` + `phx-change` no componente, `@myself`), OU
- `phx-update="ignore"` no container do input, OU
- sub-forms **OWNED pelo componente**: eventos do sub-form com `target: @myself`,
  e o commit na session sobe via `send(self(), msg)` + hook `handle_info` (padrão
  sound-settings, plano 34). Isso evita o mismatch de cid.

Se nenhum couber no tempo, **mantenha o dialog inline** (function component) e
marque `blocked` no board com o motivo — é mais barato que um wrapper quebrado.

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
