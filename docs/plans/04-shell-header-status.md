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

- [x] Criar `ChatShell` (glue function component em `chat_live/components/`) + `ChatAppHeader` (chrome em `components/ui/shell/`).
- [x] Passar `nickname`, `account_state`, `active_target`, `lag`, `muted`, `online_buddy_count`, `is_admin` como primitivos para o chrome.
- [x] Emitir comandos semanticos via attr defaults (`on_account_click`/`on_away_toggle`/`on_notify_toggle`/`on_mute_toggle`/`on_toolbar_action`/`on_logo_action`) — contratos legados preservados.
- [x] Remover calculos `admin?(@session)`, `Session.identity_state/1` e `online_buddy_count/1` do template principal (movidos p/ o `ChatShell`).
- [x] Manter `MenuBarHook` (`id="menubar" phx-hook="MenuBarHook"`) dentro do chrome do shell.

## Validacao

- [ ] Header nao re-renderiza por nova mensagem de chat.
- [ ] Status bar muda ao trocar canal/PM, away, mute e lag.
- [ ] Toolbar continua acionando todos os comandos.
- [ ] Testes de menu e toolbar passam.

## Prompt de execucao

Nao otimize prematuramente o shell. O valor principal e tirar calculos e imports do parent e evitar que mensagens invalidem o header inteiro.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
- 2026-06-29: **COMPLETE (batch 04+06+08).** Two-piece split por causa do layering + lint §1d:
  `Components.ChatShell.chat_shell_header/1` (em `chat_live/components/`, scanned) deriva
  `account_state`/`is_admin`/`online_buddy_count`/`channel`/`tab_type` do `Session` e delega o
  markup ao novo `Components.UI.ChatAppHeader.chat_app_header/1` (em `components/ui/shell/`, design
  system puro — recebe só primitivos + nomes de evento, dono do `ml-auto` que reposiciona a status
  bar). Removidos do parent: imports `AppHeader`/`MenuBarApp`/`StatusBarApp` + `Dialog show_modal`
  + o helper privado `online_buddy_count/1`; o template chama `<.chat_shell_header session=… />`.
  **Por que o split:** colocar o markup com `ml-auto` direto no glue scanned quebrou o
  `lint.css_consistency` (Tailwind cru fora de `components/ui/`); mover o chrome p/ `components/ui/`
  é o padrão `nicklist_sidebar`/`conversations_sidebar`. Validação: `make ci` **9/9**;
  `chat_shell_test.exs` (4, `@moduletag :unit`). Sem mudança de contrato → Page Object intacto.
