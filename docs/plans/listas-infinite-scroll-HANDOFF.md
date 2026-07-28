# Listas / infinite scroll — handover

Documento de retomada. Escrito em 2026-07-28 ao final da sessão de
implementação e **revisado no mesmo dia**, ao final da sessão que fechou o plano.

- **Plano:** `listas-infinite-scroll-auditoria.md` (contrato, receita, inventário)
- **Progresso e aprendizados:** `listas-infinite-scroll-PROGRESS.md`
- **Este arquivo:** estado do repositório, o que confiar, o que refazer

---

## 1. Estado do repositório — leia antes de qualquer coisa

**Nada está commitado.** `HEAD` está em `origin/main` (`a76e4130`). Todo o
trabalho — 123 entradas, 88 modificadas, 4 deletadas e 31 novas — está **solto no
working tree**, por pedido explícito do autor, para revisão antes do commit.

Consequências práticas:

- `git stash`, `git checkout .` ou `git reset --hard` **destroem uma sessão
  inteira de trabalho**. Não há commit para recuperar.
- Quatro arquivos foram **deletados** e o `git status` os mostra como ` D`. Um
  commit futuro precisa incluí-los (`git add -A` os pega; se estagiar caminho a
  caminho, não esqueça):
  - `components/ui/chat/scroll_loader.ex`
  - `components/ui/primitives/pagination.ex`
  - `live/showcase_live/chat/scroll_loader_page.ex`
  - `live/showcase_live/primitives/pagination_page.ex`
- A ressalva anterior sobre `docs/plans/dialogs-abas-para-janelas-HANDOFF.md`
  ficou sem objeto: esse arquivo não existe mais no working tree. Tudo que está
  solto hoje pertence a este refactor.

**Validação:** `make ci` **11/11** — agora incluindo `make lint.css.build`, que
não existia antes e que teria reprovado a árvore (ver §3.1).

---

## 2. O que este refactor entregou

Um contrato único de paginação, do banco ao hook JS, mais a aplicação dele a
todas as superfícies de lista do app.

### Fundação (Fase 0) — confiar

| Módulo | O que é |
|---|---|
| `RetroHexChat.Page` | struct de uma página + regra do `limit + 1` |
| `RetroHexChatWeb.PaginatedList` / `.State` | estado de paginação por lista, no island |
| `assets/js/lib/ui/infinite_scroll.js` | detecção de borda pura |
| `assets/js/hooks/ui/infinite_scroll_hook.js` | o hook para listas comuns |
| `Components.UI.ListStates` | 7 estados: vazio, fim, carregar-mais, contagem, erro, announcer, skeleton |
| `RetroHexChat.Admin.Table` | metade estruturada da resposta de `/admin` |
| `RetroHexChat.Channels.Directory` | snapshot de canal no valor do Registry |

### A regra central

Toda query paginada busca `limit + 1` linhas e devolve `limit`. `has_more` é
decidido pelo **banco**, antes de qualquer filtro de apresentação.
`Page.filter/2` e `Page.map/2` reescrevem `items` sem tocar
`has_more`/`next_cursor` — é isso que torna a classe de bug "filtro trunca a
paginação" inexprimível, e não apenas consertada.

### O critério que decide cursor vs teto

Emergiu executando, e vale aplicar a qualquer lista nova:

> **Pagina o que cresce sozinho. Limita o que só cresce quando alguém decide
> criar.** E paginar exige, além disso, que a **chave de ordenação seja
> imutável**.

Chave mutável (`last_seen_at`, `level`, "hora da última mensagem") impede cursor
keyset: linhas se movem entre páginas e podem ser puladas. Nesses casos: teto
alto + disclosure visível.

### Separação enforcement vs listagem — **não desfazer**

Cinco funções são **deliberadamente sem limite** porque alimentam aplicação de
regra, não tela. Paginá-las volta a quebrar o produto em silêncio:

| Função | Alimenta |
|---|---|
| `Services.Queries.all_bans/1` | estado do canal (recusa no join) + expiração |
| `Services.Queries.all_access/1` | idem |
| `Services.Queries.all_ban_exceptions/1` | idem |
| `Services.Queries.all_invite_exceptions/1` | idem |
| `Admin.ServerBans.all_active_bans/0` | `BanCache` (ETS que recusa conexão) |

As versões `list_*` correspondentes são paginadas e servem **só** a UI. Cada uma
tem o porquê no `@doc`.

---

## 3. Defeitos de produção corrigidos (com teste que trava a regressão)

### 3.2 O achado da terceira rodada

10. **A query migrada, a tela não.** Era o padrão por trás de quase todo o
    inventário: Channel Central lia listas ilimitadas do processo do canal, e as
    janelas de Admin desenhavam a primeira página de queries que já devolviam
    cursor. Um `Page` no domínio não é uma superfície migrada — a régua é se a
    tela alcança a página dois, ou diz que não pode.

