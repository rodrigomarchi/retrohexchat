# Oban - padronizacao completa de observabilidade e resiliencia

**Status:** implementacao completa com ajustes finais de padrao ouro e janela
admin tabulada implementados
**Criado:** 2026-08-05
**Progresso:** `docs/plans/oban-observability-standardization-PROGRESS.md`
**Escopo:** migrar trabalho duravel, recorrente, retryable ou fire-and-forget para
Oban, com observabilidade operacional para administradores.

Todos os caminhos entre crases foram validados contra o workspace no momento da
criacao deste documento.

Este documento nao define prioridade, fase ou "agora/depois". Todos os fluxos em
"Fluxos a migrar" fazem parte da padronizacao completa. Quando um fluxo for
migrado, a implementacao antiga deve ser removida ou convertida em dominio puro;
nao deve sobrar GenServer, timer, Task ou wrapper sem uso para manter compatibilidade
artificial.

## Objetivo

A plataforma ja usa Oban para o caso de RSS. O objetivo e transformar Oban no
padrao unico para:

- trabalho recorrente que precisa sobreviver a deploy/restart;
- trabalho com I/O externo que precisa de retry e backoff;
- expiracoes e limpezas de banco/storage;
- entregas agendadas ou de longa duracao;
- persistencias assincronas que hoje podem ser perdidas se o processo morrer.

Timers e processos que representam estado vivo de usuario, socket, midia, protocolo
ou UI continuam como runtime OTP/LiveView. Eles ficam mapeados no fim do documento
para evitar migracoes erradas.

## Estado atual confirmado

Oban esta inicializado como filho da aplicacao em
`apps/retro_hex_chat/lib/retro_hex_chat/application.ex`.

Configuracao atual:

- `config/config.exs` configura `Oban.Engines.Basic`, `RetroHexChat.Repo`,
  `Oban.Plugins.Pruner`, `Oban.Plugins.Cron` e as filas `rss`, `maintenance`,
  `bots`, `link_preview` e `persistence`.
- `config/runtime.exs` expoe `OBAN_RSS_CONCURRENCY`,
  `OBAN_MAINTENANCE_CONCURRENCY`, `OBAN_BOTS_CONCURRENCY`,
  `OBAN_LINK_PREVIEW_CONCURRENCY`, `OBAN_PERSISTENCE_CONCURRENCY` e sobrescreve
  as filas `rss`, `maintenance`, `bots`, `link_preview` e `persistence`.
- `config/test.exs` desliga filas e plugins para testes.

Camada de jobs existente:

- `apps/retro_hex_chat/lib/retro_hex_chat/jobs.ex` e o boundary usado para inserir
  e cancelar jobs.
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/rss_poll_worker.ex` e o worker
  duravel de RSS.
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/server_ban_expiry_worker.ex` e o
  worker duravel de expiracao de server bans.
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/registered_channel_expiry_worker.ex`
  e o worker duravel de expiracao de canais registrados.
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/registered_nick_expiry_worker.ex`
  e o worker duravel de expiracao de nicks registrados e sucessao de founder.
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/bot_scheduled_message_worker.ex`
  e o worker duravel de mensagens agendadas de bots.
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/bot_event_log_worker.ex` e o
  worker duravel de escrita de logs de eventos de bots.
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/link_preview_fetch_worker.ex` e o
  worker duravel de fetch de previews de URL Catcher.
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/preference_save_worker.ex` e o
  worker duravel de persistencia coalescida de preferencias/listas de usuario.
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/attachment_orphan_cleanup_worker.ex`
  e o worker duravel de limpeza de uploads/anexos orfaos.
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/channel_mute_expiry_worker.ex` e
  o worker duravel de expiracao de mutes temporarios de canal.
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/global_mute_expiry_worker.ex` e
  o worker duravel de expiracao de mutes globais temporarios.
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/ignore_expired_cleanup_worker.ex`
  e o worker duravel de limpeza de ignores temporarios expirados.
- `apps/retro_hex_chat/lib/retro_hex_chat/net/http_retry.ex` e a politica
  compartilhada de retry HTTP para jobs Oban.
- `apps/retro_hex_chat/lib/retro_hex_chat/bots/capabilities/rss/scheduler.ex`
  encapsula o agendamento Oban do RSS atras de um behaviour.

Observabilidade existente:

- `apps/retro_hex_chat/lib/retro_hex_chat/prom_ex.ex` registra o plugin local de
  Oban.
- `apps/retro_hex_chat/lib/retro_hex_chat/prom_ex/plugins/oban.ex` exporta
  metricas de duracao, queue time, tentativas, excecoes e tamanho de fila por
  estado.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/telemetry.ex` declara metricas
  LiveDashboard para Oban.
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/oban_health.ex` le a saude do Oban,
  filas, jobs recentes, contrato de sucessor do RSS e sweeps de maintenance.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/system_oban_dialog.ex`
  monta a janela admin de Oban.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/system/oban_panel.ex`
  apresenta a janela.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/window_registry.ex`
  registra a janela `system-oban`.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex`
  conecta a janela ao ChatLive.

Testes existentes relevantes:

- `apps/retro_hex_chat/test/retro_hex_chat/jobs/rss_poll_worker_test.exs`
- `apps/retro_hex_chat/test/retro_hex_chat/jobs/server_ban_expiry_worker_test.exs`
- `apps/retro_hex_chat/test/retro_hex_chat/jobs/registered_channel_expiry_worker_test.exs`
- `apps/retro_hex_chat/test/retro_hex_chat/jobs/registered_nick_expiry_worker_test.exs`
- `apps/retro_hex_chat/test/retro_hex_chat/jobs/bot_scheduled_message_worker_test.exs`
- `apps/retro_hex_chat/test/retro_hex_chat/jobs/bot_event_log_worker_test.exs`
- `apps/retro_hex_chat/test/retro_hex_chat/jobs/link_preview_fetch_worker_test.exs`
- `apps/retro_hex_chat/test/retro_hex_chat/jobs/preference_save_worker_test.exs`
- `apps/retro_hex_chat/test/retro_hex_chat/jobs/oban_health_test.exs`
- `apps/retro_hex_chat/test/retro_hex_chat/net/http_retry_test.exs`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/prom_ex_test.exs`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/system_windows_feature_test.exs`
- `e2e/tests/chat-system-windows.spec.ts`

## Padrao ouro

### Contrato de codigo

- Todo enqueue deve passar por `RetroHexChat.Jobs` ou por um scheduler de dominio
  que use `RetroHexChat.Jobs`.
- Nenhum contexto de dominio deve chamar `Oban.insert`, `Oban.cancel_all_jobs` ou
  consultas diretas em `Oban.Job` fora da camada `RetroHexChat.Jobs` e da leitura
  operacional em `RetroHexChat.Jobs.ObanHealth`.
- Jobs devem ser idempotentes. Rodar duas vezes nao pode duplicar efeitos externos
  nem corromper estado.
- Jobs que trabalham sobre uma entidade persistida devem recarregar o registro
  mais recente no `perform/1`.
- Jobs que alteram estado JSONB ou listas duraveis devem usar lock transacional
  quando houver risco de concorrencia, seguindo o padrao de
  `apps/retro_hex_chat/lib/retro_hex_chat/jobs/rss_poll_worker.ex`.
- Jobs que entregam mensagem ou executam side effect visivel devem separar:
  planejamento, persistencia do estado, entrega e agendamento do sucessor.
