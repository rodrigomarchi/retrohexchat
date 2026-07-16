# Dialog Mobile Playbook

Data: 2026-07-16

Baseado nas iteracoes de Channel Central, Admin Console, Bot Management, Address Book, Account, Custom Menus, Perform, Alias, Highlight Words, Auto Respond, Timers, Notify List, URL Catcher, Sound Settings, Confirm/Paste Confirm, Kick Dialog, Invite Dialog, Nick Change Dialog, Mute Duration Dialog, Knock Request Dialog, Channel List Dialog, Flood Protection Dialog, User Lookup Dialog e Keyboard Shortcuts/Cheatsheet.

## Objetivo

Padronizar como elevar dialogs Win98 para uma experiencia unica mobile-first que tambem melhora desktop, sem perder densidade nem identidade visual.

Este playbook nao e uma lista de classes para copiar. Ele e um conjunto de decisoes de UX/UI, estrutura e validacao para aplicar dialog por dialog.

## Principios

- Mobile nao deve ser apenas desktop encolhido.
- Desktop nao e uma interface separada; e a mesma interface mobile-first usando melhor o espaco disponivel.
- Nao criar dois sistemas visuais dentro do mesmo dialog. Quando o layout muda por largura, os conceitos, componentes e hierarquia devem continuar os mesmos.
- A feature nao pode quebrar: mudanca visual precisa preservar nomes de campos, eventos, test ids e fluxos existentes.
- Ajustes compartilhados so entram em componentes globais quando os testes dos outros dialogs estiverem prontos para essa mudanca.
- Para cada dialog, validar comportamento e visual. Teste funcional nao substitui screenshot.

## Padroes Estabelecidos

### Tabs

Quando um dialog tem muitas tabs:

- Desktop pode manter tabs em layout compacto.
- Mobile deve evitar wrap em varias linhas.
- Usar faixa horizontal com `overflow-x`.
- Mostrar indicador visual de continuidade no lado direito, como fade + `>`, para o usuario perceber que pode rolar.
- Quando a aba ativa desloca a faixa para a direita, mostrar tambem affordance no lado esquerdo, como fade + `<`.
- Garantir que a aba ativa continue visualmente forte.

Atencao:

- Nao alterar roles globais de `Tabs` sem rodar a suite dos dialogs. Um experimento no Channel Central mostrou que helpers existentes ainda dependem de `getByRole("button")`.

### Listas E Dados Tabulares

Quando um dialog mostra entidades, configuracoes ou entradas editaveis:

- Preferir uma unica representacao mobile-first que tambem funcione bem no desktop.
- Usar tabela somente quando o dado for realmente matricial e comparativo.
- Para list editors, uma lista de entradas acionaveis costuma ser melhor que tabela em mobile e desktop.
- O campo principal vai em destaque na primeira linha.
- Metadados aparecem abaixo com label curto, como `Set By`, `Set At`, `Added By`.
- Evitar scroll horizontal como experiencia primaria.
- Preservar test ids por linha quando eles ja existem.
- Quando a linha vira `button`, controlar `aria-label` para que o nome acessivel represente a entrada, nao todo o texto interno livre.

### Conteudo De Referencia

Quando um dialog mostra conteudo estatico longo, como ajuda, atalhos ou cheatsheet:

- Nao usar tabela por reflexo. Se o usuario procura um item, a unidade visual deve ser o item.
- Organizar por categorias fortes e entradas escaneaveis.
- Em cada entrada, colocar o nome/acao como informacao primaria, metadado curto em destaque e descricao abaixo.
- Desktop pode abrir uma ou duas colunas por largura, mas a estrutura deve continuar igual ao mobile.
- Badges curtos, como teclas, precisam de `max-width: 100%` e quebra segura para nao criar overflow silencioso.
- Evitar headers repetitivos quando eles nao ajudam a tarefa; `Action/Keys/Description` consumia espaco e nao melhorava a busca visual no Cheatsheet.

### Formularios

Para formularios em dialogs:

- Inputs devem usar `min-width: 0` e largura flexivel no mobile.
- Texto longo deve ter preview/wrap ou textarea, nao depender de input single-line com scroll interno.
- Comandos e mensagens operacionais longas devem preferir textarea em add/edit, mesmo quando o valor salvo continua sendo string simples.
- Labels e valores longos precisam de `overflow-wrap: anywhere` quando podem vir de usuario, servidor ou timestamp.
- Campos curtos podem ocupar linhas mais densas em larguras amplas, mas a hierarquia e o componente devem continuar os mesmos.
- Inputs numericos em flex/grid precisam de `flex-basis` e `min-width` estaveis; largura nominal pode encolher sob pressao e deixar so o spinner visivel.
- Settings com label, input e unidade devem tratar cada setting como um bloco responsivo, nao como uma tabela de colunas rigidas.

