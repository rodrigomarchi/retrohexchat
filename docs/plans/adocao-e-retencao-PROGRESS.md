# Adoção e retenção — progresso

Diário de execução de [`adocao-e-retencao.md`](adocao-e-retencao.md). Uma entrada
por iteração, com o que ficou pronto, o que foi aprendido e o que mudou de
plano. Aprendizado durável migra para `AGENT-GUIDE.md` ou um playbook de
`guide/` antes deste arquivo ser apagado junto com o plano.

## Estado por item

| Item | Estado |
|---|---|
| 1.1 Expiração de nick e canal | **pronto** (2026-09-22) |
| 1.2 Catálogo com salas frias | **pronto** (2026-09-22) |
| 1.3 Convite de canal com prévia | **pronto** (2026-09-22) |
| 2.1 Notificação de desktop | **pronto** (2026-09-23) |
| 2.2 PWA | **pronto** (2026-09-23) |
| 2.3 Web Push | **pronto** (2026-09-23) |
| 3.1 Reações | **pronto** (2026-09-23) |
| 3.2 Menções | **pronto** (2026-09-23) |
| 3.3 Régua de não lidas | não iniciado |
| 4.1 Multi-dispositivo | não iniciado |
| 4.2 E-mail opcional | não iniciado |
| 4.3 Fixar mensagem | não iniciado |
| 4.4 Salvar mensagem | não iniciado |
| 5.1 Arquivo público | não iniciado |
| 5.2 Threads | não iniciado |
| 5.3 Eventos | não iniciado |
| 5.4 Avatar no chat | não iniciado |
| 5.5 Emoji do servidor | não iniciado |
| 5.6 Mensagem de voz | não iniciado |

---

## Iterações

### 2026-09-22 — item 1.1, expiração de nick e canal

**Pronto.** `make ci` 18/18.

- Nick passa de 7 para **180 dias**, canal de 7 para **90**, ambos lidos em
  runtime de `config :retro_hex_chat, :expiry` e sobrescritos por
  `RHC_NICK_EXPIRY_DAYS` / `RHC_CHANNEL_EXPIRY_DAYS`. Valor malformado levanta no
  boot em vez de cair no default em silêncio.
- `NickExpiry.configured_expiration_days/0` e `ChanExpiry.configured_expiration_days/0`
  são públicas porque **seis telas citavam "7 dias"** e todas precisavam ler o
  mesmo número.
- `Chat.TimeFormatter.days/1` é o único lugar onde uma quantidade de dias é
  soletrada; todas as frases passaram a interpolar `%{window}`.

**Aprendizados**

- **O teste que já existia não questionava a constante.** Todo caso de
  `nick_expiry_test.exs` passava `expiration_days:` explicitamente, então o 7
  nunca foi exercido por ninguém. Um teste que sempre passa o parâmetro não
  testa o default — e foi por isso que a primeira versão dos casos novos
  **passou por acidente**: uma janela configurada *menor* que 7 é satisfeita
  pela constante antiga. A janela de teste tem de ser mais larga que o valor que
  se quer provar que morreu.
- **Dois testes de worker codificavam a constante sem dizer.**
  `RegisteredChannelExpiryWorkerTest` e `RegisteredNickExpiryWorkerTest`
  atrasavam a atividade em 8 dias e esperavam purga. O assunto deles é o worker,
  não a janela, então agora fixam a janela no `setup`. Regra que vale adiante:
  **teste de worker fixa a política que o worker aplica**, senão ele quebra
  quando a política muda por motivo legítimo.
- **`make i18n.gettext.merge DOMAINS=` quer vírgula, não espaço.**
  `DOMAINS="chat connect help"` roda sem erro e merge-ia só o primeiro. Meia
  hora perdida procurando msgid que o merge nunca tinha criado.
- **`gettext.merge` marcou as frases como `fuzzy` com o "7" cravado dentro.**
  Exatamente a armadilha conhecida: o msgstr sob `#, fuzzy` é o palpite copiado
  de OUTRO msgid. Aceitar aquilo teria colocado "7 dias" em catorze idiomas com
  o servidor varrendo em 180.
- **Sete msgids com plural em catorze idiomas era o desenho errado.** A primeira
  tentativa usou `dngettext` em cada frase, o que multiplica a regra de plural
  por frase. O desenho certo é **um** par plural (`%{count} day`/`%{count} days`)
  num formatador, e `%{window}` em toda frase. Reduziu o problema de plural de
  sete lugares para um, e foi o que tornou a curadoria viável.