- Jobs que nao fazem mais sentido porque o alvo foi removido devem retornar
  `{:cancel, reason}`; falhas temporarias devem retornar `{:error, reason}` para
  retry.
- Cada worker deve ter `queue`, `max_attempts`, `timeout/1`, `backoff/1`, `tags`
  e regra `unique` quando houver identidade natural do trabalho.
- Jobs Oban que fazem HTTP devem usar `RetroHexChat.Net.HTTPRetry`: status
  transitorios (`408`, `425`, `429`, `5xx`) e falhas de transporte podem retry,
  status deterministicos (`4xx` como `404`) nao devem retry, e fluxos HTTP devem
  limitar tentativas a `max_attempts: 3`.
- O payload de `args` deve ser pequeno, auditavel e sem dados sensiveis.
- Para payload grande ou sujeito a corrida, usar outbox/tabela pendente e guardar
  no job apenas chaves de lookup.

### Jobs recorrentes

- Recorrencia global de manutencao deve usar `Oban.Plugins.Cron`.
- Cron agenda ticks futuros; ele nao deve ser tratado como backfill historico.
  Sweeps que precisam recuperar atraso apos deploy/restart devem enfileirar um job
  imediato e unico no boot ou no primeiro run do supervisor que possuir o fluxo.
- Recorrencia por entidade deve ser self-scheduling: o job atual agenda o proximo
  job depois de persistir o estado, como o RSS ja faz.
- Jobs recorrentes devem ter contrato de cobertura na janela admin: "existe proximo
  job para cada alvo ativo".
- Quando uma entidade for desabilitada/removida, os jobs incompletos dela devem ser
  cancelados por `RetroHexChat.Jobs.cancel_worker_jobs/3`.

### Filas

A padronizacao completa precisa de filas separadas por natureza operacional:

- `rss`: polling de feeds RSS existente.
- `maintenance`: expiracoes, purges e limpezas de banco/storage.
- `bots`: trabalho duravel de bots, incluindo mensagens agendadas e logs de evento.
- `link_preview`: fetch seguro de metadados externos para URL Catcher.
- `persistence`: persistencia assincrona de preferencias/listas de usuario.

`config/config.exs` e `config/runtime.exs` devem deixar as concorrencias explicitas
por variavel de ambiente, no mesmo estilo de `OBAN_RSS_CONCURRENCY`.

Toda tabela duravel nova criada para suportar workers deve nascer com indices e
constraints alinhados aos acessos reais: leitura por alvo ativo, busca por vencidos,
cancelamento/logica de idempotencia e unicidade natural do fluxo.

### Observabilidade

Cada fluxo migrado deve expor:

- contagem de jobs por fila, worker e estado;
- duracao de execucao;
- tempo em fila;
- tentativas;
- erro normalizado;
- ultimo sucesso;
- ultimo descarte/cancelamento;
- contrato de cobertura quando o fluxo exigir sucessor;
- metricas de dominio com numeros de negocio.

As metricas de dominio devem usar `RetroHexChat.Observability` quando o fluxo ja
tiver spans ou quando o worker executar uma operacao relevante. A janela admin de
Oban deve deixar de ser RSS-centrica e passar a ter secoes por contrato,
agrupadas em tabs para reduzir ruido visual e dar foco operacional:

- filas;
- workers;
- jobs recentes;
- RSS feeds;
- bot schedules;
- maintenance sweeps;
- storage/link previews;
- persistence flushes.

Contrato visual implementado:

- topo sempre visivel com status geral e cards de contratos duraveis;
- tab `Overview` com configuracao do supervisor e motivos de status;
- tab `Queues` com filas por estado e jobs recentes filtraveis;
- tab `Bots` com RSS, schedules e backlog/falhas de logs de eventos;
- tab `Maintenance` com todos os sweeps duraveis;
- tab `Previews` com cache/fetch de link preview, retry e falha final;
- tab `Persistence` com outbox de preferencias/listas.

## Fluxos a migrar

### Server ban expiry

Status: implementado em 2026-08-05.

Arquivos atuais:

- `apps/retro_hex_chat/lib/retro_hex_chat/admin.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/admin/server_bans.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/admin/ban_cache.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/server_ban_expiry_worker.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/application.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/oban_health.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/system/oban_panel.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/admin/user.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.ex`

Fluxo antes da migracao:

1. `Admin.ban_user/4` calcula `expires_at` quando ha duracao.
2. `ServerBans.ban/4` insere `server_bans` e atualiza `BanCache`.
3. `ChatLive` consulta `ServerBans.banned?/1` na entrada.
4. `Admin.BanExpiry` roda como GenServer e usa `Process.send_after/3`.
5. A cada tick, `ServerBans.expire_bans/0` desativa bans vencidos e remove cada
   nick do `BanCache`.

Migracao implementada:

- `RetroHexChat.Jobs.ServerBanExpiryWorker` expira server bans na fila
  `maintenance`.
- `Oban.Plugins.Cron` enfileira o worker em `@reboot` e `@hourly`.
- `ServerBans.expire_bans/0` permanece como dominio e
  `ServerBans.expired_count/0` alimenta o snapshot admin.
- `RetroHexChat.Admin.BanExpiry` foi removido da supervision tree e o modulo
  antigo foi deletado.
- A janela admin mostra o contrato de maintenance sweeps com status, jobs ativos,
  falhas, pending work, ultimo sucesso e ultimo erro.

Sem codigo morto:

- Nao manter GenServer antigo "por garantia".
- Nao manter dois agendadores para o mesmo sweep.

### Registered channel expiry

Status: implementado em 2026-08-05.

Arquivos atuais:

- `apps/retro_hex_chat/lib/retro_hex_chat/services/chan_expiry.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/services/queries.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/registered_channel_expiry_worker.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/application.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/oban_health.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/system/oban_panel.ex`
- `apps/retro_hex_chat/priv/repo/migrations/20260805120000_add_registered_channels_last_activity_index.exs`
- `apps/retro_hex_chat/test/retro_hex_chat/services/chan_expiry_test.exs`
- `apps/retro_hex_chat/test/retro_hex_chat/jobs/registered_channel_expiry_worker_test.exs`

Fluxo antes da migracao:

1. `Services.ChanExpiry` roda como GenServer.
2. `init/1` agenda `:purge` por `Process.send_after/3`.
3. `run_now/1` existe para executar o purge sincrono, usado nos testes.
4. `do_purge/1` chama `Queries.list_expired_channel_names/1`.
5. Para cada canal, remove access, bans, ban exceptions, invite exceptions e
   welcome message.
6. `Queries.purge_expired_channels/1` remove canais registrados vencidos.

Migracao implementada:

- `RetroHexChat.Services.ChanExpiry` foi transformado em modulo de dominio puro:
  sem `use GenServer`, sem `start_link/1`, sem `Process.send_after/3`.
- `ChanExpiry.purge/1` retorna contadores de candidatos, canais removidos,
  access, bans, ban exceptions, invite exceptions e welcome messages removidas.
- `RetroHexChat.Jobs.RegisteredChannelExpiryWorker` executa o purge na fila
  `maintenance`.
- `Oban.Plugins.Cron` enfileira o worker em `@reboot` e `0 */6 * * *`.
- `RetroHexChat.Services.ChanExpiry` foi removido da supervision tree.
- `registered_channels.last_activity_at` ganhou indice para o acesso do worker.
- A janela admin lista o sweep `registered_channel_expiry` junto dos demais
  maintenance sweeps.

