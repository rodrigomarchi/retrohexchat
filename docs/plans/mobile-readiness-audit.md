# Auditoria de prontidao mobile

Data: 2026-07-15

Status: auditoria viva. O diagnostico inicial foi feito antes das mudancas; as atualizacoes abaixo refletem os ciclos de implementacao do chat mobile core.

Atualizacao 2026-07-16: a frente de implementacao do chat mobile core foi executada e registrada em `docs/plans/mobile-chat-progress.md`. Ja foram abordados breakpoint, visual viewport, teclado virtual por contrato de `visualViewport` + foco editavel, header mobile, sidebars, long press, busca, autocomplete, composer, emoji mobile, reply, edit, delete confirm, PM, nicklist/conversations por toque e projeto Playwright mobile dedicado. Ainda nao foram resolvidos os dialogos densos, P2P/midia/jogos, Mobile Safari/WebKit e validacao em dispositivo real.

## Resumo executivo

O RetroHexChat tem uma base mobile real, principalmente no shell de janelas. A decisao mais importante ja existe: em viewport estreito, o gerenciador abandona o modelo MDI desktop e passa a mostrar uma janela por vez em tela cheia. Isso reduz muito a chance de quebra estrutural no celular.

Mesmo assim, a experiencia mobile ainda nao deve ser considerada pronta. O chat basico parece perto de ser usavel, mas o produto completo ainda carrega muitos conteudos desktop dentro de janelas fullscreen: tabelas, abas, formularios laterais, menus de contexto, taskbar densa, janelas auxiliares, WebRTC, jogos e canvas.

Minha avaliacao geral:

| Area | Estado atual | Risco |
| --- | --- | --- |
| Shell de janelas mobile | Bom fundamento | Medio baixo |
| Chat basico, leitura e envio | Bom no core emulado, incluindo contrato de teclado | Baixo medio |
| Sidebars de conversas e nicklist | Razoavel | Medio |
| Dialogos de configuracao e CRUD | Fraco a medio | Alto |
| Context menus e gestos touch | Bom no chat core, parcial no produto | Medio |
| P2P, chamada em grupo, midia e jogos | Parcial | Alto |
| Cobertura automatizada mobile | Boa para chat core emulado | Medio |

Estimativa por meta:

- Chat basico confiavel em celular: 1 a 2 semanas.
- Produto autenticado com principais ferramentas polidas: 3 a 6 semanas.
- Paridade mobile completa incluindo P2P, chamada, jogos e space: 6 a 10+ semanas.

Estado apos os ciclos de 2026-07-16: a primeira meta esta implementada para o core de chat em mobile emulado, incluindo o contrato de teclado virtual. A declaracao "confiavel em celular" ainda depende de uma passada manual em Android Chrome, iOS Safari e dispositivos fisicos.

## Como esta implementado hoje

### Shell e janelas

O ponto forte da arquitetura esta em `WindowManagerHook`. O breakpoint mobile foi alinhado para `768px`:

- `apps/retro_hex_chat_web/assets/js/hooks/ui/window_manager_hook.js`
- `STACK_BREAKPOINT = 768`

Quando entra em modo empilhado, o hook mostra somente a janela focada:

- `applyWindow/1` calcula visibilidade como janela aberta, nao minimizada e, se empilhado, focada.
- Em modo empilhado, a geometria inline e limpa.
- O CSS aplica `inset: 0`, `width: auto`, `height: auto` e esconde resize/minimize/maximize.

CSS principal:

- `apps/retro_hex_chat_web/assets/css/retrohex.css`
- bloco `.desktop--stacked`

Isso e uma boa pratica para um app que nasceu como desktop retro: preservar o conceito de janelas em telas grandes e converter para pilha fullscreen em telas pequenas.

### Chat principal