- **Placeholder não carrega caso gramatical.** Alemão (`nach 7 Tagen`, dativo) e
  polonês (`po 7 dniach`, locativo) não sobrevivem à substituição: `%{window}`
  produz nominativo/acusativo. As três frases afetadas foram **reescritas** nos
  dois idiomas para uma construção que concorda (`wenn sie %{window} lang
  inaktiv sind`, `gdy są nieaktywne przez %{window}`). Russo e polonês no par
  plural ficam corretos sozinhos porque a forma concorda com o número.
- **Tradução nova derivada da antiga não é tradução automática.** As catorze
  traduções das frases novas saíram da tradução curada que já existia, trocando
  o "7 dias" da língua por `%{window}` — com snapshot antes e auditoria depois
  provando **0 entradas pré-existentes alteradas** e apenas os 7 msgids
  esperados adicionados.
- **A auditoria mentiu primeiro.** O comparador acusou 462 entradas danificadas
  porque `json.load` devolve as chaves de plural como string e `polib` como
  inteiro. Normalizar a chave zerou o número. Vale a regra: quando uma auditoria
  acusa dano em massa numa mudança cirúrgica, o suspeito é a auditoria.

**Arquivos tocados** — `config/config.exs`, `config/runtime.exs`,
`services/nick_expiry.ex`, `services/chan_expiry.ex`, `chat/time_formatter.ex`,
`chat/help_topics/features.ex`, `connect_form_panel.ex`, `chat_live.ex`, quatro
templates de `help_content/` mais seus três módulos hospedeiros, e os catálogos
de `chat`, `connect`, `help`, `help_channels`, `help_features`.

### 2026-09-22 — item 1.2, catálogo mostra salas vazias

**Pronto.** `make ci` 18/18, `make e2e.shots FILE=tests/chat-channel-list.spec.ts` verde,
auditoria visual feita nas duas telas.

- `Channels.Directory.catalog/1` é a união do registro de processos vivos com
  `registered_channels`, e cada linha carrega `live?` e `last_activity_at`.
- `Commands.Autocomplete.list_visible_channels/2` passou a ler o catálogo; as
  regras de `+s`/`+p` continuam onde estavam.
- `Channels.Modes.from_string/1` e `apply_string/2` são agora o único
  decodificador de uma string de modos guardada — o `Channels.Server` deixou de
  ter a cópia privada dele.
- A janela de canais mostra "Último uso" em sala sem ninguém.
- `Chat.TimeFormatter.format_relative/1` conta em dias a partir de um dia e
  traduz "há X"; `format_duration/1` deixou de interpolar "hours"/"minutes" em
  inglês cru.

**Aprendizados**

- **A premissa do item estava meio errada, e o código corrigiu.** Eu tinha
  escrito no plano que um canal vazio perde o processo. Só perde se **não** for
  registrado: `Channels.Server` só para quando `Membership.count == 0 and not
  state.registered`. O caso frio real é **depois de um restart** — ou seja, a
  cada deploy o catálogo volta a mostrar só o que alguém rejoinar. É um problema
  maior do que eu tinha descrito, não menor.
- **A consequência disso mudou o desenho.** A célula "Último uso" ia aparecer
  quando `live? == false`; passou a aparecer quando `user_count == 0`. Se existe
  processo por trás não é pergunta de ninguém; "tem alguém lá?" é.
- **A auditoria visual pagou sozinha.** O segundo screenshot mostrou
  "POPULAR CHANNELS" sugerindo **três salas com (0) pessoas** para quem tinha
  acabado de entrar. Nenhum teste unitário pegaria: `popular_channels/2`
  recebia a lista já filtrada e continuava correta pelo próprio contrato. Foi
  preciso ver a tela.
- **O primeiro screenshot mentiu, e quase virou bug reportado.** A janela
  apareceu com quatro linhas apesar do filtro preenchido, porque o `phx-debounce`
  de 300 ms ainda não tinha pousado e a asserção que veio antes (`row` visível)
  já era verdadeira na lista não filtrada. É a mesma armadilha do page object
  que decide sobre estado que não chegou, só que em forma de foto. **Evidência
  visual precisa de uma espera pelo estado que ela quer provar** — aqui, uma
  linha não relacionada desaparecer.
- **Mudar uma leitura de domínio para tocar o banco quebra casos que não tocavam.**
  `ConversationsReadModelTest` usava `ExUnit.Case` sem sandbox; assim que
  `load_popular_channels/1` passou a ler `registered_channels` pelo catálogo,
  dois testes morreram com erro de ownership. Trocado para `DataCase`.
