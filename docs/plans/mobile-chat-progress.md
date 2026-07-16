# Progresso - Mobile Chat

## Objetivo

Implementar, validar e documentar as melhorias mobile relacionadas ao fluxo principal de chat: shell, viewport, sidebars, abas, input/composer e interacoes de toque.

## Escopo Inicial

- Alinhar breakpoints entre cliente, servidor e UI.
- Melhorar deteccao de viewport e comportamento ao alternar entre mobile e desktop.
- Tornar o acesso mobile a conversas e nicklist explicito no header.
- Reduzir risco de controles pequenos ou inacessiveis em telas touch.
- Validar com testes automatizados focados no comportamento mobile do chat.

## Fora do Escopo Deste Ciclo

- Reescrever todos os modais/dialogos do produto.
- Redesenhar a arquitetura completa de janelas.
- Alterar regras de negocio de IRC, conexao, autenticacao ou persistencia.

## Registro de Progresso

- 2026-07-15: Criado arquivo de acompanhamento. Estado inicial observado: somente o documento de auditoria mobile esta pendente no git.
- 2026-07-15: Auditoria de codigo do chat concluida para o primeiro ciclo. Pontos confirmados: breakpoint JS do WindowManager em 720px, LiveView em 768px, `ViewportDetectHook` sem listener de resize, slot mobile do header nao utilizado, sidebars com overlay ja existentes, alvos de toque pequenos em abas/listas/controles e menus de contexto dependentes de clique direito.
- 2026-07-15: Implementado primeiro ciclo mobile-chat:
  - Breakpoint do `WindowManagerHook` alinhado para 768px.
  - `ViewportDetectHook` passou a atualizar CSS variables de visual viewport e reenviar `viewport_info` em mudancas relevantes.
  - LiveView passou a marcar/desmarcar `mobile_viewport` e restaurar sidebars ao voltar para desktop.
  - Header do chat ganhou botoes mobile para conversas e nicklist.
  - Shell passou a usar `chat-app-root` com altura de visual viewport.
  - CSS do modo `desktop--stacked` ampliou alvos de toque em header, abas, sidebars, mensagens, composer, taskbar e botao X de janelas.
  - Long-press em mensagens, nicklist e conversas agora abre os mesmos context menus do clique direito.
  - Selecionar canal/PM/status em mobile fecha os paineis de navegacao para devolver foco ao chat.
- 2026-07-15: Durante o e2e, descoberto que o servidor e2e serve `priv/static/assets/css/retrohex.css`; apos editar `assets/css/retrohex.css`, foi necessario rodar `mix assets.build` para regenerar o CSS estatico local antes do Playwright refletir as novas regras.
- 2026-07-16: Implementado segundo ciclo mobile-chat, focado no fluxo de mensagem e nas superficies que competem com o teclado:
  - Header do chat ganhou atalho mobile para busca (`chat-mobile-search`), junto de conversas e nicklist.
  - Abrir busca em viewport mobile agora fecha conversas/nicklist para devolver foco ao chat.
  - Textarea do composer passou a usar limite menor em mobile: 3 linhas abaixo de 768px, 5 linhas em desktop.
  - Hook de autocomplete passou a recalcular o limite em resize/orientacao e limpar listeners no destroy.
  - Busca, autocomplete, syntax tooltip, reply bar e emoji picker receberam limites de altura e alvos de toque melhores no modo `desktop--stacked`.
  - Sidebars mobile passaram a usar `chat-sidebar-overlay` com offset abaixo do header, evitando que o backdrop bloqueie os botoes globais do header.
  - E2E mobile passou a cobrir abertura de busca pelo header, fechamento implicito da nicklist ao buscar, autocomplete por `/` e altura do dropdown.
- 2026-07-16: Durante o e2e do segundo ciclo, foi encontrado um problema real de camada: com a nicklist aberta, o backdrop `fixed inset-0` interceptava o toque no botao de busca do header. A primeira tentativa de subir o z-index do header resolveu esse toque, mas criou uma regressao em que o header interceptava o botao de fechar da sidebar e itens de menu. A solucao final foi manter as camadas naturais e fazer os overlays mobile iniciarem abaixo do header.
- 2026-07-16: Implementado terceiro ciclo mobile-chat, focado em reply/edit/emoji:
  - O emoji picker agora tem entrada mobile no composer: o botao de emoji fica visivel abaixo de `md`, enquanto os demais botoes de formatacao continuam desktop-first.
  - O botao mobile de emoji recebeu hit area de 40px.
  - Mensagens proprias ganharam acao `Edit` no menu de contexto, alem de Reply/Delete.
  - O LiveView passou a aceitar `edit_message` por `message_id`, reaproveitando a mesma politica de permissao do `ArrowUp`.
  - Long-press mobile em mensagem agora cobre o caminho pratico para Reply/Edit sem teclado fisico.
  - O botao de dispensar reply subiu de 32px para 36px no modo `desktop--stacked`.
  - Criado `e2e/tests/chat-mobile-message-flow.spec.ts` com perfil Pixel 5, cobrindo emoji, long-press, reply, edit e tag de edicao.
