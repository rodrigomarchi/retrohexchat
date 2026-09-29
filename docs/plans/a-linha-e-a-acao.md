# A linha é a ação

Hoje, em toda lista deste inventário, a pessoa clica numa linha e **nada
acontece**. A linha fica azul. A ação de verdade mora num botão no rodapé do
diálogo, que até aquele clique estava cinza. São três gestos — ler, selecionar, atravessar o diálogo —
para uma intenção só: *entrar neste canal*, *editar este alias*.

É a lista do Win98/mIRC transcrita literalmente: lista em cima, barra de botões
embaixo. Em 1998 ela funcionava porque tinha **duplo clique** como atalho. Aqui o
duplo clique não existe, e o próprio repositório já escreveu o porquê:

> *"Ir para um canal em que você não está é entrar nele. Isso foi duplo clique
> por um tempo, ao lado de um clique simples que só trocava — dois gestos para
> uma intenção, e o duplo clique não tinha equivalente que um dedo pudesse
> executar."* — `live/chat_live/core_events.ex:85-87`

Ou seja: o produto **já decidiu o contrário** na árvore lateral. Clicar num canal
em que você não está entra nele. O Channel List é a mesma intenção, na mesma
tela, com dois gestos a mais. Este plano estende a decisão que já foi tomada
para os lugares onde ela ainda não chegou.

Este documento descreve trabalho em aberto. Quando cada fase shippar, apagar a
seção correspondente. Quando a última shippar, mover as regras duráveis para
`docs/AGENT-GUIDE.md` §9/§11 e apagar o arquivo.

---

## Decisões travadas

Não reabrir. Cada uma existe porque a alternativa já foi considerada e descartada.

1. **A linha é a ação primária.** Um clique na linha faz o que a pessoa foi ali
   fazer: entrar no canal, abrir o registro para edição. Não existe mais "clicar
   para selecionar e depois procurar o botão".
2. **A ação secundária mora na própria linha**, não no rodapé. `Remove`, `Stop`,
   `Up`, `Down` viram controles da linha a que pertencem. Um botão que age sobre
   "o item selecionado" é um botão sem sujeito.
3. **`Add` continua no rodapé.** Ele não age sobre nenhuma linha — não tem onde
   morar dentro da lista. Manter fora é o certo, não uma inconsistência.
4. **O painel de edição em duas colunas fica** (`AGENT-GUIDE` §11, paridade
   mIRC). O que muda é o gesto que o abre: o clique na linha, não o clique na
   linha *mais* o botão `Edit`. A seleção visual continua existindo nesses
   diálogos — ela agora significa "é este que o formulário ao lado está
   editando", que é um estado real, e não "o botão lá embaixo acordou".
5. **Este plano não adiciona nem remove nenhuma confirmação destrutiva.** O que
   hoje passa por `confirm_dialog` continua passando; o que não passa, não passa.
   Mudar isso é outra conversa e entra em outro plano.
6. **Nenhuma ação fica atrás de hover.** Toque não tem hover
   (`docs/guide/mobile-touch.md`). Controle de linha é sempre visível.
7. **Um componente, não uma correção por diálogo.** Corrigir um a um sem o
   componente compartilhado reintroduz a divergência que criou o problema — hoje
   `row_class/2` está copiado em `perform_dialog`, `custom_menus_dialog`,
   `nick_colors_dialog`, `address_book`, `ignore_list_dialog` e `autojoin_dialog`,
   e cada CSS de diálogo redesenhou a sua própria barra de ação.

## Regras que valem para todas as fases

1. **TDD** (`AGENT-GUIDE` §1.4). Teste de componente antes do componente; teste
   de LiveView antes de mexer no evento.
2. **Nunca assertar em `send_update`/stream assíncrono.** Estado síncrono
   (`:sys.get_state`), unidade de componente, ou dado persistido
   (`docs/guide/testing.md`).
3. **Uma asserção de ausência só vale se você a viu ficar vermelha.**
4. **`@spec` em toda função pública.** Alias na primeira escrita.
5. **Zero cor em Elixir/JS**; `make lint.css` com 0 LOW / 0 MEDIUM / 0 HIGH.
6. **Classe CSS que deixou de ser referenciada tem que ser apagada do `.css`**,
   nunca escondida no allowlist do `mix lint.css_consistency`. Toda fase que
   remove uma `*-action-row` remove as regras dela no mesmo commit.
7. **i18n pelo pipeline**: `make i18n.gettext.extract` e
   `make i18n.gettext.merge DOMAINS=dialogs APP=web`. Rótulo curto de botão vai
   para `scripts/i18n/glossary.py`, não para a máquina traduzir.
8. **Validação direcionada durante a fase, `make ci` completo no fim do bloco.**
   E2E por batch (`make e2e.batch BATCH=…`), nunca a suíte inteira num comando.