11. **O índice que a paginação por keyset exigia não existia.** `messages` tinha
    `(channel_name, inserted_at)` e o cursor é `id`, então cada página do
    scrollback lia o canal inteiro e ordenava. Medido: 439 linhas lidas para
    devolver 51. Migration `20260728120000`.

### 3.1 Os três achados da sessão de fechamento

7. **A folha de estilo não compilava.** `list-states.css` aplicava
   `shadow-retro-button`, utilitário que não existe no tema; o `@apply` derrubava
   o build inteiro do Tailwind, e todo `assets.build` servia o CSS anterior. O
   `make ci` passava 11/11 porque `lint.css` só tem analisadores estáticos —
   nenhum compila a folha. Fechado com `make lint.css.build` dentro do `lint.css`.
   Era também a causa do "erro parcial de esbuild" que tornava a §5 não-hermética.

8. **A compensação de prepend do chat era intermitente.** O `ScrollHook` media a
   altura quando o evento `prepend_start` chegava, mas ele e as linhas vêm de
   renders diferentes; despachados juntos, o evento chega tarde e a diferença dá
   zero — o leitor é jogado ao topo. Agora mede em `beforeUpdate()`, como o
   `InfiniteScrollHook` já fazia.

9. **O submenu File > Admin era inalcançável com o mouse.** O hover abre o
   flyout e o clique seguinte alternava e fechava. Só teclado e toque chegavam
   lá. Era isto que derrubava as specs de janela do Admin.

1. **Scroll infinito do canal estava desligado para quem usa `/ignore`.**
   `has_more` vinha da lista já filtrada, então uma mensagem escondida na
   primeira página encerrava a paginação para sempre.
   Teste: `message_pagination_test.exs`, "ignoring the author of every message".

2. **`admin user list` imprimia o tamanho da página como total.** Servidor com
   milhares de nicks reportava "100 results".
   Teste: `registered_nicks_page_test.exs`, "discloses truncation".

3. **Channel List fazia um `GenServer.call` síncrono por canal.** Agora é uma
   leitura ETS via `Channels.Directory`.
   Teste: `directory_test.exs`, "listing never sends a message to a channel
   process".

4. **Stream de mensagens sem teto de DOM** — crescia sem fim no scrollback.

5. **URL Catcher e transcript do Admin Console cresciam pela vida do processo
   LiveView.** Ambos são buffers efêmeros de sessão; ganharam teto.

6. **Mudança de cor de nick re-consultava todo o histórico carregado.** Depois
   de rolar 2000 mensagens, trocar uma cor relia 2000 linhas.
   Teste: `message_pagination_test.exs`, "a presentation change does not
   re-read the history".

---

## 4. O que está incompleto — não arredondar

**Antes de declarar qualquer coisa pronta, audite o inventário da §9 do plano,
não este documento.** Duas rodadas fecharam o plano a partir do resumo e
erraram. A auditoria que funciona é mecânica: para cada linha da §9, grep pelo
componente de `ListStates` na tela e leia a função de domínio.

| Item | Estado real |
|---|---|
| **1.3** paginação do chat no island | **não será feito**: 1.4 foi resolvido sem ele (o `MessageViewport` guarda `rendered`), o ganho restante é só uniformidade |
| Admin Channels: exclusão perde o canal digitado | **pré-existente**, provado em `origin/main` (§5); causa: o input de `channel_action_form` não tem `value` e não sobrevive a um re-render |
| Strings novas de lista (`Load more`, `End of list.`, …) | **nunca extraídas**: inglês nos 13 locales — ver a auditoria pós-entrega no PROGRESS |

**A auditoria pós-entrega (PROGRESS, última seção) achou um defeito crítico já
corrigido:** o teto de DOM podava pela frente da lista, que é onde um prepend
aterrissa, então o scrollback do chat morria em 150 linhas e gastava as páginas
seguintes sem mostrá-las. Regra que ficou: **teto vale para a cauda viva, nunca
para o scrollback.** O cliente de teste do LiveView não aplica `limit`, então
essa classe de defeito só aparece no browser — a guarda é
`e2e/tests/chat-scrollback-audit.spec.ts`.

Todo o resto do inventário está fechado — ver o PROGRESS, seção "Terceira
rodada". As 25 superfícies com tela hoje se dividem em: paginação alcançável
onde a chave de ordenação é imutável, e teto com aviso onde não é.

---

## 5. A falha de E2E do Admin — resolvida

A ressalva de não-hermeticidade da versão anterior deste documento tinha causa
concreta: o build de assets falhava por causa do defeito 7 da §3.1. Com ele
corrigido, a comparação foi refeita em worktree limpo sobre `origin/main`:

1. As duas specs falham **no item de menu**, idêntico — a falha é anterior a
   este trabalho, como se suspeitava.
2. A causa era o defeito 9 (submenu fechado pelo próprio clique), agora
   corrigido. Três dos quatro testes passaram a passar.
3. O que sobra — `admin creates, inspects and deletes a channel` — falha no
   formulário de exclusão, que perde o canal digitado entre tentativas. Aplicando
   **apenas** o conserto do menubar sobre o `origin/main`, a falha é a mesma:
   também é pré-existente, só estava escondida atrás da primeira.

