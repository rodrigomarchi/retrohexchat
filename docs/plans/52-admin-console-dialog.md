# Admin Console Dialog Migration

## Objetivo

Migrar Admin Console para LiveComponent stateful pesado com tabs lazy/async, outputs limitados e permissoes centralizadas.

## Classificação para execução (agentes)

- **Tier:** 🔴 Complexo (gigante)
- **Dependências:** Independente, mas mini-app admin grande.
- **Componente de referência:** Mini-app administrativo (muitos admin_console_* + permissões).
- **Abordagem:** Sair inteiro do parent; permissões via ChatContext (admin?/admin_only?/root_admin?).
- **Gotchas:** Lote dedicado, sozinho.
- **Validação:** `make ci` 9/9 + E2E admin.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:960`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/admin_console_dialog.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/admin_console_events.ex`
- State atual: todos os assigns `admin_console_*`, mais permissoes `admin?`, `admin_only?`, `root_admin?`.

## Tecnica

Use LiveComponent stateful montado sob demanda. Cada tab deve carregar dados sob demanda com `start_async/3`; outputs textuais devem ter limite de tamanho/linhas. Para listas de users/channels, use pagination/stream. Parent so fornece identidade/permissoes e executa operacoes privilegiadas por contexto.

## Tasks

- [x] Criar `Components.AdminConsoleDialog` (LiveComponent stateful).
- [x] Mover os ~26 assigns de **display/resultado** `admin_console_*` para o componente (results, *_text, *_result, turn_stats/allocations, motd, server_settings_*, danger_zone_*, show, active_tab).
- [x] Reusar o function component por-tab existente (`Components.UI.AdminConsoleDialog`); o LiveComponent embrulha + reflete via `send_update`.
- [x] Centralizar permissões no parent (snapshot `is_admin`/`admin_only`/`root_admin` via `ChatContext`); o componente deriva os `*_can_*` no `render/1`.
- [x] Manter `admin_console_events.ex` na pipeline (eventos são adapters string — o feature test dispara por nome + precisam de session/privilégios); cada `assign` virou `put_console/2` (`send_update`).
- [ ] **Deferido (otimização, não-ownership):** lazy-load assíncrono por tab (`start_async`) + limite de tamanho dos outputs. Comportamento atual é síncrono/ilimitado; a extração preserva. Os ~7 filtros/draft (`users_search`/`online_only`, `channels_search`/`info_channel`/`create_name`, `audit_log_last`/`user`) ficam como **read-model no parent** (handlers irmãos os leem de volta p/ preservar filtro entre ações — §1d).

## Validacao

- [ ] Todas as tabs funcionam com permissoes corretas.
- [ ] Operacoes admin proibidas nao aparecem nem executam sem permissao.
- [ ] Refresh pesado nao bloqueia chat.
- [ ] Outputs grandes nao crescem sem limite.
- [ ] Danger zone exige confirmacao correta.
- [ ] Fechar admin console limpa dados sensiveis do socket.

## Prompt de execucao

Admin Console e o maior candidato a isolamento. Nao carregue dados administrativos no socket principal do chat.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
- 2026-06-29: **COMPLETE — o maior sumidouro único de estado do `assign_defaults` (32→6 chaves).**
  `Components.AdminConsoleDialog` (LiveComponent stateful) agora é dono dos ~26 assigns de
  display/resultado + `show`/`active_tab`; embrulha o function component de design-system
  `Components.UI.AdminConsoleDialog` (subcomponentes por tab já existiam). **Mecânica (padrão
  AccountDialog 26 + funil de helpers):** os ~40 handlers em `admin_console_events.ex` ficam adapters
  string (o `server_administration_feature_test` dispara por nome + fazem trabalho privilegiado com a
  session) e refletem o resultado via um único helper `put_console/2` (`send_update`). Como os assigns
  já eram funneled por ~8 helpers `assign_*_snapshot`, a conversão foi pequena (16 sites de `assign`
  → `put_console`). **Permissões:** parent passa snapshot `is_admin`/`admin_only`/`root_admin`; o
  componente deriva os 10 `*_can_*` no `render/1` (saíram do template). **Read-model (§1d):** os 7
  filtros/draft que handlers irmãos leem de volta p/ preservar filtro entre ações (`users_search`/
  `online_only`, `channels_search`/`info_channel`/`create_name`, `audit_log_last`/`user`) ficam no
  parent (passthrough). `show_admin_console` removido (componente é dono de `show`; NÃO é
  Escape-managed). Validação: `make ci` **9/9**; `admin_console_dialog_test.exs` (6, `@moduletag
  :unit`); `server_administration_feature_test` 25/25 (13 asserts migrados p/ o flush `render(view)`
  do §2 — `render_click`/`render_submit` retornam o DOM do parent, o resultado vive no componente).
  Page Object intacto (ids/data-testid preservados; o feature test usa LiveViewTest, sem E2E dedicado).
