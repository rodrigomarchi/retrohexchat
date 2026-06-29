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

- [ ] Criar `AdminConsoleDialogComponent`.
- [ ] Mover todos os `admin_console_*` para o componente.
- [ ] Criar subcomponentes ou modulos por tab: server_settings, users, channels, motd, broadcast, audit_log, turn, danger_zone, console.
- [ ] Lazy load da tab ativa.
- [ ] Async para refresh users/channels/audit/turn/settings.
- [ ] Limitar `results` e outputs textuais.
- [ ] Centralizar checagem de permissoes no parent/contexto, mas passar snapshot ao componente.
- [ ] Remover `admin_console_events.ex` da pipeline global quando migrado.

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
