# Progresso — Diálogos com abas → janelas dedicadas

Plano: `docs/plans/dialogs-abas-para-janelas.md`

Registrar aqui, por fase: o que foi feito, o que foi descoberto que o plano não
previa, e as decisões tomadas em execução. Aprendizados duráveis migram para
`docs/AGENT-GUIDE.md` no fecho do bloco.

---

## Estado

| Fase | Descrição | Status | Commit |
|---|---|---|---|
| 0 | Substrato compartilhado (`AdminShared`, `AdminOps`) | ✅ feito | — |
| 0.5 | Submenu no menu bar + `File > Admin` | ✅ feito | — |
| 1 | `admin-users` | ✅ feito | — |
| 2 | `admin-channels` | ✅ feito | — |
| 3 | `admin-server-settings` | ✅ feito | — |
| 4 | `admin-audit-log` | ✅ feito | — |
| 5 | `admin-motd` | ✅ feito | — |
| 6 | `admin-turn` | ✅ feito | — |
| 7 | `admin-broadcast` | ✅ feito | — |
| 8 | `admin-danger-zone` | ✅ feito | — |
| 9 | `admin-console` — monólito deletado, recriado só com o REPL | ✅ feito | — |
| 10 | **Limpeza** (§6 do plano) | ✅ feito | — |
| 11 | **Channel Central** — 6→4 abas (fusão das 3 listas de acesso) | ✅ feito | `a0289349` |
| 12 | **Perform** — `perform` + `autojoin` (2 abas → 2 janelas) | ✅ feito | — |

Ordem: o Admin Console (era a Fase 6 do plano) foi promovido a primeiro caso por
ser o mais complexo — é ele que deriva o playbook.

---

## Passo 0 — Substrato compartilhado ✅ 2026-07-25

**Feito:** dois módulos novos, monólito passa a consumi-los. Refactor sem
mudança de comportamento.

- `components/ui/dialogs/admin_shared.ex` → `UI.AdminShared`: `inline_result/1`
  (era `admin_inline_result/1`, 7 call sites), `present?/1`.
- `live/chat_live/admin_ops.ex` → `ChatLive.AdminOps`: `admin?/1`,
  `restricted_message/0`, `dispatch/3`, `user_context/1`, `result_entry/1`,
  `first_error_entry/1`, `result_status/1`, `result_message/*`, `error_event/2`.

**Validação:** `mix compile --warnings-as-errors` limpo · `mix format` ·
`mix credo --strict` 0 issues · **27/27** em
`server_administration_feature_test.exs` · 6/6 no teste do island.

### Descoberto (não previsto no plano)

1. **Havia três cópias de `admin?/1`**, não uma: no island
   (`components/admin_console_dialog.ex`), no módulo de eventos
   (`admin_console_events.ex`) e implicitamente em `ChatContext`.
2. **`error_event/2` é duas funções diferentes com o mesmo nome.**
   `Helpers.error_event/2` roda no LiveView pai; a do island faz
   `send(self(), {:admin_system_error, msg})` para chegar lá. Conflatar as duas
   quebra o hook de abertura. **Regra:** dentro de hook → `Helpers`; dentro de
   island → `AdminOps`.
3. **`admin_inline_result/1` declarava `attr :target` e nunca usava.** Removido;
   os 7 call sites deixaram de passar.
4. **A mensagem "Admin Console is restricted…" tinha 20 call sites** e nomeava o
   monólito. Virou `AdminOps.restricted_message/0` com texto semântico. Nenhum
   teste quebrou — ou seja, **a string não é asserida em lugar nenhum**: lacuna
   de cobertura, não corrigida aqui.

### Aprendizados para o playbook

- **Rename mecânico:** `perl -pi -e 's/\bnome\(/Mod.nome(/g'` com word boundary
  **não** pega `audit_log_result_entry(` (o `_` antes é word char → sem
  fronteira). Exatamente o que se quer.
- **O que o padrão ancorado em parêntese perde: capturas.** `&result_message/1`
  não tem `(` e passou batido. Quem pegou foi
  `mix compile --warnings-as-errors`. **O compilador é o oráculo do rename** —
  rodar antes de qualquer teste.
- **Como achar o substrato:** contar consumidores. 2+ das N janelas novas usam →
  promove a módulo. 1 usa → fica privado na janela dela. Foi o que separou
  `inline_result` (7) de `settings_input` (1, fica privado em Server Settings).
