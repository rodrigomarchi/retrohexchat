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
