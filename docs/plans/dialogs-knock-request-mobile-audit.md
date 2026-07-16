# Knock Request Dialog Mobile-First Audit

Data: 2026-07-16

## Escopo

Aplicacao do `Dialog Mobile Playbook` no Knock Request Dialog, aberto pela Channel List quando um usuario tenta pedir acesso a um canal invite-only.

O objetivo foi melhorar mobile e desktop com uma unica interface compacta, preservando `knock-request-message`, `knock-request-submit`, `knock_request_change`, `knock_request_submit` e `knock_request_cancel`.

Arquivos principais:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/knock_request_dialog.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/knock_request_dialog.ex`
- `apps/retro_hex_chat_web/assets/css/retrohex.css`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/knock_request_dialog_test.exs`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/channel_membership_feature_test.exs`

## Baseline

Nao ha showcase dedicado para Knock Request. A auditoria foi feita pelo fluxo real: usuario cria canal invite-only, outro usuario abre `/list`, seleciona o canal e clica em `Request Access...`.

Screenshots baseline:

- `docs/plans/screenshots/knock-request-dialog-audit/desktop-empty.png`
- `docs/plans/screenshots/knock-request-dialog-audit/desktop-filled.png`
- `docs/plans/screenshots/knock-request-dialog-audit/desktop-too-long.png`
- `docs/plans/screenshots/knock-request-dialog-audit/mobile-empty.png`
- `docs/plans/screenshots/knock-request-dialog-audit/mobile-filled.png`
- `docs/plans/screenshots/knock-request-dialog-audit/mobile-too-long.png`

Achados principais:

- Mobile usava fullscreen para um form curto, deixando grande area vazia.
- Canal aparecia como linha de texto simples, sem hierarquia de alvo.
- Desktop era funcional, mas seco: canal, campo, contador e acoes competiam no mesmo bloco.
- Estado `205 / 200` funcionava, mas precisava de melhor agrupamento visual com o campo.
- A auditoria visual nao deve depender de sidebar/menu visivel; em mobile esses elementos podem estar ocultos por design.

## Implementacao

Decisao: transformar o dialog em form compacto `kr-*`, com target card, textarea estavel, contador local e acoes a direita.

Mudancas:

- `KnockRequestDialog` usa `kr-dialog-wrap` para sair do fullscreen mobile.
- Canal virou `kr-channel-card`, com icone, label `Channel` e valor quebravel.
- Textarea ganhou `kr-message-input`, mantendo `data-testid="knock-request-message"`.
- Contador ganhou `kr-counter` e estado `kr-counter--error`.
- Erro usa `kr-error`, dentro do mesmo grupo do campo.
- Send Request/Cancel usam `kr-action-row` e `kr-action-button`, sempre alinhados a direita.
- Testes foram ajustados para validar a hierarquia atual sem depender do texto antigo `Channel: #canal`.
- Audit spec passou a abrir a Channel List por `/list`, caminho real e estavel em desktop/mobile.

## Resultado Visual

Screenshots refinados:

- `docs/plans/screenshots/knock-request-dialog-refined/desktop-empty.png`
- `docs/plans/screenshots/knock-request-dialog-refined/desktop-filled.png`
- `docs/plans/screenshots/knock-request-dialog-refined/desktop-too-long.png`
- `docs/plans/screenshots/knock-request-dialog-refined/mobile-empty.png`
- `docs/plans/screenshots/knock-request-dialog-refined/mobile-filled.png`
- `docs/plans/screenshots/knock-request-dialog-refined/mobile-too-long.png`

Melhorias observadas:

- Mobile preserva o contexto do chat em vez de cobrir a tela inteira.
- Desktop ganhou uma hierarquia mais clara sem perder densidade.
- Canal alvo ficou escaneavel e resistente a nomes longos.
- Contador e erro ficam colados ao campo que controlam.
- Estado acima do limite mantem o submit desabilitado e comunica o problema visualmente.

## Validacao

Comandos executados:

```bash
rtk npm --prefix e2e test -- --project=chromium tests/knock-request-dialog-audit.spec.ts --reporter=list
rtk mix format apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/knock_request_dialog.ex apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/knock_request_dialog_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/channel_membership_feature_test.exs
rtk mix compile
# em apps/retro_hex_chat_web
rtk mix assets.build
KNOCK_REQUEST_DIALOG_AUDIT_OUT_DIR=knock-request-dialog-refined rtk npm --prefix e2e test -- --project=chromium tests/knock-request-dialog-audit.spec.ts --reporter=list
rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/knock_request_dialog_test.exs --trace
rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/channel_membership_feature_test.exs --include liveview_feature --trace
rtk npm --prefix e2e test -- --project=chromium tests/chat-ui-features-channel.spec.ts --reporter=list
rtk npm --prefix e2e test -- --project=chromium tests/chat-channel-knock.spec.ts --reporter=list
rtk npm --prefix e2e test -- --project=chromium tests/chat-channel-list.spec.ts --reporter=list
```

Resultados:

- Captura visual baseline: passou apos estabilizar o spec temporario.
- `mix format`: passou.
- `mix compile`: passou.
- `assets.build`: passou.
- Captura visual refinada: passou em desktop/mobile.
- `KnockRequestDialogTest`: `5 tests, 0 failures`.
- `ChannelMembershipFeatureTest` com `:liveview_feature`: `9 tests, 0 failures`.
- `chat-ui-features-channel.spec.ts`: `4 passed`.
- `chat-channel-knock.spec.ts`: `2 passed`.
- `chat-channel-list.spec.ts`: `1 passed`.

## Aprendizados

- Fluxo real e melhor que showcase para Knock Request, porque o dialog depende da Channel List e do estado invite-only.
- Audits mobile nao devem depender de sidebar ou menu visivel; `/list` abriu o mesmo dialog com menos fragilidade.
- Target card funciona tambem para canal, nao so para nick/user.
- Contador de limite precisa ficar visualmente subordinado ao textarea, nao ao rodape.
- Form curto com textarea pode ser compacto no mobile, desde que a textarea tenha altura previsivel e o footer continue touch-safe.
