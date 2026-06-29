# User Lookup Dialog Migration

## Objetivo

Migrar User Lookup para componente stateful com input local, validacao e chamadas async para whois/whowas.

## Classificação para execução (agentes)

- **Tier:** ✅ Mecânico (fazer com 45)
- **Dependências:** Independente; fazer junto com 45 (compartilham `lookup_result`).
- **Componente de referência:** Passthrough + send_update no resultado.
- **Abordagem:** Componente owns user_lookup_nick/error; `lookup_result` async (whois) = passthrough; card 45 renderiza dentro; Escape-managed → `visible` passthrough.
- **Gotchas:** Resultado chega via PubSub/whois helper → passthrough, não mover.
- **Validação:** `make ci` 9/9 + E2E user-lookup.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:882`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/user_lookup_dialog.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/user_lookup_events.ex`
- Helpers: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/whois.ex`
- State atual: `show_user_lookup_dialog`, `user_lookup_nick`, `user_lookup_error`, `lookup_result`.

## Tecnica

Use LiveComponent stateful. Input e erro ficam locais. Whois/whowas podem rodar via `start_async/3`; resultado vai para `LookupResultComponent` ou sub-state.

## Tasks

- [ ] Criar `UserLookupDialogComponent`.
- [ ] Mover nickname/error.
- [ ] Executar whois/whowas async quando custoso.
- [ ] Enviar resultado para LookupResultComponent.
- [ ] Preservar acoes: whois, whowas, query PM.
- [ ] Remover `user_lookup_events.ex` da pipeline global.

## Validacao

- [ ] Lookup por nick online mostra whois.
- [ ] Lookup por nick offline mostra whowas quando existe.
- [ ] Erro aparece localmente.
- [ ] Query PM a partir do resultado funciona.
- [ ] Dialog nao trava chat durante lookup.

## Prompt de execucao

Lookup e consulta. Nao deixe input e resultado no parent; use async e estado local.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
- 2026-06-29: **COMPLETE (com plano 45)** — 19º LiveComponent stateful. `Components.UserLookupDialog`.
  - **Ownership:** componente é dono do draft `nick`/`error`. Parent mantém `show_user_lookup_dialog` E `lookup_result` (AMBOS no mapa de Escape `secondary_dismissals`) → passthrough como `visible`/`result`. `lookup_result` é produzido pelo caminho de comando `/whois`/`/whowas` (`Helpers.Whois` assigna no socket do parent) → passthrough, NÃO movido.
  - **Eventos:** `user_lookup_change` é COMPONENT-LOCAL (`@myself`, input controlado, síncrono — o botão Whowas sempre carrega o nick atual). `user_lookup_whois` (submit do form) / `user_lookup_whowas` sobem pro adapter `UserLookupEvents` (dispatcham `/whois`/`/whowas` reais; leem nick de params — form field / `phx-value-nickname`). Os eventos do card (`lookup_result_*`, `close_lookup_result`) sobem pro parent (agem no `lookup_result` parent + abrem PM). `open`/`close` viram helpers reusados pelo keyboard Escape.
  - Removidos do parent: `user_lookup_nick`/`user_lookup_error` + import do function component.
  - **Testes:** `user_lookup_dialog_test` (componente, novo, 3 tests `@moduletag :unit`); `user_lookup_feature_test` 12/12 sem mudança (usa element-based render_submit/render_change → alcança component-local). `make ci` **9/9**; E2E `chat-whois` J12 green; **J10/J11 falham IDÊNTICO no HEAD limpo** (baseline via `git stash -u`) — pré-existentes: os specs esperam saída TEXTO (`----- Whois -----`) mas o app usa modo CARD por default (confirmado pelo feature test). Não tocam o dialog migrado.
