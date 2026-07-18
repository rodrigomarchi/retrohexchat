# Progresso - Dialogs Mobile

Data: 2026-07-16

## Objetivo

Aplicar o `Dialog Mobile Playbook` dialog por dialog, melhorando mobile e desktop sem quebrar fluxos existentes.

## Estado Atual

- Concluido: Channel Central.
- Concluido: Admin Console.
- Concluido: Bot Management.
- Concluido: Address Book.
- Concluido: Account.
- Concluido: Custom Menus.
- Concluido: Perform.
- Concluido: Alias.
- Concluido: Highlight Words.
- Concluido: Auto Respond.
- Concluido: Timers.
- Concluido: Notify List.
- Concluido: URL Catcher.
- Concluido: Sound Settings.
- Concluido: Confirm/Paste Confirm.
- Concluido: Kick Dialog.
- Concluido: Invite Dialog.
- Concluido: Nick Change Dialog.
- Concluido: Mute Duration Dialog.
- Concluido: Knock Request Dialog.
- Concluido: Channel List Dialog.
- Concluido: Flood Protection Dialog.
- Concluido: User Lookup Dialog.
- Concluido: Keyboard Shortcuts/Cheatsheet.
- Revisao registrada: primeiros dialogs estruturantes em `docs/plans/dialogs-first-pass-review.md`.
- Frente P2P/Conferencia absorvida pelo plano de media sessions: P2P Stats deixou de ser janela independente e agora vive como secao do console P2P unificado.

## Registro

### Channel Central

Documento: `docs/plans/dialogs-channel-central-mobile-audit.md`

Entregue:

- Primeiro playbook pratico para tabs, tabelas/listas, action rows e subdialogs.
- Tabs mobile com overflow horizontal e indicador.
- Tabelas administrativas convertidas para cardlets mobile.
- Botoes alinhados a direita.
- Screenshots baseline/refined em desktop e mobile.

### Admin Console

Documento: `docs/plans/dialogs-admin-console-mobile-audit.md`

Entregue:

- Aplicacao do padrao em dialog com nove tabs.
- Forms inline e outputs densos estabilizados em mobile.
- Tabs deixam de quebrar em varias linhas.
- Suite admin funcional focada passou com 14 testes.
- `chat-ui-features-admin.spec.ts` ainda tem falha preexistente fora do escopo em `Start solo arcade`.

### Bot Management

Documento: `docs/plans/dialogs-bot-management-mobile-audit.md`

Entregue:

- Split-view preservado no desktop e transformado em fluxo stacked no mobile.
- Channels e Commands viraram cardlets mobile.
- Tabs mobile ganharam affordance de overflow nos dois sentidos.
- New Bot e Add Command usam `scope={:window}` e form flex column, preservando titlebar/footer acima da taskbar.
- Bug funcional corrigido: renderizacao de `BotChannelConfig` nao tenta mais renderizar struct como HTML.
- Suite funcional de bots passou com 8 testes.
- Reachability UI de Bot Management passou.

### Address Book

Documento: `docs/plans/dialogs-address-book-mobile-audit.md`

Entregue:

- Contacts, Notify, Nick Colors e Control preservam tabela compacta no desktop e viram cardlets no mobile.
- Tabs mobile ganharam overflow horizontal com indicadores nos dois sentidos.
- Add/Edit/Remove e acoes de Control ficaram alinhadas a direita.
- Subdialogs mantiveram titlebar/footer e ganharam alvos melhores no mobile para forms e color picker.
- Bug visual corrigido: swatch de Nick Colors agora renderiza a classe de cor junto com a classe base.
- Foco por Tab no Address Book passou a ficar preso dentro do dialog.
- Suite funcional de Address Book passou com 5 testes.

### Account

Documento: `docs/plans/dialogs-account-mobile-audit.md`

Entregue:

- Register/Login, Profile, Presence e User Modes usam tabs mobile com overflow horizontal e indicadores.
- Action rows e grupos Save/Clear, Set/Clear, Apply e Drop ficaram padronizados a direita com alvos melhores.
- Presence passou a usar textarea para Away Message, evitando truncamento de mensagem real longa.
- Profile ganhou linha de nickname responsiva e footer de bio mais robusto.
- Wrapper focavel com `focus_wrap` foi aplicado ao conteudo da janela.
- Ajustes visuais evitaram outline azul de navegador, preservaram marcador nativo do Ghost Session e impediram deformacao de checkboxes.
- Gate funcional Account Feature 01 passou.

### Custom Menus

Documento: `docs/plans/dialogs-custom-menus-mobile-audit.md`

Entregue:

- Tabela foi substituida por uma lista unica mobile-first usada em desktop e mobile.
- Desktop ganhou item selecionado mais escaneavel, comando com quebra legivel, empty state e form lateral mais organizado.
- Mobile usa a mesma lista e o mesmo form, empilhados sem corte lateral.
- Add/Edit/Remove, Save/Cancel e OK ficam alinhados a direita.
- Foi adicionado `OK` explicito para fechar a janela server-managed.
- Suite funcional Custom Menus passou com 2 testes.

### Perform

Documento: `docs/plans/dialogs-perform-mobile-audit.md`

Entregue:

- Commands e Auto-Join deixaram de ser tabelas tecnicas e viraram listas unicas mobile-first usadas tambem no desktop.
- Comandos longos agora quebram linha na lista e usam textarea nos subdialogs de add/edit.
- Desktop ganhou editor mais legivel, item selecionado claro e footer `OK` explicito.
- Mobile manteve a mesma hierarquia visual, sem interface paralela.
- Helpers E2E passaram a localizar entradas por `data-testid`, nao por tag `tr`.
- Suite funcional Perform passou com 2 testes.

### Alias

Documento: `docs/plans/dialogs-alias-mobile-audit.md`

Entregue:

- Tabela foi substituida por lista unica mobile-first usada tambem no desktop.
- Expansion agora quebra linha na lista e usa textarea no add/edit.
- Desktop ganhou form lateral responsivo; mobile usa o mesmo form empilhado.
- Erro de validacao e warning de recursao entraram na captura visual.
- Linha selecionavel recebeu `aria-label` estavel para nao competir com botoes por role.
- Suite funcional Alias focada passou com 3 testes.

### Highlight Words

Documento: `docs/plans/dialogs-highlight-mobile-audit.md`

Entregue:

- Tabela foi substituida por lista unica mobile-first usada tambem no desktop.
- Own nick e palavras customizadas viraram entradas com cor como metadado visual.
- Add/Edit/Remove ficaram agrupados a direita.
- Paleta de cores ficou compacta e enquadrada.
- Subdialogs mantiveram Enter/Escape e receberam classes locais para mobile.
- OK explicito fecha a janela server-managed com `phx-target` correto.
- Suite funcional Highlight focada passou com 6 testes.

### Auto Respond

Documento: `docs/plans/dialogs-autorespond-mobile-audit.md`

Entregue:

- Tabela foi substituida por lista unica mobile-first usada tambem no desktop.
- Cada regra mostra trigger, On/Off, channel, position e command quebravel.
- Command no form virou textarea.
- Form lateral fixo virou inspector responsivo, lateral no desktop e largura total no mobile.
- Helpers E2E passaram de `tr` para `autorespond-rule-row`.
- OK explicito fecha a janela server-managed.
- Suite funcional Auto Respond focada passou com 5 testes.

### Timers

Documento: `docs/plans/dialogs-timers-mobile-audit.md`

Entregue:

- Tabela foi substituida por lista unica mobile-first usada tambem no desktop.
- Cada timer mostra nome, Every, Repeat, Next e command quebravel no mesmo item.
- Command no form virou textarea, preservando `name` e `data-testid` existentes.
- Form virou inspector responsivo, lateral no desktop e largura total no mobile.
- Add/Edit/Stop, Save/Cancel e OK ficam alinhados a direita.
- OK explicito fecha a janela server-managed.
- Suite funcional Timers focada passou com 3 testes; Feature 08 shell passou isolada.

### Notify List

