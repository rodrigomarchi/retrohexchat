# Chat Migration Testing Strategy

## Objetivo

Garantir que a migracao disruptiva do ChatLive preserve comportamento e quebre testes de forma controlada, nunca por perda acidental de cobertura. Este plano e obrigatorio para qualquer migracao de componente.

## Estado atual dos testes

O projeto tem tres camadas relevantes para esta migracao:

1. Testes Elixir com `Phoenix.LiveViewTest` e component tests com `Floki`.
2. Testes JS de assets com Vitest.
3. Suite browser E2E real com Playwright em `e2e/`.

Referencias:

- Test case: `apps/retro_hex_chat_web/test/support/live_view_case.ex`
- Feature tests de chat: `apps/retro_hex_chat_web/test/retro_hex_chat_web/live`
- Component test exemplo: `apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/chat/chat_message_test.exs`
- Dependencias de teste: `apps/retro_hex_chat_web/mix.exs`
- Playwright README: `e2e/README.md`
- Playwright config: `e2e/playwright.config.ts`
- Playwright package: `e2e/package.json`
- Playwright catalog: `e2e/TEST_CATALOG.md`
- Chat Page Object: `e2e/pages/ChatPage.ts`

O catalogo E2E registra 206 spec files e 372 Playwright `test()` cases. A suite e local-only, mas o README diz para roda-la depois de refactor que toca JS hooks, lifecycle LiveView ou fluxo visivel. Esta migracao toca os tres.

## Regra de migracao

Durante uma migracao, testes existentes devem continuar passando ou ser atualizados no mesmo commit quando a mudanca de contrato for intencional. Nao fazer refactor que altera IDs, `data-testid`, eventos, selectors Playwright, JS hooks ou Page Objects sem atualizar/compatibilizar os testes.

## Tecnica

- Manter compatibilidade temporaria de eventos antigos no parent enquanto componentes migram para `phx-target={@myself}`.
- Manter `data-testid` e IDs publicos estaveis durante a primeira fase.
- Criar testes de LiveComponent para cada componente stateful novo.
- Manter feature tests de `LiveViewTest` para fluxos de usuario atravessando componentes.
- Manter Playwright como regressao browser para hooks, foco, scroll, dialogs, menus, reconnect, PubSub realtime e fluxos multiusuario.
- Adicionar testes de regressao de performance onde houver stream/window limit.
- Separar teste de comportamento de teste de markup quando possivel.
- Atualizar `e2e/pages/ChatPage.ts` antes de atualizar dezenas de specs individuais sempre que selector publico mudar.

## Contratos que nao podem quebrar sem migracao explicita

Contratos Elixir/LiveViewTest:

- `data-testid="chat-input-form"`
- Eventos usados diretamente em tests: `send_input`, `input_changed`, `toggle_search`, `search_input`, `channel_list`, `perform_dialog_*`, `admin_console_*`, `nick_right_click`, `chat_context_action`, `nicklist_context_action`.
- Dialog triggers atuais usados por LiveViewTest, por exemplo `#perform-dialog-show-trigger`, `#channel-list-dialog-show-trigger`.

Contratos Playwright/Page Object:

- `data-testid="chat-input-field"`, `chat-input-send`, `char-counter`.
- `data-testid="chat-message-list"` com rows `[data-message-id]`.
- `data-testid="status-messages"`.
- `data-testid="nicklist"`.
- `data-testid="topic-bar"` e `tab-bar`.
- `data-testid="connection-status-hook"` e seus `data-role="banner"`, `overlay`, `overlay-action`.
- Context menus: `context-menu-chat-context-menu`, `context-menu-nicklist-context-menu`, `context-menu-conversations-context-menu`.
- Context menu item ids `context-menu-item-*`.
- Dialog containers por id com `[role="dialog"]`: `#account-dialog`, `#address-book-dialog`, `#channel-list-dialog`, `#channel-central-dialog`, `#perform-dialog`, `#admin-console-dialog`, `#bot-management-dialog`, `#timers-dialog`, etc.
- Form/test ids de dialogs listados em `e2e/pages/ChatPage.ts`, como `paste-confirm-dialog`, `url-catcher`, `lookup-result-card`, `nick-change-dialog`.
- Stable ids de inputs usados pelo Page Object, como `#admin-console-input`, `#bot-name`, `#bot-nickname`, `#channel-list-search`.

Esses contratos podem mudar, mas somente com:

- adaptador temporario;
- atualizacao de testes no mesmo PR;
- atualizacao de `e2e/pages/ChatPage.ts` quando aplicavel;
- nota no plano do componente migrado.

## Tasks