- **Um segundo decodificador de modos ia nascer.** A metade fria precisa saber
  se o canal é `+s`, e a resposta estava presa numa função privada do
  `Channels.Server`. Puxar para `Modes` custou nada e evitou a divergência que o
  §1.12 descreve — a que só aparece quando alguém adiciona uma flag num lado.

**Arquivos tocados** — `channels/directory.ex`, `channels/modes.ex`,
`channels/server.ex`, `services/queries.ex`, `commands/autocomplete.ex`,
`chat/time_formatter.ex`, `chat/help_topics/commands.ex`,
`components/ui/dialogs/channel_list.ex`, `chat_live/conversations_read_model.ex`,
`help_content/cmd_list.html.heex`, `e2e/tests/chat-channel-list.spec.ts`, e os
catálogos `chat`, `help`, `dialogs`, `help_commands`.

### 2026-09-22 — item 1.3, convite de canal com prévia

**Pronto.** `make ci` 18/18, `make e2e.shots FILE=tests/share-link-join.spec.ts`
verde, auditoria visual nas duas telas do fluxo.

- Novo kind `channel` em share links, com validação de target no changeset — é o
  único kind cujo alvo é um nome e não um token opaco, então é o único que um
  erro de digitação pode fazer parecer resolvível.
- `Liveness`, `Card` e `Policy` ganharam a cláusula do canal. Um canal é um
  **lugar**: não acaba, então a pergunta é só se é um lugar sobre o qual se pode
  falar. `+s`/`+p`/`+i` → link morto, sem oráculo.
- `Chat.Queries.preview_messages/2` devolve as últimas cinco falas visíveis,
  truncadas, sem system/service/notice e sem apagadas.
- `Visibility.nameable?/1` passou a cair na linha de `registered_channels`
  quando não há processo.
- Menu de Conversas ganhou "Copiar link de convite"; `enter_path` do card é
  `/chat?join=<canal>`, que o `ChatLive` já sabia ler.

**Aprendizados**

- **O card só é útil se mostrar a conversa.** Com nome e tópico ele é "alguém te
  mandou um link"; com as últimas falas ele é "olha do que estão falando". Foi o
  que decidiu escrever uma query própria em vez de usar `list_messages/2` com
  limite pequeno: a prévia lê texto **visível**, trunca, e corta tudo o que não é
  gente falando.
- **`data-testid` num `context_menu_item` é atributo morto.** O componente já
  deriva `data-testid="context-menu-item-<action>"`, e em HTML o primeiro
  atributo duplicado vence — então o `data-testid` que passei nunca chegou ao
  DOM. A suíte inteira usa a forma derivada; os `data-testid` nos itens vizinhos
  estão lá sem efeito desde sempre.
- **O teste de LiveView passou e a tela não funcionava.** Ele chamava
  `render_click` com o nome do evento, então exercitou o handler e nunca o
  markup. É a mesma classe de "hook registrado que nenhum template monta": só o
  Playwright encostou no item de menu de verdade.
- **O connect devolve ao card, não ao chat.** O spec assumiu que registrar levava
  direto para dentro do canal; `return_to` leva de volta ao `/join/<slug>`, e o
  botão do card é a porta. Isso é o desenho (o fluxo K4 já dizia), e o spec agora
  diz o mesmo.
- **`Policy.can_create?` tinha um comentário que afirmava não distinguir kind.**
  Passou a distinguir, e o moduledoc foi corrigido junto — um doc que descreve a
  regra anterior é pior que nenhum.
- **Playwright roda de `e2e/`, mas os alvos do Make rodam da raiz.** Um `cd e2e`
  encadeado antes de `make e2e.shots` custa uma rodada inteira com
  "No rule to make target".

**Arquivos tocados** — `share_links/schema/link.ex`, `liveness.ex`, `card.ex`,
`policy.ex`, `service.ex`, `channels/visibility.ex`, `chat/queries.ex`,
`live/join_live.ex`, `components/ui/share/join_card.ex`,
`components/ui/chat/conversations_context_menu.ex`,
`chat_live/conversations_context_menu_events.ex`, `help_topics/features.ex`,
`help_content/feature_channel_invite_link.html.heex`,
`e2e/tests/share-link-join.spec.ts`, e os catálogos `chat`, `help`,
`help_features`, `share`.

### 2026-09-23 — item 2.1, notificação de desktop

**Pronto.** `make ci` 18/18, `make e2e.shots FILE=tests/chat-sound-settings.spec.ts`
verde, auditoria visual da janela de Sons.

