# Playbook — reformar um diálogo com abas

Plano: `dialogs-abas-para-janelas.md` · Progresso: `dialogs-abas-para-janelas-PROGRESS.md`

Três receitas.  **Extração** (§1–§10) tira uma aba do diálogo e
a promove a janela do desktop; derivada das 9 janelas do Admin Console.
**Fusão** (§11–§13) funde abas irmãs numa só; derivada do Channel Central.
**Dedup** (§13b) mata uma aba que duplica uma janela existente; derivada do
Address Book. Tudo de 2026-07-25, e tudo feito — não imaginado.

Qual usar: §1 (extração) e §11.1 (fusão) respondem.

---

## 1. Quando este playbook se aplica

Uma aba de um diálogo vira uma janela do desktop quando ela é uma feature
independente: estado próprio, domínio próprio, e nada que ela precise ler das
irmãs. Se as abas compartilham um snapshot ou um "item selecionado", elas são
uma superfície só e **não** se separam (ver Channel Central e Bot Management no
plano).

Teste rápido: liste os assigns e atribua cada um a uma aba. Se sobrar um bloco
compartilhado que não seja passthrough de sessão, pare e reavalie.

---

## 2. A unidade de trabalho

**Uma janela por vez, em um commit.** O commit contém: os arquivos novos, o
wiring, a remoção da aba do monólito e a migração dos testes dela.

Abas magras (um formulário, um ou dois handlers) podem ir em lote — na fatia do
Admin, as seis últimas foram juntas. O que **não** se agrupa é o par
criar/deletar: a aba sai no mesmo passo em que a janela entra.

Nunca deixe a aba e a janela coexistindo entre commits. Duas superfícies
fazendo a mesma coisa é exatamente a dívida que o refactor existe para matar, e
a segunda vira código morto silencioso se o commit seguinte não vier.

---

## 3. Passo 0 da fatia — promover o substrato (uma vez, antes da primeira janela)

Antes de extrair a primeira janela, encontre o que **2 ou mais** das janelas
futuras vão usar e promova a módulo. Quem usa só uma fica privado nela.

Como achar: conte consumidores.

| Achado real | Consumidores | Destino |
|---|---|---|
| `admin_inline_result/1` | 7 abas | `UI.AdminShared.inline_result/1` |
| `admin?/1` | 3 cópias (island, events, ChatContext) | `ChatLive.AdminOps.admin?/1` |
| mensagem "restricted…" | 20 call sites | `AdminOps.restricted_message/0` |
| `result_entry/1` + `result_message/*` | todas | `AdminOps` |
| `settings_input/1` | 1 aba | fica privado em Server Settings |

Faça o monólito consumir os módulos novos **no mesmo passo**, e rode os testes.
Passo 0 é refactor sem mudança de comportamento — se um teste quebra, você moveu
algo errado.

**Cuidado real:** `error_event/2` existe duas vezes com o mesmo nome.
`Helpers.error_event/2` roda no LiveView pai; a do island faz
`send(self(), {:admin_system_error, msg})` para chegar lá. Dentro de hook →
`Helpers`. Dentro de island → `AdminOps`. Conflatar quebra a abertura da janela.

### Rename mecânico

```sh
perl -pi -e 's/\bnome\(/Mod.nome(/g' arquivo.ex
```

O word boundary **não** pega `audit_log_result_entry(` — o `_` antes é word
char, então não há fronteira. Exatamente o que se quer.

O que esse padrão perde: **capturas.** `&result_message/1` não tem `(`.
`mix compile --warnings-as-errors` pega. **Compile antes de qualquer teste** —
o compilador é o oráculo do rename.

---

## 4. Derivação de nomes

Do nome da aba, tudo o resto é mecânico. Exemplo com a aba `users`:

| Artefato | Valor |
|---|---|
| window id | `admin-users` |
| island id | `admin-users-dialog` |
| apresentacional | `components/ui/dialogs/admin_users_dialog.ex` → `UI.AdminUsersDialog` |
| island | `live/chat_live/components/admin_users_dialog.ex` → `ChatLive.Components.AdminUsersDialog` |
| funções públicas | `admin_users_dialog/1` (framed, showcase) + `admin_users_panel/1` (island) |
| testid do painel | `admin-users-panel` |
| testid da janela | `admin-users-window` |
| ids internos | `admin-users-<coisa>` (era `admin-console-user-<coisa>`) |
| eventos | `admin_users_<ação>` (era `admin_console_user_<ação>`) |
| evento de abertura | `open_admin_users` |
| tópico de ajuda | `feature-admin-users` + `feature_admin_users.html.heex` |
| showcase | `admin-users-dialog` |

**Nada de vestígio.** Um id `admin-console-users-form` dentro de uma janela
chamada Users é exatamente o rastro de origem que o refactor proíbe. O
compilador cobre o Elixir; o e2e cobre o resto.

**Rótulo só muda quando o conteúdo muda.** Não renomeie o item de menu antes de
a janela existir — o rótulo passa a mentir. (Erro cometido, ver PROGRESS E2.)

---

## 5. A sequência

A ordem importa: nada é deletado antes de o substituto existir e compilar.

```
1. Ler       → bloco da aba no apresentacional + handlers/helpers no island
2. Criar     → apresentacional novo
3. Criar     → island novo
4. Wiring    → 5 pontos
5. Deletar   → do monólito (9 lugares)
6. Testes    → migrar preservando asserções
7. Periferia → ajuda, showcase, e2e, catálogo
```

### 5.1 Ler