O chat real vive em uma janela fixada e maximizada por padrao:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex`
- janela `id="chat"`, `default_maximized`, `body_class="flex flex-col min-h-0 p-0 overflow-hidden"`

O miolo do chat usa `min-w-0`, `min-h-0` e `overflow-hidden` em pontos corretos. Isso e positivo para evitar overflow acidental em flex layouts.

As mensagens usam grid com coluna de meta reduzida no mobile:

- `grid-cols-[5rem_1fr]`
- `sm:grid-cols-[7rem_1fr]`
- corpo com `break-words`

### Sidebars

Conversas e nicklist ja viram overlays no mobile:

- `components/ui/chat/conversations.ex`
- `components/ui/chat/nicklist.ex`

Padrao atual no chat core:

- overlays mobile com `chat-sidebar-overlay`, iniciando abaixo do header
- backdrop escuro clicavel
- painel lateral com largura fixa (`280px` para conversas, `200px` para nicklist)

Isso e uma boa base. O risco esta mais nos alvos de toque pequenos e na forma como o usuario descobre que essas sidebars existem.

### Deteccao de viewport

`ViewportDetectHook` agora mantem o contrato entre LiveView e CSS:

- `apps/retro_hex_chat_web/assets/js/hooks/ui/viewport_detect_hook.js`

O hook observa resize, orientationchange, `visualViewport.resize`, `visualViewport.scroll`, `focusin` e `focusout`. Ele envia payloads de viewport para o servidor apenas quando ha mudanca relevante, mas atualiza CSS variables a cada alteracao visual:

- `--rhc-visual-viewport-height`
- `--rhc-visual-viewport-width`
- `--rhc-visual-viewport-offset-top`
- `--rhc-visual-viewport-offset-left`
- `--rhc-keyboard-inset-bottom`

No servidor, `viewport_info` marca mobile quando `width < 768`:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/menu_toolbar_events.ex`

O contrato de teclado virtual ficou local ao cliente: `rhc-keyboard-open` so liga em viewport mobile quando existe foco editavel e o inset inferior passa de 80px. Isso evita falsos positivos em barras de navegador, rotacao e resizes sem composer ativo.

### Dialogos e ferramentas

O chat tem 26 janelas declaradas no template principal. Muitas foram projetadas com larguras desktop:

- `min_width={480}`
- `min_width={520}`
- `min_width={560}`

No mobile empilhado, isso nao quebra a moldura porque a geometria e removida. O problema e o conteudo interno.

Foram encontradas 19 tabelas reais em dialogos, por exemplo:

- Address Book
- Highlight Words
- Sound Settings
- Timers
- Auto Respond
- Notify List
- Channel Central
- URL Catcher
- Custom Menus
- Perform
- Channel List

