# Revisao Dos Primeiros Dialogs

Data: 2026-07-16

## Escopo

Revisao critica dos primeiros dialogs trabalhados no ciclo mobile-first:

- Channel Central
- Admin Console
- Bot Management
- Address Book
- Account

Objetivo: comparar as primeiras entregas com o playbook atual, que ficou mais maduro depois dos ciclos de list editors, confirms, Channel List, Flood Protection, User Lookup e Cheatsheet.

## Achados Priorizados

### 1. Tabs mobile ainda parecem cortadas em vez de claramente rolaveis

Severidade: alta

Afeta:

- Channel Central
- Bot Management
- Address Book
- Account
- Admin Console em menor grau

Evidencia visual:

- `docs/plans/screenshots/channel-central-refined/mobile-registration.png`
- `docs/plans/screenshots/bot-management-refined/mobile-commands.png`
- `docs/plans/screenshots/address-book-refined/mobile-notify.png`
- `docs/plans/screenshots/account-refined/mobile-presence.png`
- `docs/plans/screenshots/admin-console-refined/mobile-server_settings.png`

Evidencia de codigo:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/channel_central_dialog.ex:113`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/admin_console_dialog.ex:158`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/bot_management_dialog.ex:120`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/address_book.ex:94`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/account_dialog.ex:54`
- `apps/retro_hex_chat_web/assets/css/retrohex.css:2285`
- `apps/retro_hex_chat_web/assets/css/retrohex.css:2815`
- `apps/retro_hex_chat_web/assets/css/retrohex.css:5493`
- `apps/retro_hex_chat_web/assets/css/retrohex.css:5743`

Diagnostico:

O primeiro playbook resolveu o problema mais grave, que era wrap em multiplas linhas, mas o resultado visual ainda deixa abas parcialmente escondidas por fade/indicador. Em varios screenshots, a aba anterior ou posterior aparece cortada como se fosse bug de layout. Isso e pior no Bot Management (`Capabilities` parcialmente visivel) e Channel Central (`Registration`/seta competindo no fim da faixa).

Como abordar:

- Criar um padrao local reutilizavel para tabs mobile de dialog: container com area de scroll mais limpa, padding lateral reservado para affordances e `scroll-padding-inline`.
- Evitar que o fade cubra texto ativo ou texto parcial de aba vizinha; a seta deve indicar continuidade sem parecer truncamento acidental.
- Validar em screenshots com aba no inicio, meio e fim.
- Depois de estabilizar em um dialog, aplicar aos outros quatro.

### 2. Os primeiros dialogs ainda usam tabela como estrutura primaria onde o playbook atual preferiria lista unica

Severidade: media/alta

Afeta:

- Channel Central
- Bot Management
- Address Book

Evidencia de codigo:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/channel_central_dialog.ex:474`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/channel_central_dialog.ex:1213`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/bot_management_dialog.ex:266`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/bot_management_dialog.ex:351`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/address_book.ex:698`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/address_book.ex:755`

Diagnostico:

Esses dialogs foram feitos antes de consolidarmos o criterio "uma unica interface mobile-first que tambem melhora desktop". Eles usam uma tabela real no desktop e CSS para virar cardlet no mobile. Funciona, mas e uma solucao intermediaria: a estrutura ainda carrega headers, colunas e semantica de tabela para dados que o usuario escaneia por item.

Como abordar:

- Nao precisa reescrever tudo de uma vez.
- Prioridade: Bot Management `Channels/Commands` e Address Book `Notify`, porque sao listas de objetos, nao matrizes.
- Channel Central pode ficar por ultimo por ter maior rede funcional e permissional.
- Converter cada lista para entradas compostas reais, como fizemos em Perform, Alias, Notify List, URL Catcher, Channel List e Cheatsheet.
- Preservar `data-testid`, `phx-value-*` e selecao.

### 3. Admin Console ainda tem campos textuais longos em input single-line

Severidade: media

Afeta:

- Admin Console, principalmente `Server Settings`

Evidencia visual:

- `docs/plans/screenshots/admin-console-refined/mobile-server_settings.png`

Evidencia de codigo:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/admin_console_dialog.ex:760`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/admin_console_dialog.ex:768`

Diagnostico:

`server_description` e `welcome_message` aparecem como inputs single-line. No mobile, a descricao longa fica visualmente truncada. Depois dos ciclos Account, Perform, Alias, Timers e Knock Request, o playbook ficou mais claro: texto operacional longo deve ser textarea ou ter preview wrapado.

Como abordar:

- Transformar `server_description` e `welcome_message` em textarea quando a semantica permitir.
- Se o backend espera string simples, manter `name` igual e alterar apenas o controle.
- Validar desktop tambem: altura nao deve inflar demais o Server Settings.
- Capturar estado com texto longo e vazio.

### 4. Validade dos gates amplos ficou parcialmente pendente nos primeiros ciclos

Severidade: media

Afeta:

- Admin Console
- Channel Central, por relatar falhas fora do escopo em suites amplas

Evidencia documental:

- `docs/plans/dialogs-admin-console-mobile-audit.md:113`
- `docs/plans/dialogs-channel-central-mobile-audit.md:422`

Diagnostico:

Os ciclos registraram falhas externas/preexistentes, como `Start solo arcade` no Admin Console e expectativas antigas no shell/menu. Isso foi correto no momento para nao bloquear o dialog, mas hoje precisamos separar o que ainda e falha real do que ja foi corrigido em ciclos posteriores.

Como abordar:

- Reexecutar os gates amplos relacionados aos primeiros dialogs em sequencia, nao em paralelo.
- Atualizar a documentacao se a falha sumiu.
- Se ainda falhar por expectativa obsoleta, abrir item proprio fora do dialog.

### 5. Account esta relativamente bem, mas ainda compartilha o problema de tab affordance

Severidade: baixa/media

Evidencia visual:

- `docs/plans/screenshots/account-refined/mobile-presence.png`

Evidencia de codigo:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/account_dialog.ex:44`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/account_dialog.ex:416`

Diagnostico:

Account ja incorporou aprendizados importantes: `focus_wrap`, `role="dialog"`, textarea para Away Message e action rows a direita. Nao parece precisar de redesenho grande. O ponto pendente e padronizar a tab strip junto com os outros dialogs.

Como abordar:

- Nao mexer primeiro no Account.
- Depois que o padrao de tabs for refinado em Bot Management ou Address Book, aplicar o mesmo ajuste ao Account.

## Ordem Recomendada Para Segunda Rodada

1. Bot Management tabs e listas `Channels/Commands`.
2. Address Book tabs e `Notify` como lista unica real.
3. Admin Console `Server Settings` com textareas/preview para campos longos.
4. Channel Central tabs; depois decidir se listas administrativas devem abandonar tabela no desktop tambem.
5. Account apenas para absorver o novo padrao de tabs.

## Validacao Recomendada

Rodar em sequencia:

- `rtk mix compile`
- `rtk npm --prefix e2e test -- --project=chromium tests/chat-bots.spec.ts tests/chat-bot-edges.spec.ts tests/chat-bot-persistence.spec.ts tests/chat-bot-channel-membership.spec.ts tests/chat-bot-custom-command-edges.spec.ts --reporter=list`
- `rtk npm --prefix e2e test -- --project=chromium tests/chat-address-book.spec.ts tests/chat-address-book-contacts.spec.ts tests/chat-address-book-colors.spec.ts tests/chat-address-book-control.spec.ts --reporter=list`
- `rtk npm --prefix e2e test -- --project=chromium tests/chat-admin-users.spec.ts tests/chat-admin-channels.spec.ts tests/chat-admin-audit-log.spec.ts tests/chat-admin-extended.spec.ts tests/chat-admin-channel-destructive.spec.ts tests/chat-admin-nuke.spec.ts tests/chat-admin-diagnostics.spec.ts --reporter=list`
- `rtk npm --prefix e2e test -- --project=chromium tests/chat-channel-central.spec.ts tests/chat-channel-central-exceptions.spec.ts tests/chat-channel-central-sync.spec.ts tests/chat-channel-mode-matrix.spec.ts --reporter=list`
- `rtk npm --prefix e2e test -- --project=chromium tests/chat-dialog-keyboard.spec.ts --reporter=list`

Para visual:

- Recriar specs temporarios de screenshot apenas enquanto revisamos, removendo-os antes do final.
- Capturar aba inicial, aba intermediaria e aba final de cada tab strip.
- Capturar uma lista com texto curto e outra com texto longo.
