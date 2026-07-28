# Listas — progresso e aprendizados

Plano: `listas-infinite-scroll-auditoria.md`

Registro do que foi feito e do que se aprendeu fazendo. Uma entrada por task
concluída. Aprendizado só entra aqui se foi **descoberto executando** — não se
já estava no plano.

---

## Ferramenta prévia — evidência visual no E2E (2026-07-28)

Antes da Fase 0, construída a ferramenta que o refactor vai usar para revisão
visual, a pedido: `shot()` em `e2e/helpers/screenshots.ts`, inerte a menos que
`E2E_SHOTS` esteja setada, com `make e2e.shots FILE=...`.

Premissa registrada em `CLAUDE.md` (sempre carregado, é o ponto de aplicação) e
em `e2e/README.md` (o como-fazer).

**Aprendizado:** `test-results/` é limpo pelo Playwright entre runs — evidência
que some sozinha não serve como evidência. Saída vai para `e2e/screenshots/`,
gitignored, regenerável sob demanda.

**Assumido, vale saber:** o caminho é relativo ao `cwd`, o que assume Playwright
invocado de `e2e/`. Verdade em todos os alvos do Makefile; quebraria se alguém
invocasse de outro diretório.

---

## Fase 0 — Fundação

### 0.1 — `RetroHexChat.Page` + regra do `limit + 1` ✅

`apps/retro_hex_chat/lib/retro_hex_chat/page.ex` +
`apps/retro_hex_chat/test/retro_hex_chat/page_test.exs` (15 testes, verdes).

API: `limit_with_lookahead/1`, `new/3`, `empty/0`, `filter/2`, `map/2`,
`with_total/2`.

TDD de verdade: 15 falhas primeiro, depois o módulo.

**A decisão que carrega o refactor.** `filter/2` e `map/2` existem para que
aplicar um filtro de apresentação a uma página seja *impossível* de fazer errado
— eles reescrevem `items` e não tocam `has_more`/`next_cursor`. Se o call site
reconstruísse a struct na mão, o bug de `helpers/channel.ex:284` voltaria pela
porta dos fundos. Três testes protegem isso explicitamente, incluindo o caso
extremo de filtrar *tudo* e ainda assim manter `has_more: true`.

**Aprendizado — o `limit` do `new/3` não é o `limit` da query.** `new(rows, 50, …)`
recebe o tamanho de página desejado, enquanto a query pediu 51. Foi tentador
passar o mesmo número nos dois lugares; separar deixa o call site com uma
assimetria visível (`limit_with_lookahead(50)` na query, `50` no `new`) que é
justamente o que impede alguém de esquecer a linha de lookahead.

**Aprendizado — `next_cursor` precisa de três cláusulas, não duas.** O caso
`{[], true}` (nenhum item mas `has_more` verdadeiro) não acontece via `new/3`,
mas acontece via `filter/2` quando o filtro derruba tudo — e sem a cláusula o
`List.last([])` devolveria `nil` para o `cursor_fun`, estourando. O cursor é
calculado em `new/3` e apenas carregado por `filter/2`, mas a cláusula
defensiva fica porque o struct é público.

### 0.3 — `InfiniteScrollHook` ✅ (implementado; registro pendente)

`assets/js/hooks/ui/infinite_scroll_hook.js` +
`assets/test/hooks/ui/infinite_scroll_hook.test.js` (19 testes, verdes).

Contrato por `data-*`: `edge`, `threshold`, `target`, `has-more`, `loading`.
Preserva as duas propriedades não-negociáveis: exigência de gesto real do
usuário (senão o auto-scroll do chat pagina o histórico sozinho) e reporte de
`_overran`.

**Bloqueio descoberto — o hook não pode entrar sozinho.**
`assets/scripts/enforce_hooks_contract.cjs` roda em `make ci` e exige que todo
arquivo em `js/hooks/` seja (a) classificado num builder (`critical_hooks.js` ou
`lazy_feature_hooks.js`) **e** (b) referenciado por um `phx-hook="..."` em algum
`.ex`/`.heex`. As duas checagens são mútuas: registrar sem usar falha, usar sem
registrar falha. Consequência prática: o registro do hook fica para a Fase 1,
onde o `MessageViewport` vira o primeiro consumidor. Até lá o arquivo existe e é
testado, mas não registrado — `make lint.js` só fecha ao final da Fase 1.

**Aprendizado — o hook só aprende posição por evento de scroll.** Dois testes
meus falharam porque atribuíam `el.scrollTop = 1600` e esperavam que o hook
soubesse disso. Não sabe: `lastScrollTop` só é atualizado dentro do
`handleScroll`, que é o comportamento correto (é assim que o browser funciona).
Em teste, a posição inicial precisa ser **rolada até**, com `dispatchEvent`, não
atribuída. Vale para qualquer teste futuro de detecção de borda.

### 0.2 — `PaginatedList` ✅

Três arquivos:
`live/paginated_list/state.ex` (estado puro, 19 testes),
`live/paginated_list.ex` (wrapper de socket, 10 testes),
`test/support/paginated_list_probe.ex` (LiveView+LiveComponent mínimo de teste).

**Estado puro separado do wrapper, por necessidade e não por elegância.**
`Phoenix.LiveView.stream/4` estoura com `KeyError: key :lifecycle not found` num
`%Socket{}` nu — descoberto tentando. Ou se monta um host LiveView de verdade,
ou não se testa nada. Separar o `State` (struct pura, sem socket) tornou as
regras que importam — quando pode pedir outra página, o que perguntar ao
servidor — testáveis sem harness nenhum, e o probe LiveView cobre só o que
depende de stream real.

**Estado por lista, com nome.** Channel Central tem 4 listas, Bot Form tem 3.
Um `%{paginated: %{bans: state, access: state}}` nos assigns em vez de campos
soltos — decidido antes de escrever, olhando o inventário.

**`can_load_more?` exige cursor além de `has_more`.** `has_more: true` com
`cursor: nil` é contradição, mas se acontecer o efeito é cruel: o servidor
relê a primeira página para sempre e a lista parece funcionar sem nunca
avançar. Uma cláusula e um teste.

