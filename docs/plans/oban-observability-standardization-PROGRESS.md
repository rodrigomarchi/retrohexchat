# Oban - progresso e aprendizados

Plano base: `docs/plans/oban-observability-standardization.md`

Criado em: 2026-08-05

## Objetivo deste acompanhamento

Registrar o progresso real da padronizacao Oban, os aprendizados de execucao, as
decisoes tomadas durante implementacao e a divida controlada da janela admin de
Oban.

Este arquivo nao muda o escopo. O escopo completo continua no plano base. Este
arquivo existe para impedir perda de contexto entre iteracoes longas e para
garantir que cada migracao deixe rastreio claro de:

- o que foi alterado;
- quais arquivos reais foram tocados;
- quais validacoes passaram;
- o que aprendemos que nao estava obvio no plano;
- quais contratos precisam aparecer na janela admin do Oban.

## Invariantes

- Nenhum fluxo migrado pode manter o agendador antigo por garantia.
- Nenhum worker novo deve chamar Oban direto fora de `RetroHexChat.Jobs` ou de
  scheduler de dominio que use `RetroHexChat.Jobs`.
- Todo worker precisa ser idempotente, retryable/cancellable de forma explicita
  e observavel.
- Todo fluxo removido de GenServer, timer ou Task deve remover tambem codigo
  morto, filhos antigos da supervision tree e testes obsoletos.
- Toda feature nova em Oban deve registrar aqui a secao que a janela admin deve
  exibir, mesmo que a consolidacao visual fique para o final.
- O gate final de implementacao continua sendo `make ci`.

## Loop de execucao

Para cada fluxo do plano base:

1. Registrar uma entrada em "Iteracoes" com objetivo, arquivos esperados e
   contrato de observabilidade/admin.
2. Implementar dominio, worker, enqueue/cancelamento, configuracao de fila/cron e
   remocoes do caminho antigo.
3. Adicionar ou atualizar testes de dominio, worker, cancelamento, retry/cancel e
   admin snapshot quando aplicavel.
4. Atualizar PromEx/telemetry para metricas genericas ou de dominio que o fluxo
   exigir.
5. Registrar aprendizados e divergencias reais encontradas no codigo.
6. Atualizar o tracker de status e a divida da janela admin.
7. Rodar validacoes focadas durante a iteracao, cobrindo os arquivos e fluxos
   tocados.
8. Reservar `make ci` para o fechamento consolidado da padronizacao completa ou
   para o momento de producao/commit/push/deploy, evitando repetir o guard
   completo a cada fluxo migrado.

## Tracker geral

| Fluxo | Status | Commit | Validacao | Observacao |
|---|---|---|---|---|
| Plano mestre auditado | CONCLUIDO | - | path refs + ASCII | `docs/plans/oban-observability-standardization.md` tem refs reais e foi complementado com ajustes finais pos-auditoria. |
| Server ban expiry | CONCLUIDO | - | `make ci` 13/13 | Migrado para `RetroHexChat.Jobs.ServerBanExpiryWorker`, fila `maintenance`, cron `@reboot`/`@hourly`. |
| Registered channel expiry | CONCLUIDO | - | `make ci` 13/13 | `Services.ChanExpiry` virou dominio puro; worker `RegisteredChannelExpiryWorker` roda em `maintenance` por cron. |
| Registered nick expiry | CONCLUIDO | - | focused tests | `Services.NickExpiry` virou dominio puro; worker `RegisteredNickExpiryWorker` roda em `maintenance` por cron. |
| Bot scheduled messages | CONCLUIDO | - | focused tests | `Scheduler` nao usa mais timer local; `BotScheduledMessageWorker` roda na fila `bots`. |
| Bot event log | CONCLUIDO | - | focused tests | `Task.start/1` saiu do fluxo; `BotEventLogWorker` grava logs na fila `bots`. |
| Link preview fetch | CONCLUIDO | - | focused tests | `Task.Supervisor.async_nolink/2` saiu do fluxo; `LinkPreviewFetchWorker` usa fila `link_preview` e cache duravel. |
| Preference/list persistence | CONCLUIDO | - | focused tests | `Task.start/1` saiu de preferencias/listas; `PreferenceSaveWorker` usa fila `persistence` e outbox coalescida. |
| Attachment orphan cleanup | CONCLUIDO | - | focused tests | `AttachmentOrphanCleanupWorker` limpa uploads `reserved/uploaded` antigos na fila `maintenance`. |
| Trusted devices/session cleanup | CONCLUIDO | - | focused tests | Workers `TrustedDeviceExpiryWorker` e `ChatDeviceSessionCleanupWorker` rodam em `maintenance`. |
| Lobby/arcade/group_call stale cleanup | CONCLUIDO | - | focused tests | `RuntimeStaleCleanupWorker` expira registros stale de lobby/arcade/group_call na fila `maintenance`. |
| Channel mute duravel | CONCLUIDO | - | focused tests | `channel_mutes` + `ChannelMuteExpiryWorker`; `Process.send_after/3` saiu do mute por canal. |
| Global mute duravel | CONCLUIDO | - | focused tests | `global_mutes` + `GlobalMuteExpiryWorker`; ETS virou cache derivado. |
| Ignore entries expiration | CONCLUIDO | - | focused tests | `IgnoreExpiredCleanupWorker` limpa expirados duraveis; timers LiveView ficam apenas para UX. |
| PromEx/telemetry multi-dominio | CONCLUIDO | - | focused tests | `Observability` emite counters/values whitelisted e PromEx/Telemetry exportam metricas multi-dominio. |
| Janela admin Oban completa | CONCLUIDO | - | focused tests | Janela mostra filas, jobs filtraveis, RSS, bot schedules, bot event logs, maintenance, link preview e persistence. |
| Ajustes finais padrao ouro | CONCLUIDO | - | `make ci` 13/13 | Fechado retry/falha final de link preview, boundary do nuke, cardinalidade PromEx e linguagem multi-contrato. |
| Tabs da janela admin Oban | CONCLUIDO | - | focused + e2e shots | Janela agrupa overview, filas/jobs, bots, maintenance, previews e persistence sem perder nenhum contrato observavel. |

## Divida controlada da janela admin Oban

Arquivos atuais da janela:

- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/oban_health.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/system_oban_dialog.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/system/oban_panel.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/window_registry.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex`

Contrato atual:

- filas;
- jobs recentes filtraveis por estado, fila e worker;
- contrato RSS de sucessor;
- contrato de schedules de bot;
- backlog/falhas de bot event log;
- sweeps de maintenance;
- cache de link preview;
- persistencia de preferencias/listas.
- navegacao por tabs para focar overview, filas/jobs, bots, maintenance,
  previews e persistence.

Contratos que devem existir ao final:

| Contrato admin | Status | Origem |
|---|---|---|
| Queue health por fila e estado | CONCLUIDO | Tabela `Queues by state` e card de jobs ativos. |
| Jobs recentes filtraveis por worker/fila/estado | CONCLUIDO | Filtro por estado, fila e worker na secao `Recent jobs`. |
| RSS successor coverage | CONCLUIDO | Tabela `RSS feed coverage` e card `RSS feeds`. |
| Maintenance sweeps last-run/last-error | CONCLUIDO | Tabela `Maintenance sweeps` cobre todos os workers de maintenance migrados. |
| Bot schedules successor coverage | CONCLUIDO | Tabela `Bot schedule coverage` e card `Bot schedules`. |
| Bot event log backlog/failures | CONCLUIDO | Tabela `Bot event log jobs` e card `Bot event logs`. |
| Link preview cache/fetch health | CONCLUIDO | Tabela `Link preview cache` e card `Link previews`. |
| Link preview retry vs final failure | CONCLUIDO | Tabela `Link preview cache` separa `retrying` de `final_failures`. |
| Persistence backlog/oldest pending | CONCLUIDO | Tabela `Preference persistence` e card `Preference saves`. |
| Storage cleanup summary | CONCLUIDO | `Attachment orphan cleanup` aparece em maintenance com pending work e falhas. |
| Runtime stale cleanup summary | CONCLUIDO | `Runtime stale cleanup` aparece em maintenance com pending work e falhas. |
| Durable mute expirations | CONCLUIDO | `Channel mute expiry` e `Global mute expiry` aparecem em maintenance. |
| Ignore list durable cleanup | CONCLUIDO | `Ignore expired cleanup` aparece em maintenance com pending work e falhas. |
| Agrupamento visual por tabs | CONCLUIDO | Tabs `Overview`, `Queues`, `Bots`, `Maintenance`, `Previews` e `Persistence`. |

Regra: quando um worker novo entrar sem UI final, adicionar aqui uma linha de
divida com o snapshot necessario em `ObanHealth`, as metricas esperadas e o
estado visual esperado. A consolidacao visual pode ser feita depois das
migracoes, mas a informacao operacional nao pode ficar indefinida.

## Iteracoes

### 2026-08-06 - Tabs da janela admin Oban

Status: CONCLUIDO

Objetivo:

- Reduzir a lista longa vertical da janela Oban sem remover informacao
  operacional.
- Manter resumo de saude e cards de contratos sempre visiveis.
- Agrupar analises detalhadas em tabs por foco operacional: overview,
  filas/jobs, bots, maintenance, previews e persistence.

Arquivos esperados:

- `docs/plans/oban-observability-standardization.md`
- `docs/plans/oban-observability-standardization-PROGRESS.md`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/system_oban_dialog.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/admin_shared.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/system/oban_panel.ex`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/system_windows_feature_test.exs`
- `e2e/tests/chat-system-windows.spec.ts`

Contrato admin esperado:

- A janela deve abrir em `Overview`.
- O topo deve continuar expondo saude geral e cards de contratos duraveis.
- `Queues` deve concentrar filas por estado e jobs recentes filtraveis.
- `Bots` deve concentrar RSS, schedules e event logs.
- `Maintenance` deve concentrar todos os sweeps duraveis.
- `Previews` deve concentrar link preview cache, retry e falha final.
- `Persistence` deve concentrar outbox de preferencias/listas.

Validacao:

- `mix format apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/system_oban_dialog.ex apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/system/oban_panel.ex apps/retro_hex_chat_web/test/retro_hex_chat_web/live/system_windows_feature_test.exs`
- `mix compile --warnings-as-errors`
- `mix test --warnings-as-errors apps/retro_hex_chat_web/test/retro_hex_chat_web/live/system_windows_feature_test.exs --include liveview_feature`
  passou: 12 testes, 0 falhas.
- `MIX_ENV=e2e PGPORT=5433 E2E_PORT=4004 E2E_BASE_URL=http://localhost:4004 BASE_URL=http://localhost:4004 PUBLIC_ORIGIN=http://localhost:4004 mix assets.build`
- `E2E_SHOTS=1 MIX_ENV=e2e PGPORT=5433 E2E_PORT=4004 E2E_BASE_URL=http://localhost:4004 BASE_URL=http://localhost:4004 PUBLIC_ORIGIN=http://localhost:4004 npx playwright test tests/chat-system-windows.spec.ts --grep "Oban health window" --project=chromium --reporter=list`
  passou: 1 teste, 0 falhas, com screenshots em
  `e2e/screenshots/chat-system-windows/the-oban-health-window-groups-contracts-into-tabs-without-horizontal-overflow/`.