### Botoes

Padrao de botoes em dialogs:

- Acoes principais ficam alinhadas a direita.
- Grupos OK/Cancel, Save/Clear, Add/Remove e Apply ficam alinhados a direita.
- Em largura apertada, input pode ocupar a linha inteira e botoes permanecem agrupados a direita na linha seguinte.
- Botoes destrutivos continuam distinguiveis, mas nao devem dominar a tela quando estao fora do fluxo principal.

### Dialogs Pequenos

Para confirms e prompts curtos:

- Nao usar fullscreen mobile quando o conteudo e uma decisao de uma ou duas frases.
- Preferir message box compacta: icone, pergunta, consequencia e acoes.
- Acoes continuam alinhadas a direita.
- A largura deve ser segura no mobile e compacta no desktop.
- O X do titlebar deve acionar a mesma semantica de Cancel quando o dialog possui estado no LiveComponent.
- Separar pergunta e consequencia em linhas distintas melhora decisao sem aumentar complexidade.
- Usar classe local opt-in para compactar, evitando mudar o `Dialog` global usado por surfaces maiores.
- Em notificacoes pequenas, separar evento e metadados: fato principal primeiro, depois canal/origem/motivo como detalhes escaneaveis.
- Quando o dialog representa uma fila server-owned, o X precisa mapear para uma acao de dominio, nao apenas esconder no cliente.

### Subdialogs

Para subdialogs dentro de uma janela:

- Overlay deve cobrir o painel correto.
- Preferir `scope={:window}` quando o subdialog pertence a uma desktop window e a taskbar mobile continua visivel.
- Container deve respeitar margem segura no mobile fullscreen.
- O form interno deve ser uma coluna flexivel (`flex`, `min-h-0`, `flex-1`, `flex-col`) para preservar titlebar e footer, deixando o body rolar.
- Botoes ficam alinhados a direita.
- O conteudo deve caber sem criar scroll horizontal.
- Validar foco, Escape, OK/Cancel e submit por Enter quando a feature espera isso.

### Scroll E Overflow

Checklist de overflow:

- Sem scroll horizontal no documento.
- Sem texto cortando controles adjacentes.
- Sem tab bar quebrando em multiplas linhas no mobile quando houver muitas tabs.
- Scroll interno deve ser explicito e util, nao consequencia de layout quebrado.
- Usar `overscroll-behavior: contain` em listas internas quando apropriado.
- Em listas baseadas em grid, validar o caso de uma unica entrada; o item nao deve esticar para ocupar toda a altura.
- Em desktop stacked mobile, `overflow-hidden` no root ainda pode acumular `scrollLeft` programatico; validar `scrollLeft` e retangulos dos ancestrais quando uma janela aparece deslocada.
- Result cards com acoes devem separar body rolavel e footer fixo para preservar o proximo passo do fluxo.

## Processo Por Dialog

1. Capturar baseline com Playwright em desktop e mobile.
2. Mapear tipos de superficie: tabs, tabelas, forms, action rows, subdialogs, destructive actions.
3. Escolher o trecho mais dificil do dialog primeiro.
4. Implementar uma interface unica mobile-first com classes locais prefixadas pelo dialog, evitando vazamento global.
5. Reusar os padroes deste playbook.
6. Capturar screenshots refinados.
7. Rodar testes funcionais do dialog.
8. Rodar uma suite ampla quando a mudanca tocar componentes compartilhados.
9. Registrar achados, decisoes e falhas externas no documento de auditoria/progresso.

## Ordem Recomendada

### Dialogs estruturantes

- Admin Console
- Bot Management
- Account
- Address Book
- Custom Menus
- Perform

Esses devem vir primeiro porque exercitam tabs, listas, forms e estados complexos.

### List editors

- Alias (concluido)
- Highlight Words (concluido)
- Auto Respond (concluido)
- Timers (concluido)
- Notify List (concluido)
- URL Catcher (concluido)
- Sound Settings (concluido)

Esses devem receber principalmente uma lista unica mobile-first, action rows a direita e subdialogs responsivos.