No apresentacional, a aba já é um `defp <nome>_tab/1` com bloco de `attr`
próprio, mais seus sub-formulários privados. No island, `grep` por:

```sh
grep -n "defp assign_<x>_snapshot\|defp handle_<x>\|defp <x>_" island.ex
grep -n "^  def handle_event" island.ex   # confirma o bloco contíguo
```

### 5.2 Apresentacional

**Fatie o original, não interpole texto novo.** Extrair blocos do arquivo antigo
por intervalo de linhas é seguro e exato. Montar o arquivo novo com f-strings
Python não é: `#{@id}` do Elixir colide com a interpolação da linguagem
hospedeira e vaza literal, e um intervalo errado corta uma função no meio. Na
fatia do Address Book isso custou três rodadas de conserto. Escreva o arquivo
novo direto, com a ferramenta de escrita.

Duas funções públicas. `<x>_dialog/1` é a variante emoldurada que **só o
showcase usa**; `<x>_panel/1` é o corpo nu que a janela monta.

O painel usa a raiz do monólito, não a do `highlight`:

```heex
<div id={"#{@id}-content"} data-testid="admin-users-panel"
     class="adm-dialog flex h-full min-h-0 flex-col gap-retro-8">
  <div class="adm-scroll min-h-0 flex-1 overflow-y-auto">
    ...
  </div>
</div>
```

**Não adicione `focus_wrap`** se o original não tinha: ele prende o Tab, e isso
é mudança de comportamento.

**Colapse formulários quase-idênticos.** Nas duas janelas feitas, dois
sub-formulários viraram um componente com flags:

- `user_nickserv_form` + `user_moderation_form` → `nick_action_form`
  (`show_reason`, `show_duration`, `include_password`)
- `channel_chanserv_form` + `channel_destructive_form` → `channel_action_form`
  (`include_nick`, `include_from`, `include_level`, `include_confirm`,
  `destructive`)

A ordem dos campos se preserva sozinha: os que não se aplicam não renderizam.
Onze formulários por janela, um componente.

### 5.3 Island

```elixir
use RetroHexChatWeb, :live_component
use Gettext, backend: RetroHexChatWeb.Gettext
import RetroHexChatWeb.Components.UI.<X>Dialog
alias RetroHexChatWeb.ChatLive.{AdminOps, ChatContext}

@id "admin-users-dialog"
@spec id() :: String.t()
def id, do: @id

@initial %{..., loaded?: false}

def mount(socket), do: {:ok, socket |> assign(:id, @id) |> assign(@initial) |> assign(session: nil)}
```

**Carga inicial: em `update/2`, não em `mount/1`.** `mount/1` roda antes de o pai
passar `session`, então não há contexto para despachar. E o AGENT-GUIDE proíbe
`send_update` pós-mount (funde na árvore virtual, nunca patcheia o DOM).

```elixir
def update(assigns, socket) do
  socket = assign(socket, assigns)

  if socket.assigns.loaded? do
    {:ok, socket}
  else
    {:ok, socket |> assign(loaded?: true) |> assign_snapshot(%{}, nil)}
  end
end
```

**Um guard por handler mutante**, porque os controles desabilitados são só dica:

```elixir
defp guarded(socket, run) do
  if AdminOps.admin?(socket) do
    run.()
  else
    {:noreply, AdminOps.error_event(socket, AdminOps.restricted_message())}
  end
end
```

**Armadilhas de nome:**
- `error/1` colide com `CoreComponents.error/1` em `:live_component`. Use
  `error_result/1`.
- As `normalize_*` costumam ser a mesma função repetida (`to_string |> trim`).
  Uma só, chamada `trim/1`.

**Drafts:** o formulário submetido traz seu campo; o resto vem do que a janela
já mostra. Sem os assigns-sombra do monólito, lê-se direto:

```elixir
defp draft(socket, params, key, assign_key) do
  case Map.fetch(params, key) do
    {:ok, value} -> trim(value)
    :error -> trim(Map.fetch!(socket.assigns, assign_key))
  end
end
```

### 5.4 Wiring — 7 pontos

1. `live/chat_live/windows.ex` — id no `@managed` (ordem alfabética)
2. `live/chat_live/admin_events.ex` — entrada no mapa `@windows`
3. `components/ui/shell/menu_bar_app.ex` — `<.menu_item>` em `admin_menu_items/1`
4. `components/ui/chat/chat_taskbar.ex` — `add_window/5` (ícone como **átomo**)
5. `components/ui/shell/start_menu_app.ex` — `<.app_item>` dentro de
   `<.start_menu_submenu>` (o start menu **não** aceita lista flat, ver abaixo)
6. `components/ui/shell/toolbar_app.ex` — `<.dropdown_item>`
7. `live/app/chat_live.html.heex` — bloco `<.desktop_window>`

**Nenhuma das três aceita lista flat.** Menu bar usa `<.submenu>`
(`components/ui/shell/menu_bar.ex`); start menu usa `<.start_menu_submenu>`
(`components/ui/layout/desktop.ex`), dirigido pelo `WindowManagerHook` no
contrato `data-start-submenu` / `data-start-submenu-panel`. Contratos separados
de propósito: são hooks diferentes, e reusar o atributo do outro faz um fechar o
painel do outro.

**Nem toda janela tem uma única ação de abertura.** No Account, o menu bar abre a
janela `account` por dois itens específicos de papel ("Register Nickname..." e
"Identify..."), não por um genérico. Um teste com a tabela `janela => ação` falha
ali pelo motivo errado. Use duas tabelas: `janela => ação canônica` (para o teste
de mount/unmount) e `janela => ações aceitáveis` (para o teste das três
superfícies).

