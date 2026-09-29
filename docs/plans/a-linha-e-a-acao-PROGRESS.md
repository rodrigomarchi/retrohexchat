# A linha é a ação — progresso

Companheiro de [`a-linha-e-a-acao.md`](a-linha-e-a-acao.md). O plano diz o que
fazer; este arquivo diz o que já foi feito, o que se aprendeu fazendo, e o que a
próxima sessão precisa saber para não repetir a descoberta.

Uma entrada por iteração. Aprendizado que vale além deste plano sai daqui e vai
para `docs/AGENT-GUIDE.md` no fechamento.

---

## Fase 0 — o componente único · CONCLUÍDA

**O que entrou**

| Arquivo | |
|---|---|
| `components/ui/layout/action_list.ex` | `action_list/1` + `action_row/1` |
| `assets/css/retrohex/components/action-list.css` | importado em `retrohex.css` após `list-states.css` |
| `live/showcase_live/layout/action_list_page.ex` | três cartões: porta, editor, várias ações |
| `showcase_catalog.ex` | entrada `action-list`, grupo `:layout` |
| `test/.../components/ui/layout/action_list_test.exs` | 9 testes `:unit` |
| `docs/AGENT-GUIDE.md` §11 | regra nova "The row is the action" |
| `help_topics/user_interface.ex` | `ui-listings` ganhou a frase acionável e `see_also` |

**A API que saiu**

```heex
<.action_list id="channel-list" label={dgettext("dialogs", "Channels")}>
  <.action_row on_activate={@on_join} value={%{"channel" => name}} current={@editing == name}>
    <:icon>…</:icon>
    <:title>…</:title>
    <:meta>…</:meta>
    <:trailing>…</:trailing>
    <:action event={@on_remove} value={…} label="Remove #tech" variant="destructive">
      <Icons.icon_btn_remove class="w-4 h-4" />
    </:action>
  </.action_row>
</.action_list>
```

### Aprendizados

1. **O ícone da ação é o bloco do slot, não um atributo `:atom`.** A primeira
   forma era `icon={:icon_btn_remove}`, que obrigaria `apply(Icons, @icon, […])`
   — sem checagem em tempo de compilação — ou uma lista fechada de `defp`
   clauses como `ListStates.state_icon/1`, que faria toda ação nova editar o
   primitivo. O corpo do `<:action>` **é** o ícone: `<Icons.icon_btn_remove />`
   escrito no chamador, checado pelo compilador, aberto a qualquer ícone do
   registry.
2. **`phx-value-*` dinâmico entra como lista de atributos.** `value` é um mapa e
   vira `[{"phx-value-channel", "#tech"}]` num `{…}` dentro da tag. Uma linha com
   dois parâmetros lê igual a uma com um.
3. **A ação herda o `phx-target` da linha.** Sem isso, todo `<:action>` num
   diálogo que é LiveComponent precisaria repetir `target={@myself}` — e o que
   esquecesse mandaria o evento para o LiveView raiz em silêncio.
4. **O bisel é da `<li>`, o botão primário é transparente.** Se o botão primário
   carregasse o bisel Win98, uma linha com ações desenharia um botão dentro de um
   botão. A linha inteira é o painel; o primário ocupa o que as ações deixam.
5. **A asserção de aninhamento foi vista vermelha.** Aninhei as ações dentro do
   primário de propósito, rodei, o teste caiu, restaurei. Sem isso a asserção
   `refute html =~ ~r{<button[^>]*>…<button}s` não prova nada.
6. **`disabled` existe no `<:action>` e não na linha.** Uma linha desabilitada é
   a lista de novo sem porta. Um `<:action>` desabilitado (Up na primeira linha)
   mantém os controles no mesmo lugar de linha para linha — esconder com `:if`
   faria os botões pularem de posição.

### Decisão tomada e adiada