### Dialogs pequenos

- Confirm dialogs (concluido)
- Paste Confirm (concluido)
- Kick (concluido)
- Invite (concluido)
- Nick Change (concluido)
- Mute Duration (concluido)
- Knock Request (concluido)

Esses devem ser tratados depois, com foco em largura segura, botoes a direita, toque confortavel e teclado/foco.

## Validacao Minima

Para cada dialog trabalhado:

- `rtk mix format` nos arquivos alterados.
- `rtk mix compile`.
- Playwright funcional especifico do dialog, quando existir.
- Screenshot desktop e mobile.
- Checagem visual de:
  - tab overflow;
  - botoes alinhados;
  - tabelas/listas;
  - texto longo;
  - subdialogs;
  - ausência de scroll horizontal indevido.

## Licoes Do Channel Central

- Comecar pelo trecho mais dificil pode reduzir risco quando esse trecho concentra os padroes do restante.
- Melhorias locais com classes prefixadas reduzem blast radius.
- Mudar componente global de tabs sem preparar os testes causa regressao nos helpers existentes.
- O usuario precisa de affordance explicita para rolagem horizontal em tabs mobile.
- Alinhar botoes a direita melhora consistencia tanto no desktop quanto no mobile.
- Screenshot e inspecao visual pegam problemas que testes funcionais nao veem.

## Licoes Do Bot Management

- Child dialogs dentro de desktop windows nao devem cair embaixo da taskbar no mobile; `scope={:window}` manteve o modal dentro do workspace.
- Form sem coluna flexivel pode fazer o foco do primeiro input rolar o container externo e esconder o titlebar.
- Listas/tabelas com structs precisam normalizar o valor exibido e o `phx-value-*`; fallback que renderiza struct pode crashar LiveView.
- Tabs com muitas opcoes podem precisar de indicador de overflow nos dois sentidos, nao apenas no lado direito.
- Limpar fixtures E2E depois de falhas evita que screenshots seguintes parecam regressao visual.

## Licoes Do Address Book

- Desktop windows que atuam como dialogs precisam de uma superficie focavel e `focus_wrap` quando a expectativa de UX/teste e prender Tab dentro da janela.
- Evitar seletores mobile amplos como "todos os botoes do dialog"; eles podem atingir titlebar, color picker e controles auxiliares. Preferir action rows/forms especificos.
- Quando o dado realmente exige tabela, proteger colunas criticas com `white-space: nowrap` pode preservar densidade sem virar desktop encolhido.
- Cardlets mobile devem manter o dado principal forte e metadados com `data-label`; isso funcionou bem para Contacts, Notify, Nick Colors e Control.
- Em HEEx, nao duplicar atributo `class` em elementos com classe dinamica; a duplicacao pode esconder informacao visual critica, como swatch de cor.
- Validar foco por teclado faz parte do playbook quando a janela tem comportamento de dialog, nao apenas quando ha modal overlay.

## Licoes Do Account

- Dialogs sem tabelas ainda precisam do playbook completo: tabs, forms, action rows, texto longo e foco.
- Mensagens naturalmente longas devem usar textarea quando a feature permite, como Away Message.
- Regras mobile para inputs devem excluir `checkbox` e `radio`; aumentar todo `input` pode deformar controles Win98.
- `summary` com marcador nativo deve ser validado visualmente depois de qualquer regra de layout; `display: flex` removeu o marcador no Account.
- Superficie focavel com `tabindex="0"` pode criar outline azul de navegador. Remover esse outline localmente mantem a UX Win98 sem retirar foco.
- Screenshots refinados precisam ser inspecionados depois da primeira captura; a primeira versao do Account revelou regressao visual mesmo com teste funcional verde.

## Licoes Do Custom Menus

- Nao tratar desktop e mobile como dois sistemas. A lista de entradas virou um unico componente visual que escala para ambos.
- Um list editor pequeno pode ficar melhor tambem no desktop quando deixa de usar tabela e passa a mostrar entradas acionaveis.
- Form lateral deve ser um inspector responsivo: ao lado em largura ampla, abaixo no mobile, com a mesma estrutura e a mesma semantica.
- Fechamento explicito por `OK` e parte da UX de dialog/editor; depender apenas do X da janela deixa a acao menos clara e quebrou os testes existentes.
- A primeira proposta que mantinha tabela no desktop e cardlet no mobile foi rejeitada porque criava duas interfaces. Esse criterio deve guiar os proximos dialogs.

