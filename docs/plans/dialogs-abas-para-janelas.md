# Diálogos com abas → janelas dedicadas

**Status:** plano aprovado, não iniciado
**Criado:** 2026-07-24
**Progresso:** `docs/plans/dialogs-abas-para-janelas-PROGRESS.md`

---

## 1. Objetivo

Diálogos sobrecarregados de abas escondem features independentes dentro de um
container arbitrário. Este refactor promove essas features a janelas próprias do
desktop, reorganiza as abas que sobraram e remove o código morto encontrado no
caminho.

**Nenhuma capacidade é adicionada ou removida.** Tudo que o usuário consegue
fazer hoje continua possível depois — mudando apenas *onde* mora.

### Invariantes (não negociáveis)

1. **Preservação funcional total.** Cada handler, cada validação, cada mensagem
   de erro migra. Nada é reescrito "de forma equivalente" — é movido.
2. **Todo ponto de entrada continua funcionando.** Item de menu, atalho de
   teclado, slash command, item de context menu, botão de status bar. Se hoje
   `/autojoin` abre a aba Auto-Join, depois ele abre a janela Auto-Join.
3. **Sem gambiarra.** Cada janela nova recebe o conjunto completo de artefatos
   do repo (§8). Nada de "reaproveitar o módulo antigo com uma flag" ou
   "renderizar o painel velho com metade dos attrs".
4. **Nomes semânticos.** Arquivo, módulo, window id, prefixo CSS, testid e
   ícone descrevem a feature — não a origem dela. Nenhum vestígio de "veio da
   aba X do diálogo Y" em nome ou comentário.
5. **`make ci` verde ao fim de cada fase.** 9 checks, sem pular dialyzer, E2E,
   JS ou CSS lint.

---

## 2. O diagnóstico que motiva o trabalho

`components/ui/layout/tabs.ex:110-134` — `tabs_content` **sempre** chama
`render_slot(@inner_block)`. O `initially_hidden` apenas adiciona a classe
`hidden`. Toda aba de todo diálogo é renderizada no servidor e entra no diff a
cada render, visível ou não. A troca de aba é JS puro (`show_tab/2`, :139-147),
então na maioria dos casos o servidor nem sabe qual aba está aberta.

Custo medido:

| Superfície | Custo por abertura |
|---|---|
| Admin Console | ~1.300 linhas de markup — 22 formulários, 12 painéis `<pre>`, o REPL inteiro — para ver uma aba |
| Address Book | 4 sorts recalculados por render (`ContactList`, `NotifyList` com 2 filtros + 2 sorts, `NickColors`, `IgnoreList`). Como `session` é passthrough, reroda **a cada tick de presença** |
| Account | Abrir em "User Modes" (1 checkbox) renderiza Register + Profile + Presence e paga 2 round-trips ao NickServ |

Promover a janela não é cosmético: a janela gerenciada (`@managed`) só monta o
island quando aberta, e desmonta ao fechar.

---

## 3. Inventário e decisão por superfície

| Superfície | Abas hoje | Decisão | Δ janelas |
|---|---|---|---|
| Admin Console | 9 | **Split 1:1** → 9 janelas | +8 |
| Account | 4 | **Split 1:1** → 4 janelas | +3 |
| Address Book | 4 | **Split** → 3 janelas; aba Notify morre na janela `notify-list` existente | +2 |
| Perform | 2 | **Split 1:1** → 2 janelas | +1 |
| Channel Central | 6 | **Reshape** → 4 abas (funde as 3 listas de acesso) ✅ | 0 |
| Bot Management | 5 | **Mantém** (master/detail) + limpeza de código morto | 0 |
| Custom Menus | 3 | **Mantém** (1 editor × 3 alvos, 129 LOC compartilhadas) | 0 |
| `channel_dialog.ex` | 3 | **Deletar** (código morto, só showcase) | 0 |

**Total: 22 → 36 janelas.**

### Fora de escopo (decisão do produto)

- **P2P** — `p2p_session_console.ex`, `lobby_network_panel.ex` (5 abas),
  `p2p_media_island`, `p2p_file_island`, `p2p_game_island`, janela `p2p-call`.
- **Conferência / group call** — `group_call_panel`, janela `group-call`,
  `group_call_events.ex`, diálogos de confirmação de chamada.

Nenhum arquivo dessas duas features é tocado. Onde o menu P2P aparecer numa
refatoração de navegação (Fase 0), os itens são preservados byte a byte.

---

## 4. Mapa de janelas novas

### 4.1 Admin Console → 9 janelas (todas admin-gated)

A janela atual `admin-console-dialog` é aposentada. O sufixo `-dialog` no id é
uma inconsistência (nenhuma outra janela o tem, exceto `bot-management-dialog`);
os ids novos seguem o padrão dominante.