**`components/ui/shell/config_form.ex` será apagado na Fase 5**, junto com
`showcase_live/shell/config_form_page.ex` e sua entrada no catálogo. É o molde
genérico do padrão errado e não tem nenhum consumidor real, mas apagá-lo agora
enfia uma remoção não relacionada na revisão da primeira tela. Sai quando não
houver mais nada que possa ser tentado a copiá-lo.

### Validação

- `mix test …/action_list_test.exs` — 9/9
- `mix lint.css_consistency` — 0 unused, 0 missing
- `mix test …/help_topics_test.exs` — 51/51
- `mix compile --warnings-as-errors` — limpo

---

## Fase 1 — Channel List · CONCLUÍDA, aguardando revisão

A janela do print. Cada linha virou a própria porta; o botão de rodapé não
existe mais.

**O que mudou**

| Arquivo | |
|---|---|
| `components/ui/dialogs/channel_list.ex` | linhas viram `action_row`; `cl-action-row` e `selected_channel` somem |
| `live/chat_live/components/channel_list_dialog.ex` | o assign `selected` some; o componente guarda só o `search` |
| `live/chat_live/channel_list_events.ex` | `channel_list_select` some |
| `assets/css/retrohex/dialogs/channel-list.css` | 16 regras `.cl-channel-*` / `.cl-action-*` apagadas |
| `live/showcase_live/dialogs/channel_list_page.ex` | o cartão "With Selection" some; um canal `+i` entra para desenhar os dois verbos |
| 4 arquivos de teste Elixir + 3 specs Playwright + `e2e/pages/ChatPage.ts` | |

### Aprendizados

1. **Tirar o botão do rodapé tira o verbo da tela.** Foi a descoberta que mudou
   o componente: sem "Join" escrito em algum lugar, a linha não diz o que o
   toque vai fazer. Entrou um `<:cta>` — o verbo desenhado na própria linha,
   disparando o evento da linha.
2. **O verbo por linha corrigiu um defeito que ninguém tinha reportado.**
   `request_access?/2` olhava a linha *selecionada* e o rótulo do botão de
   rodapé trocava de "Join" para "Request Access..." embaixo do dedo conforme a
   seleção mudava. Agora é propriedade da linha: `#aberto` e `#fechado` mostram
   verbos diferentes ao mesmo tempo, o que a forma antiga não conseguia
   desenhar. Está na evidência `closed-room-row`.
3. **`flex`, não `grid`, no botão primário.** Com `grid-template-columns` de
   três colunas e quatro filhos possíveis (ícone, texto, números, verbo), o
   quarto cai para uma segunda linha — o "Join" apareceu debaixo do ícone na
   primeira inspeção visual. Ícone, números e verbo são todos opcionais: contagem
   fixa de colunas deixa buraco em toda linha que omite um.
4. **O servidor e2e serve CSS velho.** Duas medições de layout no `:4003`
   voltaram idênticas depois de eu reescrever o CSS. `make e2e.shots` roda
   `assets.build` antes; `npx playwright` direto não. Vale a memória
   `stale-e2e-server-port-4003`.
5. **`python str.replace` sem `count` triplicou um bloco de CSS.** O arquivo
   ficou com três cópias da regra do verbo e uma delas capturou
   `.action-list__trailing` numa lista de seletores, que passou a desenhar um
   painel em volta dos números. Medir o computed style foi o que apontou; olhar
   o screenshot só dizia "está estranho".
6. **`refute html =~ "disabled"` é um teste falso.** As classes Tailwind do
   botão (`disabled:opacity-50`) casam a string. Duas asserções minhas passavam
   por isso. Agora é Floki: `Floki.attribute("disabled")`.
7. **`i18n_machine_translate_po.py` mexeu em 131 entradas que não eram minhas.**
   Exatamente a memória `machine-translate-damages-untouched-entries`. Snapshot
   antes, diff de `msgstr` e `msgstr_plural` depois, reverter tudo que não fosse
   msgid novo — 131 revertidas, 195 mantidas (15 msgid × 13 locales).