- `sound_settings` ganhou `notify_settings` (migration + schema + domínio), com
  `pm` e `highlight` ligados por padrão e todo o resto desligado.
- `Helpers.Session.maybe_notify_desktop/4` é a irmã de `maybe_flash_channel/4`:
  o servidor empurra `desktop_notify` só para conversa fora da tela e não mutada.
- `lib/notifications/desktop_notifier.js` decide o resto (aba oculta, permissão,
  substituição por `tag`); o hook é só a ligação, com 6 testes Vitest próprios e
  10 no controller.
- Janela de Sons ganhou a terceira coluna "Notificar" e a faixa que diz o que o
  navegador respondeu — pedindo permissão só no clique.

**Aprendizados**

- **Quatro asserções de ausência foram vistas ficando vermelhas.** Sabotei o
  gate (`if true or …`, notificar do caminho ativo, remover o mute) e as quatro
  falharam; revertido em seguida. Sem isso, "não notifica" é um teste que passa
  porque nada acontece.
- **Preferência persistida só carrega para quem se identificou.**
  `load_persisted_data/2` roda no identify, não no mount, então o teste que
  prova o desligamento precisa de `chat_conn(nick, pre_identified: true)`. A
  primeira versão usava `:sys.replace_state` e testava a struct, não o caminho.
- **Uma linha carregada antes do campo existir significa "nada", não "tudo
  desligado".** `load_notify/1` faz merge sobre os defaults; sem isso, todo
  mundo que já tinha linha em `sound_settings` perderia PM e menção em silêncio.
- **Permissão de notificação não é dirigível em Chromium headless** — ele
  responde `denied` mesmo com `grantPermissions(["notifications"])`. O spec
  passou a asseverar o invariante que vale com qualquer resposta: a janela mostra
  exatamente a nota do estado em que está, e nunca oferece perguntar quando
  perguntar não funciona. Foi o que produziu a evidência visual do estado
  bloqueado, que é um estado real de usuário.
- **Id de `@flow` é único por seção.** `U5` já existia em
  `chat-flood-protection.spec.ts`; `make e2e.catalog` recusa duplicata, e isso
  é gate de `make ci`.
- **Lacuna deixada de propósito**: o projeto `mobile-chrome` só casa
  `*mobile*.spec.ts`, então esta janela não tem captura mobile. O CSS empilha
  pelo mesmo padrão de uma coluna que já valia com um toggle (`justify-self: end`
  só existe acima de 700px), então não há deformação nova — mas é verificação
  por leitura, não por foto.

**Arquivos tocados** — migration `add_notify_settings_to_sound_settings`,
`chat/schemas/sound_setting.ex`, `chat/sound_settings.ex`,
`chat_live/helpers/session.ex`, `chat_live/helpers.ex`,
`chat_live/pubsub_handlers/messages.ex`, `chat_live/settings_dialogs_events.ex`,
`chat_live/components/sound_settings_dialog.ex`,
`components/ui/dialogs/sound_settings_dialog.ex`, `live/app/chat_live.ex(.heex)`,
`assets/js/lib/notifications/desktop_notifier.js`,
`assets/js/hooks/notifications/desktop_notify_hook.js`,
`assets/js/hooks/critical_hooks.js`, `assets/js/SURFACE.txt`,
`assets/css/retrohex/dialogs/sound-settings.css`, `help_topics/features.ex`,
`help_content/feature_desktop_notifications.html.heex`,
`e2e/tests/chat-sound-settings.spec.ts`, e os catálogos `help`, `dialogs`,
`help_features`.

### 2026-09-23 — item 2.2, PWA

**Pronto.** `make ci` 18/18, `make e2e.shots FILE=tests/landing-public.spec.ts`
verde, auditoria visual da landing.

- `manifest.webmanifest` e `sw.js` em `priv/static/`, ambos na allowlist de
  `static_paths/0` **e** `static_only_matching/0` (o digest reescreve o primeiro
  segmento do nome).
- Ícones 192 e 512 gerados do `favicon.svg` pelo Vix, compostos sobre o teal do
  desktop — **sem esticar**: o viewBox é 92×100 e um ícone de launcher é
  quadrado.
- O worker não cacheia HTML. Só `/assets/*`, que é imutável por construção.
- Registro em `lib/system/service_worker.js`, chamado de `app.js` e nunca de
  `public_pages.js` (orçamento de 80 KB no caminho crítico de todo crawler).
- Janela "Keep It On Your Device" no `/how-it-works` e tópico de ajuda
  `ui-install-app`, que diz explicitamente que **isto não é auto-hospedagem**.

**Aprendizados**