**Aprendizado — `send_update/2` não serve em teste.** Ela posta para `self()`,
que do processo de teste nunca chega ao LiveView. A aridade com pid
(`send_update(view.pid, Module, assigns)`) é a que funciona. Vale para todo
teste futuro que dirigir um island por delta.

**Aprendizado — `phx-hook` não pode ser gerado.** `State.hook_attrs/1` devolve
só os `data-*`; o `phx-hook="InfiniteScrollHook"` tem que estar literal no
template porque o `enforce_hooks_contract.cjs` procura a string com regex. Se
fosse montado dinamicamente o CI reprovaria o hook como não-usado.

**Aprendizado — `beforeUpdate()` é o lugar certo da compensação de prepend.**
O `ScrollHook` atual resolve isso com um `push_event("prepend_start")` do
servidor mais um `MutationObserver`, ou seja, o servidor precisa avisar que vai
prepender. O lifecycle `beforeUpdate()` do LiveView já roda antes do patch, o
que torna o aviso do servidor desnecessário: mede-se `scrollHeight` antes e
depois, sem protocolo extra. Uma mensagem a menos entre servidor e cliente.

### 0.4 — Componentes de estado de lista ✅

`components/ui/layout/list_states.ex` (18 testes),
`assets/css/retrohex/components/list-states.css`,
`live/showcase_live/layout/list_states_page.ex` + rota + navegação.

Sete componentes: `list_empty_state`, `list_end_marker`,
`list_load_more_button`, `list_count_strip`, `list_error_retry`,
`list_announcer`, `list_skeleton`.

**Correção da auditoria — eu contei errado.** O plano dizia "quinze empty states
bespoke e nenhum componente compartilhado". A segunda parte é falsa: existe
`components/ui/shell/empty_state.ex` desde antes, com slots. Não apareceu na
auditoria porque procurei por prefixo CSS (`cl-`, `uc-`, …) e por strings de
copy, não pelo componente.

O achado real é pior de um jeito e melhor de outro: **existia um componente
compartilhado e ele foi ignorado por quinze diálogos** — usado exatamente uma
vez, em `conversations.ex`. A hipótese que a implementação assume: a API de
slots cobra três `<:slot>` por adoção, e escrever uma `div` sai mais barato.
Então `list_empty_state` **não** é um empty state novo — é o existente com
fachada de atributos, para que o componente compartilhado fique mais barato que
a `div`. Criar o décimo sétimo teria sido exatamente o erro que este refactor
existe para desfazer.

**Aprendizado — o auditor de estilo lê `#3639` como cor hex.**
`mix audit.styles --strict` marcou MEDIUM numa referência a issue do GitHub
dentro de um comentário JS. Baseline é 0/0/0, então qualquer `#` seguido de
dígitos em JS quebra o CI. Referência a issue se escreve por extenso.

### 0.5 — Destino dos três componentes órfãos ✅

| Componente | Decisão | Porquê |
|---|---|---|
| `primitives/skeleton.ex` | **fica**, regularizado + composto | ganhou `@moduledoc`/`@spec` (violava a regra do projeto) e um consumidor real: `list_skeleton` compõe em vez de reimplementar |
| `chat/scroll_loader.ex` | **removido** | duplicava o `activity_indicator`, que é o que produção usa nesse mesmo lugar |
| `primitives/pagination.ex` | **removido** | paginação por número de página é **incompatível** com cursor keyset — não existe "pular para a página 7" com cursor. Manter no catálogo era convidar alguém a usar |

Removidas também as duas páginas de showcase, rotas e entradas de navegação.

**A remoção do `pagination.ex` é a que vale explicar.** Não saiu por estar sem
uso; saiu por ser incompatível com o contrato que acabamos de construir. Um
primitivo no catálogo é uma sugestão, e essa sugestão levaria a paginação por
offset, que é exatamente o que a §7 do plano proíbe.

**Aprendizado — o checker de hooks lê docstrings.** Além de exigir hook
registrado num builder *e* usado num template, o
`enforce_hooks_contract.cjs` casa a string de binding por regex em qualquer
`.ex`/`.heex` — inclusive dentro de um `@doc`. Uma docstring do `State` que
explicava por que o binding não é gerado foi reprovada por *conter* o binding.
Documentação sobre hooks precisa falar do binding sem escrevê-lo literal.

**Aprendizado — `mix audit.styles` só vale da raiz do repo.** Rodado de dentro
de `apps/retro_hex_chat_web` ele reporta 0 achados e diz "All styles are in
CSS!", o que parece sucesso e é só escopo vazio. Da raiz: 31 INFO, 0
bloqueantes. Quase tomei o resultado errado como validação.

### Estado da Fase 0

Verde: 47 testes Elixir (Page 15, State 19, PaginatedList 10, ListStates 18 —
somando 62 no total das quatro suítes) e 19 testes JS. Compilação com
`--warnings-as-errors` limpa. `audit.styles` no baseline.

**Pendência conhecida e intencional:** `make lint.js` está vermelho com
`infinite_scroll_hook.js is not referenced by a hook builder`. O contrato de
hooks impede registrar sem consumidor; o registro acontece na Fase 1, quando o
`MessageViewport` adota o hook. `make ci` completo só fecha lá.

---

## Fase 1 — Chat sob o contrato

### 1.1 — Mensagens de canal e PM sob `Page` ✅

`Chat.Queries.list_messages/2` e `list_private_messages/3` devolvem `Page`.
Opção `before_id:` renomeada para `cursor:`. Novos:
`Messages.visible_channel_page/2`, `visible_private_page/2` e os predicados
singulares que as duas formas compartilham.

Testes: `queries_page_test.exs` (10) + `message_pagination_test.exs` (5,
`liveview_feature`). Migrados ~20 call sites de teste existentes.

