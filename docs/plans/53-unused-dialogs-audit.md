# Unused Dialogs Audit

## Objetivo

Auditar dialogs em `components/ui/dialogs` que nao aparecem diretamente no `chat_live.html.heex`, para evitar perda de cobertura durante a migracao.

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


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
