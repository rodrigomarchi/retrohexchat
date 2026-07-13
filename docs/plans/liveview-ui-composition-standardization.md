# Padronizacao LiveView/UI - plano de composicao

> Criado em 2026-07-13. Escopo: padronizar as superficies LiveView/UI
> identificadas na auditoria, cobrindo os itens 1 a 6. A pagina admin do
> LiveDashboard fica fora do escopo por decisao explicita.

## Objetivo

Eliminar codigo visual dedicado dentro de LiveViews, LiveComponents de estado e
templates `.heex` operacionais quando esse codigo deveria ser uma composicao de
componentes reutilizaveis do design system.

Resultado esperado:

- LiveViews ficam como orquestradores de estado, eventos, autorizacao e rotas.
- LiveComponents em `live/**/components` ficam como ilhas stateful ou adapters
  de stream/hook, nao como donos de apresentacao pesada.
- UI visual e reutilizavel mora em `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/**`.
- Dialogs, cards, shells, taskbars, toolbars, empty states e secoes editoriais
  usam componentes compostos, nao markup ad hoc espalhado.
- O usuario percebe uma plataforma coesa: mesma linguagem visual, mesmos
  icones SVG, mesmos dialogs, mesmo ritmo de status/acoes.

## Regra de arquitetura

### Camadas

1. `apps/retro_hex_chat/lib/retro_hex_chat/**`
   - Dominio puro.
   - Sem Phoenix, sem HEEx, sem CSS, sem componentes.

2. `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/**`
   - LiveViews e LiveComponents stateful.
   - Responsaveis por socket assigns, eventos, PubSub, streams, hooks, rotas,
     autorizacao de UI e adapters para comandos.
   - Podem ter wrappers estruturais minimos quando necessarios para hooks,
     streams, `phx-target`, `id` estavel ou `data-*` consumidos por JS.
   - Nao devem definir telas completas, cards ricos, dialogs completos,
     toolbars visuais ou composicoes extensas de layout.

3. `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/**`
   - Design system e componentes visuais compostos.
   - Responsaveis por markup visual, icones, classes, slots, estados visuais,
     empty states, cards, dialogs, panels, headers, toolbars e shell UI.
   - Recebem dados prontos e callbacks/event names por attrs.
   - Nao devem conhecer socket, PubSub, dominio mutavel ou efeitos.

4. `apps/retro_hex_chat_web/assets/js/**`
   - Wiring de browser, WebRTC, DOM, hooks e progressive enhancement.
   - Nao decide regra de negocio ou politica de produto.

### Regra pratica

Se um bloco HEEx responde principalmente a pergunta "como isso parece?", ele
pertence a `components/ui/**`.

Se responde principalmente a pergunta "quando isso aparece, com quais dados, e
qual evento dispara?", ele pode ficar em `live/**`.

### Excecoes aceitas

- Wrappers de stream com `id`, `phx-update`, `data-*` e chamada para componente
  visual.
- Roots de hook (`phx-hook`) que existem para ancorar JS.
- Formularios escondidos usados para POST/redirect quando nao ha UI visivel.
- Templates de showcase/dev quando existem apenas para demonstrar componentes.
- Pagina admin `LiveDashboard.PageBuilder`, fora deste plano.

## Padroes obrigatorios de UI

- SVG sempre via `RetroHexChatWeb.Icons` ou componente catalogado.
- Sem emoji como icone funcional de UI.
- Sem SVG inline fora do catalogo de icones/diagramas.
- Novas telas/dialogs/cards devem ser compostos por componentes existentes
  antes de criar novo markup.
- Se a composicao ficar especifica e reutilizavel, criar um componente em
  `components/ui/<area>/`.
- Componentes visuais recebem `on_*` attrs com nomes de evento ou `JS`.
- Componentes visuais nao usam `@myself` diretamente, exceto quando sao
  chamados por uma ilha stateful que repassa `target`.
- Test ids pertencem ao contrato de produto/teste; mover UI nao deve trocar
  `data-testid` sem necessidade.
- Acessibilidade basica e obrigatoria: `aria-label`, `aria-pressed`,
  `aria-current`, headings coerentes, foco previsivel em dialogs.
- Visual retro deve continuar usando os primitives existentes: `Window`,
  `Dialog`, `Button`, `Toolbar`, `Tabs`, `TreeView`, `Fieldset`, `Alert`,
  `EmptyState`, `StatusBar`, `Taskbar`, `MenuBar`, `ContextMenu`.

