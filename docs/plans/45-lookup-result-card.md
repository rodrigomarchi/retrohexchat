# Lookup Result Card Migration

## Objetivo

Migrar card de resultado de lookup para componente dedicado, preferencialmente filho do UserLookupComponent.

## Classificação para execução (agentes)

- **Tier:** ✅ Mecânico (parte de 44)
- **Dependências:** NÃO independente — migrar como parte do componente de 44.
- **Componente de referência:** Função dentro do UserLookupDialog.
- **Abordagem:** O card compartilha `lookup_result` com 44; vira render interno do componente de 44.
- **Gotchas:** Não criar componente separado; é um sub-render de 44.
- **Validação:** Junto com 44.

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
- 2026-06-29: **COMPLETE (junto com plano 44).** O `lookup_result_card` virou um sub-render DENTRO de `Components.UserLookupDialog` (não um módulo/componente separado — é só um `<.lookup_result_card>` no `render/1` do componente de 44). `lookup_result` é passthrough do parent (produzido pelo `/whois`/`/whowas`); os botões do card (`lookup_result_whois`/`whowas`/`query`/`close_lookup_result`) sobem pros adapters do parent. Ids preservados (`#lookup-result-dialog`, `data-testid="lookup-result-card"`) → Page Object intacto. Validação junto com 44.