| Window id | Island | Título | Origem (linhas do apresentacional atual) | Peso |
|---|---|---|---|---|
| `admin-users` | `AdminUsersDialog` | Users | `admin_console_dialog.ex:916-1150` + `:1162-1252` | ~570 LOC, 11 forms |
| `admin-channels` | `AdminChannelsDialog` | Channels | `:1275-1460` + `:1475-1589` | ~609 LOC, 11 forms |
| `admin-console` | `AdminConsoleDialog` | Console | `:404-450` | REPL, ~133 LOC handlers |
| `admin-server-settings` | `AdminServerSettingsDialog` | Server Settings | `:732-891` | ~119 LOC |
| `admin-audit-log` | `AdminAuditLogDialog` | Audit Log | `:672-720` | ~49 LOC |
| `admin-motd` | `AdminMotdDialog` | MOTD | `:462-547` | ~67 LOC |
| `admin-turn` | `AdminTurnDialog` | TURN | `:624-661` | read-only |
| `admin-broadcast` | `AdminBroadcastDialog` | Broadcast | `:556-614` | ~59 LOC, write-only |
| `admin-danger-zone` | `AdminDangerZoneDialog` | Danger Zone | `:1602-1674` | ~73 LOC |

Compartilhado que precisa virar módulo próprio, não cópia:
`admin_inline_result/1` (`:1680-1693`, usado por 6 abas) →
`components/ui/dialogs/admin/inline_result.ex`.

**Acoplamentos a preservar explicitamente:**

- `admin-danger-zone` lê `Admin.server_settings_values()["server_name"]`
  (`components/admin_console_dialog.ex:1073-1076`) — o mesmo valor que
  `admin-server-settings` edita. Hoje isso já produz um estado inconsistente:
  o botão desabilitado usa `@danger_zone_server_name` cacheado enquanto o
  handler relê ao vivo. **Preservar o comportamento atual**; registrar como
  bug conhecido, não corrigir neste refactor.
- Dentro de `admin-users`, o campo de busca da lista também filtra a banlist
  (`users_banlist_args/1`, `:785`). Idem em `admin-channels`: o campo do
  formulário *info* determina a banlist (`:629-630, :814-818`). Comportamento
  preservado.
- O REPL (`admin-console`) pode mutar dados que as outras 8 janelas leem, sem
  invalidação. Hoje não há PubSub em nenhuma aba; **não introduzir**.

**Gating:** hoje é *disable-only* no cliente, com `if admin?(socket)` server-side
em cada handler mutante (união admin OR server_operator) e três handlers sem
checagem alguma (`admin_console_tab`, `admin_console_change_nuke_confirm`,
`clear_admin_console`). Cada janela nova replica o gate de abertura
(`admin_console_events.ex:23-33`) **e** o guard de render
(`chat_live.html.heex:793`, defesa contra `window_open` forjado, coberto por
`server_administration_feature_test.exs:1018-1035`). Os dois handlers órfãos
(`change_nuke_confirm`, `clear`) ganham o guard que faltava — é a única correção
de segurança admitida no refactor, e vai documentada.

### 4.2 Account → 4 janelas

O menu File **já lista as 4 como features separadas** (`menu_bar_app.ex:334-364`):
cinco itens que abrem a mesma janela em abas diferentes. O split alinha a
implementação ao modelo que o produto já expõe.

| Window id | Island | Título | Origem | Estado que carrega |
|---|---|---|---|---|
| `account` (mantém) | `AccountDialog` | Account | `account_dialog.ex:114-325` | 9 assigns (auth/ghost/drop) |
| `profile` | `ProfileDialog` | Profile | `:327-400` | 3 assigns |
| `away` | `AwayDialog` | Away | `:402-446` | 0 assigns próprios |
| `user-modes` | `UserModesDialog` | User Modes | `:448-470` | 1 assign |

Register e Identify **continuam juntos** em `account`: são um único formulário
com switch de modo (`auth_mode`), não duas abas.

Resolve de brinde:
- `update({:open, tab, ...})` (`components/account_dialog.ex:61-75`) hoje reseta
  as 4 abas a cada abertura — abrir "Set Away" apaga um rascunho de bio.
- `open_account_modes` (`account_events.ex:48-50`) hoje **não tem chamador**;
  vira o opener legítimo da nova janela, com item de menu.

`sync_identity/1` (2 lookups NickServ) roda hoje em toda abertura, qualquer aba.
Passa a rodar só na abertura de `account` — que é a única que exibe o resultado.

> **Nota registrada:** `user-modes` é uma janela para um único checkbox (`+w`).
> Aceito por consistência com a granularidade 1:1 e por ser onde futuros umodes
> IRC vão morar. Se ao implementar a janela parecer absurda em uso real,
> reabrir a decisão antes de seguir — não improvisar um meio-termo.