Observabilidade:

- metricas de canais candidatos;
- canais removidos;
- access/bans/exceptions/welcome removidos;
- duracao do sweep;
- ultimo sweep sem erro.

### Registered nick expiry e founder succession

Status: implementado em 2026-08-05.

Arquivos atuais:

- `apps/retro_hex_chat/lib/retro_hex_chat/services/nick_expiry.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/services/queries.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/services/nick_serv.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/admin/role_cache.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/registered_nick_expiry_worker.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/application.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/oban_health.ex`
- `apps/retro_hex_chat/priv/repo/migrations/20260805121000_add_registered_nicks_last_seen_index.exs`
- `apps/retro_hex_chat/test/retro_hex_chat/services/nick_expiry_test.exs`
- `apps/retro_hex_chat/test/retro_hex_chat/services/chan_expiry_test.exs`
- `apps/retro_hex_chat/test/retro_hex_chat/jobs/registered_nick_expiry_worker_test.exs`

Fluxo atual:

1. `Services.NickExpiry` monta a lista protegida com `NickServ.list_identified/1` e
   `RoleCache.list_admin_nicks/0`.
2. `Queries.purge_expired_nicks/4` remove nicks por `last_seen_at`.
3. Para cada nick removido, `NickServ.remove_identified/2` limpa runtime.
4. `handle_founder_succession/1` remove access do nick vencido.
5. Se houver sucessor, promove por `Queries.add_access/4` e
   `Queries.update_channel_founder/2`.
6. Se nao houver sucessor, remove access, bans, exceptions, welcome e apaga o
   canal registrado.

Migracao implementada:

- `RetroHexChat.Services.NickExpiry` virou dominio puro: sem `use GenServer`,
  sem `start_link/1`, sem `run_now/1` e sem `Process.send_after/3`.
- `NickExpiry.purge/1` retorna contadores de nicks expirados, candidatos,
  protegidos, removidos, sucessoes de founder, canais orfaos removidos e limpeza
  de access/bans/exceptions/welcome.
- `RetroHexChat.Jobs.RegisteredNickExpiryWorker` executa o purge na fila
  `maintenance`.
- `Oban.Plugins.Cron` enfileira o worker em `@reboot` e `15 */6 * * *`.
- A protecao de nicks identificados e administradores foi preservada.
- A sucessao ou remocao de cada canal ocorre em transacao.
- `RetroHexChat.Services.NickExpiry` foi removido da supervision tree.
- `registered_nicks.last_seen_at` ganhou indice para o acesso do worker.
- A janela admin lista o sweep `registered_nick_expiry` junto dos demais
  maintenance sweeps.

Observabilidade:

- nicks candidatos;
- nicks removidos;
- nicks protegidos por identificacao;
- nicks protegidos por admin;
- canais com founder promovido;
- canais orfaos removidos;
- falhas por etapa.

### Bot scheduled messages

Status: implementado em 2026-08-05.

Arquivos atuais:

- `apps/retro_hex_chat/lib/retro_hex_chat/bots/capability.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/bots/capabilities/scheduler.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/bots/capabilities/scheduler/durable.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/bots/server.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/bots/output.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/bots/queries.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/bots/lifecycle.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/bot_scheduled_message_worker.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/bots/loader.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/bot_events.ex`
- `apps/retro_hex_chat/test/retro_hex_chat/bots/capabilities/scheduler_test.exs`
- `apps/retro_hex_chat/test/retro_hex_chat/bots/server_test.exs`
- `apps/retro_hex_chat/test/retro_hex_chat/bots/bot_lifecycle_test.exs`
- `apps/retro_hex_chat/test/retro_hex_chat/jobs/bot_scheduled_message_worker_test.exs`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/bot_management_entry_points_feature_test.exs`

Fluxo atual:

1. A capability `Scheduler` declara `durable_keys/0` com `:schedules`.
2. `handle_add/3` adiciona schedules `interval` ou `daily` no estado da capability.
3. `handle_remove/2` remove schedules do estado.
4. `Bots.Server.update_capability_state/3` persiste fatias duraveis no JSONB de
   `bots.capabilities`.
5. `Bots.Server.reconcile_timers/2` chama `Scheduler.init_timers/4`, mas o
   callback nao cria timer local para scheduler; ele reconcilia jobs duraveis via
   `Scheduler.Durable`.
6. `Scheduler.Durable.Oban` cancela jobs stale do bot e garante um job incompleto
   por schedule ativo.
7. `BotScheduledMessageWorker` recarrega o bot, valida bot/capability/schedule,
   atualiza `last_fired` sob lock, entrega via `Bots.Output` e agenda o sucessor.
8. `Bots.Lifecycle.destroy_bot/1` e `BotEvents` cancelam jobs ao destruir,
   desabilitar bot ou desabilitar a capability `scheduler`.

Migracao implementada:

- O disparo local foi trocado por Oban, preservando o armazenamento duravel
  existente de schedules em `bots.capabilities`.
- Criado o boundary `Scheduler.Durable`, equivalente ao boundary de RSS em
  `apps/retro_hex_chat/lib/retro_hex_chat/bots/capabilities/rss/scheduler.ex`.
- Criado `RetroHexChat.Jobs.BotScheduledMessageWorker` na fila `bots`.
- `config/config.exs` e `config/runtime.exs` ganharam a fila `bots` e
  `OBAN_BOTS_CONCURRENCY`.
- `Scheduler.handle_timer/3` e `Scheduler.reschedule_delay/2` foram removidos.
- `Scheduler.init_timers/4` ficou apenas como ponte de reconciliacao duravel,
  sem `Process.send_after/3` ou `Bots.Server.schedule_capability_timer/4`.
- O worker recarrega o bot por `Bots.Queries.get_bot/1`, valida se o bot ainda
  existe, esta enabled, a capability existe e o schedule ainda existe.
- O worker atualiza `last_fired` no estado duravel sob lock antes de planejar o
  sucessor.
- A entrega usa `Bots.Output`, sem duplicar detalhes de canal no worker.
- O sucessor e self-scheduled por schedule.
- Ao remover schedule, desabilitar bot, destruir bot ou desabilitar a capability,
  jobs incompletos sao cancelados pelo boundary `RetroHexChat.Jobs`.
- Revisar `Bots.Capability` para separar timer runtime de job duravel. Os callbacks
  de timer devem permanecer enquanto capabilities runtime reais os usarem, como
  `apps/retro_hex_chat/lib/retro_hex_chat/bots/capabilities/trivia.ex` e, ate a
  remocao final do timer legado de RSS,
  `apps/retro_hex_chat/lib/retro_hex_chat/bots/capabilities/rss.ex`.

Observabilidade:

- schedules ativos;
- schedules sem job sucessor;
- proxima execucao por schedule;
- ultimo disparo;
- mensagens entregues;
- cancelamentos por bot removido, bot disabled, capability disabled ou schedule
  removido;
- falhas de entrega por canal indisponivel.

### Bot event log fire-and-forget

Status: implementado em 2026-08-05.

Arquivos atuais:

- `apps/retro_hex_chat/lib/retro_hex_chat/bots/server.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/bots/queries.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/bot_event_log_worker.ex`
- `apps/retro_hex_chat/test/retro_hex_chat/jobs/bot_event_log_worker_test.exs`
- `apps/retro_hex_chat/test/retro_hex_chat/bots/server_test.exs`

Fluxo atual:

1. `Bots.Server` chama `log_event_async/4`.
2. `log_event_async/4` normaliza metadata para payload JSON seguro.
3. `log_event_async/4` enfileira `BotEventLogWorker` via `RetroHexChat.Jobs`.
4. O worker recarrega o bot; se o bot sumiu, cancela o job.
5. O worker chama `Bots.Queries.log_event/4`.

Migracao implementada:

- Criado worker Oban para logs de evento de bot na fila `bots`.
- `log_event_async/4` foi substituido por enqueue via `RetroHexChat.Jobs`.
- O worker chama `Bots.Queries.log_event/4`.
- O worker nao usa `unique`, porque eventos distintos nao possuem identidade
  natural e nao devem ser deduplicados.
- Erros de enqueue e escrita nao sao mais descartados silenciosamente; eles
  entram em log/telemetry e seguem retry quando apropriado.
- O uso de `Task.start/1` foi removido desse fluxo.

Observabilidade:

- logs enfileirados;
- logs gravados;
- logs descartados por bot removido;
- falhas de changeset/DB.

### Link preview fetch para URL Catcher

Status: implementado em 2026-08-05.

Arquivos atuais:

- `apps/retro_hex_chat/lib/retro_hex_chat/chat/link_preview.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/link_preview/cache.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/link_preview/http.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/link_preview/result.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/link_preview/results.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/link_preview_fetch_worker.ex`
- `apps/retro_hex_chat/priv/repo/migrations/20260805122000_create_link_previews.exs`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/session.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/presence.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/url_catcher_dialog.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/oban_health.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/system/oban_panel.ex`
- `config/config.exs`
- `config/runtime.exs`