- `git diff --check`

Aprendizados:

- A janela estava operacionalmente completa, mas o empilhamento de todas as
  tabelas diluia foco: o problema era informacional/visual, nao de snapshot.
- A tab ativa deve morar no LiveComponent para que refresh e filtro continuem
  deterministas e testaveis no mesmo contrato LiveView.
- Usar o primitive de tabs existente preserva o padrao visual Win98 da
  plataforma e evita criar uma segunda implementacao de navegacao.
- O primeiro Playwright encontrou overflow real na tabela `system-oban-rss-table`
  (`scrollWidth` maior que `clientWidth`) que os testes LiveView nao
  capturavam. A correcao foi permitir `table_class` em `admin_table/1` e usar
  `table-fixed` nas tabelas Oban, preservando truncamento com `title`.

### 2026-08-06 - Ajustes finais de padrao ouro Oban

Status: CONCLUIDO

Objetivo:

- Fechar as ressalvas da auditoria pos-deploy da padronizacao Oban.
- Separar visualmente retry transitorio e falha final de link preview na janela
  admin.
- Remover a referencia direta a `Oban.Job` do reset administrativo.
- Bucketizar erro binario arbitrario no plugin PromEx de Oban.
- Reconciliar linguagem/documentacao que ainda parecia RSS-centrica.

Arquivos esperados:

- `docs/plans/oban-observability-standardization.md`
- `docs/plans/oban-observability-standardization-PROGRESS.md`
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/admin.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/link_preview/results.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/oban_health.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/system/oban_panel.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/prom_ex/plugins/oban.ex`
- `apps/retro_hex_chat/test/retro_hex_chat/jobs/oban_health_test.exs`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/prom_ex_test.exs`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/system_windows_feature_test.exs`

Contrato admin esperado:

- `Link preview cache` deve mostrar `retrying` separado de `final_failures`.
- A saude geral deve sinalizar retry transitorio em andamento, mas nao tratar
  falha final deterministica como erro operacional por si so.
- A mensagem healthy deve falar de contratos duraveis, nao apenas RSS.

Validacao:

- `mix compile --warnings-as-errors`
- `mix test --warnings-as-errors apps/retro_hex_chat/test/retro_hex_chat/jobs/oban_health_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/prom_ex_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/system_windows_feature_test.exs apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/admin/nuke_test.exs --include liveview_feature`
  passou: 40 testes, 0 falhas.
- `make ci` passou: 13/13 checks, incluindo testes particionados, feature tests,
  i18n, CSS lint e Dialyzer.

Aprendizados:

- Quando a tabela de dominio ja agrega status, o refinamento operacional deve
  acrescentar dimensoes de baixa cardinalidade (`retrying`, `final_failures`) em
  vez de vazar URL, host ou erro bruto.
- Falha final deterministica de link preview e dado operacional, nao motivo de
  warning global por si so; retry transitorio em andamento e o sinal que merece
  destaque na saude.
- Mesmo fluxos administrativos excepcionais, como nuke, devem respeitar o
  boundary `RetroHexChat.Jobs` para que o codigo de dominio nao conheca `Oban.Job`.
- Tags de Prometheus precisam assumir que texto binario pode conter dado
  arbitrario; o padrao seguro e whitelist curta mais bucket generico.

### 2026-08-05 - Ajuste final P2P/ignore com outbox Oban

Status: CONCLUIDO

Objetivo:

- Fechar a janela de corrida criada pela migracao da persistencia de
  preferencias para Oban: `/ignore` fecha sessoes P2P ativas de forma sincrona,
  mas a tabela `ignore_list_entries` so e materializada quando
  `PreferenceSaveWorker` aplica o snapshot.
- Garantir que um usuario ignorado nao consiga iniciar novo `/p2p` antes do job
  de persistencia rodar.

Feito:

- `apps/retro_hex_chat/lib/retro_hex_chat/lobby/policy.ex` passou a considerar
  `preference_save_requests` como leitura efetiva quando existe snapshot
  `ignore_list` ainda nao aplicado.
- O snapshot pendente sobrescreve a tabela materializada: ignore pendente bloqueia
  imediatamente; unignore pendente libera imediatamente.
- A leitura materializada de `ignore_list_entries` passou a ignorar entradas
  vencidas enquanto o cleanup duravel ainda nao executou.
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/ignore_entry.ex` passou a aceitar
  entradas hidratadas do outbox em `expired?/2`, mantendo compatibilidade com
  snapshots JSONB.
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/link_preview/http.ex`,
  `apps/retro_hex_chat/lib/retro_hex_chat/admin/global_mutes.ex`,
  `apps/retro_hex_chat/lib/retro_hex_chat/channels/mutes.ex` e
  `apps/retro_hex_chat/lib/retro_hex_chat/bots/server.ex` foram limpos para
  remover clauses inalcançaveis apontadas pelo Dialyzer.
- `apps/retro_hex_chat/test/retro_hex_chat/lobby/service_test.exs` ganhou testes
  cobrindo o bloqueio por snapshot pendente e o override por unignore pendente.
- `apps/retro_hex_chat/test/retro_hex_chat/bots/bot_lifecycle_test.exs` foi
  ajustado para validar `BotEventLogWorker` enfileirado/drenado em vez de esperar
  log escrito por `Task`.
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/event_routing_test.exs`
  passou a drenar push events residuais do mount e enviar `:system_nuked`
  diretamente ao processo LiveView, cobrindo o roteamento sem race no topico
  global de PubSub entre feature tests.
- `apps/retro_hex_chat/test/retro_hex_chat/system_info/query_test.exs` deixou de
  usar `:erlang.system_info(:atom_count)` global e passou a verificar que o nome
  desconhecido especifico nao foi internado como atomo.

Validacao:

- `mix compile --warnings-as-errors`
- `mix test --warnings-as-errors apps/retro_hex_chat/test/retro_hex_chat/lobby/service_test.exs`
- `mix test --warnings-as-errors apps/retro_hex_chat/test/retro_hex_chat/bots/bot_lifecycle_test.exs`
- `mix test --warnings-as-errors apps/retro_hex_chat/test/retro_hex_chat/admin/global_mutes_test.exs apps/retro_hex_chat/test/retro_hex_chat/jobs/global_mute_expiry_worker_test.exs`
- `mix test --warnings-as-errors apps/retro_hex_chat/test/retro_hex_chat/channels/mutes_test.exs apps/retro_hex_chat/test/retro_hex_chat/jobs/channel_mute_expiry_worker_test.exs`
- `mix test --warnings-as-errors apps/retro_hex_chat/test/retro_hex_chat/chat/link_preview/http_test.exs apps/retro_hex_chat/test/retro_hex_chat/net/http_retry_test.exs apps/retro_hex_chat/test/retro_hex_chat/jobs/link_preview_fetch_worker_test.exs`
- `mix test --warnings-as-errors apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs:1279 --include liveview_feature`
- `mix test --warnings-as-errors apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs --include liveview_feature`
- `mix test --warnings-as-errors apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/event_routing_test.exs --include liveview_feature`
- `mix test --warnings-as-errors apps/retro_hex_chat/test/retro_hex_chat/system_info/query_test.exs`
- `mix credo --strict`
- `mix dialyzer`
- `git diff --check`
- `make ci` passou: 13/13 checks, incluindo testes particionados, feature tests e
  Dialyzer.

Aprendizados:

- Quando um fluxo de seguranca passa a depender de um outbox Oban, politicas de
  dominio nao podem ler apenas a tabela materializada. Elas precisam ler o
  snapshot pendente como fonte efetiva ate o worker aplicar a revisao.
