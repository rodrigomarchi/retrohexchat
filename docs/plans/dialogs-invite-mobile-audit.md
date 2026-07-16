# Invite Dialog Mobile-First Audit

Data: 2026-07-16

## Escopo

Aplicacao do `Dialog Mobile Playbook` na feature de convites de canal, cobrindo duas superficies:

- `InviteDialog`: notificacao recebida com Join/Ignore para convites pendentes.
- `InviteChannelPickerDialog`: picker usado para enviar convite a um nick a partir do nicklist/context menu.

O objetivo foi melhorar mobile e desktop com a mesma interface mobile-first, preservando fila de convites, aceite/ignore, cancelamento e o fluxo real de invite-only channel.

Arquivos principais:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/invite_dialog.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/invite_channel_picker_dialog.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/invite_queue_dialog.ex`
- `apps/retro_hex_chat_web/assets/css/retrohex.css`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/invite_queue_dialog_test.exs`

## Baseline

Foi criado um spec temporario de Playwright para capturar showcase e fluxo real em desktop e mobile.

Screenshots baseline:

- `docs/plans/screenshots/invite-dialog-audit/desktop-showcase-single.png`
- `docs/plans/screenshots/invite-dialog-audit/desktop-showcase-multi.png`
- `docs/plans/screenshots/invite-dialog-audit/desktop-showcase-empty.png`
- `docs/plans/screenshots/invite-dialog-audit/desktop-real-received.png`
- `docs/plans/screenshots/invite-dialog-audit/desktop-real-picker.png`
- `docs/plans/screenshots/invite-dialog-audit/mobile-showcase-single.png`
- `docs/plans/screenshots/invite-dialog-audit/mobile-showcase-multi.png`
- `docs/plans/screenshots/invite-dialog-audit/mobile-showcase-empty.png`
- `docs/plans/screenshots/invite-dialog-audit/mobile-real-received.png`
- `docs/plans/screenshots/invite-dialog-audit/mobile-real-picker.png`

Achados principais:

- Notificacao recebida virava fullscreen no mobile, com grande area vazia abaixo de um unico convite.
- Picker de envio tambem virava fullscreen no mobile, apesar de ser um form curto sem teclado textual.
- Botoes Join/Ignore ficavam alinhados a esquerda no dialog recebido.
- A notificacao usava mini-window/card dentro do dialog, criando peso visual desnecessario.
- O X do titlebar escondia o dialog no cliente, mas nao resolvia explicitamente o convite pendente na fila server-owned.
- O picker desktop era funcional, mas target/select/acoes podiam ficar mais claros sem mudar comportamento.

## Implementacao

Decisao: transformar Invite recebido em uma lista compacta de convites e o picker em um form compacto. Ambos usam classes locais opt-in e nao alteram o `Dialog` global.

Mudancas:

- `InviteDialog` usa `iv-dialog-wrap` para sair do fullscreen mobile.
- Convites pendentes viraram `iv-invite-item`: icone, canal, inviter e acoes.
- Join/Ignore usam `iv-action-button` e ficam alinhados a direita em desktop e mobile.
- Multi invite usa uma lista com scroll interno quando necessario, sem mini-windows empilhadas.
- Empty state usa a mesma linguagem visual, sem tela inteira.
- `InviteQueueDialog` passa `on_dismiss` para o dialog com `JS.push("invite_ignore", value: %{channel: top})`, alinhando X/click-away/Escape do modal ao ignore do convite do topo.
- `InviteChannelPickerDialog` usa `icp-dialog-wrap`, target em bloco proprio, select responsivo e action row a direita.
- Helpers do invite aceitam chaves atom/string e fallback robusto para channel/inviter.
- Teste unitario do `InviteQueueDialog` passou a validar channel, inviter, Join/Ignore e eventos `invite_accept`/`invite_ignore`.

## Resultado Visual

Screenshots refinados:

- `docs/plans/screenshots/invite-dialog-refined/desktop-showcase-single.png`
- `docs/plans/screenshots/invite-dialog-refined/desktop-showcase-multi.png`
- `docs/plans/screenshots/invite-dialog-refined/desktop-showcase-empty.png`
- `docs/plans/screenshots/invite-dialog-refined/desktop-real-received.png`
- `docs/plans/screenshots/invite-dialog-refined/desktop-real-picker.png`
- `docs/plans/screenshots/invite-dialog-refined/mobile-showcase-single.png`
- `docs/plans/screenshots/invite-dialog-refined/mobile-showcase-multi.png`
- `docs/plans/screenshots/invite-dialog-refined/mobile-showcase-empty.png`
- `docs/plans/screenshots/invite-dialog-refined/mobile-real-received.png`
- `docs/plans/screenshots/invite-dialog-refined/mobile-real-picker.png`

Melhorias observadas:

- Mobile preserva o contexto do chat em vez de ocupar a tela inteira com vazio.
- Desktop ficou mais denso e escaneavel: canal e inviter no mesmo item, acoes no lado direito.
- Multi invite mantem uma lista unica mobile-first, sem criar uma interface separada.
- Picker mobile virou um form compacto com target, select e acoes previsiveis.
- O X real da notificacao remove o convite pendente; o X do picker cancela o form.

## Validacao

Comandos executados:

```bash
rtk npm --prefix e2e test -- --project=chromium tests/invite-dialog-audit.spec.ts --reporter=list
rtk mix format apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/invite_dialog.ex apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/invite_channel_picker_dialog.ex apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/invite_queue_dialog.ex apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/invite_queue_dialog_test.exs
rtk mix compile
# em apps/retro_hex_chat_web
rtk mix assets.build
rtk env INVITE_DIALOG_AUDIT_OUT_DIR=invite-dialog-refined npm --prefix e2e test -- --project=chromium tests/invite-dialog-audit.spec.ts --reporter=list
rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/invite_queue_dialog_test.exs --trace
rtk npm --prefix e2e test -- --project=chromium tests/chat-channel-invite.spec.ts --reporter=list
rtk npm --prefix e2e test -- --project=chromium tests/chat-ui-features-channel.spec.ts --reporter=list
rtk npm --prefix e2e test -- --project=chromium tests/chat-ignore-notifications.spec.ts --reporter=list
```

Resultados:

- Captura visual baseline: passou.
- `mix format`: passou.
- `mix compile`: passou.
- `assets.build`: passou.
- Captura visual refinada: passou, incluindo X real da notificacao e do picker.
- `InviteQueueDialogTest`: `3 tests, 0 failures`.
- `chat-channel-invite.spec.ts`: `1 passed`.
- `chat-ui-features-channel.spec.ts`: `4 passed`.
- `chat-ignore-notifications.spec.ts`: `2 passed`.

Observacoes de validacao:

- A auditoria mobile do picker precisou usar o mesmo long press dos testes mobile existentes para abrir o nicklist context menu.
- O overlay da nicklist pode continuar visivel ao fundo no mobile depois de abrir o picker; isso vem do caminho de entrada, mas o dialog ficou compacto, legivel e modal.
- A notificacao real foi validada via invite-only channel, nao apenas pelo showcase.

## Aprendizados

- Invite recebido e picker de envio pertencem ao mesmo ciclo de UX: um resolve convite, o outro cria convite.
- Dialog de lista curta nao precisa de mini-windows internas; item composto com canal/inviter/acoes funciona melhor em desktop e mobile.
- X de dialog com fila server-owned precisa virar acao de dominio. Para Invite, o equivalente pragmatico e ignorar o convite do topo, igual ao Escape.
- Multi invite deve continuar sendo uma lista unica; desktop apenas aproveita melhor a linha, sem interface paralela.
- Picker pequeno sem teclado textual deve ser compacto no mobile, nao fullscreen.
- Auditoria mobile de context menu deve usar o mesmo gesto real suportado pela app, como long press na nicklist.
