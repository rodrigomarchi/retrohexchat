# Timers Mobile-First Audit

Data: 2026-07-16

## Escopo

Aplicacao do `Dialog Mobile Playbook` no Timers, tratando ele como list editor operacional: entradas com metadados de tempo, comando longo e acoes de Add/Edit/Stop em uma interface unica mobile-first que tambem melhora desktop.

Arquivos principais:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/timers_dialog.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/timers_dialog.ex`
- `apps/retro_hex_chat_web/assets/css/retrohex.css`

## Baseline

Foi criado um spec temporario de Playwright para abrir Timers e capturar lista vazia, add form, erro de repeat menor que o minimo, timer selecionado e edit form em desktop e Pixel 5.

Screenshots baseline:

- `docs/plans/screenshots/timers-audit/desktop-empty.png`
- `docs/plans/screenshots/timers-audit/desktop-add-form.png`
- `docs/plans/screenshots/timers-audit/desktop-repeat-error.png`
- `docs/plans/screenshots/timers-audit/desktop-selected.png`
- `docs/plans/screenshots/timers-audit/desktop-edit-form.png`
- `docs/plans/screenshots/timers-audit/mobile-empty.png`
- `docs/plans/screenshots/timers-audit/mobile-add-form.png`
- `docs/plans/screenshots/timers-audit/mobile-repeat-error.png`
- `docs/plans/screenshots/timers-audit/mobile-selected.png`
- `docs/plans/screenshots/timers-audit/mobile-edit-form.png`

Achados principais:

- A tabela cortava o command no mobile e deixava a leitura tecnica demais no desktop.
- O command usava input single-line, ruim para revisar comandos reais.
- Every, Repeat e Next eram colunas estreitas; funcionam melhor como metadados da entrada.
- Add/Edit/Stop e Save/Cancel ficavam alinhados a esquerda, quebrando o padrao visual dos dialogs ja tratados.
- O editor server-managed nao tinha OK explicito no painel.

## Implementacao

Decisao: trocar a tabela por uma lista unica de timers, com uma entrada acionavel por timer. A entrada mostra nome, metadados de agendamento e command quebravel. O form vira inspector responsivo: lateral no desktop quando ha espaco, empilhado no mobile.

Mudancas:

- Conteudo ganhou `focus_wrap`, `role="dialog"`, `aria-modal="false"`, superficie focavel e foco inicial.
- Tabela foi substituida por `tm-timer-list` e `tm-timer-entry`.
- `timer-row-*` foi preservado para manter o contrato dos testes funcionais.
- Nome do timer virou o texto principal da entrada, com `aria-label` estavel.
- Every, Repeat e Next viraram metadados curtos dentro da mesma entrada.
- Command na lista quebra linha e command no add/edit virou `textarea`, mantendo `name="command"` e `data-testid="timer-command-input"`.
- Add/Edit/Stop, Save/Cancel e OK ficam alinhados a direita.
- LiveComponent ganhou `timers_dialog_close` para fechar a janela server-managed pelo OK explicito.

## Resultado Visual

Screenshots refinados:

- `docs/plans/screenshots/timers-refined/desktop-empty.png`
- `docs/plans/screenshots/timers-refined/desktop-add-form.png`
- `docs/plans/screenshots/timers-refined/desktop-repeat-error.png`
- `docs/plans/screenshots/timers-refined/desktop-selected.png`
- `docs/plans/screenshots/timers-refined/desktop-edit-form.png`
- `docs/plans/screenshots/timers-refined/mobile-empty.png`
- `docs/plans/screenshots/timers-refined/mobile-add-form.png`
- `docs/plans/screenshots/timers-refined/mobile-repeat-error.png`
- `docs/plans/screenshots/timers-refined/mobile-selected.png`
- `docs/plans/screenshots/timers-refined/mobile-edit-form.png`

Melhorias observadas:

- Mobile deixou de depender de tabela cortada e passou a mostrar o timer como entrada legivel.
- Desktop ganhou leitura mais direta: nome, cadence, repeat, next fire e command ficam no mesmo item.
- Command longo pode ser revisado no form sem scroll horizontal interno.
- Erro de repeat menor que 10s fica visivel sem deformar o form.
- OK explicito fecha o ciclo visual do editor, mantendo o comportamento server-managed.

## Validacao

Comandos executados:

```bash
rtk npm --prefix e2e test -- --project=chromium tests/timers-audit.spec.ts --reporter=list
rtk mix format apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/timers_dialog.ex apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/timers_dialog.ex
rtk mix compile
rtk env TIMERS_AUDIT_OUT_DIR=timers-refined npm --prefix e2e test -- --project=chromium tests/timers-audit.spec.ts --reporter=list
rtk npm --prefix e2e test -- --project=chromium tests/chat-timer.spec.ts --reporter=list
rtk npm --prefix e2e test -- --project=chromium tests/chat-ui-features-shell.spec.ts -g "Timers dialog opens" --reporter=list
```

Resultados:

- Captura visual baseline: passou.
- `mix format`: passou.
- `mix compile`: passou.
- Captura visual refinada: passou.
- Suite funcional Timers: `3 passed`.
- Feature shell focada em Timers: `1 passed`.
- A suite ampla `chat-ui-features-shell.spec.ts` falhou antes de chegar no Timers por expectativa antiga de menu: ela esperava `File, Edit, View, Tools, P2P, Games, Help`, mas a UI atual tambem mostra `Language`. Fora do escopo do Timers.
- Uma tentativa de rodar specs Playwright em paralelo bateu em conflito de build `_build/e2e/consolidated`; rerodando sequencialmente, os testes focados passaram.

## Aprendizados

- Timers confirma que metadados temporais funcionam melhor como parte da entrada do que como colunas estreitas.
- Command operacional longo deve usar textarea tambem em desktop, nao so no mobile.
- O padrao de OK server-managed se repete nos list editors e precisa de `phx-target` correto quando o evento pertence ao LiveComponent.
- Specs Playwright que sobem webServer no mesmo app nao devem rodar em paralelo quando podem disputar a mesma build E2E.
