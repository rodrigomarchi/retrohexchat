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

- [ ] Criar `ConnectionStatusComponent`.
- [ ] Mover hook `ConnectionStatusHook` para dentro dele.
- [ ] Definir contrato de push_event para lost/reconnecting/restored/cancel.
- [ ] Remover HTML manual do template principal.
- [ ] Garantir que overlay nao re-renderiza por mensagens.

## Validacao

- [ ] Simular queda/reconnect e confirmar banner/overlay.
- [ ] Cancel reconnect continua funcionando.
- [ ] DOM ignorado nao diverge de estado server-side.
- [ ] Testes de reconnect passam.

## Prompt de execucao

Trate conexao como componente de infraestrutura. Ele nao deve receber `Session`.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
