# Confirm/Paste Confirm Mobile-First Audit

Data: 2026-07-16

## Escopo

Aplicacao do `Dialog Mobile Playbook` nos confirms pequenos, inaugurando o padrao para dialogs de decisao curta. O foco foi compactar mobile sem perder clareza no desktop, preservar eventos/test ids e evitar que prompts de uma ou duas frases ocupem uma tela inteira.

Componentes cobertos:

- `ConfirmDialog`
- `DeleteConfirmDialog`
- `DisconnectConfirmDialog`
- `PasteConfirmDialog`

Arquivos principais:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/confirm_dialog.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/delete_confirm_dialog.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/disconnect_confirm_dialog.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/paste_confirm_dialog.ex`
- `apps/retro_hex_chat_web/assets/css/retrohex.css`
- `e2e/tests/chat-message-edit-delete-edges.spec.ts`

## Baseline

Foi criado um spec temporario de Playwright para capturar generic confirm, Paste standard, Paste flood warning, Delete Message e Disconnect em desktop e mobile. Generic/Paste flood vieram do showcase; Paste standard/Delete/Disconnect vieram do chat real.

Screenshots baseline:

- `docs/plans/screenshots/confirm-dialogs-audit/desktop-generic-confirm.png`
- `docs/plans/screenshots/confirm-dialogs-audit/desktop-paste-standard.png`
- `docs/plans/screenshots/confirm-dialogs-audit/desktop-paste-flood.png`
- `docs/plans/screenshots/confirm-dialogs-audit/desktop-delete-message.png`
- `docs/plans/screenshots/confirm-dialogs-audit/desktop-disconnect.png`
- `docs/plans/screenshots/confirm-dialogs-audit/mobile-generic-confirm.png`
- `docs/plans/screenshots/confirm-dialogs-audit/mobile-paste-standard.png`
- `docs/plans/screenshots/confirm-dialogs-audit/mobile-paste-flood.png`
- `docs/plans/screenshots/confirm-dialogs-audit/mobile-delete-message.png`
- `docs/plans/screenshots/confirm-dialogs-audit/mobile-disconnect.png`

Achados principais:

- Mobile usava a superficie fullscreen do modal global, gerando um prompt pequeno no topo e uma grande area vazia ate o footer.
- Desktop era compacto, mas a mensagem ficava solta e sem agrupamento visual de risco/acao.
- Paste flood no showcase mostrava risco de largura insegura no viewport mobile.
- Delete/Disconnect dependiam de texto corrido; o risco e a consequencia ficavam menos escaneaveis.
- O X do titlebar escondia visualmente alguns dialogs stateful sem acionar o mesmo cancelamento do botao Cancel.

## Implementacao

Decisao: nao alterar o modal global. Os confirms pequenos optam por `cd-dialog-wrap`, que sobrescreve localmente a superficie para ser compacta, largura segura e orientada a message box.

Mudancas:

- `ConfirmDialog`, `DeleteConfirmDialog`, `DisconnectConfirmDialog` e `PasteConfirmDialog` usam `class="cd-dialog-wrap"`.
- Corpos usam `cd-message-row`: icone em bloco + texto/notas ao lado.
- Footer usa `cd-dialog-footer` e botoes `cd-dialog-action`, sempre alinhados a direita e com wrap.
- Paste ganhou resumo em bloco e nota curta sobre envio em lote.
- Paste flood ganhou `cd-callout` para destacar warning sem estourar largura.
- Delete separa pergunta e consequencia (`This action cannot be undone.`).
- Disconnect separa pergunta e consequencia (`Your current chat session will end.`).
- `on_cancel` agora chega ao `dialog` e ao `dialog_header`, para o X executar a mesma semantica de Cancel nos dialogs stateful.
- O teste `chat-message-edit-delete-edges.spec.ts` passou a usar um canal unico, evitando falha por historico persistente de `#lobby`.

## Resultado Visual

Screenshots refinados:

- `docs/plans/screenshots/confirm-dialogs-refined/desktop-generic-confirm.png`
- `docs/plans/screenshots/confirm-dialogs-refined/desktop-paste-standard.png`
- `docs/plans/screenshots/confirm-dialogs-refined/desktop-paste-flood.png`
- `docs/plans/screenshots/confirm-dialogs-refined/desktop-delete-message.png`
- `docs/plans/screenshots/confirm-dialogs-refined/desktop-disconnect.png`
- `docs/plans/screenshots/confirm-dialogs-refined/mobile-generic-confirm.png`
- `docs/plans/screenshots/confirm-dialogs-refined/mobile-paste-standard.png`
- `docs/plans/screenshots/confirm-dialogs-refined/mobile-paste-flood.png`
- `docs/plans/screenshots/confirm-dialogs-refined/mobile-delete-message.png`
- `docs/plans/screenshots/confirm-dialogs-refined/mobile-disconnect.png`

Melhorias observadas:

- Mobile deixou de transformar confirm curto em tela inteira vazia.
- Desktop manteve compacidade e ganhou leitura mais clara por message box.
- Botoes continuam a direita, com area de toque maior em mobile.
- Paste standard no chat fica sobre o contexto da conversa, sem esconder a tela inteira.
- Delete/Disconnect mostram consequencia perto da acao destrutiva.
- Generic confirm estabelece o molde para os proximos dialogs pequenos.

## Validacao

Comandos executados:

```bash
rtk npm --prefix e2e test -- --project=chromium tests/confirm-dialogs-audit.spec.ts --reporter=list
rtk mix format apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/confirm_dialog.ex apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/delete_confirm_dialog.ex apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/disconnect_confirm_dialog.ex apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/paste_confirm_dialog.ex
rtk mix compile
# em apps/retro_hex_chat_web
rtk mix assets.build
rtk env CONFIRM_DIALOGS_AUDIT_OUT_DIR=confirm-dialogs-refined npm --prefix e2e test -- --project=chromium tests/confirm-dialogs-audit.spec.ts --reporter=list
rtk npm --prefix e2e test -- --project=chromium tests/chat-message-edit-delete-edges.spec.ts --reporter=list
rtk npm --prefix e2e test -- --project=chromium tests/logout.spec.ts --reporter=list
rtk npm --prefix e2e test -- --project=chromium tests/chat-search-navigation.spec.ts --reporter=list
rtk npm --prefix e2e test -- --project=chromium tests/chat-flood-protection.spec.ts --reporter=list
```

Resultados:

- Captura visual baseline: passou.
- `mix format`: passou.
- `mix compile`: passou.
- `assets.build`: passou.
- Captura visual refinada: passou.
- Delete confirm edge: `1 passed`.
- Logout/disconnect confirm: `1 passed`.
- Search navigation com paste confirm: `1 passed`.
- Flood protection/paste confirm: `2 passed`.

Observacoes de validacao:

- `chat-message-edit-delete-edges.spec.ts` falhou primeiro por historico persistente em `#lobby` contendo `deleted-message` antigos. O teste foi isolado em canal unico e passou.
- `chat-search-history.spec.ts` falhou em expectativa de pagination/search (`search-highlight` ja estava visivel antes do scroll). O paste confirm foi acionado/enviado, mas a falha e de search history.
- `chat-history-pagination.spec.ts` falhou em expectativas de viewport de historico (`60` mensagens visiveis onde o spec espera `50`). Isso tambem e externo ao confirm.

## Aprendizados

- Dialog pequeno nao deve herdar fullscreen mobile sem criterio; confirms curtos precisam de message box compacta.
- Nao foi necessario alterar o `Dialog` global: uma classe opt-in (`cd-dialog-wrap`) reduziu o risco para dialogs grandes.
- Confirm de risco deve separar pergunta e consequencia, porque isso melhora decisao em desktop e mobile.
- O X do titlebar precisa chamar o mesmo cancelamento de Cancel quando o dialog tem estado no LiveComponent.
- Specs que usam `#lobby` e fazem assercoes globais sobre mensagens sao frageis em ambiente E2E sem reset completo.
- Showcase ajuda a capturar estados artificiais como Paste flood/disabled, mas fluxo real do chat continua necessario para validar stacking e contexto.