- **O `.gitignore` come `icon-192.png`.** A regra
  `priv/static/**/*-[0-9a-f]*.*` casa qualquer hífen seguido de dígitos hex —
  e `1`, `9`, `2` são todos hex. Nomes com underscore (`app_icon_192.png`)
  escapam, e é a convenção que os arquivos vizinhos já usavam.
- **`Operation.thumbnail` sobre SVG achata em branco.** O caminho certo é
  `svgload` (que devolve `{:ok, {img, meta}}`, não `{:ok, img}`) →
  `thumbnail_image` → `flatten` sobre a cor de fundo → `embed`. Sem o `flatten`,
  o miolo transparente deixa o fundo do sistema aparecer através do hexágono.
- **Uma janela nova na landing quebra um invariante que já existia.**
  `landing_controller_test.exs` compara o conjunto de janelas com o de botões da
  taskbar: "uma janela sem botão não pode ser reaberta depois de fechada". O
  teste apontou `install-app` em segundos — exatamente o tipo de regra que vale
  a pena ter escrita como teste em vez de como parágrafo.
- **`/install` e "instalar o app" são assuntos diferentes.** A página existente
  é sobre subir o seu próprio servidor; confundir os dois na mesma tela seria o
  pior dos dois mundos. A janela nova vive em `/how-it-works` e o tópico de ajuda
  tem uma seção só para dizer que não é a mesma coisa.
- **Bônus da auditoria visual**: o screenshot da landing mostrou a janela Connect
  dizendo "Nicknames unused for **180 days**" — confirmação visual do item 1.1
  que nenhum teste tinha dado.

**Arquivos tocados** — `priv/static/manifest.webmanifest`, `priv/static/sw.js`,
`priv/static/images/app_icon_{192,512}.png`, `retro_hex_chat_web.ex`,
os três layouts, `landing_live/how_it_works.{ex,html.heex}`,
`assets/js/lib/system/service_worker.js`, `assets/js/app.js`,
`help_topics/user_interface.ex`, `help_content/ui_install_app.html.heex`,
`e2e/tests/landing-public.spec.ts`, e os catálogos `help`, `help_ui`, `landing`.


---

### 2026-09-23 — item 2.3, web push

**Pronto.** `make ci` 18/18. O item mais pesado da onda: dependência nova,
tabela nova, contexto novo, fila nova, service worker com dois handlers novos,
controle novo e um parágrafo de privacidade.

- Contexto `RetroHexChat.Notifications` com o layer da casa — `Candidates`
  (puro), `Queries`, `Policy`, `Service`, mais a fachada.
- `Jobs.PushDispatchWorker` na fila `push`, com
  `unique: [period: 60, keys: [:nickname, :conversation]]`.
- Enfileiramento nos **dois** caminhos de mensagem de canal
  (`Chat.Service.broadcast_message/2` e `Channels.Server.do_handle_send_message/5`)
  com o par de asserções duplicado, como o `AGENT-GUIDE` §5 exige enquanto as
  duas vias existirem.
- `sw.js` ganhou `push` e `notificationclick`. `/privacy` ganhou dois parágrafos.
  Tópico de ajuda `feature-closed-app-notifications`.

**Aprendizados**

- **`web_push_encryption` não entra neste projeto.** O plano o nomeava; ele
  depende de `httpoison ~> 1.0` → `hackney ~> 1.8`, e `ex_aws ~> 2.7` exige
  `hackney ~> 4.0`. O resolvedor recusa. Troquei por **`web_push_ex`**, cuja
  única dependência de runtime é `jose`: ele *monta* a requisição (cifra RFC
  8291 + JWT VAPID) e quem envia é o `Req`, que já estava aqui. Melhor arranjo
  que o do plano — o cliente HTTP fica sendo o mesmo do resto do servidor.
- **`Req.Test` engole o `content-encoding` da requisição.** O adaptador de plug
  lê esse cabeçalho, tenta descomprimir o corpo com ele e o *apaga* antes do
  plug rodar (`Req.Steps.run_plug`). O adaptador real envia. Ou seja: aquele
  cabeçalho não é asserível por esse caminho, e um teste que "falhou" ali não
  estava achando bug nenhum.
- **`rescue` largo demais come a asserção do teste.** O primeiro `deliver/2`
  envolvia cifra *e* POST num `rescue`; uma asserção falhando dentro do plug do
  `Req.Test` virava `{:error, :transient}` em vez de teste vermelho. O `rescue`
  agora cobre só a montagem da requisição, que é onde uma chave malformada da
  assinatura pode de fato levantar.
