# Listas da plataforma — refactor de paginação

> Plano para padronizar **toda** superfície de lista da plataforma sob um único
> contrato de paginação por cursor. Auditoria de base: 2026-07-28, varredura dos
> 43 schemas Ecto, de todos os `Repo.all` do domínio e de todos os `:for=` do
> app web.
>
> Contém o contrato, os componentes visuais a construir, a receita de migração,
> o que testar em cada fase, e a ordem de execução. TDD em todas as camadas;
> validação final é E2E Playwright.

## Objetivo

Hoje a plataforma tem **um** infinite scroll (mensagens de chat) e treze outras
superfícies que ou carregam tudo, ou truncam em silêncio, ou nem são listas —
são blobs de texto. Cada uma resolve o problema de um jeito diferente, e a que
funciona tem cinco defeitos.

Ao final:

- existe **um** contrato de paginação, do banco ao hook JS;
- existe **um** conjunto de estados visuais (vazio, carregando, fim, erro,
  truncado) em vez de quinze implementações bespoke;
- nenhuma lista carrega tudo, nenhuma trunca em silêncio;
- adicionar uma lista nova é seguir uma receita;
- a classe de bug "`has_more` errado" é **estruturalmente impossível**.

## O que o refactor entrega

| Camada | Artefato | Substitui |
|---|---|---|
| Domínio | `RetroHexChat.Page` + convenção `list_*/2` | `opts` ad-hoc por query |
| Web (lógica) | `PaginatedList` island behaviour | cada island reinventando stream + estado |
| Web (visual) | 7 componentes de estado de lista (§4) | 15 empty states bespoke, 2 loaders duplicados |
| JS | `InfiniteScrollHook` isolado | gatilho fundido dentro do `ScrollHook` |
| Admin | retorno estruturado dos handlers | `%{content: string}` pré-formatada |

---

## 1. Diagnóstico — por que um contrato, e não catorze correções

Quatro evidências de que o problema é ausência de padrão:

- `phx-viewport-top` / `phx-viewport-bottom` não aparecem em **nenhum** arquivo
  do repositório. O único infinite scroll é um hook manual.
- `primitives/pagination.ex` e `chat/scroll_loader.ex` existem e só são usados em
  `/showcase`. `primitives/skeleton.ex` tem **zero** uso — e viola a regra do
  projeto (`@moduledoc false`, sem `@spec`).
- **Quinze** empty states bespoke, cada um com prefixo CSS próprio (`cl-`, `uc-`,
  `ul-`, `pf-`, `cm-`, `ab-`, `nl-`, `tm-`, `cc-`, `ar-`, `iv-`, `al-`), contra a
  regra Component-First do projeto.
- O cálculo de `has_more` está escrito **três vezes** e uma está errada
  (`helpers/channel.ex:284` usa a lista já filtrada; `core_events.ex:615` e
  `helpers/pm.ex:32` usam a contagem crua). Não é descuido — é o que acontece
  quando a regra mora no call site.

---

## 2. Arquitetura alvo

### 2.1 Domínio — `RetroHexChat.Page` e a regra do `limit + 1`

```elixir
defmodule RetroHexChat.Page do
  @type t :: %__MODULE__{
          items: [struct() | map()],
          next_cursor: term() | nil,
          has_more: boolean(),
          total: non_neg_integer() | nil
        }
  defstruct items: [], next_cursor: nil, has_more: false, total: nil
end
```

Toda função de lista paginada passa a ter a forma:

```elixir
@spec list_x(scope :: term(), opts :: keyword()) :: Page.t()
# opts: :limit, :cursor, :total? e os filtros próprios da superfície
```

**A regra central — busque `limit + 1`, devolva `limit`:**

```elixir
rows = query |> limit(^(limit + 1)) |> Repo.all()
{items, rest} = Enum.split(rows, limit)
%Page{items: items, has_more: rest != [], next_cursor: cursor_of(List.last(items))}
```

`has_more` passa a ser propriedade **do banco**, decidida antes de qualquer
filtro em memória. Filtrar ignore-list, clear-cutoff ou visibilidade depois não
pode mais corromper a paginação. O bug de `helpers/channel.ex:284` deixa de ser
algo que se conserta e passa a ser **inexprimível**.

`total` é opcional e só é calculado quando a superfície exibe contador — é o que
mata o contador mentiroso do Admin (§2.4) sem impor um `COUNT` a toda lista.