- 2026-07-16: Durante o e2e do terceiro ciclo, foram encontrados dois detalhes reais: o helper de teste estava mirando um filho `.chat-message`, mas a classe fica no proprio stream row; e o dismiss da reply bar ainda estava menor que o alvo minimo pratico adotado para mobile.
- 2026-07-16: Implementado quarto ciclo mobile-chat, focado em fechar os fluxos touch restantes do chat core:
  - Playwright ganhou projeto dedicado `mobile-chrome`, com perfil Pixel 5 e `testMatch` restrito a specs mobile.
  - O projeto desktop `chromium` passou a ignorar specs `*mobile*.spec.ts`, evitando duplicacao da suite.
  - `chat-mobile-message-flow.spec.ts` passou a cobrir delete com cancel/confirm por long-press, PM aberta via long-press na nicklist, reply/edit/delete dentro de PM e long-press em nicklist/conversas.
  - O teste de delete passou a usar canal unico para evitar historico persistido do `#lobby`.
  - Corrigido bug funcional de PM: `:pm_activity` agora abre uma aba de PM em background para mensagens privadas comuns, sem roubar foco. Antes, PM recebida por uma conversa iniciada via Query/context menu podia ficar apenas como atividade/sidebar e nao aparecer como aba no destinatario.
  - Testes LiveView de persistencia/navegacao foram atualizados para o novo contrato: PM activity abre aba, mantem unread e nao seleciona automaticamente.
- 2026-07-16: Implementado quinto ciclo mobile-chat, focado em teclado virtual realista:
  - `ViewportDetectHook` passou a observar `visualViewport.resize`, `visualViewport.scroll`, `focusin` e `focusout`.
  - O hook agora calcula altura, largura, `offsetTop`, `offsetLeft` e `keyboardInset`, expondo tudo como CSS variables no `:root`.
  - A classe global `rhc-keyboard-open` so e ativada em viewport mobile quando existe foco editavel e o inset inferior passa de 80px. Isso evita tratar barras de navegador/resize sem input como teclado aberto.
  - `chat-app-root` passou a seguir largura, altura e offsets do visual viewport, reduzindo risco de input coberto por teclado ou deslocamento lateral em navegadores moveis.
  - Com `rhc-keyboard-open`, a taskbar e o Start menu do modo empilhado ficam ocultos para devolver altura ao chat.
  - Autocomplete, syntax tooltip e emoji picker ganharam limites ainda menores quando o teclado esta aberto, para nao competir com o composer.
  - Cobertura adicionada em unit test do hook e em E2E mobile que valida o contrato visual de esconder taskbar e expandir workspace durante teclado aberto.

## Estado Atual do Chat Core

O chat core em mobile emulado esta coberto para: shell empilhado, header mobile, sidebars, busca, autocomplete, emoji, reply, edit, delete, PM, long-press em mensagens/nicklist/conversas, contrato de teclado via `visualViewport` e regressao desktop dos mesmos contratos.

Para o chat core, o codigo e a automacao agora cobrem o comportamento esperado inclusive quando o teclado reduz o visual viewport. A declaracao "finalizado de fato em celular" ainda depende de uma passada manual em iOS/Android fisico, porque Playwright/Chromium em desktop nao abre o teclado nativo do sistema.

Ainda nao e correto declarar o produto mobile completo. Continuam pendentes: Safari/WebKit mobile, dialogos densos, P2P/midia/jogos/space e QA em dispositivos fisicos.

## Aprendizados