**E as três não abrem a janela do mesmo jeito.** Menu bar e toolbar emitem a
ação (`open_<x>`); o start menu, via `<.window_item window="<id>">`, fala direto
com o window manager por `data-window-open` — o servidor monta a janela
gerenciada ao receber o evento `window_open`. Consequência para o teste: o
testid do start menu é `start-menu-item-<window-id>`, **não**
`start-menu-item-open_<x>`. Copie o padrão da janela vizinha antes de escrever a
asserção.

**Sem aba, não há diretiva de abertura.** Se a janela nova não precisa abrir num
estado específico, use `Windows.open/2` e **não** escreva a cláusula
`update(%{open: ...})`: a janela gerenciada desmonta ao fechar, então o `mount/1`
seguinte já reconstrói o estado que a diretiva resetaria. `open_with/4` existe
para o caso oposto (abrir apontando para algo), e usá-lo sem necessidade nasce
como código morto.

**E o estado que existia só para a aba lembrar em qual modo abriu some junto.**
No Account, `auth_mode` era assign, era parâmetro de 6 funções e tinha cláusula
de reset própria — tudo porque a aba precisava reabrir no mesmo modo. Sem aba, o
modo é **derivado** na hora (`NickServ.registered?/1`), já que o formulário nunca
ofereceu escolha. Procure por parâmetros que só existem para sobreviver ao
fechamento da aba.

**Não crie substrato que já existe.** Ao dividir um hook monolítico, o impulso é
extrair um `<Feature>Ops` com os helpers comuns. Antes, confira se o helper não é
só um wrapper de uma linha sobre um módulo compartilhado que já existe
(`CommandDispatch`, `Helpers`). No Account, `dispatch/3` e
`dispatch_with_result/3` eram exatamente isso — os quatro hooks passaram a
chamar `CommandDispatch` direto. A regra de contar consumidores (§3) é para
código sem casa, não para reembrulhar o que já tem uma.

**Três superfícies listam a janela, não uma.** Menu bar, start menu e toolbar
são arquivos separados. Esquecer duas delas não quebra nada: a janela
simplesmente não existe a partir dali, e nenhum teste padrão percebe. Foi o que
aconteceu na fatia do Admin (ver PROGRESS, E3). O teste de entry points tem de
iterar as três — ver §5.6.

O bloco da janela, com o guard de render como segunda linha de defesa:

```heex
<.desktop_window
  :if={admin?(@session) and "admin-users" in @open_windows}
  id="admin-users"
  title={dgettext("chat", "Users")}
  managed
  default_x={150} default_y={60}
  width={680} height={580} min_width={520} min_height={400}
  body_class="flex min-h-0 flex-col p-2"
  data-testid="admin-users-window"
>
  <:icon><Icons.icon_community class="h-4 w-4" /></:icon>
  <.live_component module={...AdminUsersDialog} id={...AdminUsersDialog.id()} session={@session} />
</.desktop_window>
```

**Ícones:** reuse do catálogo quando houver semântica correta
(`icon_community`, `icon_channels`) em vez de mintar SVG. Se mintar, são dois
(`icon_dialog_<x>` e `icon_btn_<x>`) mais o `defdelegate` em `icons.ex` — e
esquecer o delegate quebra a taskbar **em runtime, não em compile**.

**O `icon_tab_<x>` da aba extraída fica órfão.** O prefixo mente numa janela sem
abas: aposente-o em favor do par `icon_dialog_` / `icon_btn_`. Cuidado ao caçar
os usos — tópicos de ajuda referenciam ícones **como átomo**
(`icon: :icon_tab_autojoin`), então um grep pelo nome da função não os encontra:

```sh
grep -rn ":icon_tab_<x>" apps/
```

**CSS: família compartilha, par extraído duplica.** As 9 janelas admin
compartilham `dialogs/admin.css` (`adm-dialog`, `adm-scroll`), que já carrega
todo o trabalho mobile — nenhum arquivo novo por janela. Já um par nascido de um
split de duas abas segue o contrato literal do plano (§8.13): arquivo próprio,
prefixo próprio (`perform.css`/`pf-` + `autojoin.css`/`aj-`). ~100 linhas
duplicadas valem menos que um prefixo que mente sobre a janela em que mora.

A fatia do Account confirmou o outro lado: 4 janelas irmãs ficaram com um
`account.css` só, prefixo `acct-` — que continua honesto porque as quatro **são**
configurações de conta. O corte fica entre 2 (duplica) e 4 (compartilha).

De qualquer forma, **o CSS do shell de abas morre junto com o shell**: 80 linhas
de scroller mobile saíram do `perform.css`, ~85 do `account.css`, do mesmo jeito
que os `.ac-main-tabs*` saíram na fatia do Admin.

**O CSS do shell de abas está sempre em dois lugares.** O arquivo da feature
tem o dele, e há um bloco compartilhado (hoje em `account.css`) que agrupa os
scrollers mobile de vários diálogos por prefixo. Ao matar um shell de abas,
limpe os dois — o `lint.css_consistency` acusa, mas só depois de você ter feito
metade.

**E não filtre CSS por linha.** Remover as linhas de um prefixo de uma lista de
seletores multi-linha apaga também a que carrega o `{`. Depois de qualquer
edição programática, confira `count("{") == count("}")` antes de rodar o lint.