---

## Fase 0 — o componente único

**Sem isto, nada mais começa.** As fases seguintes são adoção; esta é a única que
projeta.

### O que se cria

| Arquivo | Papel |
|---|---|
| `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/layout/action_list.ex` | o componente |
| `apps/retro_hex_chat_web/assets/css/retrohex/components/action-list.css` | o desenho, importado no `retrohex.css` |
| `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/showcase_live/layout/action_list_page.ex` | a página de showcase |
| `apps/retro_hex_chat_web/lib/retro_hex_chat_web/showcase_catalog.ex` | uma entrada, ao lado de `list-states` |
| `apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/layout/action_list_test.exs` | teste de componente |

Vizinho de `UI.ListStates` (`components/ui/layout/list_states.ex`), que já resolve
vazio / carregando / fim / erro. O `ActionList` **compõe** com ele, não o
reimplementa: a lista vazia continua sendo `list_empty_state/1`.

### A forma

```
<.action_list id="channel-list" label={dgettext("dialogs", "Channels")}>
  <.action_row
    :for={ch <- @channels}
    id={"channel-list-row-#{ch.name}"}
    on_activate={@on_join}
    value={%{"channel" => ch.name}}
    current={@editing == ch.name}
  >
    <:title>{ch.name}</:title>
    <:meta>{ch.topic}</:meta>
    <:action
      event={@on_remove}
      value={%{"channel" => ch.name}}
      label={dgettext("dialogs", "Remove")}
      icon={:icon_btn_remove}
      variant="destructive"
    />
  </.action_row>
</.action_list>
```

### A armadilha estrutural

**Um `<button>` não pode conter outro `<button>`.** Hoje a linha inteira *é* um
`<button>` (`channel_list.ex:83`, `autojoin_dialog.ex:128`,
`custom_menus_dialog.ex:262`, `perform_dialog.ex:145`). Pendurar um botão de
`Remove` dentro dela produz HTML inválido e comportamento indefinido de clique.

A linha passa a ser um `<li>` com dois filhos irmãos:

- `.action-list__primary` — um `<button>` que ocupa a largura restante e carrega
  o `on_activate`;
- `.action-list__actions` — os controles de linha, irmãos do primário.

O alvo de toque do primário continua sendo praticamente a linha inteira; o que
muda é que ele para antes dos controles, em vez de contê-los.

### Contrato

- **`on_activate` é obrigatório.** Uma linha sem ação primária não é uma
  `action_row` — é uma linha de tabela, e para isso existe `UI.Table`.
- **`current`** (não `selected`) marca a linha que o formulário ao lado está
  editando. Renderiza `aria-current="true"`. O `aria-pressed` de hoje sai: ele
  dizia "este botão está apertado", que deixa de ser verdade quando o clique
  dispara uma ação em vez de alternar um estado.
- **`<:action>` é repetível e sempre visível.** `label` obrigatório — vira
  `aria-label`, porque o controle é só ícone.
- **Sem estado interno.** O chamador continua dono de tudo, como
  `UI.ListStates` e `UI.Table`.
- **`row_class/2` morre.** As cópias privadas somem; a classe de seleção
  passa a ser do componente.

### Como se prova

Teste de componente (`:unit`), sem LiveView:

- uma linha sem `<:action>` renderiza exatamente um `<button>`;
- uma linha com dois `<:action>` renderiza três botões **irmãos**, nenhum
  aninhado (assertar sobre o HTML, é o ponto da fase);
- `current` emite `aria-current` e não emite `aria-pressed`;
- `<:action>` sem `label` levanta em tempo de compilação;
- lista vazia delega para `list_empty_state/1`.

### O que fecha a fase junto

- **`docs/AGENT-GUIDE.md` §11** manda hoje, textualmente: *"two-panel list +
  inline edit form; … grayed disabled states for unavailable actions"*. É a regra
  que produziu o problema. Reescrever para: o painel de duas colunas fica, a ação
  primária mora na linha, e cinza-desabilitado vale para ação indisponível por
  **permissão ou estado**, nunca por falta de seleção.
- **Help `ui-listings`** (`help_topics/user_interface.ex:579`) descreve a tabela
  compartilhada. Ganha a frase que a pessoa consegue agir: a linha é a ação.
  `ui-lists` e `ui-conversations` ganham `see_also` para ele.
- **`components/ui/shell/config_form.ex:85-107`** é o molde genérico dessa forma
  errada e **não tem nenhum consumidor real** — só o showcase. Ou adota o
  `ActionList`, ou é apagado junto com `showcase_live/shell/config_form_page.ex`.
  Decidir na Fase 0, porque enquanto existir alguém copia dele.

---

## Fase 1 — Channel List (a porta)