**Cursor é keyset, nunca offset.** `before_id` já é a convenção nas mensagens.

**Regra do cursor cru:** o cursor sai da última linha **crua** da página, não da
última visível após filtro — senão a página seguinte re-busca o que foi
escondido (é o que `helpers/channel.ex:270` faz hoje).

### 2.2 Web — o island `PaginatedList`

| Elemento | Regra |
|---|---|
| `stream` | sempre com `limit:` negativo e `dom_id:` estável |
| assigns | `cursor`, `has_more`, `loading_more` moram **no island** |
| `load_more` | `phx-target={@myself}` — nunca sobe ao LiveView raiz |
| deltas | `{:reset, page}`, `{:append, page}`, `{:prepend, page}` |
| guarda | ignora `load_more` se `loading_more` ou `not has_more` |

Mudança em relação ao que existe: hoje o estado de paginação do chat mora no
**pai** (`ChatLive`) e o `load_more` sobe até `core_events.ex`. Justificável com
uma lista; com catorze, não. O pai continua dono do read-model materializado
onde outros subsistemas leem (AGENT-GUIDE §6.5) — o que desce é só a paginação.

**Teto do stream:** `limit` do stream = 3× o tamanho da página (recomendação da
documentação do LiveView para scroll virtualizado bidirecional).

### 2.3 JS — hook próprio, e por quê

**Decisão: hook próprio (`InfiniteScrollHook`), importando a semântica
`_overran` do LiveView.** Não usar `phx-viewport-*` nativo.

Investigado antes de decidir (LiveView 1.1.22 no projeto):