Fluxo legado removido:

1. ChatLive captura URLs e chama `maybe_fetch_previews/2`.
2. `fetch_preview_for_url/2` consulta `LinkPreview.Cache`.
3. Em miss, `spawn_preview_fetch/2` marca pending no ETS.
4. O fetch roda por `Task.Supervisor.async_nolink/2`.
5. `LinkPreview.HTTP.fetch_title/1` faz HTTP com validacao SSRF por
   `RetroHexChat.Net.URLGuard`.
6. A task envia `{:link_preview_result, url, result}` para o pid da LiveView.
7. O handler atualiza ETS e os entries do URL Catcher.

Implementacao:

- Criado `RetroHexChat.Jobs.LinkPreviewFetchWorker` na fila `link_preview`.
- `config/config.exs` e `config/runtime.exs` ganharam fila `link_preview` e
  `OBAN_LINK_PREVIEW_CONCURRENCY`.
- O enqueue e unique por `url_hash`, derivado da URL normalizada.
- O worker deve manter o uso de `LinkPreview.HTTP`, sem duplicar regras de SSRF,
  redirect, timeout ou parsing.
- O worker usa `LinkPreview.fetch_title_result/1`, que preserva status HTTP
  quando a implementacao suporta a API rica.
- Erros HTTP transitorios (`408`, `425`, `429`, `5xx`) e falhas de transporte
  tentam retry, limitados por `max_attempts: 3`.
- Erros deterministicos (`404`, URL bloqueada, sem HTML, sem titulo/metadado)
  viram falha persistida sem retry.
- O resultado nao depende de pid de LiveView. O worker grava resultado em
  `link_previews`, atualiza ETS derivado e publica via PubSub.
- A LiveView assina o topico global de previews e atualiza a
  janela quando o resultado chegar.
- O resultado e persistido em banco com URL normalizada, hash, status,
  titulo/metadados, erro normalizado, TTL e timestamps.
- ETS continua como cache derivado/read-through, nao como fonte unica de verdade.
- `RetroHexChat.LinkPreviewTasks` foi removido da supervision tree.
- `Task.Supervisor.async_nolink/2` foi removido desse fluxo.
- A janela admin do Oban ganhou card e tabela de `Link preview cache`, lendo o
  snapshot em `ObanHealth`.

Observabilidade:

- fetch started;
- fetch ok;
- fetch sem titulo;
- fetch bloqueado por URLGuard;
- fetch timeout;
- erros HTTP;
- cache hit/miss;
- backlog por fila.

Fechado em 2026-08-06:

- A tabela `Link preview cache` mostra agregados por status, expirados,
  timestamps, retry transitorio em `retrying` e falha final em `final_failures`,
  sem expor URL completa ou dominio externo como label.

### Persistencia assincrona de preferencias/listas de usuario

Status: implementado em 2026-08-05.

Arquivos atuais de chamada:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/persistence.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/settings_dialogs_events.ex`

Arquivos atuais de destino:

- `apps/retro_hex_chat/lib/retro_hex_chat/presence/notify_list.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/accounts/contact_list.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/accounts/nick_colors.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/highlight_words.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/ignore_list.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/perform_list.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/autojoin_list.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/input_history.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/alias_list.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/custom_menus.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/auto_respond_rules.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/flood_protection.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/sound_settings.ex`

Arquivos novos/alterados da migracao:

- `apps/retro_hex_chat/lib/retro_hex_chat/chat/preference_persistence.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/preference_persistence/request.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/preference_save_worker.ex`
- `apps/retro_hex_chat/priv/repo/migrations/20260805123000_create_preference_save_requests.exs`
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/oban_health.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/system/oban_panel.ex`
- `config/config.exs`
- `config/runtime.exs`

Fluxo legado removido:

1. A LiveView altera a sessao em memoria.
2. Helpers chamam `Task.start/1` para persistir a lista/preferencia se o usuario
   estiver identificado.
3. Cada modulo de dominio executa `save/2`.
4. Varios `save/2` apagam os registros atuais e reinserem o snapshot.

Implementacao:

- Criada a tabela `preference_save_requests` como outbox por `owner_nickname` e
  `preference_type`.
- O payload de cada preferencia/lista fica na outbox; o job carrega apenas
  `owner_nickname` e `preference_type`.
- O upsert da outbox incrementa `revision`, sobrescreve o snapshot mais recente e
  coalesce alteracoes rapidas do mesmo tipo.
- `RetroHexChat.Jobs.PreferenceSaveWorker` roda na fila `persistence`, com unique
  por usuario/tipo em estados incompletos.
- O worker marca a request como `processing`, hidrata o payload para o formato de
  dominio, chama o `save/2` correto e marca `applied` quando a `revision` salva e
  a mais recente.
- Se uma alteracao nova chegar enquanto o worker executa, a request volta para
  `pending` e o job retorna erro controlado para retry.
- Falhas de changeset/DB/excecao ficam normalizadas em `last_error`, com
  `attempts` e `last_attempted_at`.
- `helpers/persistence.ex` e `settings_dialogs_events.ex` deixaram de usar
  `Task.start/1` para estes fluxos.
- `sound_settings` foi incluido porque `settings_dialogs_events.ex` persiste o
  mesmo tipo de preferencia de usuario.
- `config/config.exs` e `config/runtime.exs` ganharam fila `persistence` e
  `OBAN_PERSISTENCE_CONCURRENCY`.
- A janela admin do Oban ganhou card `Preference saves` e tabela `Preference
  persistence`, lendo backlog, falhas, bytes de payload e idade do pendente mais
  antigo pelo snapshot de `ObanHealth`.

