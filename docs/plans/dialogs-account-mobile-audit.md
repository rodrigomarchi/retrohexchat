# Account Mobile Audit

Data: 2026-07-16

## Escopo

Aplicacao do `Dialog Mobile Playbook` no Account, cobrindo Register/Login, Profile, Presence, User Modes e o fluxo expandido de Ghost Session.

Arquivos principais:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/account_dialog.ex`
- `apps/retro_hex_chat_web/assets/css/retrohex.css`

## Baseline

Foi criado um spec temporario de Playwright que abre o Account em usuario real registrado/identificado, derruba a registracao para capturar o estado de cadastro, expande Ghost Session e percorre Profile, Presence e User Modes. O fluxo foi capturado em desktop e Pixel 5.

Screenshots baseline:

- `docs/plans/screenshots/account-audit/desktop-register-identified.png`
- `docs/plans/screenshots/account-audit/desktop-register-unregistered.png`
- `docs/plans/screenshots/account-audit/desktop-ghost-expanded.png`
- `docs/plans/screenshots/account-audit/desktop-profile.png`
- `docs/plans/screenshots/account-audit/desktop-presence.png`
- `docs/plans/screenshots/account-audit/desktop-modes.png`
- `docs/plans/screenshots/account-audit/mobile-register-identified.png`
- `docs/plans/screenshots/account-audit/mobile-register-unregistered.png`
- `docs/plans/screenshots/account-audit/mobile-ghost-expanded.png`
- `docs/plans/screenshots/account-audit/mobile-profile.png`
- `docs/plans/screenshots/account-audit/mobile-presence.png`
- `docs/plans/screenshots/account-audit/mobile-modes.png`

Achados principais:

- Mobile ainda funcionava, mas era um formulario desktop estreito.
- Tabs cabiam parcialmente no Pixel 5; `User Modes` aparecia como icone parcial, sem indicador claro de rolagem.
- Profile tinha input + botao na mesma linha, mas o campo ficava comprimido no mobile.
- Presence usava input single-line para mensagem de away; mensagens reais longas ficavam truncadas.
- Botoes ja estavam majoritariamente a direita, mas os alvos eram pequenos para toque.
- Ghost Session cabia, mas ficava muito justo e precisava preservar o marcador nativo de `summary`.
- O dialog nao tinha uma superficie focavel/role propria para comportamento consistente de janela-dialog.

## Implementacao

Decisao: aplicar classes locais `acct-*`, preservando eventos, nomes de campos e `data-testid`s usados nos testes existentes.

Mudancas:

- Conteudo passou a ter wrapper `focus_wrap`, `role="dialog"`, `aria-modal="false"`, foco inicial e classe `acct-dialog`.
- Tabs ganharam `acct-tabs-shell` e `acct-main-tabs`.
- Mobile usa tab strip horizontal com scrollbar fina e indicadores `<`/`>` conforme a tab ativa.
- Action rows e action groups usam `acct-action-row`/`acct-action-group`, mantendo botoes alinhados a direita.
- Botoes de formulario ganharam `acct-action-button` para alvos mobile maiores sem atingir titlebar.
- Textos de estado, labels, mensagens e detalhes ganharam wrapping local.
- Profile ganhou linha de nickname flexivel e textarea/botoes com melhor comportamento responsivo.
- Presence trocou Away Message de input single-line para textarea com o mesmo `id`, `name` e `data-testid`.
- Inputs textuais e textareas ganharam altura/fonte mobile melhores, excluindo checkbox/radio para preservar o controle Win98.
- `summary` de Ghost Session manteve o marcador triangular nativo; o primeiro ajuste foi corrigido depois da screenshot refinada.
- O foco inicial no painel teve outline visual removido por CSS local para nao criar um contorno azul de navegador dentro da janela Win98.

## Resultado Visual

Screenshots refinados:

- `docs/plans/screenshots/account-refined/desktop-register-identified.png`
- `docs/plans/screenshots/account-refined/desktop-register-unregistered.png`
- `docs/plans/screenshots/account-refined/desktop-ghost-expanded.png`
- `docs/plans/screenshots/account-refined/desktop-profile.png`
- `docs/plans/screenshots/account-refined/desktop-presence.png`
- `docs/plans/screenshots/account-refined/desktop-modes.png`
- `docs/plans/screenshots/account-refined/mobile-register-identified.png`
- `docs/plans/screenshots/account-refined/mobile-register-unregistered.png`
- `docs/plans/screenshots/account-refined/mobile-ghost-expanded.png`
- `docs/plans/screenshots/account-refined/mobile-profile.png`
- `docs/plans/screenshots/account-refined/mobile-presence.png`
- `docs/plans/screenshots/account-refined/mobile-modes.png`

Melhorias observadas:

- Desktop continua denso, com tabs em uma linha e formularios compactos.
- Mobile agora mostra affordance de rolagem das tabs; `User Modes` deixa de parecer uma tab perdida.
- Profile ficou mais confortavel: input maior, textarea legivel e botoes com alvos melhores.
- Presence agora mostra mensagem de away longa em multiplas linhas.
- Checkboxes continuaram com o tratamento Win98 apos restringir a regra de input.
- Ghost Session preserva o marcador nativo e os campos ficam mais confortaveis.
- O foco programatico nao deixa contorno azul no painel.

## Validacao

Comandos executados:

```bash
rtk npm --prefix e2e test -- --project=chromium tests/account-audit.spec.ts --reporter=list
rtk mix format apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/account_dialog.ex
rtk mix compile
rtk env ACCOUNT_AUDIT_OUT_DIR=account-refined npm --prefix e2e test -- --project=chromium tests/account-audit.spec.ts --reporter=list
rtk npm --prefix e2e test -- --project=chromium tests/chat-ui-features-shell.spec.ts -g "Account dialog covers registration, profile, presence, and user modes" --reporter=list
```

Resultados:

- Captura visual baseline: passou.
- `mix format`: passou.
- `mix compile`: passou.
- Captura visual refinada: passou.
- Gate funcional Account Feature 01: `1 passed`.

## Aprendizados

- Para formularios mobile, aumentar `input` genericamente quebra checkbox/radio. O seletor precisa excluir controles binarios.
- `summary` perde marcador nativo quando recebe `display: flex`; preferir `line-height`/padding quando o marcador importa.
- Foco programatico em uma superficie `tabindex="0"` pode produzir outline de navegador. A janela pode manter foco sem expor contorno visual fora do sistema Win98.
- Mensagens que naturalmente sao frases, como Away Message, devem ser textarea; manter input single-line preserva a feature, mas degrada a UX real.
- Account confirmou que o playbook tambem cobre dialogs sem tabelas: tabs, forms densos, action rows e teclado/foco ainda sao suficientes para achar problemas reais.
