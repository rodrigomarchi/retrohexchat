# Bot Management Mobile Audit

Data: 2026-07-16

## Escopo

Aplicacao do `Dialog Mobile Playbook` no Bot Management e nos child dialogs de bot.

Arquivos principais:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/bot_management_dialog.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/bot_form_dialog.ex`
- `apps/retro_hex_chat_web/assets/css/retrohex.css`

## Baseline

Foi criado um spec temporario de Playwright que abre o Bot Management com um bot real, canal real e comando real, capturando desktop e Pixel 5.

Screenshots baseline:

- `docs/plans/screenshots/bot-management-audit/desktop-general.png`
- `docs/plans/screenshots/bot-management-audit/desktop-capabilities.png`
- `docs/plans/screenshots/bot-management-audit/desktop-channels.png`
- `docs/plans/screenshots/bot-management-audit/desktop-commands.png`
- `docs/plans/screenshots/bot-management-audit/desktop-events.png`
- `docs/plans/screenshots/bot-management-audit/desktop-new-bot-dialog.png`
- `docs/plans/screenshots/bot-management-audit/desktop-add-command-dialog.png`
- `docs/plans/screenshots/bot-management-audit/mobile-general.png`
- `docs/plans/screenshots/bot-management-audit/mobile-capabilities.png`
- `docs/plans/screenshots/bot-management-audit/mobile-channels.png`
- `docs/plans/screenshots/bot-management-audit/mobile-commands.png`
- `docs/plans/screenshots/bot-management-audit/mobile-events.png`
- `docs/plans/screenshots/bot-management-audit/mobile-new-bot-dialog.png`
- `docs/plans/screenshots/bot-management-audit/mobile-add-command-dialog.png`

Achados principais:

- Mobile era um split-view desktop empilhado, mas sem tratar tabelas densas como listas.
- Channels e Commands dependiam de tabela horizontal; em Commands a resposta longa ficava cortada.
- Tabs nao cabiam no Pixel 5 e precisavam de affordance clara de scroll.
- Acoes principais ja existiam, mas precisavam alinhar consistentemente a direita.
- Child dialogs de New Bot e Add Command precisavam respeitar titlebar, footer e taskbar no mobile.
- O baseline descobriu um bug funcional: Channels podia crashar com `Phoenix.HTML.Safe not implemented for RetroHexChat.Bots.BotChannelConfig`, porque o fallback tentava renderizar a struct inteira.

## Implementacao

Decisao: aplicar classes locais `bm-*`, sem mudar nomes de eventos, ids de campos, test ids ou o contrato dos comandos existentes.

Mudancas no Bot Management:

- Root windowed ganhou `bm-dialog`; scroll interno ganhou `bm-scroll`.
- Split desktop foi preservado, mas mobile usa layout stacked com lista de bots, acoes e detalhes em fluxo vertical.
- Tabs ganharam `bm-tabs-shell` e `bm-main-tabs`.
- Mobile usa tab strip horizontal com scrollbar fina, fade e indicador `>`; para abas deslocadas a direita, tambem mostra indicador `<`.
- Channels e Commands viraram listas/cardlets no mobile, mantendo tabela no desktop.
- Campos principais das listas ganharam destaque; metadados recebem label via `data-label`.
- Textos longos usam `overflow-wrap: anywhere` e removem truncamento no mobile onde a leitura importa.
- Acoes destrutivas e botoes Add/New/Delete ficam alinhados a direita.
- Events usa lista empilhada no mobile, com timestamp e mensagem quebrando corretamente.
- Capabilities recebeu wrappers locais para labels/configs quebrarem sem gerar overflow.

Mudancas nos child dialogs:

- `new_bot_dialog` e `add_command_dialog` passaram a usar `scope={:window}`.
- Forms ganharam `flex min-h-0 flex-1 flex-col`, preservando header e footer e deixando apenas o body rolar.
- Footers usam `bm-form-footer` e botoes continuam alinhados a direita.
- Inputs mobile ficam com altura confortavel e fonte 16px para evitar zoom do teclado.
- O ajuste evitou que o footer ficasse atras da taskbar mobile.

Bug funcional corrigido:

- Channels agora usa `bot_channel_name/1` para renderizar e preencher `phx-value-channel`.
- `channel_status/1` passou a tratar maps/structs com `:status`, `enabled: false` e fallback `"joined"`.

## Resultado Visual

Screenshots refinados:

- `docs/plans/screenshots/bot-management-refined/desktop-general.png`
- `docs/plans/screenshots/bot-management-refined/desktop-capabilities.png`
- `docs/plans/screenshots/bot-management-refined/desktop-channels.png`
- `docs/plans/screenshots/bot-management-refined/desktop-commands.png`
- `docs/plans/screenshots/bot-management-refined/desktop-events.png`
- `docs/plans/screenshots/bot-management-refined/desktop-new-bot-dialog.png`
- `docs/plans/screenshots/bot-management-refined/desktop-add-command-dialog.png`
- `docs/plans/screenshots/bot-management-refined/mobile-general.png`
- `docs/plans/screenshots/bot-management-refined/mobile-capabilities.png`
- `docs/plans/screenshots/bot-management-refined/mobile-channels.png`
- `docs/plans/screenshots/bot-management-refined/mobile-commands.png`
- `docs/plans/screenshots/bot-management-refined/mobile-events.png`
- `docs/plans/screenshots/bot-management-refined/mobile-new-bot-dialog.png`
- `docs/plans/screenshots/bot-management-refined/mobile-add-command-dialog.png`

Melhorias observadas:

- Desktop continua compacto, com split-view e subdialogs centralizados sobre a janela.
- Mobile nao tem tabela espremida nem scroll horizontal como caminho principal.
- Tabs sinalizam overflow, inclusive quando a aba ativa desloca a faixa para a direita.
- New Bot abre com titlebar visivel e footer acionavel acima da taskbar.
- Add Command abre como subdialog de janela, com contexto do Bot Management escurecido atras.
- O dialog suporta texto real de canal/comando sem quebrar a tela.

## Validacao

Comandos executados:

```bash
rtk mix format apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/bot_management_dialog.ex apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/bot_form_dialog.ex
rtk mix compile
rtk npm --prefix e2e test -- --project=chromium tests/bot-management-audit.spec.ts --reporter=list
rtk env MIX_ENV=e2e PGPORT=5433 mix run -e 'alias RetroHexChat.Bots.{Lifecycle, Queries}; Queries.list_bots() |> Enum.filter(&String.starts_with?(&1.name, "bmaudit")) |> Enum.each(fn bot -> IO.puts("destroy #{bot.name}"); Lifecycle.destroy_bot(bot) end)'
rtk npm --prefix e2e test -- --project=chromium tests/chat-bots.spec.ts tests/chat-bot-edges.spec.ts tests/chat-bot-persistence.spec.ts tests/chat-bot-channel-membership.spec.ts tests/chat-bot-custom-command-edges.spec.ts --reporter=list
rtk npm --prefix e2e test -- --project=chromium tests/chat-ui-features-shell.spec.ts -g "Notify List and Bot Management are reachable" --reporter=list
```

Resultados:

- `mix format`: passou.
- `mix compile`: passou.
- Captura visual Bot Management: passou apos ajustes, com spec temporario removido ao final.
- Limpeza E2E: removeu bots temporarios `bmaudit*` de execucoes falhas.
- Suite funcional de bots: `8 passed`.
- Reachability UI de Notify List + Bot Management: `1 passed`.

## Aprendizados

- Subdialogs dentro de desktop windows devem preferir `scope={:window}` quando a taskbar mobile permanece visivel.
- Form em dialog com header/footer precisa ser flex column; caso contrario o foco do primeiro input pode rolar o container externo e esconder o titlebar.
- Tabela desktop pode virar cardlet mobile sem alterar evento se `phx-value-*` receber valor normalizado.
- Screenshots pegaram dois problemas que testes funcionais isolados nao veriam: tab overflow sem affordance e footer atras da taskbar.
- O playbook deve tratar tabs com overflow bidirecional quando a aba ativa desloca a faixa.
