# Mute Duration Dialog Mobile-First Audit

Data: 2026-07-16

## Escopo

Aplicacao do `Dialog Mobile Playbook` no Mute Duration Dialog, prompt curto aberto pelo nicklist/context menu para definir duracao opcional de mute de canal.

O objetivo foi melhorar mobile e desktop com uma unica interface compacta, preservando `mute-duration-input`, submit/cancel e o fluxo real de mutar/desmutar usuario.

Arquivos principais:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/mute_duration_dialog.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/mute_duration_dialog.ex`
- `apps/retro_hex_chat_web/assets/css/retrohex.css`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/mute_duration_dialog_test.exs`

## Baseline

Nao ha showcase dedicado para Mute Duration. A auditoria foi feita pelo fluxo real de nicklist/context menu em desktop e mobile.

Screenshots baseline:

- `docs/plans/screenshots/mute-duration-dialog-audit/desktop-default.png`
- `docs/plans/screenshots/mute-duration-dialog-audit/desktop-filled.png`
- `docs/plans/screenshots/mute-duration-dialog-audit/mobile-default.png`
- `docs/plans/screenshots/mute-duration-dialog-audit/mobile-filled.png`

Achados principais:

- Mobile usava fullscreen para um prompt de uma linha, com grande area vazia.
- Titlebar carregava o nick alvo; em mobile, nick longo competia com o titulo e podia truncar informacao importante.
- O alvo do mute nao tinha bloco proprio; a informacao estava apenas no titulo.
- Desktop era funcional, mas podia ficar mais claro com target, campo e hint separados.

## Implementacao

Decisao: transformar o prompt em form compacto com classes locais `mud-*`, mantendo campo de duracao touch-safe e acoes a direita.

Mudancas:

- `MuteDurationDialog` usa `mud-dialog-wrap` para sair do fullscreen mobile.
- Titlebar ficou estavel: `Mute User`.
- Nick alvo virou `mud-target-card`, com icone, label `Muting` e valor quebravel.
- Campo de duracao usa `mud-duration-input`, com altura/fonte segura.
- Hint de formato usa `mud-help-text`.
- OK/Cancel usam `mud-action-row` e `mud-action-button`, alinhados a direita.
- Teste unitario passou a validar titulo, target, input e evento de cancelamento.

## Resultado Visual

Screenshots refinados:

- `docs/plans/screenshots/mute-duration-dialog-refined/desktop-default.png`
- `docs/plans/screenshots/mute-duration-dialog-refined/desktop-filled.png`
- `docs/plans/screenshots/mute-duration-dialog-refined/mobile-default.png`
- `docs/plans/screenshots/mute-duration-dialog-refined/mobile-filled.png`

Melhorias observadas:

- Mobile preserva o contexto do chat/nicklist em vez de ocupar a tela inteira.
- Desktop ficou mais claro sem perder densidade.
- Nick alvo aparece como dado do form, nao como titulo truncavel.
- Campo, hint e acoes mantem alinhamento previsivel em desktop e mobile.

## Validacao

Comandos executados:

```bash
rtk npm --prefix e2e test -- --project=chromium tests/mute-duration-dialog-audit.spec.ts --reporter=list
rtk mix format apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/mute_duration_dialog.ex apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/mute_duration_dialog_test.exs
rtk mix compile
# em apps/retro_hex_chat_web
rtk mix assets.build
rtk env MUTE_DURATION_DIALOG_AUDIT_OUT_DIR=mute-duration-dialog-refined npm --prefix e2e test -- --project=chromium tests/mute-duration-dialog-audit.spec.ts --reporter=list
rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/mute_duration_dialog_test.exs --trace
rtk npm --prefix e2e test -- --project=chromium tests/chat-ui-features-channel.spec.ts --reporter=list
```

Resultados:

- Captura visual baseline: passou.
- `mix format`: passou.
- `mix compile`: passou.
- `assets.build`: passou.
- Captura visual refinada: passou, incluindo X real no fluxo desktop/mobile.
- `MuteDurationDialogTest`: `3 tests, 0 failures`.
- `chat-ui-features-channel.spec.ts`: `4 passed`.

## Aprendizados

- Quando nao ha showcase, a auditoria precisa usar fluxo real. Para Mute Duration, isso inclui context menu desktop e long press mobile.
- Titlebar nao deve carregar dado dinamico longo quando esse dado pode virar um bloco proprio no body.
- Prompt de duracao curta pode ser compacto no mobile mesmo com input textual, desde que o campo seja touch-safe.
- Validar estado preenchido e importante porque o placeholder pode parecer valor visualmente.