> **✅ Executado em 2026-07-25.** As 4 janelas nasceram; `user-modes` foi
> mantida como planejado (a decisão foi reconfirmada antes de começar). O hook
> monolítico virou 4 (`account`/`profile`/`away`/`user_modes`), `sync_identity`
> passou a rodar só na abertura de `account`, e a família de 4 janelas
> compartilha `account.css` com o prefixo `acct-`. Detalhes no PROGRESS.

### 4.3 Address Book → 3 janelas + deduplicação do Notify

A aba Notify duplica a janela `notify-list`: mesmo `NotifyOps`, mesmos nomes de
evento, mesma mensagem de timer, ~176 linhas de markup contra ~290, e formatação
de data divergente. **A janela `notify-list` vence** — ela já tem dois settings
que a aba não tem (`auto_whois`, `auto_add_pm`).

| Window id | Island | Título | Origem | Domínio |
|---|---|---|---|---|
| `address-book` (mantém) | `AddressBookDialog` | Address Book | `address_book.ex:696-743` + `:272-406` | `Accounts.ContactList` |
| `nick-colors` | `NickColorsDialog` | Nick Colors | `:808-847` + `:548-685` | `Accounts.NickColors` |
| `ignore-list` | `IgnoreListDialog` | Ignore List | `:856-904` + `:961-1039` | `Chat.IgnoreList` |
| ~~aba Notify~~ | — | — | **deletada** | absorvida por `notify-list` |

O id `address-book` fica com Contacts: o nome descreve exatamente essa feature, e
preserva geometria salva, taskbar, menu e atalho `Ctrl+Shift+A`.

**Antes de deletar a aba Notify**, migrar para `notify_list.ex` o que só existe
lá: os timestamps com timezone (`format_last_seen`, `address_book.ex:1063-1071`
— `"%d/%m %H:%M"`, `"Never"`, `"—"` quando online) contra o formato atual sem
timezone da standalone (`notify_list.ex:431-440`). O comportamento com timezone
é o superior; a standalone adota ele.

Atalhos: `Ctrl+Shift+A` continua em `address-book`. `Ctrl+Shift+G` (hoje
`AddressBookEvents.open(socket, "control")`) passa a abrir `ignore-list`.

> **✅ Executado em 2026-07-25.** As 4 abas viraram 3 janelas + a dedup: a aba
> Notify morreu e a janela `notify-list` absorveu os timestamps com timezone
> que só a aba tinha. Janelas 34 → 36, fechando o total previsto no §3.
> Detalhes no PROGRESS.

Correção de contrato incluída: os attrs duplicados `@selected_index` e
`@contacts_selected` (`address_book_dialog.ex:470,482`, mesmo valor por dois
caminhos) colapsam em um só no módulo novo.

### 4.4 Perform → 2 janelas

Zero assigns compartilhados. Módulos de domínio distintos, comandos distintos, e
`/autojoin` **já faz deep-link para a aba** (`handlers/autojoin.ex:44` →
`%{tab: "autojoin"}`) — o sintoma clássico de "isto queria ser uma janela".

| Window id | Island | Título | Origem | Domínio |
|---|---|---|---|---|
| `perform` (mantém) | `PerformDialog` | Perform | `perform_dialog.ex:561-661` + `:250-379` | `Chat.PerformList` |
| `autojoin` | `AutojoinDialog` | Auto-Join | `:673-733` + `:385-545` | `Chat.AutoJoinList` |

`/autojoin` sem argumentos passa a retornar `{:ok, :ui_action, :open_autojoin_dialog, %{}}`
e o payload `%{tab: ...}` desaparece junto com o roteamento em
`ui_actions/perform.ex:20-23`. O teste que fixa isso
(`handlers/autojoin_test.exs:83`) é atualizado para a nova asserção.

`Ctrl+Shift+E` continua em `perform`.

> **✅ Executado em 2026-07-25.** As duas janelas nasceram sem shell de abas —
> `open_with` deu lugar a `Windows.open/2` nas duas, porque sem aba não há
> diretiva de abertura. `perform_autojoin_events.ex` virou `perform_events.ex` +
> `autojoin_events.ex`; o ícone `icon_tab_autojoin` foi aposentado em favor do
> par `icon_dialog_autojoin` / `icon_btn_autojoin`. Detalhes no PROGRESS.

---

## 5. Reshape (sem janela nova)

### 5.1 Channel Central: 6 → 4 abas

As 6 abas são legitimamente coesas — todas escopadas ao mesmo canal, todas
derivadas de **um único** `Server.get_state`. A janela fica. O que sai são as
três abas de lista de acesso, que são a mesma superfície com um discriminador:

- `bans`, `ban_exceptions`, `invite_exceptions` → uma aba **Access Lists** com
  seletor de tipo.
- Já compartilham `list_tab/1` (`channel_central_dialog.ex:1204-1289`) e o mesmo
  shape de entrada (`to_list_entry/1`, `:960-961`).
- Os três add-forms (`:590-648`, `:652-710`, `:714-772`) são 83% idênticos —
  10 linhas diferentes em 59 — e colapsam em um, parametrizado pelo tipo.
- Os 3 trios de assigns, os 3 pares open/close, os 3 select, os 3 add/remove e
  os 3 getters derivados (`:926-937`) colapsam em um conjunto + discriminador.

Saldo: 6→4 abas, ~200 linhas a menos, 6 funções de `Channels.Server` continuam
todas acessíveis (`ban/4`, `unban/3`, `add_ban_exception/3`,
`remove_ban_exception/3`, `add_invite_exception/3`, `remove_invite_exception/3`).

O moduledoc diz "5-tab dialog" (`:5-7,24`) e está errado desde a aba
Registration — corrigir para 4.

> **✅ Executado em 2026-07-25.** Saldo real: −198 linhas (apresentacional
> 1343→1223, island 1003→925), 3 add-forms → 1, 3 trios de assigns → 1
> discriminador `list_type`, 6 handlers de add/remove → 2 com tabela de
> despacho. Zero CSS novo (reusou `.cc-segmented-tabs` da aba Registration).
> A receita virou a Parte II do playbook. Detalhes e a única mudança de
> comportamento (trocar de tipo limpa a seleção) no PROGRESS.

**Não** mexer na aba Registration nesta fase. Ela é a maior (269 LOC) e tem
sub-abas SOP/AOP/VOP dentro, mas é ChanServ — outro serviço, outra decisão,
outro ciclo.

---

## 6. Limpeza de código morto

Executada na Fase 1, antes de qualquer migração — reduz a superfície a mover.

| Alvo | Local | Evidência |
|---|---|---|
| `channel_dialog.ex` inteiro | `components/ui/dialogs/channel_dialog.ex` | Único call site é a página de showcase (`showcase_live/dialogs/channel_dialog_page.ex:44`). Subconjunto degradado do Channel Central, com modes hardcoded que nem batem (`+n/+t/+m/+i` vs `+m/+i/+t/+k/+l`) e shape de ban incompatível (`ban.date` vs `entry.set_at`) |
| + rota, nav, icon map, smoke lists | `router.ex:227`, `showcase_helpers.ex:125-126,359`, `test/showcase_smoke_test.exs:63`, `scripts/test_showcase.exs` | |
| `admin_shell_tabs/0` + a comprehension `:for` | `admin_console_dialog.ex:236-245, 1699-1701` | Retorna `~w()`; gerador de placeholders das abas, todas já implementadas |
| `update(%{open: true})`, `update(%{close: true})`, mapa `@reset` | `components/admin_console_dialog.ex:76-88, 99-100` | Nada faz `send_update` neste módulo — `admin_console_events.ex:25` usa `Windows.open/2`, e o próprio moduledoc (`:9-10`) diz que não há open-directive |
| 7 assigns-sombra | `components/admin_console_dialog.ex:68-73` | Cópias byte-a-byte de `users_search`, `users_online_only`, `channels_search`, `channels_info_channel`, `channels_create_name`, `audit_log_last`, `audit_log_user`. Resolvidos naturalmente pelo split |
| Handlers de inline-edit do Bot | `bot_events.ex:261-280`, `:423-487` | `bot_edit_field`, `bot_cancel_edit`, `bot_update_field`, `handle_field_update/4` — nenhum markup emite |
| `bot_update_cap_config` | `bot_events.ex:295-330` | Sem emissor |
| `bot_toggle_channel` + `do_toggle_channel/4` | `bot_events.ex:334-337`, `:523-548` | Sem emissor |
| Attrs mortos do Bot | `bot_management_dialog.ex:25,27,28` | `active_tab`, `editing_field`, `capabilities` declarados e nunca referenciados no template |
| Branch `:reset` do Custom Menus | `components/custom_menus_dialog.ex:144-162` | Sem remetente em todo o repo |

O branch modal não-windowed do Admin Console (`admin_console_dialog.ex:124-152`,
`:if={not @windowed and @show}`) **não** é morto — é o que a página de showcase
usa. Ele desaparece junto com o monólito quando as 9 janelas nascerem, e cada
página de showcase nova usa a variante framed própria (§8, item 1).

---

## 7. Fase 0 — infra de navegação (BLOQUEANTE)