## Mapa da auditoria

### Fora do padrao - prioridade alta

1. `live/app/connect_live.html.heex`
   - Monta a tela inteira de conexao diretamente no template.
   - Inclui desktop, app header, janela, locale switcher, taskbar, start menu,
     form escondido e about dialog.

2. `live/app/connect_live.ex`
   - Define `nickname_step/1`, `password_step/1` e `register_step/1` com markup
     visual rico dentro do LiveView.

3. `live/chat_live/components/session_card.ex`
   - Resolvido em 2026-07-13: o componente visual foi movido para
     `components/ui/chat/session_card.ex`.
   - O `MessageRow` agora consome o componente pela camada UI.

### Parcial - prioridade media

4. `live/chat_live/components/message_row.ex`
   - Tem justificativa tecnica por ser hot path de stream.
   - Ainda faz branching visual por tipo de mensagem e monta corpos de mensagem.
   - Deve preservar wrapper de stream, mas extrair a composicao visual.

5. `live/app/chat_live.html.heex`
   - E grande demais e concentra orquestracao de janelas/taskbar.
   - Em geral ja compoe componentes corretamente, entao nao e uma violacao
     forte.
   - Deve ser quebrado em componentes de shell para reduzir acoplamento e
     impedir crescimento continuo.

6. `live/help_live/index.ex` e `live/help_live/help_helpers.ex`
   - A tela de ajuda usa componentes UI existentes, mas define layout, toolbar,
     navegador, tabs e resultados dentro de `live/help_live`.
   - Deve migrar a apresentacao para `components/ui/help/**`.

### Fora do padrao estrito, mas com prioridade menor

7. `live/landing_live/*.html.heex` e `live/landing_live/landing_helpers.ex`
   - Landing pages sao conteudo publico/editorial.
   - Ainda assim, ha muitos blocos repetidos de janela, lista com icones,
     desktop folder, mockups e secoes que deveriam virar componentes UI.
   - Refatorar depois das superficies operacionais para evitar misturar risco de
     app com conteudo publico.

### Fora do escopo

8. `live/admin/app_info_page.ex`
   - Usa `Phoenix.LiveDashboard.PageBuilder`.
   - Mantido como excecao.

## Plano de refatoracao

Estados:

- `PENDENTE`: ainda nao iniciado.
- `EM ANDAMENTO`: implementacao iniciada.
- `CONCLUIDO`: implementado, testado e documentado.

### F1 - Extrair tela de conexao

Status: `CONCLUIDO`