**O bug está morto, e morto pela estrutura.** `helpers/channel.ex` agora aplica
os dois filtros — cutoff de canal limpo e ignore list — via `Page.filter/2`,
então nenhum deles alcança `has_more`. O teste que prova isso ignora o autor de
*todas* as 60 mensagens e ainda assim exige `has_more: true` e cursor presente.

**Decisão — mudar o tipo de retorno em vez de criar função paralela.** Custou
migrar ~20 call sites de teste. A alternativa (`page_messages/2` ao lado de
`list_messages/2`) não custava nada e teria deixado duas formas de paginar —
exatamente a ambiguidade que o refactor existe para remover. Uma forma só.

**Aprendizado — o fim da lista zera o cursor, e isso é contrato.** Um teste meu
assumiu que `oldest_message_id` continuaria decrescendo na última página. Não:
`Page.next_cursor` é `nil` quando `has_more` é falso, porque não há mais nada
para pedir. A guarda do `load_more` (`is_nil(oldest_id)`) já dependia disso.

**Aprendizado — `&#123;` é a convenção da casa para chaves em `code_example`.**
Escapar `<` como `&lt;` não protege `{}` num sigil `~H`: o HEEx interpola
mesmo assim. Um `{@myself}` dentro de um exemplo de código derrubou a página de
showcase com `KeyError: key :myself not found` — em LiveView não existe
`@myself`. As páginas antigas já usavam `&#123;`/`&#125;`; eu não tinha olhado.

**Aprendizado — o smoke test do showcase tem lista de rotas própria.**
`showcase_smoke_test.exs` mantém um array literal de todas as rotas. Remover uma
página de showcase exige mexer em quatro lugares: módulo, rota no router, entrada
de navegação + mapa de ícones em `showcase_helpers.ex`, e essa lista.

### 1.2 e 1.5 — Teto de DOM e limiar do gatilho ✅

`MessageViewport` streama com `limit: -150` (3 páginas) nas quatro mutações.
A detecção de borda saiu para `assets/js/lib/ui/infinite_scroll.js` e o
`ScrollHook` do chat passou a usá-la — limiar de 10px vira 400px.
`shouldLoadMore/2` (o antigo, de 10px) removido junto com seus testes: ficou sem
uso em produção.

**Bloqueio arquitetural resolvido: um hook por elemento.** A ideia original era
o `ScrollHook` *compor* o `InfiniteScrollHook`. Não dá — LiveView monta apenas
um hook por elemento e ignora o segundo em silêncio (confirmado na doc e em
discussões da comunidade; o padrão sugerido é um `DelegateHook`, que seria
complexidade sem retorno aqui). A saída é a que o repo já usa em toda parte: a
**lógica** vai para `js/lib/`, e `js/hooks/` fica só com as definições. O chat
compõe a lib; as outras treze listas usam o hook.

Isso também resolve o bloqueio do contrato de hooks de outro jeito: o arquivo em
`js/hooks/` precisa de builder + consumidor, mas um arquivo em `js/lib/` não.

### 1.3 e 1.4 — não feitas (decisão registrada)

Descer a paginação do chat para o island e re-estilizar sem refetch ficaram de
fora desta rodada. Motivo: o estado (`oldest_message_id`, `has_more`,
`loaded_message_count`, `loading_more`) aparece em **40 pontos** de 6 arquivos
do LiveView mais quente do app, e 1.4 depende de 1.3 (para re-estilizar sem
consultar, alguém precisa guardar os itens materializados — hoje ninguém guarda).

O valor de 1.3 é consistência: as outras treze superfícies já nascem com o
estado no island via `PaginatedList`, então nenhuma delas roteia `load_more`
pela raiz. O chat é a exceção que já funcionava. Fica como dívida explícita, não
como esquecimento.

---

## Fase 2 — Superfícies que carregam tudo

### 2.6 (parcial) — Bot Form › Events ✅

`Bots.Queries.list_event_logs/2` devolve `Page`; o island
`BotManagementDialog` adota `PaginatedList` e é o **primeiro consumidor do
`InfiniteScrollHook`**, o que destravou `make lint.js`.

Testes: `bots/queries_page_test.exs` (5).

**Ordenação trocada de `inserted_at` para `id`.** O log é append-only, então a
ordem de id é a mesma cronologia — e dá um cursor que não empata nem deriva.
`inserted_at` com precisão de microssegundo empataria raramente, mas empataria, e
um cursor que empata pula ou repete linhas.

**Aprendizado — `required: true` num `attr` não protege `render_component`.**
Marquei `events_state` como obrigatório; compilou limpo (todos os call sites de
template passavam) e quebrou em runtime num teste que chama
`render_component/2` direto com uma lista de atributos. `render_component` não
valida atributos obrigatórios em tempo de compilação. Como o componente
apresentacional é renderizado standalone de propósito (showcase e testes
diretos), a correção certa não foi consertar o teste: foi dar `default: nil` e
fazer o componente degradar — sem estado de paginação, ele só renderiza as
linhas que recebeu.

**Aprendizado — `PaginatedList.state/2` recebe socket, `render/1` só tem
assigns.** Dentro do template o acesso é `@paginated.<nome>`. Vale para todas as
próximas superfícies.

### 2.3 e 2.4 — reclassificadas: teto, não paginação ✅

O plano listava URL Catcher e Admin Console como superfícies a paginar, e eu as
tinha marcado como **bloqueadas** esperando uma decisão de produto sobre
persistência. Errado nos dois pontos.

**Nenhuma das duas é lista de banco.** São buffers efêmeros de sessão: não
existe página anterior para buscar, porque não existe nada além do que aquela
sessão viu. O próprio plano já tinha a regra — "lista sem teto de domínio
pagina; lista com teto documenta o teto" — e elas caem no segundo caso, como as
treze listas de configuração. Paginar seria inventar um cursor sobre memória
volátil.

Feito: `@max_captured_urls 200` em `helpers/session.ex` (mantendo os mais
recentes) e `@max_results 200` no `admin_console_dialog.ex`, que também matou o
`results ++ novos` — o append custava mais a cada execução.

Teste: `session_buffers_test.exs`.