- [ ] Antes de migrar cada componente, rodar os testes relacionados ao dominio.
- [ ] Criar um teste de componente novo para cada LiveComponent stateful novo.
- [ ] Manter pelo menos um feature test cobrindo o fluxo integrado antigo.
- [ ] Adicionar adaptador de eventos antigos quando testes ou hooks ainda dependem deles.
- [ ] Atualizar selectors para `data-testid` estavel, evitando depender de classe/CSS.
- [ ] Mapear specs Playwright impactadas no `e2e/TEST_CATALOG.md` ou por nome de arquivo antes da implementacao.
- [ ] Rodar pelo menos um spec Playwright focado para cada fluxo visual migrado.
- [ ] Se Page Object mudar, rodar `npx tsc --noEmit` em `e2e/`.
- [ ] Para streams, criar teste que prova limite de DOM e insert/update/delete sem reset total.
- [ ] Para dialogs, testar abrir, submeter, cancelar, fechar via Escape quando suportado, e limpar draft.
- [ ] Para async, testar loading, sucesso, erro e resultado atrasado/obsoleto.
- [ ] Para permission/admin, testar usuario sem permissao e usuario autorizado.
- [ ] Ao final de cada componente, rodar suite Elixir focada, spec Playwright focado e depois suite web completa.
- [ ] Ao final de uma fase inteira, rodar Playwright headless para os specs de chat impactados ou a suite completa se o refactor tocou shell/hooks globais.

## Validacao por fase

### Fase 1: wrappers sem mudar comportamento

- [ ] Todos os testes existentes continuam passando sem alteracao relevante.
- [ ] IDs e `data-testid` seguem iguais.
- [ ] Eventos antigos ainda funcionam.
- [ ] `e2e/pages/ChatPage.ts` nao precisou mudar ou foi atualizado junto.
- [ ] Specs Playwright focados passam para a area encapsulada.

### Fase 2: ownership stateful

- [ ] Testes novos de LiveComponent cobrem estado local.
- [ ] Feature tests seguem passando com adaptadores.
- [ ] Playwright confirma o fluxo real no browser: foco, click, keyboard, hooks e scroll.
- [ ] Parent perde assigns migrados.

### Fase 3: remocao de legado

- [ ] Testes sao atualizados para os novos eventos/componentes.
- [ ] Page Objects sao atualizados para novos selectors publicos.
- [ ] Adaptadores antigos sao removidos.
- [ ] Nenhum teste usa evento legado sem necessidade.

### Fase 4: performance

- [ ] Teste de mensagens confirma janela limitada.
- [ ] Teste de nicklist confirma updates incrementais.
- [ ] Teste de dialogs pesados confirma async/loading e ausencia de dados sensiveis apos close.
- [ ] Playwright confirma que scroll/load more, focus retention e dialogs continuam corretos no Chromium.

## Ambiente E2E — confirmado funcional neste host (2026-06-27)

O Playwright **roda localmente** neste ambiente. Setup ja presente:
`e2e/node_modules` instalado, Chromium baixado (`~/Library/Caches/ms-playwright`),
DB `retro_hex_chat_e2e` criado e migrado. O `playwright.config.ts` sobe o
servidor sozinho (`MIX_ENV=e2e mix phx.server` na porta 4003,
`reuseExistingServer: true`).

Procedimento por slice (gate real antes de marcar `complete`):

```sh
# uma vez, se assets mudaram:
MIX_ENV=e2e mix assets.build
# spec focado:
cd e2e && npx playwright test tests/<spec>.spec.ts --reporter=list
# um unico teste:
cd e2e && npx playwright test tests/<spec>.spec.ts:<linha> --reporter=list
```

Para isolar regressao vs. baseline: `git stash push <arquivo.ex>` →
`MIX_ENV=e2e mix compile` → rodar o spec → `git stash pop`.

### Baseline de falhas pre-existentes (NAO sao regressao)

Metodo de auditoria (eficiente + rigoroso): um spec que **passa no branch da
migracao nao pode ser regressao**, entao so os specs que FALHAM no branch sao
re-rodados no baseline limpo (`git stash` de `chat_live.ex` →
`MIX_ENV=e2e mix compile` → spec → `git stash pop`). Falha nos dois = baseline
pre-existente; passa no baseline e falha no branch = regressao real.

Auditoria por feature em 2026-06-27 (foundations 01/02 aplicadas). **Zero
regressoes** introduzidas — todas as falhas abaixo reproduzem identicas em
`main` limpo:

| Feature spec | Branch | Baseline | Veredito |
|---|---|---|---|
| chat-admin-permissions | 1/1 | — | verde |
| chat-admin-extended | 3/3 | — | verde |
| chat-autocomplete | 2/2 | — | verde |
| chat-conversations-sidebar | 3/3 | — | verde |
| chat-history-pagination | 2/2 | — | verde |
| chat-input-limits | 1/1 | — | verde |
| chat-channel-list | 1/1 | — | verde |
| chat-reconnect | 2/2 | — | verde |
| chat-multiuser | 4/4 | — | verde |
| chat-context-menus | 1f/1p | 1f (O12) | **pre-existente** |
| chat-sound-settings | 1f/1p | 1f (U3) | **pre-existente** |
| chat-search | 2f | 2f (O6,O7) | **pre-existente** |
| chat-search-history | 1f (S7) | 1f (S7) | **pre-existente** (auditado 2026-06-28) |
| chat-search-navigation | 1f (S8) | 1f (S8) | **pre-existente** (auditado 2026-06-28) |
| chat-search-window-state | 1f (S9) | 1f (S9) | **pre-existente** (auditado 2026-06-28) |
| chat-perform-dialog | 1f/1p | 1f (U6) | **pre-existente** |
| chat-send | flaky (1f depois 4/4) | — | flaky (timing) |

> 2026-06-28 (plano 09): a extracao do `SearchBar` para LiveComponent stateful nao
> introduziu regressao. Os specs `chat-search-history` (S7), `chat-search-navigation`
> (S8) e `chat-search-window-state` (S9) falham **identicos em `main` limpo** (provado
> via `git stash` dos arquivos `.ex` + `MIX_ENV=e2e mix compile`). Eles nao estavam na
> tabela original porque a auditoria de 2026-06-27 so cobriu `chat-search.spec.ts`.

### Investigacao da menubar (2026-06-27) — CORRECAO de diagnostico

> CORRECAO IMPORTANTE: uma hipotese anterior dizia que "o `MenuBarHook` nao
> monta / a menubar esta quebrada". **Isso estava ERRADO** — foi artefato de um
> probe Playwright bugado que procurava o item `toggle_search` ("Find") no menu
> **View**, quando na verdade ele so existia no menu **Edit**. Verificado com
> probes corretos: a menubar **funciona** (`Tools→Sound` e `View→Channel List`
> abrem normalmente via click real do Playwright; `MENUBAR_MOUNT` ocorre e o
> handler de `mousedown` dispara e remove `u-hidden`). O hook esta bom.

Causas reais, separadas, das falhas menu-driven:

1. **O6/O7 + 5 specs de busca — E2E STALE, NAO corrigir movendo o menu.**
   Tentativa inicial: adicionar "Find" (`toggle_search`) ao menu View (alem do
   Edit) + `findMenuItem` com `:visible`. Os specs E2E ficaram verdes, MAS o
   `make ci` pegou uma **regressao**: o teste Elixir autoritativo
   `window_display_edit_menu_feature_test.exs` asserta explicitamente
   `menu_actions(edit_section) == ["clear_window","copy_selection","toggle_search"]`
   e `refute "toggle_search" in menu_actions(view_section)` — ou seja, o layout
   canonico e **Find no Edit, NUNCA no View**. Esse teste **passa no main**;
   os 7 specs `openSearchFromViewMenu` ja **falhavam no baseline** (O6/O7 estao
   na lista de pre-existentes). Logo, os specs E2E e que estao **stale**.
   - **Mudanca revertida** (menu_bar_app.ex + ChatPage.ts) — nao se sobrepoe a
     um teste autoritativo que passa.
   - Resolucao correta (cleanup de teste E2E, separado do refactor): repontar os
     7 specs `openSearchFromViewMenu` para o menu **Edit** (helper
     `openSearchFromEditMenu` ja existe e e usado por 1 spec). Ou, se o produto
     decidir que Find DEVE estar no View, atualizar o teste Elixir junto. Decisao
     de produto pendente.
   - **Licao:** validacao E2E por-feature sozinha NAO pega regressoes de
     LiveViewTest/component. `make ci` (compile+format+credo+css+test+
     test_feature+js) e o gate de completude obrigatorio antes de declarar
     qualquer fatia pronta. Playwright NAO faz parte do `scripts/ci.exs`.

2. **U3 (Tools→Sound) — first-click race, AINDA ABERTO:** U3 abre o menu Tools
   como **primeira acao** logo apos `signedInUser` (sem settle). O item existe
   (probe confirma `Tools→Sound` visivel quando clicado apos ~1s). O primeiro
   click de menu logo apos o connect e instavel — a menubar sofre
   MOUNT→DESTROY→MOUNT no burst de render do connect; um click nessa janela abre
   num node que e substituido em seguida. `phx-update="ignore"` na menubar
   melhora (passou de 0/3 para flaky 1/2) mas NAO resolve e tem tradeoff (item
   admin nao atualiza em identify tardio), entao foi revertido. Precisa de fix
   dedicado (ex.: estabilizar a identidade do node da menubar no connect, ou
   isolar a menubar do status bar que re-renderiza em toda atualizacao de lag).
   Tratar no plano 04 (shell-header-status) / 08 (connection-status).