Documento: `docs/plans/dialogs-notify-list-mobile-audit.md`

Entregue:

- Tabela standalone foi substituida por lista unica mobile-first usada tambem no desktop.
- Cada buddy mostra nickname, Online/Offline, Last Seen e Note no mesmo item.
- Nota passou a aparecer no standalone Notify List, nao apenas via comando/Address Book.
- Add/Edit note virou textarea, preservando `name` e ids existentes.
- Add/Edit/Remove e Close ficam alinhados a direita.
- Close explicito fecha a janela server-managed sem depender apenas do X.
- Suites funcionais Notify commands/settings passaram com 6 testes; gate shell focado passou com 1 teste.

### URL Catcher

Documento: `docs/plans/dialogs-url-catcher-mobile-audit.md`

Entregue:

- Tabela foi substituida por lista unica mobile-first usada tambem no desktop.
- Cada URL mostra link completo quebravel, preview title, Nick, Channel e Time no mesmo item.
- Sort headers viraram faixa compacta de botoes, preservando eventos e `phx-value-column`.
- Filter/search ganharam wrap responsivo sem criar interface separada.
- Contrato `url-catcher-row`, `data-url` e `url-catcher-preview-title` foi preservado.
- Janela client-managed sempre montada continuou fechando pelo titlebar.
- Suite funcional URL Catcher, seguranca de links, Tools menu e menu/atalho parity passaram com 4 testes.

### Sound Settings

Documento: `docs/plans/dialogs-sound-settings-mobile-audit.md`

Entregue:

- Tabela de eventos foi substituida por lista unica mobile-first usada tambem no desktop.
- Cada evento mostra nome, Play, Sound e Flash no mesmo item, preservando callbacks/test ids.
- Desktop ganhou grid de duas colunas quando ha largura; mobile empilha sem truncar Preview/Flash.
- Dropdown de som foi validado aberto em desktop e mobile.
- Helpers E2E passaram a escopar controles dentro da janela Sound Settings.
- Ajuste de `grid-auto-rows` corrigiu overlap do Flash com o proximo card no mobile.
- Lista mobile voltou a ocupar o espaco restante da janela, com OK/Cancel/Apply alinhados a direita no rodape.
- Suite funcional Sound Settings, Tools menu, Conversation mute e Local storage isolation passaram com 6 testes.

### Confirm/Paste Confirm

Documento: `docs/plans/dialogs-confirm-paste-mobile-audit.md`

Entregue:

- Generic Confirm, Delete Confirm, Disconnect Confirm e Paste Confirm ganharam padrao compacto `cd-*`.
- Confirms pequenos deixam de virar tela inteira vazia no mobile.
- Desktop preserva compacidade e ganha estrutura de message box com icone, copia e consequencia.
- Paste flood usa callout local para warning sem estourar largura.
- O X do titlebar agora aciona o mesmo cancelamento de Cancel nos dialogs stateful.
- Delete/Disconnect separam pergunta e consequencia para decisao mais clara.
- Teste de delete confirm foi isolado em canal unico para nao depender do historico persistente de `#lobby`.
- Captura visual refinada passou; Delete, Logout, Search navigation e Flood protection passaram com 5 testes funcionais.

### Kick Dialog

Documento: `docs/plans/dialogs-kick-mobile-audit.md`

Entregue:

- Kick Dialog deixou de virar tela inteira vazia no mobile.
- Desktop manteve compacidade e ganhou leitura por message box com canal, operador e motivo.
- Bug visual/funcional corrigido: o componente agora le `:operator`, payload real da fila, alem de `:kicker`.
- X do titlebar, Escape e click-away passam pelo mesmo `on_dismiss` do OK quando existe fila LiveComponent.
- Motivo longo quebra dentro do dialog sem scroll horizontal.
- Teste unitario do KickQueueDialog passou a validar operador, motivo, consequencia e evento de dismiss.
- Captura visual refinada passou em showcase e fluxo real; Channel moderation passou com 3 testes.

### Invite Dialog

Documento: `docs/plans/dialogs-invite-mobile-audit.md`