- **Um teto de 8 tokens gasto em ordem de leitura perde o nome.** "lorem ipsum
  … Bob" consome o orçamento antes de chegar no Bob. Os tokens escritos com `@`
  entram primeiro na lista; o resto segue a ordem do texto.
- **A auditoria visual pegou um controle que não poderia funcionar.** O
  screenshot mostrou o interruptor de push desenhado logo abaixo de "Your
  browser is blocking notifications for this site". Um push *precisa* levantar
  uma notificação, então navegador com permissão negada recusa a assinatura —
  a linha agora some em `denied` e `unsupported`. Nenhum teste de unidade
  pegaria: cada metade estava certa sozinha.
- **Permissão de notificação continua não sendo dirigível no Chromium headless**
  (responde `denied` mesmo com `grantPermissions`). Para o screenshot valer, o
  spec U18 injeta um `window.Notification` com `permission: "granted"` via
  `addInitScript`; a metade ausente é asserida no teste de componente.
- **O `sw.js` não é importável, e não deve virar artefato de build.** Um worker
  ESM quebra no Firefox e um `esbuild` escrevendo `priv/static/sw.js` tornaria
  um arquivo versionado — que `endpoint_static_test.exs` exige servido em
  `MIX_ENV=test` — dependente de `assets.build`. O Vitest passou a **avaliar o
  arquivo publicado** num `vm` com um `self` falso e a dirigir os dois
  listeners. Testa o que é servido, não uma cópia das decisões dele.
- **Um `.heex` novo em `help_content/` não é extraído sozinho.** Ele precisa
  entrar no glob de `embed_templates` do módulo `HelpContent` correspondente;
  sem isso o `gettext.extract` não vê uma linha e o catálogo fica verde com a
  ajuda inteira em inglês.
- **O `gettext.merge` fuzzificou "closed tab"** com o palpite de "Close Tab"
  (imperativo: "fechar página", "Zamknij zakładkę"). Eram msgid **novos**, não
  entradas antigas estragadas — mas o palpite estava errado em todos os 13
  locales. Auditoria contra o snapshot: **0 entradas pré-existentes alteradas**;
  273 traduções curadas escritas à mão.
- **`config/runtime.exs` só escreve o VAPID quando os três valores existem.**
  Escrever `nil` ali sobrescreveria o par descartável do `config/e2e.exs` e o
  recurso sumiria da suíte de browser.

**Compromisso conhecido e aceito.** A janela de unicidade colapsa por
`{nickname, conversation}`. Duas menções a pessoas *diferentes* na mesma sala
dentro de 60 s viram uma job, e a segunda pessoa não é avisada. É o que o plano
travou e é o que impede uma rajada de virar vinte pushes; a alternativa —
resolver candidatos no enfileiramento — põe uma query no caminho de toda
mensagem humana. Se aparecer sala movimentada de verdade, a saída é chavear a
unicidade pelo conjunto de tokens, não aumentar o período.

**Sem cobertura de browser, de propósito.** Push real depende de serviço de
terceiro sem duplo de teste; a lacuna está registrada em `e2e/TEST_BACKLOG.md`
com o que a substitui e o que precisa ser conferido à mão antes de um release.

**Arquivos tocados** — `apps/retro_hex_chat/mix.exs`, `config/{config,runtime,e2e}.exs`,
migration `create_push_subscriptions`, `notifications/{candidates,policy,queries,service}.ex`
+ `notifications/schema/push_subscription.ex` + `notifications.ex`,
`jobs/push_dispatch_worker.ex`, `chat/{highlight,service}.ex`, `channels/server.ex`,
`priv/static/sw.js`, `assets/js/lib/notifications/push_subscriptions.js`,
`assets/js/hooks/notifications/push_subscribe_hook.js`, `hooks/critical_hooks.js`,
`components/ui/dialogs/sound_settings_dialog.ex`, `chat_live/components/sound_settings_dialog.ex`,
`chat_live/settings_dialogs_events.ex`, `live/app/chat_live.{ex,html.heex}`,
`landing_live/privacy.html.heex`, `help_topics/features.ex`,
`help_content/feature_closed_app_notifications.html.heex`,
`help_content/chat_status_features.ex`, `assets/css/retrohex/dialogs/sound-settings.css`,
`e2e/tests/chat-sound-settings.spec.ts`, `e2e/TEST_BACKLOG.md`, e os catálogos
`help`, `help_features`, `dialogs`, `landing`.

---

### 2026-09-23 — item 3.1, reações em mensagem

**Pronto.** `make ci` 18/18 e `make e2e.batch BATCH=messages`.