- Para preferencias coalescidas, o snapshot pendente deve sobrescrever a tabela,
  nao ser combinado com ela, senao `/unignore` fica preso ate o job rodar.
- Testes que antes aguardavam side effect de `Task` precisam validar o contrato
  Oban novo: job enfileirado e execucao controlada via `Oban.drain_queue/1`.
- Feature tests que verificam push events depois do mount precisam drenar eventos
  residuais antes de provocar o evento sob teste; quando o objetivo e roteamento
  de `handle_info/2`, enviar a mensagem ao processo LiveView e mais estavel que
  depender de topico global de PubSub compartilhado por outros testes.
- Testes de protecao contra atom leak nao devem comparar `atom_count` global em
  uma VM com testes concorrentes; devem verificar a existencia do atomo especifico
  antes e depois da chamada.

### 2026-08-05 - Link preview fetch em Oban

Status: CONCLUIDO

Objetivo:

- Migrar o fetch de titulo do URL Catcher para Oban sem depender do pid da
  LiveView.
- Persistir resultado de preview em banco e manter ETS apenas como cache
  derivado/read-through.
- Remover `RetroHexChat.LinkPreviewTasks` da supervision tree.

Feito:

- Criada a migration
  `apps/retro_hex_chat/priv/repo/migrations/20260805122000_create_link_previews.exs`.
- Criados `apps/retro_hex_chat/lib/retro_hex_chat/chat/link_preview/result.ex` e
  `apps/retro_hex_chat/lib/retro_hex_chat/chat/link_preview/results.ex`.
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/link_preview/cache.ex` passou a
  chavear por `url_hash` normalizado e fazer read-through no banco.
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/link_preview/http.ex` ganhou API
  rica `fetch_title_result/1`, preservando `{:http_status, code}` para o worker
  sem quebrar `fetch_title/1` e `fetch_metadata/1`.
- Criado `apps/retro_hex_chat/lib/retro_hex_chat/jobs/link_preview_fetch_worker.ex`
  na fila `link_preview`, com `max_attempts: 3`, unique por `url_hash` e retry
  apenas para HTTP transitorio/infra.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/session.ex`
  deixou de usar `Task.Supervisor.async_nolink/2` e passou a enfileirar via
  `LinkPreview.enqueue_fetch/1`.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.ex` assina o
  topico global de previews.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers.ex`
  e `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/presence.ex`
  tratam resultado via PubSub e atualizam entradas por hash normalizado.
- `apps/retro_hex_chat/lib/retro_hex_chat/application.ex` removeu
  `RetroHexChat.LinkPreviewTasks`.
- `config/config.exs` e `config/runtime.exs` ganharam fila `link_preview` e
  `OBAN_LINK_PREVIEW_CONCURRENCY`.
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/oban_health.ex` e
  `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/system/oban_panel.ex`
  ganharam card/tabela de `Link preview cache`.

Contrato admin registrado:

- Fila: `link_preview`.
- Worker: `LinkPreviewFetchWorker`.
- Tela mostra: card de link previews e tabela por status (`pending`, `ready`,
  `failed`), `retrying`, `final_failures`, expirados, tentativa mais antiga e
  fetch mais recente.
- O painel generico de filas/jobs mostra backlog e jobs recentes da fila
  `link_preview`.
- Fechado em 2026-08-06: a janela separa retry transitorio de falha final sem
  expor URL completa ou dominio externo como label de alta cardinalidade.

Validacao:

- `mix compile --warnings-as-errors` passou.
- `mix test --warnings-as-errors apps/retro_hex_chat/test/retro_hex_chat/chat/link_preview/cache_test.exs apps/retro_hex_chat/test/retro_hex_chat/chat/link_preview/http_test.exs apps/retro_hex_chat/test/retro_hex_chat/jobs/link_preview_fetch_worker_test.exs apps/retro_hex_chat/test/retro_hex_chat/jobs/oban_health_test.exs`
  passou: 40 testes, 0 falhas.
- `mix test --warnings-as-errors apps/retro_hex_chat/test/retro_hex_chat/jobs/oban_health_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/system_windows_feature_test.exs --include liveview_feature`
  passou: 14 testes, 0 falhas.
- `mix test --warnings-as-errors apps/retro_hex_chat_web/test/retro_hex_chat_web/live/url_catcher_window_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/system_windows_feature_test.exs --include liveview_feature`
  passou: 15 testes, 0 falhas.

Aprendizados:

- A API antiga de `LinkPreview.HTTP` achatava todos os 4xx para `:not_found` e
  todos os 5xx para `:server_error`; o worker precisava de uma API rica para
  cumprir retry por status code sem quebrar RSS.
- Resultados de link preview precisam ser casados na LiveView por `url_hash`, nao
  por URL textual, porque a persistencia normaliza scheme/host e remove fragmento.
- Falha HTTP esperada nao deve virar job descartado no Oban quando chega na
  terceira tentativa; ela deve virar resultado duravel `failed` e o job concluir.
- As linhas agregadas do `Admin.Table` precisam sempre de `:id`; a primeira
  versao do snapshot quebrou o render LiveView por nao incluir esse campo.

### 2026-08-05 - Politica HTTP retry compartilhada

Status: CONCLUIDO

Objetivo:

- Garantir que erros HTTP em jobs Oban tenham retry apenas quando o status code
  for transitorio e nunca passem de 3 tentativas.
- Evitar divergencia entre link preview e RSS.

Feito:

- Criado `apps/retro_hex_chat/lib/retro_hex_chat/net/http_retry.ex`.
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/link_preview/results.ex` passou a
  delegar a decisao de retry para `RetroHexChat.Net.HTTPRetry`.
- `apps/retro_hex_chat/lib/retro_hex_chat/bots/capabilities/rss/fetcher.ex`
  preserva `{:http_status, status}` em vez de achatar para texto.
- `apps/retro_hex_chat/lib/retro_hex_chat/bots/capabilities/rss.ex` continua
  persistindo mensagem operacional legivel (`HTTP 503`, `HTTP 404`).
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/rss_poll_worker.ex` passou para
  `max_attempts: 3`.
- RSS faz retry Oban para `408`, `425`, `429`, `5xx` antes da terceira tentativa;
  na terceira tentativa registra a falha final do feed, agenda o proximo poll
  normal e conclui o job.
- Status deterministicos, como `404`, nao fazem retry e seguem direto para erro
  persistido + proximo poll normal.

Validacao:

- `mix compile --warnings-as-errors` passou.
- `mix test --warnings-as-errors apps/retro_hex_chat/test/retro_hex_chat/net/http_retry_test.exs apps/retro_hex_chat/test/retro_hex_chat/jobs/link_preview_fetch_worker_test.exs apps/retro_hex_chat/test/retro_hex_chat/jobs/rss_poll_worker_test.exs`
  passou: 13 testes, 0 falhas.

Aprendizados:

- RSS antes registrava erro HTTP como sucesso de job e aguardava o proximo ciclo
  normal. Para status transitorio, isso escondia uma falha retryable do Oban.
- Falha final esperada tambem nao deve virar job descartado: depois da terceira
  tentativa, o dominio registra `last_error`, agenda sucessor normal e encerra
  com sucesso operacional.

### 2026-08-05 - Preference/list persistence em Oban

Status: CONCLUIDO

Objetivo:

- Remover persistencia fire-and-forget por `Task.start/1` de preferencias/listas
  de usuario.
- Criar outbox coalescida para snapshots mutaveis e aplicar via Oban.
- Registrar backlog e falhas na janela admin de Oban.

Feito:

- Criada a migration
  `apps/retro_hex_chat/priv/repo/migrations/20260805123000_create_preference_save_requests.exs`.
- Criados `apps/retro_hex_chat/lib/retro_hex_chat/chat/preference_persistence.ex`
  e `apps/retro_hex_chat/lib/retro_hex_chat/chat/preference_persistence/request.ex`.
- Criado `apps/retro_hex_chat/lib/retro_hex_chat/jobs/preference_save_worker.ex`
  na fila `persistence`, com unique por `owner_nickname` + `preference_type`.
- A outbox salva payload, tamanho, status, `revision`, `applied_revision`,
  tentativas, ultimo erro e timestamps.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/persistence.ex`
  passou a enfileirar `notify_list`, `contacts`, `nick_colors`,
  `highlight_words`, `ignore_list`, `perform_list`, `autojoin_list`,
  `input_history`, `aliases`, `custom_menus` e `autorespond_rules`.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/settings_dialogs_events.ex`
  passou a enfileirar `flood_protection` e `sound_settings`.
- `config/config.exs` e `config/runtime.exs` ganharam fila `persistence` e
  `OBAN_PERSISTENCE_CONCURRENCY`.
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/oban_health.ex` ganhou agregados
  e tabela de persistencia.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/system/oban_panel.ex`
  ganhou card `Preference saves` e tabela `Preference persistence`.
- Testes LiveView que liam o banco imediatamente passaram a aplicar
  `PreferencePersistence.apply_pending/3`, refletindo que a escrita agora e
  assincrona e duravel.

Contrato admin registrado:

- Fila: `persistence`.
- Worker: `PreferenceSaveWorker`.
- Tela mostra: total de requests, pendentes/processando, falhas, bytes de payload
  e tabela por tipo/status com pendente mais antigo e ultima tentativa.