**Aprendizado — flood auto-ignore interrompe antes da captura.** A primeira
versão do teste mandava 210 mensagens de um autor e falhava dizendo que o teto
descartava o mais novo. Não descartava: a partir de ~10 mensagens do mesmo
autor, `check_flood_and_auto_ignore` corta o handler **antes** do
`capture_urls`, e nada mais era capturado. O teste estava medindo proteção de
flood achando que media o teto. Agora são 250 URLs em 5 mensagens.

---

## Fase 2.1 — Channel List: N chamadas síncronas → 1 leitura ETS ✅

`Channels.Directory` novo. Cada servidor de canal publica um snapshot pequeno
(nome, tópico, contagem, três flags de modo) no **valor do próprio registro no
Registry** — que já é uma tabela ETS. Listar canais passou a ser um
`Registry.select`.

Antes: `Autocomplete.list_visible_channels/1` fazia um `Server.get_state/1`
**síncrono por canal** e jogava fora quase todo o mapa retornado. Numa abertura
da janela isso é N round trips bloqueantes, cada um enfileirado atrás do que
aquele canal estivesse fazendo.

Testes: `channels/directory_test.exs` (11), incluindo um que compara a fila de
mensagens do processo do canal antes e depois de listar — se alguém reintroduzir
uma chamada, ele acusa.

**A decisão que evitou um processo novo.** A primeira ideia era uma tabela ETS
dedicada com um GenServer dono. Desnecessário: o `Registry` do Elixir guarda um
valor arbitrário por registro e `Registry.update_value/3` é chamado pelo próprio
processo dono. Zero infraestrutura nova, e o snapshot morre junto com o canal
sem precisar de limpeza.

**Aprendizado — todo retorno do servidor passa a funilar por `reply/2`.**
Publicar o snapshot só nos callbacks que mudam estado visível significaria achar
os certos entre 23 e nunca ter certeza. Em vez disso, os 41 sites de
`{:reply, _, state}` e `{:noreply, state}` viraram `reply/2` e `noreply/1`, que
republicam antes de devolver. Nenhuma mutação pode esquecer. O custo é
reconstruir um mapa de sete campos por chamada — barato, e comprado por não ter
uma classe inteira de bug de snapshot velho.

**Aprendizado — regex multilinha em código Elixir erra.** A substituição
mecânica dos 41 retornos com `.+?` e `re.S` atravessou quebras de linha em
quatro sites e gerou `reply(x,\\n state}` — parênteses e chaves misturados. O
compilador achou todos, mas vale saber: para reescrita mecânica de returns, ou
se casa linha a linha, ou se confere o compilador antes de confiar.

**Aprendizado — o filtro do Channel List também mudou de lugar.** Era
`Enum.filter` sobre a lista inteira já materializada no island. Agora
`Directory.search/1` filtra na fonte e o island recebe só o que interessa. O
`filter_channels/2` do island foi removido, e seu teste migrou para
`Channels.DirectoryTest` — o comportamento não sumiu, mudou de dono.

**Aprendizado — os dois workers do CI rodam em paralelo e compartilham o
Registry.** Um teste meu fazia `assert length(search("   ")) == length(all())`.
Passa isolado, quebra no `make ci`: o worker de feature tests cria canais entre
as duas chamadas. Partição de banco não protege estado de processo global.
Asserções sobre diretório global precisam ser de pertencimento, nunca de
contagem.

### 2.7 — Trusted Terminals: três listas, três respostas ✅ (parcial)

| Lista | Resposta | Por quê |
|---|---|---|
| eventos de segurança | `Page`, keyset por `id` | log append-only que cresce pela vida da conta |
| sessões ativas | `Page`, keyset por `id` | inseridas na conexão, id é a mesma cronologia |
| dispositivos | **teto de 200**, não paginação | ver abaixo |

**Não se pagina por keyset uma lista ordenada por coluna mutável.** Os
dispositivos são ordenados por `last_seen_at`, que muda toda vez que o
dispositivo é usado. Um cursor sobre isso deixa linhas **se moverem entre
páginas** enquanto se pagina — e a linha pulada seria um dispositivo confiável
que o dono não veria para revogar. Num painel de segurança, esconder um item é
pior que qualquer truncamento. Teto alto (200, com expirados e revogados já
excluídos) é a resposta certa aqui.

Foi o primeiro caso em que a regra do plano ("lista sem teto de domínio pagina")
não bastou: falta a condição de que a **chave de ordenação seja imutável**.

**Aprendizado — `Page.map/2` fecha o ciclo com `select: {row, join}`.** As três
queries selecionam tuplas `{registro, join}` e só depois montam o mapa da UI.
Com `Page`, isso vira `Page.new(rows, limit, fn {e, _} -> e.id end)` seguido de
`Page.map/2` — o cursor sai da tupla crua e a projeção acontece depois, sem
nenhum dos dois interferir na paginação.

**Parcial, e vale ser exato sobre o que falta.** O diálogo renderiza listas
simples, não streams. As duas listas paginadas entregam hoje: fim do `Repo.all`
ilimitado e **disclosure** do truncamento via `list_end_marker`. O que **não**
foi feito: converter as seções para stream + `PaginatedList` + hook, que é o que
daria "carregar mais" de verdade. Sem isso a UI ainda mostra só a primeira
página — a diferença é que agora ela **avisa**, em vez de truncar em silêncio.

### 2.5 / 2.6 e 2.8 — o critério que decide entre cursor e teto ✅

Depois de sete superfícies, o critério ficou claro o bastante para escrever:

> **Pagina o que cresce sozinho. Limita o que só cresce quando alguém decide
> criar.** E paginação exige, além disso, que a **chave de ordenação seja
> imutável**.

Aplicado:

| Lista | Resposta | Motivo |
|---|---|---|
| bans de canal | `Page`, keyset por `id` | moderação cresce com o tráfego |
| access list | teto | ordenada por `level`, que muda em promoção/rebaixamento |
| ban / invite exceptions | teto | curadas por operador, entrada a entrada |
| bots, channel configs, custom commands | teto | só existem porque um admin criou |