## Licoes Do Perform

- O padrao de lista unica mobile-first pode substituir tabelas em Commands e Auto-Join sem perder comportamento.
- A melhoria tambem deve aparecer no desktop: item selecionavel, comando quebravel e metadado claro tornam a edicao mais rapida que uma tabela tecnica.
- Conteudo de comando longo nao deve ficar preso em input single-line; textarea facilita revisao antes de salvar.
- Helpers E2E devem mirar `data-testid`/semantica da entrada, nao a tag antiga da tabela.
- Listas em grid precisam de `align-content: start` para que uma unica entrada nao vire um bloco alto demais.
- Footer `OK` em editor server-managed ajuda a fechar o ciclo visual do dialog, alem do X da janela.

## Licoes Do Alias

- Alias virou o molde base dos list editors menores: lista acionavel, form responsivo, estados de erro/warning e footer explicito.
- Expansion e conteudo de comando longo; usar textarea evita truncamento e melhora revisao antes de salvar.
- Form lateral no desktop e empilhado no mobile pode ser a mesma interface quando os componentes e a hierarquia sao os mesmos.
- Ao trocar tabela por linhas `button`, o `aria-label` deve ser estavel; caso contrario o texto interno pode fazer uma linha competir com botoes como `Edit`.
- Capturar erro de validacao e warning de recursao evita entregar apenas o caminho feliz visualmente polido.

## Licoes Do Highlight Words

- Color picker e parte do layout do dialog; precisa de area compacta e previsivel, nao ficar solto no rodape.
- Own nick pode ser uma entrada visual nao interativa, enquanto palavras customizadas usam a mesma linguagem visual como botoes.
- Preservar test ids por palavra/cor permite trocar tabela por lista sem quebrar o contrato funcional.
- OK em server-managed window precisa chegar ao LiveComponent; quando `phx-click` e string, o footer deve receber `phx-target`.
- Subdialogs de color picker precisam entrar nos screenshots porque overlay, paleta e botoes reagem diferente no mobile.

## Licoes Do Auto Respond

- Form lateral fixo deve ser tratado como risco alto; no mobile ele pode sair completamente da janela.
- Regras com trigger, channel, enabled e command funcionam melhor como entrada composta do que como tabela estreita.
- Command longo com variaveis deve usar textarea, mantendo o mesmo `name` para preservar submit e testes.
- Checkbox dentro de entrada acionavel e aceitavel quando o helper mira a entrada por test id e o checkbox continua localizavel.
- O padrao de list editor agora cobre entradas simples, entradas com cor e entradas com toggle/status.

## Licoes Do Timers

- Every, Repeat e Next sao metadados do timer; como colunas, eles competem com command e pioram mobile e desktop.
- Command de timer deve usar textarea no form, porque o usuario precisa revisar uma acao operacional antes de agendar.
- Preservar `timer-row-*`, `name="command"` e `data-testid="timer-command-input"` permitiu trocar tabela por lista sem quebrar o contrato funcional.
- OK em window server-managed segue o mesmo padrao dos outros list editors: evento no LiveComponent e `phx-target` explicito.
- Specs Playwright que sobem o mesmo webServer podem conflitar em `_build/e2e`; para validar dialogs, prefira execucao sequencial dos specs focados.

## Licoes Do Notify List

- Uma tabela pode esconder informacao importante mesmo quando cabe visualmente; a nota do buddy existia no dominio, mas nao aparecia no standalone dialog.
- Status, last seen e note funcionam melhor como uma entrada composta do que como colunas, porque o usuario escaneia por buddy.
- Footer explicito deve respeitar a semantica local: neste dialog, `Close` preservou o contrato funcional melhor que trocar para `OK`.
- Toggle rows devem permitir texto quebravel sem aumentar/deformar checkbox; regras mobile para inputs continuam excluindo checkbox/radio.
- Quando a entrada vira `button`, preservar `notify-list-row-*` e `aria-label` pelo nick mantem testes e acessibilidade estaveis.

## Licoes Do URL Catcher

