# Address Book Mobile Audit

Data: 2026-07-16

## Escopo

Aplicacao do `Dialog Mobile Playbook` no Address Book, incluindo as quatro tabs principais e os subdialogs de contatos, notify, cores de nick e control/ignore.

Arquivos principais:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/address_book.ex`
- `apps/retro_hex_chat_web/assets/css/retrohex.css`

## Baseline

Foi criado um spec temporario de Playwright que abre o Address Book com dados reais em Contacts, Notify, Nick Colors e Control. O mesmo fluxo capturou desktop e Pixel 5, incluindo subdialogs de add/edit.

Screenshots baseline:

- `docs/plans/screenshots/address-book-audit/desktop-contacts.png`
- `docs/plans/screenshots/address-book-audit/desktop-notify.png`
- `docs/plans/screenshots/address-book-audit/desktop-nick-colors.png`
- `docs/plans/screenshots/address-book-audit/desktop-control.png`
- `docs/plans/screenshots/address-book-audit/desktop-contact-add-dialog.png`
- `docs/plans/screenshots/address-book-audit/desktop-contact-edit-dialog.png`
- `docs/plans/screenshots/address-book-audit/desktop-notify-add-dialog.png`
- `docs/plans/screenshots/address-book-audit/desktop-nick-color-add-dialog.png`
- `docs/plans/screenshots/address-book-audit/desktop-control-add-dialog.png`
- `docs/plans/screenshots/address-book-audit/mobile-contacts.png`
- `docs/plans/screenshots/address-book-audit/mobile-notify.png`
- `docs/plans/screenshots/address-book-audit/mobile-nick-colors.png`
- `docs/plans/screenshots/address-book-audit/mobile-control.png`
- `docs/plans/screenshots/address-book-audit/mobile-contact-add-dialog.png`
- `docs/plans/screenshots/address-book-audit/mobile-contact-edit-dialog.png`
- `docs/plans/screenshots/address-book-audit/mobile-notify-add-dialog.png`
- `docs/plans/screenshots/address-book-audit/mobile-nick-color-add-dialog.png`
- `docs/plans/screenshots/address-book-audit/mobile-control-add-dialog.png`

Achados principais:

- Mobile usava tabela desktop encolhida; Contacts, Notify e Control ficavam legiveis apenas com esforco.
- Notify era o pior caso: `Last Seen` e note longa comprimiam a tabela e reduziam a leitura.
- Tabs cabiam por pouco em algumas telas, mas nao tinham affordance clara quando o usuario precisava rolar.
- Acoes Add/Edit/Remove estavam alinhadas a esquerda, diferente do padrao definido para dialogs.
- Subdialogs ja tinham titlebar/footer razoaveis, mas precisavam de validacao contra seletores mobile mais amplos.
- O teste amplo de teclado mostrou que o Address Book nao prendia foco de Tab dentro do dialog no primeiro ajuste.

## Implementacao

Decisao: usar classes locais `ab-*`, mantendo ids, eventos, test ids e fluxo funcional existente.

Mudancas no Address Book:

- Root do conteudo ganhou `ab-dialog`, `role="dialog"`, `aria-modal="false"`, foco inicial e `focus_wrap`.
- Tabs ganharam `ab-tabs-shell` e `ab-main-tabs`.
- Mobile usa tab strip horizontal com scrollbar fina, fade e indicadores `<`/`>` conforme a aba ativa.
- Contacts, Notify, Nick Colors e Control continuam tabela no desktop, mas viram cardlets no mobile.
- Cada linha mobile ganhou campo principal forte e metadados com label via `data-label`.
- Textos livres, notas e timestamps usam `overflow-wrap: anywhere` onde podem vir longos.
- Acoes Add/Edit/Remove e Control Add/Remove passaram a ficar alinhadas a direita.
- Primeiro e ultimo campos das tabelas ficam sem wrap no desktop para preservar a leitura compacta.
- Swatch de Nick Colors foi normalizado em uma unica classe interpolada para garantir que a cor renderize corretamente.

Mudancas nos subdialogs:

- Botoes de forms mobile ganharam area de toque mais confortavel sem afetar o botao de fechar da titlebar.
- Color picker ganhou swatches maiores no mobile.
- Inputs, selects e textareas usam `min-height: 40px` e fonte 16px no mobile para reduzir zoom involuntario do teclado.
- Textareas ganharam altura minima maior para notas reais.

## Resultado Visual

Screenshots refinados:

- `docs/plans/screenshots/address-book-refined/desktop-contacts.png`
- `docs/plans/screenshots/address-book-refined/desktop-notify.png`
- `docs/plans/screenshots/address-book-refined/desktop-nick-colors.png`
- `docs/plans/screenshots/address-book-refined/desktop-control.png`
- `docs/plans/screenshots/address-book-refined/desktop-contact-add-dialog.png`
- `docs/plans/screenshots/address-book-refined/desktop-contact-edit-dialog.png`
- `docs/plans/screenshots/address-book-refined/desktop-notify-add-dialog.png`
- `docs/plans/screenshots/address-book-refined/desktop-nick-color-add-dialog.png`
- `docs/plans/screenshots/address-book-refined/desktop-control-add-dialog.png`
- `docs/plans/screenshots/address-book-refined/mobile-contacts.png`
- `docs/plans/screenshots/address-book-refined/mobile-notify.png`
- `docs/plans/screenshots/address-book-refined/mobile-nick-colors.png`
- `docs/plans/screenshots/address-book-refined/mobile-control.png`
- `docs/plans/screenshots/address-book-refined/mobile-contact-add-dialog.png`
- `docs/plans/screenshots/address-book-refined/mobile-contact-edit-dialog.png`
- `docs/plans/screenshots/address-book-refined/mobile-notify-add-dialog.png`
- `docs/plans/screenshots/address-book-refined/mobile-nick-color-add-dialog.png`
- `docs/plans/screenshots/address-book-refined/mobile-control-add-dialog.png`

Melhorias observadas:

- Desktop preserva tabela compacta, sem transformar a experiencia operacional em layout mobile.
- Mobile deixa de depender de scroll horizontal em tabelas; cada entrada vira um item escaneavel.
- Notify agora mostra nick, status, note e last seen em bloco legivel.
- Nick Colors mostra swatch real tanto no desktop quanto no mobile.
- Tabs sinalizam continuidade; quando o usuario esta em Nick Colors ou Control, o lado esquerdo tambem indica que ha tabs anteriores.
- Botoes ficaram consistentemente alinhados a direita.
- Color picker mobile tem alvos maiores sem estourar a titlebar.
- O foco por Tab permanece dentro do Address Book.

## Validacao

Comandos executados:

```bash
rtk npm --prefix e2e test -- --project=chromium tests/address-book-audit.spec.ts --reporter=list
rtk env ADDRESS_BOOK_AUDIT_OUT_DIR=address-book-refined npm --prefix e2e test -- --project=chromium tests/address-book-audit.spec.ts --reporter=list
rtk mix format apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/address_book.ex
rtk mix compile
rtk npm --prefix e2e test -- --project=chromium tests/chat-address-book.spec.ts tests/chat-address-book-contacts.spec.ts tests/chat-address-book-colors.spec.ts tests/chat-address-book-control.spec.ts --reporter=list
rtk npm --prefix e2e test -- --project=chromium tests/chat-dialog-keyboard.spec.ts -g "Tab focus stays inside major dialogs" --reporter=list
```

Resultados:

- Captura visual baseline: passou.
- Captura visual refinada: passou.
- `mix format`: passou.
- `mix compile`: passou.
- Suite funcional de Address Book: `5 passed`.
- Teste de foco em dialogs principais: `1 passed`.

Observacao:

- A suite ampla `chat-dialog-keyboard.spec.ts` tambem expos uma falha fora do escopo em `Enter submits primary sub-dialog action and Escape discards drafts (T7)`, no Highlight Words. O gate usado para esta rodada foi o teste T8, que cobre o foco do Address Book e passou apos o `focus_wrap`.

## Aprendizados

- Desktop windows que atuam como dialogs tambem precisam declarar uma superficie focavel e prender foco; sem isso, Tab pode escapar mesmo quando a UI parece correta.
- Seletores mobile amplos para `button` sao perigosos em dialogs com titlebar e color picker. O seletor deve mirar action rows/forms, nao todos os botoes.
- Em tabelas preservadas no desktop, pode ser necessario proteger primeira/ultima coluna contra wrap para nao degradar a experiencia desktop enquanto o mobile vira cardlet.
- `class` duplicado em HEEx pode parecer inocuo, mas pode apagar a classe dinamica que representa informacao visual importante, como cor de nick.
- Address Book confirma que o playbook escala para dialogs com multiplas listas e subdialogs sem exigir mudanca global nos componentes.