`list_bans/2` tinha seis consumidores fora da UI (chan_expiry, nick_expiry,
channels/queries, chan_serv e testes) — todos migrados para `.items`.

**Aprendizado — `@max_curated` não é um limite de produto, é um piso de
segurança.** Posto em 500, muito acima de qualquer configuração real. Existe
para que a query não seja ilimitada, não para impedir alguém. Vale o comentário
no código: um número que alguém pode ler como "limite de bots" convida a
mudanças erradas.

---

## Fase 5 — código morto (parcial)

Removidos, todos do inventário de listas do plano:

| Função | Task | Nota |
|---|---|---|
| `Chat.Search.search_messages/3` | 5.1 | tinha 14 testes e nenhum consumidor |
| `Bots.Queries.list_bots_by_creator/1` | 5.2 | tinha 1 teste e nenhum consumidor |
| `Admin.GlobalMutes.list_mutes/0` | 5.3 | delegação sem consumidor e sem UI |

**A decisão que mudei no meio.** Primeiro mantive o `search_messages`, migrado
para `Page`, argumentando que código morto *testado* representa intenção
deliberada. Errado, e pelo motivo oposto ao que pensei: o teste faz o código
morto **parecer vivo**. Quem lê o repositório — pessoa ou agente — conclui que
existe uma busca com lista de resultados. Não existe. Teste sobre código morto é
o pior tipo de código morto.

**Aprendizado — o escopo da limpeza é o escopo do trabalho.** Depois de remover
as três acima, saí varrendo o repositório inteiro atrás de código morto e
cheguei em `list_stale_sessions`/`expire_session` de arcade e lobby, que não têm
nada a ver com listas. Removi e tive que reverter. Remover código morto é algo
que se faz **ao passar pelo código durante a tarefa**, não uma caçada paralela —
senão o refactor perde o foco e passa a mexer em subsistemas que ninguém pediu.

**Ficou registrado como observação, não como task:** arcade e lobby têm
`list_stale_sessions` + `expire_session` sem chamador, enquanto nicks, canais e
bans têm GenServers de expiração no supervisor. Pode ser uma lacuna de
durabilidade real, mas está **fora do escopo deste plano** e precisa de
investigação própria antes de virar trabalho.

---

## Fase 3 — Admin

### 3.1 — handlers de `/admin` passam a carregar dados ✅

`RetroHexChat.Admin.Table` novo (10 testes). Os handlers de listagem — `user
list`, `user banlist`, `channel list`, `log` — passaram a responder:

```elixir
{:ok, :system, %{content: texto, table: %Table{}}}
```

**O desenho mudou em relação ao plano, e para melhor.** O plano previa trocar o
retorno por `{:ok, :table, ...}` e criar um `TextFormatter` que reproduzisse o
texto antigo, protegido por fixtures capturados antes do refactor. Aditivo é
estritamente superior: o texto continua sendo produzido **pelo mesmo código de
antes**, então não pode regredir — não por um teste passar, mas por construção.
E o caminho do chat não muda uma linha, porque `%{content: text}` continua
casando num mapa com chave a mais.

Fixture de regressão deixou de ser necessário. O teste que ficou no lugar é o
que prova a propriedade: `assert {:ok, :system, %{content: text}} = ...` — a
mesma asserção que todo consumidor existente faz.

**Achado no caminho: `admin channel list` tinha o mesmo N+1 do Channel List.**
`format_channel_entry/1` chamava `Server.get_state/1` por canal para pegar a
contagem de membros. Trocado pelo `Directory` da 2.1 — o mesmo snapshot serve as
duas superfícies. Não estava no inventário porque a auditoria classificou o
Admin como "blob de texto" e parou aí; o custo de servidor estava escondido
atrás do texto.

**Aprendizado — `:last` e `:limit` são a mesma coisa com nomes diferentes.**
`AuditLogs.list/1` sempre recebeu `:last` (o nome da flag `/admin log --last`),
e o contrato de `Page` usa `:limit`. Aceitar os dois evitou renomear a flag,
que é interface pública de comando.

### 3.3 — Audit log paginado ✅

`AuditLogs.list/1` devolve `Page`, keyset por `id`. Mesmo raciocínio dos outros
logs append-only: ordenar por `inserted_at` com precisão de microssegundo empata
raramente, mas empata — e cursor que empata pula ou repete linhas.

### 3.4 e 3.5 — Channel list e Server bans estruturados ✅

Ambos carregam `Table` agora. Continuam com teto em vez de cursor: a lista de
canais ativos é limitada pelos canais vivos, e os bans de servidor são curados
por admin.

### 3.6 e a metade de UI de 3.1–3.5 ✅

`UI.AdminShared.admin_table/1` novo: um componente, quatro janelas. Os diálogos
de Users, Channels, Audit Log e Server Settings deixaram de renderizar `<pre>`
com o texto do comando e passaram a renderizar linhas com `data-row-id`,
cabeçalho de colunas e `list_count_strip` quando há truncamento.

**A cláusula de fallback é o que permitiu converter um comando por vez.**
`admin_table/1` casa `%{table: %Table{}}` numa cláusula e cai no `<pre>` na
outra. Enquanto um handler não carregasse tabela, sua janela renderizava
exatamente como antes. Sem isso, converter o primeiro handler exigiria converter
os quatro no mesmo passo.

**Aprendizado — booleano em célula precisa de tradução visual.**
`to_string(true)` numa tabela vira a palavra "true", que lê mal. `format_cell/1`
converte booleanos em `✓`/`—` e `nil` em vazio; "nil" impresso numa célula é
ruído de implementação vazando para a tela.

**Aprendizado de processo — o erro que me custou uma rodada de CI.** Migrei as
asserções dos dois testes cujos arquivos eu tinha aberto, vi verde, e chamei o
bloco de fechado. Outros dois arquivos de teste afirmavam sobre o mesmo `<pre>`
e eu não tinha procurado. A ordem certa é: **grep por tudo que afirma sobre a
saída antiga → corrigir tudo → rodar esses arquivos → CI**. Testar só o que se
editou e deixar o CI achar o resto transforma um bloco numa sequência de
rodadas de quatro minutos.