Observabilidade:

- saves pendentes/processando por tipo;
- saves aplicados/falhos por tipo;
- tamanho agregado do payload por tipo/status;
- `oldest_pending_at` e `last_attempted_at`;
- falhas normalizadas por request;
- backlog da fila `persistence` no painel generico de filas/jobs.

Observacao de UI:

- A consolidacao final da janela pode separar os tipos de preferencia por familia
  visual, mas os dados operacionais necessarios ja estao no snapshot.

### Attachment orphan cleanup

Status: implementado em 2026-08-05.

Arquivos atuais:

- `apps/retro_hex_chat/lib/retro_hex_chat/chat/attachments.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/queries.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/uploaded_file.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/attachment.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/attachments/storage.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/attachments/s3_storage.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/attachment_orphan_cleanup_worker.ex`
- `apps/retro_hex_chat/priv/repo/migrations/20260804150000_create_chat_attachments.exs`
- `apps/retro_hex_chat/priv/repo/migrations/20260804153000_add_preview_fields_to_chat_uploaded_files.exs`
- `apps/retro_hex_chat/priv/repo/migrations/20260805124000_add_chat_uploaded_files_orphan_cleanup_index.exs`
- `apps/retro_hex_chat/test/retro_hex_chat/chat/attachments_test.exs`
- `apps/retro_hex_chat/test/retro_hex_chat/jobs/attachment_orphan_cleanup_worker_test.exs`
- `apps/retro_hex_chat/test/retro_hex_chat/jobs/oban_health_test.exs`

Fluxo legado:

1. `Attachments.prepare_direct_upload/2` cria registro `reserved` e URL PUT com
   expiracao curta.
2. `Attachments.confirm_uploaded_files/2` chama `Queries.mark_uploaded_files/2`
   e muda `reserved/uploaded` para `uploaded`.
3. `Queries.attach_to_message/3` ou `attach_to_private_message/3` muda
   `uploaded` para `attached` e cria `chat_attachments`.
4. O storage behaviour tem `put_file/3`, `presigned_put_url/3` e
   `presigned_get_url/3`.
5. A implementacao S3 nao expoe delete.
6. Nao ha cleanup atual para objetos/registros `reserved` ou `uploaded` que nunca
   viraram attachment.

Implementacao:

- `RetroHexChat.Chat.Attachments.Storage` ganhou `delete_file/3`.
- `RetroHexChat.Chat.Attachments.S3Storage.delete_file/3` usa delete de objeto S3
  e trata `404` como sucesso idempotente.
- `RetroHexChat.Chat.Queries` ganhou listagem/contagem de uploads orfaos por
  `status`, `inserted_at` e ausencia de `chat_attachments`.
- `RetroHexChat.Chat.Attachments.cleanup_orphan_uploads/1` trava cada candidato
  com `FOR UPDATE`, confirma que ainda esta `reserved/uploaded` e sem attachment,
  apaga o objeto no storage e so entao marca `chat_uploaded_files.status` como
  `deleted`.
- Se o delete no storage falhar, a transacao nao marca o registro como
  `deleted`; o worker retorna erro para retry.
- `RetroHexChat.Jobs.AttachmentOrphanCleanupWorker` roda na fila `maintenance`
  com `max_attempts: 3`, timeout, backoff e unique por worker/fila.
- `Oban.Plugins.Cron` agenda o cleanup em `@reboot` e `30 * * * *`.
- A migration nova adiciona indice parcial para candidatos
  `reserved/uploaded` por idade.
- A janela admin de Oban inclui o sweep `Attachment orphan cleanup` na tabela de
  maintenance, com pending work vindo de `Attachments.orphan_upload_count/1`.

Observabilidade:

- arquivos candidatos;
- objetos apagados;
- bytes liberados;
- registros marcados como `deleted`;
- falhas por provider;
- idade do upload orfao mais antigo.

### Trusted devices e chat device sessions

Status: implementado em 2026-08-05.

Arquivos atuais:

- `apps/retro_hex_chat/lib/retro_hex_chat/accounts/trusted_devices.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/accounts/trusted_device.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/accounts/trusted_device_nick.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/accounts/trusted_device_preference.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/accounts/trusted_device_event.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/accounts/chat_device_session.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/trusted_device_expiry_worker.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/chat_device_session_cleanup_worker.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/connection.ex`
- `apps/retro_hex_chat/priv/repo/migrations/20260727120000_create_trusted_devices.exs`
- `apps/retro_hex_chat/priv/repo/migrations/20260729100000_add_auto_login_to_trusted_device_nicks.exs`
- `apps/retro_hex_chat/priv/repo/migrations/20260805125000_add_trusted_device_cleanup_indexes.exs`
- `apps/retro_hex_chat/test/retro_hex_chat/accounts/trusted_devices_test.exs`
- `apps/retro_hex_chat/test/retro_hex_chat/jobs/trusted_device_cleanup_worker_test.exs`
- `apps/retro_hex_chat/test/retro_hex_chat/jobs/oban_health_test.exs`

Fluxo legado:

1. Trusted devices recebem `expires_at` e sao renovados em uso.
2. Consultas de remembered devices excluem `revoked_at` e `expires_at <= now`.
3. `ensure_device_usable/1` rejeita revoked/expired.
4. `record_session_start/3` cria `chat_device_sessions`.
5. `Connection.handle_ping/2` chama `TrustedDevices.touch_session/1` no maximo a
   cada 60s.
6. `record_session_stop/2` marca `disconnected_at`.
7. A listagem de sessoes ativas filtra `disconnected_at IS NULL`.

Implementacao:

- `TrustedDevices.expire_devices/1` materializa devices vencidos como revogados
  por `system`, sem hard delete.
- A expiracao revoga grants ativos em `trusted_device_nicks`, preenche
  `trusted_devices.revoked_at/revoked_by_nickname` e registra evento
  `device.expired`.
- `TrustedDevices.close_stale_sessions/1` fecha linhas ativas de
  `chat_device_sessions` cujo `last_seen_at` passou do cutoff e marca
  `disconnect_reason` como `stale_heartbeat`.
- O fechamento de sessao stale nao envia `force_disconnect`; ele materializa a
  auditoria de sessoes que deixaram de receber heartbeat.
- `TrustedDeviceExpiryWorker` e `ChatDeviceSessionCleanupWorker` rodam na fila
  `maintenance`, com `max_attempts: 3`, timeout, backoff e unique por worker/fila.
- `Oban.Plugins.Cron` agenda os dois workers em `@reboot`; devices vencidos rodam
  em `35 * * * *` e sessoes stale em `*/15 * * * *`.
- A migration nova adiciona indices parciais para devices nao revogados por
  `expires_at` e sessoes ativas por `last_seen_at`.
- A janela admin de Oban inclui os sweeps `Trusted device expiry` e
  `Chat device session cleanup` na tabela de maintenance.

Observabilidade:

- devices vencidos encontrados;
- devices materializados como expirados/revogados;
- sessoes stale fechadas;
- idade da sessao ativa mais antiga sem touch;
- falhas de update.

### Lobby, arcade e group call stale cleanup

Status: implementado em 2026-08-05.

Arquivos atuais:

- `apps/retro_hex_chat/lib/retro_hex_chat/lobby/queries.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/lobby/session_server.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/arcade/queries.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/arcade/solo_session_server.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/group_call/queries.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/group_call/room_server.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/runtime_stale_cleanup.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/runtime_stale_cleanup_worker.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/oban_health.ex`
- `apps/retro_hex_chat/priv/repo/migrations/20260805130000_add_runtime_stale_cleanup_indexes.exs`
- `apps/retro_hex_chat/test/retro_hex_chat/jobs/runtime_stale_cleanup_worker_test.exs`

Fluxo atual:

1. Lobby tem `Queries.list_stale_sessions/1` e `Queries.expire_session/1`.
2. Arcade tem `Queries.list_stale_sessions/1` e `Queries.expire_session/1`.
3. Group call tem `Queries.list_stale_rooms/1` e `Queries.expire_room/1`.
4. Os session/room servers tambem possuem timers runtime para pending, lobby,
   reconnect, ready e peerless timeouts.
5. `RuntimeStaleCleanupWorker` agenda a reconciliacao duravel pela fila
   `maintenance`.

Migracao implementada:

- Criado `RetroHexChat.RuntimeStaleCleanup` para coordenar o dominio entre
  lobby, arcade e group call sem colocar regra de negocio dentro do worker.
- `RuntimeStaleCleanupWorker` roda na fila `maintenance`, com `max_attempts: 3`,
  timeout, backoff e unique por worker/fila.
- `Oban.Plugins.Cron` agenda o worker em `@reboot` e `45 * * * *`.
- O cutoff default e conservador: 24 horas. Isso evita encerrar sessoes
  longas validas; o worker e uma rede de seguranca para registros realmente
  abandonados.
- As queries de expiracao stale sao condicionais no update: se o registro deixou
  de estar nao-terminal ou foi atualizado depois da selecao de candidatos, o
  item e marcado como `skipped`, nao expirado.
- A migration nova adiciona indices parciais por `updated_at` em
  `lobby_sessions`, `solo_sessions` e `group_call_rooms` para registros
  nao-terminais.
- A janela admin de Oban inclui o sweep `Runtime stale cleanup` na tabela de
  maintenance.
- Nao substituir timers de UX dos session/room servers; eles continuam dando
  feedback em tempo real quando o processo esta vivo.
- O worker e a rede de seguranca para quando o processo caiu, deploy interrompeu
  fluxo ou o registro ficou aberto sem owner runtime.

Observabilidade:

- sessoes lobby expiradas por stale cleanup;
- sessoes arcade expiradas por stale cleanup;
- rooms group call expiradas por stale cleanup;
- idade maxima de registro nao-terminal stale;
- falhas por dominio.

### Channel mute duravel

Status: implementado em 2026-08-05.

Arquivos atuais:

- `apps/retro_hex_chat/lib/retro_hex_chat/channels/server.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/channels/channel_mute.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/channels/mutes.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/channel_mute_expiry_worker.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/oban_health.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/mute_cmd.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/ui_actions/core.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/context_menu_events.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/channel.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/channel_state.ex`
- `apps/retro_hex_chat/priv/repo/migrations/20260805131000_create_channel_mutes.exs`
- `apps/retro_hex_chat/test/retro_hex_chat/channels/mutes_test.exs`
- `apps/retro_hex_chat/test/retro_hex_chat/jobs/channel_mute_expiry_worker_test.exs`

Fluxo antes da migracao:

1. UI/comandos chamam `Channels.Server.channel_mute/4`.
2. `Channels.Server` guarda `channel_mutes` em memoria.
3. Para duracao temporaria, agenda `{:unmute_timer, target_nick}` com
   `Process.send_after/3`.
4. `handle_info({:unmute_timer, target_nick}, state)` remove o nick do MapSet e
   broadcasta unmute.
5. `check_channel_mute/2` bloqueia envio enquanto o nick esta no MapSet.
6. `get_state/1` expoe `channel_mutes` para a UI.

Migracao implementada:

- Criado `RetroHexChat.Channels.ChannelMute` e a tabela `channel_mutes` com
  canal, alvo, alvo normalizado, operador, motivo opcional, `expires_at`,
  `revoked_at`, ator/reason de revogacao e timestamps.
- Criado `RetroHexChat.Channels.Mutes` como dominio duravel para criar,
  substituir, revogar, contar e expirar mutes.
- `Channels.Server` carrega mutes ativos no start do canal.
- `channel_mute/4` persiste o mute e enfileira `ChannelMuteExpiryWorker` quando
  temporario.
- `channel_unmute/3` revoga no banco, cancela jobs incompletos e atualiza o
  runtime.
- `ChannelMuteExpiryWorker` recarrega o mute, valida se ainda esta ativo e
  vencido, revoga como `system/expired` e pede ao `Channels.Server` vivo para
  retirar o mute do MapSet e publicar o evento de unmute.
- `Process.send_after/3` e `handle_info({:unmute_timer, ...})` foram removidos
  desse fluxo.
- A janela admin de Oban inclui `Channel mute expiry` na tabela de maintenance,
  com jobs ativos/falhas/pending work.

Observabilidade:

- mutes ativos por canal;
- unmute jobs agendados;
- mutes expirados;
- cancelamentos manuais;
- falhas de broadcast/update.

### Global mute duravel

Status: implementado em 2026-08-05.

Arquivos atuais:

- `apps/retro_hex_chat/lib/retro_hex_chat/admin.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/admin/global_mute.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/admin/global_mutes.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/admin/global_mute_table.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/application.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/global_mute_expiry_worker.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/oban_health.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/admin/user.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/command_dispatch.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/server_messages.ex`
- `apps/retro_hex_chat/priv/repo/migrations/20260805132000_create_global_mutes.exs`
- `apps/retro_hex_chat/test/retro_hex_chat/admin/global_mutes_test.exs`
- `apps/retro_hex_chat/test/retro_hex_chat/jobs/global_mute_expiry_worker_test.exs`

Fluxo antes da migracao:

1. `Admin.mute_user/4` chama `GlobalMutes.mute/3`.
2. `GlobalMutes` delega para `GlobalMuteTable`.
3. `GlobalMuteTable` e ETS-backed e declara que o estado e efemero.
4. Mutes temporarios sao guardados como monotonic expiration no ETS.
5. `muted?/1` checa expiracao no momento da leitura.
6. `CommandDispatch` bloqueia envio quando `GlobalMutes.muted?/1` retorna true.
7. `pubsub_handlers/server_messages.ex` recebe `{:user_muted, ...}` para informar o
   usuario afetado.
8. `Admin.nuke` limpa a tabela ETS `:global_mutes`.

Migracao implementada:

- Criado `RetroHexChat.Admin.GlobalMute` e a tabela `global_mutes` com alvo,
  alvo normalizado, operador/admin, motivo, `expires_at`, `revoked_at`,
  ator/reason de revogacao e timestamps.
- `RetroHexChat.Admin.GlobalMutes` virou fonte de verdade duravel: cria,
  substitui, revoga, conta e expira mutes globais.
- `GlobalMuteTable` permanece como cache ETS derivado do banco, sem semantica de
  fonte efemera.
- `GlobalMutes.mute/4` persiste e atualiza cache runtime.
- `GlobalMutes.unmute/2` revoga no banco, cancela jobs incompletos e limpa cache.
- `GlobalMuteExpiryWorker` roda na fila `maintenance`, com `max_attempts: 3`,
  recarrega o mute, valida vencimento, materializa `system/expired`, limpa cache
  e publica `user_unmuted`.
