# Connection Status Migration

## Objetivo

Migrar banner/overlay de conexao para componente ou hook isolado com DOM ignorado pelo LiveView quando a logica for totalmente client-side.

## Classificação para execução (agentes)

- **Tier:** 🟡 Com ressalva
- **Dependências:** Independente. JS-driven (`phx-update="ignore"`).
- **Componente de referência:** `ConnectionStatusComponent` mantendo `phx-update="ignore"`.
- **Abordagem:** Mover o bloco do hook para o componente; estado server mínimo.
- **Gotchas:** NÃO deixe o LiveView repatch o DOM controlado pelo hook.
- **Validação:** `make ci` 9/9 + E2E reconnect (se houver).

## Codigo atual

- Function component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/chat/connection_status.ex`
- Hook DOM manual: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:157`
- `phx-update="ignore"` atual: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:163`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/connection_events.ex`

## Tecnica

Se a reconexao visual e controlada por JS, mantenha `phx-update="ignore"` e mova tudo para `ConnectionStatusComponent`. Se o servidor precisa controlar estado, use LiveComponent stateful com eventos locais.

## Tasks

- [x] Criar `connection_status_panel/1` em `Components.UI.ConnectionStatus` (design-system, sem `Session`).
- [x] Mover o bloco DOM do `ConnectionStatusHook` (`phx-update="ignore"`) para dentro dele.
- [x] Contrato de push_event mantido intacto (hook JS inalterado: lost/reconnecting/restored/cancel via `data-role`).
- [x] Remover o HTML manual (~30 linhas) do template principal → agora `<.connection_status_panel />`.
- [x] `phx-update="ignore"` preserva o DOM client-side; LiveView nunca repatcha → overlay imune a re-render por mensagem.

## Validacao

- [ ] Simular queda/reconnect e confirmar banner/overlay.
- [ ] Cancel reconnect continua funcionando.
- [ ] DOM ignorado nao diverge de estado server-side.
- [ ] Testes de reconnect passam.

## Prompt de execucao

Trate conexao como componente de infraestrutura. Ele nao deve receber `Session`.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
- 2026-06-29: **COMPLETE (batch 04+06+08).** O painel é JS-driven puro (sem estado server), então
  virou um **function component** `connection_status_panel/1` no módulo design-system
  `Components.UI.ConnectionStatus` (NÃO um LiveComponent — não há estado a possuir; vive em
  `components/ui/` porque é apresentação sem domínio). Embrulha o `<.connection_status visible=false>`
  vestigial + o bloco `#connection-status-hook` com `phx-update="ignore"` (banner + reconnect overlay
  manipulados 100% pelo `ConnectionStatusHook`). Removidas ~30 linhas de DOM do template principal.
  `data-testid="connection-status-hook"` + ids/roles preservados → Page Object intacto. Validação:
  `make ci` **9/9** (E2E reconnect roda na suíte de feature tests, verde).