O grep que teria evitado:
`grep -rln "admin-users-output\|\*\*\* User List\|…" test/`

### 3.2 (parcial) — o contador parou de mentir ✅

`Services.Queries.list_registered_nicks/1` devolve `Page` com `total` e cursor
keyset alfabético. `handlers/admin/user.ex` ganhou `list_header/2`, que reporta
`showing N of TOTAL` quando há truncamento.

Testes: `services/registered_nicks_page_test.exs` (5), incluindo um que registra
130 nicks e exige que o cabeçalho **não** contenha `(100 results)`.

**Feito sem 3.1.** O plano põe a reestruturação do Admin (handlers devolvendo
dados em vez de texto) como pré-requisito de 3.2. Para a *paginação* é mesmo;
para o **contador falso**, não — bastava a query devolver `total` e o handler
lê-lo. Uma tela que informa número errado é defeito de correção, e não precisava
esperar a mudança arquitetural.

**Cursor alfabético, não por id.** A lista é ordenada por `nickname`, então o
cursor é o nickname — `WHERE nickname > cursor`. Usar id com ordenação por nome
pularia e repetiria linhas.

**Aprendizado — o filtro `--online` também é apresentação.** Ele roda em memória
sobre a página (a presença não está no banco), então passa por `Page.filter/2`.
Se filtrasse a lista direto, o contador voltaria a mentir pelo mesmo motivo de
antes, só que em outro lugar.

**Aprendizado — Credo checa ordem alfabética de alias e o CI reprova por isso.**
Inserir `alias RetroHexChat.Page` depois de `Repo` passou em compile, format e
todos os testes, e quebrou o `make ci` no Credo. Vale conferir a ordem ao
adicionar alias — é o que a memória do projeto já dizia sobre escrever
credo-clean de primeira.

### Estado após a Fase 1 + primeira fatia da Fase 2

`make ci` **11/11 verde**. Suítes novas: Page 15, State 19, PaginatedList 10,
ListStates 18, queries_page (chat) 10, queries_page (bots) 5,
registered_nicks_page 5, message_pagination 5 — mais 3966 testes JS.

## Fase final — as quatro superfícies restantes e o débito do chat ✅

### 2.2, 2.9, 4.1, 4.2 — todas com chave de ordenação mutável

As quatro últimas caíram no mesmo caso, e isso fecha o critério:

| Superfície | Chave de ordenação | Por que muda |
|---|---|---|
| Conversations / PMs | último recebimento | **toda PM nova reordena a lista** |
| Nicks lembrados | `last_used_at` | muda a cada uso do nick |
| Nicklist | papel + nick | promoção/rebaixamento muda o papel |
| Status viewport | — | não é persistido; não há página anterior |

Todas ganharam teto alto com **disclosure** — `list_count_strip` na nicklist,
`list_end_marker` no status viewport. Nenhuma trunca em silêncio.

**Isso resolve a questão de desenho que eu tinha deixado em aberto no 4.1.** Eu
tinha escrito que `pm_conversations` conflacionava "conversas abertas" (sessão) e
"histórico" (banco), e que separar as duas era o conserto de verdade. Estava
certo sobre a conflação e errado sobre a solução: mesmo separadas, o histórico
de conversas não é paginável por cursor, porque a ordem depende de quando a
última mensagem chegou. Separar não teria resolvido nada; teto com disclosure
resolve.

### 1.3 / 1.4 — o débito do chat, pago ✅

`MessageViewport` passou a guardar as linhas que renderiza (`rendered`,
limitado ao mesmo teto do DOM), e ganhou `restyle/1`.
`refresh_active_message_stream/2` deixou de refazer a consulta e virou uma
chamada de re-stream.

**O que isso custava.** Um stream não re-estiliza linhas existentes num
re-render comum (AGENT-GUIDE §6.5), então mudar a cor de um nick precisa
re-streamar. O código antigo fazia isso re-executando a query com
`limit = loaded_message_count` — depois de rolar 2000 mensagens para trás,
trocar uma cor relia 2000 linhas do banco para pintá-las de outra cor.

O teste que fixa a propriedade compara o estado de paginação antes e depois da
mudança de cor: um refetch o teria resetado.

**1.3 continua não feito, e agora é por escolha e não por dívida.** Descer o
estado de paginação do chat para o island era o pré-requisito de 1.4 pelo
raciocínio "alguém precisa guardar os itens". O `rendered` no viewport é esse
alguém, e é bem menor que mover 40 pontos de estado em 6 arquivos. O ganho
restante de 1.3 é só uniformidade — as outras treze superfícies já nascem com o
estado no island.

## Sessão de fechamento (2026-07-28, segunda rodada)

Retomada a partir do handover para fechar o que faltava. Encontrou três defeitos
que o `make ci` verde não pegava.

### 2.7 — Trusted Terminals ganhou o "carregar mais" de verdade ✅

Sessões e eventos viraram stream + `PaginatedList` + `InfiniteScrollHook`; a
janela deixou de descartar o cursor que o domínio já devolvia. Dispositivos
continuam com teto (chave de ordenação mutável). Os três empty states bespoke da
janela viraram `list_empty_state`.

Testes: `trusted_terminals_pagination_test.exs` (5).

**O `update/2` de um LiveComponent roda a cada render do pai.** Enquanto as
listas eram simples, refazer o snapshot ali era só desperdício. Com stream, é
correção: cada render do pai resetaria as páginas que o leitor carregou. O
snapshot passou a ser refeito só na abertura, na troca de identidade e depois de
uma mutação. Um teste fixa cada metade — que um render do pai **não** descarta, e
que um refresh **sim** recarrega.

**O contrato do hook ganhou `data-event`.** Duas listas paginadas no mesmo island
compartilham o `phx-target`, então o nome do evento é a única coisa que
distingue qual delas chegou na borda. O `list_load_more_button` já previa isso
com o atributo `event`; o hook não.