- O painel generico de filas/jobs mostra backlog e jobs recentes da fila
  `persistence`.
- Divida visual final: agrupar familias de preferencias se a lista ficar grande,
  sem perder os dados operacionais ja expostos.

Validacao:

- `mix compile --warnings-as-errors` passou.
- `mix test --warnings-as-errors apps/retro_hex_chat/test/retro_hex_chat/jobs/preference_save_worker_test.exs`
  passou: 3 testes, 0 falhas.
- `mix test --warnings-as-errors apps/retro_hex_chat/test/retro_hex_chat/jobs/preference_save_worker_test.exs apps/retro_hex_chat/test/retro_hex_chat/jobs/oban_health_test.exs`
  passou: 8 testes, 0 falhas.
- `mix test --warnings-as-errors apps/retro_hex_chat_web/test/retro_hex_chat_web/live/autocomplete_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/mute_toggle_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/autojoin_auto_add_test.exs`
  passou: 33 testes, 0 falhas.
- `mix test --warnings-as-errors apps/retro_hex_chat/test/retro_hex_chat/jobs/preference_save_worker_test.exs apps/retro_hex_chat/test/retro_hex_chat/jobs/oban_health_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/system_windows_feature_test.exs --include liveview_feature`
  passou: 18 testes, 0 falhas.

Aprendizados:

- `settings_dialogs_events.ex` tambem persiste `sound_settings`; ele pertence ao
  mesmo fluxo de preferencias de usuario mesmo nao estando explicito na primeira
  versao do plano.
- Payload de preferencias precisa de encode/hydrate recursivo para atravessar
  JSONB sem perder chaves atomicas e enums (`ignore_type`, `menu_type`,
  `trigger_event`).
- Unique do Oban precisa incluir estados incompletos; quando uma nova revision
  chega durante execucao, o worker deve detectar `pending` e retryar, nao marcar
  uma revision antiga como final.
- Testes de UI nao devem dormir esperando persistencia assincrona. O contrato
  correto e sincronizar a LiveView com `render/1` e aplicar explicitamente a
  pendencia quando o teste quer verificar o banco.

### 2026-08-05 - Attachment orphan cleanup em Oban

Status: CONCLUIDO

Objetivo:

- Limpar uploads `reserved`/`uploaded` antigos que nunca viraram
  `chat_attachments`.
- Adicionar delete ao boundary de storage e tornar o cleanup idempotente.
- Mostrar o sweep na janela admin de Oban.

Feito:

- `apps/retro_hex_chat/lib/retro_hex_chat/chat/attachments/storage.ex` ganhou
  callback `delete_file/3`.
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/attachments/s3_storage.ex`
  implementou delete S3 e trata `404` como sucesso idempotente.
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/queries.ex` ganhou queries para
  listar, contar, travar e marcar uploads orfaos como `deleted`.
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/attachments.ex` ganhou
  `cleanup_orphan_uploads/1` e `orphan_upload_count/1`.
- Criado
  `apps/retro_hex_chat/lib/retro_hex_chat/jobs/attachment_orphan_cleanup_worker.ex`
  na fila `maintenance`, com `max_attempts: 3`.
- `config/config.exs` agenda o worker em `@reboot` e `30 * * * *`.
- Criada a migration
  `apps/retro_hex_chat/priv/repo/migrations/20260805124000_add_chat_uploaded_files_orphan_cleanup_index.exs`.
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/oban_health.ex` passou a incluir
  `Attachment orphan cleanup` na tabela de maintenance.
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/system_windows_feature_test.exs`
  valida que a janela mostra o novo sweep.

Contrato admin registrado:

- Sweep: `attachment_orphan_cleanup`.
- Fila: `maintenance`.
- Worker: `AttachmentOrphanCleanupWorker`.
- Tela mostra: status, jobs ativos, falhas, pending work, ultimo sucesso e ultimo
  erro na tabela de maintenance.
- Divida visual final: um card especifico de storage pode mostrar bytes liberados
  do ultimo run se houver historico duravel de execucoes; hoje o worker emite
  telemetry e a tabela mostra pendencias.

Validacao:

- `mix compile --warnings-as-errors` passou.
- `mix test --warnings-as-errors apps/retro_hex_chat/test/retro_hex_chat/chat/attachments_test.exs apps/retro_hex_chat/test/retro_hex_chat/jobs/attachment_orphan_cleanup_worker_test.exs apps/retro_hex_chat/test/retro_hex_chat/jobs/oban_health_test.exs`
  passou: 13 testes, 0 falhas.
- `mix test --warnings-as-errors apps/retro_hex_chat_web/test/retro_hex_chat_web/live/system_windows_feature_test.exs --include liveview_feature`
  passou: 10 testes, 0 falhas.

Aprendizados:

- `chat_uploaded_files` ja tinha status `deleted`; a migracao correta era usar
  esse estado, nao apagar fisicamente o registro nem criar coluna paralela.
- `FOR UPDATE` nao pode ser aplicado ao lado nullable de `LEFT JOIN` no Postgres.
  Para cleanup concorrente, travamos `chat_uploaded_files` primeiro e verificamos
  a ausencia de attachment em segunda query dentro da mesma transacao.
- Direct upload S3 pode nao ter checksum local; a identidade de cleanup deve ser
  bucket/key/status/idade, como previsto no plano.

### 2026-08-05 - Trusted devices/session cleanup em Oban

Status: CONCLUIDO

Objetivo:

- Materializar expiracao de trusted devices vencidos sem hard delete.
- Fechar linhas de `chat_device_sessions` sem heartbeat recente.
- Expor os dois contratos na janela admin de Oban.

Feito:

- `apps/retro_hex_chat/lib/retro_hex_chat/accounts/trusted_devices.ex` ganhou
  `expire_devices/1`, `expired_device_count/1`, `close_stale_sessions/1` e
  `stale_session_count/1`.
- Criado
  `apps/retro_hex_chat/lib/retro_hex_chat/jobs/trusted_device_expiry_worker.ex`.
- Criado
  `apps/retro_hex_chat/lib/retro_hex_chat/jobs/chat_device_session_cleanup_worker.ex`.
- Criada a migration
  `apps/retro_hex_chat/priv/repo/migrations/20260805125000_add_trusted_device_cleanup_indexes.exs`.
- `config/config.exs` agenda os workers em `@reboot`; device expiry roda em
  `35 * * * *` e session cleanup em `*/15 * * * *`.
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/oban_health.ex` inclui `Trusted
  device expiry` e `Chat device session cleanup` na tabela de maintenance.
- `apps/retro_hex_chat/test/retro_hex_chat/accounts/trusted_devices_test.exs`
  cobre expiracao materializada e fechamento de sessao stale.
- `apps/retro_hex_chat/test/retro_hex_chat/jobs/trusted_device_cleanup_worker_test.exs`
  cobre workers e telemetry.

Contrato admin registrado:

- Sweeps: `trusted_device_expiry` e `chat_device_session_cleanup`.
- Fila: `maintenance`.
- Workers: `TrustedDeviceExpiryWorker` e `ChatDeviceSessionCleanupWorker`.
- Tela mostra: status, jobs ativos, falhas, pending work, ultimo sucesso e ultimo
  erro na tabela de maintenance.
- O pending work usa devices vencidos nao revogados e sessoes ativas com
  `last_seen_at` acima do cutoff.

Validacao:

- `mix compile --warnings-as-errors` passou.
- `mix test --warnings-as-errors apps/retro_hex_chat/test/retro_hex_chat/accounts/trusted_devices_test.exs apps/retro_hex_chat/test/retro_hex_chat/jobs/trusted_device_cleanup_worker_test.exs apps/retro_hex_chat/test/retro_hex_chat/jobs/oban_health_test.exs`
  passou: 20 testes, 0 falhas.
- `mix test --warnings-as-errors apps/retro_hex_chat_web/test/retro_hex_chat_web/live/system_windows_feature_test.exs --include liveview_feature`
  passou: 10 testes, 0 falhas.

Aprendizados:

- Expirar trusted device nao deve apagar registro nem grants; o estado auditavel e
  `revoked_at/revoked_by_nickname` com evento `device.expired`.
- Fechar sessao stale e diferente de matar LiveView viva. O worker so materializa
  `disconnected_at` para linhas sem heartbeat, sem `force_disconnect`.
- O cutoff de sessoes precisa ficar acima do throttle real de heartbeat
  (`Connection.handle_ping/2` usa 60s); o default implementado e 300s.

### 2026-08-05 - Lobby/arcade/group_call stale cleanup em Oban

Status: CONCLUIDO

Objetivo:

- Criar uma rede de seguranca duravel para registros runtime que ficaram
  nao-terminais apos crash, deploy ou perda do processo dono.
- Reaproveitar as queries stale existentes de lobby, arcade e group call.
- Expor o sweep na janela admin de Oban.

Feito:

- `apps/retro_hex_chat/lib/retro_hex_chat/lobby/queries.ex` ganhou
  `stale_session_count/1`, limit opcional em `list_stale_sessions/2` e
  `expire_stale_session/2` condicional.
- `apps/retro_hex_chat/lib/retro_hex_chat/arcade/queries.ex` ganhou o mesmo
  contrato para `solo_sessions`.
- `apps/retro_hex_chat/lib/retro_hex_chat/group_call/queries.ex` ganhou
  `stale_room_count/1`, limit opcional em `list_stale_rooms/2` e
  `expire_stale_room/2` condicional.