**Grepe o CSS pelo valor da aba, não só pelo prefixo.** Os blocos de scroller
mobile são compartilhados entre diálogos e selecionam a aba ativa por
`:has(.tabs-trigger[data-state="active"][data-target="<aba>"])`. Isso é seletor
de **atributo**, então `lint.css_consistency` — que casa nomes de classe — não
enxerga. Na fatia do Account achei seletores `cc-main-tabs-shell` ainda citando
`bans`/`ban_exceptions`/`invite_exceptions`, abas que a fatia do Channel Central
tinha removido duas fases antes:

```sh
grep -rn 'data-target="<aba removida>"' apps/*/assets/css/
```

### 5.5 Deletar do monólito — 9 lugares

Faça só depois de `mix compile --warnings-as-errors` verde com a janela nova.

**Apresentacional:** ① trigger da aba · ② bloco `tabs_content` ·
③ função `<x>_tab/1` + sub-formulários · ④ attrs órfãos

**Island:** ⑤ handlers · ⑥ `assign_<x>_snapshot` + helpers · ⑦ assigns em
`@owned_defaults`/`@reset` + sombras · ⑧ branch no `case` do `admin_console_tab`
+ whitelist do `normalize_tab` · ⑨ wiring no `render/1`

Deleções contíguas em **um passe de sed** — os intervalos referem-se à numeração
original:

```sh
sed -i '' -e '1247,1258d' -e '1218,1223d' -e '784,813d' -e '123,202d' -e '87d' arquivo.ex
```

Confirme cada fronteira antes (`sed -n 'N,+5p'`), e depois:

```sh
grep -n "<x>" arquivo.ex   # tem que sobrar só o que é de outro domínio
```

**Helpers que ficam órfãos vão junto** — verifique antes de deletar:

```sh
grep -n "truthy_param?\|normalize_user_moderation_value" island.ex
```

Se os únicos usos estavam na aba, o helper sai. Se um helper for usado por outro
domínio (aconteceu com `dispatch_admin_user/2`, que channels usava), **renomeie
para um nome honesto e mantenha** em vez de duplicar.

### 5.6 Testes — o oráculo de paridade

Este é o passo que prova que nada quebrou.

O `describe` da aba vira um arquivo `<x>_feature_test.exs`. Muda **só** o
mecanismo de abertura e os ids. **Toda asserção de comportamento é preservada
literalmente.**

Janelas com um ou dois testes podem dividir um arquivo de suíte, um `describe`
cada — seis arquivos de scaffolding para seis testes é pior de manter. As
pesadas ficam com arquivo próprio.

```elixir
# antes
open_admin(view)
admin_tab(view, "users")

# depois
render_click(view, "toolbar_action", %{"action" => "open_admin_users"})
render(view)
```

> Se uma asserção precisa mudar de **significado** (não só de seletor), a
> feature mudou. Pare e investigue — não ajuste o teste.

Adicione ao arquivo novo o bloco de entry points, que a aba não tinha:

```elixir
assert has_element?(view, ~s([data-window-id="admin-users"][data-window-managed="true"]))
assert_push_event(view, "window_command", %{action: "open", id: "admin-users"})
render_hook(view, "window_closed", %{"id" => "admin-users"})
refute has_element?(view, ~s([data-window-id="admin-users"]))
```

E o forjado: `render_hook(view, "window_open", ...)` com sessão não-admin não
pode renderizar o painel.

**Cubra as três superfícies de entrada**, iterando em vez de asserir uma:

```elixir
for {surface, html} <- admin_surfaces(true) do
  for action <- admin_actions() do
    assert html =~ ~s(data-testid="context-menu-item-#{action}") or
             html =~ ~s(data-testid="start-menu-item-#{action}"),
           "#{surface} should offer #{action}"
  end
end
```

Um teste que assere só o menu bar deixa passar uma janela ausente do start menu
e do toolbar — foi exatamente o furo da fatia do Admin.

**Teste de island** (`@moduletag :unit`): id estável, painel nu sem chrome,
`phx-target` presente, e que a carga inicial rodou. Para a carga, não assere
conteúdo do banco — assere que o painel tem saída do dispatcher:

```elixir
assert pane |> Floki.text() |> String.starts_with?("***")
```

**Regra aprendida na marra:** o teste de island **do monólito** não pode se
ancorar na aba que está saindo. Reescrevi a fixture dele duas vezes por isso.
Ancore na aba que sai por último.

### 5.7 Periferia

**Ajuda** (obrigatória por CLAUDE.md):
- tópico em `help_topics/features.ex` (campos `id, title, category, keywords,
  icon, description, see_also`; `category` tem que ser uma das 26 de
  `@categories` ou levanta)
- `help_content/feature_<x>.html.heex`
- **glob `embed_templates`** em `chat_features.ex` — sem isso, `ArgumentError`
  ao abrir o tópico
- as keywords da aba **saem** do tópico do monólito e **entram** no novo
- referências cruzadas nos dois sentidos: o tópico novo aponta para o console, e
  os `cmd-admin-*` deixam de apontar só para ele

**Showcase** — 4 registros manuais: `router.ex`, lista de nav e `@nav_icon_map`
em `showcase_helpers.ex`, `scripts/test_showcase.exs`.

**E2E** — page object (declaração, construtor, opener), spec nova, remoção do
bloco do spec do console, linha em `TEST_CATALOG.md` + contadores do cabeçalho.

O opener passa pelo submenu:

```ts
async openAdminUsersFromMenu() {
  await this.openAdminSubmenu();
  await expect(this.adminUsersMenuItem).toBeVisible();
  await this.adminUsersMenuItem.click();
  await expect(this.adminUsersWindow).toBeVisible();
}
```

**Cuidado:** antes de criar `chat-admin-<x>.spec.ts`, cheque se já existe — o
`chat-admin-users.spec.ts` já cobria os comandos `/admin user`. Use o sufixo
`-window`.

---

## 6. Escada de verificação

Por janela, nesta ordem — cada degrau é mais caro que o anterior:

```sh
mix compile --warnings-as-errors     # oráculo do rename
mix format
mix credo --strict <arquivos novos>
mix test <feature novo> --include liveview_feature
mix test <island novo>
mix test <suíte do monólito> --include liveview_feature
make lint.css
make lint.js
```

**`--include liveview_feature` não é opcional.** Os feature tests têm essa tag e
ficam **excluídos por padrão** — `mix test <arquivo>` responde "0 failures" sem
rodar nada relevante.

`make ci` completo no fechamento da fatia, não por janela.

---

## 7. Falhas silenciosas

| Esquecer | Como falha |
|---|---|
| `@managed` em `windows.ex` | `window_command` dispara, janela nunca renderiza |
| entrada no `AdminEvents` | clique no menu não faz nada, evento vira "unrouted" |
| `defdelegate` em `icons.ex` | taskbar quebra em **runtime**, não em compile |
| `@import` no `retrohex.css` | janela sem estilo |
| glob `embed_templates` | `ArgumentError` só ao abrir o tópico de ajuda |
| carga inicial via `send_update` pós-mount | dado invisível no browser; **ExUnit passa** |
| `phx-target` em form aninhado | input digitado é resetado no re-render |
| `--include liveview_feature` | suíte "verde" sem ter rodado |
| `@nav_icon_map` no showcase | página existe, nav sem ícone |
| contadores do `TEST_CATALOG.md` | drift silencioso, sem check automático |

---

## 8. Teardown do monólito

A última janela é diferente: além de extrair, ela **deleta o arquivo antigo**.

Quando a penúltima aba sai, o que resta é a última aba mais o shell de abas — e
o shell não tem mais função, porque um conjunto de abas com um item é só um
painel. Então o passo 9 não é uma extração: é uma reescrita.

```sh
rm components/ui/dialogs/<monolito>.ex
rm live/chat_live/components/<monolito>.ex
```

E recriar os dois com o conteúdo da última aba apenas. Deletar de verdade, não
editar até sobrar pouco — é o que garante que nenhuma linha do monólito
sobreviva disfarçada de janela nova.

Resultado real da fatia do Admin Console:

| Arquivo | Antes | Depois |
|---|---|---|
| apresentacional | 1703 linhas, 9 abas | 116, só o REPL |
| island | 1336 linhas | 191, só o REPL |

O que morre junto com o shell: a função que monta as abas, o componente de
gatilho de aba, o gerador de placeholders, a superfície de attrs inteira, o
branch modal não-windowed que só o showcase usava, e os assigns-sombra que
existiam para os irmãos lerem filtro um do outro.

**Renomear por último.** O window id perde o sufixo herdado
(`admin-console-dialog` → `admin-console`) e o rótulo do menu vira o nome real
("Admin Console" → "Console") **só agora**, porque só agora o conteúdo bate com
o nome. O island id mantém a convenção `<window-id>-dialog`.

**O linter marca a hora de refatorar o que inchou.** Nove janelas viraram nove
branches na taskbar e o credo reprovou por complexidade (12, máx 9). Viraram
uma lista de módulo mais uma função de redução. Vale esperar o linter apontar
em vez de antecipar.

**CSS morto não está só no arquivo da feature.** O `<monolito>.css` inteiro
morreu — mas `account.css` também carregava 23 seletores `.ac-main-tabs*`, de
quando os dois diálogos dividiam o scroller de abas do mobile. Quem achou foi o
`lint.css_consistency`; procurar pelo prefixo no arquivo da feature não teria
bastado.

## 9. Passada de i18n

Uma vez, no fim da fatia — rodar por janela é desperdício.

```sh
make i18n.gettext.extract
# reverter os .pot que o extract mexeu e você não tocou (débito pré-existente)
make i18n.gettext.merge DOMAINS=<d> APP=web    # um por domínio
```

Domínios de uma janela: `dialogs` (painel), `ui` (menu), `chat` (título e
taskbar), `showcase`, `help_features` (corpo da ajuda) e `help` (metadados do
tópico, app de domínio).

### O venv

`scripts/i18n_machine_translate_po.py` precisa de três pacotes, não um:

```sh
python3 -m venv /tmp/retro_hex_chat_i18n_venv
/tmp/retro_hex_chat_i18n_venv/bin/pip install polib argostranslate opencc-python-reimplemented
```

`opencc-python-reimplemented` só é exigido quando `zh_hant` está na lista — e o
script falha inteiro sem ele, no meio da rodada.

### Os três passos que o fluxo documentado não menciona

**1. Traduzir os 20 locales não-ingleses.**

```sh
/tmp/retro_hex_chat_i18n_venv/bin/python scripts/i18n_machine_translate_po.py \
  --locales pt_BR,es,fr,de,ja,zh_hans,id,ar,ru,hi,ko,tr,vi,bn,ur,zh_hant,pt_PT,it,pl,nl \
  apps/retro_hex_chat_web/priv/gettext/*/LC_MESSAGES/<dominio>.po
```