8. **Depois do polib, refazer o merge.** `po.save()` reembrulha os `msgid` no
   estilo do polib e briga com o próximo `mix gettext.merge`. Rodar o merge de
   novo devolve o arquivo ao formato canônico do gettext sem perder `msgstr`.
9. **O motor errou o sentido em duas etiquetas do produto.** "Rooms" virou
   quarto de hotel em nove locales (`Quartos`, `Habitaciones`, `Chambres`,
   `Zimmer`, `客室案内`) e "Action List" virou `Artikel` em alemão. Foram para
   `scripts/i18n/glossary.py` junto com "Move up"/"Move down" — que o polonês
   tinha traduzido como reflexivo (`Przesuń się`). Rótulo curto é glossário.
10. **O catálogo `en` precisa de `msgstr` preenchido.** Entrada nova nasce vazia
    lá também, e `make i18n.placeholder.check` reprova qualquer msgid com
    `%{...}` e msgstr vazio. `msgstr = msgid` no `en`.

### Evidência visual

`make e2e.shots FILE=tests/chat-channel-list.spec.ts` e
`FILE=tests/chat-ui-features-channel.spec.ts -g "Feature 06"`:

- `row-is-the-door` — lista filtrada, um `Join` por linha
- `closed-room-row` — `Join` e `Request Access...` lado a lado na mesma lista
- `cold-channel-row` — sala fria, "Last used" e `Join` alinhados à direita

Toque conferido a 375×720 (spec descartável, apagada): a linha vira um cartão de
uma coluna e o verbo ocupa a largura inteira a 40px.

### Validação

- `make ci` — todos os checks verdes
- `chat-channel-list` 2/2, `chat-conversations-sidebar`,
  `chat-ui-features-channel` 4/4
- Os quatro portões de i18n: catalog / placeholder / quality / source-fallback

### O que fica para a próxima sessão

- **Fase 2 — Channel Central** é a próxima do plano.

### Correção da rodada de revisão

A primeira entrega desenhou o verbo como um `<span>` estilizado. Errado: é uma
face de botão feita à mão.

11. **O verbo é um `UI.Button` de verdade, irmão do press.** Eu tinha reescrito o
    bisel Win98 em CSS cru (`inset -1px -1px #0a0a0a…`) em vez de usar
    `shadow-retro-raised`, a classe que o `Button` usa — um segundo desenho do
    mesmo controle, livre para divergir. Agora o `<:cta>` renderiza
    `<.button size="sm">` ao lado do botão primário, dispara o evento da linha e
    carrega o ícone 16×16 que todo botão do app carrega. Continua HTML válido
    porque é irmão, não filho. O componente perdeu 30 linhas de CSS.
12. **Os quadros de números viraram `action_figure/1`.** `cl-meta-item` /
    `-label` / `-value` eram markup avulso dentro do `channel_list.ex`, e cada
    diálogo da Fase 3 tem uma caixa quase idêntica. Um componente, e o CSS do
    Channel List encolheu para busca + lista.
13. **`-g` contra um arquivo `describe.serial` não é o arquivo.** Reportei como
    flake um `sets mode +i` que caía na 1ª tentativa de
    `chat-ui-features-channel.spec.ts -g "Feature 06"`. Rodando o arquivo
    inteiro passa 4/4 de primeira: o `-g` tira o teste do encadeamento serial que
    o precede. O relato de flake era meu erro de invocação, não um defeito.

**Regra que sai daqui para a Fase 2 em diante:** nenhuma linha desenha um
controle. Verbo é `<:cta>`, ação secundária é `<:action>`, número é
`action_figure/1` — os três são componentes, e nenhum deles repinta um bisel.

---

## Fase 2 — Channel Central · CONCLUÍDA

Duas listas: os *access lists* (bans / exceções de ban / exceções de convite) e a
lista de acesso do ChanServ na aba Registration.

### A premissa do plano estava errada

