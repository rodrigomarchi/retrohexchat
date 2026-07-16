# Custom Menus Mobile-First Audit

Data: 2026-07-16

## Escopo

Aplicacao do `Dialog Mobile Playbook` no Custom Menus, com correcao de direcao: a UI final deve ser uma superficie unica mobile-first que melhora desktop e mobile, nao uma tabela desktop com alternativa mobile.

Arquivos principais:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/custom_menus_dialog.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/custom_menus_dialog.ex`
- `apps/retro_hex_chat_web/assets/css/retrohex.css`

## Baseline

Foi criado um spec temporario de Playwright que abre Custom Menus com usuario real, cria entradas em Nicklist, Channel e Chat, captura lista vazia, linha selecionada, formulario de edicao e formulario de adicao em desktop e Pixel 5.

Screenshots baseline:

- `docs/plans/screenshots/custom-menus-audit/desktop-empty-nicklist.png`
- `docs/plans/screenshots/custom-menus-audit/desktop-nicklist-row.png`
- `docs/plans/screenshots/custom-menus-audit/desktop-nicklist-edit.png`
- `docs/plans/screenshots/custom-menus-audit/desktop-channel-row.png`
- `docs/plans/screenshots/custom-menus-audit/desktop-chat-add.png`
- `docs/plans/screenshots/custom-menus-audit/mobile-empty-nicklist.png`
- `docs/plans/screenshots/custom-menus-audit/mobile-nicklist-row.png`
- `docs/plans/screenshots/custom-menus-audit/mobile-nicklist-edit.png`
- `docs/plans/screenshots/custom-menus-audit/mobile-channel-row.png`
- `docs/plans/screenshots/custom-menus-audit/mobile-chat-add.png`

Achados principais:

- A interface era uma tabela desktop encolhida.
- O formulario lateral era o pior caso: no mobile ele ficava cortado para fora da janela.
- O desktop tambem podia melhorar: estado vazio sem orientacao, comandos longos pouco escaneaveis e acoes soltas a esquerda.
- O dialog dependia do X da janela, mas os testes e a UX esperavam um fechamento explicito por `OK`.
- A primeira tentativa de ajuste ainda pensava em tabela desktop + card mobile; isso foi corrigido para uma unica lista mobile-first.

## Implementacao

Decisao: substituir a tabela por uma lista unica de entradas interativas em todos os tamanhos. A lista usa o mesmo item visual no desktop e no mobile; apenas o layout aproveita o espaco disponivel.

Mudancas:

- Conteudo ganhou `focus_wrap`, `role="dialog"`, `aria-modal="false"` e foco inicial.
- Tabs ganharam `cm-tabs-shell` e `cm-main-tabs` com indicadores de overflow.
- A tabela foi substituida por `cm-entry-list` + `cm-menu-entry`.
- Cada entrada mostra label forte e comando quebrando linha dentro do mesmo item.
- Desktop usa a mesma entrada em lista, com form ao lado quando ha espaco.
- Mobile usa a mesma entrada em lista, com form abaixo para evitar corte lateral.
- Estado vazio passou a ter mensagem clara dentro da lista.
- Add/Edit/Remove, Save/Cancel e OK ficam alinhados a direita.
- Foi adicionado `OK` no footer do editor, ligado ao fechamento da janela server-managed.

## Resultado Visual

Screenshots refinados:

- `docs/plans/screenshots/custom-menus-refined/desktop-empty-nicklist.png`
- `docs/plans/screenshots/custom-menus-refined/desktop-nicklist-row.png`
- `docs/plans/screenshots/custom-menus-refined/desktop-nicklist-edit.png`
- `docs/plans/screenshots/custom-menus-refined/desktop-channel-row.png`
- `docs/plans/screenshots/custom-menus-refined/desktop-chat-add.png`
- `docs/plans/screenshots/custom-menus-refined/mobile-empty-nicklist.png`
- `docs/plans/screenshots/custom-menus-refined/mobile-nicklist-row.png`
- `docs/plans/screenshots/custom-menus-refined/mobile-nicklist-edit.png`
- `docs/plans/screenshots/custom-menus-refined/mobile-channel-row.png`
- `docs/plans/screenshots/custom-menus-refined/mobile-chat-add.png`

Melhorias observadas:

- Desktop deixou de ser uma tabela tecnica e virou um editor mais claro, com item selecionado, comando legivel e form lateral organizado.
- Mobile usa o mesmo item/lista, sem form cortado para fora da tela.
- Estado vazio ficou compreensivel em desktop e mobile.
- Acoes ficaram consistentes no canto direito.
- O dialog agora tem fechamento explicito por `OK`, alem do X da janela.
- A feature continuou executando comandos customizados de nicklist, channel e chat.

## Validacao

Comandos executados:

```bash
rtk npm --prefix e2e test -- --project=chromium tests/custom-menus-audit.spec.ts --reporter=list
rtk mix format apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/custom_menus_dialog.ex apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/custom_menus_dialog.ex
rtk mix compile
rtk env CUSTOM_MENUS_AUDIT_OUT_DIR=custom-menus-refined npm --prefix e2e test -- --project=chromium tests/custom-menus-audit.spec.ts --reporter=list
rtk npm --prefix e2e test -- --project=chromium tests/chat-custom-menus-dialog.spec.ts tests/chat-custom-menus.spec.ts --reporter=list
```

Resultados:

- Captura visual baseline: passou.
- `mix format`: passou.
- `mix compile`: passou.
- Captura visual refinada: passou.
- Suite funcional Custom Menus: `2 passed`.

## Aprendizados

- O criterio correto nao e "desktop preservado, mobile adaptado"; e uma unica interface mobile-first que escala para desktop.
- List editors pequenos podem melhorar desktop ao abandonar tabela quando o dado real e melhor entendido como entradas acionaveis.
- Form lateral precisa ser pensado como inspector responsivo: ao lado com espaco amplo, abaixo no mobile, mesma semantica.
- Teste funcional revelou uma lacuna de UX: o helper esperava `OK`, e a interface nao tinha fechamento explicito.
- Screenshots e teste funcional se complementaram: screenshot mostrou o form cortado; teste mostrou a ausencia de `OK`.