- O documento `docs/plans/mobile-readiness-audit.md` identifica o chat como a area de maior impacto mobile.
- A implementacao atual ja possui sinais mobile, mas eles aparecem distribuidos entre hooks JS, LiveView e classes responsivas, o que exige alinhar contratos antes de mexer em UI.
- A tela principal do chat ja roda dentro do `WindowManagerHook`; portanto, a correcao de maior impacto e estabilizar o modo `desktop--stacked` em vez de redesenhar o shell inteiro.
- As sidebars de conversas e nicklist ja usam backdrop em mobile. O problema principal e a descoberta/acesso pelo usuario e a preservacao de estado ao cruzar breakpoints.
- O CSS fonte e o CSS servido localmente podem divergir em e2e. Para validar layout apos mexer em CSS, rodar `mix assets.build` antes do Playwright ou garantir watcher ativo.
- `chat-app-root` deve manter `inset-0` no markup como fallback estrutural; o CSS atualizado troca `bottom` para `auto` quando as variaveis de visual viewport estao disponiveis.
- Em mobile, sidebars `fixed inset-0` dentro do chat nao devem cobrir o header se o header possui acoes globais de navegacao. O melhor contrato local e: header sempre acessivel, overlays laterais ocupam a area abaixo dele.
- Resolver sobreposicao com z-index amplo e arriscado neste shell, porque o header, menubar, workspace e sidebars compartilham o mesmo desktop manager. Preferir ajustar geometria/escopo da camada que esta cobrindo a tela.
- Busca/autocomplete/emoji/reply precisam ser tratados como superficies do composer em mobile: limites de altura e scroll interno evitam que uma lista auxiliar consuma a tela toda.
- Ainda falta validar teclado virtual real em iOS/Android. O E2E atual cobre viewport e toque, mas nao garante comportamento identico com teclado nativo aberto.
- Funcionalidades historicamente acionadas por teclado, como editar a ultima mensagem via `ArrowUp`, precisam de uma entrada touch equivalente. No mobile, long-press/context menu passa a ser o caminho minimo viavel para essas acoes.
- E melhor manter a toolbar de formatacao completa desktop-first e expor no mobile apenas a acao essencial de emoji; trazer todos os botoes de B/I/U/cor para uma linha de telefone competiria com o composer e reduziria a area de escrita.
- Specs mobile podem usar um device profile local (`Pixel 5`) sem ainda transformar a configuracao global do Playwright. Isso reduz risco de rodar toda a suite desktop em layout mobile antes dos dialogos estarem prontos.
- PM recebida precisa abrir uma superficie acionavel, nao apenas aparecer na sidebar. O contrato final ficou: `pm_activity` abre aba em background, marca unread quando nao ativa e nao rouba foco.
- Testes E2E de chat nao devem depender do estado do `#lobby`, porque mensagens e placeholders deletados podem persistir entre execucoes locais. Fluxos destrutivos devem usar canais unicos.
- Separar specs mobile em um projeto Playwright dedicado deixa a matriz explicita e evita rodar todos os testes desktop em viewport mobile antes de dialogos e recursos avancados estarem prontos.
- Teclado virtual deve ser inferido por combinacao de `visualViewport` reduzido e foco editavel. Usar apenas resize gera falsos positivos por barra de navegador, orientacao ou viewport emulado.
- Em chat fullscreen, esconder a taskbar enquanto o teclado esta aberto e mais valioso que preservar o switcher visivel: o recurso escasso nesse momento e altura para mensagens/composer.
- A automacao consegue provar o contrato do hook e do CSS, mas nao substitui device QA para teclado nativo. O criterio final precisa incluir Android Chrome e iOS Safari reais.

## Validacoes