- Criado `apps/retro_hex_chat/lib/retro_hex_chat/runtime_stale_cleanup.ex`.
- Criado
  `apps/retro_hex_chat/lib/retro_hex_chat/jobs/runtime_stale_cleanup_worker.ex`
  na fila `maintenance`, com `max_attempts: 3`.
- Criada a migration
  `apps/retro_hex_chat/priv/repo/migrations/20260805130000_add_runtime_stale_cleanup_indexes.exs`.
- `config/config.exs` agenda o worker em `@reboot` e `45 * * * *`.
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/oban_health.ex` inclui `Runtime
  stale cleanup` na tabela de maintenance.
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/system_windows_feature_test.exs`
  valida que a janela mostra o novo sweep.

Contrato admin registrado:

- Sweep: `runtime_stale_cleanup`.
- Fila: `maintenance`.
- Worker: `RuntimeStaleCleanupWorker`.
- Tela mostra: status, jobs ativos, falhas, pending work, ultimo sucesso e ultimo
  erro na tabela de maintenance.
- O pending work soma registros stale de `lobby_sessions`, `solo_sessions` e
  `group_call_rooms` com o mesmo cutoff default do worker.
- Divida visual final: adicionar detalhamento por dominio se a tabela de
  maintenance ficar insuficiente para diagnosticar onde estao os stale records.

Validacao:

- `mix compile --warnings-as-errors` passou.
- `mix test --warnings-as-errors apps/retro_hex_chat/test/retro_hex_chat/jobs/runtime_stale_cleanup_worker_test.exs apps/retro_hex_chat/test/retro_hex_chat/jobs/oban_health_test.exs`
  passou: 8 testes, 0 falhas.
- `mix test --warnings-as-errors apps/retro_hex_chat_web/test/retro_hex_chat_web/live/system_windows_feature_test.exs --include liveview_feature`
  passou: 10 testes, 0 falhas.

Aprendizados:

- Lobby conectado pode ser legitimo por bastante tempo; `session_server.ex`
  deixa claro que alguns timeouts sao UX/runtime, nao regra duravel de
  encerramento. Por isso o cutoff default do cleanup stale e 24h.
- A expiracao precisa ser condicional no update, nao apenas na selecao inicial.
  Se o processo vivo atualizar o registro entre listagem e update, o worker deve
  pular o candidato.
- `updated_at` e a coluna comum entre os tres dominios. `group_call_rooms`
  tambem possui `last_activity_at`, mas o plano auditado definiu o contrato stale
  por `updated_at`; trocar isso exigiria novo mapeamento especifico de calls.

### 2026-08-05 - Channel mute duravel em Oban

Status: CONCLUIDO

Objetivo:

- Persistir mutes de canal para sobreviver a restart/deploy.
- Substituir o timer local de unmute temporario por Oban.
- Expor expiracao de mutes temporarios na janela admin de Oban.

Feito:

- Criado `apps/retro_hex_chat/lib/retro_hex_chat/channels/channel_mute.ex`.
- Criado `apps/retro_hex_chat/lib/retro_hex_chat/channels/mutes.ex`.
- Criado
  `apps/retro_hex_chat/lib/retro_hex_chat/jobs/channel_mute_expiry_worker.ex`
  na fila `maintenance`, com `max_attempts: 3`.
- Criada a migration
  `apps/retro_hex_chat/priv/repo/migrations/20260805131000_create_channel_mutes.exs`.
- `apps/retro_hex_chat/lib/retro_hex_chat/channels/server.ex` passou a carregar
  mutes ativos no start do canal.
- `Channels.Server.channel_mute/4` persiste `channel_mutes` e enfileira expiry
  quando a duracao e temporaria.
- `Channels.Server.channel_unmute/3` revoga no banco, cancela jobs incompletos e
  atualiza o runtime.
- O antigo `Process.send_after/3` e `handle_info({:unmute_timer, ...})` foram
  removidos desse fluxo.
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/oban_health.ex` inclui `Channel
  mute expiry` na tabela de maintenance.
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/system_windows_feature_test.exs`
  valida que a janela mostra o novo contrato.

Contrato admin registrado:

- Worker: `ChannelMuteExpiryWorker`.
- Fila: `maintenance`.
- Tela mostra: jobs ativos/futuros, falhas, expirados vencidos pendentes, ultimo
  sucesso e ultimo erro na tabela de maintenance.
- Divida visual final: quando global mute entrar, consolidar um bloco de
  `Durable mute expirations` com contadores separados para channel/global.

Validacao:

- `mix compile --warnings-as-errors` passou.
- `mix test --warnings-as-errors apps/retro_hex_chat/test/retro_hex_chat/channels/mutes_test.exs apps/retro_hex_chat/test/retro_hex_chat/jobs/channel_mute_expiry_worker_test.exs apps/retro_hex_chat/test/retro_hex_chat/channels/server_test.exs apps/retro_hex_chat/test/retro_hex_chat/jobs/oban_health_test.exs`
  passou: 120 testes, 0 falhas.
- `mix test --warnings-as-errors apps/retro_hex_chat_web/test/retro_hex_chat_web/live/channel_moderation_context_menu_feature_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/system_windows_feature_test.exs --include liveview_feature`
  passou: 14 testes, 0 falhas.

Aprendizados:

- O comando `/mute` nao carrega motivo no fluxo atual; a tabela ja permite
  `reason`, mas a migracao nao inventou UI/campo novo.
- Mutes expirados mas ainda nao materializados nao sao reidratados no start do
  canal, porque `Mutes.active_nicknames/2` filtra `expires_at`.
- Re-mutar o mesmo alvo reutiliza a linha nao revogada e substitui o job de
  expiracao, evitando duplicidade de estado ativo por canal/alvo.
- O worker precisa atualizar o banco antes de tocar o processo vivo. Se o canal
  nao estiver rodando, a expiracao continua materializada e sera refletida no
  proximo start.

### 2026-08-05 - Global mute duravel em Oban

Status: CONCLUIDO

Objetivo:

- Trocar o estado global mute de ETS efemero para tabela duravel.
- Manter leitura rapida via cache derivado, sem tratar ETS como fonte de verdade.
- Substituir expiracao implicita por worker Oban observavel.

Feito:

- Criado `apps/retro_hex_chat/lib/retro_hex_chat/admin/global_mute.ex`.
- `apps/retro_hex_chat/lib/retro_hex_chat/admin/global_mutes.ex` passou a
  persistir, revogar, contar e expirar mutes globais duraveis.
- `apps/retro_hex_chat/lib/retro_hex_chat/admin/global_mute_table.ex` virou cache
  ETS derivado do banco e removeu a semantica antiga de estado efemero.
- Criado
  `apps/retro_hex_chat/lib/retro_hex_chat/jobs/global_mute_expiry_worker.ex` na
  fila `maintenance`, com `max_attempts: 3`.
- Criada a migration
  `apps/retro_hex_chat/priv/repo/migrations/20260805132000_create_global_mutes.exs`.
- `apps/retro_hex_chat/lib/retro_hex_chat/admin.ex` passou a tratar falha de
  persistencia em `mute_user/4` e `unmute_user/2`.