- Visualizadores de conteudo capturado tambem podem usar lista unica mobile-first; o item principal era o URL, nao uma linha de tabela.
- Preview, URL, nick, channel e time pertencem ao mesmo objeto visual para reduzir busca ocular no desktop e no mobile.
- Sort pode sair do header de tabela e virar uma faixa de botoes, desde que `phx-value-column` e o comportamento sejam preservados.
- Em janelas client-managed sempre montadas, nao forcar footer server-managed; a arquitetura de fechamento faz parte do contrato.
- Fixtures de screenshot devem evitar formatos mais frageis que os testes funcionais, senao a auditoria falha por dado artificial e nao por UX.

## Licoes Do Sound Settings

- Configuracoes matriciais podem abandonar tabela quando a unidade mental do usuario e o evento.
- Uma entrada composta com select, toggle e preview melhora desktop e mobile quando a relacao entre controles fica local.
- Mobile-first precisa ser a regra base de CSS; desktop pode abrir colunas por media query, mas nao o contrario.
- Selects em cards precisam de screenshot com dropdown aberto, porque overlay pode esconder problemas de largura e clique.
- Grid de cards com controles empilhados precisa de `grid-auto-rows`/dimensoes estaveis; validar o clique real evita overlap invisivel.
- Page Objects devem escopar controles dentro da janela/dialog aberta, nao buscar `data-testid` globalmente quando a feature pode aparecer em mais de uma superficie.
- Quando o E2E serve CSS compilado, lembrar de rodar o build de assets depois de alterar a folha fonte antes de confiar no screenshot.

## Licoes Do Confirm/Paste Confirm

- Confirm curto precisa de message box compacta; fullscreen mobile criou grande area vazia e piorou a decisao.
- Nao foi necessario alterar o `Dialog` global: `cd-dialog-wrap` funciona como opt-in para prompts pequenos.
- Delete/Disconnect ficaram mais claros quando pergunta e consequencia foram separadas.
- Paste Confirm precisa preservar contexto da conversa; como compact modal, ele informa sem esconder a tela inteira.
- Titlebar X deve chamar o mesmo cancelamento do botao Cancel em dialogs stateful, senao o cliente fecha visualmente e o LiveComponent pode ficar aberto.
- Testes de dialog que operam em `#lobby` podem falhar por estado persistente; canal unico e melhor quando a feature nao depende do lobby.
- Validacao visual deve incluir estados de warning artificiais no showcase e fluxo real no app.

## Licoes Do Kick Dialog

- Message box compacta tambem vale para notificacoes curtas, nao apenas confirms.
- Kick precisa de fluxo real alem do showcase, porque o payload vem de PubSub e a fila LiveComponent controla o dismiss.
- Renderizar canal, operador e motivo como detalhes separados melhora desktop e mobile mais que uma frase corrida.
- Helpers de payload devem aceitar o nome real do dominio (`:operator`) e aliases legados (`:kicker`) quando o componente ja era usado de forma divergente.
- X/Escape/click-away precisam drenar a fila pelo mesmo `on_dismiss` do OK; esconder so no cliente pode deixar estado vivo.
- E2E mobile nao deve esperar sidebars escondidas, mesmo quando o DOM existe. Use sinais de dominio ou o proprio dialog.

## Licoes Do Invite Dialog

- Invite recebido e Invite Channel Picker devem ser tratados juntos, porque a feature tem uma superficie para receber e outra para enviar convite.
- Uma lista compacta de convites substitui melhor as mini-windows internas: canal, inviter e acoes ficam no mesmo objeto visual.
- Join/Ignore continuam por item, mas o X do dialog precisa resolver a fila; no Invite, isso significa ignorar o convite do topo, preservando a semantica de Escape.
- Picker curto sem teclado textual nao deve usar fullscreen mobile; target, select e acoes cabem melhor em message/form box compacta.
- Long press na nicklist faz parte da auditoria mobile do picker, porque esse e o gesto real usado pela app.
- O overlay de origem pode permanecer atras do modal em mobile, mas o dialog precisa se manter legivel, compacto e dominante.

## Licoes Do Nick Change Dialog

- Form curto com senha opcional pode ser compacto no mobile se o campo mantiver altura e fonte seguras.
- Estados de erro precisam entrar na captura visual; eles mudam altura, cor e hierarquia da action row.
- Em LiveComponent stateful, o X deve chamar o mesmo cancelamento do botao Cancel para limpar target, senha e erro.
- Target, aviso operacional e erro devem ser blocos distintos. Isso melhora leitura no desktop e no mobile.
- Fluxo real de nick registrado e necessario para validar password/error; showcase sozinho nao cobre o lifecycle NickServ.

## Licoes Do Mute Duration Dialog

