# Shell Header, Menu And Status Migration

## Objetivo

Extrair header, menu bar e status bar para um componente stateful leve que consome apenas dados globais e emite acoes de alto nivel.

## Classificação para execução (agentes)

- **Tier:** 🟡 Com ressalva
- **Dependências:** Independente, mas toca o dispatcher `toolbar_action`.
- **Componente de referência:** Wrapper function-component (`ChatShell`); stateful só se guardar menu/hover/lag local.
- **Abordagem:** Começar como wrapper que reduz assigns no template; só virar stateful se necessário.
- **Gotchas:** `toolbar_action` é re-dispatchado via `@event_hook_fns` — preserve o contrato.
- **Validação:** `make ci` 9/9 + E2E chat-menu-* / chat-tools-menu.

## Codigo atual

- Imports: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.ex:20`
- Render no template: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:34`
- Componentes: `components/ui/shell/app_header.ex`, `components/ui/shell/menu_bar_app.ex`, `components/ui/shell/status_bar_app.ex`
- Toolbar dispatcher: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.ex:281`

## Tecnica

Use `LiveComponent` stateful se o shell passar a guardar estado de menu aberto, hover, lag local ou responsividade. Caso contrario, crie um wrapper function component `ChatShell` que reduz o numero de assigns no template principal.

## Tasks

- [ ] Criar `ChatShellComponent` ou `ChatShell`.
- [ ] Passar `nickname`, `account_state`, `active_target`, `lag`, `muted`, `online_buddy_count`, `admin?`.
- [ ] Emitir comandos semanticos: `:open_account`, `:toggle_away`, `:toggle_notify`, `:toggle_mute`, `{:toolbar, action}`.
- [ ] Remover calculos `admin?(@session)`, `Session.identity_state/1` e `online_buddy_count/1` do template principal.
- [ ] Manter `MenuBarHook` onde ele for necessario, preferencialmente dentro do shell.

## Validacao

- [ ] Header nao re-renderiza por nova mensagem de chat.
- [ ] Status bar muda ao trocar canal/PM, away, mute e lag.
- [ ] Toolbar continua acionando todos os comandos.
- [ ] Testes de menu e toolbar passam.

## Prompt de execucao

Nao otimize prematuramente o shell. O valor principal e tirar calculos e imports do parent e evitar que mensagens invalidem o header inteiro.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