- `Admin.nuke` passou a deletar a tabela duravel `global_mutes`; a limpeza ETS
  restante e apenas limpeza de cache.
- A janela admin de Oban inclui `Global mute expiry` na tabela de maintenance.

Observabilidade:

- mutes globais ativos;
- expiracoes executadas;
- revogacoes manuais;
- divergencia cache/banco se cache permanecer.

### Ignore entries com expiracao

Arquivos atuais:

- `apps/retro_hex_chat/lib/retro_hex_chat/chat/ignore_entry.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/ignore_list.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/schemas/ignore_list_entry.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/session.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/flood.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/ui_actions/ignore.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/ignore_list_dialog.ex`

Fluxo atual:

1. Ignore entries podem ter `expires_at`.
2. `IgnoreEntry.expired?/1` calcula expiracao em memoria.
3. `IgnoreList.load/1` filtra entradas expiradas, mas nao remove do banco.
4. ChatLive agenda timers locais para remover ignore/auto-ignore da sessao.
5. A persistencia da lista passa pelo fluxo fire-and-forget descrito em
   "Persistencia assincrona de preferencias/listas de usuario".

Migracao:

- Criado cleanup Oban na fila `maintenance` para remover entradas expiradas do
  banco:
  `apps/retro_hex_chat/lib/retro_hex_chat/jobs/ignore_expired_cleanup_worker.ex`.
- Criada a migration
  `apps/retro_hex_chat/priv/repo/migrations/20260805133000_add_ignore_list_entries_expiry_index.exs`
  com indice parcial em `expires_at`.
- Timers locais foram mantidos apenas para feedback imediato da sessao viva.
- O worker nao remove entradas permanentes (`expires_at IS NULL`).
- `IgnoreList.save/2` filtra entradas expiradas para evitar que
  `PreferenceSaveWorker` regrave snapshot antigo.
- `ObanHealth` mostra `Ignore expired cleanup` na tabela de maintenance.

Observabilidade:

- ignores expirados pendentes via `IgnoreList.expired_entry_count/1`;
- ignores expirados removidos via telemetry do worker;
- idade maxima de ignore expirado processado via `oldest_expired_age_ms`;
- falhas de delete via estado do job e `Last error` da tabela de maintenance;
- interacao com persistence queue observada junto da tabela `Preference
  persistence`.

## Evolucao da janela admin de Oban

Arquivos atuais:

- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/oban_health.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/system_oban_dialog.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/system/oban_panel.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/window_registry.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/controllers/help_content/ui_system_windows.html.heex`

Mudanca necessaria:

- `ObanHealth` foi generalizado para contratos multiplos, nao somente RSS.
- A tabela de filas por estado foi mantida.
- Jobs recentes podem ser filtrados por estado, fila e worker.
- Secoes de contrato implementadas:
  - RSS successor coverage;
  - scheduled bot messages successor coverage;
  - bot event log backlog/failures;
  - maintenance last-run coverage;
  - storage cleanup summary via maintenance;
  - link preview fetch summary;
  - persistence backlog summary;
  - ignore-list cleanup summary via maintenance.
- Cada secao vem de funcoes de leitura no dominio ou em `ObanHealth`; a UI nao
  conhece detalhes de schema do Oban alem do snapshot.
- A tela exibe estado healthy/warning/critical com razoes concretas.
- Help content foi atualizado para explicar os contratos observaveis.

## Evolucao do PromEx e telemetry

Arquivos atuais:

- `apps/retro_hex_chat/lib/retro_hex_chat/prom_ex.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/prom_ex/plugins/oban.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/telemetry.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/observability.ex`

Mudanca necessaria:

- Metricas genericas atuais do Oban foram mantidas em
  `apps/retro_hex_chat/lib/retro_hex_chat/prom_ex/plugins/oban.ex`.
- `apps/retro_hex_chat/lib/retro_hex_chat/observability.ex` emite eventos
  genericos de dominio para campos numericos whitelisted:
  `[:retro_hex_chat, :observability, :operation, :counter]` e
  `[:retro_hex_chat, :observability, :operation, :value]`.
- `apps/retro_hex_chat/lib/retro_hex_chat/prom_ex/plugins/domain.ex` exporta
  `operation.counter.total` e `operation.value`.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/telemetry.ex` declara as mesmas
  metricas para o painel runtime.
- Tags estaveis e de baixa cardinalidade: `context`, `operation`, `result`,
  `measurement`.
- Nao usar tags com URL completa, nick arbitrario, canal arbitrario, bot id, feed
  id, schedule id, args ou mensagem.
- Para link previews, normalizar erro e observar fetch por resultado/worker; URL
  completa fica fora de tags.
- Para bot schedules, usar contadores por `operation`/`result` e
  `measurement=messages_sent`, nao por schedule id.
- Para anexos, `bytes_deleted` e exportado como counter.

## Fronteiras runtime que nao viram Oban

Esta secao nao e uma lista de trabalho pendente. Ela define fronteiras para evitar
gambiarra e codigo morto. Esses pontos usam timers reais hoje, mas dependem de
processo vivo, socket, protocolo ou UX imediata.

- `apps/retro_hex_chat/lib/retro_hex_chat/services/nick_serv.ex`: identify timeout
  e estado identificado sao runtime de sessao/seguranca.
- `apps/retro_hex_chat/lib/retro_hex_chat/bots/loader.ex`: boot task que inicia
  processos long-lived de bot; Oban nao deve hospedar processos long-running.
