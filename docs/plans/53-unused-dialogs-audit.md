# Unused Dialogs Audit

## Objetivo

Auditar dialogs em `components/ui/dialogs` que nao aparecem diretamente no `chat_live.html.heex`, para evitar perda de cobertura durante a migracao.

## Classificação para execução (agentes)

- **Tier:** 🧹 Auditoria/limpeza
- **Dependências:** Independente. NÃO é migração.
- **Componente de referência:** —
- **Abordagem:** Classificar channel_dialog.ex, confirm_dialog.ex (showcase? legado? base reutilizável?). Base genérica fica function component.
- **Gotchas:** Não migrar por impulso; criar plano só se houver estado real num fluxo.
- **Validação:** `make ci` 9/9.

## Codigo atual

- Dialogs renderizados no chat: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:485`
- Catalogo de dialogs: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs`
- Dialogs existentes mas nao renderizados diretamente no chat template atual:
  - `channel_dialog.ex`
  - `confirm_dialog.ex`

## Tecnica

Nao migrar por impulso. Primeiro classificar: usado por showcase, legado, componente base reutilizavel ou futuro fluxo de chat. Se for base generica, manter como function component. Se tiver estado real em algum fluxo, criar plano especifico quando esse fluxo entrar no escopo.

## Tasks

- [ ] Confirmar usos com `rg "channel_dialog|confirm_dialog"`.
- [ ] Marcar cada dialog como `chat-used`, `showcase-only`, `generic`, `dead`, ou `future`.
- [ ] Se `confirm_dialog` puder substituir confirmacoes simples, padronizar API antes de migrar.
- [ ] Se `channel_dialog` for legado, decidir remover ou manter apenas showcase.
- [ ] Atualizar este arquivo com decisao final.

## Validacao

- [ ] Nenhum dialog usado em producao fica sem plano.
- [ ] Componentes showcase-only continuam compilando.
- [ ] Nao ha duplicacao desnecessaria entre confirm dialogs.

## Prompt de execucao

Audite antes de alterar. O objetivo e nao perder componente, mas tambem nao migrar componente morto.


## Decisão final (auditoria 2026-06-29)

| Dialog | Classificação | Evidência |
|--------|---------------|-----------|
| `channel_dialog.ex` | **showcase-only** | Único ref: `showcase_live/dialogs/channel_dialog_page.ex`. O chat usa `ChannelList` (`channel_list.ex`), não este. Não é morto (showcase compila), não migrar. |
| `confirm_dialog.ex` | **showcase-only / base genérica** | Único ref de produção: `showcase_live/dialogs/confirm_dialog_page.ex`. O chat usa dialogs de confirmação específicos (`delete_confirm_dialog`/`disconnect_confirm_dialog`/`paste_confirm_dialog`, todos já migrados p/ LiveComponent). Mantido como base/showcase; NÃO padronizar agora (os 3 confirmes já têm componentes próprios e testes). |

**Resultado: ZERO dialogs mortos.** Nenhum dialog usado em produção fica sem plano (todos os usados no chat já foram migrados). Nada a remover.

## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
- 2026-06-29: **COMPLETE (auditoria).** `channel_dialog.ex` e `confirm_dialog.ex` = **showcase-only**, não mortos, não usados no chat (o chat usa `ChannelList` + os confirm dialogs específicos já migrados). Zero remoções. `make ci` 9/9 (sem mudança de código de produção — apenas confirmação).