- **Os feature tests são `@tag :liveview_feature` e ficam EXCLUÍDOS por
  padrão.** `mix test <arquivo>` dá "0 failures" sem rodar nada relevante.
  Precisa de `--include liveview_feature`. Esses 27 testes são o oráculo de
  paridade da fatia inteira.

---

## Passo 0.5 — Submenu no menu bar ✅ 2026-07-25

**Feito:** o menu bar ganhou suporte a submenu, e as janelas admin passam a
morar em `File > Admin`.

- `components/ui/shell/menu_bar.ex`: novo `submenu/1`. Renderiza como um único
  `<li>` (o formato que as `*_menu_items/1` produzem) com gatilho + painel
  próprios, no contrato `data-menubar-submenu` / `data-menubar-submenu-panel`.
- `assets/js/hooks/ui/menu_bar_hook.js`: `_trackSubmenuHover/1`,
  `_openSubmenu/1`, `_closeSiblingSubmenus/2`, `_setSubmenu/2`; isenção do
  gatilho no handler de click; `_closeAll` passa a fechar submenus.
- `assets/css/retrohex/components/app-menu.css`: flyout no desktop, **expansão
  inline no `.desktop--stacked`**.
- `menu_bar_app.ex`: `File > Admin` com `admin_menu_items/1` dentro.

**Validação:** compile limpo · `make lint.js` · **23/23** em
`menu_bar_hook.test.js` (8 novos) · `make lint.css` **0 LOW / 0 MEDIUM /
0 HIGH** · **54/54** em 5 suítes Elixir que asseguram markup de menu.

### Por que o painel não pode reusar `data-menubar-dropdown`

O hook varre `querySelectorAll("[data-menubar-dropdown]")` no `_closeAll` e faz
`querySelector` descendente no `_openMenu`. Um painel aninhado com esse atributo
abriria e fecharia junto com o pai, e o `_openMenu` poderia achar o painel
errado. Daí o contrato separado.

### A regressão que o teste cobre

`menu_bar_hook.js` fechava tudo ao clicar em qualquer `<li>` dentro de um
dropdown. O gatilho do submenu **é** um `<li>` dentro de um dropdown — sem
isenção, clicar nele fecharia o menu inteiro. O teste
`"keeps the parent dropdown open when the submenu trigger is clicked"` trava
isso.

### Mobile: expansão inline, não flyout

O shell mobile é grid fixo de duas colunas, com `overflow: hidden` no dropdown
externo e `overflow-y: auto` no painel de conteúdo. Um flyout `absolute`
escapando para a direita é clipado e fica inalcançável. A solução é CSS puro —
`position: static` no `.desktop--stacked` — então **o contrato de abrir/fechar é
idêntico nos dois**, sem ramificação no JS.

### Aprendizados

- **Três pontos de inserção por menu**, não um: strip desktop, categoria mobile
  e painel mobile. As `*_menu_items/1` são compartilhadas, mas a navegação
  mobile não é.
- **Mover item de menu é barato e não é coberto.** Os 54 testes asseguram
  `data-testid="context-menu-item-<action>"`, nunca a hierarquia. Mudar um item
  de menu não quebra teste nenhum — o que também significa que a hierarquia do
  menu não tem rede de proteção.

---

## Janelas 1 e 2 — `admin-users`, `admin-channels` ✅ 2026-07-25

**Feito.** Duas janelas completas; as abas Users e Channels saíram do monólito
(markup, handlers, assigns, helpers, attrs, testes e blocos e2e).

Por janela: apresentacional (`_dialog/1` framed + `_panel/1`), island, entrada
no `AdminEvents`, `@managed`, bloco `desktop_window`, taskbar, item em
`File > Admin`, tópico de ajuda + conteúdo + glob, página de showcase + 4
registros, teste de island, teste de feature, spec e2e + page object + catálogo.

**Validação:** compile `--warnings-as-errors` · `mix format` · credo 0 issues ·
`make lint.css` 0/0/0 · `make lint.js` · **8/8** users feature · **11/11**
channels feature · **5/5 + 6/6** islands · **19/19** console (as 7 abas
restantes intactas).

### O padrão que se repetiu

A segunda janela levou uma fração do tempo da primeira. A sequência que
funciona, na ordem:

1. Ler o bloco da aba no apresentacional **e** os handlers/helpers no island.
2. Criar o apresentacional (mover markup, renomear ids para o prefixo novo).
3. Criar o island (mover handlers, renomear eventos).
4. Wiring em 5 pontos: `windows.ex`, `AdminEvents`, `menu_bar_app`,
   `chat_taskbar`, `chat_live.html.heex`.
5. **Só então** deletar do monólito: trigger, `tabs_content`, função,
   sub-formulários, attrs, handlers, helpers, assigns, wiring do render.
6. Migrar os testes preservando as asserções.
7. Ajuda, showcase, e2e, catálogo.

### Aprendizados novos

- **Formulários quase-idênticos colapsam em um.** `user_nickserv_form` +
  `user_moderation_form` → `nick_action_form`; `channel_chanserv_form` +
  `channel_destructive_form` → `channel_action_form`. A diferença era só quais
  campos opcionais aparecem, e a ordem dos campos se preserva porque os que
  faltam simplesmente não renderizam. 11 formulários por janela, um componente.
- **`error/1` colide com `CoreComponents.error/1`** em qualquer módulo
  `use ..., :live_component`. Nomear `error_result/1`.
- **Três funções `normalize_*` eram idênticas** (`to_string |> String.trim`) —
  `users_search`, `user_moderation_value`, `channels_value`. Viraram um `trim/1`
  por janela.
- **O teste de island do console teve a fixture reescrita duas vezes**, porque
  eu a ancorei na aba que estava saindo. Agora aponta para `motd` /
  `server_settings` / `audit_log`. **Regra:** teste de shell nunca se ancora na
  aba que está sendo extraída — escolha a que sai por último.
- **As keywords de ajuda migram junto com a aba**, e as referências cruzadas
  precisam de ajuste nos dois sentidos: o tópico novo aponta para o console, e
  `cmd-admin-*` deixa de apontar só para o console.
- **`scripts/test_showcase.exs` tinha um caminho morto** (`/showcase/admin-console`
  em vez de `admin-console-dialog`). Corrigido de passagem.

### Pendente naquele momento (ambos resolvidos depois)

- ~~Catálogos i18n não rodados.~~ Rodados no fecho da fatia — ver "Limpeza das
  falhas pré-existentes".
- ~~`p2p_session_flow_test.exs:682` falhou uma vez.~~ Ver "Testes flaky".

---

## Janelas 3-9 + teardown do monólito ✅ 2026-07-25

**A fatia do Admin Console está completa.** As 9 abas viraram 9 janelas e o
monólito foi deletado.

| Arquivo | Antes | Depois |
|---|---|---|
| `components/ui/dialogs/admin_console_dialog.ex` | 1703 linhas (9 abas) | **116** (só o REPL) |
| `live/chat_live/components/admin_console_dialog.ex` | 1336 linhas | **191** (só o REPL) |

Os dois arquivos foram **deletados com `rm`** e recriados, para não sobrar linha
do monólito disfarçada de janela nova. O shell de abas inteiro morreu:
`admin_console_tabs/1`, `admin_tab/1`, `admin_shell_tabs/0`, a superfície de 82
attrs, o branch modal não-windowed, os 7 assigns-sombra.

**Janelas:** 22 → 30 no chat.

### Validação final

`make ci` — **9/9**. Todos verdes, dialyzer incluído. Ver "Limpeza das falhas
pré-existentes" abaixo.

### Aprendizados novos

- **Corrigir uma segurança que estava aberta.** `admin_console_change_nuke_confirm`
  não tinha guard de admin. A janela nova roda todos os handlers por `guarded/2`,
  inclusive esse. Foi a única correção de comportamento do refactor.
- **CSS morto não é só o arquivo da feature.** `admin-console.css` inteiro
  morreu, mas `account.css` também carregava 23 seletores `.ac-main-tabs*` da
  época em que os dois diálogos dividiam o scroller de abas mobile. O
  `lint.css_consistency` achou; grep pelo prefixo não teria bastado.
- **O credo pegou o inchaço da taskbar** (complexidade 12, máx 9) quando as 9
  janelas viraram 9 branches. Viraram uma lista `@admin_windows` + um
  `add_admin_windows/2`. O linter marcou o momento certo de extrair.
- **`npx prettier` ≠ o prettier do repo.** `npx` baixa outra versão e discorda
  do `node_modules/.bin/prettier` que o `make format.check` usa. Sempre o do
  repo.