- Concluido: leitura dos arquivos de chat principais (`chat_live.html.heex`, `ChatShell`, `ChatAppHeader`, `MenuToolbarEvents`, sidebars, abas, composer, hooks de viewport/window/conversas/nicklist/scroll).
- Passou: `npm --prefix apps/retro_hex_chat_web/assets test -- --run test/hooks/ui/viewport_detect_hook.test.js test/hooks/ui/window_manager_hook.test.js test/hooks/ui/conversations_hook.test.js test/hooks/ui/nicklist_hook.test.js test/hooks/chat/scroll_hook.test.js` (108 testes).
- Passou: `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/chat_shell_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_desktop_shell_test.exs` (19 testes).
- Passou: `mix assets.build` para atualizar o CSS estatico usado no e2e local.
- Passou: `npm --prefix e2e test -- tests/chat-mobile-desktop.spec.ts --reporter=list` (2 testes).
- Passou: `npm --prefix apps/retro_hex_chat_web/assets run lint`.
- Passou: `mix compile --warnings-as-errors`.
- Passou: `npm --prefix apps/retro_hex_chat_web/assets test -- --run test/hooks/chat/autocomplete_hook.test.js` (36 testes).
- Passou: `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/chat_shell_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/search_highlight_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/search_bar_test.exs` (28 testes).
- Passou: `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/conversations_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/nicklist_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/chat_shell_test.exs` (16 testes).
- Passou: `mix assets.build` apos mudancas CSS/JS do segundo ciclo.
- Passou: `npm --prefix e2e test -- tests/chat-mobile-desktop.spec.ts --reporter=list` (2 testes) apos corrigir a camada das sidebars.
- Passou: `npm --prefix apps/retro_hex_chat_web/assets run lint`.
- Passou: `mix compile --warnings-as-errors`.
- Passou: `git diff --check`.
- Passou: `npm --prefix apps/retro_hex_chat_web/assets test -- --run test/hooks/ui/viewport_detect_hook.test.js test/hooks/ui/window_manager_hook.test.js test/hooks/ui/conversations_hook.test.js test/hooks/ui/nicklist_hook.test.js test/hooks/chat/scroll_hook.test.js test/hooks/chat/autocomplete_hook.test.js test/hooks/chat/format_toolbar_hook.test.js` (148 testes).
- Passou: `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/user_context_menus_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/chat_shell_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/message_row_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_desktop_shell_test.exs` (43 testes).
- Passou: `mix assets.build` apos mudancas CSS/Elixir do terceiro ciclo.
- Passou: `npm --prefix e2e test -- tests/chat-mobile-desktop.spec.ts tests/chat-mobile-message-flow.spec.ts --reporter=list` (4 testes).
- Passou: `npm --prefix e2e test -- tests/chat-message-actions.spec.ts tests/chat-emoji.spec.ts --reporter=list` (5 testes).
- Passou: `npm --prefix apps/retro_hex_chat_web/assets run lint`.
- Passou: `mix compile --warnings-as-errors`.
- Passou: `git diff --check`.
- Passou: `npm --prefix e2e test -- --project=mobile-chrome --reporter=list` (7 testes).
- Passou: `npm --prefix e2e test -- --project=chromium tests/chat-pm.spec.ts tests/chat-message-actions.spec.ts tests/chat-context-menus.spec.ts --reporter=list` (10 testes).
- Passou: `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/session_persistence_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/window_navigation_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/visual_notifications_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/sound_dispatch_test.exs` (40 testes).
- Passou: `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_desktop_shell_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/chat_shell_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/user_context_menus_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/chat_tabs_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/message_row_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/messaging_ui_feature_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/composer_placeholder_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/autocomplete_test.exs` (67 testes, 6 excluidos por tag).
- Passou: `npm test --prefix apps/retro_hex_chat_web/assets` (139 arquivos, 3875 testes).
- Passou: `npm run lint:hooks --prefix apps/retro_hex_chat_web/assets`.
- Passou: `npm run lint --prefix apps/retro_hex_chat_web/assets`.
- Passou: `npm run format:check --prefix apps/retro_hex_chat_web/assets`.
- Passou: `mix format --check-formatted`.
- Passou: `make format.e2e.check`.
- Passou: `mix compile --warnings-as-errors`.
- Passou: `npm test --prefix apps/retro_hex_chat_web/assets -- --run test/hooks/ui/viewport_detect_hook.test.js test/hooks/ui/window_manager_hook.test.js test/hooks/chat/autocomplete_hook.test.js` (107 testes).
- Passou: `npm --prefix e2e test -- --project=mobile-chrome --reporter=list` (8 testes).
- Passou: `npm test --prefix apps/retro_hex_chat_web/assets -- --run` (139 arquivos, 3876 testes).
- Passou: `npm --prefix e2e test -- --project=chromium tests/chat-pm.spec.ts tests/chat-message-actions.spec.ts tests/chat-context-menus.spec.ts --reporter=list` (10 testes).
- Passou: `npm run lint --prefix apps/retro_hex_chat_web/assets`.
- Passou: `npm run format:check --prefix apps/retro_hex_chat_web/assets`.
- Passou: `make format.e2e.check`.
- Passou: `mix format --check-formatted`.
- Passou: `mix compile --warnings-as-errors`.
- Passou: `git diff --check`.
- Bloqueado fora do escopo: `./node_modules/.bin/tsc --noEmit` em `e2e/` falha por erro preexistente em `tests/chat-group-call.spec.ts:303` (`Property 'frameCount' does not exist on type 'never'`).

## Pendencias Fora do Chat Core Emulado

- Fazer QA final do teclado virtual em Android Chrome e iOS Safari fisicos, incluindo foco no composer, autocomplete, emoji, reply/edit e recebimento de mensagens com teclado aberto.
- Revisar os primeiros dialogos de uso frequente: Channel List, URL Catcher, Timers, Highlight Words e Account.
- Expandir a matriz para Mobile Safari/WebKit e landscape.
- Validar P2P, chamada em grupo, file transfer, jogos e Space em touch.
- Resolver o erro TypeScript preexistente em `e2e/tests/chat-group-call.spec.ts:303` para reabilitar `tsc --noEmit` como check limpo.