O componente de tabela encapsula `overflow-x-auto`, o que protege contra quebra global:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/layout/table.ex`

Isso evita layout quebrado, mas nao garante boa UX mobile. Em celular, tabela horizontal dentro de janela fullscreen vira uma experiencia pesada.

### Midia, chamada, P2P e jogos

Ha bons sinais:

- Group Call tem media queries para reduzir layouts abaixo de `700px`.
- P2P e game media tem media queries para colapsar layouts abaixo de `640px` e `860px`.
- P2P evita abrir varias janelas auxiliares automaticamente quando `mobile_viewport` esta ativo.
- Group Call abre menos janelas quando `mobile_viewport` esta ativo.

Ainda assim, essas areas exigem validacao especifica porque envolvem:

- permissoes de camera/microfone;
- WebRTC;
- canvas;
- WASM/jogos;
- orientacao;
- desempenho;
- toque/gestos;
- controles em overlay.

## Praticas da comunidade relevantes

### Alvos de toque

Referencias comuns:

- WCAG 2.2 AA: alvo minimo de `24 x 24 CSS px`, com excecoes para espacamento/equivalente/inline.
- WCAG 2.2 AAA: alvo aprimorado de `44 x 44 CSS px`.
- Apple HIG: regioes de toque de pelo menos `44 x 44 pt`.
- Material Design: considerar alvos de toque de pelo menos `48 x 48dp`.

Implicacao para o RetroHexChat:

- Controles Win98 de `14px`, `16px`, `20px`, `28px` podem ser visualmente coerentes, mas precisam de hit area maior no mobile.
- O icone pode continuar pequeno; a area clicavel nao precisa ser pequena.
- A solucao deve preservar a estetica retro, mas separar tamanho visual de tamanho interativo.

### Viewport mobile e teclado virtual

Boas praticas atuais para apps web mobile:

- Evitar depender apenas de `100vh`/`h-screen` para apps fullscreen em mobile.
- Usar unidades modernas como `dvh`, `svh` e `lvh` onde fizer sentido.
- Considerar `visualViewport` para componentes presos ao fundo, especialmente chat composer.
- Garantir que o teclado virtual reduza a area de mensagens, em vez de cobrir o input.

O chat core agora combina `100dvh`, CSS variables de visual viewport e offsets de `visualViewport`. Dialogos e ferramentas fora do core ainda precisam de revisao especifica.

### Navegacao mobile

Padroes esperados:

- Acoes frequentes devem estar a um toque, nao escondidas em menu textual profundo.
- Menus de contexto de desktop precisam de alternativa touch: long press, action sheet, botao de overflow ou menu por item.
- Tabs com muitos itens devem ter scroll claro, area de toque maior e fechamento dificil de acionar por engano.
- Listas densas devem priorizar scan vertical; tabelas horizontais devem ser excecao.

### Testes mobile

Playwright suporta perfis de dispositivo com viewport, user agent, DPR e `hasTouch`. O projeto agora possui `mobile-chrome` para o chat core, mas ainda falta matriz mobile real fora do chat, WebKit/Mobile Safari e device QA fisico.

Pratica recomendada:

- Manter testes desktop existentes.
- Manter o projeto Mobile Chrome existente e adicionar Mobile Safari/WebKit quando viavel.
- Testar pelo menos: 375x667, 390x844, 414x896 e uma largura tablet/landscape.
- Medir overflow horizontal, alvos menores que 44px e comportamento com teclado/viewport.

## Problemas encontrados

### 1. Breakpoints desalinhados

Estado: resolvido no chat core.

Problema original:

- Window Manager: `<720px`.
- Servidor/mobile defaults: `<768px`.
- `ViewportDetectHook` envia apenas no mount.

Impacto original:

- Sidebars podem fechar como mobile enquanto janelas ainda estao em modo desktop.
- Rotacao de tela pode deixar `mobile_viewport` errado.
- P2P e Group Call usam `mobile_viewport` para decidir comportamento; se esse estado ficar stale, a UX degrada.

Abordagem executada:

- Breakpoint do Window Manager alinhado para 768px.
- Hook passou a reportar mudancas relevantes de largura/altura/visual viewport.
- LiveView passou a restaurar sidebars ao voltar para desktop.

Pendencia:

- Revalidar o comportamento em rotacao portrait/landscape.
- Expandir a mesma disciplina para areas fora do chat core quando forem tratadas.

### 2. Touch targets pequenos

Estado: parcialmente resolvido no chat core; ainda pendente em dialogos e ferramentas.

Problema original:

- Controles de janela: `16 x 14`.
- Fechar aba: `14 x 14`.
- Botao de fechar sidebar: `20 x 20`.
- Muitos botoes pequenos com icones `14px` ou `16px`.

Impacto original:

- Uso impreciso no celular.
- Acoes destrutivas ou de fechamento ficam faceis de tocar por engano.
- A estetica retro pode parecer bonita, mas cansativa no uso real.

Abordagem executada no chat:

- Hit areas aumentadas no modo `desktop--stacked` para header, abas, sidebars, mensagens, composer, taskbar e controles de janela.
- Emoji mobile, dismiss de reply e botoes de sidebars ganharam area de toque mais segura.

Pendencia:

- Levar a mesma camada mobile de hit area para dialogos, tabelas, formularios e ferramentas fora do chat core.
- Mirar pelo menos 44px para acoes frequentes e perigosas.

### 3. Teclado virtual e composer

Estado: implementado no chat core em codigo e automacao; pendente device QA.

Problema original:

- Shell do chat usa `fixed inset-0`.
- Composer fica no fundo da tela.
- Textarea auto-resize sobe ate 5 linhas.
- Nao ha tratamento explicito de `visualViewport`.

Impacto original:

- Em iOS/Android, o teclado pode cobrir o input ou comprimir mal a area de mensagens.
- Autocomplete/emoji/search podem disputar espaco com teclado.

Abordagem executada:

- `chat-app-root` passou a seguir dimensoes e offsets do visual viewport.
- Textarea do composer usa limite menor de linhas em mobile.
- `rhc-keyboard-open` esconde taskbar/Start menu enquanto o teclado esta aberto.
- Autocomplete, syntax tooltip e emoji picker reduzem altura maxima no estado de teclado aberto.
- Unit tests validam foco editavel, inset, CSS variables e classes globais.
- E2E mobile valida que a taskbar some e o workspace ganha altura no contrato de teclado aberto.

Pendencia:

- Validar em Android Chrome e iOS Safari fisicos, porque a automacao desktop nao abre teclado nativo.
- Confirmar scroll-to-bottom e recebimento de mensagem com teclado aberto em device real.

### 4. Dialogos desktop dentro de mobile fullscreen

Problema:

- Muitas janelas secundarias sao mini-apps desktop.
- Tabelas usam scroll horizontal.
- Abas fazem wrap e consomem altura.
- Alguns formularios ficam lado a lado com lista em larguras fixas.

Impacto:

- A aplicacao nao quebra, mas a experiencia fica pesada.
- Fluxos como Address Book, Custom Menus, Auto Respond, Timers, Channel Central e Admin Console exigem redesign responsivo.

Abordagem:

- Classificar dialogos por frequencia e criticidade.
- Para dialogos simples: ajustes CSS e hit areas.
- Para CRUDs densos: mudar fluxo mobile para lista -> detalhe/editar.
- Para tabelas: criar variante mobile em cards ou rows empilhadas.
- Para abas: usar segmented control/scroll horizontal ou agrupar funcionalidades.

### 5. Menus de contexto e gestos desktop

Estado: resolvido para chat core; parcial no restante do produto.

Problema original:

- Muitas acoes dependem de right-click/contextmenu.
- Hooks de nicklist, conversas, mensagens e space usam `contextmenu`.
- Nao ha alternativa clara de long press/action sheet.

Impacto original:

- Funcionalidade fica escondida no celular.
- Usuarios mobile podem nao descobrir P2P, Whois, Notice, Invite, Ignore, Custom Menus etc.

Abordagem executada no chat:

- Long-press abre os mesmos menus em mensagens, nicklist e conversas.
- Reply/Edit/Delete/PM passaram a ter caminho touch.
- Delete usa confirmacao e cancelamento por menu em mobile.

Pendencia:

- Implementar um padrao unico de "acoes do item" para mobile.
- Opcoes possiveis: long press, botao `...`, action sheet fullscreen ou menu ancorado.
- Nao depender apenas de long press; ele e pouco descobrivel.
- Levar o padrao para Space, P2P, dialogos e ferramentas fora do chat core.

### 6. Taskbar e Start menu densos

Estado: parcialmente mitigado no chat core.

Problema original:

- Taskbar tem scroll horizontal e pode acumular muitas janelas.
- Start menu lista muitas ferramentas em um menu estreito.
- O header tinha slot `mobile_actions`, mas o chat nao o usava para acoes moveis explicitas.

Impacto original:

- Abrir/trocar ferramentas funciona, mas exige navegacao pesada.
- Em mobile, a taskbar vira mistura de switcher e launcher.

Abordagem executada no chat:

- Header passou a expor conversas, nicklist e search como acoes mobile diretas.
- Taskbar e Start menu somem enquanto o teclado esta aberto, devolvendo altura ao chat.

Pendencia:

- Considerar um launcher mobile agrupado por categoria.
- Limitar labels longas e melhorar area de toque dos botoes de taskbar.
- Manter taskbar como parte da identidade retro, mas nao depender dela para fluxos frequentes.

### 7. Cobertura insuficiente

Estado: melhorou bastante para chat core; insuficiente para produto completo.

Problema original:

- Existe teste e2e para mobile stacked, mas ele cobre apenas shell + Timers.
- E2E usa Desktop Chrome, nao perfil mobile/touch.
- Faltam testes para teclado, sidebars, context menus, dialogos densos, P2P, chamada, jogos e rotacao.

Impacto original:

- Podemos achar que mobile esta bom porque nao quebra no shell.
- Problemas de UX real ficam invisiveis.

Abordagem executada:

- Adicionado projeto Playwright `mobile-chrome` com device Pixel 5.
- Specs mobile cobrem shell, header, sidebars, busca, autocomplete, emoji, reply, edit, delete, PM, long-press e contrato de teclado.
- Specs desktop de PM/acoes/context menus continuam rodando no projeto desktop para regressao.

Pendencia:

- Adicionar auditoria automatizada de overflow/hit target.
- Tirar screenshots por viewport para revisar visualmente.
- Adicionar WebKit/mobile Safari e landscape quando os proximos blocos entrarem.

## Como abordar por feature

### Shell de janelas

Estado: bom no chat core.

Riscos:

- breakpoint desalinhado;
- estado stale apos resize;
- taskbar densa;
- controles pequenos.

Abordagem:

1. Manter breakpoint de 768px como contrato unico para chat.
2. Continuar fazendo `mobile_viewport` reagir a resize/orientacao.
3. Garantir hit areas maiores no modo empilhado.
4. Manter a regra "uma janela visivel por vez".
5. Testar com 375x667, 390x844 e landscape.

Complexidade: media baixa.

### Header, menubar, Start e taskbar

Estado: bom para chat core; desktop-first no restante do produto.

Riscos:

- menus textuais compactos;
- Start menu longo;
- taskbar vira switcher pesado;
- acoes frequentes escondidas.

Abordagem:

1. Manter `mobile_actions` para conversas/nicklist/search no chat.
2. Aumentar hit area dos botoes principais fora do chat.
3. Avaliar launcher mobile por categorias.
4. Preservar Start/taskbar como identidade, mas nao depender apenas deles.

Complexidade: media.

### Chat: leitura, envio e mensagens

Estado: bom no core emulado.

Riscos:

- teclado virtual;
- composer cobrindo mensagens;
- autocomplete e emoji disputando espaco;
- nicks e timestamps muito densos.

Abordagem:

1. Manter o contrato de `visualViewport`/`rhc-keyboard-open`.
2. Validar composer com mensagens longas e multiline em device real.
3. Garantir scroll-to-bottom e leitura ao receber mensagem com teclado aberto.
4. Revisar tamanho de nick/timestamp se ficar apertado.

Complexidade: media.

### Conversas sidebar

Estado: bom no chat core.

Riscos:

- largura fixa de 280px em telas pequenas;
- item de lista pequeno;
- fechar overlay pequeno;
- acoes via context menu.

Abordagem:

1. Manter hit area ampliada dos itens.
2. Manter fechamento do overlay apos escolher canal/PM.
3. Evoluir descoberta de acoes alem de long-press, se necessario.
4. Validar popular channels, unread, group call badges e P2P badges.

Complexidade: media.

### Nicklist

Estado: bom no chat core.

Riscos:

- itens muito baixos;
- right-click/double-click nao traduzem bem para touch;
- acoes de usuario pouco descobriveis.

Abordagem:

1. Manter long-press como entrada touch minima para acoes de usuario.
2. Adicionar overflow/action sheet se a descoberta de long-press for insuficiente.
3. Manter altura minima de rows no mobile.
4. Manter busca/scroll simples.

Complexidade: media.

### Context menus de chat/canal/nick

Estado: bom para chat core; incompleto para produto amplo.

Riscos:

- right-click como unica entrada;
- long press nao implementado;
- action discovery baixa.

Abordagem:

1. Manter long-press como caminho minimo em mensagens, nicks e canais.
2. Avaliar botao `...` ou action sheet para melhorar descoberta.
3. Manter context menu desktop intacto.
4. Garantir equivalencia de acoes para acessibilidade.

Complexidade: media alta.

### Tabs de canal/PM

Estado: funcional com scroll horizontal e hit area mobile melhorada.

Riscos:

- fechar aba `14x14`;
- muitos canais ficam dificeis de navegar;
- PM/call badges competem por espaco.

Abordagem:

1. Manter hit area mobile do fechar aba.
2. Considerar menu/lista de abas no mobile quando houver muitas.
3. Manter scroll horizontal, mas com boa area de toque.
4. Validar nomes longos e badges.

Complexidade: media.

### Search, reply, edit e autocomplete

Estado: funcional no chat core, ainda sensivel a device QA.

Riscos:

- janelas/flutuantes competem com teclado;
- foco e scroll podem saltar;
- autocomplete pode abrir fora da area visivel.

Abordagem:

1. Auditar com teclado nativo aberto em Android/iOS.
2. Manter posicionamento relativo ao visual viewport.
3. Preferir paines dentro do fluxo do composer no mobile.
4. Manter smoke tests para `/`, search, reply/edit e emoji.

Complexidade: media.

### Address Book

Estado: mini-app desktop com 4 abas e varias tabelas.

Riscos:

- muitas abas;
- tabelas horizontais;
- subformularios;
- CRUD denso.

Abordagem:

1. Priorizar cards/list rows no mobile.
2. Separar lista e formulario em etapas.
3. Transformar abas em navegacao mais compacta.
4. Manter tabela desktop.

Complexidade: alta.

### Custom Menus

Estado: desktop CRUD com tabela + formulario lateral fixo.

Riscos:

- `flex` horizontal com painel de 200px;
- comando pode ser longo;
- abas e formulario simultaneos.

Abordagem:

1. No mobile, trocar para lista -> editar em painel/tela.
2. Usar textarea/input full width para comando.
3. Evitar tabela horizontal.
4. Garantir alternativa mobile para testar o menu criado.

Complexidade: alta.

### Auto Respond

Estado: desktop CRUD com tabela + formulario lateral fixo.

Riscos:

- quatro colunas;
- formulario lateral de 220px;
- comando longo;
- trigger/channel/enable em espaco pequeno.

Abordagem:

1. Criar card por regra no mobile.
2. Editar regra em tela separada/painel fullscreen.
3. Agrupar campos por prioridade.
4. Manter tabela no desktop.

Complexidade: alta.

### Timers

Estado: razoavel, mas tabela larga.

Riscos:

- cinco colunas;
- comando truncado;
- acoes Add/Edit/Remove pequenas.

Abordagem:

1. Cards mobile com nome, intervalo, proximo disparo e comando.
2. Formularios ja parecem mais proximos de mobile por usarem breakpoints.
3. Aumentar botoes e checkboxes.

Complexidade: media.

### Channel List

Estado: funcional com tabela.

Riscos:

- canal/usuarios/topico em tabela horizontal;
- topicos longos;
- search + join em espaco limitado.

Abordagem:

1. Cards mobile: canal, user count, badges, topico em duas linhas.
2. Manter busca no topo.
3. Acoes de join como botao claro por card ou tap com confirmacao.

Complexidade: media.

### Channel Central

Estado: complexo.

Riscos:

- seis abas;
- modos, bans, exceptions, registration;
- tabelas de masks;
- formularios condicionais por permissao.

Abordagem:

1. Tratar como projeto proprio.
2. Separar mobile por secoes verticais: General, Modes, Access Lists, Registration.
3. Converter mask tables para cards.
4. Validar com roles diferentes: usuario comum, operador, founder/admin.

Complexidade: alta.

### URL Catcher

Estado: tabela e filtro horizontal.

Riscos:

- filtro com select fixo `140px` + search + botao;
- tabela com URL/Nick/Channel/Time;
- URLs longas.

Abordagem:

1. Quebrar filtros em linhas no mobile.
2. Cards de URL com dominio/titulo, origem e tempo.
3. Acoes claras: abrir, copiar, filtrar por canal/nick.

Complexidade: media.

### Sound Settings

Estado: tabela de eventos.

Riscos:

- select por evento em tabela;
- colunas Flash/Preview pequenas.

Abordagem:

1. Cards por evento no mobile.
2. Select full width.
3. Switch/checkbox e preview com hit area maior.

Complexidade: media.

### Highlight Words

Estado: tabela simples.

Riscos:

- cor e remocao em colunas pequenas;
- alvo de remover.

Abordagem:

1. Provavelmente basta ajuste medio.
2. Cards simples ou tabela compacta com hit areas maiores.
3. Garantir swatches tocaveis.

Complexidade: baixa media.

### Alias e Perform

Estado: tabelas e comandos longos.

Riscos:

- comandos sao texto longo;
- tabelas truncam informacao;
- edicao precisa de espaco de input.

Abordagem:

1. Lista mobile de aliases/commands.
2. Editar em formulario fullscreen.
3. Mostrar preview/expansao em bloco mono com quebra.

Complexidade: media alta.

### Notify List

Estado: tabela simples.

Riscos:

- status/last seen em colunas;
- acoes por selecao.

Abordagem:

1. Cards/list rows.
2. Status visual claro.
3. Botoes Add/Edit/Remove maiores.

Complexidade: media.

### Account

Estado: provavelmente tratavel.

Riscos:

- abas;
- formularios de senha/registro/perfil;
- teclado virtual.

Abordagem:

1. Validar teclado.
2. Garantir campos full width.
3. Aumentar tabs e botoes.
4. Priorizar fluxos Register/Identify/Profile.

Complexidade: media.

### User Lookup

Estado: janela pequena e mais simples.

Riscos:

- grid fixo de labels;
- resultados com texto longo.

Abordagem:

1. Ajustes leves.
2. Labels empilhadas se necessario.
3. Botoes e search full width.

Complexidade: baixa media.

### Admin Console

Estado: muito complexo.

Riscos:

- nove abas;
- tabelas/formularios;
- comandos perigosos;
- console.

Abordagem:

1. Nao priorizar para MVP mobile publico, a menos que admins usem celular.
2. Se necessario, transformar em secoes empilhadas.
3. Manter confirmacoes fortes para acoes perigosas.
4. Testar separadamente.

Complexidade: alta.

### Bot Management

Estado: melhor que outros dialogos porque ja usa `flex-col md:flex-row`.

Riscos:

- cinco abas de detalhe;
- lista + detalhe ainda densos;
- comandos/capabilities.

Abordagem:

1. Aproveitar a base responsiva existente.
2. Melhorar tabs e rows.
3. Transformar detalhe em acordeoes ou telas dedicadas no mobile.

Complexidade: media alta.

### Group Call

Estado: ha trabalho responsivo especifico.

Riscos:

- permissoes de midia;
- video grid;
- sidebar de participantes;
- toolbar densa;
- landscape/portrait;
- screen share em mobile.

Abordagem:

1. Manter validacao separada de chamada.
2. Criar matriz: audio only, receive only, video, sem permissao, reconnect.
3. Testar portrait e landscape.
4. Garantir controles de chamada com 40-48px.

Complexidade: alta.

### P2P call/files/games/stats

Estado: parcialmente consciente de mobile.

Riscos:

- WebRTC e permissao;
- janelas auxiliares escondidas;
- file picker mobile;
- jogos e chamada simultaneos;
- estatisticas densas.

Abordagem:

1. Definir quais capacidades mobile entram no primeiro corte.
2. Priorizar sessao P2P, chamada audio/video e arquivo simples.
3. Rebaixar stats avancadas para depois.
4. Validar file input e permissao em dispositivos reais.

Complexidade: alta.

### Arcade e jogos

Estado: lobby responsivo parcial; jogos variam.

Riscos:

- muitos jogos documentados com teclado/mouse/gamepad;
- canvas em touch;
- WASM/performance;
- orientacao;
- controles virtuais.

Abordagem:

1. Separar jogos touch-ready de jogos keyboard-first.
2. Marcar suporte mobile por jogo.
3. Adicionar controles virtuais onde fizer sentido.
4. Testar performance e layout fullscreen.

Complexidade: alta.

### Space/canvas

Estado: desktop/touch incerto.

Riscos:

- hover/contextmenu em canvas;
- camera/viewport;
- selecao de participantes;
- movimento por teclado.

Abordagem:

1. Definir gestos touch: tap, drag, long press.
2. Substituir hover por selected state.
3. Testar canvas em 320/375/390px.
4. Garantir action sheet para participantes.

Complexidade: alta.

### Landing, Connect e Help

Estado: melhor que o app autenticado.

Riscos:

- `h-screen` em connect/help;
- botoes compactos;
- help com toolbar pequena.

Abordagem:

1. Migrar fullscreen para `dvh` onde aplicavel.
2. Validar connect com teclado aberto.
3. Aumentar hit areas basicas.
4. Baixa prioridade comparado ao chat autenticado.

Complexidade: baixa media.

## Sequencia recomendada

### Fase 1: estabilizar fundacao mobile

Objetivo: chat basico confiavel.

Status em 2026-07-16: implementada para o chat core em mobile emulado. Falta device QA real para declarar confiavel em celular fisico.

Itens:

1. Concluido no chat: unificar breakpoint mobile.
2. Concluido no chat: corrigir `mobile_viewport` em resize/orientacao.
3. Concluido em codigo/automacao: resolver teclado virtual/composer/viewport.
4. Concluido no chat: aumentar hit areas dos controles mais usados.
5. Concluido: adicionar projeto Playwright mobile.
6. Concluido no chat: criar smoke tests de chat, sidebars, taskbar e teclado.

Resultado esperado:

- Usuario consegue conectar, ler, enviar, alternar canais/PM, abrir sidebars e trocar janelas sem friccao grave.
- Resultado pendente de confirmacao em aparelho fisico: teclado nativo nao cobre composer e nao quebra scroll/recebimento de mensagens.

### Fase 2: polir ferramentas de uso frequente

Objetivo: principais dialogos deixam de parecer desktop encolhido.

Prioridade sugerida:

1. Channel List
2. URL Catcher
3. Timers
4. Highlight Words
5. Account
6. User Lookup
7. Notify List

Resultado esperado:

- Tabelas principais viram listas/cards no mobile.
- Acoes ficam tocaveis.
- Formularios usam fluxo vertical.

### Fase 3: CRUDs densos e configuracoes avancadas

Objetivo: ferramentas de power user funcionam bem no mobile.

Prioridade sugerida:

1. Address Book
2. Custom Menus
3. Auto Respond
4. Alias
5. Perform
6. Sound Settings
7. Channel Central

Resultado esperado:

- Cada mini-app tem variante mobile clara.
- Lista e edicao deixam de competir no mesmo canvas.

### Fase 4: midia, P2P, jogos e space

Objetivo: recursos avancados com QA especifico.

Itens:

1. Group Call mobile matrix.
2. P2P mobile matrix.
3. File transfer mobile.
4. Jogos touch-ready.
5. Space touch interactions.
6. Validacao em dispositivos reais.

Resultado esperado:

- Mobile deixa de ser apenas "abre" e passa a ser "usavel com os recursos avancados".

## Matriz minima de validacao

Viewports:

- 320x568: pior caso antigo/estreito.
- 375x667 ou 375x720: telefone pequeno.
- 390x844: telefone moderno comum.
- 414x896: telefone grande.
- 667x375 ou 844x390: landscape.
- 768x1024: tablet pequeno.

Browsers/perfis:

- Desktop Chrome atual, para regressao.
- Mobile Chrome emulado.
- Mobile Safari/WebKit emulado quando viavel.
- Pelo menos um iPhone real e um Android real antes de declarar pronto.

Fluxos basicos:

- conectar/registrar;
- enviar mensagem;
- receber mensagem;
- multiline composer;
- teclado aberto;
- alternar canais/PM;
- abrir/fechar conversas;
- abrir/fechar nicklist;
- abrir Start/menu/taskbar;
- abrir 5 dialogos prioritarios;
- rotacao;
- reload/reconnect.

Checks automatizaveis:

- `document.documentElement.scrollWidth <= window.innerWidth`;
- elementos interativos abaixo de 24px/44px;
- containers com overflow horizontal inesperado;
- janelas visiveis em modo empilhado;
- screenshots por viewport.

## Criterios de pronto

### Chat mobile MVP

- Sem overflow horizontal global.
- Composer visivel com teclado aberto.
- Sidebars acessiveis por toque claro.
- Alvos principais com hit area aceitavel.
- Uma janela por vez garantida abaixo do breakpoint.
- Testes e2e mobile cobrindo shell, chat, sidebars e teclado.

Status em 2026-07-16: shell, chat, sidebars, long-press, busca, autocomplete, emoji, reply, edit, delete, PM e contrato de teclado aberto estao cobertos em Playwright Mobile Chrome. O item de teclado aberto ainda exige validacao real em Android Chrome/iOS Safari para confirmar o comportamento do teclado nativo.

### Produto mobile bom

- Principais dialogos sem tabela horizontal obrigatoria.
- Context menus tem alternativa touch.
- Taskbar/start nao sao a unica forma eficiente de navegar.
- P2P/chamada/jogos declarados como suportados, parciais ou desktop-only.
- Matriz mobile roda no e2e.

### Paridade mobile completa

- Recursos avancados validados em mobile.
- Media permissions e rotacao testadas.
- Jogos/canvas com controles touch.
- Pelo menos uma rodada em dispositivos fisicos.

## Referencias oficiais

- W3C WCAG 2.2, Target Size Minimum: https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum
- W3C WCAG 2.2, Target Size Enhanced: https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced.html
- Apple Human Interface Guidelines, Buttons: https://developer.apple.com/design/human-interface-guidelines/buttons
- Material Design 3, touch targets: https://m3.material.io/foundations/designing/structure
- MDN, viewport concepts and visual viewport: https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/CSSOM_view/Viewport_concepts
- MDN, CSS length units including `svh`, `lvh`, `dvh`: https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Values/length
- MDN, VisualViewport API: https://developer.mozilla.org/en-US/docs/Web/API/VisualViewport
- Playwright, emulation: https://playwright.dev/docs/emulation

## Referencias locais principais

- `apps/retro_hex_chat_web/assets/js/hooks/ui/window_manager_hook.js`
- `apps/retro_hex_chat_web/assets/css/retrohex.css`
- `apps/retro_hex_chat_web/assets/js/hooks/ui/viewport_detect_hook.js`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/menu_toolbar_events.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/layout/desktop.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/layout/window.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/layout/dialog.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/layout/table.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/chat/conversations.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/chat/nicklist.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/chat/chat_input.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/chat/irc_tabs.ex`
- `e2e/tests/chat-mobile-desktop.spec.ts`
- `e2e/tests/chat-mobile-message-flow.spec.ts`
- `e2e/playwright.config.ts`