- Uma tabela para as duas conversas: `message_reactions` com `message_id` e
  `private_message_id` anuláveis e um `CHECK` de exatamente um preenchido. O
  terceiro fork canal/privado não foi criado.
- `Chat.Reactions` com `toggle/3`, `summary_for/1` e `summary_for_many/2`
  (uma query por página, não por linha). `Chat.Service.toggle_reaction/3` e
  `toggle_private_reaction/3` publicam `reaction_changed` por
  `broadcast_to_conversation/3`.
- Componente `MessageReactions` **composto do primitivo `.button`** — a tira de
  chips e a barra de acesso rápido. Nada de markup dedicado: um segundo botão
  parecido divergiria do bisel retro na primeira mudança dele.
- Sem hook novo. A barra vive no markup e o CSS decide quando aparece; passar o
  mouse numa linha não custa round trip.
- Reação não marca não lida, não toca som e não gera push.

**Aprendizados**

- **O bug estava no roteador de PubSub, não em nada testado.** `Chat.Service`
  publicava, `PubsubHandlers.Messages` tratava — e `PubsubHandlers` não tinha
  cláusula para `reaction_changed`, então o evento caía no chão. Todos os testes
  de unidade abaixo disso estavam verdes. O teste que pega isso é síncrono:
  `handle_info/2` com uma conversa inativa devolve `{:halt, _}` se está
  roteado e `{:cont, _}` se não está.
- **Não dá para assertar a tira no stream do LiveView.** `MessageViewport.insert`
  vai por `send_update`, então o primeiro `render/1` depois do broadcast não tem
  a linha e o segundo tem. Isso é exatamente o render-retry que
  `.claude/rules/testing.md` proíbe — a metade visível ficou no Playwright, que
  é onde ela pode ser vista de verdade.
- **`@apply` num modificador perde para o primitivo.** `.message-reaction--mine`
  e o `shadow-retro-raised` do `.button` têm a mesma especificidade, e quem
  ganha é quem o Tailwind emitir por último — o que este arquivo não decide.
  Seletor composto (`.message-reaction.message-reaction--mine`) resolve.
- **O filtro do catálogo comia um dos cinco atalhos em silêncio.** 🎉 não está
  no `EmojiData`, então a barra nascia com quatro. O teste que pega isso é a
  contagem (`length(quick_picks()) == 5`), não "todos os que sobraram são
  válidos" — esse passava vazio.
- **Um bisel de 1 px não sobrevive a um screenshot de chip de 16 px.** A
  auditoria visual confirmou o layout (tira acima da barra, cinco atalhos, nada
  empurrando a linha) mas não conseguia provar o estado "pressionado"; isso
  virou asserção de `getComputedStyle().boxShadow` no spec.
- **Escrever tradução casando só por msgid atropela outro domínio.** O msgid
  `thumbs up` já existia como *keyword* no domínio `emoji`; o passe em lote o
  sobrescreveu em 11 locales. Auditoria contra o snapshot pegou, restaurei e
  passei a escopar por domínio. **0 entradas pré-existentes alteradas** no
  fechamento.
- **Catálogo `en` guarda msgstr igual ao msgid.** O merge deixa vazio, e o gate
  só reclama quando o msgid tem placeholder — por isso havia 47 entradas vazias
  de sessões anteriores passando verdes. Preenchi as 39 que introduzi; as
  outras continuam lá e não são deste commit.
- **`make i18n.glossary` precisa de `polib`**, que não está no ambiente. Os
  rótulos novos (`React`, `React...`) entraram em `scripts/i18n/glossary.py`
  para a próxima rodada e foram escritos nos `.po` com a mesma tradução.

**Decisão que desvia do plano.** Os cinco atalhos são uma lista fixa curada
(👍 ❤️ 😂 🔥 👀), não "os cinco mais usados". Um ranking seria uma query no
caminho de render de toda linha, e uma barra cujo conteúdo se move é uma barra
que você tem que ler antes de clicar.

**Arquivos tocados** — migration `create_message_reactions`,
`chat/schemas/message_reaction.ex`, `chat/reactions.ex`, `chat/emoji_data.ex`
(`known?/1`, `chars/0`), `chat/service.ex`,
`components/ui/chat/message_reactions.ex`, `components/ui/chat/message_row.ex`,
`components/ui/chat/chat_context_menu.ex`, `chat_live/reaction_events.ex`,
`chat_live/emoji_events.ex`, `chat_live/stream_item.ex`,
`chat_live/pubsub_handlers.ex` + `pubsub_handlers/messages.ex`,
`chat_live/helpers/{channel,pm}.ex`, `chat_live/core_events.ex`,
`live/app/chat_live.ex`, `assets/css/retrohex/components/chat-message.css`,
`help_topics/features.ex`, `help_content/feature_reactions.html.heex`,
`scripts/i18n/glossary.py`, `e2e/pages/ChatPage.ts`,
`e2e/tests/chat-message-actions.spec.ts`, e os catálogos `chat`, `help`,
`help_features`.

