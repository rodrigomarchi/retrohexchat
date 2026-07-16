# Kick Dialog Mobile-First Audit

Data: 2026-07-16

## Escopo

Aplicacao do `Dialog Mobile Playbook` no Kick Dialog, que e a notificacao exibida para o usuario quando ele foi removido de um canal. O objetivo foi melhorar mobile e desktop com uma unica interface compacta, sem quebrar a fila `KickQueueDialog` nem os contratos `kick-dialog` e `kick-dialog-ok`.

Arquivos principais:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/kick_dialog.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/kick_queue_dialog.ex`
- `apps/retro_hex_chat_web/assets/css/retrohex.css`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/kick_queue_dialog_test.exs`

## Baseline

Foi criado um spec temporario de Playwright para capturar o Kick Dialog no showcase e no fluxo real de chat, em desktop e mobile.

Screenshots baseline:

- `docs/plans/screenshots/kick-dialog-audit/desktop-showcase-with-info.png`
- `docs/plans/screenshots/kick-dialog-audit/desktop-showcase-no-info.png`
- `docs/plans/screenshots/kick-dialog-audit/desktop-real-kick.png`
- `docs/plans/screenshots/kick-dialog-audit/mobile-showcase-with-info.png`
- `docs/plans/screenshots/kick-dialog-audit/mobile-showcase-no-info.png`
- `docs/plans/screenshots/kick-dialog-audit/mobile-real-kick.png`

Achados principais:

- Mobile herdava o fullscreen do `Dialog` global: mensagem curta no topo, botao no rodape e grande area vazia no meio.
- Desktop era compacto, mas o texto corrido dificultava escanear canal, operador e motivo.
- O fluxo real expunha bug de dado: o componente lia `:kicker`, mas a fila real enfileira `:operator`; o resultado visual era `by (reason)`.
- O X do titlebar precisava chamar a mesma semantica de dismiss do botao OK; esconder apenas no cliente deixaria risco de fila viva no LiveComponent.
- Showcase sozinho nao bastava, porque o estado real vem de `KickQueueDialog` e PubSub.

## Implementacao

Decisao: tratar o Kick como message box compacta de notificacao, com classes locais `kd-*`. O padrao visual e o mesmo dos dialogs pequenos, mas a informacao e apresentada como fatos escaneaveis em vez de pergunta/confirmacao.

Mudancas:

- `KickDialog` usa `class="kd-dialog-wrap"` para sair do fullscreen mobile sem alterar o `Dialog` global.
- Corpo usa `kd-message-row`: icone de alerta, titulo curto e metadados.
- Canal aparece na frase principal: `You were kicked from %{channel}.`
- Operador e motivo aparecem como detalhes `By` e `Reason`, com quebra segura de texto.
- O helper aceita `:operator` e `:kicker`, alem de chaves string, para preservar compatibilidade.
- Mensagem de consequencia fica separada: `The channel tab was closed. You can rejoin if allowed.`
- Footer usa `kd-dialog-footer` e `kd-dialog-action`, mantendo OK alinhado a direita.
- `on_cancel` chega ao `dialog` e ao `dialog_header`, para X/Escape/click-away executarem o mesmo dismiss da fila quando `on_dismiss` existe.
- Teste unitario do `KickQueueDialog` passou a validar canal, operador, motivo, texto de consequencia e evento `kick_dialog_dismiss`.

## Resultado Visual

Screenshots refinados:

- `docs/plans/screenshots/kick-dialog-refined/desktop-showcase-with-info.png`
- `docs/plans/screenshots/kick-dialog-refined/desktop-showcase-no-info.png`
- `docs/plans/screenshots/kick-dialog-refined/desktop-real-kick.png`
- `docs/plans/screenshots/kick-dialog-refined/mobile-showcase-with-info.png`
- `docs/plans/screenshots/kick-dialog-refined/mobile-showcase-no-info.png`
- `docs/plans/screenshots/kick-dialog-refined/mobile-real-kick.png`

Melhorias observadas:

- Mobile deixou de virar uma tela vazia; o dialog aparece compacto sobre o contexto do chat/showcase.
- Desktop manteve compacidade e ganhou melhor hierarquia de informacao.
- Operador real passou a aparecer corretamente no dialog.
- Motivo longo quebra dentro do bloco sem scroll horizontal.
- OK continua a direita; no mobile ganha alvo de toque melhor.
- O fallback sem detalhes continua legivel e compacto.

## Validacao

Comandos executados:

```bash
rtk npm --prefix e2e test -- --project=chromium tests/kick-dialog-audit.spec.ts --reporter=list
rtk mix format apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/kick_dialog.ex apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/kick_queue_dialog_test.exs
rtk mix compile
# em apps/retro_hex_chat_web
rtk mix assets.build
rtk env KICK_DIALOG_AUDIT_OUT_DIR=kick-dialog-refined npm --prefix e2e test -- --project=chromium tests/kick-dialog-audit.spec.ts --reporter=list
rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/kick_queue_dialog_test.exs --trace
rtk npm --prefix e2e test -- --project=chromium tests/chat-channel-moderation.spec.ts --reporter=list
```

Resultados:

- Captura visual baseline: passou.
- `mix format`: passou.
- `mix compile`: passou.
- `assets.build`: passou.
- Captura visual refinada: passou, incluindo clique no X do fluxo real.
- `KickQueueDialogTest`: `3 tests, 0 failures`.
- `chat-channel-moderation.spec.ts`: `3 passed`.

Observacoes de validacao:

- Uma tentativa de rodar dois Playwrights em paralelo falhou por porta `4003` ja em uso. A suite de moderacao foi rerodada isolada e passou.
- A primeira versao da auditoria usava nicklist como espera no mobile; isso era errado porque a nicklist existe no DOM mas fica escondida no layout mobile. O spec foi ajustado para nao depender de sidebar escondida.
- A primeira captura baseline foi mantida somente depois que o spec deixou de depender dessas esperas visuais fragilizadas.

## Aprendizados

- Notificacao pequena tambem precisa do padrao de message box compacta; fullscreen mobile prejudica tanto confirmacao quanto aviso.
- Fluxo real e indispensavel quando o componente recebe estado via LiveComponent/PubSub; showcase nao revela fila, dismiss nem shape real do payload.
- Metadados de evento (`channel`, `operator`, `reason`) devem ser renderizados como fatos separados, nao como frase corrida.
- Quando a UI antiga lia `:kicker` mas o dominio envia `:operator`, a auditoria visual pega um bug funcional pequeno que testes de existencia nao capturavam.
- Em dialogs stateful, X/Escape/click-away devem chegar no mesmo evento de dismiss do botao principal.
- E2E mobile nao deve usar visibilidade de sidebars escondidas como proxy de estado de dominio.