Entregue:

- Invite recebido deixou de virar fullscreen vazio no mobile.
- Convites pendentes viraram lista unica com canal, inviter e acoes, melhorando desktop e mobile.
- Join/Ignore ficam alinhados a direita e preservam `invite-join-*`/`invite-ignore-*`.
- X do titlebar agora ignora o convite do topo via `invite_ignore`, alinhando com a semantica de Escape.
- Multi invite usa lista compacta com scroll interno quando necessario, sem mini-windows empilhadas.
- Invite Channel Picker tambem ficou compacto, com target/select/acoes organizados e botoes a direita.
- Captura visual refinada passou em showcase e fluxo real; Invite, UI channel features e Ignore notifications passaram com 7 testes E2E.

### Nick Change Dialog

Documento: `docs/plans/dialogs-nick-change-mobile-audit.md`

Entregue:

- Nick Change deixou de virar fullscreen vazio no mobile.
- Desktop ganhou estrutura mais clara para target, aviso NickServ, senha e erro.
- X do titlebar agora usa o mesmo cancelamento server-owned do botao Cancel.
- Campo de senha recebeu dimensao/fonte segura no mobile.
- Estado de erro foi validado em showcase e fluxo real com nick registrado.
- Captura visual refinada passou em showcase e fluxo real; Identity e NickServ passaram com 5 testes E2E.

### Mute Duration Dialog

Documento: `docs/plans/dialogs-mute-duration-mobile-audit.md`

Entregue:

- Mute Duration deixou de virar fullscreen vazio no mobile.
- Titlebar ficou estavel (`Mute User`), e nick alvo virou bloco proprio no body.
- Campo de duracao e hint ficaram agrupados e touch-safe.
- OK/Cancel ficam alinhados a direita.
- Auditoria foi feita pelo fluxo real, ja que nao ha showcase dedicado.
- Captura visual refinada passou em desktop/mobile; Channel UI features passou com 4 testes E2E.

### Knock Request Dialog

Documento: `docs/plans/dialogs-knock-request-mobile-audit.md`

Entregue:

- Knock Request deixou de virar fullscreen vazio no mobile.
- Canal alvo virou bloco proprio no body, com label e valor quebravel.
- Textarea, contador, erro e acoes ficaram agrupados como um form compacto.
- Send Request/Cancel ficam alinhados a direita e preservam os `data-testid` existentes.
- Auditoria foi feita pelo fluxo real via `/list`, porque nao ha showcase dedicado.
- Captura visual refinada passou em desktop/mobile; Membership, UI channel features, Channel knock e Channel List passaram com 16 testes.

### Channel List Dialog

Documento: `docs/plans/dialogs-channel-list-mobile-audit.md`

Entregue:

- Channel List deixou de usar tabela para uma tarefa de selecao.
- Canais viraram entradas compostas com nome, topic, users, mode e badge `+i`.
- Mobile deixou de cortar topic e colunas; desktop ficou mais escaneavel.
- Search, loading, empty state e action row receberam classes locais `cl-*`.
- Join e Request Access preservam eventos/test ids e seguem alinhados a direita.
- Captura visual refinada passou em desktop/mobile; Channel List, Membership, UI Channel Features, Dialog Close e View Menu passaram com 23 testes.

### Flood Protection Dialog

Documento: `docs/plans/dialogs-flood-protection-mobile-audit.md`

Entregue:

- Corrigido bug estrutural do mobile stacked: abrir via Tools podia deixar `#chat-desktop.scrollLeft` diferente de zero e deslocar header, workspace, taskbar e dialog para fora da viewport.
- `WindowManagerHook` agora zera scroll interno do desktop em modo stacked; CSS do root stacked usa `overflow: clip`.
- Form de settings virou uma interface unica `fp-*`, mobile-first e tambem melhor no desktop.
- Inputs numericos ganharam dimensoes estaveis para nao encolherem ate o spinner.
- Desktop ganhou geometria padrao mais proporcional (`560x440`), com grupos mais legiveis e menos vazio.
- Captura visual refinada passou em desktop/mobile; Flood Protection, Tools Menu e Mobile Desktop passaram com 8 testes.