---

### 2026-09-23 — item 3.2, menção deixa de ser só uma cor

**Pronto.** `make ci` 18/18 e `make e2e.batch BATCH=persistence`.

- `Chat.Search.list_mentions/3` — a query de lista que o moduledoc já previa,
  sob o contrato `Page`, keyset por id, `has_more` vindo do `limit + 1`.
  Ignora as próprias linhas, as apagadas e tudo que não é `message`/`action`.
- `mention_counts` ao lado de `unread_counts`, alimentado nos mesmos dois
  pontos e zerado no mesmo lugar. Reusa `UnreadTracker`; nenhum módulo novo.
- Componente `MentionBadge` **composto do primitivo `.badge`**, usado na barra
  lateral e na bandeja da taskbar.
- Janela `mentions` no `WindowRegistry` + ilha `MentionsDialog` usando
  `PaginatedList` e os cinco estados de lista. A primeira página carrega no
  primeiro `update/2` da ilha — nunca num `send_update` pós-mount.
- Clicar numa linha ativa a conversa e empurra `scroll_to_message`, o mesmo
  caminho que o bloco de resposta já usa.

**Aprendizados**

- **A barra de abas não ganhou o selo, e isso foi decisão e não esquecimento.**
  O plano pedia `IrcTabs`, mas essa barra hoje mostra Status + a conversa em
  foco — um selo de menção na conversa que você está lendo não informa nada.
  Cheguei a escrever o atributo e o reverti: atributo morto é pior que ausência.
- **A ilha tem lista branca de assigns.** `Conversations.update/2` copia só as
  chaves que conhece, então `mention_counts` chegava ao template do host e
  morria ali. Nenhum teste de unidade pegou — o e2e pegou em 5 segundos,
  porque é o único que olha a tela montada de verdade.
- **A auditoria visual mudou o desenho.** O screenshot mostrou `(2) 1 1`: dois
  números idênticos lado a lado lidos como um número partido ao meio. O selo de
  menção passou a levar `@` na frente (`@1`), e isso virou teste.
- **Uma asserção pode passar pelo motivo errado.** "abre com a primeira página
  desenhada" casava com o texto da mensagem — que estava no chat atrás da
  janela. Sabotar a carga não deixou o teste vermelho. Passou a assertar no
  `data-testid` da linha da janela, e aí sim ficou vermelho.
- **O erro de escopo de i18n se repetiu.** `Mentions` já existia no domínio
  `help_bots`; o passe em lote o sobrescreveu em 3 locales. Mesma correção:
  restaurar do snapshot e escopar por domínio. Vale escrever a regra: **o passe
  de tradução casa msgid E domínio, sempre.**
- **Escrever plural com regex quebrou um arquivo.** Um `msgstr[1] ""` vazio não
  casou o padrão multilinha e o resultado saiu concatenado na mesma linha
  (`msgstr[0] "..."msgstr[1] ""`). O gate de placeholder pegou; acrescentei uma
  varredura por linhas com dois `msgstr[` ao fechamento.
- **Tradução idêntica ao inglês é reprovada pelo gate.** "%{count} mention" em
  francês é literalmente "%{count} mention"; o `i18n_source_fallback_check`
  trata isso como não traduzido. Resolvido com "%{count} mention reçue".

**Arquivos tocados** — `chat/search.ex`,
`components/ui/chat/mention_badge.ex`, `components/ui/chat/conversations.ex`,
`components/ui/chat/chat_taskbar.ex`,
`components/ui/dialogs/mentions_dialog.ex`,
`chat_live/components/{conversations,mentions_dialog}.ex`,
`chat_live/mention_events.ex`, `chat_live/pubsub_handlers/messages.ex`,
`chat_live/helpers/conversation.ex`, `chat_live/window_registry.ex`,
`live/app/chat_live.{ex,html.heex}`,
`assets/css/retrohex/components/chat-message.css`,
`help_topics/features.ex`, `help_content/feature_mentions.html.heex`,
`e2e/tests/chat-mentions.spec.ts`, e os catálogos `chat`, `dialogs`, `help`,
`help_features`, `ui`.