O plano dizia "a linha ativa abre o detalhe da entrada (quem adicionou, quando)".
**Não existe detalhe para abrir** — "quem adicionou" e "quando" já são colunas da
própria linha. E as duas listas não são cartões: são tabelas de três e duas
colunas alinhadas, com uma única ação, destrutiva.

Converter para `ActionList` teria destruído a tabela para resolver um problema
que a tabela não tem. A regra que vale é a mesma — a ação pertence à linha — mas
o meio pede outra forma: **a tabela continua tabela e ganha uma coluna final com
o `Remove` de cada linha.** Não há seleção nenhuma.

### O que entrou

| Arquivo | |
|---|---|
| `components/ui/layout/action_list.ex` | `row_action/1` extraído — o controle que `<:action>` já renderizava, agora compartilhado com a tabela |
| `components/ui/dialogs/channel_central_dialog.ex` | coluna de ação nas duas tabelas; `selected`/`has_selection`/`can_remove?`/`removable?/2` removidos; `Remove` sai dos rodapés |
| `live/chat_live/components/channel_central_dialog.ex` | `cc_list_select` e `cc_cs_access_select` removidos, e os dois assigns de seleção junto |
| `assets/css/retrohex/dialogs/channel-central.css` | 4 regras de seleção apagadas; `cc-mobile-list-action` entra |
| `live/showcase_live/dialogs/channel_central_dialog_page.{ex,html.heex}` | |
| 2 testes de feature + `e2e/pages/ChatPage.ts` + `chat-ui-features-channel.spec.ts` | |
| `scripts/i18n/glossary.py` | `Remove %{nickname}` e `Remove %{mask}` curados |

### Aprendizados

14. **`row_action/1` é o que impede os dois meios de divergirem.** Um cartão e
    uma linha de tabela desenham o mesmo botão de remover; sem extrair, a segunda
    cópia nasceria no dia seguinte. `<:action>` do `ActionList` agora só delega.
15. **O handler parou de ler estado do socket.** `cc_remove_list_entry` e
    `cc_cs_access_remove` liam `channel_central_list_selected` /
    `channel_central_access_selected`; agora recebem `phx-value-nickname` da
    linha. O evento carrega o sujeito, e o sujeito não pode estar velho.
16. **Um teste inteiro deixou de fazer sentido e virou outro.** "7.4 switching
    access list type drops the stale selection" existia porque `Remove` agia
    sobre "o que estiver selecionado", e trocar de lista podia deixar o botão
    apontando para uma linha que saiu da tela. Um controle que pertence à linha
    **sai com ela** — o teste agora afirma exatamente isso.
17. **O rótulo com placeholder foi para o glossário, não para o motor.**
    `Remove %{nickname}` é duas palavras sem frase em volta, e alemão, holandês
    e japonês põem o verbo depois do sujeito. Curado à mão nos 13 locales.
18. **Menu Start no celular abre um nível por vez.** Perdi três tentativas
    tentando clicar `start-menu-item-open_channel_central` direto; é preciso
    abrir `start-menu-tools-submenu` antes. Está em `chat-mobile-desktop.spec.ts`
    (MB3) e eu não tinha lido.

### Evidência visual

- desktop: a tabela mantém `Mask | Set By | Set At` alinhados e ganha a coluna de
  remoção; `Add` continua com o painel
- toque (375×720): a linha vira cartão com os rótulos embutidos e o botão de
  remover numa linha própria, no alvo de 40px

19. **O Dialyzer pegou uma cópia que virou mentira.** `target in [nil, ""]`
    deixou de ser possível quando `target` passou a vir sempre do
    `phx-value-nickname` — `:exact_compare`, binário contra `nil`. As duas
    mensagens em volta diziam "Select a nickname", e não há mais o que
    selecionar: viraram "%{nickname} is not on this list." e "That row carries
    no nickname to remove.".
