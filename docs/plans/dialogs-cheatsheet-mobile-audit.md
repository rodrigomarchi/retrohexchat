# Keyboard Shortcuts/Cheatsheet - Mobile/Desktop Audit

Data: 2026-07-16

## Escopo

Dialog: `Keyboard Shortcuts`

Arquivos principais:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/cheatsheet_dialog.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex`
- `apps/retro_hex_chat_web/assets/css/retrohex.css`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/cheatsheet_dialog_test.exs`

## Baseline

Screenshots:

- `docs/plans/screenshots/cheatsheet-audit/desktop-top.png`
- `docs/plans/screenshots/cheatsheet-audit/desktop-bottom.png`
- `docs/plans/screenshots/cheatsheet-audit/mobile-top.png`
- `docs/plans/screenshots/cheatsheet-audit/mobile-bottom.png`

Achados:

- O dialog usava tabela com colunas `Action`, `Keys` e `Description`.
- No desktop, a tabela era funcional, mas densa, cinza demais e com leitura fraca para descricoes longas.
- No mobile, as tres colunas competiam por largura. Acoes e descricoes quebravam em excesso, e atalhos longos como `Ctrl+Shift+ArrowRight` deixavam a leitura truncada/espremida.
- O conteudo e estatico e longo; o usuario precisa escanear por categoria e atalho, nao comparar colunas como em uma matriz.
- A abertura via menu Help no mobile nao foi um caminho estavel para auditoria: a barra superior fica parcialmente fora da area visivel em stacked mobile. O atalho `Ctrl+Shift+/` abriu o dialog de forma confiavel. Isso fica registrado como tema do shell/menu mobile, nao como defeito interno do Cheatsheet.

## Decisoes

- Substituir a tabela por uma lista unica mobile-first, usada tambem no desktop.
- Cada atalho virou uma entrada composta: acao forte, tecla em badge retro e descricao abaixo.
- Desktop usa grid de duas colunas quando ha largura, mantendo a mesma estrutura visual do mobile.
- Mobile mantem tecla na mesma linha da acao quando cabe e quebra naturalmente nos atalhos longos.
- Preservar contratos funcionais e de teste: `data-testid="cheatsheet-dialog"`, textos dos atalhos, categorias e abertura/fechamento existentes.
- Ajustar a janela para `600x500` e `min_width=360`, evitando largura minima artificial no modo stacked.
- Adicionar classes locais `cs-*` para nao vazar regras para outros dialogs.

## Resultado

Screenshots refinados:

- `docs/plans/screenshots/cheatsheet-refined/desktop-top.png`
- `docs/plans/screenshots/cheatsheet-refined/desktop-bottom.png`
- `docs/plans/screenshots/cheatsheet-refined/mobile-top.png`
- `docs/plans/screenshots/cheatsheet-refined/mobile-bottom.png`

Entregue:

- A leitura no desktop ficou mais rapida: duas colunas de entradas, sem headers repetitivos e com acao/tecla proximas.
- O mobile deixou de ser uma tabela comprimida e virou uma lista escaneavel.
- Atalhos longos de P2P quebram sem scroll horizontal e sem invadir a descricao.
- O dialog continua usando uma unica interface que escala entre mobile e desktop.
- O conteudo rolavel continua interno ao dialog e preserva a titlebar/taskbar.

## Validacao

- Passou: captura visual Keyboard Shortcuts desktop/mobile em fluxo real via `Ctrl+Shift+/`.
- Passou: `rtk mix compile`.
- Passou: `rtk mix assets.build` em `apps/retro_hex_chat_web`.
- Passou: `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/cheatsheet_dialog_test.exs --trace` (2 testes).
- Passou: `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/keyboard_shortcuts_test.exs --include liveview --trace` (9 testes).
- Passou: `rtk npm --prefix e2e test -- --project=chromium tests/chat-cheatsheet.spec.ts --reporter=list` (1 teste).
- Passou: `rtk npm --prefix e2e test -- --project=chromium tests/chat-keyboard.spec.ts --reporter=list` (1 teste).
- Passou: `rtk npm --prefix e2e test -- --project=chromium tests/chat-menu-toolbar-parity.spec.ts --reporter=list` (1 teste).

## Licoes Para O Playbook

- Conteudo de referencia longo nao deve usar tabela por padrao; se o usuario escaneia itens, lista composta costuma funcionar melhor no desktop e no mobile.
- Uma interface unica pode mudar densidade por largura sem mudar o modelo mental: uma ou duas colunas, mas sempre entradas com acao, tecla e descricao.
- Atalhos longos precisam de `overflow-wrap` e badges com `max-width: 100%`; `white-space` implicito em kbd pode criar overflow silencioso.
- Em mobile, forcar tudo em coluna pode resolver overflow, mas piorar densidade; deixar flex wrap decidir quando quebrar produziu melhor resultado.
- Auditoria de dialog tambem revela problemas de shell. O menu Help mobile nao foi caminho estavel para abrir o Cheatsheet, embora o dialog em si funcione via atalho.