### User Lookup Dialog

Documento: `docs/plans/dialogs-user-lookup-mobile-audit.md`

Entregue:

- Form de nickname ficou compacto e alinhado ao mesmo fluxo no desktop e mobile.
- Result card ganhou body rolavel e action row fixa, evitando Clear/Query fora da janela no desktop.
- Rows do resultado usam duas colunas no desktop e label sobre valor no mobile, evitando quebra ruim de labels longos.
- Estado default ganhou empty state simples para reduzir a tela fullscreen vazia.
- `chat-whowas.spec.ts` foi atualizado para o contrato atual de result card estruturado.
- Captura visual refinada passou em desktop/mobile; User Lookup, Whois, Whowas, Tools Menu e Context Menus passaram com 20 testes.

### Keyboard Shortcuts/Cheatsheet

Documento: `docs/plans/dialogs-cheatsheet-mobile-audit.md`

Entregue:

- Tabela de atalhos foi substituida por lista unica mobile-first usada tambem no desktop.
- Cada atalho mostra acao, badge de tecla e descricao no mesmo cardlet.
- Desktop usa grid de duas colunas quando ha largura, mantendo a mesma hierarquia do mobile.
- Mobile deixou de comprimir `Action`/`Keys`/`Description` em tres colunas e passou a quebrar naturalmente atalhos longos.
- Janela recebeu geometria mais proporcional (`600x500`, `min_width=360`) e classes locais `cs-*`.
- Auditoria registrou que o menu Help mobile nao e caminho estavel para abrir o dialog; `Ctrl+Shift+/` foi o caminho confiavel no fluxo real.
- Captura visual refinada passou em desktop/mobile; Cheatsheet, Keyboard shortcuts e Menu/Toolbar parity passaram com 3 testes E2E.

## Aprendizados Atuais