| Fator | Nativo | Consequência para nós |
|---|---|---|
| Requer `padding` de ~2× a altura do viewport | sim | inviável: nossas listas vivem em janelas win98 de **altura fixa**; `pb-[200vh]` dentro de um diálogo de 400px é absurdo |
| [Issue #3639](https://github.com/phoenixframework/phoenix_live_view/issues/3639) — último filho **oculto** zera o gatilho | aberta | nos atinge direto: o chat faz `hidden={@show_status_tab}`, a nicklist fica montada-porém-oculta, e todo diálogo tem empty state condicional |
| [Issue #3887](https://github.com/phoenixframework/phoenix_live_view/issues/3887) — refresh restaura scroll e a tela fica em branco | aberta | atinge qualquer lista longa após reconexão |
| Semântica `_overran` (usuário agarra a barra e volta ao topo de uma vez) | sim | **vale copiar** — precisa resetar para a primeira página |
| Preservação de posição no prepend | não documentada | já resolvida no nosso `ScrollHook` |

Contrato do hook, por `data-*`:

```
data-edge="top" | "bottom"     onde carregar mais
data-threshold="400"            px antes da borda (hoje: 10)
data-target                     phx-target do island
```

O `ScrollHook` fica só com o que é exclusivo do chat — pin de auto-scroll,
tooltips, hover card, long-press, context menu — e **compõe** o hook novo.
A preservação de posição no prepend (`prepend_start` + ajuste de `scrollHeight`)
migra para o hook novo: é genérica.

**Gotcha a preservar:** o hook exige `userScrollIntent` (wheel/touch/pointer/
tecla) antes de disparar `load_more`, para que um scroll programático não
pagine. O E2E já convive com isso — `pages/ChatPage.ts:879` dispara um
`WheelEvent` sintético **antes** de mexer no `scrollTop`. O contrato novo
mantém essa exigência e o helper continua válido.

### 2.4 Admin — de texto para dados

Único item que exige mudança de contrato **fora** das listas; por isso é
pré-requisito de cinco tasks.

Hoje os handlers de `/admin` retornam `{:ok, :system, %{content: texto_pronto}}`
e os dialogs renderizam a string. Não há linha, não há id, não há stream.

```elixir
{:ok, :table, %{columns: [...], page: %Page{}}}   # dialog renderiza stream
                    ↓ TextFormatter
{:ok, :system, %{content: texto}}                  # /admin no chat, inalterado
```

Ganho colateral: o contador do cabeçalho passa a vir de `page.total`. Hoje
`commands/handlers/admin/user.ex:31` imprime
`"*** User List (%{entries_count} results)"` com `length(entries)` sobre uma
lista capada em 100 — com 5000 nicks a tela **mente**, e
`count_registered_nicks/0` já existe no mesmo módulo, sem uso.

---

## 3. Receita de migração (por superfície)

**Passo 1 — chave de cursor.** Coluna estável e indexada. Confirmar o índice
antes de escrever a query; sem índice, keyset é pior que offset.

**Passo 2 — domínio (TDD).** Testes do `Page` primeiro, depois `list_x/2` com
`limit + 1`. Filtro de busca vai para o `WHERE`, nunca `Enum.filter`.

**Passo 3 — island (TDD).** Testes de estado primeiro. Adota `PaginatedList`.

**Passo 4 — markup.** Contêiner com `InfiniteScrollHook` + os estados visuais da
§4 (vazio / carregando / fim / erro / truncado).

**Passo 5 — E2E.** Spec Playwright que exercita o gesto real.

**Passo 6 — Help Topics.** Obrigatório quando a UX muda.

**Gate de completude:** `grep` pelo nome do stream, não o compilador — um
callsite de stream esquecido compila e falha em runtime (AGENT-GUIDE §6.5).

---

## 4. Componentes visuais e base

Resposta curta à pergunta "precisamos de componentes novos?": **sim, sete** — e
nenhum estava no plano anterior. Além disso há consolidação a fazer no que já
existe.

### 4.1 O que já existe

| Componente | Estado hoje | Destino |
|---|---|---|
| `shell/activity_indicator.ex` | em produção; `role="status"` + `aria-live="polite"` | **base** do estado "carregando mais" |
| `chat/scroll_loader.ex` | **só showcase**; duplica o de cima | absorver no padrão ou remover |
| `primitives/skeleton.ex` | **zero uso**; `@moduledoc false`, sem `@spec` | usar no first-load ou remover; regularizar `@spec` |
| `primitives/pagination.ex` | **só showcase** | virar a apresentação do "carregar mais" ou remover |
| `layout/scroll_area.ex` | só no emoji picker | avaliar como contêiner padrão de lista |
| `layout/table.ex` | em uso pelos diálogos | mantém; ganha variante paginada |
| 15 empty states bespoke | um por diálogo, CSS próprio | consolidar em `list_empty_state` |

### 4.2 O que precisa ser construído

- [ ] **4.1 — `list_empty_state`.** Ícone + título + texto opcional + ação
      opcional. Substitui as quinze variantes. Sem ele, cada superfície migrada
      inventa a décima sexta.
- [ ] **4.2 — `list_end_marker`.** "Fim da lista." Hoje **não existe**: quando a
      paginação acaba, o usuário não distingue fim de falha de carregamento.
- [ ] **4.3 — `list_load_more_button`.** Fallback acessível ao auto-load. A
      pesquisa de a11y é consistente: auto-load sozinho prejudica teclado e
      leitor de tela; o botão explícito é o padrão preferido e deve coexistir
      com o scroll automático.
- [ ] **4.4 — `list_count_strip`.** "Mostrando 100 de 5.000." Mata o contador
      mentiroso do Admin e torna qualquer truncamento **visível por contrato**.
- [ ] **4.5 — `list_error_retry`.** Falha ao carregar página + botão de tentar
      de novo. Hoje **toda** lista assume sucesso; uma falha de query é uma
      lista silenciosamente curta.
- [ ] **4.6 — Announcer `aria-live` de resultado.** O `activity_indicator`
      anuncia *que está carregando*; falta anunciar *o que chegou* ("20 itens
      carregados", "fim da lista"). `aria-live="polite"` + `aria-atomic="true"`.
- [ ] **4.7 — Skeleton rows no first-load.** Hoje o carregamento inicial é um
      spinner (`channel-loader`). Skeleton reduz o salto de layout. Usa o
      primitivo que existe e nunca foi usado.

Todos entram no `/showcase` (regra da casa) e no catálogo de ícones quando
precisarem de arte nova — SVG só via `RetroHexChatWeb.Icons`, nunca inline.

### 4.3 CSS

Estados novos ganham classes no `retrohex.css` seguindo a arquitetura atual
(sem cor hardcoded em Elixir/JS; `mix audit.styles --strict` precisa ficar em
0/0/0). O contêiner de lista padroniza a `retro-scrollbar` que hoje é aplicada
caso a caso.

---

## 5. Fases, com o que testar em cada uma

TDD em todas: teste primeiro, nas três camadas. E2E é a validação final e roda
local, com alvo único, após `MIX_ENV=e2e PGPORT=5433 mix assets.build`.

### Fase 0 — Fundação

- [ ] **0.1 — `RetroHexChat.Page` + regra do `limit + 1`.**
- [ ] **0.2 — `PaginatedList` island behaviour.**
- [ ] **0.3 — `InfiniteScrollHook`** (extraído do `ScrollHook`, com `_overran`).
- [ ] **0.4 — Componentes visuais 4.1–4.7** + entradas no `/showcase`.
- [ ] **0.5 — Destino de `pagination.ex`, `scroll_loader.ex`, `skeleton.ex`.**

**Testar — domínio (unit):**
- `has_more` na borda exata: exatamente `limit`, `limit + 1` e `limit - 1` linhas.
- **O teste que protege a regra central:** filtrar itens do `Page` depois
  **não** altera `has_more`.
- `next_cursor` é `nil` quando `has_more` é falso; é a última linha crua quando
  verdadeiro.
- `total` só é calculado quando pedido.

**Testar — island (LiveView):**
- `load_more` com `loading_more: true` é ignorado (sem consulta).
- `load_more` com `has_more: false` é ignorado.
- `{:append, page}` não reseta o stream; `{:reset, page}` reseta.
- Stream respeita o teto: com teto 3×, a página 5 não deixa 5 páginas no DOM.
- Asserções em estado **síncrono** (`:sys.get_state`), nunca em mensagem
  assíncrona de `send_update`, e sem `sleep`/retry de render.

**Testar — JS (unit, roda no `make ci`):**
- Threshold: dispara antes da borda, não só nela.
- Sem `userScrollIntent`, scroll programático **não** dispara `load_more`.
- `_overran` dispara reset em vez de próxima página.
- Preservação de posição: após prepend, `scrollTop` compensa o `scrollHeight`.

**Testar — componentes (LiveView):** cada estado da §4.2 renderiza com o
`data-testid` e os atributos ARIA corretos.

### Fase 1 — Trazer o chat para o contrato

- [ ] **1.1 — Mensagens de canal e PM sob `Page`.**
      Hoje: `has_more` calculado três vezes, uma sobre a lista filtrada
      (`helpers/channel.ex:284`), desligando o scroll infinito para quem usa
      `/ignore`. Alvo: `list_messages/2` e `list_private_messages/3` devolvem
      `Page`; os três call sites leem `page.has_more`; cursor vem da linha crua.
- [ ] **1.2 — Teto de DOM no stream de mensagens.**
      Hoje: `message_viewport.ex:91` sem `limit:`.
- [ ] **1.3 — Paginação desce para o island.**
      Hoje: `oldest_message_id`, `has_more`, `loaded_message_count`,
      `loading_more` no pai; `load_more` roteado por `core_events.ex:232`.
- [ ] **1.4 — Re-render de estilo sem refetch.**
      Hoje: `helpers/session.ex:61` re-consulta `loaded_message_count` linhas ao
      trocar contexto de apresentação — 2000 mensagens roladas = 2000 linhas
      re-buscadas ao mudar uma cor de nick. Provável efeito colateral de 1.3.
- [ ] **1.5 — Threshold do gatilho** (`chat.js:25`, hoje 10px).

**Testar — domínio:** canal cuja primeira página crua contém mensagem de nick
ignorado ainda devolve `has_more: true`. Idem para mensagem antes do
clear-cutoff. Este é **o** teste de regressão da fase.

**Testar — LiveView:** trocar `nick_color` re-estiliza as linhas sem emitir
consulta (asserção sobre chamadas ao domínio, não sobre render).

**Testar — E2E (`chat-infinite-scroll.spec.ts`, novo):**
- Semear mais de duas páginas, rolar ao topo, verificar que mensagens antigas
  entram **e** que a posição de leitura não salta.
- Repetir com um nick ignorado na primeira página — o cenário do bug.
- Fim do histórico mostra `list_end_marker`, não spinner infinito.
- Reaproveitar `ChatPage.scrollMessagesToTop()` (já dispara o `WheelEvent`
  sintético exigido pelo hook).
- `chat-autoscroll.spec.ts` precisa continuar verde: pin de rodapé e paginação
  disputam o mesmo scroll. Rodar os dois no mesmo alvo.

**Evidência visual:** `shot()` no próprio spec, nos estados que valem revisão de
fidelidade retro — topo da lista com `list_end_marker`, `list_load_more_button`,
e o skeleton do first-load. `make e2e.shots FILE=tests/chat-infinite-scroll.spec.ts`.

### Fase 2 — Superfícies que carregam tudo

- [ ] **2.1 — Channel List (`/list`).** *Desvio: exige fonte de dados nova.*
      Hoje: `commands/autocomplete.ex:382` varre o Registry inteiro e faz um
      `Server.get_state` — **GenServer.call síncrono** — por canal, sem limit; o
      filtro é `Enum.filter` sobre a lista completa
      (`channel_list_dialog.ex:31`). Alvo: índice/snapshot consultável (ETS
      alimentado pelos canais) com `WHERE` e cursor. Paginar sobre N
      GenServer.calls não resolve — a fonte está errada.
- [ ] **2.2 — Nicklist.** *Desvio: ordenação por papel + presença, não por id.*
      Hoje: `helpers/channel.ex:206` streama todos os membros; `reset` completo
      a cada troca de canal e a cada `rebuild_nick_color_fn`.
- [ ] **2.3 — URL Catcher.** *Desvio: a lista não existe no banco.*
      Hoje: `helpers/session.ex:101` faz `new_entries ++ entries` — acumula toda
      URL da sessão, no assign do processo, nunca podada. Vazamento por sessão.
      Alvo: decidir persistência ou teto explícito; só então paginar.
- [ ] **2.4 — Admin Console.** *Desvio: histórico efêmero.*
      Hoje: `admin_console_dialog.ex:46`, `results ++ ...`, sem teto, O(n²).
- [ ] **2.5 — Bots.** `bots/queries.ex:34` sem limit.
- [ ] **2.6 — Bot Form: 3 sub-listas.** `bots/queries.ex:90` e `:128` sem limit;
      `:138` com limit 50 sem cursor. As três re-consultadas **inteiras a cada
      mutação** — `bot_events.ex:41-43`, `:173`, `:207`, `:234`, `:285`, `:327`,
      `:396-397`.
- [ ] **2.7 — Trusted Terminals.** `trusted_devices.ex:220` e `:264` sem limit;
      `:306` com limit 20 sem cursor.
- [ ] **2.8 — Channel Central: 4 listas.** *Desvio: dois consumidores.*
      `services/queries.ex:205`, `:252`, `:284`, `:319`, todas sem limit.
      `list_access/1` alimenta **duas** superfícies em formatos diferentes — o
      Channel Central (lista) e `/cs access` (`cs.ex:162`,
      `admin/chan_serv.ex:23,61`, texto no chat). As duas migram no mesmo passo.
- [ ] **2.9 — Connect screen: nicks lembrados.** `trusted_devices.ex:70` sem
      limit (`connect_live.ex:36` → `connect_screen.ex:205`). Naturalmente
      pequeno, mas sem teto declarado: decidir teto **ou** paginação.

**Testar — domínio:** para cada query, o trio de borda do `Page` e o filtro
aplicado no `WHERE` (asserção de que o filtro reduz a consulta, não a lista).
Em 2.1, teste de que abrir a lista **não** faz N chamadas ao `Server`.

**Testar — LiveView:** em 2.2, mudança de cor não emite consulta. Em 2.6, mutar
um bot emite delta, não re-consulta das três listas. Em 2.3/2.4, o teto poda e o
processo não cresce (asserção sobre tamanho do assign).

**Testar — E2E:** um spec por superfície com janela — abrir, rolar, ver a
segunda página, ver o marcador de fim. Em 2.1, verificar que o filtro devolve
resultado que **não** estava na primeira página (prova de que a busca foi ao
banco, não à lista carregada). Especs de regressão a manter verdes:
`chat-channel-list*.spec.ts`, `chat-admin-*window*.spec.ts`,
`chat-address-book*.spec.ts`.

### Fase 3 — Admin: de texto para listas

**3.1 é pré-requisito de todo o resto desta fase.**

- [ ] **3.1 — Retorno estruturado dos handlers de `/admin`** (§2.4) + o
      `TextFormatter` que preserva o caminho de chat.
- [ ] **3.2 — Admin › Users.** `services/queries.ex:330`, limit 100 fixo, e o
      cabeçalho imprime `length(entries)`.
- [ ] **3.3 — Admin › Audit Log.** `admin/audit_logs.ex:44`, `last` sem cursor.
- [ ] **3.4 — Admin › Channels.** `handlers/admin/channel.ex:12`.
- [ ] **3.5 — Server Bans** (pane banlist). `admin/server_bans.ex:59` sem limit,
      texto em `handlers/admin/user.ex:152`.
- [ ] **3.6 — Admin › Server Settings.** `services/queries.ex:394` sem limit.

**Testar — domínio:** o `TextFormatter` produz **exatamente** o texto que os
handlers produzem hoje. Capturar a saída atual como fixture **antes** de
refatorar — é o que garante que `/admin` no chat não regride. Este é o teste
mais importante da fase.

**Testar — domínio (o contador):** com mais linhas do que o limite,
`page.total` traz o total real e `length(page.items)` traz a página. O teste que
prova que a tela parou de mentir.

**Testar — LiveView:** os quatro dialogs renderizam linhas com id, não string.

**Testar — E2E:** manter verdes os especs existentes de Admin
(`chat-admin-users*.spec.ts`, `chat-admin-audit-log.spec.ts`,
`chat-admin-channels*.spec.ts`) — eles hoje afirmam sobre **texto**; parte do
trabalho é migrá-los para asserções sobre linhas. Novo: paginar o audit log e
conferir `list_count_strip` com o total real.

### Fase 4 — Conversations e Status

- [ ] **4.1 — Conversations / PMs.** `chat/queries.ex:79`, limit 50 sem cursor;
      a sidebar não sinaliza truncamento.
- [ ] **4.2 — Status viewport.** `status_viewport.ex:21`, `limit: -500`,
      descarte silencioso e irrecuperável. É a única superfície onde "não
      paginar" pode ser a resposta certa — mas tem que ser decisão registrada.

**Testar:** domínio com mais de 50 parceiros de PM; LiveView com a sidebar
paginando; E2E abrindo a sidebar com muitas conversas e alcançando a 51ª.

### Fase 5 — Decisões pendentes (não bloqueiam)

- [ ] **5.1 — Lista de resultados de busca não existe.** `chat/search.ex:12`
      não tem **nenhum** caller fora do próprio módulo; a busca só conta
      (`search_bar.ex:274`) e destaca o DOM. Construir ou remover.
- [ ] **5.2 — `Bots.Queries.list_bots_by_creator/1` sem caller.**
- [ ] **5.3 — `Admin.GlobalMutes.list_mutes/0` sem caller.** **Não existe UI de
      mutes globais**, apesar de o mute global existir como ação.

---

## 6. Estratégia de teste

**Unit (domínio).** Onde mora o contrato. Todo `Page` novo entra aqui primeiro.
Roda em `make ci`.

**LiveView.** Estado síncrono (`:sys.get_state(view.pid).socket.assigns` ou o
estado do island), nunca a mensagem assíncrona de `send_update`; sem `sleep` nem
retry de render — padrão já estabelecido nesta suíte.

**JS unit.** O hook é lógica de borda com aritmética de scroll: testável fora do
browser e roda em `make ci`.

**E2E Playwright.** Validação final. Não faz parte de `make ci` (o worker
"feature tests" é `mix test --only liveview_feature`). Suíte atual: 195 specs,
368 casos, serial, um worker, POM em `pages/`.

```bash
MIX_ENV=e2e PGPORT=5433 mix assets.build       # pular = CSS/JS velho servido
cd e2e && npx playwright test tests/<arquivo>.spec.ts
```

Alvo único, nunca a suíte inteira. Depois de mexer em Elixir, matar a :4003.

**Screenshots.** Ferramenta já construída (2026-07-28): `shot()` em
`e2e/helpers/screenshots.ts`, inerte a menos que `E2E_SHOTS` esteja setada, com
`make e2e.shots FILE=...`. As evidências visuais deste refactor entram **dentro**
dos specs reais, nos estados que valem revisão — nunca em spec descartável. Ver
`e2e/README.md` § Visual evidence.

**`TEST_CATALOG.md`** é a fonte única da suíte E2E e precisa ser atualizado a
cada spec novo.

---

## 7. Ordem e dependências

```
0.1 Page ──┬─→ Fase 1 (chat valida o contrato numa lista real e quente)
0.2 island ┤
0.3 hook  ─┤
0.4 visual ┘   └─→ Fase 2 · 2.5–2.9 em paralelo
               └─→ 3.1 ─→ 3.2 … 3.6
               └─→ Fase 4

2.1 Channel List  → fonte de dados nova (maior escopo isolado)
2.3 URL Catcher   → decisão de persistência
2.4 Admin Console → decisão de persistência
```

1. **Fase 0** — fundação, incluindo os componentes visuais. Sem 0.4, a primeira
   superfície migrada inventa a décima sexta variante de empty state.
2. **Fase 1** — o chat valida o contrato. Se a fundação estiver errada, aparece
   aqui, com uma superfície e não catorze.
3. **2.3 e 2.4** — crescimento não-limitado de memória; risco operacional,
   escopo pequeno.
4. **3.1** — destrava cinco tasks.
5. **2.1** — maior ganho de servidor, maior escopo; depois da receita rodada.
6. Resto da Fase 2, Fase 3, Fase 4, Fase 5.

**Unidade de trabalho:** uma superfície por commit — domínio, island, markup,
testes e remoção do caminho antigo juntos. Nunca deixar caminho antigo e novo
coexistindo entre commits.

---

## 8. Regras que o refactor institui

- Cursor keyset, nunca offset.
- `has_more` sempre do `limit + 1` no banco, nunca de `length` de lista filtrada.
- Cursor da última linha **crua**, não da última visível.
- Todo stream de lista longa com `limit:` negativo (3× a página).
- Filtro/busca no `WHERE`, nunca `Enum.filter` sobre a lista inteira.
- Nenhum contador exibido pode vir de lista truncada — vem de `page.total`.
- Toda lista tem os cinco estados: vazio, carregando, fim, erro, truncado.
- Auto-load sempre acompanhado de fallback acessível por teclado.
- Lista sem teto de domínio pagina; lista com teto documenta o teto.
- LiveViews finas, domínio no app de domínio, SVG via `Icons`, sem cor
  hardcoded, Help Topics atualizado. TDD. `make ci` é o gate.

---

## 9. Inventário — cobertura da auditoria

Varredura pelos 43 schemas Ecto e por todos os `Repo.all` do domínio.

| Schema / fonte | Superfície | Task |
|---|---|---|
| `Chat.Message` | Viewport do canal | 1.1–1.5 |
| `Chat.PrivateMessage` | Viewport de PM | 1.1–1.5 |
| `Chat.PrivateMessage` (partners) | Sidebar Conversations | 4.1 |
| Registry + GenServer | Channel List `/list` | 2.1 |
| Presence | Nicklist | 2.2 |
| assign em memória | URL Catcher | 2.3 |
| assign em memória | Admin Console | 2.4 |
| assign em memória | Status viewport | 4.2 |
| `Bots.Bot` | Bot Management | 2.5 |
| `Bots.BotChannelConfig` | Bot Form › Channels | 2.6 |
| `Bots.BotCustomCommand` | Bot Form › Commands | 2.6 |
| `Bots.BotEventLog` | Bot Form › Events | 2.6 |
| `Accounts.TrustedDevice` | Trusted Terminals | 2.7 |
| `Accounts.ChatDeviceSession` | Trusted Terminals | 2.7 |
| `Accounts.TrustedDeviceEvent` | Trusted Terminals | 2.7 |
| `Services.AccessListEntry` | Channel Central + `/cs access` | 2.8 |
| `Services.Ban` | Channel Central | 2.8 |
| `Services.BanException` | Channel Central | 2.8 |
| `Services.InviteException` | Channel Central | 2.8 |
| `Accounts.TrustedDeviceNick` | Connect screen | 2.9 |
| `Services.RegisteredNick` | Admin › Users | 3.2 |
| `Admin.AuditLog` | Admin › Audit Log | 3.3 |
| `Services.RegisteredChannel` | Admin › Channels | 3.4 |
| `Admin.ServerBan` | Admin › Users (banlist) | 3.5 |
| `Services.ServerSetting` | Admin › Server Settings | 3.6 |
| `Chat.Message` (search) | **sem superfície** | 5.1 |
| `Bots.Bot` (by creator) | **sem superfície** | 5.2 |
| mutes globais | **sem superfície** | 5.3 |

### Verificado e fora do contrato

- **Listas de configuração com teto de domínio** (tabela abaixo):
  `ContactEntry`, `HighlightWordEntry`, `NickColorEntry`, `IgnoreListEntry`,
  `AliasEntry`, `PerformListEntry`, `AutojoinListEntry`, `AutoRespondRule`,
  `CustomMenuItem`, `NotifyListEntry`.
- **Registros únicos** (formulário, não lista): `UserBio`, `UserPreference`,
  `SoundSetting`, `FloodProtectionSetting`, `NoticeRoutingSetting`,
  `PerformSettings`, `NotifyListSettings`, `ChannelWelcomeMessage`,
  `Admin.AdminRole`.
- **Só rotina de limpeza**, nunca renderizado: `Arcade.SoloSession`
  (`arcade/queries.ex:59`), `Lobby.Session` (`lobby/queries.ex:69`),
  `GroupCall.Room` (`group_call/queries.ex:57`), `RegisteredChannel` via
  `list_channels_for_founder` (`services/queries.ex:138`, só `nick_expiry.ex:81`).
- **Sessões P2P**: `lobby/queries.ex:47,59` nunca viram lista — `List.first/1`
  ou iteração para encerrar.
- **Conferência**: `GroupCall.Participant` e `GroupCall.Track`
  (`group_call/queries.ex:96,104,152,160`), teto de 100 da sala.
- **Presença global**: `Tracker.list_users("presence:global")` devolve todos os
  online mas **nunca é renderizado** — só contagem (`admin/server.ex:17`) e
  checagem de pertencimento. Se virar tela "quem está online", entra no contrato.
- **Whowas**: ETS capado em 1000; `lookup/1` devolve **uma** entrada por nick.

### Tetos de domínio (documentados, não paginam)

| Lista | Teto | Onde |
|---|---|---|
| Ignore list | 100 | `chat/ignore_list.ex:15` |
| Contacts / Address book | 100 | `accounts/contact_list.ex:16` |
| Alias list | 50 | `chat/alias_list.ex:17` |
| Perform list | 50 | `chat/perform_list.ex:16` |
| Highlight words | 50 | `chat/highlight_words.ex:15` |
| Nick colors | 50 | `accounts/nick_colors.ex:15` |
| Notify list | 50 | `presence/notify_list.ex:18` |
| Autojoin list | 20 | `chat/autojoin_list.ex:15` |
| Autocomplete | 20 resultados | `commands/autocomplete.ex:63` |
| Auto-respond rules | 10 | `chat/auto_respond_rules.ex:16` |
| Custom menus | 10 por tipo | `chat/custom_menus.ex:13` |
| Timers | 5 | `chat/timer_manager.ex:8` |
| Group call | 100 participantes | `group_call/config.ex:21` |

Estáticas (catálogo em código): emoji picker, cheatsheet, help topics, catálogo
de jogos, seletor de locales, seletor de avatares, dispositivos de mídia.

---

## Placar

| Fase | Tasks | O que é |
|---|---|---|
| 0 | 5 (+7 componentes) | fundação: contrato, island, hook, visual |
| 1 | 5 | chat migrado para o contrato |
| 2 | 9 | superfícies que carregam tudo |
| 3 | 6 | Admin: de texto para listas |
| 4 | 2 | Conversations e Status |
| 5 | 3 | decisões pendentes |
| **Total** | **30 + 7** | |

## Referências consultadas

- [LiveView bindings — `phx-viewport-top`/`bottom`, `_overran`, stream limit](https://phoenix-live-view.hexdocs.pm/bindings.html)
- [Issue #3639 — último filho oculto zera `phx-viewport-bottom`](https://github.com/phoenixframework/phoenix_live_view/issues/3639)
- [Issue #3887 — refresh + scroll restaurado deixa a tela em branco](https://github.com/phoenixframework/phoenix_live_view/issues/3887)
- [Load More Pattern — UX Patterns for Developers](https://uxpatterns.dev/patterns/navigation/load-more)
- [Infinite Scroll Pattern — UX Patterns for Developers](https://uxpatterns.dev/patterns/navigation/infinite-scroll)
- [Infinite scroll accessibility and usability — Human-centred](https://human-centred.nz/2020/04/22/infinite-scroll-and-accessibility/)
