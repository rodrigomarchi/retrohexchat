# Lookup Result Card Migration

## Objetivo

Migrar card de resultado de lookup para componente dedicado, preferencialmente filho do UserLookupComponent.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:893`
- Function component no mesmo arquivo: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/user_lookup_dialog.ex`
- State atual: `lookup_result`.

## Tecnica

Use function component se resultado e apenas render. Use LiveComponent filho se ele tiver acoes locais ou async secundario. O estado `lookup_result` deve sair do parent.

## Tasks

- [ ] Mover `lookup_result` para UserLookupDialogComponent.
- [ ] Separar `LookupResultCard` em modulo proprio se crescer.
- [ ] Passar result normalizado com `kind`, `nickname`, `rows`, `online`.
- [ ] Emitir `whois`, `whowas`, `query` para o componente pai.

## Validacao

- [ ] Resultados whois e whowas renderizam rows.
- [ ] Botoes condicionais respeitam `kind` e `online`.
- [ ] Fechar limpa resultado sem afetar chat.

## Prompt de execucao

Resultado de lookup pertence ao fluxo de lookup, nao ao estado global do chat.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
