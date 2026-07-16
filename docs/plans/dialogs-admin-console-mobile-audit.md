# Admin Console Mobile Audit

Data: 2026-07-16

## Escopo

Aplicacao do `Dialog Mobile Playbook` no Admin Console, depois da rodada do Channel Central.

Arquivos principais:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/admin_console_dialog.ex`
- `apps/retro_hex_chat_web/assets/css/retrohex.css`

## Baseline

Foi criado um spec temporario de Playwright para capturar as nove tabs do Admin Console em desktop e Pixel 5.

Screenshots baseline:

- `docs/plans/screenshots/admin-console-audit/desktop-server_settings.png`
- `docs/plans/screenshots/admin-console-audit/desktop-users.png`
- `docs/plans/screenshots/admin-console-audit/desktop-channels.png`
- `docs/plans/screenshots/admin-console-audit/desktop-motd.png`
- `docs/plans/screenshots/admin-console-audit/desktop-broadcast.png`
- `docs/plans/screenshots/admin-console-audit/desktop-audit_log.png`
- `docs/plans/screenshots/admin-console-audit/desktop-turn.png`
- `docs/plans/screenshots/admin-console-audit/desktop-danger_zone.png`
- `docs/plans/screenshots/admin-console-audit/desktop-console.png`
- `docs/plans/screenshots/admin-console-audit/mobile-server_settings.png`
- `docs/plans/screenshots/admin-console-audit/mobile-users.png`
- `docs/plans/screenshots/admin-console-audit/mobile-channels.png`
- `docs/plans/screenshots/admin-console-audit/mobile-motd.png`
- `docs/plans/screenshots/admin-console-audit/mobile-broadcast.png`
- `docs/plans/screenshots/admin-console-audit/mobile-audit_log.png`
- `docs/plans/screenshots/admin-console-audit/mobile-turn.png`
- `docs/plans/screenshots/admin-console-audit/mobile-danger_zone.png`
- `docs/plans/screenshots/admin-console-audit/mobile-console.png`

Achados principais:

- Mobile tinha tabs em tres linhas, sem affordance de rolagem.
- As tabs consumiam espaco vertical em todas as abas.
- Users e Channels tinham bons blocos funcionais, mas dependiam de layout desktop empilhado.
- Outputs `pre` funcionavam, mas precisavam de regras mais fortes de wrapping/scroll.
- Botoes principais ja estavam majoritariamente a direita, mas faltava padrao responsivo para forms inline.

## Implementacao

Decisao: usar classes locais `ac-*` e CSS escopado por `.ac-dialog`, sem alterar ids, nomes de campos, eventos ou roles globais.

Mudancas:

- Root windowed ganhou `ac-dialog`.
- Scroll interno ganhou `ac-scroll`.
- Tabs ganharam wrapper `ac-main-tabs-shell` e lista `ac-main-tabs`.
- Mobile usa tab strip horizontal com `overflow-x`, scrollbar fina e indicador `>` no lado direito.
- Inputs, selects, textareas, `pre` e resultados inline ganharam regras locais de `min-width: 0` e wrapping.
- Forms inline no mobile usam grid `minmax(0, 1fr) auto`, mantendo input + acao na mesma linha quando couber.
- Botoes diretos de forms inline ficam na coluna direita.
- Grids internos ficam single-column no mobile, preservando desktop.
- Cards administrativos com `shadow-retro-sunken` ficam em coluna, com inputs full-width no mobile.
- Outputs mantem scroll interno e melhor leitura no mobile.

## Resultado Visual

Screenshots refinados:

- `docs/plans/screenshots/admin-console-refined/desktop-server_settings.png`
- `docs/plans/screenshots/admin-console-refined/desktop-users.png`
- `docs/plans/screenshots/admin-console-refined/desktop-channels.png`
- `docs/plans/screenshots/admin-console-refined/desktop-motd.png`
- `docs/plans/screenshots/admin-console-refined/desktop-broadcast.png`
- `docs/plans/screenshots/admin-console-refined/desktop-audit_log.png`
- `docs/plans/screenshots/admin-console-refined/desktop-turn.png`
- `docs/plans/screenshots/admin-console-refined/desktop-danger_zone.png`
- `docs/plans/screenshots/admin-console-refined/desktop-console.png`
- `docs/plans/screenshots/admin-console-refined/mobile-server_settings.png`
- `docs/plans/screenshots/admin-console-refined/mobile-users.png`
- `docs/plans/screenshots/admin-console-refined/mobile-channels.png`
- `docs/plans/screenshots/admin-console-refined/mobile-motd.png`
- `docs/plans/screenshots/admin-console-refined/mobile-broadcast.png`
- `docs/plans/screenshots/admin-console-refined/mobile-audit_log.png`
- `docs/plans/screenshots/admin-console-refined/mobile-turn.png`
- `docs/plans/screenshots/admin-console-refined/mobile-danger_zone.png`
- `docs/plans/screenshots/admin-console-refined/mobile-console.png`

Melhorias observadas:

- Tabs mobile deixam de quebrar em varias linhas.
- O indicador `>` torna a rolagem de tabs descobrivel.
- Users e Channels preservam densidade, com botoes alinhados no eixo direito.
- Console fica estavel: output grande, input e Run em linha.
- Desktop permaneceu compacto e com layout original preservado.

## Validacao

Comandos executados:

```bash
rtk mix format apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/admin_console_dialog.ex
rtk mix compile
rtk npm --prefix e2e test -- --project=mobile-chrome tests/admin-console-mobile-audit.spec.ts --reporter=list
rtk npm --prefix e2e test -- --project=chromium tests/chat-admin-users.spec.ts tests/chat-admin-channels.spec.ts tests/chat-admin-audit-log.spec.ts tests/chat-admin-extended.spec.ts tests/chat-admin-channel-destructive.spec.ts tests/chat-admin-nuke.spec.ts tests/chat-admin-diagnostics.spec.ts --reporter=list
rtk npm --prefix e2e test -- --project=chromium tests/chat-ui-features-admin.spec.ts --reporter=list
```

Resultados:

- `mix format`: passou.
- `mix compile`: passou.
- Captura visual Admin Console: `1 passed` com spec temporario, removido apos gerar screenshots.
- Suíte admin funcional focada: `14 passed`.
- `chat-ui-features-admin.spec.ts`: falhou em ponto preexistente. O teste procura o botao `Start solo arcade` dentro de `#admin-console-server-settings-form`, mas esse botao nao aparece na UI atual.

## Proximos Aprendizados

- O padrao de tabs do Channel Central escalou bem para um dialog com nove tabs.
- Regras locais por root (`.ac-dialog`) reduzem bastante o custo de aplicar o playbook dialog por dialog.
- Forms inline precisam preservar densidade; forcar uma coluna no mobile pode criar espaco morto.
- Admin Console confirmou que o playbook pode ser aplicado com baixo risco quando ids/eventos sao mantidos.