- **A tradução automática perde placeholders.** 112 entradas voltaram sem
  `%{...}`. `scripts/i18n_repair_placeholder_mismatches.py` conserta, mas marca
  as reparadas como fuzzy — e aí o `catalog.check` reprova. Precisa de um
  terceiro passo: limpar a flag onde os placeholders voltaram a bater.
- **O locale `en` não é traduzido, é preenchido.** `msgstr = msgid`. O tradutor
  automático pula `en`, então as entradas novas ficam vazias e reprovam. E os
  fuzzy do `en` vêm errados do merge (`Channels` → `Channel List`).
- **O `extract` mexe em 18 `.pot`**, 12 dos quais eu não tinha tocado. Revertidos
  um a um. Consequência: `i18n.gettext.check` reprova, apontando esses 12 —
  **débito pré-existente**, e não faz parte do `make ci`.

### Limpeza das falhas pré-existentes

Pedido de deixar tudo verde antes do commit. Estado final: **`make ci` 9/9**.

**Dialyzer — corrigido.** Duas advertências `pattern_match` em
`help_live/index.ex`. A causa: `@spec resolve_topic(map()) :: {:ok, map(), ...}`
declarava não-nil, mas o corpo chama `HelpTopics.get_topic(@default_topic)`, que
devolve `topic() | nil`. O spec estava mentindo, e o dialyzer, confiando nele,
concluía que as cláusulas defensivas `page_title(nil)` / `page_description(nil)`
eram inalcançáveis.

Corrigido **alargando o spec** para `{:ok, map() | nil, String.t()}`, não
deletando as cláusulas: o tópico padrão é procurado como qualquer outro, e um
catálogo que o perdesse devolveria nil de verdade. `breadcrumb_items/2` ganhou a
cláusula nil que faltava para o mesmo caminho. Dialyzer: **0 erros**.

**Catálogos `.pot` desatualizados — corrigidos.** `i18n.gettext.check` apontava
5 `.pot` do app de domínio. É all-or-nothing: regenerei os 18, fiz merge dos 18
domínios, e só `help_space.po` tinha entradas novas (7 × 21 locales). Traduzido,
`en` preenchido, placeholders conferidos. **Os cinco gates de i18n passam**
(`catalog`, `placeholder`, `source-fallback`, `gettext`, `catalog.size`).

### Continua vermelho, e por quê

**`i18n.audit.check` — ~280 findings, nenhum meu.** São keywords de tópicos de
ajuda em string crua em vez de `dgettext`, espalhadas por `services.ex`,
`commands.ex` e outros. Zero findings nos arquivos que criei e zero nos tópicos
que adicionei; o trabalho desta fatia **reduziu** o total de 283 para 280.

Não corrigi porque não é limpeza, é outro refactor: embrulhar ~280 keywords
geraria ~5.900 traduções (280 × 21 locales) — e, mais sério, **as keywords
alimentam a busca da ajuda**. Traduzi-las muda o que casa com o que o usuário
digita. É uma decisão de produto, não uma correção de lint, e não cabe num
commit de refactor de UI.

`i18n.audit.check` não faz parte do `make ci`.

### E3 — Só liguei uma das três superfícies de entrada

Achado na revisão final, não por teste. As 9 janelas entraram no menu bar
(`File > Admin`), mas o **start menu** e o **toolbar** continuaram com a entrada
única "Admin Console" — que, depois do teardown, abre o REPL. Ou seja: o rótulo
voltou a mentir nessas duas superfícies (o mesmo E2), e 8 janelas eram
invisíveis a partir delas.

**Por que passou:** meu teste de entry points asseria só o menu bar, e o
playbook listava 5 pontos de wiring sem o start menu. O contrato do plano (§8
item 9) sempre disse três superfícies.

**Corrigido:** as 9 entradas nas três superfícies, e o teste passou a iterar
`admin_actions()` × `admin_surfaces()` — se uma superfície esquecer uma janela,
o teste nomeia qual e onde. O playbook virou 7 pontos de wiring.

## Fase 2 — Limpeza de código morto ✅ 2026-07-25

Cada alegação do §6 do plano foi **verificada antes de deletar** — o plano é de
antes das minhas mudanças e podia estar desatualizado. Todas se confirmaram.

