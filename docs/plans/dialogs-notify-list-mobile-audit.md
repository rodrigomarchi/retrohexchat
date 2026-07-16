# Notify List Mobile-First Audit

Data: 2026-07-16

## Escopo

Aplicacao do `Dialog Mobile Playbook` no Notify List standalone, mantendo a mesma interface mobile-first para desktop e mobile. O dialog combina toggles persistentes, lista de buddies, status online/offline, nota do usuario e subforms de add/edit.

Arquivos principais:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/notify_list.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/notify_list_dialog.ex`
- `apps/retro_hex_chat_web/assets/css/retrohex.css`

## Baseline

Foi criado um spec temporario de Playwright para abrir Notify List e capturar lista vazia, add form, lista com buddy online/offline selecionado e edit form com nota longa em desktop e Pixel 5.

Screenshots baseline:

- `docs/plans/screenshots/notify-list-audit/desktop-empty.png`
- `docs/plans/screenshots/notify-list-audit/desktop-add-form.png`
- `docs/plans/screenshots/notify-list-audit/desktop-selected.png`
- `docs/plans/screenshots/notify-list-audit/desktop-edit-form.png`
- `docs/plans/screenshots/notify-list-audit/mobile-empty.png`
- `docs/plans/screenshots/notify-list-audit/mobile-add-form.png`
- `docs/plans/screenshots/notify-list-audit/mobile-selected.png`
- `docs/plans/screenshots/notify-list-audit/mobile-edit-form.png`

Achados principais:

- A lista standalone ainda era tabela, com Nick/Status/Last Seen como colunas.
- A nota do notify entry nao aparecia na lista, apesar de existir no dominio.
- No mobile, a tabela ficava espremida e o usuario nao via que cada linha era uma entrada editavel rica.
- Status offline selecionado tinha contraste ruim no baseline.
- Add/Edit usavam input single-line para `note`, truncando conteudo real longo.
- Acoes ficavam no canto esquerdo; faltava fechamento explicito no painel standalone.

## Implementacao

Decisao: aplicar o padrao de list editor em uma unica lista de entradas acionaveis. Cada buddy mostra nickname, status, last seen e note no mesmo item, preservando `notify-list-row-*` para os testes.

Mudancas:

- Conteudo ganhou `focus_wrap`, `role="dialog"`, `aria-modal="false"`, superficie focavel e foco inicial.
- Tabela foi substituida por `nl-entry-list` e `nl-entry`.
- `notify-list-row-*`, ids dos toggles e eventos existentes foram preservados.
- Nota passou a aparecer diretamente na entrada, com fallback `No note`.
- Last Seen ganhou fallback legivel e `Now` para buddies online.
- Status online/offline ganhou classes locais para contraste consistente quando selecionado.
- Add/Edit/Remove e Close ficam alinhados a direita.
- Footer explicito usa `Close`, preservando o contrato ja usado pelos helpers e pela semantica do Notify List.
- Add/Edit note virou `textarea`, mantendo `name="note"` e ids existentes.
- LiveComponent ganhou `notify_close` para fechar a janela server-managed pelo footer explicito.

## Resultado Visual

Screenshots refinados:

- `docs/plans/screenshots/notify-list-refined/desktop-empty.png`
- `docs/plans/screenshots/notify-list-refined/desktop-add-form.png`
- `docs/plans/screenshots/notify-list-refined/desktop-selected.png`
- `docs/plans/screenshots/notify-list-refined/desktop-edit-form.png`
- `docs/plans/screenshots/notify-list-refined/mobile-empty.png`
- `docs/plans/screenshots/notify-list-refined/mobile-add-form.png`
- `docs/plans/screenshots/notify-list-refined/mobile-selected.png`
- `docs/plans/screenshots/notify-list-refined/mobile-edit-form.png`

Melhorias observadas:

- Desktop deixou de ser uma tabela tecnica e passou a mostrar o contexto operacional completo do buddy.
- Mobile mostra a mesma entrada do desktop, sem criar uma interface paralela.
- Nota longa quebra linha na lista e no textarea do edit form.
- Status e metadados seguem legiveis quando a entrada esta selecionada.
- Botoes de lista, subform e fechamento ficaram agrupados a direita.

## Validacao

Comandos executados:

```bash
rtk npm --prefix e2e test -- --project=chromium tests/notify-list-audit.spec.ts --reporter=list
rtk mix format apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/notify_list.ex apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/notify_list_dialog.ex
rtk mix compile
rtk env NOTIFY_LIST_AUDIT_OUT_DIR=notify-list-refined npm --prefix e2e test -- --project=chromium tests/notify-list-audit.spec.ts --reporter=list
rtk npm --prefix e2e test -- --project=chromium tests/chat-notify.spec.ts --reporter=list
rtk npm --prefix e2e test -- --project=chromium tests/chat-notify-settings.spec.ts --reporter=list
rtk npm --prefix e2e test -- --project=chromium tests/chat-ui-features-shell.spec.ts -g "Notify List and Bot Management are reachable" --reporter=list
```

Resultados:

- Captura visual baseline: passou.
- `mix format`: passou.
- `mix compile`: passou.
- Captura visual refinada: passou.
- Suite funcional Notify commands: `3 passed`.
- Suite funcional Notify settings: `3 passed`.
- Gate shell focado em Notify List/Bot Management: `1 passed`.

## Aprendizados

- List editor nao deve esconder dados de dominio: a nota existia, mas nao aparecia no standalone Notify List.
- Quando uma linha tem status + nota + timestamp, uma entrada composta e melhor que tabela em desktop e mobile.
- Nem todo footer explicito precisa ser `OK`; quando o dialog ja tem semantica de fechamento, `Close` preserva contrato e melhora clareza.
- Toggle rows precisam de texto quebravel e checkbox preservado; nao aplicar regra mobile generica em checkbox.