---

## 6. Como continuar — o playbook que funcionou

Ordem por superfície:

1. **Grep primeiro, código depois.** Antes de mudar uma query, liste **todos**
   os consumidores *e todos os testes* que afirmam sobre o comportamento antigo
   — incluindo `e2e/tests/`. Pular isso custou duas rodadas de CI nesta sessão.
   ```sh
   grep -rn "nome_da_funcao" --include="*.ex" --include="*.exs" apps/
   grep -rln "texto-antigo\|id-antigo" apps/*/test/ e2e/tests/
   ```
2. **Classifique** com o critério da §2 (cresce sozinho? chave imutável?).
3. **Domínio**: `Page` com `limit + 1`, ou teto com `@doc` explicando por quê.
4. **Consumidores**: separe enforcement de UI se houver os dois (§2).
5. **Island**: `PaginatedList`; markup com o hook e os estados de `ListStates`.
6. **Testes**: rode **só os arquivos afetados**.
7. **`make ci` uma vez, ao final de um bloco grande** — não por superfície.
   Cada execução leva ~4min30.
8. **Registre no PROGRESS** antes de seguir para a próxima.

### Armadilhas verificadas nesta sessão

- `mix audit.styles` rodado de dentro de `apps/retro_hex_chat_web` reporta
  **0 achados e "All styles are in CSS!"** — parece sucesso, é escopo vazio.
  Sempre da raiz.
- `enforce_hooks_contract.cjs` exige hook (a) num builder **e** (b) usado num
  `phx-hook` literal — e casa a string por regex **inclusive dentro de `@doc`**.
- Credo reprova alias fora de ordem alfabética. Conferir ao adicionar.
- Em `~H`, `@qualquer_coisa` é lookup de **assigns**, nunca atributo de módulo.
- Em `code_example` do showcase, chaves se escrevem `&#123;`/`&#125;` — `&lt;`
  não impede o HEEx de interpolar `{...}`.
- `send_update/2` posta para `self()`; de um teste use a aridade com pid.
- `Phoenix.LiveView.stream/4` estoura num `%Socket{}` nu (`KeyError :lifecycle`).
- `required: true` num `attr` **não** protege `render_component/2` — vira
  `KeyError` em runtime. Componente renderizado standalone precisa de default.
- Os dois workers de teste do CI rodam **em paralelo e compartilham o Registry**;
  asserção sobre diretório global tem que ser de pertencimento, nunca de
  contagem.
- Proteção de flood corta o handler a partir de ~10 mensagens do mesmo autor —
  testes que semeiam muitas mensagens medem flood sem perceber. **Mas ela isenta
  o próprio autor** (`flood.ex:23`), então no E2E um usuário pode encher o
  próprio canal à vontade; a armadilha vale para semeadura por outro autor.
- `lint.css` **não compila** a folha de estilo — são três analisadores estáticos.
  Um `@apply` de utilitário inexistente passa em todos e quebra todo build real,
  servindo o CSS anterior. É por isso que existe `make lint.css.build`.
- `update/2` de um LiveComponent roda a **cada render do pai**. Refazer o
  snapshot ali reseta os streams e descarta as páginas já carregadas.
- Recarregar a página inicia uma sequência de rejoin (`{:execute_rejoin, ...}`,
  um canal a cada 100ms) que termina recarregando a primeira página do canal
  ativo. Um E2E que recarrega e pagina em seguida corre contra isso, e o sintoma
  — a página antiga aparece e some — parece bug de paginação. Espere a lista
  estabilizar antes de rolar.
- Ao diagnosticar sumiço de linhas: o teste LiveView prova o **servidor**, o
  `MutationObserver` no browser prova o **cliente**, e um `Logger` nos callbacks
  do island prova **quem** disparou. Três medidas, nessa ordem, em vez de
  hipóteses.

### Regra de escopo

Remover código morto é algo que se faz **ao passar pelo código durante a
tarefa**. Nesta sessão eu saí varrendo o repositório inteiro e cheguei em
subsistemas sem relação (expiração de sessões de arcade/lobby), tive que
reverter e perdi tempo. O escopo da limpeza é o escopo do trabalho.

---

## 7. Observação fora do escopo deste plano

Encontrada durante a sessão, **revertida por estar fora de escopo**, registrada
para não se perder:

`Arcade.Queries` e `Lobby.Queries` têm `list_stale_sessions/1` e
`expire_session/1` **sem nenhum chamador**, enquanto nicks, canais e bans têm
GenServers de expiração no supervisor (`NickExpiry`, `ChanExpiry`, `BanExpiry`).
O caminho normal de encerramento funciona (o `session_server` marca `"closed"` ao
terminar), mas se o processo morre sem isso — crash, restart, deploy — a linha
fica em status não-terminal para sempre, e `active_session_exists?/1` passa a
impedir o usuário de abrir sessão nova.

Pode ser lacuna real de durabilidade. Precisa de investigação e decisão próprias,
não faz parte deste refactor.