| Removido | Evidência |
|---|---|
| `channel_dialog.ex` + página de showcase + 4 registros | Único call site era o showcase. Subconjunto degradado do Channel Central, com modes que nem batiam |
| `bot_edit_field`, `bot_cancel_edit`, `bot_update_field` + `handle_field_update/4` | 0 emissores fora do próprio events |
| `bot_update_cap_config` + `coerce_config_value/1` | 0 emissores |
| `bot_toggle_channel` + `do_toggle_channel/4` | 0 emissores |
| attrs `active_tab`, `editing_field`, `capabilities` do Bot | 0 usos no template |
| branch `:reset` do Custom Menus | `:saved`/`:error`/`:deleted` têm remetente; `:reset` não |

### A cadeia que a limpeza expôs

Tirar os attrs mortos do Bot revelou mais coisa morta atrás deles:

- `editing_field` ficou sem quem escrevesse (os handlers saíram) **e** sem quem
  lesse (o attr saiu) — assign removido.
- `tab` era gravado por `bot_dialog_tab`, um handler cujo efeito visual é zero:
  a troca de aba do Bot é JS puro. Com o attr fora, virou estado morto. Saíram
  o assign, o handler e os 5 `phx-click="bot_dialog_tab"` dos gatilhos.

**O compilador fez a detecção em cascata.** Removi um handler, ele apontou
`coerce_config_value/1` órfão; removi, apontou o próximo. Rodei em loop até
parar. `--warnings-as-errors` é a ferramenta certa para isso — não grep.

**Validação:** compile limpo · credo 0 issues · `lint.css` PASS · 305/305 nas
suítes de showcase, bot e componentes.

### E4 — Despejei 9 itens flat no start menu

Ao corrigir o E3 eu adicionei as 9 janelas ao start menu **como lista flat** —
o mesmo problema que o plano descreve na Fase 0b e que eu tinha acabado de
marcar como pendente. O usuário apontou.

**Corrigido:** `start_menu_submenu/1` em `components/ui/layout/desktop.ex`, com
JS próprio no `WindowManagerHook` (`data-start-submenu` /
`data-start-submenu-panel` — contrato separado do menu bar, que é dirigido por
outro hook), flyout no desktop e expansão inline no `.desktop--stacked`. As 9
janelas viraram um grupo "Admin". 7 testes novos em
`window_manager_hook.test.js` (74/74).

Aproveitei para fechar a outra metade da Fase 0b que faltava: o
`.desktop-start-menu` ganhou `max-height: min(72vh, 560px)` e `overflow-y: auto`
— antes era `w-56` sem teto nem scroll, e crescia para fora da viewport.

**Regra:** ao adicionar entradas a uma superfície de navegação, ver antes se ela
já tem agrupamento. Se não tem e você está adicionando mais de duas, o
agrupamento é parte do trabalho.

### Testes flaky, sem veredito

Duas falhas apareceram **uma vez cada** sob carga paralela do `make ci`, e nunca
mais: `p2p_session_flow_test.exs:682` e `sfu_media_path_test.exs:105`. Ambas em
WebRTC/mídia, ambas 3/3 verdes isoladas, ambas fora do escopo do refactor. O CI
final passou com as duas verdes. **Não confirmadas como pré-existentes** — só
não reproduziram.

**Atualização 2026-07-25 (pós-rebase): a frequência subiu.** O teste
"audio-only setup joins receive-first and starts microphone after peer media"
(`p2p_session_flow_test.exs`, a linha muda a cada commit de P2P) falhou em
**2 de 4** rodadas de `make ci`, sempre no mesmo ponto: o **segundo**
`{:ok, state} = Lobby.session_info(session.token)` devolve `{:error, :not_found}`
— o `SessionServer` morreu entre a primeira consulta e a segunda. Isolado:
2,3s e 269/269 verdes.

**Duas hipóteses investigadas e DESCARTADAS** (não repetir):

| Hipótese | Como testei | Resultado |
|---|---|---|
| `@connecting_timeout` (30s, armado ao entrar em "lobby", cancelado só em "connected") | `lobby_connecting_timeout: 300` em `config/test.exs` | teste **passa** — o fusível não está armado neste caminho |
| `@rejoin_grace_timeout` (30s, armado no `:DOWN` de uma conexão) | `lobby_rejoin_grace_timeout: 300` | teste **passa** — idem |

Ambos os temporizadores leem de `Application.get_env`, então a costura para
encurtá-los já existe e funciona — só não é por eles que a sessão morre.