Sem isto, trocamos diálogo sobrecarregado por menu sobrecarregado. Nenhuma
janela nova entra antes desta fase fechar.

### 7.1 O que existe

- `menu_bar/1` + `menu/1` (`components/ui/shell/menu_bar.ex:36-88`), contrato
  plano documentado: `[data-menubar-trigger]` e `[data-menubar-dropdown]` como
  irmãos sob um wrapper.
- `MenuBarHook` (`assets/js/hooks/ui/menu_bar_hook.js`, 189 linhas): abre em
  `mousedown` com `preventDefault()` deliberado (não roubar foco do input de
  chat), hot-tracking em hover, click-outside, Escape, evento
  `menubar:close-all`, e a troca de tab-panel do mobile.
- **`context_menu_label/1`** (`components/ui/layout/context_menu.ex:152-163`) —
  cabeçalho de grupo para dropdowns do menu bar **já existe** e já é usado duas
  vezes (`menu_bar_app.ex:334, 621`).
- As funções `*_menu_items/1` são consumidas pelo strip desktop **e** pelos
  tab-panels mobile — escrever uma vez cobre os dois.
- Mobile: `.app-mobile-menu__content` já tem `overflow-y: auto`
  (`app-menu.css:162`). Task switcher mobile já rola
  (`max-height: min(62vh, 420px)`, `window-manager.css:388-395`).

### 7.2 O que precisa ser construído

1. **Componente de submenu.** Não existe nada — grep por
   `submenu|sub-menu|flyout|nested menu` em `apps/` retorna zero. Precisa
   renderizar como um único `<li>` (as `*_menu_items/1` devolvem sequência de
   `<li>` irmãos, sem `<ul>` envolvente) contendo trigger + painel próprios.
2. **Atributo de dados distinto de `data-menubar-dropdown`.** `_closeAll()`
   (`menu_bar_hook.js:107`) faz `querySelectorAll` global e `_openMenu` faz
   `querySelector` descendente (`:94`) — reusar o atributo quebra os dois.
3. **Exceção no handler de click.** `menu_bar_hook.js:71` fecha tudo ao clicar
   em qualquer `<li>` dentro de um dropdown; o `<li>` pai de um submenu precisa
   ser isento. O padrão de isenção já existe duas vezes no arquivo
   (`:47-54` para `[data-mobile-menu-category]`, `:56-69` para copy-selection).
4. **Representação mobile do submenu.** O shell mobile é um grid fixo de duas
   colunas com `overflow: hidden` no dropdown externo (`app-menu.css:79`) e
   `overflow-y: auto` no painel de conteúdo (`:162`). Um flyout absoluto será
   clipado. Solução: expansão inline (accordion) dentro do painel — **não** uma
   terceira coluna, que não cabe no `grid-template-columns` de
   `minmax(112px, .4fr) minmax(0, 1fr)`.
5. **Cabeçalho de grupo no start menu.** Não existe. `start_menu/1`
   (`desktop.ex:412-430`) é um `<div>` de `<button>`s, então
   `context_menu_label/1` (um `<li>`) não serve. Precisa de
   `start_menu_group/1`.
6. **Scroll e teto de altura no start menu.** `desktop.ex:420-422` tem `w-56`
   fixo, **sem** `max-height` e **sem** `overflow`. Indo de 25 para ~39 itens,
   o menu cresce para cima e é clipado pelo topo da viewport sem rolar.
7. **Taskbar.** Desktop hoje só tem `overflow-x-auto` com botões
   `max-w-[12ch] truncate` (`desktop.ex:267,353,362`). 36 janelas ≈ 4.000px de
   scroll horizontal. Mobile já rola, mas 36 × 38px = 1.368px num painel de
   420px. Decidir e implementar um agrupamento — o mínimo aceitável é agrupar
   as 9 janelas admin sob uma entrada.

### 7.3 Estrutura de menu alvo

- **Tools** vira submenus temáticos, drenando os 12 itens atuais + os novos.
- **File → Admin** vira submenu com as 9 janelas admin. ✅ feito — nas três
  superfícies (menu bar, start menu, toolbar).
- **Start menu** ganha cabeçalhos de grupo nas divisões que hoje são só
  comentários HEEx (`start_menu_app.ex:35, 85-86, 108, 158, 175`) e separadores.
- Menus **P2P** e **Games** ficam intocados.

### 7.4 Riscos conhecidos da Fase 0

- **Navegação por teclado não existe hoje** no menu bar — só Escape. Sem
  arrow keys, sem roving tabindex, sem `role="menuitem"`, sem
  `aria-haspopup`. O submenu **não** introduz navegação por teclado: fora de
  escopo, registrado como débito. Se introduzir, entra em conflito com o
  `preventDefault()` de `menu_bar_hook.js:20`.
