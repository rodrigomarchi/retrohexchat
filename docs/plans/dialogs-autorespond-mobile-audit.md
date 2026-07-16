# Auto Respond Mobile-First Audit

Data: 2026-07-16

## Escopo

Aplicacao do `Dialog Mobile Playbook` no Auto Respond, combinando list editor, toggle de enabled, select de trigger, channel filter e comando longo em uma interface unica mobile-first que tambem melhora desktop.

Arquivos principais:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/auto_respond_dialog.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/auto_respond_dialog.ex`
- `apps/retro_hex_chat_web/assets/css/retrohex.css`
- `e2e/pages/ChatPage.ts`

## Baseline

Foi criado um spec temporario de Playwright para abrir Auto Respond e capturar lista vazia, add form, erro de validacao, regra selecionada, edit form e regra disabled em desktop e Pixel 5.

Screenshots baseline:

- `docs/plans/screenshots/autorespond-audit/desktop-empty.png`
- `docs/plans/screenshots/autorespond-audit/desktop-add-form.png`
- `docs/plans/screenshots/autorespond-audit/desktop-validation-error.png`
- `docs/plans/screenshots/autorespond-audit/desktop-selected.png`
- `docs/plans/screenshots/autorespond-audit/desktop-edit-form.png`
- `docs/plans/screenshots/autorespond-audit/desktop-disabled.png`
- `docs/plans/screenshots/autorespond-audit/mobile-empty.png`
- `docs/plans/screenshots/autorespond-audit/mobile-add-form.png`
- `docs/plans/screenshots/autorespond-audit/mobile-validation-error.png`
- `docs/plans/screenshots/autorespond-audit/mobile-selected.png`
- `docs/plans/screenshots/autorespond-audit/mobile-edit-form.png`
- `docs/plans/screenshots/autorespond-audit/mobile-disabled.png`

Achados principais:

- No mobile o form lateral fixo ficava cortado para fora da janela.
- A tabela deixava command em uma coluna estreita e dificil de revisar.
- Add/Edit/Remove ficavam presos ao layout tecnico da tabela.
- Command usava input single-line, inadequado para comandos longos com variaveis.
- O editor server-managed nao tinha OK explicito no painel.

## Implementacao

Decisao: aplicar o padrao de list editor usado em Alias/Highlight, com uma entrada acionavel por regra. A regra mostra trigger, estado On/Off, channel, position e command quebravel na mesma superficie.

Mudancas:

- Conteudo ganhou `focus_wrap`, `role="dialog"`, `aria-modal="false"`, superficie focavel e foco inicial.
- Tabela foi substituida por `ar-rule-list` e `ar-rule-entry`.
- Checkbox de enabled foi preservado dentro da entrada.
- `autorespond-rule-row` foi adicionado e os helpers E2E deixaram de depender de `tr`.
- Command em add/edit virou `textarea`, mantendo `name="command"`.
- Form virou inspector responsivo: lateral no desktop, largura total no mobile.
- Add/Edit/Remove, Save/Cancel e OK ficam alinhados a direita.
- LiveComponent ganhou `autorespond_dialog_close` para fechar a janela pelo OK explicito.

## Resultado Visual

Screenshots refinados:

- `docs/plans/screenshots/autorespond-refined/desktop-empty.png`
- `docs/plans/screenshots/autorespond-refined/desktop-add-form.png`
- `docs/plans/screenshots/autorespond-refined/desktop-validation-error.png`
- `docs/plans/screenshots/autorespond-refined/desktop-selected.png`
- `docs/plans/screenshots/autorespond-refined/desktop-edit-form.png`
- `docs/plans/screenshots/autorespond-refined/desktop-disabled.png`
- `docs/plans/screenshots/autorespond-refined/mobile-empty.png`
- `docs/plans/screenshots/autorespond-refined/mobile-add-form.png`
- `docs/plans/screenshots/autorespond-refined/mobile-validation-error.png`
- `docs/plans/screenshots/autorespond-refined/mobile-selected.png`
- `docs/plans/screenshots/autorespond-refined/mobile-edit-form.png`
- `docs/plans/screenshots/autorespond-refined/mobile-disabled.png`

Melhorias observadas:

- Mobile deixou de cortar o form e passou a mostrar command em textarea.
- Desktop ganhou entrada selecionavel mais legivel, com metadados e command quebravel.
- Enabled/disabled ficou visivel junto da regra, sem esconder o checkbox.
- Validacao de channel/command continua aparecendo dentro do form.
- OK explicito fecha o editor de forma consistente com os outros windows server-managed.

## Validacao

Comandos executados:

```bash
rtk npm --prefix e2e test -- --project=chromium tests/autorespond-audit.spec.ts --reporter=list
rtk mix format apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/auto_respond_dialog.ex apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/auto_respond_dialog.ex
rtk mix compile
rtk env AUTORESPOND_AUDIT_OUT_DIR=autorespond-refined npm --prefix e2e test -- --project=chromium tests/autorespond-audit.spec.ts --reporter=list
rtk npm --prefix e2e test -- --project=chromium tests/chat-autorespond-dialog.spec.ts tests/chat-autorespond.spec.ts --reporter=list
```

Resultados:

- Captura visual baseline: passou.
- `mix format`: passou.
- `mix compile`: passou.
- Captura visual refinada: passou.
- Suite funcional Auto Respond focada: `5 passed`.

## Aprendizados

- Form lateral fixo e o maior risco nos list editors: no mobile ele pode simplesmente sair da janela.
- Command com variaveis deve usar textarea, igual Alias e Perform.
- Uma entrada pode conter checkbox, status e metadados sem voltar para tabela.
- Helpers E2E precisam acompanhar a intencao (`autorespond-rule-row`) em vez de depender da tag antiga `tr`.