Arquivos atuais:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/connect_live.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/connect_live.html.heex`

Componentes alvo:

- `components/ui/connect/connect_screen.ex`
- `components/ui/connect/connect_window.ex`
- `components/ui/connect/connect_nickname_step.ex`
- `components/ui/connect/connect_password_step.ex`
- `components/ui/connect/connect_register_step.ex`
- `components/ui/connect/connect_locale_switcher.ex`
- `components/ui/connect/connect_taskbar.ex`
- `components/ui/connect/connect_session_form.ex` se o form escondido continuar
  merecendo isolamento.

Componente entregue:

- `components/ui/connect/connect_screen.ex`, com subcomponentes privados para a
  janela, steps, notices, locale switcher, taskbar e form escondido.

Implementacao:

- Mover a shell visual inteira para `<.connect_screen ... />`.
- Mover o `case @step` para componente UI, mantendo o LiveView como dono do
  estado `@step`, valores dos forms e validacoes.
- Preservar eventos atuais: `connect`, `validate`, `authenticate`,
  `validate_password`, `register`, `validate_register`, `back`, `menu_action`.
- Preservar `phx-hook="ConnectFormHook"` e o contrato do form escondido.
- Preservar `data-testid`: `connect-desktop`, `connect-window`,
  `session-alert`, `connect-btn`, `auth-btn`, `register-btn`,
  `locale-switcher`, `connect-start-help-topics`.
- Garantir que `ConnectLive` nao tenha funcoes HEEx privadas de tela ao final.

TDD/verificacao:

- LiveView tests do fluxo nickname disponivel, nickname registrado, senha
  invalida, register, back e troca de locale.
- Teste de render garantindo que os test ids continuam presentes.
- `mix format`.

Riscos:

- O form escondido de sessao depende de CSRF e timezone; mover sem alterar
  nomes/ids.
- `phx-mounted={JS.focus()}` precisa continuar no input correto por step.

### F2 - Mover SessionCard para UI

Status: `CONCLUIDO`

Arquivo original:

- `live/chat_live/components/session_card.ex`

Componente entregue:

- `components/ui/chat/session_card.ex`

Implementacao:

- Criar `RetroHexChatWeb.Components.UI.SessionCard` ou
  `RetroHexChatWeb.Components.UI.Chat.SessionCard`, seguindo a organizacao real
  dos componentes de chat.
- Mover markup, timeline, icon dispatch e labels para o novo modulo UI.
- Manter o helper de resolucao de dados fora do componente visual.
- Atualizar `MessageRow` para importar o componente UI.
- Opcionalmente deixar um wrapper temporario com delegacao para reduzir churn,
  mas remover quando os imports forem atualizados.
- Preservar `data-testid="session-card"`, `session-card-accept` e
  `session-card-decline`.

TDD/verificacao:

- Component/LiveView test para convite pendente, viewer convidado, viewer nao
  convidado, sessao encerrada, motivo de fechamento e duracao.
- Teste de regressao para aceitar/declinar convite pelo card.
- `mix format`.

Riscos:

- O card dispara eventos no root LiveView. Nao introduzir `phx-target`.
- Evitar trocar labels/status sem atualizar Gettext.

### F3 - Extrair corpo visual de MessageRow

Status: `CONCLUIDO`

Arquivo atual:

- `live/chat_live/components/message_row.ex`

Componentes alvo:

- `components/ui/chat/message_row.ex`
- `components/ui/chat/message_body.ex` se a separacao ficar mais clara.

Componente entregue:

- `components/ui/chat/message_row.ex`, com `message_row_body/1`.

Implementacao:

- Manter em `MessageRow` apenas:
  - wrapper com `id`;
  - classes de stream/highlight/pending/failed/deleted/editing;
  - `data-author`, `data-message-id`, `data-temp-id`, `data-msg-status`,
    `data-system-message`, `data-real-id`;
  - preparacao minima de attrs.
- Mover branching por tipo (`:action`, `:system`, `:p2p_system`, `:service`,
  `:error`, `:notice`, `:announcement`, `:inline_help`, `:p2p_invite`,
  default) para componente UI.
- Deixar `ChatHelpers.format_*` onde fizer mais sentido. Se ficar no UI, aceitar
  como formatacao visual; se ficar no Live adapter, passar strings prontas.
- Preservar `chat_message`, reply block, inline help, p2p invite fallback,
  session card, edited tag, deleted placeholder e retry button.

TDD/verificacao:

- Component tests ou LiveView tests cobrindo cada tipo de mensagem.
- Teste para retry de mensagem falhada continuar disparando `retry_message`.
- Teste de reply click continuar disparando `scroll_to_reply_parent`.
- E2E leve para render de mensagem normal, system e P2P invite.

Riscos:

- `MessageRow` e hot path. Evitar LiveComponent por linha.
- Nao trocar `dom_id` nem `data-*`; hooks de interacao dependem disso.

### F4 - Quebrar ChatLive shell em composicoes

Status: `CONCLUIDO`

Arquivo atual:

- `live/app/chat_live.html.heex`

Componentes alvo possiveis:

- `components/ui/shell/chat_desktop.ex`
- `components/ui/shell/chat_window_registry.ex`
- `components/ui/shell/chat_taskbar.ex`
- `components/ui/shell/channel_view_switcher.ex`
- ou `live/chat_live/components/chat_desktop_shell.ex` caso parte precise
  continuar como adapter stateful.

Componentes entregues:

- `components/ui/chat/chat_taskbar.ex`
- `components/ui/chat/channel_view_switcher.ex`

Escopo entregue:

- Extraida a taskbar do desktop de chat, preservando Start menu, tray clock,
  ids de janela, `data-testid` e regras de visibilidade dos botoes.
- Extraido o switcher Chat/Space/Call da topic bar, mantendo eventos e passando
  para UI apenas estados ja derivados pelo LiveView.
- Mantido o registry de `desktop_window` no template por enquanto, porque as
  janelas misturam montagem condicional, hooks, LiveComponents stateful e
  contratos de fechamento. Essa parte deve ser quebrada em uma frente propria
  se crescer mais.

Implementacao:

- Nao mover regras de dominio ou eventos.
- Extrair primeiro componentes sem estado:
  - taskbar do chat;
  - switcher Chat/Space/Conference no topic bar;
  - declaracoes repetitivas de `desktop_window` quando forem puramente
    declarativas.
- Manter no template principal os hidden hooks e forms que forem contratos de
  browser/root LiveView, a menos que uma composicao clara preserve o contrato.
- Para cada janela, garantir que o body continua sendo LiveComponent/UI
  existente, nao reimplementar dialog.
- Preservar todos os `window id`, `data-testid`, `on_close`, `open`,
  `persist_geometry` e dimensoes.

TDD/verificacao:

- LiveView tests garantindo que janelas principais ainda abrem:
  channel list, URL catcher, account, admin console quando admin, P2P stats,
  P2P call/files/games, group call, group call stats.
- E2E smoke do desktop: abrir/minimizar/restaurar janelas, taskbar e start menu.
- Screenshot Playwright antes/depois para comparar layout basico.

Riscos:

- O WindowManager depende de ids estaveis.
- A taskbar precisa refletir `@open_windows`, `@p2p_session`, `@group_call`,
  `@arcade_session` e permissoes admin.
- Extracao grande demais pode gerar regressao visual dificil de diagnosticar;
  fazer em passos pequenos.

### F5 - Migrar HelpLive para componentes UI

Status: `CONCLUIDO`

Arquivos atuais:

- `live/help_live/index.ex`
- `live/help_live/help_helpers.ex`

Componentes alvo:

- `components/ui/help/help_layout.ex`
- `components/ui/help/help_toolbar.ex`
- `components/ui/help/help_navigator.ex`
- `components/ui/help/help_topic_header.ex`
- `components/ui/help/help_topic_content_frame.ex`
- `components/ui/help/help_empty_state.ex`
- `components/ui/help/help_see_also.ex`

Componente entregue:

- `components/ui/help/help_viewer.ex`, com subcomponentes privados para shell,
  toolbar, navegador, tabs, resultados, header de topico, empty state, see also
  e taskbar.

Implementacao:

- Deixar `HelpLive.Index` com estado, busca, navegacao e `handle_params`.
- Mover layout desktop completo para UI.
- Mover toolbar CHM-style para UI.
- Mover tabs Contents/Index/Search para UI.
- Mover item de resultado/topico para UI.
- Mover header do topico e empty state para UI.
- Manter `render_topic_content/1` como helper de conteudo se ele for ponte para
  os modulos `HelpContent.*`, mas tirar layout visual dele.
- Preservar hooks `HelpNavHook` e `MenuBarHook`.
- Preservar rotas `/chat/help` e `/chat/help/:topic`.

TDD/verificacao:

- LiveView tests para selecionar topico, breadcrumb, tabs, busca com resultado,
  busca vazia e voltar ao chat.
- Teste de render para `help-desktop`, `help-window`, `help-content-pane`,
  `help-search-input`, `help-search-results`, `help-see-also`.
- E2E smoke de navegacao e busca.

Riscos:

- Existem muitos topicos de ajuda. Nao mexer no conteudo enquanto migrar a
  shell.
- `render_topic_content/1` usa `String.to_existing_atom`; preservar ids.

### F6 - Componentizar landing pages publicas

Status: `CONCLUIDO`

Arquivos atuais:

- `live/landing_live/*.html.heex`
- `live/landing_live/landing_helpers.ex`

Componentes alvo:

- `components/ui/landing/landing_layout.ex`
- `components/ui/landing/landing_taskbar.ex`
- `components/ui/landing/landing_menu_bar.ex`
- `components/ui/landing/landing_hero.ex`
- `components/ui/landing/landing_window_section.ex`
- `components/ui/landing/landing_icon_list.ex`
- `components/ui/landing/landing_desktop_folder.ex`
- `components/ui/landing/landing_feature_card.ex`
- `components/ui/landing/landing_mockups.ex`

Componente entregue:

- `components/ui/landing/landing_shell.ex`

Escopo entregue:

- Movida a shell publica compartilhada para UI: layout, header, menu bar,
  taskbar/start menu, mobile nav, page intro e footer.
- `live/landing_live/landing_helpers.ex` virou adapter/delegador para preservar
  os imports existentes dos templates.
- Conteudo editorial das paginas foi mantido nos templates para evitar
  reescrita de copy, headings e SEO.

Implementacao:

- Manter conteudo editorial nos templates quando ele for texto unico da pagina.
- Extrair padroes repetidos:
  - janela com title bar + body + status bar;
  - listas de beneficios com icone;
  - secoes grid de cards;
  - desktop folder;
  - mockups reutilizados;
  - taskbar e start menu publicos;
  - menu bar publico.
- Evitar over-abstraction: nao criar componente para um unico paragrafo.
- Preservar SEO: headings, `aria-labelledby`, links reais, `hreflang`,
  localized paths e ausencia de dependencia LiveSocket para paginas publicas.
- Preservar assets reais como `wordmark.svg` e diagramas existentes.

TDD/verificacao:

- Tests de render das paginas principais se ja houver infraestrutura; caso nao,
  adicionar smoke tests focados.
- E2E publico leve para home/features/how-it-works/privacy/faq.
- Verificar mobile e desktop com screenshot Playwright nas paginas mais densas.

Riscos:

- Landing e SEO sao sensiveis a headings e texto; nao reescrever copy durante a
  componentizacao.
- Public pages usam JS vanilla; nao introduzir contratos LiveView desnecessarios.

## Ordem recomendada

1. F2 - SessionCard
   - Baixo risco e corrige violacao clara.
   - Prepara F3.

2. F1 - ConnectLive
   - Violacao mais clara de tela completa.
   - Risco moderado por auth/session form.

3. F3 - MessageRow
   - Fazer depois do SessionCard.
   - Exige cuidado por hot path e hooks.

4. F5 - HelpLive
   - Superficie publica/prod, mas isolada.
   - Bom ganho arquitetural com risco contido.

5. F4 - ChatLive shell
   - Fazer em pequenos PRs/commits.
   - Maior risco de WindowManager/taskbar.

6. F6 - Landing
   - Maior volume editorial.
   - Menor risco operacional, mas precisa preservar SEO.

## Checklist global de aceite

Para cada frente:

- [x] Nenhum novo componente visual pesado em `live/**`.
- [x] UI visual extraida para `components/ui/**`.
- [x] LiveView/LiveComponent virou adapter/orquestrador.
- [x] `data-testid` preservado ou alterado com justificativa e testes.
- [x] Eventos e `phx-hook` preservados.
- [x] Icones via `RetroHexChatWeb.Icons`.
- [x] Sem emoji como icone funcional.
- [x] Textos novos com Gettext quando user-facing.
- [x] Tests cobrindo comportamento, nao apenas presenca de botao.
- [x] `mix format` executado.
- [x] `git diff --check` sem problemas.

Gate final do plano:

- [x] `make ci`
- [x] E2E smoke das superficies afetadas.
- [x] Revisao visual via Playwright para connect, chat desktop, help e landing.
- [x] Atualizar `docs/AGENT-GUIDE.md` com aprendizado duravel.
- [x] Cristalizar regras duraveis em `docs/AGENT-GUIDE.md`; este plano fica em
  `docs/plans` como historico da implementacao.

## Regras de git para este plano

- Antes de qualquer commit/push em `main`: rodar `git fetch`, verificar
  `git status` e trazer a main com `git pull --ff-only`.
- Se houver edicoes locais antes do pull, usar stash/autostash de forma
  explicita e re-aplicar antes de testar.
- Nunca fazer push sem revisar se `origin/main` andou.
- Deploy deve usar os comandos do `Makefile`, especialmente `make deploy`, nao
  comandos manuais que pulem o fluxo do projeto.

## Perguntas que nao bloqueiam

- O `MessageRow` deve passar strings ja formatadas para UI ou permitir que o UI
  use `ChatHelpers` para formatacao visual?
- A shell do `ChatLive` deve ir para `components/ui/shell` ou permanecer como
  `live/chat_live/components` quando carregar muitos eventos/window contracts?
- Landing deve ser tratada com a mesma severidade do app operacional ou apenas
  componentizada onde houver repeticao clara?

Decisao inicial recomendada: aplicar a regra com rigor nas superficies
operacionais (`connect`, chat/P2P/message/help) e com pragmatismo nas paginas
editoriais (`landing`), extraindo repeticoes reais sem transformar copy unica em
abstracoes artificiais.