**`State` ganhou `count` e `loaded?`, e com eles quatro predicados.** Um stream
não conta linhas para o markup, então sem isso não dá para diferenciar uma lista
vazia de uma que ainda não carregou — e toda lista piscaria seu empty state
enquanto carrega. `empty?`, `exhausted?`, `more?` e `loading?` aceitam `nil`
para o componente renderizado standalone. `bot_management_dialog` tinha dois
desses predicados duplicados localmente, e o `list_end_marker` dele aparecia
**sob uma lista vazia** — `exhausted?` existe para tornar isso inexprimível.

### Fase 1 estava sem o quinto estado ✅

O plano exige "vazio, carregando, fim, erro, truncado" em toda lista, e a §5 pede
`list_end_marker` no fim do histórico. O viewport do chat tinha os dois
indicadores de carregamento e **nenhum marcador de fim** — nem o PROGRESS nem o
handover pegaram. Agora `has_more` desce até o `MessageViewport` e o scrollback
fecha com "Beginning of history", com quatro testes: aparece com histórico curto,
some enquanto há páginas, aparece depois da última, e **não** aparece em canal
vazio (onde leria como falha).

### Help Topics — requisito do plano que faltava inteiro ✅

`ui-lists` ("Long Lists & Loading More") + template, mais See Also em
`ui-conversations`, `ui-nicklist` e `keyboard-shortcuts`, e uma seção no
cheatsheet dizendo que o botão Load More é o caminho de teclado. Antes disso o
help não mencionava scroll infinito, carregar mais, marcador de fim ou
truncamento em lugar nenhum.

### Defeito 1 — a folha de estilo não compilava, e o CI não sabia ✅

`list-states.css` (Fase 0) usava `shadow-retro-button` e
`shadow-retro-button-pressed`, que **não existem** no tema. O `@apply` derrubava
o build inteiro do Tailwind. Consequência: qualquer `mix assets.build` falhava e
servia o CSS anterior — é isto que estava por trás do "erro parcial de esbuild"
que tornou a comparação da §5 não-hermética.

`make ci` passava 11/11 mesmo assim: `lint.css` são três **analisadores
estáticos** e nenhum deles compila a folha. Um utilitário inexistente passa em
todos e quebra todo build real.

Fechado com `make lint.css.build`, agora dentro do `lint.css`: monta o bundle e
roda o Tailwind num arquivo descartável. Verificado nos dois sentidos —
reintroduzindo o defeito o alvo falha, removendo passa.

**O aprendizado:** um gate que só lê o código não prova que ele constrói.

### Defeito 2 — a compensação de prepend do chat era intermitente ✅

O `ScrollHook` media `scrollHeight` quando o evento `prepend_start` chegava. Mas
o evento vem de um render e as linhas de outro (o `send_update` do island), e
quando o LiveView despacha os dois juntos o evento chega com as linhas já no DOM:
a diferença dá zero e o leitor é jogado para o topo. Media-se 252px de
compensação numa execução e 0 na seguinte.

O `beforeUpdate()` é o único momento que o framework garante ser anterior ao
patch — é o que o `InfiniteScrollHook` já fazia desde a 0.2. O `ScrollHook`
adotou o mesmo, e o E2E passou a medir `scrollTop == cresceu` de forma estável.

### Defeito 3 — o submenu File > Admin era inalcançável com o mouse ✅

Passar o mouse numa linha de submenu abre o flyout; o `mousedown` do clique
seguinte **alternava e fechava**. Como todo ponteiro passa por cima da linha a
caminho de clicá-la, o submenu abria e fechava no mesmo gesto. Só teclado e
toque chegavam lá.

Era isto que derrubava `chat-admin-users-window`, `chat-admin-channels-window` e
`chat-ui-features-admin` — não o refactor. `_setSubmenu` passou a registrar o que
abriu o flyout, e só um clique sobre um submenu que um **clique** abriu conta
como "fechar". Dois testes JS travam as duas metades.

### §5 do handover, resolvida hermeticamente ✅

Worktree em `origin/main` com build limpo: as duas specs falham **no item de
menu**, idêntico. Com só o conserto do menubar aplicado sobre o `origin/main`,
passam a falhar mais adiante, no formulário de exclusão do Admin Channels —
mesmo ponto e mesma mensagem que na árvore de trabalho. Ou seja: **as duas
falhas são anteriores a este trabalho**, e a segunda estava escondida atrás da
primeira.

### E2E ✅

`chat-infinite-scroll.spec.ts` (2 testes) e
`chat-trusted-terminals-pagination.spec.ts` (1), com `shot()` — o primeiro uso
real da ferramenta. `TEST_CATALOG.md` atualizado (197 specs, 371 casos).

**Aprendizado — proteção de flood isenta o próprio autor** (`flood.ex:23`), então
um usuário pode semear 58 mensagens no próprio canal sem se auto-ignorar. O
aprendizado registrado antes ("flood corta a partir de ~10") vale para semeadura
feita por **outro** autor.

**Aprendizado — recarregar a página inicia uma sequência de rejoin.**
`{:execute_rejoin, ...}` anda um canal a cada 100ms e termina em
`maybe_restore_active_tab`, que recarrega a primeira página do canal ativo. Um
E2E que recarrega e pagina em seguida corre contra isso: a página antiga é
buscada, renderizada e apagada. Custou três diagnósticos errados até instrumentar
o servidor. Specs que paginam depois de um reload precisam esperar a lista
estabilizar.

## Terceira rodada — auditoria do inventário e o que ela achou (2026-07-28)

O fechamento anterior declarou o plano cumprido a partir da §4 do handover. Uma
auditoria linha a linha do **inventário da §9** — a fonte da verdade — mostrou
que não estava: de 25 superfícies com tela, 10 estavam prontas, 11 tinham teto
sem aviso ou paginação inalcançável, e 4 não tinham sido tocadas.

O padrão era sempre o mesmo: **a query foi migrada, a tela não.**