Sobra investigar: as outras saídas `{:stop, :normal, ...}` do
`lobby/session_server.ex` (`do_close`, `do_expire` por `lobby_expiry`, o
`handle_info({:DOWN, ...})` derrubando a última conexão) e a hipótese de que sob
`max_cases: 28` um processo LiveView do par seja derrubado, levando a sessão
junto. **Fora do escopo deste refactor** (decisão travada §12.2: P2P não é
tocado) e dentro da área que o upstream mexeu hoje — não corrigi.

---

## Fase 3 — Channel Central: 6 → 4 abas ✅ 2026-07-25

**Feito.** As abas `bans`, `ban_exceptions` e `invite_exceptions` viraram uma
aba **Access Lists** com seletor de tipo. A janela ficou, como o plano manda.
Nenhuma janela nova; nenhuma capacidade perdida.

| Arquivo | Antes | Depois |
|---|---|---|
| `components/ui/dialogs/channel_central_dialog.ex` | 1343 | **1223** |
| `live/chat_live/components/channel_central_dialog.ex` | 1003 | **925** |

O que colapsou: 3 add-forms de 59 linhas → 1 parametrizado · `list_tab/1` 3×
chamada → `access_lists_tab/1` com seletor · 3 `*_selected` + 3
`show_cc_add_*_dialog` → `list_type` + `list_selected` +
`show_cc_add_list_entry_dialog` · 12 handlers → 6 · 3 getters derivados → 1 com
chave de estado.

**Validação:** `make ci` **9/9** · 30/30 `channel_central_feature_test` ·
6/6 `chanserv_channel_central_feature_test` · 100/100 showcase smoke ·
**15/15 specs e2e** (channel-central, exceptions ×3, sync, mode-matrix,
ui-features-channel, context-menus, conversation-context-settings, tools-menu) ·
os 5 gates de i18n verdes.

### A receita saiu daqui

O playbook ganhou uma **Parte II** (§11–§14) com o procedimento de fusão. O
resumo do que ela trava: como reconhecer uma fusão (5 sinais mecânicos), a
sequência invertida (fusão substitui no lugar, não cria antes de deletar), o
discriminador ditando o vocabulário, um testid + `data-*` em vez de N testids,
e a divisão despacho-no-island / rótulos-no-apresentacional.

### Aprendizados novos

- **O rótulo do produto não pode ser o identificador do código quando o nome já
  está tomado.** "Access Lists" colidia com o `access_tab`/`access_selected`/
  `access_nick` que a aba Registration usa para SOP/AOP/VOP. Os assigns novos
  viraram `list_*`; "Access Lists" ficou só na UI.
- **A fusão obriga exatamente uma mudança de comportamento**, e ela precisa de
  teste próprio: três seleções viram uma, então **trocar de tipo limpa a
  seleção** (senão o Remove aponta para uma máscara fora da lista visível). Foi
  a única asserção nova — todas as outras foram migradas, não escritas.
- **Preserve as mensagens de erro literalmente, inclusive as assimétricas.**
  `unban` erra com "Unban error:" e `remove_ban_exception` com "Ban exception
  error:". Uniformizar seria bonito e descartaria 21 locales de tradução. Duas
  famílias de função preservam a assimetria sem custo.
- **Zero CSS novo.** O seletor reusou `.cc-segmented-tabs` da aba Registration —
  incluindo o `grid-template-columns: repeat(3, minmax(0, 1fr))` do
  `.desktop--stacked`, já escrito para exatamente três botões. Numa fusão,
  procure o controle equivalente no vizinho antes de escrever CSS.
- **`mb-2` virou gap dobrado** ao embrulhar a aba num `space-y-2` para caber o
  seletor. Remover preservou o espaçamento original exatamente.
- **Grep na ajuda por nome de aba, não só pelo nome do diálogo.**
  `chanserv_ui.html.heex` dizia "escolha Registration **depois de Invite
  Exceptions**" — instrução de navegação invalidada em silêncio pela fusão.

### E5 — Confundi deriva de referência com rewrap de catálogo

Vi 1.399 linhas alteradas em `help.po` depois do `mix gettext.merge`, lembrei da
regra "PO files são polib-canônicos, nunca gettext.merge", revertí tudo e comecei
a escrever um sincronizador cirúrgico com polib. **Estava errado:** as 1.399
linhas eram `#: features.ex:NNN` deslocadas em 1, porque eu tinha adicionado uma
linha ao arquivo. Nenhum rewrap.

O sincronizador foi jogado fora e o fluxo do playbook (extract → merge) rodou
como sempre. Custo: uma volta inteira.