20. **O motor injetou um cabeçalho falso em três idiomas.** As novas frases
    saíram como `シリーズ\nその行は…`, `数据\n该行…`, `數據\n該行…` — o modo de
    falha "injected heading" que `make i18n.quality.check` existe para pegar — e
    o polonês devolveu o inglês. Corrigidos à mão nos oito locales afetados. O
    portão pegou; a tradução automática sozinha teria shipado.

### Validação

- `channel_central_feature_test.exs` + `chanserv_channel_central_feature_test.exs` — 37/37
- Playwright: `chat-channel-central`, `-exceptions`, `-sync`, `chat-ui-features-channel` — 7/7
- `make ci` verde

---

## Fase 3 — os editores lista + formulário · CONCLUÍDA

Os oito diálogos se separaram em dois grupos, e a divisão coincide exatamente com
o acoplamento de CSS que o plano tinha previsto:

| forma | diálogos | tratamento |
|---|---|---|
| **cartões** (`<button>` por linha) | Alias, Auto-Join, Auto-Respond, Highlight Words, Notify List | `ActionList`: o toque abre o formulário ao lado, `Remove` é `<:action>` |
| **tabelas** (colunas alinhadas, prefixo `ab-`) | Address Book, Ignore List, Nick Colors | coluna de ação como no Channel Central — **próxima sessão** |

Entregues em dois commits: primeiro os cinco de cartões, depois as três tabelas
juntas — compartilham CSS e não podiam sair separadas.

### Aprendizados

21. **Um `<:control>` entrou no componente por necessidade real.** A linha do
    Auto-Respond carrega um checkbox On/Off. Ela era um `<div role="button">`, o
    que escondia o problema; como `<button>` de verdade, um checkbox dentro é
    HTML inválido. `<:control>` renderiza conteúdo interativo como irmão do
    press — mesma razão que já valia para `<:action>`.
22. **O nome da lista não precisa de tradução nova.** Os cinco `aria-label` que
    escrevi ("Aliases", "Notify entries", …) voltaram errados do motor: pt_BR
    "Outros nomes", alemão "Anmeldungen", polonês "Pseudonimy". Cada diálogo já
    tem um título traduzido e revisado — "Alias Editor", "Notify List",
    "Auto-Join" — e usá-lo como rótulo da lista é ao mesmo tempo mais correto e
    zero tradução nova. Cinco msgid a menos.
23. **`phx-value-*` chega como string, e `==` não avisa.** `autorespond_dialog_delete`
    passou a receber a posição da linha; `remove_entry/2` compara com `==` contra
    um inteiro, então a regra simplesmente sobrevivia em silêncio. **O `make ci`
    passou verde** — quem pegou foi o Playwright. Consertado no evento e coberto
    por um teste de unidade que afirma o contrato dos dois lados.
24. **Uma spec descartável que abre cinco diálogos em sequência não funciona.**
    O diálogo anterior fica por cima do menu. Um teste por diálogo.

### Evidência visual

`alias`, `highlight`, `autojoin`, `autorespond`, `notify` — todos com o toque
abrindo o editor, `Remove` na linha e `Add` no rodapé. No Auto-Respond o checkbox
On/Off e o `Remove` convivem como irmãos do press.

Pendência estética anotada: em Highlight Words a linha "Own nick" (`hl-own-entry`,
uma lista à parte, sem ação) ficou com um desenho diferente das linhas migradas.
Não é regressão — é a vizinhança nova tornando visível uma diferença que já existia.

### Validação

- suíte web inteira: 2340 testes, 0 falhas
- Playwright: alias (3), autojoin (2), highlights (2), autorespond (3), notify,
  address-book — 25 no total
- `make ci` verde


### As três tabelas

Mesmo tratamento do Channel Central: coluna final com `Edit` e `Remove` da
própria linha, `Add` no rodapé, nenhuma seleção. O `crud_buttons` de três botões
virou `add_button` de um — o único que não tem linha a que pertencer.

### Aprendizados