**2. Preencher o `en`.** O tradutor pula o inglês, então as entradas novas ficam
vazias e reprovam no `catalog.check`. Em `en`, `msgstr = msgid`. Os fuzzy do
`en` também vêm errados do merge (`Channels` → `Channel List`) e devem ser
sobrescritos, não revisados.

**Preencha com Expo, não com polib.** `Expo.PO.parse_file!` + `Expo.PO.compose`
é o mesmo escritor que o `mix gettext.merge` usa, então as entradas que você não
tocou saem byte a byte iguais. `polib.save()` rewrapa os `msgid` em 78 colunas e
produz ~1.200 linhas de churn num `help_features.po` para preencher 5 entradas.

```elixir
po = Expo.PO.parse_file!(path)
# msgstr: msgid e flags -- ["fuzzy"] nas entradas vazias/fuzzy
File.write!(path, Expo.PO.compose(%{po | messages: messages}))
```

**3. Consertar os placeholders e limpar o fuzzy.** A tradução automática perde
`%{...}` — 112 entradas na fatia do Admin. `scripts/i18n_repair_placeholder_mismatches.py`
restaura, **mas marca as reparadas como fuzzy**, e aí o `catalog.check` reprova
de novo. Terceiro passo: limpar a flag onde o conjunto de placeholders do
`msgstr` voltou a bater com o do `msgid`.

**O tradutor também estraga entradas que não são suas.** Ele varre o arquivo
inteiro, não só o que você adicionou, e entradas que estavam em fallback inglês
viram lixo com placeholder quebrado (`"Version %{version}"` → `"<ph0>>/ph0>"`).
Na fatia do Channel Central foram 7: 2 singulares e **5 plurais**. Depois de
traduzir, faça um diff semântico contra o snapshot pré-merge e reverta o que
você não pretendia mudar:

```python
old = {e.msgid: (e.msgstr, dict(e.msgstr_plural)) for e in polib.pofile(antes)}
```

**Compare `msgstr_plural` também.** Um diff que olha só `e.msgstr` acha 2 dos 7
— entradas plurais têm `msgstr` vazio e o dano fica invisível. Quem pegou os
outros 5 foi o `i18n.placeholder.check`; sem placeholder no msgid, teriam
passado.

### Gates

```sh
make i18n.catalog.check          # vazio / fuzzy / inglês / tamanho
make i18n.placeholder.check      # placeholders preservados
make i18n.source-fallback.check  # inglês vazando em locale traduzido
```

`make i18n.gettext.check` vai reprovar apontando os `.pot` que você reverteu.
É débito pré-existente e **não faz parte do `make ci`**.

### Disciplina de escopo

O `extract` reescreve todos os `.pot` (18, na fatia do Admin — 12 sem relação
com o trabalho). Reverter um a um. Mesma regra ao preencher o `en`: o script
vai querer consertar `errors.po` e `group_call.po` de brinde — reverter também.

**Mas nem todo `.pot` alterado é churn.** Na fatia do Channel Central o extract
mexeu em 7, e `chat.pot`/`ui.pot` perderam msgids porque a **fase anterior**
(limpeza de código morto) apagou o código que os produzia sem re-extrair.
Reverter isso teria mantido o `i18n.gettext.check` vermelho preservando strings
de handlers que não existem mais. Antes de reverter um `.pot`, diffe: se ele só
perdeu msgids de código que morreu, ele está certo e você está atrasado.

**E a disciplina de escopo não se aplica a catálogo misturado.** Na fatia do
Perform, um rebase trouxe 6 commits de P2P que renomearam strings sem
re-extrair; o extract acusou 17 `.pot`, 11 alheios. Três deles —
`help.pot`, `chat.pot`, `help_features.pot` — carregavam as minhas strings **e**
as deles no mesmo arquivo. Reverter perderia as minhas; manter sem tratar deixa
entradas vazias que o `catalog.check` reprova.

Quando isso acontece, a escolha é binária: absorver a dívida inteira (extract
completo + merge + tradução) ou entregar o gate vermelho. Traduzir catálogo não
é tocar no código da feature alheia — **mas não é barato**. Na fatia do Perform a
absorção rendeu 1.470 entradas novas e **354 traduções existentes destruídas**,
porque os domínios alheios (`chat`, `group_call`, `p2p`, `commands`, `lobby`)
estão cheios de strings em fallback inglês com placeholders que o tradutor
automático moe.

Orce os três passos de limpeza antes de decidir; se a dívida alheia for grande,
um `chore(i18n)` separado sai melhor.

### Os três passos de limpeza depois de uma rodada grande

1. **Restaurar o colateral** — diff semântico contra o snapshot pré-merge
   (`msgstr` **e** `msgstr_plural`) e devolver toda entrada que já existia. Só as
   entradas novas ficam.
2. **Reparar placeholders** com `i18n_repair_placeholder_mismatches.py`. Saiba o
   que ele faz: para recuperar os `%{}` ele devolve o **inglês**. Isso deixa
   `placeholder.check` verde e derruba `source-fallback.check`.
3. **Traduzir à mão o resíduo do passo 2.** Na fatia do Perform foram 45
   entradas (5 strings × 9 locales); os outros 11 locales o tradutor acertou de
   primeira. Cinco strings curtas escritas à mão custam menos que outra rodada
   de máquina.

Os gates só ficam todos verdes depois dos três — cada um cobre o buraco que o
anterior abre.

### Não confunda deriva de referência com rewrap