**Regra:** contar linhas alteradas não distingue deriva de churn — **ler cinco
delas distingue**. E a regra do polib vale para editar um msgid existente, não
para o ciclo extract/merge.

Ironia útil: no `en` a regra do polib valia mesmo. `polib.save()` rewrapou os
msgid e gerou ~1.200 linhas de churn em `help_features.po` para preencher 5
entradas. O preenchimento do `en` passou a usar `Expo.PO.compose` — o mesmo
escritor do gettext — e ficou byte a byte.

### O tradutor automático estraga entradas que não são suas

7 entradas em fallback inglês viraram lixo com placeholder quebrado
(`"Version %{version}"` → `"<ph0>>/ph0>"`), nenhuma delas tocada por este
trabalho. **5 das 7 eram plurais** e um diff que olha só `e.msgstr` não as vê —
entrada plural tem `msgstr` vazio. Quem pegou foi o `i18n.placeholder.check`.

Depois de traduzir: diff semântico contra o snapshot pré-merge comparando
`msgstr` **e** `msgstr_plural`, e reverter o que não era para mudar.

### Fora de escopo, registrado

- `scripts/test_showcase.exs` lista 76 páginas contra as 99 do
  `showcase_smoke_test.exs` — `/showcase/channel-central-dialog` está entre as
  ausentes. Divergência pré-existente, não corrigida aqui.
- **O flake de P2P subiu de frequência e continua sem causa.** Ver
  "Testes flaky" abaixo — investigado a fundo no rebase, duas hipóteses
  descartadas.

---

## Fase 4 — Perform → `perform` + `autojoin` ✅ 2026-07-25

**Feito.** As duas abas viraram duas janelas. Janelas: 30 → 31.

Por janela: apresentacional (`_dialog/1` framed + `_panel/1`), island, hook de
eventos próprio, `@managed`, bloco `desktop_window`, taskbar, entrada nas três
superfícies, página de showcase + 4 registros, teste de island, teste de
feature, page object e spec e2e, tópico de ajuda.

**Validação:** `make ci` **9/9** · 133/133 nas suítes tocadas (feature + island +
showcase smoke) · `lint.css` 0/0/0.

### O que a extração pura confirmou do playbook

A Parte I funcionou sem emenda — foi a primeira extração feita **lendo** o
playbook em vez de derivá-lo. Os 7 pontos de wiring, a ordem "nada é deletado
antes de o substituto compilar" e a escada de verificação bateram. Duas notas
novas:

- **Sem aba, não há diretiva de abertura.** As duas janelas trocaram
  `Windows.open_with/4` por `Windows.open/2` e apagaram a cláusula
  `update(%{open: ...})`. Como a janela é gerenciada, fechar desmonta o island —
  o estado que a diretiva resetava é reconstruído no mount seguinte. Manter a
  cláusula seria código morto nascendo junto com a janela.
- **O hook compartilhado se divide junto.** `perform_autojoin_events.ex` (um
  módulo, dois donos) virou `perform_events.ex` + `autojoin_events.ex`. O nome
  composto era o rastro de que ali moravam duas features.

### Aprendizados novos

- **As três superfícies de entrada não têm o mesmo contrato.** Menu bar e
  toolbar emitem a ação (`data-testid="context-menu-item-open_autojoin_dialog"`);
  o **start menu** abre a janela direto pelo window manager
  (`data-window-open="autojoin"`, testid `start-menu-item-autojoin`). Meu teste
  de entry points nasceu com a asserção do Admin — um `or` entre os dois shapes —
  e reprovou. Corrigido para cada superfície asseriar **o seu** contrato: um `or`
  teria deixado passar uma entrada faltando na superfície ímpar, que é
  exatamente o furo do E3.
- **Ícone de aba vira ícone de janela.** `icon_tab_autojoin` ficaria órfão (o
  prefixo `icon_tab_` mente numa janela sem abas). Virou o par
  `icon_dialog_autojoin` + `icon_btn_autojoin`, com os 4 usos em tópicos de
  ajuda repontados. **Checar os usos como átomo** (`icon: :icon_tab_autojoin`) —
  grep pelo nome da função não os acha.
- **CSS: aqui a duplicação venceu o compartilhamento.** O Admin compartilhou
  `admin.css` entre 9 janelas irmãs; com 2, segui o contrato literal do plano
  (§8.13) e criei `autojoin.css` com prefixo `aj-`. `perform.css` perdeu 80
  linhas do scroller de abas mobile que morreram com o shell — o mesmo padrão do
  `.ac-main-tabs*` no Admin. **Regra:** família grande compartilha, par
  extraído duplica.
