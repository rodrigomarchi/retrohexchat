# Perform Mobile-First Audit

Data: 2026-07-16

## Escopo

Aplicacao do `Dialog Mobile Playbook` no Perform, com o mesmo criterio estabelecido nos ciclos anteriores: uma interface unica mobile-first que melhora mobile e desktop, sem criar uma versao separada por tamanho.

Arquivos principais:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/perform_dialog.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/perform_dialog.ex`
- `apps/retro_hex_chat_web/assets/css/retrohex.css`
- `e2e/pages/ChatPage.ts`

## Baseline

Foi criado um spec temporario de Playwright para abrir o Perform, exercitar Commands e Auto-Join, selecionar entradas, abrir subdialogs de add/edit e capturar desktop e Pixel 5.

Screenshots baseline:

- `docs/plans/screenshots/perform-audit/desktop-commands-empty.png`
- `docs/plans/screenshots/perform-audit/desktop-commands-selected.png`
- `docs/plans/screenshots/perform-audit/desktop-perform-add-dialog.png`
- `docs/plans/screenshots/perform-audit/desktop-perform-edit-dialog.png`
- `docs/plans/screenshots/perform-audit/desktop-autojoin-empty.png`
- `docs/plans/screenshots/perform-audit/desktop-autojoin-selected.png`
- `docs/plans/screenshots/perform-audit/desktop-autojoin-add-dialog.png`
- `docs/plans/screenshots/perform-audit/desktop-autojoin-edit-dialog.png`
- `docs/plans/screenshots/perform-audit/mobile-commands-empty.png`
- `docs/plans/screenshots/perform-audit/mobile-commands-selected.png`
- `docs/plans/screenshots/perform-audit/mobile-perform-add-dialog.png`
- `docs/plans/screenshots/perform-audit/mobile-perform-edit-dialog.png`
- `docs/plans/screenshots/perform-audit/mobile-autojoin-empty.png`
- `docs/plans/screenshots/perform-audit/mobile-autojoin-selected.png`
- `docs/plans/screenshots/perform-audit/mobile-autojoin-add-dialog.png`
- `docs/plans/screenshots/perform-audit/mobile-autojoin-edit-dialog.png`

Achados principais:

- Commands e Auto-Join ainda eram tabelas tecnicas em um editor de lista.
- Comando longo ficava pouco escaneavel na tabela e piorava no mobile.
- O subdialog de add/edit usava input single-line para comandos que podem ser longos, causando truncamento visual de conteudo real.
- Acoes de lista e formularios ainda nao seguiam completamente o padrao de botoes a direita.
- O desktop tambem se beneficiava de um item de lista acionavel com conteudo quebravel, em vez de uma tabela com celula tecnica.

## Implementacao

Decisao: aplicar o mesmo padrao de list editor mobile-first construido em Custom Menus, agora para Commands e Auto-Join. A mesma lista e usada em desktop e mobile; apenas a densidade e o aproveitamento de espaco mudam por largura.

Mudancas:

- Conteudo ganhou `focus_wrap`, `role="dialog"`, `aria-modal="false"`, superficie focavel e foco inicial.
- Tabs ganharam classes locais `pf-tabs-shell` e `pf-main-tabs`.
- Tabelas foram substituidas por `pf-entry-list` e entradas acionaveis `pf-entry`.
- Commands mostram posicao, comando mascarado/quebravel e metadado de posicao no mesmo item.
- Auto-Join mostra canal e estado da key no mesmo item.
- Campo de comando em add/edit virou `textarea`, mantendo ids, nomes e test ids existentes.
- Subdialogs usam `pf-sub-form`, `pf-form-actions` e botoes alinhados a direita.
- A janela ganhou `OK` explicito no footer, ligado ao fechamento server-managed.
- Helpers E2E deixaram de depender de `tr` e passaram a localizar linhas por `data-testid`.
- `pf-entry-list` recebeu `align-content: start` para uma unica entrada nao esticar verticalmente.

## Resultado Visual

Screenshots refinados:

- `docs/plans/screenshots/perform-refined/desktop-commands-empty.png`
- `docs/plans/screenshots/perform-refined/desktop-commands-selected.png`
- `docs/plans/screenshots/perform-refined/desktop-perform-add-dialog.png`
- `docs/plans/screenshots/perform-refined/desktop-perform-edit-dialog.png`
- `docs/plans/screenshots/perform-refined/desktop-autojoin-empty.png`
- `docs/plans/screenshots/perform-refined/desktop-autojoin-selected.png`
- `docs/plans/screenshots/perform-refined/desktop-autojoin-add-dialog.png`
- `docs/plans/screenshots/perform-refined/desktop-autojoin-edit-dialog.png`
- `docs/plans/screenshots/perform-refined/mobile-commands-empty.png`
- `docs/plans/screenshots/perform-refined/mobile-commands-selected.png`
- `docs/plans/screenshots/perform-refined/mobile-perform-add-dialog.png`
- `docs/plans/screenshots/perform-refined/mobile-perform-edit-dialog.png`
- `docs/plans/screenshots/perform-refined/mobile-autojoin-empty.png`
- `docs/plans/screenshots/perform-refined/mobile-autojoin-selected.png`
- `docs/plans/screenshots/perform-refined/mobile-autojoin-add-dialog.png`
- `docs/plans/screenshots/perform-refined/mobile-autojoin-edit-dialog.png`

Melhorias observadas:

- Desktop deixou de parecer uma tabela administrativa e virou um editor de entradas mais legivel.
- Mobile mostra a mesma hierarquia do desktop, com comandos longos quebrando linha em vez de ficarem escondidos.
- Add/Edit de perform agora permite revisar comando longo antes de salvar.
- Auto-Join ganhou item selecionavel mais claro, sem tabela para uma lista simples.
- Acoes ficaram agrupadas e alinhadas a direita em lista, forms e footer.

## Validacao

Comandos executados:

```bash
rtk npm --prefix e2e test -- --project=chromium tests/perform-audit.spec.ts --reporter=list
rtk mix format apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/perform_dialog.ex apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/perform_dialog.ex
rtk mix compile
rtk env PERFORM_AUDIT_OUT_DIR=perform-refined npm --prefix e2e test -- --project=chromium tests/perform-audit.spec.ts --reporter=list
rtk npm --prefix e2e test -- --project=chromium tests/chat-perform-dialog.spec.ts --reporter=list
```

Resultados:

- Captura visual baseline: passou.
- `mix format`: passou.
- `mix compile`: passou.
- Captura visual refinada: passou.
- Suite funcional Perform: `2 passed`.

## Aprendizados

- O padrao de lista unica mobile-first tambem funciona para listas operacionais pequenas como Perform Commands e Auto-Join.
- Quando o conteudo real e um comando possivelmente longo, `textarea` e mais honesto que input single-line.
- Helpers E2E nao devem depender de tags de layout como `tr` quando a evolucao esperada e trocar tabela por lista; `data-testid` preserva intencao.
- Grid/listas com uma unica entrada precisam de `align-content: start`; caso contrario o item pode esticar e parecer um painel quebrado.
- `OK` explicito continua sendo parte do contrato visual de dialogs/editor windows server-managed.
