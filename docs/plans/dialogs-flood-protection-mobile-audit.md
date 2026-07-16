# Flood Protection Dialog - Mobile/Desktop Audit

Data: 2026-07-16

## Escopo

Dialog: `Flood Protection`

Arquivos principais:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/flood_protection_dialog.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex`
- `apps/retro_hex_chat_web/assets/css/retrohex.css`
- `apps/retro_hex_chat_web/assets/js/hooks/ui/window_manager_hook.js`

## Baseline

Screenshots:

- `docs/plans/screenshots/flood-protection-audit/desktop-default.png`
- `docs/plans/screenshots/flood-protection-audit/desktop-edited.png`
- `docs/plans/screenshots/flood-protection-audit/mobile-default.png`
- `docs/plans/screenshots/flood-protection-audit/mobile-edited.png`

Achados:

- No mobile, abrir via Tools podia deslocar o workspace inteiro para a esquerda. A janela estava correta internamente, mas `#chat-desktop.scrollLeft` ficava em `101`, empurrando header, workspace, taskbar e dialog para fora da viewport.
- O form antigo usava fieldsets com labels e inputs em linhas rigidas. Em largura pequena, isso gerava corte lateral e botoes inacessiveis.
- No desktop, a janela antiga era alta demais para a densidade real do conteudo e o layout nao ajudava a escanear grupos de settings.
- Inputs numericos dentro de flex/grid podem encolher ate virar quase so o spinner nativo se nao tiverem `flex-basis`/`min-width` estaveis.

## Decisoes

- Corrigir a causa estrutural no `WindowManagerHook`: em modo stacked, o desktop zera scroll interno ao processar clique e ao recalcular responsividade.
- Adicionar guarda CSS em `.desktop--stacked` com `overflow: clip`, impedindo que o desktop vire um scroll container horizontal programatico no mobile.
- Recriar o body do Flood como form mobile-first unico, com classes locais `fp-*`.
- Manter a mesma interface para desktop e mobile: grupos, labels, controles e action row sao os mesmos; desktop apenas usa melhor a largura.
- Tornar inputs numericos controles fixos dentro do grupo (`flex: 0 0 ...`) para preservar leitura e evitar shrink.
- Ajustar geometria desktop padrao para `560x440`, deixando o dialog mais proporcional sem afetar o fullscreen mobile.

## Resultado

Screenshots refinados:

- `docs/plans/screenshots/flood-protection-refined/desktop-default.png`
- `docs/plans/screenshots/flood-protection-refined/desktop-edited.png`
- `docs/plans/screenshots/flood-protection-refined/mobile-default.png`
- `docs/plans/screenshots/flood-protection-refined/mobile-edited.png`

Entregue:

- Mobile abre em fullscreen stacked sem deslocamento horizontal.
- Desktop ficou mais largo e mais baixo, com grupos legiveis e sem vazio excessivo.
- Fieldsets preservam identidade Win98, mas agora usam rows responsivas.
- Save, Reset Defaults e Cancel ficam agrupados a direita.
- Eventos, nomes de campos, ids e fluxo funcional foram preservados.

## Validacao

- Passou: captura visual Flood Protection desktop/mobile em fluxo real via Tools.
- Passou: `rtk mix compile`.
- Passou: `rtk mix assets.build` em `apps/retro_hex_chat_web`.
- Passou: `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/flood_protection_dialog_test.exs --trace` (2 testes).
- Passou: `rtk npm --prefix e2e test -- --project=chromium tests/chat-flood-protection.spec.ts --reporter=list` (2 testes).
- Passou: `rtk npm --prefix e2e test -- --project=chromium tests/chat-tools-menu.spec.ts --reporter=list` (1 teste).
- Passou: `rtk npm --prefix e2e test -- --project=mobile-chrome tests/chat-mobile-desktop.spec.ts --reporter=list` (3 testes).

## Licoes Para O Playbook

- Overflow hidden ainda pode acumular `scrollLeft` programatico; no mobile stacked, o desktop root precisa ser tratado como nao rolavel.
- Quando um dialog e aberto por menu em mobile, o teste visual precisa medir o shell inteiro, nao apenas a janela.
- Forms de configuracao devem evitar label/input/unit em uma unica linha rigida; a unidade mental e o setting, nao a coluna.
- Inputs numericos precisam de dimensoes estaveis em flex para nao encolherem ate o spinner.
- Geometria desktop tambem faz parte da melhoria: depois de compactar o conteudo, uma janela antiga pode ficar grande demais.
