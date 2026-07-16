# Channel Central Mobile Audit

Data: 2026-07-16

## Escopo

Auditoria visual e estrutural do dialog Channel Central antes de implementar ajustes. O objetivo foi sair da suposicao e usar o app real com Playwright em desktop e mobile, comparando as telas com a implementacao.

Dialog auditado:

- Janela: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex`
- Componente stateful: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/channel_central_dialog.ex`
- UI: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/channel_central_dialog.ex`
- Tabs base: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/layout/tabs.ex`
- Table base: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/layout/table.ex`

## Evidencia Gerada

Foi criado e rodado um spec temporario de Playwright para abrir o Channel Central com dados reais e capturar cada aba em desktop e Pixel 5.

Comando validado:

```bash
rtk npm --prefix e2e test -- --project=chromium tests/channel-central-audit.spec.ts --reporter=list
```

Resultado:

- `1 passed`
- Desktop: `620x560`
- Mobile Pixel 5: `1081x1779` no screenshot do elemento, refletindo o dialog fullscreen empilhado em DPR alto.

Screenshots:

- `docs/plans/screenshots/channel-central-audit/desktop-general.png`
- `docs/plans/screenshots/channel-central-audit/desktop-modes.png`
- `docs/plans/screenshots/channel-central-audit/desktop-bans.png`
- `docs/plans/screenshots/channel-central-audit/desktop-ban_exceptions.png`
- `docs/plans/screenshots/channel-central-audit/desktop-invite_exceptions.png`
- `docs/plans/screenshots/channel-central-audit/desktop-registration.png`
- `docs/plans/screenshots/channel-central-audit/mobile-general.png`
- `docs/plans/screenshots/channel-central-audit/mobile-modes.png`
- `docs/plans/screenshots/channel-central-audit/mobile-bans.png`
- `docs/plans/screenshots/channel-central-audit/mobile-ban_exceptions.png`
- `docs/plans/screenshots/channel-central-audit/mobile-invite_exceptions.png`
- `docs/plans/screenshots/channel-central-audit/mobile-registration.png`

## Cobertura Existente

Sim, ja temos Playwright cobrindo Channel Central. A cobertura atual e funcional, nao visual.

Arquivos relevantes:

- `e2e/tests/chat-channel-central.spec.ts`: edita modes, key e limit; valida comandos slash depois.
- `e2e/tests/chat-ui-features-channel.spec.ts`: salva welcome, throttle, transferencia de ownership, registro ChanServ e AOP add/remove.
- `e2e/tests/chat-channel-central-exceptions.spec.ts`: ban exceptions e invite exceptions afetando join/ban behavior.
- `e2e/tests/chat-channel-central-sync.spec.ts`: sync entre dialog e comandos slash.
- `e2e/tests/chat-channel-mode-matrix.spec.ts`: matriz de modos combinados e limpeza de key/limit.
- `e2e/tests/chat-conversation-context-settings.spec.ts`: abrir Channel Central pelo contexto do canal correto.
- `e2e/tests/chat-tools-menu.spec.ts`: abertura via Tools menu.

Conclusao: o dialog tem boa rede de seguranca funcional. O gap real e responsivo/visual: layout, densidade, overflow, semantica de tabs, tabelas no mobile e regressao por screenshot.

## Estado Atual

### Shell da janela

O `desktop_window` do Channel Central nasce com:

- `width={620}`
- `height={560}`
- `min_width={480}`
- `min_height={380}`
- `body_class="flex min-h-0 flex-col p-2"`

No mobile, o Window Manager aplica `.desktop--stacked`:

- janela fullscreen dentro do workspace;
- resize/minimize/maximize escondidos;
- close maior;
- taskbar vira alternador de janelas;
- visualViewport e teclado ja sao tratados globalmente.

Isso e bom. O problema nao esta na janela saindo da tela. O problema esta no conteudo interno ainda ser um painel desktop.

### Estrutura interna

O root do Channel Central usa:

- `class="flex h-full min-h-0 flex-col overflow-y-auto"`
- `tabs_list class="flex flex-wrap"`
- seis tabs: General, Modes, Bans, Ban Exc., Invite Exc., Registration.

Cada aba renderiza uma superficie diferente:

- General: status do canal, topic, welcome message, throttle e transfer ownership.
- Modes: checkboxes e inputs inline para key/limit.
- Bans, Ban Exceptions, Invite Exceptions: tabela de Mask/Set By/Set At + Add/Remove.
- Registration: status ChanServ, drop/register, tabs SOP/AOP/VOP, tabela de access, form de nick.

## Achados Visuais

### Desktop

Desktop esta aceitavel e consistente com o tema Win98. A densidade e alta, mas compatvel com uma janela administrativa. O dialog de `620x560` funciona bem para:

- General com texto salvo;
- Modes com key/limit;
- Listas com uma linha;
- Registration com status, access table e form.

O principal cuidado no desktop e nao quebrar a compactacao atual ao melhorar mobile.

### Mobile

Mobile nao esta quebrado, mas tambem nao esta bom o suficiente. Ele esta "usavel por ampliacao", nao desenhado para telefone.

Problemas observados:

- A tab bar ocupa duas linhas grandes. Em um dialog de administracao, isso rouba espaco vertical em todas as abas.
- As tabs continuam como Win98 tabs desktop com wrap. Em mobile, pratica comum e evitar tab wrap quando ha muitas abas; melhor usar scroll horizontal, modo compacto, ou navegacao secundaria.
- O CSS mobile tenta ajustar `[role="tablist"]` e `[role="tab"]`, mas o componente de tabs nao renderiza esses roles. Ou seja: parte da intencao responsiva/acessivel nao pega aqui.
- General mostra um topic longo em input de linha unica; o conteudo fica cortado e so e acessivel por cursor/scroll horizontal interno.
- General cresce bastante com mensagem, notice e botoes. Ainda cabe, mas a tela fica longa e com custo alto de scan.
- Modes e a aba mais simples e esta proxima de aceitavel, mas key/limit ainda dependem de linha horizontal com label + input.
- As tres abas de lista usam tabela. Em mobile, a tabela fica visualmente grande e semanticamente pobre: Mask e metadata competem por colunas mesmo quando cada entrada deveria virar um item com detalhes.
- Registration e a maior complexidade: mistura status, timestamp longo, destructive action, segment SOP/AOP/VOP, tabela e form no mesmo fluxo vertical.
- Botoes destrutivos desabilitados ficam visualmente presentes e grandes, aumentando ruido em mobile.

## Achados de Codigo

### Tabs

`tabs.ex` nao declara `role="tablist"` nem `role="tab"`. Isso tem dois impactos:

- acessibilidade/teclado de tabs fica mais fraca;
- CSS mobile existente baseado em roles nao afeta o Channel Central.

Hoje os testes e helpers clicam por `button[data-target]` ou `phx-value-tab`, o que funciona, mas nao valida a semantica esperada.

Risco: corrigir roles no componente base impacta todos os dialogs que usam `Tabs`. Isso e provavelmente positivo, mas deve rodar suite de dialogs/tabs, nao apenas Channel Central.

### Tables

`table.ex` sempre envolve a tabela com `overflow-x-auto`. Isso evita quebra dura, mas nao resolve UX mobile. Scroll horizontal em tabela administrativa pequena e um fallback, nao uma boa experiencia primaria.

No Channel Central, listas e access list deveriam ter representacao mobile propria:

- desktop: tabela;
- mobile: lista de linhas/cardlets com campo principal em destaque e metadata abaixo.

### General

O topic usa `<.input type="text">`. Para o mobile, um topic de canal e conteudo textual longo, nao um valor curto. O desktop pode manter input de uma linha; mobile deveria permitir leitura completa sem depender de scroll horizontal no campo.

### Registration

A grid `grid-cols-[86px_1fr]` funciona no desktop, mas em mobile timestamp e nicks longos podem pressionar a coluna de valor. A tela atual ainda nao estoura visualmente no caso testado, mas esta no limite.

O access table tambem sofre do mesmo problema das outras tabelas, com agravante: nicks e `added_by` sao ambos dados relevantes e podem ser longos.

## Praticas da Comunidade Aplicaveis

- Dialog mobile deve preferir fullscreen/bottom-sheet ou tela dedicada quando contem muitos controles. O app ja faz fullscreen via stacked mode, entao a base esta correta.
- Tab bar com muitas opcoes nao deve quebrar em varias linhas quando cada aba e uma secao operacional. Scroll horizontal com estado ativo claro costuma ser melhor que wrap vertical.
- Tabela em telefone deve virar lista semantica quando as colunas sao poucas e cada linha representa uma entidade. Isso reduz overflow e melhora scan.
- Controles destrutivos devem continuar visiveis quando relevantes, mas em mobile e melhor reduzir ruido de acoes indisponiveis ou desloca-las para contexto da selecao.
- Campos com texto longo devem permitir leitura completa. Input single-line e bom para valores curtos; topic/welcome/hostmask longo pedem textarea, wrapping ou display de leitura separado.
- Testes funcionais nao substituem testes visuais. O ideal e combinar asserts de comportamento com screenshots em viewports fixos e checks de overflow.

## Tamanho do Problema

O problema e medio, nao pequeno.

Motivo: o shell mobile ja existe e funciona. Nao precisamos refazer Window Manager, teclado ou viewport. Mas Channel Central concentra praticamente todos os padroes dificeis de dialog:

- tabs numerosas;
- formularios curtos e longos;
- listas administraveis;
- tabelas;
- acoes destrutivas;
- subdialogs;
- permissoes/estado disabled;
- integracao ChanServ;
- sincronizacao com comandos slash.

Ele e um bom primeiro dialog para estabelecer playbook, mas deve ser quebrado em fases.

## Playbook Proposto

### Fase 1: Baseline e guardrails

Objetivo: tornar a evidencia reproduzivel antes de mudar UI.

Acao:

- Transformar o spec temporario em ferramenta de auditoria ou teste visual controlado.
- Capturar desktop e mobile das seis abas.
- Adicionar asserts baratos:
  - Channel Central visivel;
  - janela cabe no viewport mobile;
  - nenhum scroll horizontal no documento;
  - aba ativa visivel;
  - subdialogs abrem e cabem em mobile.

Validacao:

- Playwright Chromium desktop e mobile.
- Screenshots guardados por aba.
- Rodar os testes funcionais existentes de Channel Central.

### Fase 2: Navegacao por tabs

Objetivo: reduzir custo vertical e corrigir semantica.

Acao recomendada:

- Adicionar roles corretos em `Tabs` ou criar ajuste local bem delimitado.
- No mobile, trocar `flex-wrap` por uma tab strip horizontal com `overflow-x-auto`, `flex-nowrap` e active state claro.
- Manter desktop igual.

Risco:

- `Tabs` e componente compartilhado. Se mexer nele, rodar testes/showcase dos dialogs que usam tabs.

Validacao:

- screenshots mobile de todas as abas;
- asserts por role se roles forem adicionados;
- checar que active tab nao fica fora da area visivel depois do click.

### Fase 3: General e Modes

Objetivo: resolver as abas mais faceis e confirmar linguagem visual.

General:

- Mobile: topic deve permitir leitura completa. Opcoes:
  - textarea responsiva para mobile;
  - display read area + edit field;
  - input com wrapper e texto completo abaixo.
- Botoes devem poder quebrar em coluna quando a largura apertar.
- Notice deve manter espaco consistente sem empurrar acoes perigosas para fora de contexto.

Modes:

- Manter layout simples.
- Em mobile, key/limit podem virar linhas de setting com checkbox na esquerda e input abaixo ou alinhado em grid curta.
- Garantir alvos de toque consistentes.

Validacao:

- `chat-channel-central.spec.ts`
- `chat-channel-mode-matrix.spec.ts`
- screenshots desktop/mobile de General e Modes.

### Fase 4: Listas

Objetivo: criar o padrao reutilizavel para Bans, Ban Exceptions e Invite Exceptions.

Acao:

- Desktop continua tabela.
- Mobile vira lista:
  - mask como linha principal;
  - set_by e set_at como metadata;
  - selected state claro;
  - Add/Remove em action bar estavel.
- Se `set_by`/`set_at` forem vazios, nao desperdiçar colunas/espaco com `-` grande.

Validacao:

- `chat-channel-central-exceptions.spec.ts`
- `chat-channel-ban-exceptions.spec.ts`
- `chat-channel-invite-exceptions.spec.ts`
- screenshot das tres abas em mobile.

### Fase 5: Registration

Objetivo: tratar a maior aba sem comprometer ChanServ.

Acao:

- Separar visualmente status, access level e gerenciamento.
- Mobile access list em lista semantica, nao tabela.
- Timestamp deve ser formatado para leitura mobile ou permitir wrap sem quebrar alinhamento.
- Drop Registration deve continuar forte, mas nao dominar a tela quando o usuario esta gerenciando AOP/VOP/SOP.
- Form de nick deve ter largura flexivel e botoes que quebram corretamente.

Validacao:

- `chat-ui-features-channel.spec.ts` Feature 11.
- screenshot registration desktop/mobile.
- cenario com nicks longos e sem permissao.

### Fase 6: Subdialogs

Objetivo: validar as camadas internas.

Subdialogs:

- Add Ban
- Add Ban Exception
- Add Invite Exception
- Transfer Ownership
- Drop Registration confirm

Acao:

- Capturar screenshots mobile e desktop.
- Garantir `max-w-sm` com margem segura no fullscreen mobile.
- Garantir foco, close e submit/cancel com toque confortavel.

Validacao:

- Playwright abrindo cada subdialog via UI.
- Confirmar que overlay cobre o panel certo e nao cria scroll horizontal.

## Resposta Direta Sobre Playwright

Sim, devemos usar Playwright para isso. E sim, existem testes do dialog. O ponto e que eles validam comportamento, nao qualidade responsiva. A abordagem correta para esta frente e:

1. reaproveitar os helpers funcionais existentes;
2. gerar screenshots reais por viewport e aba;
3. adicionar checks de overflow/visibilidade;
4. so entao implementar cada padrao visual;
5. validar com testes funcionais + screenshots.

## Recomendacao

Channel Central e um bom primeiro dialog para definir o playbook porque exercita quase todos os problemas de dialog mobile do app. Mas a primeira entrega nao deve tentar "redesenhar tudo" de uma vez.

Ordem recomendada:

1. Baseline Playwright visual.
2. Tabs mobile e semantica.
3. General + Modes.
4. List tabs.
5. Registration.
6. Subdialogs.

Essa ordem reduz risco porque estabiliza navegacao primeiro, valida formularios simples depois, e deixa a aba mais densa para quando o padrao de lista mobile ja estiver provado.

## Iteracao Implementada

Depois da auditoria, a estrategia foi ajustada: em vez de comecar pelo menor risco, a implementacao atacou primeiro a parte mais dificil, `Registration`, para estabelecer o padrao que as outras abas deveriam seguir. Isso estruturou o resto da entrega porque Registration combina status, acoes destrutivas, segmented control, lista administrativa, selecao e formulario.

### Decisoes tomadas

- `Tabs` base nao foi alterado semanticamente nesta rodada. Um experimento com roles globais quebrou helpers de dialogs existentes que ainda usam `getByRole("button")`, entao a correcao de semantica de tabs ficou fora desta entrega e o comportamento visual foi isolado no Channel Central.
- A tab bar do Channel Central no mobile virou uma faixa horizontal com `overflow-x`, sem wrap vertical. Para resolver a descoberta final do usuario, foi adicionado um indicador visual no lado direito com fade e `>` para sinalizar que ha mais tabs rolaveis.
- Os botoes de acao dos dialogs foram padronizados para alinhar a direita. Isso foi aplicado nas acoes principais, nos formularios, nos confirms inline e nos subdialogs.
- As tabelas seguem como tabela no desktop, mas no mobile viram lista/cardlet com o valor principal em destaque e metadados abaixo.
- O desktop foi mantido compacto, mas tambem recebeu melhorias de alinhamento, quebra de texto e consistencia visual.

### Features abordadas

Registration:

- Status ChanServ ganhou container com classes proprias para permitir wrapping de founder/timestamp.
- SOP/AOP/VOP virou segmented control responsivo, ocupando a largura disponivel no mobile.
- A access table vira lista mobile com nickname principal e `Added By` como metadata.
- O form de Nick usa input em largura flexivel no mobile e mantem Add/Remove alinhados a direita.
- Drop Registration e confirm inline mantem peso visual, mas com acoes alinhadas e sem estourar a largura.

General:

- Topic mantem o input funcional existente e ganhou preview wrapado no mobile para leitura completa.
- Save Topic, Save Welcome, Clear Welcome, Apply Throttle e Transfer Ownership foram alinhados a direita.
- Campos longos ganharam regras de wrapping para nao criar overflow horizontal.

Modes:

- As linhas de settings ganharam estrutura propria para toque e wrapping.
- Key/Limit continuam funcionais e Apply Modes fica alinhado a direita.

Bans, Ban Exceptions e Invite Exceptions:

- Cada linha vira item mobile com mask como conteudo primario.
- `Set By` e `Set At` aparecem como metadados, preservando o conteudo sem forcar scroll horizontal.
- Add/Remove usam action row estavel e alinhada a direita.

Subdialogs:

- Add Ban, Add Ban Exception, Add Invite Exception e Transfer Ownership ganharam overlay/container com classes locais.
- Acoes OK/Cancel/Transfer ficam alinhadas a direita e o container respeita margem segura no mobile fullscreen.

### Validacao desta rodada

Screenshots refinados foram gerados em:

- `docs/plans/screenshots/channel-central-refined/desktop-general.png`
- `docs/plans/screenshots/channel-central-refined/desktop-modes.png`
- `docs/plans/screenshots/channel-central-refined/desktop-bans.png`
- `docs/plans/screenshots/channel-central-refined/desktop-ban_exceptions.png`
- `docs/plans/screenshots/channel-central-refined/desktop-invite_exceptions.png`
- `docs/plans/screenshots/channel-central-refined/desktop-registration.png`
- `docs/plans/screenshots/channel-central-refined/mobile-general.png`
- `docs/plans/screenshots/channel-central-refined/mobile-modes.png`
- `docs/plans/screenshots/channel-central-refined/mobile-bans.png`
- `docs/plans/screenshots/channel-central-refined/mobile-ban_exceptions.png`
- `docs/plans/screenshots/channel-central-refined/mobile-invite_exceptions.png`
- `docs/plans/screenshots/channel-central-refined/mobile-registration.png`
- `docs/plans/screenshots/channel-central-refined/mobile-subdialog-add-ban.png`
- `docs/plans/screenshots/channel-central-refined/mobile-subdialog-transfer.png`
- `docs/plans/screenshots/channel-central-refined/mobile-inline-drop-confirm.png`

Resultado visual:

- A tab strip mobile agora comunica rolagem antes da primeira interacao.
- Registration deixa de parecer uma tabela desktop reduzida e passa a ter leitura mobile propria.
- As listas administrativas nao dependem mais de scroll horizontal como experiencia primaria.
- Os botoes ficaram mais previsiveis por seguirem alinhamento a direita.

Resultado funcional:

- Os testes focados de Channel Central passaram dentro da suite ampla:
  - `chat-channel-central.spec.ts`
  - `chat-ui-features-channel.spec.ts`
  - `chat-channel-central-exceptions.spec.ts`
  - `chat-channel-mode-matrix.spec.ts`
- A suite ampla de dialogs encontrou falhas existentes fora do escopo:
  - `chat-custom-menus-dialog.spec.ts`: o dialog ja estava fechado quando o helper tentou clicar em `OK`.
  - `chat-ui-features-admin.spec.ts`: o botao `Start solo arcade` nao aparece no Admin Console atual.
  - `chat-ui-features-shell.spec.ts`: o teste espera menu sem `Language`, mas a UI atual inclui `Language`.