O caso do print, e o mais grave: é a porta de entrada de uma sala.

| Arquivo | O que muda |
|---|---|
| `components/ui/dialogs/channel_list.ex:83-160` | linha vira `action_row`; rodapé `cl-action-row` some |
| `live/chat_live/channel_list_events.ex:72` | `channel_list_select` deixa de existir |
| `live/chat_live/components/channel_list_dialog.ex` | assign `selected_channel` some |
| `assets/css/retrohex/dialogs/channel-list.css:66-233` | `.cl-channel-entry*`, `.cl-action-row` |
| `live/showcase_live/dialogs/channel_list_page.ex` | idem |
| `test/.../components/ui/dialogs/channel_list_rows_test.exs` | reescrever |
| `test/.../live/channel_list_dialog_test.exs` | reescrever |
| `test/.../live/chat_live/components/channel_list_dialog_test.exs` | reescrever |
| `test/.../live/channel_membership_feature_test.exs` | reescrever |
| `e2e/tests/chat-channel-list.spec.ts` | reescrever |
| `e2e/pages/ChatPage.ts` | locators |

**Ganho de projeto, não só de gesto:** hoje `request_access?/2`
(`channel_list.ex:161-171`) decide *Join* vs *Request Access* olhando **a linha
selecionada**, e o rótulo do botão de rodapé troca embaixo do dedo. Com a ação na
linha, cada linha já sabe se é `+i` e se você está dentro — o rótulo é uma
propriedade da linha e para de piscar. O helper privado some.

Manter os `data-testid` de linha (`channel-list-row-#{name}`); trocar
`channel-list-join` por um testid por linha.

## Fase 2 — Channel Central (duas listas numa janela)

| Arquivo | O que muda |
|---|---|
| `components/ui/dialogs/channel_central_dialog.ex:1120-1185` | Access Lists: `Remove` vai para a linha |
| `components/ui/dialogs/channel_central_dialog.ex:470-554` | Registration/ChanServ: idem |
| `live/chat_live/components/channel_central_dialog.ex:230,302` | `cc_cs_access_select`, `cc_list_select` |
| `assets/css/retrohex/dialogs/channel-central.css` | classes de linha e de barra |
| `live/showcase_live/dialogs/channel_central_dialog_page.{ex,html.heex}` | |
| `test/.../live/channel_central_feature_test.exs` | |
| `test/.../live/chanserv_channel_central_feature_test.exs` | |
| `e2e/tests/chat-channel-central{,-exceptions,-sync}.spec.ts` | |

Aqui as duas listas são **só destrutivas** — não há ação primária natural. A linha
ativa abre o detalhe da entrada (quem adicionou, quando); `Remove` é `<:action>`.
O gate `:if={@operator}` continua valendo por linha.

## Fase 3 — editores lista + formulário

Mesma mecânica em todos: clique na linha **abre o formulário de edição ao lado**
(era clique + `Edit`), `Remove` vai para a linha, `Add` fica no rodapé. São
independentes entre si — podem ir num commit cada, ou em dois lotes.

| Diálogo | Componente | Eventos | CSS | Showcase | E2E |
|---|---|---|---|---|---|
| Address Book | `dialogs/address_book.ex:297` | `contact_select` | `address-book.css` | `address_book_page.ex` | `chat-address-book*.spec.ts` (4) |
| Alias | `dialogs/alias_dialog.ex:164` | `alias_select` | `alias.css` | `alias_dialog_page.ex` | `chat-alias*.spec.ts` (3) |
| Auto-Join | `dialogs/autojoin_dialog.ex:145` | `autojoin_select` | `autojoin.css` | `autojoin_dialog_page.{ex,html.heex}` | `chat-autojoin*.spec.ts` (2) |
| Auto-Respond | `dialogs/auto_respond_dialog.ex:180` | `autorespond_select` | `auto-respond.css` | `auto_respond_dialog_page.ex` | `chat-autorespond*.spec.ts` (3) |
| Highlight Words | `dialogs/highlight_dialog.ex:175` | `highlight_select` | `highlight-words.css` | `highlight_dialog_page.ex` | `chat-highlights*.spec.ts` (2) |
| Ignore List | `dialogs/ignore_list_dialog.ex:58` | `control_select` | `address-book.css` (`ab-*`) | `ignore_list_page.ex` | `chat-ignore*.spec.ts` (2) |
| Nick Colors | `dialogs/nick_colors_dialog.ex:280` | `nick_color_select` | `address-book.css` (`ab-*`) | `nick_colors_page.ex` | — |
| Notify List | `dialogs/notify_list.ex:179` | `notify_select` | `notify-list.css` | `notify_list_page.ex` | `chat-notify*.spec.ts` (2) |

**Duas coisas que essa tabela esconde e que derrubam a fase se passarem batido:**

