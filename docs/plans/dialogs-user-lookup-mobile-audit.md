# User Lookup Dialog - Mobile/Desktop Audit

Data: 2026-07-16

## Escopo

Dialog: `User Lookup`

Arquivos principais:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/user_lookup_dialog.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex`
- `apps/retro_hex_chat_web/assets/css/retrohex.css`
- `e2e/tests/chat-whowas.spec.ts`

## Baseline

Screenshots:

- `docs/plans/screenshots/user-lookup-audit/desktop-default.png`
- `docs/plans/screenshots/user-lookup-audit/desktop-error.png`
- `docs/plans/screenshots/user-lookup-audit/desktop-whois.png`
- `docs/plans/screenshots/user-lookup-audit/desktop-whowas.png`
- `docs/plans/screenshots/user-lookup-audit/mobile-default.png`
- `docs/plans/screenshots/user-lookup-audit/mobile-error.png`
- `docs/plans/screenshots/user-lookup-audit/mobile-whois.png`
- `docs/plans/screenshots/user-lookup-audit/mobile-whowas.png`

Achados:

- No mobile, o estado inicial era uma janela fullscreen quase vazia para um form curto.
- O resultado Whois ficava visualmente pesado porque o form permanecia grande acima do card.
- O `dl` em duas colunas quebrava labels no mobile, como `Shared channels`, piorando leitura.
- No desktop, a action row do resultado podia ficar parcialmente fora da janela.
- O spec E2E de `/whowas` ainda esperava output textual antigo na lista de mensagens, mas o produto atual usa result card estruturado.

## Decisoes

- Manter User Lookup como desktop window stacked no mobile, porque o resultado pode ser longo e a taskbar/window switcher ainda fazem parte do fluxo.
- Refatorar para uma interface unica `ul-*`: form compacto no topo, resultado em regiao flex e actions fixas no fim do card.
- Preservar todos os contratos: `user-lookup-form`, `user-lookup-nickname`, `user-lookup-whois`, `user-lookup-whowas`, `lookup-result-card`, `dt/dd` e eventos.
- Converter a lista de resultado para rows responsivas: duas colunas no desktop, label sobre valor no mobile.
- Adicionar empty state simples para reduzir a sensacao de tela vazia sem criar fluxo paralelo.
- Ajustar a geometria desktop para `500x420`, dando largura para formulario/actions sem aumentar altura.
- Atualizar `chat-whowas.spec.ts` para validar o contrato atual do result card.

## Resultado

Screenshots refinados:

- `docs/plans/screenshots/user-lookup-refined/desktop-default.png`
- `docs/plans/screenshots/user-lookup-refined/desktop-error.png`
- `docs/plans/screenshots/user-lookup-refined/desktop-whois.png`
- `docs/plans/screenshots/user-lookup-refined/desktop-whowas.png`
- `docs/plans/screenshots/user-lookup-refined/mobile-default.png`
- `docs/plans/screenshots/user-lookup-refined/mobile-error.png`
- `docs/plans/screenshots/user-lookup-refined/mobile-whois.png`
- `docs/plans/screenshots/user-lookup-refined/mobile-whowas.png`

Entregue:

- Form de lookup ficou mais compacto no desktop e no mobile.
- Result card ganhou body rolavel e action row sempre visivel.
- Labels do resultado deixam de quebrar no meio no mobile.
- Estado de erro preserva foco visual sem desalojar os botoes.
- Whois, Query, Whowas e Clear continuam funcionando pelos mesmos eventos.

## Validacao

- Passou: captura visual User Lookup desktop/mobile em fluxo real via Tools.
- Passou: `rtk mix compile`.
- Passou: `rtk mix assets.build` em `apps/retro_hex_chat_web`.
- Passou: `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/user_lookup_dialog_test.exs --trace` (3 testes).
- Passou: `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/user_lookup_feature_test.exs --include liveview_feature --trace` (9 testes).
- Passou: `rtk npm --prefix e2e test -- --project=chromium tests/chat-ui-features-shell.spec.ts --grep "User Lookup" --reporter=list` (1 teste).
- Passou: `rtk npm --prefix e2e test -- --project=chromium tests/chat-whois.spec.ts --reporter=list` (3 testes).
- Passou: `rtk npm --prefix e2e test -- --project=chromium tests/chat-whowas.spec.ts --reporter=list` (1 teste).
- Passou: `rtk npm --prefix e2e test -- --project=chromium tests/chat-tools-menu.spec.ts --reporter=list` (1 teste).
- Passou: `rtk npm --prefix e2e test -- --project=chromium tests/chat-context-menus.spec.ts --reporter=list` (2 testes).

Nota: duas tentativas E2E paralelas falharam por disputa conhecida de `E2E_PORT=4003`/`_build/e2e`. Os mesmos specs passaram em sequencia.

## Licoes Para O Playbook

- Result cards precisam de footer fixo quando as acoes sao parte do fluxo, nao do conteudo rolavel.
- `dl` de duas colunas funciona no desktop, mas no mobile deve virar label sobre valor quando labels sao longos.
- Uma janela fullscreen mobile pode ser aceitavel para form curto se o resultado potencial e longo; a composicao interna precisa compensar o estado vazio.
- Testes antigos de output textual devem acompanhar a mudanca para cards estruturados, senao bloqueiam evolucao de UX ja entregue.
- Rodar specs Playwright em paralelo continua sendo risco quando eles compartilham webServer/database no ambiente e2e local.