- Na ausencia de showcase, a auditoria deve usar o fluxo real e registrar essa lacuna.
- Titlebar com dado dinamico longo e fragil; mover o alvo para o body melhora truncamento e leitura.
- Prompt curto com input textual pode ser compacto no mobile quando o campo e os botoes seguem dimensoes touch-safe.
- Capturar estado preenchido evita confundir placeholder com valor real.
- Context menu mobile precisa ser auditado pelo gesto real, como long press na nicklist.

## Licoes Do Knock Request Dialog

- Fluxo real via Channel List e necessario; showcase isolado nao cobriria canal invite-only, selecao e submit real.
- Audits mobile nao devem depender de sidebars ou menus visiveis, porque eles podem estar escondidos por design. `/list` abriu a mesma superficie de forma estavel.
- Target card tambem funciona para canal: label e valor quebravel deixam o alvo mais claro que uma frase `Channel: #nome`.
- Contador de limite deve ficar visualmente subordinado ao textarea que ele valida.
- Form curto com textarea pode ser compacto no mobile quando altura, max-height e botoes touch-safe ficam definidos.

## Licoes Do Channel List Dialog

- Se a tarefa primaria e selecionar um item, tabela pode ser a abstracao errada mesmo no desktop.
- Canal, topic, users e mode pertencem ao mesmo objeto visual; separar em colunas estreitas piorou leitura e cortou topic no mobile.
- Preservar `data-testid` na entrada permite trocar `tr` por `button` sem quebrar page objects.
- Selecionar uma entrada com cor forte exige revisar contraste de chips internos; nem todo texto interno deve herdar branco.
- Em specs visuais com `phx-debounce`, aguarde tambem a ausencia de itens antigos para nao fotografar estado intermediario.

## Licoes Do Flood Protection Dialog

- Um dialog pode estar correto internamente e ainda aparecer quebrado por causa do shell. Neste caso, o problema era `#chat-desktop.scrollLeft=101` apos abrir via Tools no mobile.
- `overflow-hidden` nao basta para impedir scroll programatico; o modo stacked precisa zerar scroll interno e evitar que o desktop root vire scroll container horizontal.
- Medir `getBoundingClientRect` dos ancestrais e `scrollLeft` do shell e parte da auditoria quando o screenshot mostra deslocamento global.
- Fieldsets de configuracao funcionam melhor como blocos de settings do que como linhas rigidas label/input/unit.
- Inputs numericos precisam de dimensoes estaveis em flex, senao o spinner nativo consome o pouco espaco restante.
- A geometria desktop tambem deve ser revista depois da refatoracao mobile-first; o Flood ficou melhor mais largo e mais baixo.

## Licoes Do User Lookup Dialog

- Form curto dentro de desktop window pode continuar fullscreen no mobile quando o resultado e potencialmente longo; o importante e que o estado vazio e o resultado sejam intencionais.
- Result card precisa de body rolavel e action row fixa quando as acoes `Whowas`, `Query` e `Clear` sao parte do fluxo principal.
- `dl` de duas colunas deve virar label sobre valor no mobile para labels longos como `Shared channels` e `Quit message`.
- O form acima do resultado deve encolher depois da busca; repetir uma area de entrada grande rouba espaco do resultado.
- Testes E2E devem acompanhar o contrato visual atual. Se a UI virou card estruturado, specs procurando output textual antigo precisam ser atualizados.
- Nao rodar specs Playwright focados em paralelo neste ambiente e2e local; porta e build compartilhados podem falhar antes do teste real.

## Licoes Do Keyboard Shortcuts/Cheatsheet

- Conteudo de referencia longo merece padrao proprio: o usuario escaneia uma lista de itens, nao compara uma matriz.
- Uma lista composta melhorou desktop e mobile ao mesmo tempo: acao, badge de tecla e descricao ficaram no mesmo objeto visual.
- Desktop pode ganhar densidade com grid de duas colunas sem criar uma interface diferente.
- No mobile, deixar `flex-wrap` decidir quando a tecla quebra foi melhor que forcar sempre acao e tecla em linhas separadas.
- `kbd` precisa ser tratado como conteudo potencialmente longo; sem `max-width` e `overflow-wrap`, atalhos P2P podem criar overflow.
- A auditoria visual do dialog tambem pode revelar tema do shell: o menu Help mobile nao foi caminho estavel, enquanto `Ctrl+Shift+/` abriu o dialog corretamente.