- `menu_bar_hook.test.js` tem 5 blocos `describe` fixando o comportamento
  plano, incluindo "closes on dropdown item click" (`:119`). Serão estendidos,
  não afrouxados.
- 10 testes Elixir chamam `render_component(&MenuBarApp.menu_bar_app/1, ...)` e
  asseguram markup de menu.
- `showcase_live/layout/menu_page.html.heex:181-253` é uma **réplica copiada à
  mão do dropdown Tools**. Vai divergir; atualizar junto.
- Z-index: dropdown é `z-dropdown` (100), taskbar e start menu são
  `z-floating` (150), context menu é 300. Um flyout do start menu precisa ficar
  ≥150 e <300.

---

## 8. Contrato de "adicionar uma janela"

Cada uma das 15 janelas novas cumpre **todos** os pontos. Não há item opcional
por conveniência — só os marcados *(condicional)*, que dependem da feature ter
atalho/comando.

**Design system**
1. `components/ui/dialogs/<x>.ex` — módulo `RetroHexChatWeb.Components.UI.<X>Dialog`
   (sem segmento `Dialogs`), `use RetroHexChatWeb.Component`. Exporta **as duas**
   variantes: `<x>_dialog/1` (framed, só showcase, `sub_scope={:viewport}`) e
   `<x>_panel/1` (bare, usada pelo island, `sub_scope` default `:window`). Raiz
   obrigatória: `<div id={"#{@id}-panel-root"} class="contents">` →
   `<.focus_wrap class="contents">` → `<div id={"#{@id}-content"}
   data-testid="<x>-panel" role="dialog" aria-modal="false" tabindex="0">`.
   `@spec` em toda função pública. Labels via `dgettext("dialogs", ...)`.
   `phx-target={@target}` em todo form e primitivo aninhado.

**Runtime**
2. `live/chat_live/components/<x>_dialog.ex` — `RetroHexChatWeb.ChatLive.Components.<X>Dialog`,
   `use RetroHexChatWeb, :live_component`. `@id`/`id/0` públicos (id =
   `"<window-id>-dialog"`). Mapa `@initial`/`@closed` quando houver diretiva de
   abertura. Cláusulas `update/2` específicas primeiro, passthrough por último.
   **Carga inicial no `mount/1` do island**, nunca via `send_update` pós-mount
   (AGENT-GUIDE §7.1:487-493 — o diff funde na árvore virtual e nunca patcheia
   o DOM; ExUnit passa, só E2E pega).
3. `live/chat_live/<x>_events.ex` — hook com catch-all
   `handle_event(_, _, socket), do: {:cont, socket}` obrigatório no fim.
4. Tupla em `attach_all_hooks/1` (`live/app/chat_live.ex:631-670`).
5. Cláusulas `handle_info` no host, acima do catch-all, uma por mensagem
   `send(self(), ...)` que o island emite.

**Janela**
6. Id no `@managed` de `live/chat_live/windows.ex:34-36`, em ordem alfabética.
7. Bloco `<.desktop_window :if={"<id>" in @open_windows} ...>` em
   `live/app/chat_live.html.heex`, com `:icon`, geometria, `body_class` e
   `data-testid="<id>-window"`.
8. Entrada em `taskbar_windows/1` (`components/ui/chat/chat_taskbar.ex:103-224`)
   via `add_window/5`, com o ícone como **átomo**.

**Entradas**
9. Item no menu bar (`menu_bar_app.ex`), no toolbar (`toolbar_app.ex`) e no
   start menu (`start_menu_app.ex`) — **três arquivos distintos**, os testes de
   entry-points cobram os três.
10. *(condicional)* Atalho: `chat/key_bindings.ex` (dois mapas: `@default_bindings`
    **e** `@action_metadata`) + `keyboard_events.ex` + assert em
    `key_bindings_test.exs`.
11. *(condicional)* Slash command: `commands/handlers/<x>.ex` +
    `commands/registry.ex` + `live/chat_live/ui_actions/<x>.ex` +
    lista `@*_actions` em `ui_action_handlers.ex`.

**Ícones**
12. **Dois ícones, dois nomes, dois arquivos.** `icon_dialog_<x>` (barra de
    título + taskbar) e `icon_btn_<x>` (menu/toolbar/start menu). Submódulo
    escolhido pelo *que o ícone representa*. Mais `defdelegate` em
    `components/icons.ex` — esquecer isso quebra o `apply(Icons, ...)` dinâmico
    da taskbar **em runtime, não em compile** — mais linha em
    `docs/reference/svg-catalog.md`.