### 2.8 Channel Central — e por que a resposta do plano estava errada ✅

O plano supunha que `services/queries.ex` alimentava esta janela. O código diz
outra coisa: ela lê `state.bans` / `state.ban_exceptions` /
`state.invite_exceptions` do **processo do canal**, e a access list vem do banco
via `ChanServ.registration_snapshot/2`.

Isso muda a decisão. Bans só são persistidos **se o canal for registrado**
(`server.ex`, `maybe_persist_ban`), então a tabela é um registro parcial e o
processo é a autoridade. Uma query paginada sobre essas linhas mostraria uma
lista vazia num canal não registrado.

Feito: teto de render de 200 por lista, no island, com `list_count_strip` dando
o total real. Testes em `channel_central_lists_test.exs` (6).

**`Services.Queries.list_bans/2` foi removida.** Construída na rodada anterior
para esta janela, tinha zero chamadores em produção — só três testes e um
exemplo de `@moduledoc`. É o padrão que a Fase 5 deste mesmo plano condena:
teste sobre código morto o faz *parecer vivo*. Os testes migraram para
`all_bans/1`, que é a função que de fato existe no caminho de enforcement, e o
`@doc` dela agora explica por que não há irmã paginada.

### 3.2 e 3.3 Admin — o cursor existia e não chegava na tela ✅

Audit log e lista de usuários já devolviam `Page` com cursor; as janelas
desenhavam a primeira página e paravam.

`Admin.Table` ganhou `append/2` — a janela pagina redespachando o mesmo comando
com um cursor, e o que volta descreve só a página nova. As colunas vêm da tabela
já em tela de propósito: são propriedade da listagem, não de uma página, e
adotar as novas deixaria uma mudança de forma reordenar colunas sob o leitor.

Os comandos ganharam a flag do cursor — `--before` no log (id), `--after` na
lista de usuários (nickname, porque a ordenação é alfabética). Paginação é uma
flag no comando que já existe, não um segundo caminho de leitura.

Testes: `admin_windows_pagination_test.exs` (3), `Table.append` (5),
`--after` no handler (2).

### As seis que truncavam em silêncio — três avisam, três documentam ✅

Espalhar `list_count_strip` em todas seria ruído. O critério aplicado:

| Superfície | Resposta | Por quê |
|---|---|---|
| URL Catcher (2.3) | conta o que descartou | buffer efêmero que **de fato** descarta em uso normal |
| Admin Console (2.4) | conta o que descartou | idem |
| Conversations (4.1) | `list_end_marker` | o plano nomeia a falta de sinal como o defeito |
| Bots / channel configs / commands (2.5, 2.6) | teto documentado | `@max_curated` é piso de segurança, não limite de produto |
| Nicks lembrados (2.9) | teto documentado | 200 dispositivos num terminal não acontece |

**Contar o que foi descartado é a única forma honesta.** Uma vez que o link ou a
linha caiu do buffer não há como inferi-lo depois, e um buffer cheio não é prova
de que algo foi jogado fora. Os dois contadores são incrementados no ponto do
descarte.

`list_pm_partners/2` passou a devolver `Page` com `has_more` e **sem cursor** —
`Page.new(rows, limit, fn _ -> nil end)`. É a forma honesta de uma lista que não
pode ser paginada: `limit + 1` é suficiente para dizer que não está inteira, e a
ausência de cursor faz `can_load_more?` recusar por construção.

### Os cinco estados, finalmente todos ligados ✅

`list_error_retry`, `list_skeleton` e `list_announcer` tinham **zero**
consumidores fora do showcase — a §8 exige os cinco estados e o de erro não
existia em superfície nenhuma.

O erro foi resolvido na fundação, não numa tela: `PaginatedList.load/3` captura
a falha, `State.failed/1` a registra **mantendo o cursor** (limpá-lo
transformaria uma falha numa lista silenciosamente curta), e as janelas
paginadas mostram o retry. Deixado propagar, o LiveView seria derrubado e
remontado na primeira página — que lê exatamente como "não havia mais nada".

O announcer deriva a mensagem do próprio estado, então é uma linha por janela.
O skeleton foi para a casa que o plano lhe deu na 4.7: o first-load do canal,
onde só havia spinner.

### Índice de `messages` — medido, e era um problema ✅

A §3 Passo 1 exige confirmar o índice antes de escrever a query keyset. Nunca
foi feito. Medido com 20 mil linhas em 40 canais:

```
SEM índice:  Bitmap Heap Scan → 439 linhas lidas + top-N heapsort → 51
COM (channel_name, id):  Index Scan Backward → 51 linhas lidas
```

O índice que cobria `channel_name` estava ordenado por `inserted_at`, então cada
página do scrollback lia **o canal inteiro** e ordenava. O trabalho crescia com o
tamanho do canal, não com o da página — que é precisamente "keyset sem índice é
pior que offset". Migration `20260728120000`, criada `concurrently` porque
`messages` é a tabela mais quente do servidor.

## O que falta

| Item | Estado |
|---|---|
| 1.3 — paginação do chat no island | **não será feito**: 1.4 foi resolvido sem ele, o ganho restante é só uniformidade |
| Admin Channels: exclusão perde o canal digitado | **pré-existente**, provado em `origin/main`; o formulário limpa o campo entre tentativas e a spec assume que persiste |

E a observação **fora do escopo deste plano**, mantida: arcade e lobby têm
`list_stale_sessions` + `expire_session` sem chamador, enquanto nicks, canais e
bans têm GenServers de expiração no supervisor. Pode ser uma lacuna de
durabilidade real e precisa de investigação própria.

## Aprendizado de método

O handover é um resumo; **o inventário do plano é a fonte da verdade**. Duas
rodadas seguidas fecharam o plano a partir do resumo e erraram, porque o resumo
registrava o que a rodada anterior *achava* ter deixado pendente, não o que a
tela de fato faz. A auditoria que funcionou foi mecânica: para cada linha da §9,
grep pelo componente de estado na tela e leitura da função de domínio.
