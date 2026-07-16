# Nick Change Dialog Mobile-First Audit

Data: 2026-07-16

## Escopo

Aplicacao do `Dialog Mobile Playbook` no Nick Change Dialog, cobrindo troca para nick nao registrado, troca para nick registrado com senha NickServ e estado de erro de senha.

O objetivo foi melhorar mobile e desktop com uma unica interface compacta, preservando `nick-change-dialog`, `nick-change-password`, `nick-change-confirm`, `nick-change-cancel`, `nick-change-error`, eventos de confirm/cancel e atualizacao do password draft.

Arquivos principais:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/nick_change_dialog.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/nick_change_dialog.ex`
- `apps/retro_hex_chat_web/assets/css/retrohex.css`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/nick_change_dialog_test.exs`

## Baseline

Foi criado um spec temporario de Playwright para capturar showcase e fluxo real em desktop e mobile.

Screenshots baseline:

- `docs/plans/screenshots/nick-change-dialog-audit/desktop-showcase-unregistered.png`
- `docs/plans/screenshots/nick-change-dialog-audit/desktop-showcase-registered.png`
- `docs/plans/screenshots/nick-change-dialog-audit/desktop-showcase-error.png`
- `docs/plans/screenshots/nick-change-dialog-audit/desktop-real-unregistered.png`
- `docs/plans/screenshots/nick-change-dialog-audit/desktop-real-registered.png`
- `docs/plans/screenshots/nick-change-dialog-audit/desktop-real-error.png`
- `docs/plans/screenshots/nick-change-dialog-audit/mobile-showcase-unregistered.png`
- `docs/plans/screenshots/nick-change-dialog-audit/mobile-showcase-registered.png`
- `docs/plans/screenshots/nick-change-dialog-audit/mobile-showcase-error.png`
- `docs/plans/screenshots/nick-change-dialog-audit/mobile-real-unregistered.png`
- `docs/plans/screenshots/nick-change-dialog-audit/mobile-real-registered.png`
- `docs/plans/screenshots/nick-change-dialog-audit/mobile-real-error.png`

Achados principais:

- Mobile usava fullscreen para um form curto, deixando grande area vazia e botoes no rodape.
- Desktop era funcional, mas a informacao ficava em texto corrido: target, aviso NickServ, campo e erro competiam visualmente.
- O X do titlebar nao recebia `on_cancel`, entao podia esconder no cliente sem resetar o estado do LiveComponent.
- O estado de erro precisava entrar na auditoria porque aumenta altura e muda a hierarquia visual.

## Implementacao

Decisao: aplicar um form/message box compacto com classes locais `nc-*`, mantendo input touch-safe e acoes alinhadas a direita.

Mudancas:

- `NickChangeDialog` usa `nc-dialog-wrap` para sair do fullscreen mobile sem alterar o `Dialog` global.
- `on_cancel` agora chega ao `dialog` e ao `dialog_header`, fazendo X/Escape/click-away executarem o mesmo cancelamento server-owned.
- Target nick virou `nc-target-card`, com icone, label e valor quebravel.
- Aviso de nick registrado virou `nc-notice`, separado do target e do campo.
- Campo de senha usa `nc-password-input`, com altura/fonte segura no mobile.
- Erro usa `nc-error`, mantendo `data-testid="nick-change-error"`.
- Footer usa `nc-dialog-footer` e botoes `nc-action-button`, sempre alinhados a direita.
- Teste unitario passou a validar `nick_change_cancel` e o campo NickServ.

## Resultado Visual

Screenshots refinados:

- `docs/plans/screenshots/nick-change-dialog-refined/desktop-showcase-unregistered.png`
- `docs/plans/screenshots/nick-change-dialog-refined/desktop-showcase-registered.png`
- `docs/plans/screenshots/nick-change-dialog-refined/desktop-showcase-error.png`
- `docs/plans/screenshots/nick-change-dialog-refined/desktop-real-unregistered.png`
- `docs/plans/screenshots/nick-change-dialog-refined/desktop-real-registered.png`
- `docs/plans/screenshots/nick-change-dialog-refined/desktop-real-error.png`
- `docs/plans/screenshots/nick-change-dialog-refined/mobile-showcase-unregistered.png`
- `docs/plans/screenshots/nick-change-dialog-refined/mobile-showcase-registered.png`
- `docs/plans/screenshots/nick-change-dialog-refined/mobile-showcase-error.png`
- `docs/plans/screenshots/nick-change-dialog-refined/mobile-real-unregistered.png`
- `docs/plans/screenshots/nick-change-dialog-refined/mobile-real-registered.png`
- `docs/plans/screenshots/nick-change-dialog-refined/mobile-real-error.png`

Melhorias observadas:

- Mobile preserva o contexto do chat e deixa de empurrar botoes para o rodape.
- Desktop ficou mais escaneavel sem perder compacidade.
- Target, aviso, senha e erro passaram a ter hierarquia visual clara.
- Botoes Confirm/Cancel permanecem a direita e com alvo melhor no mobile.
- O estado sem senha ficou curto; o estado com erro continua cabendo sem scroll horizontal.

## Validacao

Comandos executados:

```bash
rtk npm --prefix e2e test -- --project=chromium tests/nick-change-dialog-audit.spec.ts --reporter=list
rtk mix format apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/nick_change_dialog.ex apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/nick_change_dialog_test.exs
rtk mix compile
# em apps/retro_hex_chat_web
rtk mix assets.build
rtk env NICK_CHANGE_DIALOG_AUDIT_OUT_DIR=nick-change-dialog-refined npm --prefix e2e test -- --project=chromium tests/nick-change-dialog-audit.spec.ts --reporter=list
rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/nick_change_dialog_test.exs --trace
rtk npm --prefix e2e test -- --project=chromium tests/chat-identity.spec.ts --reporter=list
rtk npm --prefix e2e test -- --project=chromium tests/chat-nickserv.spec.ts --reporter=list
```

Resultados:

- Captura visual baseline: passou.
- `mix format`: passou.
- `mix compile`: passou.
- `assets.build`: passou.
- Captura visual refinada: passou, incluindo X real em fluxo sem senha e erro com senha.
- `NickChangeDialogTest`: `4 tests, 0 failures`.
- `chat-identity.spec.ts`: `2 passed`.
- `chat-nickserv.spec.ts`: `3 passed`.

Observacoes de validacao:

- `chat-identity` e `chat-nickserv` emitiram warnings de tracker ja rastreado em `#lobby`, mas todos os testes passaram.
- A auditoria real de senha usou nick registrado e desconectado para exercitar o fluxo NickServ sem depender apenas do showcase.

## Aprendizados

- Form curto com senha opcional ainda pode ser compacto no mobile, desde que o input tenha altura/fonte segura.
- Estado de erro precisa ser capturado, porque muda o peso visual e pode empurrar action row.
- X em LiveComponent stateful deve ser conectado ao mesmo cancel que o botao Cancel.
- Separar target, aviso e erro melhora desktop tambem; nao e apenas uma adaptacao mobile.