- `Admin.nuke` passou a incluir `global_mutes` nos alvos duraveis deletados; a
  limpeza ETS permanece apenas para cache.
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/oban_health.ex` inclui `Global
  mute expiry` na tabela de maintenance.

Contrato admin registrado:

- Worker: `GlobalMuteExpiryWorker`.
- Fila: `maintenance`.
- Tela mostra: jobs ativos/futuros, falhas, expirados vencidos pendentes, ultimo
  sucesso e ultimo erro na tabela de maintenance.
- Divida visual final: consolidar `Channel mute expiry` e `Global mute expiry`
  em um bloco de mutes duraveis com contadores por tipo.

Validacao:

- `mix compile --warnings-as-errors` passou.
- `mix test --warnings-as-errors apps/retro_hex_chat/test/retro_hex_chat/admin/global_mutes_test.exs apps/retro_hex_chat/test/retro_hex_chat/jobs/global_mute_expiry_worker_test.exs apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/admin/nuke_test.exs apps/retro_hex_chat/test/retro_hex_chat/jobs/oban_health_test.exs`
  passou: 25 testes, 0 falhas.
- `mix test --warnings-as-errors apps/retro_hex_chat_web/test/retro_hex_chat_web/live/admin_users_feature_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/system_windows_feature_test.exs --include liveview_feature`
  passou: 18 testes, 0 falhas.

Aprendizados:

- O comportamento antigo de `muted?/1` removia o efeito de mute quando a duracao
  passava, mesmo sem materializar auditoria. O cache novo preserva essa leitura:
  mutes vencidos deixam de bloquear, e o worker materializa `revoked_at`.
- A API de admin antes assumia que mute/unmute nunca falhava. Com banco como
  fonte de verdade, `Admin.mute_user/4` e `Admin.unmute_user/2` precisam retornar
  erro operacional se a persistencia falhar.
- `GlobalMuteTable` ainda e util como cache porque `CommandDispatch` consulta
  global mute no caminho quente de envio de mensagem.

### 2026-08-05 - Ignore entries expiration em Oban

Status: CONCLUIDO

Objetivo:

- Materializar a limpeza de ignores temporarios vencidos em Oban.
- Evitar que snapshots antigos de preferencias/listas regravem entradas ja
  expiradas.
- Manter timers locais da LiveView apenas como feedback imediato de sessao viva.

Feito:

- `apps/retro_hex_chat/lib/retro_hex_chat/chat/ignore_entry.ex` ganhou
  `expired?/2` deterministico e passou a tratar `expires_at <= now` como
  expirado.
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/ignore_list.ex` passou a filtrar
  entradas expiradas em `save/2`, mantendo permanentes e futuras.
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/ignore_list.ex` ganhou
  `cleanup_expired_entries/1` e `expired_entry_count/1`.
- Criado
  `apps/retro_hex_chat/lib/retro_hex_chat/jobs/ignore_expired_cleanup_worker.ex`
  na fila `maintenance`, com `max_attempts: 3`, unique por worker/fila e
  telemetry em `[:retro_hex_chat, :chat, :ignore_list, :cleanup]`.
- Criada a migration
  `apps/retro_hex_chat/priv/repo/migrations/20260805133000_add_ignore_list_entries_expiry_index.exs`
  com indice parcial para `expires_at IS NOT NULL`.
- `config/config.exs` ganhou cron `@reboot` e `55 * * * *` para
  `IgnoreExpiredCleanupWorker`.
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/oban_health.ex` inclui `Ignore
  expired cleanup` na tabela de maintenance.
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/system_windows_feature_test.exs`
  cobre a renderizacao da nova linha na janela Oban.

Contrato admin registrado:

- Worker: `IgnoreExpiredCleanupWorker`.
- Fila: `maintenance`.
- Tela mostra: jobs ativos/futuros, falhas, ignores expirados pendentes, ultimo
  sucesso e ultimo erro na tabela de maintenance.
- Telemetry do worker inclui candidatos, removidos e idade em ms do ignore
  expirado mais antigo processado.
- Divida visual final: agrupar cleanup de ignore com persistence/list health
  para explicar se backlog vem de snapshot antigo ou atraso de maintenance.

Validacao:

- `mix compile --warnings-as-errors` passou.
- `mix test --warnings-as-errors apps/retro_hex_chat/test/retro_hex_chat/chat/ignore_list_persistence_test.exs apps/retro_hex_chat/test/retro_hex_chat/jobs/ignore_expired_cleanup_worker_test.exs apps/retro_hex_chat/test/retro_hex_chat/jobs/oban_health_test.exs`
  passou: 17 testes, 0 falhas.
- `mix test --warnings-as-errors apps/retro_hex_chat_web/test/retro_hex_chat_web/live/ignore_list_feature_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/system_windows_feature_test.exs --include liveview_feature`
  passou: 13 testes, 0 falhas.

Aprendizados:

- `IgnoreList.save/2` era parte do risco porque a persistence queue recebe
  snapshots de sessao. Filtrar no worker de limpeza nao basta se um snapshot
  antigo puder regravar a entrada vencida depois.
- Os timers `:ignore_expired` e `:auto_ignore_expired` continuam corretos como
  mecanismo de UX local; a fonte duravel e saneada pelo banco/Oban.
- Entries permanentes (`expires_at IS NULL`) precisam ficar fora do indice e da
  query de cleanup para nao misturar manutencao com configuracao persistente.

### 2026-08-05 - PromEx/telemetry multi-dominio

Status: CONCLUIDO

Objetivo:

- Exportar numeros de negocio dos workers migrados sem depender apenas das
  metricas genericas de job/fila do Oban.
- Manter tags de baixa cardinalidade.
- Reaproveitar `RetroHexChat.Observability` como ponto unico para spans e eventos
  PromEx.

Feito:

- `apps/retro_hex_chat/lib/retro_hex_chat/observability.ex` passou a manter, por
  span, atributos numericos adicionados via `set_current_span_attributes/1`.
- `Observability` emite
  `[:retro_hex_chat, :observability, :operation, :counter]` para contadores
  whitelisted como candidatos, removidos, expirados, publicados e bytes
  deletados.
- `Observability` emite
  `[:retro_hex_chat, :observability, :operation, :value]` para valores
  whitelisted como `next_poll_ms`, `next_delay_ms`, `seen_count` e
  `oldest_expired_age_ms`.
- `apps/retro_hex_chat/lib/retro_hex_chat/prom_ex/plugins/domain.ex` exporta as
  metricas PromEx `operation.counter.total` e `operation.value`.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/telemetry.ex` declara as mesmas
  metricas para o painel de metricas runtime.
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/bot_scheduled_message_worker.ex`
  passou a emitir `messages_sent`.
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/bot_event_log_worker.ex` passou a
  emitir `events_written`.
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/channel_mute_expiry_worker.ex` e
  `apps/retro_hex_chat/lib/retro_hex_chat/jobs/global_mute_expiry_worker.ex`
  passaram a emitir `expired_count` quando materializam expiracao.
- `apps/retro_hex_chat/test/retro_hex_chat/jobs/rss_poll_worker_test.exs` cobre
  que `published_count` e `source_item_count` chegam como metricas genericas.

Contrato de metricas registrado:

- Tags: `context`, `operation`, `result`, `measurement`.
- Nao entram como tags: nick, canal, URL, schedule id, feed id, bot id ou args de
  job.
- Counters cobrem trabalho processado por execucao; values cobrem ultimo valor
  observado de medidas operacionais.

Validacao:

- `mix compile --warnings-as-errors` passou.
- `mix test --warnings-as-errors apps/retro_hex_chat/test/retro_hex_chat/observability_test.exs apps/retro_hex_chat/test/retro_hex_chat/jobs/rss_poll_worker_test.exs apps/retro_hex_chat/test/retro_hex_chat/jobs/bot_scheduled_message_worker_test.exs apps/retro_hex_chat/test/retro_hex_chat/jobs/bot_event_log_worker_test.exs apps/retro_hex_chat/test/retro_hex_chat/jobs/channel_mute_expiry_worker_test.exs apps/retro_hex_chat/test/retro_hex_chat/jobs/global_mute_expiry_worker_test.exs apps/retro_hex_chat/test/retro_hex_chat/jobs/server_ban_expiry_worker_test.exs apps/retro_hex_chat/test/retro_hex_chat/jobs/attachment_orphan_cleanup_worker_test.exs apps/retro_hex_chat/test/retro_hex_chat/jobs/ignore_expired_cleanup_worker_test.exs`
  passou: 25 testes, 0 falhas.
- `mix test --warnings-as-errors apps/retro_hex_chat_web/test/retro_hex_chat_web/prom_ex_test.exs`
  passou: 7 testes, 0 falhas.

Aprendizados:

- `set_current_span_attributes/1` sozinho nao alimentava PromEx. O wrapper de
  span precisava transformar campos numericos whitelisted em eventos
  `:telemetry` separados.
- Uma metrica generica com tag `measurement` evita criar uma metrica nova por
  worker e preserva baixa cardinalidade porque o conjunto vem de whitelist no
  codigo.

### 2026-08-05 - Janela admin Oban completa

Status: CONCLUIDO

Objetivo:

- Fechar a janela administrativa de Oban com todos os contratos migrados no
  plano.
- Tirar a janela do foco exclusivo em RSS.
- Adicionar filtros de jobs recentes por estado, fila e worker.

Feito:

- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/oban_health.ex` ganhou snapshot de
  `bot_schedule_table` e `bot_event_log_table`.
- `ObanHealth` passou a sumarizar `bot_schedules`,
  `bot_schedule_missing_jobs`, `bot_schedule_failures`,
  `bot_event_log_active` e `bot_event_log_failures`.
- `ObanHealth.snapshot/1` aceita filtros `:queue` e `:worker` alem do filtro de
  estado ja existente.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/system_oban_dialog.ex`
  preserva filtros de estado, fila e worker entre refreshes.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/system/oban_panel.ex`
  ganhou cards `Bot schedules` e `Bot event logs`.
- A janela ganhou as secoes `Bot schedule coverage` e `Bot event log jobs`.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/controllers/help_content/ui_system_windows.html.heex`
  foi atualizado para explicar os contratos observaveis atuais.

Contrato admin final:

- Headline: status, active jobs, failures, RSS, bot schedules, bot event logs,
  maintenance, link previews e preference saves.
- Tabelas: filas por estado, jobs recentes filtraveis, RSS feed coverage, bot
  schedule coverage, bot event log jobs, maintenance sweeps, link preview cache e
  preference persistence.
- Motivos de warning/critical incluem lag de fila, jobs retryable/discarded,
  missing successor de RSS/schedules, falhas de event log, falhas de maintenance
  e falhas de persistence.

Validacao:

- `mix compile --warnings-as-errors` passou.
- `mix test --warnings-as-errors apps/retro_hex_chat/test/retro_hex_chat/jobs/oban_health_test.exs`
  passou: 6 testes, 0 falhas.
- `mix test --warnings-as-errors apps/retro_hex_chat_web/test/retro_hex_chat_web/live/system_windows_feature_test.exs --include liveview_feature`
  passou: 11 testes, 0 falhas.

Aprendizados:

- Successor coverage para bot schedules pode seguir o mesmo modelo de RSS:
  enumerar schedules configurados e procurar jobs incompletos por `bot_id` e
  `schedule_id`.
- O backlog de bot event log nao precisa expor canal/evento como tag visual para
  ser operacional; agrupar jobs por estado mostra fila e falha sem cardinalidade
  desnecessaria.

### 2026-08-05 - Registered nick expiry em Oban

Status: CONCLUIDO

Objetivo:

- Migrar a expiracao de nicks registrados inativos e a sucessao de founder para
  Oban sem manter o timer antigo.
- Transformar `Services.NickExpiry` em dominio puro.
- Expandir a tabela de maintenance sweeps da janela admin.

Feito:

- `apps/retro_hex_chat/lib/retro_hex_chat/services/nick_expiry.ex` deixou de ser
  GenServer e passou a expor `purge/1`, `expired_count/1` e
  `default_expiration_days/0`.
- Criado `apps/retro_hex_chat/lib/retro_hex_chat/jobs/registered_nick_expiry_worker.ex`.
- `config/config.exs` ganhou cron `@reboot` e `15 */6 * * *` para
  `RegisteredNickExpiryWorker`.
- `apps/retro_hex_chat/lib/retro_hex_chat/application.ex` deixou de supervisionar
  `RetroHexChat.Services.NickExpiry`.
- `apps/retro_hex_chat/lib/retro_hex_chat/services/queries.ex` ganhou
  `expired_nick_count/3`, `list_expired_nicknames/3` e purge com `now`
  deterministico.
- Criada a migration
  `apps/retro_hex_chat/priv/repo/migrations/20260805121000_add_registered_nicks_last_seen_index.exs`.
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/oban_health.ex` passou a mostrar o
  sweep `Registered nick expiry`.