25. **A lacuna de cobertura que o plano apontou não existia.** Escrevi no plano
    que "Nick Colors não tem spec Playwright" porque não há arquivo
    `chat-nick-color*.spec.ts`. O fluxo add/edit/remove está inteiro dentro de
    `chat-address-book.spec.ts`, mais um segundo teste para a cor aplicada à
    mensagem. Julguei pelo nome do arquivo em vez de pelo conteúdo, e isso teria
    custado uma spec duplicada.
26. **O helper genérico dos testes sobreviveu à mudança.** `ab_select(view,
    evento, nick)` casa `[phx-click=EVENTO][phx-value-nickname=NICK]` — a forma
    nova continua sendo exatamente isso, só com outro nome de evento. Os seis
    arquivos de teste precisaram de troca de nome, não de reescrita.
27. **Os testes "o botão acorda quando seleciono" descreviam o defeito.** Três
    deles (contatos, cores, notify) existiam só para afirmar que os controles
    ficavam cinza até haver seleção. Não dava para adaptá-los: o estado que
    descreviam deixou de existir. Viraram a afirmação oposta — cada linha carrega
    os próprios controles e nenhum deles nasce desabilitado.

### Evidência visual

`address-book`, `nick-colors`, `ignore-list` — colunas alinhadas preservadas,
lápis e X por linha, `Add` no rodapé.

### Validação

- 47 testes dos seis arquivos das três tabelas, 0 falhas
- Playwright: address-book (4), ignore (2) — 12 no total
- `make ci` verde

---

## Fase 4 — os três com ação além de editar · CONCLUÍDA

| diálogo | o que tinha | o que tem |
|---|---|---|
| **Perform** | `Edit / Remove / Up / Down` no rodapé | setas e `Remove` na linha; a posição vira o ícone da linha |
| **Timers** | `Edit / Stop`, cinza até selecionar | toque abre o editor; `Stop` na linha |
| **Custom Menus** | `Edit / Remove` no rodapé | toque abre o editor; `Remove` na linha |

Timers ganhou a **página de showcase** que era a única faltando do grupo.

### Aprendizados

28. **Reordenar era mesmo a sequência mais cara.** No rodapé, subir um comando
    custava selecionar, atravessar o diálogo, `Up`, atravessar de volta para ver.
    Na linha é uma prensa por passo, com as setas sempre na mesma posição —
    `disabled` na primeira e na última em vez de `:if`, ou os controles pulariam
    de lugar entre as linhas.
29. **`phx-value-*` como string mordeu de novo, em dois lugares.** `perform_move_up`,
    `perform_move_down`, `perform_remove` e `perform_edit` liam
    `socket.assigns.selected`, um inteiro; agora recebem a posição da linha, que
    chega como texto. Mesma armadilha do `autorespond_dialog_delete` na fase
    anterior — a terceira vez que aparece nesta migração.
30. **Um rótulo com cor própria não segue a linha selecionada.** `Command` ficou
    ilegível sobre o azul-marinho no Custom Menus. `.action-list__row--current`
    precisa de um `color: inherit` para cada rótulo que pinta a si mesmo —
    corrigido nos quatro diálogos que têm editor ao lado.
31. **`Remove` sem sujeito é um nome inútil para leitor de tela.** No Perform
    escrevi `label={dgettext("dialogs", "Remove")}` e três linhas ficaram com o
    mesmo nome acessível. Passou a nomear o comando mascarado, reusando o msgid
    `Remove %{name}` que já existia — zero string nova.
32. **O glossário precisa rodar depois da tradução automática, não antes.** O
    motor traduziu "Timers" como "Relógios" em pt_BR por cima do valor curado.
    `make i18n.quality.check` pegou como *glossary drift*; a ordem certa é
    extract → merge → machine → **glossary** → merge.

### Evidência visual

`perform` (badge de posição, setas com a primeira e a última desabilitadas),
`timers` (Every/Repeat/Next como figuras, `Stop` na linha), `custom-menus`
(rótulo legível na linha selecionada).

### Validação

- Playwright: perform (3), timer (3), custom-menus (2), ui-features-shell — 20
- `make ci` verde
