# Padronizacao LiveView/UI - progresso e aprendizados

> Criado em 2026-07-13. Plano base:
> `docs/plans/liveview-ui-composition-standardization.md`.

## Objetivo do acompanhamento

Registrar o progresso da padronizacao LiveView/UI, os aprendizados encontrados
durante a implementacao e os gates usados para garantir que a refatoracao nao
degrade features existentes.

## Gate de regressao

Os testes atuais devem servir como gate sempre que cobrirem a superficie
alterada. Quando a cobertura existente for insuficiente, a frente deve adicionar
teste focado antes de considerar a refatoracao concluida.

Gate minimo por ciclo:

- `mix format` depois de alteracoes Elixir/HEEx.
- Testes focados da superficie alterada.
- `git diff --check`.
- Quando a alteracao tocar fluxo de usuario ou window manager, rodar smoke E2E
  ou Playwright focado.

Gate final do plano:

- `make ci`, se o tempo/local permitir.
- E2E smoke para connect, chat desktop, help e landing.
- Revisao do diff para garantir que a camada `live/**` ficou como adapter e que
  a UI visual migrou para `components/ui/**`.

## Ciclos

### 2026-07-13 - Inicio

Status: `CONCLUIDO`

Decisoes:

- Admin LiveDashboard fica fora do escopo.
- A ordem de implementacao segue o risco: SessionCard, ConnectLive, MessageRow,
  HelpLive, ChatLive shell, Landing.
- Cada frente precisa preservar `data-testid`, eventos, hooks, ids do window
  manager e iconografia via `RetroHexChatWeb.Icons`.

Validacao planejada:

- Mapear testes existentes antes de mexer nos arquivos.
- Adicionar testes apenas onde houver lacuna real de regressao.

Aprendizados:

- A cobertura existente ja oferece gates uteis para as primeiras frentes:
  `session_card_test.exs`, `message_row_test.exs`,
  `connect_desktop_shell_test.exs`, `help_live_test.exs`,
  `chat_desktop_shell_test.exs`, E2E `connect-flow.spec.ts`,
  `chat-help.spec.ts`, `chat-message-rendering.spec.ts`,
  `landing-public.spec.ts` e testes JS do `WindowManagerHook`.
- Os gates atuais nao substituem teste novo quando a refatoracao criar um
  componente UI novo com contrato proprio; nesse caso o teste deve acompanhar a
  migracao.

### 2026-07-13 - F2 SessionCard

Status: `CONCLUIDO`

Alteracoes:

- Movido `RetroHexChatWeb.ChatLive.Components.SessionCard` para
  `RetroHexChatWeb.Components.UI.SessionCard`.
- Atualizado `MessageRow` para importar o card pela camada UI.
- Atualizado o teste do card para o novo namespace.

Validacao:

- `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/session_card_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/message_row_test.exs`
  - Resultado: 21 testes, 0 falhas.

Aprendizados:

- O card era totalmente visual e side-effect free; a migracao para UI nao exigiu
  adapter Live.
- O card dispara eventos no root LiveView, entao o componente UI deve continuar
  sem `phx-target`.

### 2026-07-13 - F1 ConnectLive

Status: `CONCLUIDO`

Alteracoes:

- Criado `RetroHexChatWeb.Components.UI.ConnectScreen`.
- Movida a shell visual da conexao para a camada UI: desktop, app header,
  connect window, forms por step, locale switcher, taskbar, session form e
  about dialog.
- `ConnectLive` ficou com estado, validacao, auth, menu actions e helper de
  rotas verificadas para locales.
- `connect_live.html.heex` virou uma chamada unica a `<.connect_screen />`.

Validacao:

- `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/connect_desktop_shell_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/i18n_live_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/controllers/session_controller_test.exs`
  - Resultado: 25 testes, 0 falhas.

Aprendizados:

- Componentes UI nao usam `~p`; o LiveView deve passar paths prontos quando a
  rota precisa continuar verificada.
- O CSRF token tambem entra como attr para o componente visual nao chamar APIs
  de sessao diretamente.

### 2026-07-13 - F3 MessageRow

Status: `CONCLUIDO`

Alteracoes:

- Criado `RetroHexChatWeb.Components.UI.MessageRow.message_row_body/1`.
- Mantido `RetroHexChatWeb.ChatLive.Components.MessageRow` como wrapper de
  stream, preservando `id`, classes e `data-*`.
- Movida a composicao visual por tipo de mensagem para a camada UI.

Validacao:

- `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/message_row_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/session_card_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/message_viewport_test.exs`
  - Resultado: 28 testes, 0 falhas.

Aprendizados:

- A extracao manteve o hot path barato: nenhuma linha de mensagem virou
  LiveComponent.
- URLs de help dentro do componente UI foram mantidas como strings simples para
  evitar `~p` na camada UI; se essa regra ficar recorrente, criar attr de path
  pronto no adapter.

### 2026-07-13 - F5 HelpLive

Status: `CONCLUIDO`

Alteracoes:

- Criado `RetroHexChatWeb.Components.UI.Help.HelpViewer`.
- Movida a shell CHM-style de ajuda para a camada UI: desktop, janela, toolbar,
  navegador Contents/Index/Search, resultados, frame de topico, empty state,
  see also e taskbar.
- `HelpLive.Index` ficou responsavel por estado, busca, selecao de topico e
  `handle_params`.
- `HelpLive.HelpHelpers` ficou como adapter de conteudo, delegando a UI visual
  e preservando os helpers usados pelos templates `HelpContent.*`.

Validacao:

- `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/help_live_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/help_system_feature_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/feature/help_access_feature_test.exs`
  - Resultado: 18 testes, 0 falhas, 9 excluidos.

Aprendizados:

- O conteudo dos topicos deve permanecer separado da shell visual; o dispatcher
  por `String.to_existing_atom/1` continua no adapter para nao espalhar logica
  dinamica na camada UI.
- Preservar ids, hooks e titulo da janela e essencial para nao quebrar
  navegacao, history local e testes de desktop.

### 2026-07-13 - F4 ChatLive shell

Status: `CONCLUIDO`

Alteracoes:

- Criado `RetroHexChatWeb.Components.UI.ChatTaskbar`.
- Criado `RetroHexChatWeb.Components.UI.ChannelViewSwitcher`.
- `chat_live.html.heex` passou a montar a taskbar por composicao UI e deixou o
  seletor Chat/Space/Call como componente visual.
- Removidos imports diretos da Start menu e do badge de call no LiveView,
  mantendo no LiveView apenas a derivacao de estado por canal.

Validacao:

- `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_desktop_shell_test.exs`
  - Resultado: 12 testes, 0 falhas.

Aprendizados:

- A taskbar e uma superficie boa para componente UI porque e basicamente uma
  leitura visual de `open_windows` e sessoes ativas.
- O registry de janelas do ChatLive ainda mistura montagem condicional,
  LiveComponents stateful, hooks e semantica de fechamento. Ele deve ser
  quebrado em uma frente propria se necessario, nao junto com a taskbar.

### 2026-07-13 - F6 Landing

Status: `CONCLUIDO`

Alteracoes:

- Criado `RetroHexChatWeb.Components.UI.Landing.LandingShell`.
- Movida a shell publica compartilhada para UI: layout, header, menu bar,
  taskbar/start menu, mobile nav, page intro e footer.
- `RetroHexChatWeb.LandingLive.LandingHelpers` virou adapter/delegador para
  manter os templates existentes sem churn.

Validacao:

- `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/controllers/landing_controller_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/seo_test.exs`
  - Resultado: 87 testes, 0 falhas.

Aprendizados:

- A landing mistura componente visual e conteudo editorial. Mover a shell
  compartilhada primeiro da ganho arquitetural sem reescrever copy ou headings.
- Os testes de SEO/render sao um gate importante aqui: eles protegem links reais,
  headings, canonical/localized paths e conteudo publico.

### 2026-07-13 - Gate final

Status: `CONCLUIDO`

Validacao:

- `mix format`
  - Resultado: ok.
- `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/session_card_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/message_row_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/message_viewport_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/connect_desktop_shell_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/i18n_live_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/controllers/session_controller_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/help_live_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/help_system_feature_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/feature/help_access_feature_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_desktop_shell_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/controllers/landing_controller_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/seo_test.exs`
  - Resultado: 170 testes, 0 falhas, 9 excluidos.
- `make ci`
  - Primeira execucao: falha intermitente em Feature Tests por Ecto Sandbox no
    cleanup de `GroupCall.RoomServer.leave_participant/4`.
  - Reproducao isolada: `make test.feature` passou com 254 testes, 0 falhas.
  - Reproducao do worker: `MIX_TEST_PARTITION=2 mix test --only liveview_feature`
    passou com 254 testes, 0 falhas.
  - Segunda execucao de `make ci`: 9/9 checks, tudo passou, incluindo Dialyzer.
- Playwright headless focado:
  - `npm test -- tests/landing-public.spec.ts tests/connect-flow.spec.ts tests/chat-ui-features-shell.spec.ts tests/chat-help.spec.ts`
  - Resultado: 10 testes, 0 falhas.
- `git diff --check`
  - Resultado: sem problemas.

Correcoes feitas durante o gate:

- Atualizado `chat-ui-features-shell.spec.ts` para o menu atual, que inclui
  `P2P` e `Games`.
- Atualizada a assercao de `/me` para validar texto de acao e autoria como
  contratos separados.
- Atualizado `landing-public.spec.ts` para clicar no link visivel `My Chats`,
  evitando selecionar um link de menu oculto.

Aprendizados:

- O E2E local pegou expectativas stale dos specs, nao regressao da composicao.
- Para alteracoes de shell publica, seletores E2E devem mirar elementos visiveis
  e sem ambiguidade; links duplicados em menus ocultos quebram `.first()`.
- `make ci` segue sendo o gate principal. Quando falhar por feature tests em
  cleanup assincrono, reproduzir o worker isolado antes de atribuir a falha a
  mudanca de produto.