- `apps/retro_hex_chat/lib/retro_hex_chat/bots/capabilities/rss.ex`: `Task.async/1`
  e `Task.async_stream/3` sao trabalho interno do worker RSS, usado para parsing e
  fetch paralelo dentro da execucao ja duravel.
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/reconnect_state.ex` e
  `apps/retro_hex_chat/lib/retro_hex_chat/chat/schemas/reconnect_state.ex`: save,
  load e delete sao persistencia sincronica do fluxo de reconnect; nao ha timer,
  Task ou regra de expiracao codificada para migrar.
- `apps/retro_hex_chat/lib/retro_hex_chat/presence/whowas_cache.ex`: ETS cache
  efemero com capacidade maxima e cleanup local.
- `apps/retro_hex_chat/lib/retro_hex_chat/lobby/session_server.ex`: timers de
  pending/lobby/rejoin/game request sao UX e estado vivo; Oban entra apenas como
  stale cleanup persistido.
- `apps/retro_hex_chat/lib/retro_hex_chat/arcade/solo_session_server.ex`: timers
  de pending/lobby sao UX e estado vivo; Oban entra apenas como stale cleanup.
- `apps/retro_hex_chat/lib/retro_hex_chat/group_call/room_server.ex`: ready,
  reconnect e peerless timeouts pertencem ao processo da sala; Oban entra apenas
  como stale cleanup persistido.
- `apps/retro_hex_chat/lib/retro_hex_chat/virtual_space/channel_space_server.ex`:
  KO/getup e movimento sao simulacao runtime.
- `apps/retro_hex_chat/lib/retro_hex_chat/p2p/turn/allocation_handler.ex` e
  `apps/retro_hex_chat/lib/retro_hex_chat/p2p/turn/listener.ex`: protocolo TURN e
  sockets vivos nao sao jobs.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/timer_handlers.ex`:
  perform/autojoin/rejoin/paste pacing e `/timer` executam comandos dentro da
  LiveView do usuario.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/ui_actions/scripting.ex`:
  criacao e disparo de `/timer` pertencem ao processo LiveView da sessao.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/session.ex`:
  ignore timers, notify debounce e rejoin inicial sao timers locais de sessao; o
  fetch de link preview neste arquivo esta mapeado em "Link preview fetch para URL
  Catcher".
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/messages.ex`:
  typing indicator e estado visual local.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/presence.ex`:
  expiracao visual de invite recebido e estado local da janela.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/p2p_session_events.ex`:
  retry de reattach P2P depende do estado vivo da LiveView e do processo de sessao.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/system_metrics_dialog.ex`:
  refresh visual da janela de metricas.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/system_metrics/collector.ex`:
  collector temporario por janela aberta, com ciclo de vida acoplado ao LiveView
  que pediu as series.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/p2p_media_island.ex`:
  timeout visual de reacao de chamada.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/paste_confirm_dialog.ex`:
  replay inicial do paste dialog e pacing local de UI.

## Remocoes obrigatorias durante a implementacao

- Remover filhos antigos da supervision tree quando o worker Oban substituir o
  fluxo.
- Remover `Task.start/1` e `Task.Supervisor.async_nolink/2` dos fluxos migrados.
- Remover callbacks de timer que ficarem sem consumidor.
- Remover modulos GenServer transformados em workers quando nao houver mais API
  publica real.
- Atualizar testes que hoje chamam `run_now/1` para chamar dominio/worker.
- Atualizar help/admin docs que descrevem Oban como "RSS only".

## Ajustes finais para 100% do padrao ouro

Estes itens foram derivados da auditoria pos-implementacao da padronizacao Oban.
Eles nao adicionam novos fluxos migraveis; fecham incoerencias, leitura fina de
observabilidade e regras de boundary que ficaram como ressalvas depois do deploy
inicial.

### Link preview retry transitorio vs falha final

Status: implementado em 2026-08-06.

Arquivos atuais:

- `apps/retro_hex_chat/lib/retro_hex_chat/chat/link_preview/result.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/link_preview/results.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/link_preview_fetch_worker.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/oban_health.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/system/oban_panel.ex`
- `apps/retro_hex_chat/test/retro_hex_chat/jobs/oban_health_test.exs`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/system_windows_feature_test.exs`

Problema confirmado:

- O worker ja diferencia retry HTTP transitorio de falha final, mas a janela admin
  agregava `link_previews` apenas por `pending`, `ready` e `failed`.
- Administradores conseguiam ver backlog de jobs recentes pelo filtro generico,
  mas a tabela especifica de link preview nao deixava explicito se um `pending`
  estava aguardando primeira tentativa ou retry transitorio.
- Falhas finais esperadas, como `404` ou pagina sem titulo, nao devem parecer
  falha operacional da plataforma.

Implementacao necessaria:

- Enriquecer `LinkPreview.Results.stats/1` com contadores de `retrying` e
  `final_failures` sem expor URL, host ou erro arbitrario como label.
- Propagar os novos campos para `ObanHealth.Snapshot.summary` e para a tabela
  `Link preview cache`.
- Manter falha final deterministica como dado operacional da tabela, sem elevar
  automaticamente a saude global.
- Elevar apenas retry transitorio em andamento como motivo de warning na saude
  da janela.

Observabilidade:

- `pending` total;
- `retrying` transitorio dentro de `pending`;
- `final_failures` dentro de `failed`;
- expirados;
- tentativa mais antiga;
- fetch mais recente.

### Boundary Oban no nuke administrativo

Status: implementado em 2026-08-06.

Arquivos atuais:

- `apps/retro_hex_chat/lib/retro_hex_chat/admin.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/jobs.ex`
- `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/admin/nuke_test.exs`

Problema confirmado:

- `RetroHexChat.Admin` conhecia `Oban.Job` diretamente no reset administrativo
  para contar e deletar `oban_jobs`.
- O uso nao era enqueue/cancelamento operacional, mas feria literalmente o
  contrato de que acesso a Oban deve passar por `RetroHexChat.Jobs` ou pela
  leitura operacional de `ObanHealth`.

Implementacao necessaria:

- Criar funcoes administrativas explicitas em `RetroHexChat.Jobs` para contar e
  deletar todos os jobs durante reset total.
- Trocar o alvo `oban_jobs` do nuke para um identificador interno, sem alias direto
  para `Oban.Job` em `RetroHexChat.Admin`.
- Preservar o comportamento existente de preview, transaction summary e testes de
  delecao de jobs.

Sem codigo morto:

- Nao criar wrapper generico de queries Oban fora de necessidade real.
- Nao expor API publica para mutacoes arbitrarias de Oban; apenas o contrato de
  reset administrativo.

### Baixa cardinalidade de erro Oban no PromEx

Status: implementado em 2026-08-06.

Arquivos atuais:

- `apps/retro_hex_chat/lib/retro_hex_chat/prom_ex/plugins/oban.ex`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/prom_ex_test.exs`

Problema confirmado:

- `PromEx.Plugins.Oban` normalizava worker/fila/estado, mas aceitava `reason`
  binario como tag `error` em evento de exception.
- Em caso de erro binario contendo URL, mensagem de banco, args ou texto externo,
  isso poderia criar cardinalidade alta no Prometheus.

Implementacao necessaria:

- Manter atomos e modulos de exception como labels estaveis.
- Permitir apenas strings whitelisted ou padroes HTTP transitorios finitos como
  `http_408`, `http_425`, `http_429` e `http_5xx`.
- Bucketizar qualquer outro binario em `binary_error`.
- Cobrir esse contrato em teste unitario do plugin.

### Linguagem multi-contrato da janela Oban

Status: implementado em 2026-08-06.

Arquivos atuais:

- `apps/retro_hex_chat/lib/retro_hex_chat/jobs/oban_health.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/system/oban_panel.ex`
- `docs/plans/oban-observability-standardization.md`
- `docs/plans/oban-observability-standardization-PROGRESS.md`

Problema confirmado:

- A implementacao funcional ja e multi-contrato, mas alguns textos internos ainda
  carregavam linguagem RSS-centrica.
- O arquivo de progresso mantinha linhas antigas de divida que foram resolvidas
  na consolidacao final da janela admin.

Implementacao necessaria:

- Atualizar moduledocs/mensagens healthy para refletir contratos duraveis, nao
  apenas RSS.
- Reconciliar plano e progresso para que dividas antigas nao parecam pendencias
  reais.
- Preservar a documentacao historica das iteracoes, mas registrar explicitamente
  quando uma divida antiga foi fechada por uma iteracao posterior.

## Validacao de pronto

A padronizacao completa so esta pronta quando:

- todas as filas estao configuradas em `config/config.exs` e `config/runtime.exs`;
- `Oban.Plugins.Cron` cobre sweeps globais;
- jobs por entidade usam self-scheduling e contrato de sucessor;
- nenhum fluxo migrado ainda usa timer local ou Task fire-and-forget;
- a janela admin mostra todos os contratos;
- PromEx exporta metricas genericas e de dominio;
- os testes cobrem worker, dominio, cancelamento, retry/cancel e painel admin;
- testes de worker usam `Oban.Testing` ou chamada direta de `perform/1`, mantendo
  `config/test.exs` sem queues/plugins rodando em background;
- `make ci` passa no commit final;
- deploy usa o pipeline padrao do projeto.
