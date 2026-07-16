# Alias Mobile-First Audit

Data: 2026-07-16

## Escopo

Aplicacao do `Dialog Mobile Playbook` no Alias Editor, tratando ele como o list editor base da proxima leva: uma lista unica mobile-first, form responsivo e melhoria real tambem no desktop.

Arquivos principais:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/alias_dialog.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/alias_dialog.ex`
- `apps/retro_hex_chat_web/assets/css/retrohex.css`

## Baseline

Foi criado um spec temporario de Playwright para abrir o Alias Editor, capturar lista vazia, add form, linha selecionada, edit form, erro de validacao e warning de recursao em desktop e Pixel 5.

Screenshots baseline:

- `docs/plans/screenshots/alias-audit/desktop-empty.png`
- `docs/plans/screenshots/alias-audit/desktop-add-form.png`
- `docs/plans/screenshots/alias-audit/desktop-selected.png`
- `docs/plans/screenshots/alias-audit/desktop-edit-form.png`
- `docs/plans/screenshots/alias-audit/desktop-validation-error.png`
- `docs/plans/screenshots/alias-audit/desktop-recursion-warning.png`
- `docs/plans/screenshots/alias-audit/mobile-empty.png`
- `docs/plans/screenshots/alias-audit/mobile-add-form.png`
- `docs/plans/screenshots/alias-audit/mobile-selected.png`
- `docs/plans/screenshots/alias-audit/mobile-edit-form.png`
- `docs/plans/screenshots/alias-audit/mobile-validation-error.png`
- `docs/plans/screenshots/alias-audit/mobile-recursion-warning.png`

Achados principais:

- A tabela truncava a expansion em desktop e mobile.
- O form usava input single-line para expansion, embora o conteudo real seja comando longo.
- Botoes de Add/Edit/Remove e Save/Cancel ficavam alinhados a esquerda.
- O desktop tambem parecia tecnico demais para um editor de entradas.
- Estados de erro e warning precisavam participar da auditoria, porque sao parte do fluxo principal do Alias.

## Implementacao

Decisao: transformar o Alias no list editor padrao para os proximos dialogs pequenos. A mesma entrada acionavel aparece em desktop e mobile; no desktop o form usa layout lateral quando existe espaco, e no mobile empilha abaixo da lista.

Mudancas:

- Conteudo ganhou `focus_wrap`, `role="dialog"`, `aria-modal="false"`, superficie focavel e foco inicial.
- Tabela foi substituida por `al-entry-list` e entradas `al-alias-entry`.
- Cada entrada mostra alias forte e expansion quebravel com label curta.
- Linha selecionavel virou `button`, mas com `aria-label` estavel do alias para nao competir com botoes `Edit`.
- Expansion em add/edit virou `textarea`, mantendo `name="expansion"` e `data-testid="alias-expansion-input"`.
- Form virou inspector responsivo: lateral no desktop e empilhado no mobile.
- Erro e warning receberam area propria, com quebra de texto segura.
- Add/Edit/Remove, Save/Cancel e OK ficam alinhados a direita.
- LiveComponent ganhou handler `alias_dialog_close` para o OK explicito fechar a janela server-managed.

## Resultado Visual

Screenshots refinados:

- `docs/plans/screenshots/alias-refined/desktop-empty.png`
- `docs/plans/screenshots/alias-refined/desktop-add-form.png`
- `docs/plans/screenshots/alias-refined/desktop-selected.png`
- `docs/plans/screenshots/alias-refined/desktop-edit-form.png`
- `docs/plans/screenshots/alias-refined/desktop-validation-error.png`
- `docs/plans/screenshots/alias-refined/desktop-recursion-warning.png`
- `docs/plans/screenshots/alias-refined/mobile-empty.png`
- `docs/plans/screenshots/alias-refined/mobile-add-form.png`
- `docs/plans/screenshots/alias-refined/mobile-selected.png`
- `docs/plans/screenshots/alias-refined/mobile-edit-form.png`
- `docs/plans/screenshots/alias-refined/mobile-validation-error.png`
- `docs/plans/screenshots/alias-refined/mobile-recursion-warning.png`

Melhorias observadas:

- Desktop ganhou lista de entradas mais legivel e form lateral sem truncar expansion.
- Mobile usa a mesma entrada e o mesmo form, com expansion em textarea e acoes no canto direito.
- Warning de recursao e erro de validacao ficaram visiveis sem quebrar layout.
- O OK explicito fecha o ciclo visual do editor, alem do X da janela.
- O ajuste de altura da lista evitou area branca excessiva quando existe apenas uma entrada.

## Validacao

Comandos executados:

```bash
rtk npm --prefix e2e test -- --project=chromium tests/alias-audit.spec.ts --reporter=list
rtk mix format apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/alias_dialog.ex apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/alias_dialog.ex
rtk mix compile
rtk env ALIAS_AUDIT_OUT_DIR=alias-refined npm --prefix e2e test -- --project=chromium tests/alias-audit.spec.ts --reporter=list
rtk npm --prefix e2e test -- --project=chromium tests/chat-alias-dialog.spec.ts tests/chat-alias-dialog-edges.spec.ts tests/chat-reconnect-dialog-state.spec.ts --reporter=list
```

Resultados:

- Captura visual baseline: passou.
- `mix format`: passou.
- `mix compile`: passou.
- Captura visual refinada: passou.
- Suite funcional Alias focada: `3 passed`.

## Aprendizados

- Alias e o molde mais simples dos list editors: uma lista de entradas acionaveis, form responsivo e footer explicito.
- Ao transformar linha em `button`, o nome acessivel precisa ser controlado; deixar todo o texto livre como nome pode competir com botoes como `Edit`.
- Expansion de alias e comando longo; textarea melhora revisao em desktop e mobile.
- Estados de erro/warning devem entrar na captura visual, nao apenas o caminho feliz.
- O form lateral no desktop e empilhado no mobile funciona como a mesma interface quando a hierarquia e os componentes continuam iguais.