- **`window_item` do start menu não aceita `action`.** Ele emite
  `data-window-open` e o testid é o **id da janela**, não o da ação. Perform já
  era assim; copiar o padrão do vizinho antes de escrever o teste teria evitado
  a reprovação.

### A dívida de i18n que o rebase entregou

Os 6 commits de P2P que chegaram do upstream renomearam "P2P Lobby" → "P2P
Session" **sem re-extrair os catálogos**. O `extract` desta fase acusou 17
`.pot` alterados: 6 meus, 11 deles.

Tentei a disciplina de escopo do playbook (reverter o que não é meu), mas
`help.pot`, `chat.pot` e `help_features.pot` estão **misturados** — carregam as
minhas strings e as deles no mesmo arquivo. Reverter perderia as minhas; manter
sem tratar deixa entradas vazias que o `catalog.check` reprova.

**Decisão:** absorver a dívida inteira — extract completo, merge dos 17 domínios,
tradução dos 20 locales. Nenhum arquivo de código P2P foi tocado (decisão §12.2
intacta); o que entrou foram catálogos, que são arquivos compartilhados e não
têm dono por feature.

**O custo foi bem maior do que eu estimei.** A rodada gerou 1.470 entradas novas
e **354 traduções existentes destruídas** — domínios como `chat`, `group_call`,
`p2p`, `commands` e `lobby` são cheios de strings em fallback inglês com
placeholders, e o tradutor automático varre o arquivo inteiro. Amostra do dano:
`"%{field}: %{errors}"` → `"<ph0>/ph0>: <ph1>/ph1>"`,
`"5:%{seconds}"` → `"৫:২ <f00>"`.

Limpeza em três passos, nesta ordem:

1. **Restaurar as 354** a partir do snapshot pré-merge (comparando `msgstr`
   **e** `msgstr_plural`). Sobrou 0 colateral, 1.470 novas preservadas.
2. **Reparar placeholders** nas 45 entradas novas que os perderam
   (`i18n_repair_placeholder_mismatches.py`) — mas atenção: o reparo devolve o
   **inglês** para recuperar os `%{}`, o que troca `placeholder.check` verde por
   `source-fallback.check` vermelho.
3. **Traduzir essas 45 à mão** (5 strings × 9 locales: ar, bn, de, es, id, it,
   pl, ur, vi). Os outros 11 locales o tradutor acertou.

**Regra revisada:** quando um catálogo fica misturado, a disciplina de escopo não
se aplica — ela pressupõe arquivos separáveis. Mas absorver **não** é barato:
orce o diff semântico + restauração + reparo + tradução manual do resíduo. Se a
dívida alheia for grande, um commit separado de `chore(i18n)` provavelmente sai
melhor do que carregá-la junto.

---

## Erros cometidos (e corrigidos)

### E1 — Troquei uma decisão do usuário por conta própria

Implementei um menu **top-level "Admin"** em vez do submenu que tinha sido
escolhido explicitamente, justificando com economia de infra. Não era uma
decisão minha para tomar. **Revertido**; o submenu foi construído (Passo 0.5).

**Regra daqui pra frente:** decisão registrada em "Decisões travadas" do plano
só muda com aprovação. Economia de esforço não é justificativa.

### E2 — Renomeei um rótulo antes de o conteúdo mudar

Troquei "Admin Console" por "Console" no menu enquanto o item ainda abria o
monólito de 9 abas — rótulo mentindo sobre o que a janela é. **Revertido** para
"Admin Console".

**Regra daqui pra frente:** o rótulo só muda no mesmo passo em que o conteúdo
muda. "Console" só quando a janela for só o REPL (passo 9).

### E5 — Confundi deriva de referência com rewrap

Registrado em detalhe na Fase 3 acima. Em uma linha: revertí um `gettext.merge`
correto e comecei a reescrever a ferramenta porque contei linhas alteradas em vez
de ler cinco delas.

---

## Em aberto (para o usuário decidir)

- **Bot Management continua em Tools**, apesar de ser admin-gated. Movê-lo para
  `File > Admin` deixaria a coisa coerente, mas muda onde um usuário acha uma
  feature existente — fora do "split de código". Não movi.