**CSS**
13. `assets/css/retrohex/dialogs/<x>.css` com prefixo de classe de duas letras,
    mais `@import` em `assets/css/retrohex.css` (não é auto-globbed). Sem
    `style=`, sem hex em Elixir, sem `defp *_style` — `mix audit.styles --strict`
    reprova. Toda classe `.<pfx>-*` definida precisa aparecer num template e
    vice-versa (`mix lint.css_consistency`).

**Ajuda (obrigatório por CLAUDE.md)**
14. Tópico em `chat/help_topics/<categoria>.ex` (campos `id, title, category,
    keywords, icon, description`; `category` tem que ser uma das 26 strings de
    `@categories` ou `topics_by_category/0` levanta) + corpo em
    `controllers/help_content/<id>.html.heex` + **registro no glob
    `embed_templates`** do módulo `HelpContent` correspondente (sem isso,
    `ArgumentError` ao abrir o tópico) + See Also recíproco nos tópicos
    relacionados.

**i18n**
15. Domínios afetados: `dialogs` (labels do painel), `chat` (título da janela,
    label da taskbar), `ui` (menu/start menu), `showcase`, `help_features`
    (corpo) e `help` (metadados, app de domínio). 21 locales — as 20 não-inglesas
    **não podem** ficar vazias/fuzzy/em inglês, `make i18n.catalog.check`
    reprova. Fluxo cirúrgico obrigatório (AGENT-GUIDE:837-841):
    `make i18n.gettext.extract` → `make i18n.gettext.merge DOMAINS=<d> APP=web`
    → `make i18n.catalog.check` → `make i18n.gettext.check`; commitar só os
    `.pot`/`.po` dos domínios tocados e reverter a churn incidental. **Nunca**
    `make i18n.gettext.rebuild`.

**Showcase (6 arquivos, todos manuais)**
16. `live/showcase_live/dialogs/<x>_page.ex` (usa a variante framed) + rota em
    `router.ex` + entrada de nav em `showcase_helpers.ex` + **`@nav_icon_map`**
    no mesmo arquivo + `scripts/test_showcase.exs` + `test/showcase_smoke_test.exs`
    (duas listas separadas).

**Testes**
17. Teste unitário do island em
    `test/.../live/chat_live/components/<x>_dialog_test.exs` (id estável,
    `data-testid="<x>-panel"` sem chrome de dialog, sub-forms ausentes até a
    flag, `phx-target` presente).
18. `test/.../live/<x>_entry_points_feature_test.exs` — menu + toolbar via
    `render_component`, abertura via `render_click(view, "toolbar_action", ...)`,
    `assert_push_event(view, "window_command", %{action: "open", id: "<x>"})`,
    e `render_hook(view, "window_closed", ...)` desmontando o island.
19. E2E: locators em `e2e/pages/ChatPage.ts` (4 pontos de inserção) + spec em
    `e2e/tests/` + **linha em `e2e/TEST_CATALOG.md` com os contadores do
    cabeçalho atualizados**.

---

## 9. Fases

Cada fase termina com `make ci` verde e um commit. A ordem é por risco
crescente; a Fase 3 valida o playbook no menor split possível antes de escalar.

> **A ordem mudou na execução.** O Admin Console foi promovido a primeiro caso
> por ser o mais complexo — é dele que saiu o playbook
> (`dialogs-abas-para-janelas-PLAYBOOK.md`). O estado real está em
> `dialogs-abas-para-janelas-PROGRESS.md`.

| # | Fase | Conteúdo | Janelas novas | Status |
|---|---|---|---|---|
| 0 | **Infra de navegação** | Submenu (componente + JS + mobile) | 0 | ✅ feito |
| 0b | **Resto da infra de navegação** | Grupos e scroll no start menu ✅ · agrupamento na taskbar ✅ | 0 | ✅ feito |
| 1 | **Admin Console** | 9 janelas; monólito deletado | +8 | ✅ feito |
| 2 | **Limpeza** | Tudo em §6, menos o que saiu junto com o Admin | 0 | ✅ feito |
| 3 | **Channel Central** | 6 → 4 abas, funde as 3 listas de acesso | 0 | ✅ feito |
| 4 | **Perform** | `perform` + `autojoin` | +1 | ✅ feito |
| 5 | **Account** | `account` + `profile` + `away` + `user-modes` | +3 | ✅ feito |
| 6 | **Address Book** | `address-book` + `nick-colors` + `ignore-list`; aba Notify absorvida por `notify-list` | +2 | ✅ feito |

**Fase 0b: concluída em 2026-07-26**, fechando o plano. O start menu ganhou
grupos (`start_menu_submenu/1`) e teto de altura com scroll; a taskbar ganhou
`taskbar_group/1`, que colapsa uma família de janelas numa entrada só —
**apenas quando 2+ da família estão abertas**, porque agrupar uma janela
solitária custaria um clique e não esconderia nada.

