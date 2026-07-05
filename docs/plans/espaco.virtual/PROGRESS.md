# PROGRESS — Espaço Virtual

Arquivo vivo do loop de implementação. Toda iteração começa lendo este arquivo
e termina atualizando-o. O checklist canônico é o
`05-plano-implementacao.md`; aqui ficam estado, histórico e aprendizados.

## Estado atual

- **Status**: EM ANDAMENTO
- **Fase corrente**: Fase 1 — domínio, comando, card e channel mínimo
- **Próximo item**: migration `virtual_space_sessions` (primeiro item da
  Fase 1; começar pelos testes de
  `virtual_space/schema/session_test.exs` — ver `09-mapa-de-testes.md` §Fase 1)
- **Último commit do projeto**: nenhum ainda

## Perguntas para o usuário

(nenhuma pendente)

## Aprendizados acumulados

Registrados na fase de planejamento/auditoria (2026-07-05), válidos para toda a
implementação:

- **Gabarito de contexto**: `RetroHexChat.Lobby` é o análogo exato do layout
  planejado (facade + policy/queries/registry/service/session_server/
  supervisor/schema). `Arcade` nomeia diferente — não usar como gabarito.
- **Primeira Phoenix Channel do projeto**: não existe UserSocket, `socket
  "/socket"`, diretório `channels/` nem ChannelCase. Tudo nasce na Fase 1.
- **Contrato de handler**: retorno `{:ok, :ui_action, atom, map}` com payload
  contendo `target`/`token`/`creator_id` (gabarito `Handlers.Lobby`); registro
  no mapa `@commands` de `Commands.Registry`; behaviour exige `help/0`,
  `syntax_definition/0` opcional, `category/0`.
- **Card em canal é inédito**: `:p2p_invite` só existe em `PrivateMessage`;
  `:arcade_link` é efêmero. `space_invite` entra em `Chat.Message @type_values`
  + `Chat.Service @known_types` (decisão 19).
- **Sem refresh ao vivo de card** (decisão 20): enrich no build da linha, como
  hoje.
- **Mapa canônico no Elixir** (decisão 21): cliente recebe tudo no
  `space_init`, sem cópia JS.
- **Settings de admin**: runtime via tabela `server_settings`
  (`get_setting/1` + fallback; whitelist em
  `Handlers.Admin.Server.validate_setting_value/2`), não config estática.
- **lazyFeatureHook**: `reason` obrigatório; `serverEvents: []` quando o hook
  não recebe eventos LiveView (caso do SpaceCanvasHook).
- **Sem precedente de netcode**: previsão/reconciliação é trabalho novo; os
  jogos atuais são host-autoritativos via DataChannel binário. Não herdar de
  `lib/game_engine.js`.
- **Ciclo de validação**: por arquivo durante o loop; `make ci` completo
  SOMENTE no fechamento de fase (pedido explícito do usuário — o CI é lento).
- **Commits**: um por fase, direto na `main`, stage por caminho explícito.

## Histórico de iterações

### 2026-07-05 — Planejamento (sessão de auditoria)

- Plano auditado contra o codebase com 3 varreduras (domínio, web, JS); todos
  os apontamentos inválidos corrigidos nos docs 00–08.
- 4 ambiguidades levadas ao usuário e fechadas (decisões 18–21 no doc 06).
- `05-plano-implementacao.md` reescrito como checklist rastreável por fase;
  `09-mapa-de-testes.md` criado (inventário TDD por fase);
  `10-prompt-loop.md` criado (prompt do loop); este PROGRESS criado.
- Implementação: nada iniciado. A Fase 1 começa na próxima iteração.