Adicionar uma linha a `features.ex` desloca todos os `#:` seguintes e o merge
reescreve ~1.400 linhas de `help.po` — **e está tudo certo**. Antes de concluir
que o `mix gettext.merge` rewrapou o arquivo e partir para edição cirúrgica,
olhe o diff: se as linhas alteradas são todas `#: caminho.ex:NNN`, é deriva de
número de linha e não há nada a consertar. Contar linhas alteradas não distingue
os dois casos; ler cinco delas distingue.

---

## 10. Prettier: use o do repo

`npx prettier` baixa outra versão e discorda do que o `make format.check` roda.
Sempre:

```sh
apps/retro_hex_chat_web/assets/node_modules/.bin/prettier --write <arquivo>
```

---

# Parte II — Fundir abas irmãs numa só

Derivado da fusão `bans` + `ban_exceptions` + `invite_exceptions` →
**Access Lists** no Channel Central (2026-07-25). Saldo: 6→4 abas, −198 linhas,
zero capacidade perdida.

## 11. Quando fundir em vez de extrair

Extração e fusão são o mesmo diagnóstico lido em direções opostas. Liste os
assigns e atribua cada um a uma aba:

- **Nada compartilhado** → são features independentes → extrai (§1).
- **Compartilham o snapshot mas divergem no conteúdo** (General, Modes,
  Registration do Channel Central) → ficam abas separadas, não se toca.
- **São a mesma superfície com um discriminador** → funde.

O terceiro caso tem uma assinatura mecânica, e ela é o teste decisivo:

| Sinal | No Channel Central |
|---|---|
| As abas já compartilham a função de render | `list_tab/1`, chamada 3× com attrs diferentes |
| Os sub-formulários são quase-idênticos | 3 add-forms, 59 linhas cada, 10 diferentes |
| Os assigns vêm em trios paralelos | `*_selected` ×3, `show_*_dialog` ×3 |
| Os handlers vêm em famílias paralelas | select/open/close/add/remove ×3 |
| Os getters derivados diferem só na chave | `Map.get(state, :bans / :ban_exceptions / …)` |

Três ou mais sinais e a fusão é mecânica. Um ou dois, pare: pode ser coincidência
de forma, não de significado.

**O que a fusão NÃO é:** um jeito barato de reduzir a contagem de abas. Se as
listas fossem lidas de serviços diferentes ou tivessem permissões diferentes, o
seletor esconderia uma diferença real. Aqui as três saem do mesmo
`Server.get_state`, são gated pelo mesmo `operator`, e as seis funções de
`Channels.Server` continuam todas alcançáveis.

## 12. A sequência da fusão

Ao contrário da extração, **nada é criado antes de deletar** — é uma
substituição no lugar. A ordem é do mais interno para o mais externo:

```
1. Escolher   → o discriminador e o vocabulário derivado dele
2. Colapsar   → sub-formulários N → 1, parametrizado
3. Colapsar   → a função de aba N → 1, com o seletor
4. Colapsar   → assigns, eventos e handlers no island
5. Despachar  → uma tabela por tipo para as chamadas de domínio
6. Wiring     → strip de abas, render do island, showcase
7. Testes     → migrar preservando asserções
8. Periferia  → ajuda, e2e, catálogos
```

### 12.1 O discriminador dita todo o vocabulário

Escolha um nome para o discriminador e derive tudo dele — do mesmo jeito
mecânico que a extração deriva do nome da aba (§4):

| Artefato | Valor |
|---|---|
| valor da aba | `access_lists` |
| rótulo | "Access Lists" |
| discriminador | `list_type` ∈ `bans \| ban_exceptions \| invite_exceptions` |
| attrs do painel | `list_type`, `list_entries`, `list_selected` |
| callbacks | `on_list_type`, `on_list_add`, `on_list_remove`, `on_list_select` |
| assigns do island | `channel_central_list_type`, `channel_central_list_selected` |
| eventos | `cc_list_type`, `cc_list_select`, `cc_add_list_entry`, … |
| testids do seletor | `cc-list-type-<tipo>` |
| testid do sub-form | `cc-add-list-entry-dialog` + `data-access-list=<tipo>` |

**Cuidado com colisão de vocabulário.** "Access Lists" é o rótulo do produto,
mas a aba Registration já tinha `access_tab`/`access_selected`/`access_nick`
para os níveis SOP/AOP/VOP do ChanServ. Prefixar os novos assigns com `access_`
teria criado dois significados para a mesma palavra no mesmo módulo. Daí
`list_*` no código e "Access Lists" só na UI. **O rótulo do produto não é
obrigado a ser o identificador do código** — e quando o nome já está tomado,
não pode ser.

### 12.2 Um testid, não N

O sub-formulário fundido tem **um** testid mais um atributo de dados com o tipo:

```heex
<div data-access-list={@list_type} data-testid="cc-add-list-entry-dialog">
```

Assim o teste não perde poder: em vez de `assert html =~ "cc-add-ban-ex-dialog"`
ele faz `assert html =~ ~s(data-access-list="ban_exceptions")`, que continua
provando *qual* diálogo abriu. Manter os três testids antigos teria sido mais
barato e teria mentido — três nomes para um componente.

### 12.3 A tabela de despacho fica no island, os rótulos no apresentacional

Divisão que se paga: o island mapeia tipo → função de domínio e → mensagem de
erro; o apresentacional mapeia tipo → rótulo, placeholder de lista vazia e
título do sub-form. Nenhum texto de UI atravessa para o island, e nenhuma
chamada de `Server` atravessa para o apresentacional.