Famílias: admin (9), account (4), contacts (4, incluindo `notify-list`) e
on-connect (2). O grupo assume a posição do primeiro membro, então os botões não
saltam de lugar quando uma janela irmã abre.

~~**Fase 6 é a maior por larga margem** — 9 janelas × 19 pontos do contrato.~~
**Nota obsoleta:** escrita quando o Admin Console *era* a fase 6. Ele foi
promovido a primeiro caso e concluído na Fase 1; este parágrafo descrevia
trabalho já feito e não se aplica à Fase 6 atual (Address Book).

---

## 10. Como provamos que nada quebrou

Para cada feature movida, três provas:

1. **O teste E2E que a cobria continua passando**, com os locators reescritos
   para a janela nova e as **mesmas asserções de comportamento**. Se uma
   asserção precisa mudar de significado (não só de seletor), é sinal de que a
   feature mudou — parar e investigar.
2. **O teste LiveView de feature idem.** Os arquivos com um `describe` por aba
   (`server_administration_feature_test.exs`, 1.099 linhas, 9 blocos;
   `channel_central_feature_test.exs`, 671 linhas; `address_book_test.exs` +
   `address_book_feature_test.exs` com o helper `ab_tab/2` em ~40 call sites)
   viram um arquivo por janela, preservando as asserções.
3. **Todo ponto de entrada testado explicitamente.** O teste de entry-points
   (§8.18) é obrigatório por janela nova e cobre menu + toolbar + abertura +
   fechamento. Atalhos e slash commands ganham assert próprio.

Ponto de atenção: o helper de troca de aba é usado por dezenas de call sites em
cada arquivo (`switchAddressBookToTab` em `ChatPage.ts:1492-1496` tipa os labels
**visíveis**; `switchAdminConsoleToTab` em `:1283-1288`; `cc/3` em
`channel_central_feature_test.exs:639`). Reescrever esses helpers é a maior
parte do trabalho de teste — orçar.

---

## 11. Riscos

| Risco | Impacto | Mitigação |
|---|---|---|
| **Mobile perde o trânsito entre abas.** Em stacked (<768px) o WM mostra uma janela por vez (`window_manager_hook.js:1104-1110`); trocar de aba dentro da janela vira ida ao task switcher | Regressão de UX real | Cada janela nascida de um split carrega links para as irmãs no rodapé, preservando o trânsito que a aba dava de graça. Obrigatório, não opcional |
| **Janelas triviais.** `admin-broadcast` (59 LOC markup, 25 de handler, zero leitura) e `user-modes` (1 checkbox) recebem o aparato completo de 19 pontos | Custo desproporcional | Aceito por decisão de granularidade 1:1. Revisitar se em uso a janela parecer absurda — reabrir a decisão, não improvisar |
| **Fase 0 é infra pura sem entrega visível** e é bloqueante | Pode ser pulada sob pressão | Nenhuma janela nova entra antes dela. Regra dura |
| **44 arquivos de catálogo por lote de strings** (`ui` × 22, `chat` × 22), mais `dialogs`/`help_*` | Churn enorme, `make i18n.catalog.check` reprova | Fluxo cirúrgico do §8.15. Traduzir de verdade, nunca deixar seed em inglês |
| ~~**Taskbar em 36 botões** sem agrupamento~~ | ~4.000px de scroll horizontal | **Resolvido na 0b** (2026-07-26): 4 famílias colapsam em uma entrada cada a partir de 2 janelas abertas |
| **Réplica manual do Tools no showcase** (`menu_page.html.heex:181-253`) | Divergência silenciosa | Atualizar na mesma fase; não há check automático |
| **Geometria salva em localStorage** (`rhc:desktop:*`) fica órfã para os ids aposentados | Usuário perde posição de janela | Aceito, sem migração |
| **Estado inconsistente Danger Zone ↔ Server Settings** existe hoje e sobrevive ao split | Bug preservado | Documentado como bug conhecido; corrigir fora deste refactor |

---

## 12. Decisões travadas

Não reabrir sem motivo novo:

1. Escopo é split + reshape + limpeza de código morto.
2. **P2P e conferência não são tocados.** Isso exclui o `lobby_network_panel`
   (5 abas) e todo o `p2p_session_console`.
3. Admin Console vai a **9 janelas, uma por aba**.
4. Address Book vira 3 janelas; a **janela `notify-list` absorve** a aba Notify
   e a duplicata morre.
5. Navegação: **submenus no Tools + grupos no start menu**, como Fase 0
   bloqueante.
6. Channel Central mantém a janela; só funde as 3 listas de acesso. A aba
   Registration não é tocada.
7. Bot Management e Custom Menus mantêm as abas.