- **Ignore List, Nick Colors e Address Book compartilham o prefixo `ab-`.**
  Apagar `.ab-action-row` numa fase quebra o desenho das outras duas. Ou migram
  juntos, ou o CSS compartilhado é a última coisa a sair.
- **Nick Colors não tem spec Playwright.** Só cobertura Elixir
  (`nick_colors_test.exs`, `nick_colors_feature_test.exs`). Migrar sem spec é
  migrar no escuro num diálogo que abre dois sub-modais — escrever a spec **antes**
  de mexer, e vê-la passar no código atual.

Testes Elixir por diálogo: `address_book_test.exs`, `address_book_feature_test.exs`,
`chat_live/components/address_book_dialog_test.exs`, `autojoin_feature_test.exs`,
`chat_live/components/autojoin_dialog_test.exs`, `chat_live/components/alias_dialog_test.exs`,
`chat_live/components/highlight_dialog_test.exs`, `chat_live/components/ignore_list_dialog_test.exs`,
`ignore_list_test.exs`, `ignore_list_feature_test.exs`, `nick_colors_test.exs`,
`nick_colors_feature_test.exs`, `chat_live/components/nick_colors_dialog_test.exs`,
`notify_list_test.exs`, `notify_list_feature_test.exs`,
`notify_list_entry_points_feature_test.exs`, `chat_live/components/notify_list_dialog_test.exs`.

## Fase 4 — os três com ação além de editar

Por último porque cada um tem uma pergunta própria.

| Diálogo | Ação extra | Pergunta a resolver |
|---|---|---|
| **Perform** `dialogs/perform_dialog.ex:165` | `Up` / `Down` | reordenar é a sequência mais cara do repo hoje: selecionar, atravessar, subir, atravessar de volta. Setas na linha resolvem; se for arrastar, é hook JS e vira plano próprio. **Setas na linha.** |
| **Timers** `dialogs/timers_dialog.ex:111` | `Stop` | `Stop` é destrutivo e a linha carrega estado (ativo/parado). Vira `<:action>` visível só em linha ativa — `:if`, não cinza (§11). **Sem página de showcase hoje** — criar, é a única do grupo que falta. |
| **Custom Menus** `dialogs/custom_menus_dialog.ex:281` | — | só Edit/Remove, mas as linhas carregam `data-menu-type`/`data-menu-label` consumidos por teste. Preservar. |

Arquivos: `live/chat_live/components/{perform,timers,custom_menus}_dialog.ex`;
`assets/css/retrohex/dialogs/{perform,timers,custom-menus}.css`;
`live/showcase_live/dialogs/{perform_dialog_page.{ex,html.heex},custom_menus_dialog_page.ex}`;
testes `perform_feature_test.exs`, `chat_live/components/perform_dialog_test.exs`,
`timers_dialog_feature_test.exs`, `chat_live/components/timers_dialog_test.exs`,
`chat_live/components/custom_menus_dialog_test.exs`;
specs `chat-perform*.spec.ts` (3), `chat-timer*.spec.ts` (3),
`chat-custom-menus*.spec.ts` (2).

## Fase 5 — fechar

- `mix lint.css_consistency` sem nenhuma entrada nova no allowlist. Se apareceu,
  é regra CSS órfã que ficou para trás.
- `make i18n.gettext.extract` + `merge DOMAINS=dialogs APP=web`. Os `Edit` de
  rodapé que sumiram deixam msgid órfão; os `aria-label` por linha
  (`"Remove %{name}"`) são msgid novo e **têm placeholder** — auditar contra
  snapshot antes de escrever em lote.
- `e2e/TEST_CATALOG.md` atualizado se alguma spec mudou de `@section`.
- Regras duráveis migram para `AGENT-GUIDE` §9 e §11; este arquivo é apagado.
- `make ci` completo (`make ci > log 2>&1; echo $?` — pipe mascara exit code),
  depois `make e2e.prepare` e as batches tocadas.

---

## O que já está certo (não mexer)

Contraprovas do próprio repositório — o alvo não é invenção, é convergência:

- `dialogs/trusted_terminals_dialog.ex:223` — `Revoke`/`Forget` na linha
- `dialogs/bot_management_dialog.ex:147` — clique abre o detalhe
- `dialogs/saved_dialog.ex:83`, `pinned_dialog.ex:83`, `mentions_dialog.ex:76`
- `dialogs/server_emoji_dialog.ex:124` — remove na linha
- `games/retro_games_panel.ex:59`, `games/solo_lobby.ex:117` — drill-down
- `space_character_select.ex:76` — o clique já escolhe
- `dialogs/invite_channel_picker_dialog.ex:52` — `<select>` nativo: é campo de
  formulário, não lista. Fora de escopo.