- `apps/retro_hex_chat/test/retro_hex_chat/services/nick_expiry_test.exs` passou
  a cobrir o dominio puro e adicionou protecao de root admin.
- `apps/retro_hex_chat/test/retro_hex_chat/services/chan_expiry_test.exs` passou
  a chamar o dominio puro para manter cobertura de sucessao de founder.

Contrato admin registrado:

- Sweep: `registered_nick_expiry`.
- Fila: `maintenance`.
- Tela mostra: status, jobs ativos, falhas, pending work, ultimo sucesso e ultimo
  erro.
- O worker emite telemetry com nicks expirados, candidatos, removidos, protegidos
  por identificacao/admin, sucessoes de founder, canais orfaos e limpezas de
  access/bans/exceptions/welcome.

Validacao:

- `mix compile --warnings-as-errors` passou.
- `mix test --warnings-as-errors apps/retro_hex_chat/test/retro_hex_chat/services/nick_expiry_test.exs apps/retro_hex_chat/test/retro_hex_chat/services/chan_expiry_test.exs apps/retro_hex_chat/test/retro_hex_chat/jobs/registered_nick_expiry_worker_test.exs apps/retro_hex_chat/test/retro_hex_chat/jobs/oban_health_test.exs`
  passou: 20 testes, 0 falhas.
- `mix test --warnings-as-errors apps/retro_hex_chat_web/test/retro_hex_chat_web/live/system_windows_feature_test.exs --include liveview_feature`
  passou: 10 testes, 0 falhas.

Aprendizados:

- `NickServ.remove_identified/2` e cast e nao retorna remocao efetiva; por isso
  o resultado nao inventa contador de runtime cleanup.
- A protecao de root admins vem de `:root_admins`, enquanto a protecao de admins
  de banco vem de `RoleCache.list_admin_nicks/0`.
- A sucessao de cada canal precisa ser transacional, porque remove access,
  promove sucessor ou remove o canal orfao em multiplas tabelas.
- Durante este refactor amplo, o loop usa testes focados por fluxo; `make ci`
  fica reservado para o fechamento consolidado ou producao/commit/push/deploy.

### 2026-08-05 - Bot scheduled messages em Oban

Status: CONCLUIDO

Objetivo:

- Migrar mensagens agendadas de bots para Oban sem perder o estado duravel em
  `bots.capabilities`.
- Remover o disparo por timer local da capability `Scheduler`.
- Criar a fila operacional `bots`.

Feito:

- Criado `apps/retro_hex_chat/lib/retro_hex_chat/bots/capabilities/scheduler/durable.ex`
  como boundary de agendamento duravel.
- Criado `apps/retro_hex_chat/lib/retro_hex_chat/jobs/bot_scheduled_message_worker.ex`.
- `apps/retro_hex_chat/lib/retro_hex_chat/bots/capabilities/scheduler.ex` deixou
  de expor `handle_timer/3` e `reschedule_delay/2`.
- `Scheduler.init_timers/4` passou a reconciliar jobs Oban via
  `Scheduler.Durable`, sem criar `Process.send_after/3`.
- `config/config.exs` e `config/runtime.exs` ganharam a fila `bots` e
  `OBAN_BOTS_CONCURRENCY`.
- `apps/retro_hex_chat/lib/retro_hex_chat/bots/lifecycle.ex` cancela jobs de
  schedule ao destruir bot.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/bot_events.ex`
  cancela jobs ao desabilitar bot ou desabilitar a capability `scheduler`, e
  reconcilia jobs ao reabilitar bot.
- `apps/retro_hex_chat/test/retro_hex_chat/bots/server_test.exs` e
  `apps/retro_hex_chat/test/retro_hex_chat/bots/bot_lifecycle_test.exs` passaram
  a validar jobs Oban e `capability_timers == %{}` para scheduler.
- Criado `apps/retro_hex_chat/test/retro_hex_chat/jobs/bot_scheduled_message_worker_test.exs`.

Contrato admin registrado:

- Fila: `bots`.
- Worker: `BotScheduledMessageWorker`.
- A tela admin mostra a fila `bots`, jobs recentes pelo painel generico de Oban
  e a secao especifica `Bot schedule coverage`.
- Fechado na consolidacao final da janela admin: schedules ativos, schedules sem
  job, proxima execucao, ultimo disparo e ultimo erro por schedule.

Validacao:

- `mix compile --warnings-as-errors` passou.
- `mix test --warnings-as-errors apps/retro_hex_chat/test/retro_hex_chat/bots/capabilities/scheduler_test.exs apps/retro_hex_chat/test/retro_hex_chat/jobs/bot_scheduled_message_worker_test.exs apps/retro_hex_chat/test/retro_hex_chat/bots/server_test.exs apps/retro_hex_chat/test/retro_hex_chat/bots/bot_lifecycle_test.exs`
  passou: 59 testes, 0 falhas.
- `mix test --warnings-as-errors apps/retro_hex_chat_web/test/retro_hex_chat_web/live/bot_management_entry_points_feature_test.exs --include liveview_feature`
  passou: 8 testes, 0 falhas.

Aprendizados:

- `put_in(bot.capabilities["scheduler"]["schedules"], ...)` atualiza o struct
  inteiro quando o caminho comeca no struct; nos testes o correto e atualizar o
  mapa de capabilities com `put_in(bot.capabilities, ["scheduler", "schedules"], ...)`.
- `Scheduler.init_timers/4` ainda e chamado pelo servidor por contrato legado,
  mas para scheduler ele virou reconciliador de jobs duraveis e nao agenda timer
  local.
- `Server.sync_capabilities/2`, usado pelo worker apos persistir `last_fired`,
  nao reconcilia jobs; isso evita que o job em execucao seja cancelado pelo
  proprio refresh de estado.

### 2026-08-05 - Bot event log em Oban

Status: CONCLUIDO

Objetivo:

- Substituir a escrita fire-and-forget de logs de evento de bot por worker Oban.
- Remover `Task.start/1` do fluxo sem deduplicar eventos distintos.

Feito:

- Criado `apps/retro_hex_chat/lib/retro_hex_chat/jobs/bot_event_log_worker.ex`.
- `apps/retro_hex_chat/lib/retro_hex_chat/bots/server.ex` passou a enfileirar
  logs via `RetroHexChat.Jobs` e `BotEventLogWorker`.
- Metadata de evento e normalizada para payload JSON seguro antes do enqueue.
- O worker cancela quando o bot nao existe mais e retorna erro para retry em
  falha de changeset/DB.
- Criado `apps/retro_hex_chat/test/retro_hex_chat/jobs/bot_event_log_worker_test.exs`.
- `apps/retro_hex_chat/test/retro_hex_chat/bots/server_test.exs` passou a validar
  que respostas do bot enfileiram o job de log.

Contrato admin registrado:

- Fila: `bots`.
- Worker: `BotEventLogWorker`.
- A tela admin atual ja mostra backlog/falhas pelo painel generico de filas e
  jobs recentes.
- A secao especifica de bot event log ainda deve expor backlog/falhas por worker
  quando a consolidacao visual da janela admin for feita.

Validacao:

- `mix compile --warnings-as-errors` passou.
- `mix test --warnings-as-errors apps/retro_hex_chat/test/retro_hex_chat/jobs/bot_event_log_worker_test.exs apps/retro_hex_chat/test/retro_hex_chat/bots/server_test.exs`
  passou: 30 testes, 0 falhas.

Aprendizados:

- `bot_event_log` nao tem identidade natural por evento; o worker nao deve usar
  `unique`, ou eventos distintos podem ser perdidos.
- O `Task.start_link/1` em `apps/retro_hex_chat/lib/retro_hex_chat/bots/loader.ex`
  e parte do loader supervisionado e nao pertence a este fluxo.

### 2026-08-05 - Server ban expiry em Oban

Status: CONCLUIDO

Objetivo:

- Migrar a expiracao periodica de server bans para Oban sem manter o GenServer
  antigo.
- Criar a primeira base da fila `maintenance`.
- Evoluir a janela admin do Oban com contrato minimo de maintenance sweeps.

Feito:

- Criado `apps/retro_hex_chat/lib/retro_hex_chat/jobs/server_ban_expiry_worker.ex`.
- `config/config.exs` ganhou `Oban.Plugins.Cron` com entradas `@reboot` e
  `@hourly` para o worker.
- `config/config.exs` e `config/runtime.exs` ganharam fila `maintenance` e
  `OBAN_MAINTENANCE_CONCURRENCY`.
- `apps/retro_hex_chat/lib/retro_hex_chat/admin/server_bans.ex` ganhou
  `expired_count/0` e `expired_count/1` para snapshot admin e teste
  deterministico.
- `RetroHexChat.Admin.BanExpiry` saiu da supervision tree e o modulo antigo foi
  deletado.
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/oban_health.ex` ganhou tabela de
  maintenance sweeps.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/system/oban_panel.ex`
  ganhou card e tabela de maintenance.

Contrato admin registrado:

- Sweep: `server_ban_expiry`.
- Fila: `maintenance`.
- Tela mostra: status, jobs ativos, falhas, pending work, ultimo sucesso e ultimo
  erro.
- O numero de bans expirados no ultimo run fica em telemetry/log; a tela mostra o
  backlog atual (`pending_work`) ate existir uma tabela generica de historico de
  maintenance runs.

Validacao:

- `mix test apps/retro_hex_chat/test/retro_hex_chat/jobs/server_ban_expiry_worker_test.exs`
  passou: 2 testes, 0 falhas.
- `mix test apps/retro_hex_chat/test/retro_hex_chat/jobs/oban_health_test.exs`
  passou: 3 testes, 0 falhas.
- `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/system_windows_feature_test.exs --include liveview_feature`
  passou: 10 testes, 0 falhas.
- `make ci` passou no rerun final: 13/13 checks, incluindo dialyzer.

Nota de validacao:

- A primeira execucao de `make ci` falhou em um teste de P2P/lobby
  (`apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs`,
  linha 622). O teste passou isolado em seguida, e o rerun completo de `make ci`
  passou. Nao houve falha em Oban, bans ou janela admin.

Aprendizados:

- `BanCache` e ETS global; testes que chamam `ServerBans.ban/4` precisam limpar
  nicks explicitamente em `on_exit`.
- `Oban.Plugins.Cron` suporta `@reboot`, o que cobre o sweep de boot sem criar
  outro processo agendador.
- Oban nao persiste o retorno do worker de forma adequada para dashboard de
  dominio. Para exibir "quantos itens o ultimo run processou" de modo generico,
  a padronizacao completa pode precisar de uma tabela de historico de
  maintenance runs ou outro snapshot duravel de resultado.

### 2026-08-05 - Registered channel expiry em Oban

Status: CONCLUIDO

Objetivo:

- Migrar a purga de canais registrados inativos para Oban sem manter o timer
  antigo.
- Transformar `Services.ChanExpiry` em dominio puro.
- Expandir a tabela de maintenance sweeps da janela admin.

Feito:

- `apps/retro_hex_chat/lib/retro_hex_chat/services/chan_expiry.ex` deixou de ser
  GenServer e passou a expor `purge/1`, `expired_count/1` e
  `default_expiration_days/0`.
- Criado `apps/retro_hex_chat/lib/retro_hex_chat/jobs/registered_channel_expiry_worker.ex`.
- `config/config.exs` ganhou cron `@reboot` e `0 */6 * * *` para
  `RegisteredChannelExpiryWorker`.
- `apps/retro_hex_chat/lib/retro_hex_chat/application.ex` deixou de supervisionar
  `RetroHexChat.Services.ChanExpiry`.
- `apps/retro_hex_chat/lib/retro_hex_chat/services/queries.ex` ganhou
  `expired_channel_count/2` e suporte a `now` deterministico para listagem/purge.
- Criada a migration
  `apps/retro_hex_chat/priv/repo/migrations/20260805120000_add_registered_channels_last_activity_index.exs`.
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/oban_health.ex` passou a mostrar o
  sweep `Registered channel expiry`.