3. **O12 (nicklist context menu) — NAO e menubar.** "element(s) not found" ao
   abrir o context menu da nicklist (right-click). Subsistema diferente.
   Investigar no plano 13/21.

Falhas pre-existentes ainda abertas (tratar no plano do componente):

- `chat-context-menus.spec.ts:61` (O12) — nicklist context menu. Plano 13/21.
- `chat-sound-settings.spec.ts:96` (U3) — first-click race no menu Tools.
  Plano 04/34.
- `chat-perform-dialog.spec.ts:42` (U6) — perform com reconnect. Plano 35.
- `chat-send` — falha intermitente (timing); nao reproduzivel de forma estavel.

## Comandos recomendados

Rodar foco por app:

```sh
mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/messaging_ui_feature_test.exs
mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/channel_list_dialog_test.exs
mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/perform_feature_test.exs
mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/server_administration_feature_test.exs
```

Rodar suite do app web:

```sh
cd apps/retro_hex_chat_web && mix test
```

Rodar precommit do umbrella quando a migracao estiver pronta:

```sh
mix precommit
```

Rodar Playwright focado a partir de `e2e/`:

```sh
make e2e.install
make e2e.db.setup
npx playwright test tests/chat-send.spec.ts
npx playwright test tests/chat-history-pagination.spec.ts
npx playwright test tests/chat-channel-list.spec.ts
npx playwright test tests/chat-perform-dialog.spec.ts
npx playwright test tests/chat-admin-extended.spec.ts
npx tsc --noEmit
```

Rodar Playwright completo:

```sh
make e2e.headless
```

## Playwright por area migrada

Use specs focados. Exemplos:

- MessageViewport: `chat-send.spec.ts`, `chat-history-pagination.spec.ts`, `chat-message-rendering.spec.ts`, `chat-message-actions.spec.ts`, `chat-message-edit-delete-edges.spec.ts`, `chat-message-reply-*.spec.ts`.
- Composer/autocomplete/search: `chat-input-limits.spec.ts`, `chat-autocomplete.spec.ts`, `chat-autocomplete-advanced.spec.ts`, `chat-command-history.spec.ts`, `chat-search.spec.ts`, `chat-search-navigation.spec.ts`, `chat-search-history.spec.ts`.
- Nicklist/context menus: `chat-multiuser.spec.ts`, `chat-channel-moderation.spec.ts`, `chat-context-menus.spec.ts`.
- Conversations/tabs/unread: `chat-conversations-sidebar.spec.ts`, `chat-conversation-unread.spec.ts`, `chat-tab-unread-edges.spec.ts`, `chat-pm-unread-multiple.spec.ts`.
- Dialogs: usar o spec de dialog correspondente, por exemplo `chat-perform-dialog.spec.ts`, `chat-address-book.spec.ts`, `chat-channel-central.spec.ts`, `chat-sound-settings.spec.ts`, `chat-custom-menus-dialog.spec.ts`.
- Admin: `chat-admin-*.spec.ts` e `chat-ui-features-admin.spec.ts`.
- Hooks/lifecycle/reconnect: `chat-reconnect*.spec.ts`, `multi-tab-takeover*.spec.ts`, `chat-no-focus-steal.spec.ts`, `chat-dialog-keyboard.spec.ts`.

Se a migracao tocar `ChatPage.ts` selectors amplos, rode um conjunto maior ou `make e2e.headless`.

## Prompt de execucao

Antes de migrar qualquer plano de componente, abra este arquivo e identifique os testes impactados em Elixir e Playwright. A migracao so termina quando os testes atuais continuam passando, ou quando a mudanca de contrato foi explicitamente refletida nos testes e no Page Object.

## Progress Log

- 2026-06-27: Estrategia criada e corrigida para tratar Playwright como gate obrigatorio quando a migracao tocar UI, hooks, lifecycle, selectors ou Page Objects.
- 2026-06-29 (plano 17 emoji): `chat-emoji.spec.ts` O1 falhava **identico no HEAD limpo** (baseline via `git stash -u`) — **first-click-after-connect race**: `waitUntilConnected()` so espera `liveSocket.isConnected()` (handshake WS), que resolve antes do join-render assentar; o primeiro `toggle_emoji_picker` e engolido pelo burst de render do connect. **Corrigido** com helper robusto `ChatPage.openEmojiPicker()` (re-clica se o picker nao aparecer em 2s). Mesma familia de causa do U3 (menubar first-click). Padrao reutilizavel para qualquer spec que interage logo apos connect.
