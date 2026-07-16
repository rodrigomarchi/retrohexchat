# Channel List Dialog Mobile-First Audit

Data: 2026-07-16

## Escopo

Aplicacao do `Dialog Mobile Playbook` no Channel List, janela aberta por `/list`, View menu, toolbar e Browse All.

O objetivo foi melhorar mobile e desktop com uma unica interface de lista, preservando `channel-list-search`, `channel-list-row-*`, `channel-list-invite-only-*`, `channel-list-join`, `channel-list-knock` e os eventos `channel_list_filter`, `channel_list_select`, `channel_list_join` e `channel_list_knock`.

Arquivos principais:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/channel_list.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/channel_list_dialog.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/channel_list_events.ex`
- `apps/retro_hex_chat_web/assets/css/retrohex.css`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/channel_list_dialog_test.exs`

## Baseline

A auditoria foi feita pelo fluxo real em desktop e mobile: criar canal publico, criar canal invite-only, abrir `/list`, filtrar, selecionar canal publico/invite-only e capturar empty state.

Screenshots baseline:

- `docs/plans/screenshots/channel-list-audit/desktop-filtered.png`
- `docs/plans/screenshots/channel-list-audit/desktop-invite-selected.png`
- `docs/plans/screenshots/channel-list-audit/desktop-public-selected.png`
- `docs/plans/screenshots/channel-list-audit/desktop-empty.png`
- `docs/plans/screenshots/channel-list-audit/mobile-filtered.png`
- `docs/plans/screenshots/channel-list-audit/mobile-invite-selected.png`
- `docs/plans/screenshots/channel-list-audit/mobile-public-selected.png`
- `docs/plans/screenshots/channel-list-audit/mobile-empty.png`

Achados principais:

- Mobile renderizava uma tabela larga com colunas Channel/Users/Topic; topic ficava cortado e criava leitura horizontal ruim.
- Nome de canal, `+i`, users e topic ficavam separados em colunas, dificultando entender cada canal como uma unidade.
- Desktop era funcional, mas truncava topicos importantes e parecia tabela tecnica para uma tarefa de selecao.
- Botao Join/Request Access ja ficava a direita, mas a selecao visual competia com colunas estreitas.
- A captura precisa aguardar o debounce do filtro; sem isso, screenshots podem misturar estado antigo e filtrado.

## Implementacao

Decisao: substituir tabela por lista unica de entradas clicaveis `cl-*`, usada tambem no desktop.

Mudancas:

- `ChannelList` removeu a tabela e passou a renderizar `cl-channel-entry` por canal.
- Cada entrada agrupa icone, nome, badge `+i`, topic quebravel, users e mode.
- Selecionado usa `cl-channel-entry--selected`, preservando contraste nos chips internos.
- Empty/loading ganharam estados proprios (`cl-empty-state`, `cl-loading-state`).
- Search form usa `cl-search-form`, `cl-search-input` e `cl-search-button`, com wrap mobile.
- Action row usa `cl-action-row` e `cl-action-button`, mantendo Join/Request Access a direita.
- Todos os test ids e eventos de dominio foram preservados.

## Resultado Visual

Screenshots refinados:

- `docs/plans/screenshots/channel-list-refined/desktop-filtered.png`
- `docs/plans/screenshots/channel-list-refined/desktop-invite-selected.png`
- `docs/plans/screenshots/channel-list-refined/desktop-public-selected.png`
- `docs/plans/screenshots/channel-list-refined/desktop-empty.png`
- `docs/plans/screenshots/channel-list-refined/mobile-filtered.png`
- `docs/plans/screenshots/channel-list-refined/mobile-invite-selected.png`
- `docs/plans/screenshots/channel-list-refined/mobile-public-selected.png`
- `docs/plans/screenshots/channel-list-refined/mobile-empty.png`

Melhorias observadas:

- Mobile deixou de cortar topic e colunas.
- Desktop ficou mais escaneavel: canal, topico e metadados ficam juntos no mesmo objeto.
- Invite-only aparece como badge e tambem como metadado `Mode`.
- Selecao ficou mais forte sem quebrar contraste dos chips.
- Empty state ficou enquadrado e legivel.

## Validacao

Comandos executados:

```bash
rtk npm --prefix e2e test -- --project=chromium tests/channel-list-dialog-audit.spec.ts --reporter=list
rtk mix format apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/channel_list.ex
rtk mix compile
# em apps/retro_hex_chat_web
rtk mix assets.build
CHANNEL_LIST_AUDIT_OUT_DIR=channel-list-refined rtk npm --prefix e2e test -- --project=chromium tests/channel-list-dialog-audit.spec.ts --reporter=list
rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/channel_list_dialog_test.exs --include liveview --trace
rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/channel_membership_feature_test.exs --include liveview_feature --trace
rtk npm --prefix e2e test -- --project=chromium tests/chat-channel-list.spec.ts --reporter=list
rtk npm --prefix e2e test -- --project=chromium tests/chat-ui-features-channel.spec.ts --reporter=list
rtk npm --prefix e2e test -- --project=chromium tests/chat-dialog-close.spec.ts --reporter=list
rtk npm --prefix e2e test -- --project=chromium tests/chat-view-menu.spec.ts --reporter=list
```

Resultados:

- Captura visual baseline: passou.
- `mix format`: passou.
- `mix compile`: passou.
- `assets.build`: passou.
- Captura visual refinada: passou em desktop/mobile.
- `ChannelListDialogTest` com `:liveview`: `7 tests, 0 failures`.
- `ChannelMembershipFeatureTest` com `:liveview_feature`: `9 tests, 0 failures`.
- `chat-channel-list.spec.ts`: `1 passed`.
- `chat-ui-features-channel.spec.ts`: `4 passed`.
- `chat-dialog-close.spec.ts`: `1 passed`.
- `chat-view-menu.spec.ts`: `1 passed`.

## Aprendizados

- Channel List e um selector, nao uma tabela comparativa; entradas compostas melhoram mobile e desktop.
- A unidade mental do usuario e o canal, entao topic, users e mode devem ficar no mesmo objeto visual.
- Selecionar uma entrada com background forte exige cuidado com metadados internos; chips podem manter contraste proprio.
- Audits com `phx-debounce` precisam esperar a remocao de resultados antigos, nao apenas a presenca do resultado esperado.
- Testes funcionais existentes podem provar Join, mas nao necessariamente provar que o filtro limpou a lista visualmente.