Contrato admin registrado:

- Sweep: `registered_channel_expiry`.
- Fila: `maintenance`.
- Tela mostra: status, jobs ativos, falhas, pending work, ultimo sucesso e ultimo
  erro.
- O worker emite telemetry com candidatos, canais removidos, access/bans/
  exceptions e welcome messages removidas.

Validacao:

- `mix test apps/retro_hex_chat/test/retro_hex_chat/services/chan_expiry_test.exs`
  passou: 8 testes, 0 falhas.
- `mix test apps/retro_hex_chat/test/retro_hex_chat/jobs/registered_channel_expiry_worker_test.exs`
  passou: 2 testes, 0 falhas.
- `mix test apps/retro_hex_chat/test/retro_hex_chat/jobs/oban_health_test.exs`
  passou: 3 testes, 0 falhas.
- `mix test --warnings-as-errors apps/retro_hex_chat_web/test/retro_hex_chat_web/live/nick_colors_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/address_book_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/ignore_list_feature_test.exs --include liveview_feature`
  passou: 30 testes, 0 falhas.
- `make ci` passou no rerun final: 13/13 checks, incluindo dialyzer.

Aprendizados:

- O modulo antigo podia ser reaproveitado como boundary de dominio limpo em vez
  de deletado, porque o nome ainda descreve a regra de negocio e agora nao possui
  processo nem timer.
- A listagem e o purge passaram a aceitar `now` explicito para evitar testes
  dependentes do relogio entre duas queries.
- A query de expiracao de canais precisava de indice em `last_activity_at`; a
  migration foi incluida junto da migracao para Oban.
- O CI pode retornar erro mesmo com `0 failures` quando testes emitem warnings.
  Foram removidos aliases mortos em
  `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/nick_colors_test.exs` e
  `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/address_book_test.exs`,
  alem de helpers duplicados/mortos em
  `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/ignore_list_feature_test.exs`.

### 2026-08-05 - Arquivos de planejamento e progresso

Status: CONCLUIDO

Feito:

- Criado o plano mestre em
  `docs/plans/oban-observability-standardization.md`.
- Auditado o plano mestre contra os arquivos reais do workspace.
- Criado este arquivo de progresso para acompanhar execucao, aprendizados e
  divida da janela admin.

Validacao:

- Referencias do plano mestre: 118 caminhos reais, 0 ausentes.
- ASCII: OK nos documentos novos.

Aprendizados:

- Os callbacks de timer em `RetroHexChat.Bots.Capability` ainda tem consumidores
  reais fora de scheduled messages. A migracao de `Scheduler` nao pode remover a
  API de timer global antes de migrar ou justificar esses consumidores.
- `settings_dialogs_events.ex` usa "mute" para audio local; nao deve ser tratado
  como parte do fluxo de global mute administrativo.
- Link preview precisa de cache duravel para atingir o padrao ouro. ETS sozinho
  melhora UX local, mas nao e fonte suficiente para retry/observabilidade entre
  deploys.
- A tela admin do Oban ja existe, mas hoje ainda e centrada em RSS. Ela deve ser
  generalizada por contratos conforme os workers forem migrados ou em uma fase
  final dedicada.

## Aprendizados duraveis

Mover para ca aprendizados que continuem relevantes depois de uma iteracao
especifica.

- Cron cobre recorrencia futura, nao backfill historico. Sweeps que precisam
  recuperar atraso apos restart/deploy devem ter enqueue imediato e unico.
- Upload direto por S3 pode nao ter checksum local. Cleanup de orfaos deve usar
  bucket/key/status/idade, nao checksum.
- Trusted devices devem preservar auditabilidade; expiracao materializada nao
  deve virar hard delete implicito.
- Para metricas PromEx, evitar labels de alta cardinalidade como nick, canal, URL
  completa, schedule id ou mensagem.
- Jobs Oban que fazem HTTP devem compartilhar `RetroHexChat.Net.HTTPRetry`,
  retryar apenas status transitorios (`408`, `425`, `429`, `5xx`) ou falhas de
  transporte e limitar o fluxo a 3 tentativas.
- Stale cleanup de runtime nao substitui timeouts de UX. Para sessoes que podem
  durar bastante, o cutoff duravel deve ser conservador e o update deve confirmar
  que o registro ainda esta stale no banco.
- Mutes por canal precisam de unicidade por canal/alvo enquanto nao revogados.
  Re-mute deve substituir a linha ativa e o job futuro, nao criar duas fontes de
  verdade.
- Global mute usa ETS apenas como cache derivado. O banco e a fonte de verdade,
  e expiracao por leitura no cache nao substitui a materializacao auditavel por
  worker.
- Workers de cleanup nao bastam quando existe outbox de persistencia com snapshot
  de sessao. A borda `save/2` do dominio tambem precisa rejeitar entradas
  expiradas para nao ressuscitar estado vencido.
- `Observability.set_current_span_attributes/1` atualiza o span OpenTelemetry,
  mas metricas PromEx precisam de eventos `:telemetry`; campos numericos de
  negocio devem sair por eventos whitelisted para nao depender de tags de alta
  cardinalidade.
- Politicas de dominio que dependem de preferencias persistidas por outbox Oban
  devem considerar o snapshot pendente como leitura efetiva quando a revisao ainda
  nao foi aplicada. A tabela materializada so e fonte suficiente quando nao ha
  snapshot pendente.
- Ao trocar `Task.start/1` por Oban, testes E2E nao devem usar `Process.sleep/1`
  como proxy de persistencia; devem afirmar o job enfileirado e drenar a fila
  relevante.