- Cada dialog precisa de screenshot antes/depois; testes funcionais nao pegam todos os problemas de affordance e camada.
- Classes locais prefixadas (`cc-*`, `ac-*`, `bm-*`) permitem evoluir sem alterar componentes globais cedo demais.
- Tabs em dialogs densos devem ter scroll horizontal mobile com indicador visivel; quando a aba ativa desloca a faixa, o indicador precisa existir tambem a esquerda.
- Subdialogs dentro de desktop windows devem respeitar o workspace mobile, nao o viewport inteiro, quando a taskbar segue visivel.
- Forms com header/footer precisam ser flex column para evitar foco rolando titlebar para fora da tela.
- Fixtures E2E temporarias devem ser limpas, principalmente quando uma falha interrompe o `finally`.
- Desktop windows que funcionam como dialogs precisam de superficie focavel e `focus_wrap`, senao o Tab pode escapar mesmo com a janela aberta.
- Seletores mobile de botoes devem ser especificos; regras amplas podem atingir titlebar, color picker e controles que nao fazem parte da action row.
- Dados que realmente exigem tabela podem precisar de nowrap seletivo em colunas criticas, mas list editors devem buscar uma representacao unica mobile-first.
- Regras mobile para inputs precisam excluir checkbox/radio; controles binarios tem dimensoes proprias no Win98.
- `summary` com marcador nativo nao deve receber `display: flex` sem validar screenshot.
- Foco programatico pode precisar remover apenas o outline visual local, sem remover a superficie focavel.
- O criterio do plano e interface unica mobile-first que escala para desktop; nao tabela desktop + alternativa mobile.
- List editors podem abandonar tabela quando a entrada acionavel melhora a UX tambem no desktop.
- Testes funcionais podem revelar lacunas de UX, como ausencia de fechamento explicito por `OK`.
- Conteudo de comando longo deve usar textarea nos subdialogs, porque truncamento em input single-line prejudica mobile e desktop.
- Quando uma lista mobile-first usa grid, validar o caso de uma unica entrada; `align-content: start` evita item esticado.
- Helpers E2E devem representar a intencao da UI por test id/semantica, nao a tag estrutural antiga.
- Quando uma entrada vira `button`, controlar o `aria-label` evita conflito com seletores por role e melhora a semantica.
- Estados de erro e warning precisam de screenshot; eles podem ter densidade e wrapping diferentes do caminho feliz.
- Color pickers precisam ser tratados como parte do layout, com area compacta e previsivel em mobile e desktop.
- Em LiveComponent, OK de window server-managed precisa de target correto quando o callback e string.
- Form lateral fixo e um risco alto nos list editors; ele deve virar inspector responsivo.
- Entradas acionaveis podem conter checkbox/status/metadados sem voltar para tabela, desde que o contrato de teste seja preservado.
- Metadados temporais como Every/Repeat/Next ficam mais legiveis como metadados da entrada do que como colunas estreitas.
- Specs Playwright com webServer compartilhado podem disputar `_build/e2e`; quando o objetivo e validar dialog especifico, rodar specs focadas em sequencia evita ruido.
- Suites amplas podem falhar antes do alvo por expectativas externas; registrar o bloqueio e rerodar o teste focado mantem o ciclo auditavel.
- List editor nao deve esconder dados importantes do dominio; Notify List ja tinha `note`, mas a tabela standalone nao exibia.
- Footer explicito pode ser `Close` quando essa e a semantica do dialog e o contrato funcional existente.
- Visualizadores de conteudo capturado tambem podem abandonar tabela quando o usuario escaneia por item, como URL, preview e origem.
- Sort nao precisa depender de header de tabela; pode virar faixa de botoes preservando o mesmo evento.
- Janelas client-managed sempre montadas devem manter fechamento client-side quando isso e parte da arquitetura da feature.
- Configuracoes matriciais podem virar entradas compostas quando a unidade mental e o evento; isso melhora mobile e desktop.
- Selects dentro de cards precisam de screenshot com dropdown aberto, porque overlay e foco se comportam diferente do estado fechado.
- Grid mobile com controles empilhados precisa de auto-rows/dimensoes estaveis; sem isso, o conteudo pode ficar clicavel fora do card visual.
- Helpers E2E de dialog devem escopar controles pela janela aberta, principalmente quando os `data-testid` sao genericos por feature.
- Depois de mudar CSS fonte, validar se o E2E esta usando a folha compilada; neste ciclo foi necessario `assets.build` no app web.
- Dialog pequeno precisa de tratamento proprio: fullscreen mobile e correto para forms grandes, mas ruim para confirms curtos.
- Uma classe opt-in no wrapper do dialog permite compactar confirms sem alterar o comportamento dos dialogs grandes.
- Em dialogs stateful, titlebar X deve preservar a mesma semantica de Cancel para nao deixar estado aberto no LiveComponent.
- Specs que usam `#lobby` e fazem assercoes globais podem falhar por historico persistente; preferir canal unico quando a feature nao depende do lobby.
- Notificacoes pequenas tambem precisam de tratamento compacto; Kick mostrou que message box vale para aviso, nao so confirmacao.
- Showcase nao valida payload real de LiveComponent/PubSub; fluxo real e necessario quando o dialog nasce de uma fila.
- Metadados de evento devem aparecer como fatos separados quando o usuario precisa entender o que aconteceu: canal, operador e motivo.
- Esperas E2E mobile nao devem depender da visibilidade de sidebars que ficam escondidas por design.
- Convites recebidos e picker de envio devem ser avaliados juntos, porque fazem parte da mesma feature de Invite.
- Dialog com fila server-owned precisa transformar X em acao de dominio; no Invite, X ignora o convite do topo.
- Mini-windows dentro de dialogs pequenos pesam demais; lista composta preserva identidade Win98 sem duplicar titlebars.
- Mobile context menu deve ser auditado com o gesto real da app, como long press na nicklist.
- Form curto com senha opcional pode ser compacto no mobile, desde que o input mantenha fonte/altura seguras.
- Estados de erro precisam entrar nas capturas, porque mudam hierarquia e podem empurrar os botoes.
- Separar target, aviso operacional e erro melhora desktop tambem, nao so mobile.
- Quando nao ha showcase, a auditoria deve usar o fluxo real e registrar essa ausencia no documento.
- Titlebar nao deve carregar dado dinamico longo se o dado pode virar bloco proprio no body.
- Estado preenchido tambem precisa de screenshot quando placeholder e valor podem parecer parecidos.
- Audits mobile nao devem depender de sidebar/menu visivel; Knock Request mostrou que `/list` e caminho real mais estavel para abrir a Channel List.
- Contadores de limite devem ficar subordinados ao campo correspondente, nao soltos perto do footer.
- Quando a tarefa e selecao, tabela pode ser pior no desktop tambem; Channel List ficou melhor como lista de objetos.
- Specs visuais com `phx-debounce` devem esperar a ausencia do item antigo, nao so a presenca do item desejado.
- `overflow-hidden` no desktop root nao impede `scrollLeft` programatico; em stacked mobile, o shell precisa zerar scroll interno e evitar virar scroll container horizontal.
- Dialog aberto por menu pode deslocar o shell antes da janela aparecer; medir `getBoundingClientRect` dos ancestrais e `scrollLeft` do desktop ajuda a separar bug de componente de bug estrutural.
- Inputs numericos dentro de flex precisam de `flex-basis`/`min-width` estaveis; largura nominal sozinha pode encolher ate o spinner nativo.
- Form de configuracao com label/input/unit deve priorizar a unidade "setting" e nao reproduzir colunas rigidas do desktop.
- Geometria desktop deve ser reavaliada depois da refatoracao mobile-first; conteudo mais compacto pode pedir janela menor/mais larga.
- Result cards com acoes devem manter footer fixo; se as acoes rolam junto com o conteudo, o usuario perde o proximo passo.
- `dl` em duas colunas precisa virar label sobre valor no mobile quando labels podem ser longos.
- Um form curto pode continuar em desktop window fullscreen no mobile quando o resultado potencial e longo, mas o estado vazio precisa ser intencional.
- Specs antigas que esperam output textual precisam ser atualizadas quando a feature ja adotou card estruturado.
- Playwright em paralelo ainda pode disputar `E2E_PORT=4003` e `_build/e2e`; specs focados devem ser rodados em sequencia para validacao confiavel.
- Conteudo de referencia longo, como cheatsheet, deve ser tratado como lista escaneavel quando o usuario procura um item, nao como tabela comparativa.
- Densidade mobile nao deve ser resolvida sempre empilhando tudo; em atalhos curtos, manter acao e badge na mesma linha melhora escaneabilidade.
- Atalhos longos precisam de badges com `max-width: 100%` e `overflow-wrap`; `kbd` pode introduzir overflow silencioso se for tratado como texto sem quebra.
- Auditoria de dialog pode revelar problema de acesso no shell. No Cheatsheet, o dialog ficou correto, mas o menu Help no mobile segue como tema separado.

## Validacao Do Ultimo Ciclo

- Passou: `rtk mix compile`.
- Passou: `rtk mix assets.build` em `apps/retro_hex_chat_web`.
- Passou: captura visual Keyboard Shortcuts desktop/mobile com Playwright em fluxo real via `Ctrl+Shift+/`.
- Passou: `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/cheatsheet_dialog_test.exs --trace` (2 testes).
- Passou: `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/keyboard_shortcuts_test.exs --include liveview --trace` (9 testes).
- Passou: `rtk npm --prefix e2e test -- --project=chromium tests/chat-cheatsheet.spec.ts --reporter=list` (1 teste).
- Passou: `rtk npm --prefix e2e test -- --project=chromium tests/chat-keyboard.spec.ts --reporter=list` (1 teste).
- Passou: `rtk npm --prefix e2e test -- --project=chromium tests/chat-menu-toolbar-parity.spec.ts --reporter=list` (1 teste).

Observacao: a captura mobile registrou que abrir pelo menu Help nao e caminho estavel no shell stacked; a auditoria visual usou o atalho real `Ctrl+Shift+/`.