```elixir
defp add_list_entry("bans", ch, op, mask), do: Server.ban(ch, op, mask)
defp add_list_entry("ban_exceptions", ch, op, mask), do: Server.add_ban_exception(ch, op, mask)
defp add_list_entry("invite_exceptions", ch, op, mask), do: Server.add_invite_exception(ch, op, mask)
```

**Preserve as mensagens de erro literalmente.** Elas são msgids traduzidos em 21
locales. `unban` erra com "Unban error:" e `remove_ban_exception` com "Ban
exception error:" — assimetria feia, mas reescrever para uniformizar descartaria
traduções e violaria "é movimentação, não reescrita". Duas famílias
(`add_error_message/2`, `remove_error_message/2`) preservam a assimetria de
graça.

### 12.4 A única mudança de comportamento que a fusão obriga

Três seleções viram uma. Trocar de tipo com uma seleção viva deixaria o Remove
apontando para uma máscara que não está na lista visível — então **trocar o tipo
limpa a seleção**.

Isto é comportamento novo: não existia "trocar de tipo" antes. Precedente no
próprio arquivo (`cc_cs_access_tab` já limpava a seleção ao trocar SOP/AOP/VOP),
então a escolha não é arbitrária. Merece comentário no handler e **um teste
próprio** — foi o único teste que a fusão adicionou, e o único lugar onde a
paridade não podia ser provada por migração de asserção, porque não havia
asserção anterior a migrar.

### 12.5 Espaçamento: o wrapper novo já traz o gap

`list_tab/1` renderizava a tabela e a barra de ações como irmãos soltos, com
`mb-2` na tabela para separá-los. A aba fundida embrulha tudo num
`<div class="space-y-2">` para acomodar o seletor — e aí o `mb-2` vira gap dobrado.
Removê-lo preserva o espaçamento original **exatamente**. Fusão mexe em layout;
confira o que o wrapper novo já dá antes de manter o espaçador antigo.

### 12.6 Reuse as classes do vizinho

O seletor de tipo é visualmente o mesmo controle segmentado que a aba
Registration usa para SOP/AOP/VOP. Reusar `.cc-segmented-tabs` / `.cc-segmented-tab`
custou **zero CSS novo** — inclusive o
`grid-template-columns: repeat(3, minmax(0, 1fr))` do `.desktop--stacked`, que
já estava escrito para exatamente três botões.

Antes de escrever CSS numa fusão, procure o controle equivalente no mesmo
arquivo. Quem funde abas quase sempre está construindo um seletor que a feature
vizinha já tem.

## 13. Testes da fusão

Mesma regra da extração (§5.6): **muda o mecanismo, não o significado**. Numa
fusão a tradução é de duas etapas — a aba vira aba + tipo:

```elixir
# antes
cc(view, "channel_central_tab", %{"tab" => "ban_exceptions"})

# depois
cc(view, "channel_central_tab", %{"tab" => "access_lists"})
cc_list(view, "ban_exceptions")
```

Vale um helper por eixo (`cc/3` para a aba, `cc_list/2` para o tipo) em vez de
um helper que faz os dois: os testes de General/Modes/Registration não passam
pelo segundo eixo, e um helper fundido os obrigaria a passar um argumento que
não significa nada para eles.

**Aumente a cobertura onde a fusão remove redundância.** O teste de não-operador
verificava a ausência do botão Add só na aba Bans; com um único componente para
os três tipos, verificar os três custa duas linhas e cobre a regressão de "o
gate sumiu num tipo só".

## 13b. Deduplicar uma aba contra uma janela que já existe

Quando a aba duplica uma janela standalone (Address Book × Notify List), a
janela vence — mas **primeiro migre o que só a aba tinha**. Diff campo a campo
antes de apagar: na fatia do Address Book era o timestamp com timezone, e sem
migrar teria sido uma regressão silenciosa para quem usava a aba.

**Nem tudo da aba é melhor.** A aba mostrava `—` para contato online; a
standalone mostra "Now". Migrar `—` teria piorado a janela vencedora. Migre o
que é superior, não o que é diferente — e registre a escolha.

**Os testes da aba mudam de seletor, não de significado.** Eles vão para o
arquivo da janela vencedora e passam a falar a markup dela
(`.text-success` → `.nl-status--online`, id → `data-testid`, cópia do estado
vazio). Se uma asserção não tem tradução possível, ela provavelmente comparava
as **duas** superfícies — e essa, sim, morre com a dedup, porque não há mais o
que comparar.

---

## 14. Ajuda: fundir não é só renomear

O tópico de ajuda listava três linhas de aba. Vira uma, mas o texto tem de
ensinar **o seletor**, senão o usuário perde a feature de vista:

> "Access Lists: uma lista por vez, escolhida no seletor no topo da aba: bans,
> ban exceptions (+e)…"

E as referências cruzadas de outros tópicos mudam de forma, não só de nome:
`feature-ban-exceptions` dizia "a aba **Ban Exceptions**"; passa a dizer "a aba
**Access Lists**, com o seletor em Ban Exc." — o caminho ficou com dois passos,
e a ajuda tem de refletir isso.

Grep obrigatório antes de dar por fechado — abas fundidas são citadas por nome
em lugares que não têm nada a ver com o diálogo:

```sh
grep -rn "<nome da aba antiga>" apps/*/lib/*/controllers/help_content/
```

Foi assim que apareceu `chanserv_ui.html.heex`, que dizia "escolha Registration
**depois de Invite Exceptions**" — uma instrução de navegação que a fusão
invalidou silenciosamente.
