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
| 3.3 Régua de não lidas | **pronto** (2026-09-23) |
| 4.1 Multi-dispositivo | **pronto** (2026-09-23) |
| 4.2 E-mail opcional | **parcial** (2026-09-23) — dois dos três usos; falta o aviso de PM com a pessoa fora, e nenhuma cobertura de navegador |
| 4.3 Fixar mensagem | **pronto** (2026-09-23) |
| 4.4 Salvar mensagem | **pronto** (2026-09-23) |
| 5.1 Arquivo público | **pronto** (2026-09-24) |
| 5.2 Threads | **pronto** (2026-09-24) |
| 5.3 Eventos | **pronto** (2026-09-25) |
| 5.4 Avatar no chat | **pronto** (2026-09-25) |
| 5.5 Emoji do servidor | **pronto** (2026-09-26) |
| 5.6 Mensagem de voz | **pronto** (2026-09-27) |

---

## Auditoria de fechamento — 2026-09-28

Feita contra o **código**, não contra este arquivo: cada atividade escrita no
plano foi procurada na árvore. Dezesseis itens fecham inteiros. O que não fecha:

- **4.2 entregou dois dos três usos.** O plano decidiu três — recuperar senha,
  avisar antes do nick expirar, e avisar de mensagem privada com a pessoa fora
  há mais de N horas. O terceiro nunca foi construído, e a janela Conta não tem
  as "preferências de aviso" que a atividade 6 previa. Estava escrito aqui em
  "Falta neste item"; a tabela de estado é que dizia **pronto**. Corrigida.
- **4.2 não tem nenhuma cobertura de navegador.** `/account/verify/:token` e
  `/account/reset/:token` são rotas públicas que um estranho abre a partir do
  cliente de e-mail dele, e nenhuma spec as dirige. O domínio e as duas
  LiveViews têm teste de ExUnit (`nick_email_test.exs`, `account_test.exs`,
  `connect_recovery_test.exs`) — o caminho que ninguém exercita é o do
  navegador, que é exatamente onde um token expirado, um link aberto duas vezes
  ou uma sessão já iniciada se comportam de forma diferente.
- **O arquivo público publica linha em branco.** Uma mensagem só com anexo é
  gravada com `content: ""` (`allow_blank_content: attachment_ids != []`), e
  `Archive.entry/1` devolve `text: ""` com `attachment?: false` — um campo
  declarado no tipo, fixado numa constante e lido por ninguém. Numa página feita
  para estranhos e robôs, sai autor, horário e nada. O 5.6 torna o caso comum:
  mensagem de voz normalmente não tem texto.
- **Duas capacidades subiam apagadas.** `RHC_VAPID_*` e `RHC_SMTP_*` eram lidas
  pelo `runtime.exs` e não apareciam em lugar nenhum de `README`/`docs`: push e
  e-mail existem no código e o operador não tinha como saber que existem, nem o
  que setar. Documentadas na seção de deploy, junto com
  `RHC_NICK_EXPIRY_DAYS`/`RHC_CHANNEL_EXPIRY_DAYS`.

Continua de pé o bloqueio de release do 2.3: um push real contra um serviço de
push de verdade, conferido à mão uma vez (`e2e/TEST_BACKLOG.md`).

**O que a auditoria confirmou íntegro**, por ter procurado e achado: entrada
segue exigindo nick registrado nos três caminhos de `route_valid_nickname/2`;
o arquivo público filtra `archive_since`, apagadas, tipos não publicáveis e
canal `+s` na leitura e na escrita; os dois caminhos de mensagem (`Chat.Service`
e `Channels.Server`) enfileiram push; os três workers novos têm telemetria;
nenhum `TODO`/stub no código do plano; o service worker só cacheia asset
digerido, então cache velho não serve código velho.

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

---

### 2026-09-23 — item 3.3, régua de não lidas e voltar para onde parei

**Pronto.** `make ci` 18/18 e `make e2e.batch BATCH=persistence`. Fecha a onda 3.

- Coluna `read_markers` em `reconnect_states` — a tabela que já guarda o que a
  pessoa tinha aberto passa a guardar também onde ela estava. Nenhuma tabela
  nova.
- `ReconnectState.normalize/1` defende tudo: chave que não é conversa, valor
  que não é id, mapa maior que o teto.
- `ChatLive.ReadMarkers` com a regra que define o recurso: **o marcador não
  anda enquanto você lê.** Anda ao trocar de conversa, ao entrar em outra e ao
  focar a aba — nunca quando a mensagem chega.
- Componente `UnreadDivider` e botão "Primeira não lida" na barra da conversa,
  visível só quando há algo para pular.

**Aprendizados**

- **A régua não pode ser irmã das linhas.** Um container `phx-update="stream"`
  exige id em **todo** filho, e o LiveView levanta
  `ArgumentError` no primeiro render. A régua foi para *dentro* da linha, como
  primeiro filho — o que também resolve o motivo original do plano (um item
  sintético reordena e é podado pelo `limit:` negativo).
- **Entrar num canal não passa por `enter_conversation`.** `setup_joined_channel`
  monta a conversa por conta própria, então o avanço do marcador precisou de
  dois pontos. O teste que pegou isso usa `switch_channel` explicitamente,
  porque o `/join` exercita o outro caminho.
- **`reset` do viewport precisa zerar o "visto", não só atualizar.** Entrar numa
  conversa vazia deixava o `newest_message_id` da conversa anterior, e ao sair
  o marcador **da conversa errada** avançava. `replace_seen/2` aceita `nil`;
  `seen/2` continua só avançando.
- **Adicionar um campo ao snapshot quebra asserções de shape exato.**
  `reconnect_state_test.exs` compara o mapa inteiro com `==` em dois lugares.
  Errado meu não ter procurado antes; corrigido nos dois.
- **A auditoria visual confirmou de primeira**: régua vermelha atravessando a
  conversa com "NEW MESSAGES" no meio, entre a linha lida e a que chegou depois.

**Arquivos tocados** — migration `add_read_markers_to_reconnect_states`,
`chat/reconnect_state.ex`, `chat/schemas/reconnect_state.ex`,
`chat_live/read_markers.ex`, `chat_live/components/{message_row,message_viewport}.ex`,
`chat_live/helpers/{channel,conversation,pm,session}.ex`,
`chat_live/pm_typing_events.ex`, `chat_live/core_events.ex`,
`components/ui/chat/{unread_divider,conversation_toolbar_actions}.ex`,
`live/app/chat_live.{ex,html.heex}`,
`assets/css/retrohex/components/chat-message.css`, `help_topics/features.ex`,
`help_content/feature_where_you_left_off.html.heex`,
`e2e/tests/chat-unread-divider.spec.ts`, e os catálogos `chat`, `help`,
`help_features`.

---

## Onda 3 fechada

Reações, menções e a régua de não lidas. As três respondem à mesma coisa: antes
delas, a única forma de participar era escrever, e a única forma de voltar era
rolar. Onda 4 (uso diário) começa em 4.1, que o plano marca como **plan mode
obrigatório**.

---

## Iteração 4.1 — Duas telas do mesmo nick ao mesmo tempo

Abrir o chat no celular deixou de matar o desktop. Teto de **3 sessões
simultâneas** por nick (`SessionControl.max_sessions/0`, configurável); a quarta
derruba a que está há mais tempo sem uso.

**O que ficou**

- Coluna `browser_id` em `reconnect_states` e chave primária composta
  `(owner_nickname, browser_id)`. O que você tinha aberto é fato de uma tela,
  não de uma pessoa.
- Plug `PutBrowserId` + `App.BrowserIdCookie`: um nome opaco por navegador,
  cunhado no primeiro acesso, no desenho do `PutTrustedDevice` ao lado.
- `SessionControl.enforce_limit/2` substitui o `disconnect(…, :chat)`
  incondicional no mount. Conta pelas linhas abertas de `chat_device_sessions`
  — query, não lookup, porque um processo morto e ainda não varrido mente.
- `Surfaces.count_kind/3`: "há processo de chat vivo" e "há alguma aba aberta"
  são perguntas diferentes e agora têm funções diferentes.
- Marcador de leitura sincroniza pelo `Topics.inbox/1` com cláusula explícita em
  `PubsubHandlers`. Ler no celular limpa o badge no desktop.
- Ajuda: `feature-single-session` virou `feature-sessions`, dizendo o oposto do
  que dizia. `/privacy` ganhou o parágrafo do `browser_id`.

**Quatro descobertas que encurtaram o trabalho**

- **O endereço por sessão já existia.** `chat_device_session:<ref>` já era
  assinado pelo `ChatLive` e publicado por `TrustedDevices` e `Admin`. Derrubar
  *uma* sessão não precisou de mecanismo novo.
- **A chave que evita o estrago já era lida.** O handler de `force_disconnect`
  já consulta `skip_channel_cleanup` no payload. A sessão derrubada manda essa
  chave e não abandona os canais que os sobreviventes ocupam — zero mudança no
  handler.
- **Reentrar em canal já era suportado.** `{:error, "Already in channel"}` já
  caía em `setup_joined_channel`, então a segunda tela adota a membership sem um
  segundo `user_joined`.
- **"Encerrar as outras sessões" já estava no ar** em Terminais confiáveis
  (`trusted_terminals_kill_other_sessions`). O plano previa construir; o
  trabalho real foi apontar a ajuda para lá.

**Dois alargamentos que o plano não previa**

- **O push duplicaria.** `candidates_for_channel_message/2` fazia `join` em
  `owner_nickname` sem `distinct`. Com uma linha por navegador, cada inscrição
  voltaria N vezes e o mesmo aparelho receberia N notificações por mensagem.
  Virou `EXISTS`, que diz a intenção e não pode multiplicar por construção. O
  teste que pega isso é vermelho contra o `join`.
- **Fechar uma aba diria que a pessoa saiu.** `terminate/2` publicava
  `{:user_disconnected}` e gravava whowas incondicionalmente, e esse evento
  alimenta a notify list. Agora só quando é a última sessão **de chat**.

**Aprendizados**

- **A espera de takeover saiu inteira** — `takeover_expected?`,
  `takeover_acker?`, `wait_for_takeover_cleanup`, o `takeover_ack`. Ela existia
  para a sessão antiga abandonar os canais antes da nova entrar; a sessão
  derrubada não abandona mais nada, então não havia o que esperar. Some um
  `receive` bloqueante de até 1s do mount. *Desvio consciente do plano escrito.*
- **Minha ferramenta de `.po` corrompeu acentuação.** `unicode_escape` destrói
  UTF-8: o travessão virou mojibake em 44 entradas. Restaurei tudo do snapshot e
  reescrevi o unescape para tratar só `\n`, `\t`, `\"` e `\\`. A auditoria
  final fecha com **0 entradas pré-existentes alteradas**.
- **O mesmo passo também preencheu 44 entradas vazias de domínios alheios.**
  Dívida pré-existente que não é deste item; revertida junto.
- **Mexer num comentário invalida o `.pot`.** As referências `#:` guardam
  número de linha, então reescrever um moduledoc num arquivo com `dgettext`
  derruba "i18n Catalog Coverage". Aconteceu duas vezes; a lição é extrair
  **depois** do último retoque de texto, não antes.
- **O merge marcou meu próprio msgid como `fuzzy`** nos 14 catálogos, por ser
  uma reescrita de uma frase anterior. Limpar a marca só é legítimo porque o
  `msgstr` já era a tradução que eu tinha escrito — e só nessa entrada.
- **O plug roda no teste de LiveView.** Plantar `browser_id` na sessão não
  adianta: o plug sobrescreve. `chat_conn` passou a mandar cookie, que é como um
  navegador de verdade faz.
- **Escrevi um teste contra a regra de testes.** Assertei em linha de stream
  (`send_update` assíncrono) com um helper de polling. A pergunta real —
  "cada tela recebe uma entrega só" — é respondida de forma síncrona pelo
  registro de assinantes do PubSub.
- **Quatro specs afirmavam o takeover, dois deles de lado.** Os dois diretos
  (`multi-tab-takeover`, `multi-tab-takeover-edges`) eu já esperava reescrever.
  Os outros dois foram as únicas falhas dos batches: `surface-multi-tab` (K2)
  provava que uma aba de jogo sobrevive à derrubada do chat, e
  `admin-registration-closed-edges` (AA7) terminava exigindo que a senha certa
  derrubasse a sessão de origem. Nesse, a parte que importa — senha errada não
  entra **nem desloca** quem já está lá — passava e continua intacta; só as duas
  últimas linhas caíram. Nenhuma das duas falhas apontou defeito no código: as
  duas apontaram texto descrevendo um mecanismo removido.
- **A paginação da lista de sessões ficou inalcançável.** Um teste existente
  semeava 26 sessões abertas e o teto poda para 3. É o recurso funcionando: a
  lista nunca passa de uma página, e a poda também limpa linhas que um navegador
  que travou deixou abertas. O teste passou a afirmar isso.

**Arquivos tocados** — migration `rekey_reconnect_states_by_browser`,
`chat/reconnect_state.ex`, `chat/schemas/reconnect_state.ex`,
`session_control.ex`, `surfaces.ex`, `accounts/trusted_devices.ex`,
`notifications/queries.ex`, `plugs/put_browser_id.ex`,
`app/browser_id_cookie.ex`, `router.ex`, `live/app/chat_live.ex`,
`chat_live/read_markers.ex`, `chat_live/pubsub_handlers.ex`,
`chat_live/helpers/session.ex`, `components/ui/connect/connect_form_panel.ex`,
`help_topics/features.ex`, `help_content/feature_sessions.html.heex`,
`landing_live/privacy.html.heex`, `e2e/tests/multi-tab-takeover*.spec.ts`,
`e2e/tests/surface-multi-tab.spec.ts`,
`e2e/tests/admin-registration-closed-edges.spec.ts`, e os
catálogos `accounts`, `help`, `connect`, `help_features`, `help_games`,
`landing`.

---

## Iteração 4.2 — E-mail opcional

**Pronto**

- `swoosh` + `gen_smtp`, `RetroHexChat.Mailer` com `configured?/0`. SMTP em
  produção por env, `Local` em dev e e2e, `Test` em teste. Sem relay, o recurso
  não existe — mesma disciplina do VAPID e do TURN.
- Migration `add_email_to_registered_nicks` com índice único **parcial** sobre
  `lower(email)`: um endereço pertence a um nick, e todo nick sem endereço
  continua livre.
- `Services.NickEmail` — endereço opcional, confirmação, reset e envio. 16
  testes.
- `/account/verify/:token` e `/account/reset/:token` no pipeline `:landing_live`
  e **dentro do loop de locales**. 7 testes.

**Aprendizados**

- **O render estático gastava o token.** Um LiveView monta duas vezes, e o link
  é de uso único: a primeira passagem consumia, a segunda achava gasto, e
  *todo mundo* veria "link inválido" ao confirmar um endereço. Só acontece com
  token de uso único — nada no repo tinha esse formato antes. `connected?/1`
  decide, e a passagem estática apenas diz que está checando.
- **Erro de validação não é link morto.** Esconder o formulário quando havia
  qualquer erro fazia uma senha curta demais matar a página. São dois estados
  diferentes: `link_dead` esconde, `error` mantém o formulário aberto.
- **A página de reset precisa checar o link sem gastá-lo.** Oferecer um
  formulário que o submit vai recusar é pior do que dizer de cara que o link
  morreu — daí `reset_token_valid?/2`.
- **Confirmar precisa zerar o carimbo de envio.** O debounce de 5 min existe
  para espaçar envios, e um link seguido é um envio concluído; sem zerar, quem
  acabou de confirmar o endereço ouvia "espere" ao pedir reset.
- **O e-mail não sai do domínio montando URL.** `apps/retro_hex_chat` não tem
  rotas, então quem chama passa uma função que transforma token em link. O teste
  usa isso para extrair o token da mensagem realmente enviada, em vez de ler o
  banco — e assim prova que o link da mensagem funciona.

- `Jobs.NickExpiryWarningWorker` — avisa 14 dias antes da liberação, fechando o
  item 1.1. Não guarda quem foi avisado: a janela tem um dia de largura sobre
  `last_seen_at` e a job roda diária, então cada nick passa por ela uma vez, e
  quem volta sai da janela voltando.
- "Esqueci minha senha" na tela de conexão e a seção de endereço na janela
  Conta, ambas invisíveis sem SMTP.
- Tópico `feature-account-email`, `/privacy` com o que é guardado e como apagar,
  e os 57 msgids novos traduzidos nos 13 locales.

**Mais aprendizados**

- **Eu estava fazendo SMTP dentro do `handle_event`.** O teste do LiveView
  quebrou porque a mensagem chegava no processo dele — e isso expôs o problema
  real: o socket ficava preso pela duração da conversa com o outro servidor.
  `AGENTS.md` é explícito ("Oban owns all background work"), então o envio virou
  `Jobs.MailWorker` numa fila `mail` própria. Os testes passaram a ler **a job
  enfileirada**, que carrega a mensagem inteira, e um teste só do worker prova
  que uma job vira mensagem enviada — sem ele, todos os outros passariam num
  servidor que nunca entregou nada.
- **Um contador de teste estourou o limite de 16 caracteres do nick.** 36
  lugares em 19 arquivos montavam nicks como `"NotifyUser#{unique_integer}"`;
  `System.unique_integer/1` cresce com a atividade da VM, então bastou a suíte
  ganhar testes para um prefixo de 10 letras não caber mais. Falha latente que
  este item apenas expôs — todos passaram a usar `rem(…, 100_000)`.
- **Um número de varreduras estava escrito no teste.** `oban_health_test`
  afirmava `maintenance_sweeps == 11`; apodrece no dia em que alguém adiciona
  uma varredura e não diz nada sobre o snapshot estar certo. Agora deriva.
- **Desvio do plano:** as funções ficaram em `Services.NickEmail`, não em
  `NickServ`. O NickServ já tem 455 linhas e carrega o GenServer do conjunto de
  identificados; recuperação não compartilha nada desse estado.

**Falta neste item** — o terceiro uso previsto no plano (avisar de mensagem
privada quando a pessoa está fora há N horas) não foi construído: depende de
preferência por pessoa e de saber há quanto tempo ela sumiu, que é trabalho de
domínio próprio. Os outros dois usos estão de pé. E2E ainda não rodou.

---

## Iteração 4.3 — Fixar mensagem no canal

Um canal tinha um tópico (uma linha, substituída a cada vez) e uma mensagem de
boas-vindas que ninguém lê duas vezes. As regras, o link do evento e o combinado
sumiam no scroll e eram redigitados.

**O que ficou**

- Tabela `pinned_messages` com FK `on_delete: :delete_all`: o pin é propriedade
  da **conversa**, não da mensagem — dois canais podem manter a mesma linha por
  motivos diferentes, e uma linha apagada leva seus pins junto sem código
  nenhum lembrar disso.
- `Channels.Pins` com teto de 50, idempotência e `Page`; `Policy.can_pin?/2` na
  mesma régua do tópico.
- `/pin` e `/unpin`, um Handler cada; `Server.pin_message/3` e
  `unpin_message/3` decidem no processo do canal, onde a membership vive.
- Broadcast `pinned_changed` com **a contagem, não a lista** — toda tela mostra
  o número, só a janela aberta precisa das linhas.
- Janela Pinned, item no menu de contexto e botão na barra da conversa.

**Aprendizados**

- **O menu de contexto não era opcional.** Eu ia deixá-lo para depois, até
  perceber que sem ele **não há como criar o primeiro pin**: ninguém lê ids de
  mensagem numa tela, e o botão da barra só aparece quando já existe um pin. O
  próprio texto de ajuda que escrevi expôs o círculo.
- **Um catch-all silencioso engoliu a ação nova.** `UiActionHandlers` roteia por
  listas explícitas e terminava com `def handle_ui_action(socket, _action,
  _payload), do: socket`. `/pin` rodava e não fazia nada, sem erro e sem log —
  a classe de bug que o `CLAUDE.md` proíbe. Agora ele avisa.
- **Mais três números escritos à mão em teste.** `registry_test` afirmava
  `length(commands) == 54` em três lugares. Trocados por propriedades: todo
  comando responde `known?/1`, a lista não tem repetidos, e as categorias cobrem
  exatamente a lista. Mesma classe do `maintenance_sweeps == 11` do item 4.2.
- **`Page` expõe `next_cursor`, não `cursor`.** Detalhe pequeno que só aparece
  quando se escreve o teste antes.

**Arquivos tocados** — migration `create_pinned_messages`, `channels/pins.ex`,
`channels/schemas/pinned_message.ex`, `channels/policy.ex`, `channels/server.ex`,
`commands/handlers/{pin,unpin}.ex`, `commands/registry.ex`,
`chat_live/pin_events.ex`, `chat_live/components/pinned_dialog.ex`,
`components/ui/dialogs/pinned_dialog.ex`,
`components/ui/chat/{chat_context_menu,conversation_toolbar_actions}.ex`,
`chat_live/{ui_action_handlers,ui_actions/core,pubsub_handlers,
pubsub_handlers/channel_state,helpers/conversation,window_registry}.ex`,
`help_topics/{commands,user_interface}.ex`, três `.heex` de ajuda, e os
catálogos `channels`, `chat`, `commands`, `dialogs`, `help`, `help_commands`,
`help_ui`.


---

## Iteração 4.4 — Salvar mensagem para depois

Fecha a Onda 4. Um chat perde coisas: o endereço que alguém digitou, o link da
build, o parágrafo que vale ler duas vezes. A única recuperação que o produto
oferecia era a busca, que exige lembrar uma palavra. Salvar serve para o momento
em que a pessoa **já sabe agora** que vai querer aquilo depois.

**O que ficou**

- Tabela `saved_messages` com os **dois pais anuláveis e o mesmo `CHECK`** das
  reações — canal e privado no mesmo modelo, não um terceiro fork. FK do dono em
  `registered_nicks` com `on_delete: :delete_all`.
- `Chat.SavedMessages`: `save/3` idempotente, `unsave/2` (por mensagem, do menu),
  `unsave_id/2` (por linha, da janela, sempre com o dono na pergunta),
  `list/2` sob `Page` com os dois `left_join` numa consulta só, `set_note/3`,
  `saved?/2`, `saved_ids/3`. Teto de 500.
- **Linha apagada mantém a linha salva, marcada e sem o conteúdo.** Sumir
  ensinaria que salvar não funciona; mostrar o texto desfaria a exclusão. Quem
  some é só a mensagem removida de verdade do banco, e quem faz isso é a FK.
- **`counterpart` sai do banco**, não da tela: quem é "a outra pessoa" numa
  conversa privada só o dono da linha pode dizer, e é ele que faz a consulta.
- Janela Saved Messages (ilha + componente de apresentação, cinco estados de
  lista), item no menu de contexto com Save/Unsave, entrada em Start ▸ Tools,
  campo de nota por linha.
- Ajuda: `feature-saved-messages` e `ui-saved-window`, 34 msgid curados nos 13
  idiomas.

**Aprendizados**

- **Havia duas listas de hooks e a segunda estava quatro módulos atrás.**
  `@event_hook_fns` (usada por `dispatch_to_hooks/3`, o caminho de
  `toolbar_action`) era uma cópia manual da lista de `attach_all_hooks/1` e não
  tinha `ReactionEvents`, `MentionEvents`, `PinEvents` nem o novo
  `SaveEvents`. Resultado: um item de menu podia estar ligado, desenhado e
  **não fazer nada**. Agora é `event_hooks/0`, uma fonte só. Mesma classe do
  catch-all silencioso do 4.3.
- **O menu de contexto nunca soube o que já estava fixado.** `msg_pinned` lia
  `Map.get(msg, :pinned, false)` e ninguém jamais preenchia `:pinned` — o item
  "Unpin", escrito no 4.3, era desenhado por nada e estava verde em todo teste.
  Agora `pinned?` e `saved?` são perguntados uma vez, para a linha em que se
  clicou.
- **O item do menu não se fechava depois de agir.** Ficava por cima da linha
  seguinte, então o segundo clique com o botão direito caía no menu em vez da
  mensagem. Valia para Pin/Unpin também; os quatro fecham agora.
- **A auditoria visual pegou o título errado da janela.** Ela dizia "Private
  Message". Causa: limpei a marca `fuzzy` de seis msgid meus sem ler o texto
  que o gettext havia **copiado de outro msgid** — exatamente a armadilha que a
  memória `gettext-fuzzy-is-a-different-msgid` descreve. Em `en` o palpite ficou
  valendo, porque as tabelas curadas não cobrem `en`. Varri o `en` inteiro:
  **20 entradas** tinham `msgstr != msgid`, 6 minhas e 14 de itens anteriores
  ("Mentions" aparecia como "My mentions", "New messages" como "Notice
  message"). Todas realinhadas.
- **`i18n_apply_translation_overrides.py` reescreveu 14 entradas alheias**
  (Kick, Status, Auto) mesmo com o glob do domínio, porque esses msgid vivem nos
  mesmos domínios. Revertidas contra o snapshot. A auditoria "0 entradas
  pré-existentes alteradas" é obrigatória depois de **cada** passada, não só no
  fim.
- **`nick_serv_race_test` é instável sob carga.** Falhou uma vez na partição 3
  com `refute_receive {:force_rename, _}, 500` recebendo o timeout de 60s;
  passa isolado e no `make ci` seguinte. É relógio de parede dentro de uma
  partição concorrida, não regressão deste item.

**Arquivos tocados** — migration `create_saved_messages`,
`chat/saved_messages.ex`, `chat/schemas/saved_message.ex`,
`chat_live/save_events.ex`, `chat_live/components/saved_dialog.ex`,
`components/ui/dialogs/saved_dialog.ex`, `chat_live/pin_events.ex`,
`chat_live/context_menu_events.ex`, `components/ui/chat/chat_context_menu.ex`,
`components/ui/shell/start_menu_app.ex`, `chat_live/window_registry.ex`,
`live/app/chat_live.ex` + `.html.heex`,
`help_topics/{features,user_interface}.ex`, dois `.heex` de ajuda,
`help_content/chat_status_features.ex`, `e2e/tests/chat-saved-messages.spec.ts`,
`scripts/i18n_apply_translation_overrides.py` e os catálogos `chat`, `dialogs`,
`help`, `help_features`, `help_ui`, `ui`.


---

## Auditoria de fechamento da Onda 4 — 2026-09-24

Varredura dos 13 commits locais contra o plano, o código e este arquivo, antes
de qualquer push. O que foi conferido e o que saiu dela.

**Conferido e correto**

- Cada item de 1.1 a 4.4 foi lido contra a sua lista de Atividades do plano.
  Os desvios encontrados já estavam registrados e justificados: `IrcTabs` sem
  selo de menção (3.2), `Reactions` validando em vez de `Chat.Policy.can_react?`
  (3.1), `web_push_ex` no lugar de `web_push_encryption` (2.3), `cmd-list`
  reusado em vez de um tópico novo para o catálogo frio (1.2, que é o que a
  regra 6 manda).
- **As 8 migrations replicam do zero**, revertem as 8 e reaplicam, tudo com
  saída 0. Testado num banco vazio, não no incremental.
- **A decisão travada continua de pé**: `route_valid_nickname/2` só leva a
  senha ou a registro, e não existe caminho de convidado em lugar nenhum da
  tela de conexão.
- Rotas públicas novas (`/account/verify/:token`, `/account/reset/:token`)
  estão no loop de locales **e** sem prefixo — a armadilha do `/join/:slug`.
- Nenhum `TODO`/`FIXME`, nenhum teste pulado, nenhum evento novo sem handler,
  nenhum `attr` declarado e não lido. Os 39 arquivos de teste novos têm
  `@moduletag`. Dialyzer rodou e passou.
- Ajuda: todo item acionável tem tópico. Os controllers JS novos têm Vitest;
  os hooks são ligação fina dentro do teto de 200 linhas.
- `delete_env(:web_push_ex, :vapid)` nos testes **não** é a armadilha que o
  1.1 descreve: `config/test.exs` não define a chave, então ausente é de fato o
  valor neutro, e os testes são `async: false`.

**Corrigido nesta auditoria**

- **1.2 não pôs a exclusão no `WHERE`, e isso custava linhas.** A atividade 1
  pedia `exclude` na consulta; o código trazia até `limit` linhas registradas e
  **depois** descartava as que já estavam vivas. Com o teto de 500, cada canal
  rodando comia uma vaga da metade fria — o `:limit` documentado como "da
  metade fria" era, na verdade, da metade registrada. Agora são duas consultas:
  a fria exclui os nomes vivos dentro do `WHERE`, e os vivos são buscados por
  nome, sem teto, só para saber quando a sala foi usada pela última vez.
  Asserção nova em `directory_test`, vista vermelha antes e depois da correção.

**A varredura de browser encontrou dois defeitos que nenhum gate de item pegou**

Doze batches em sequência — a primeira varredura completa sobre os 13 commits.
Dez verdes, dois vermelhos, e os dois eram reais:

- **`commands` (2 specs): `/pin` e `/unpin` não tinham `Syntax` nem
  `Examples`.** `chat-command-registry` varre **todo** comando registrado e
  exige a forma que todas as outras páginas de comando seguem; o item 4.3
  escreveu prosa livre e o gate dele era `channels`, então ninguém rodou o
  spec que cobria isso. As duas páginas foram reescritas na forma canônica
  (Syntax, Parameters, How It Works, Who can, Rules & Limits, Examples, See
  Also), e uma varredura conferiu que **nenhuma** página `cmd_*` está sem as
  duas seções.
- **`public` (1 spec): a janela do `/privacy` virou uma tira.** Os itens 2.3,
  4.1 e 4.2 acrescentaram uma seção cada — push, o cookie de navegador, o
  endereço opcional — e ninguém alargou a janela. 560×908 dá proporção 1,62,
  acima do teto de 1,5 que `desktop-window-sizing` cobra. Alargada para 680.

A lição é a do gate por item: **um item que acrescenta a uma superfície
compartilhada precisa rodar o batch daquela superfície, não só o seu.** Um
comando novo é o batch `commands`; um parágrafo no `/privacy` é o `public`.

**Registrado, não corrigido**

- **3.3, atalho de teclado: avaliado e recusado.** O plano pedia "avaliar em
  `Chat.KeyBindings`; se entrar, atualizar Keyboard Shortcuts". Não entrou, e a
  entrada de progresso do item não dizia isso. O botão "Primeira não lida" só
  aparece quando há algo a pular, e um atalho global para uma ação que quase
  sempre não tem alvo é ruído. Fica dito aqui.
- **2.3 continua com a verificação manual pendente** (`e2e/TEST_BACKLOG.md`):
  um push real contra um serviço de push de verdade, uma vez, antes de um
  release que toque nisso. Estes 13 commits tocam. **É bloqueio de release, não
  de commit.**
- **4.2 não construiu o terceiro uso do e-mail** (avisar de PM depois de N
  horas fora). Decisão registrada no item; `/privacy` descreve só os três usos
  que existem de fato, então o texto não mente.

**O plano não está concluído.** 13 de 18 itens. A Onda 5 inteira — 5.1 arquivo
público, 5.2 threads (plan mode obrigatório), 5.3 eventos, 5.4 avatar, 5.5
emoji do servidor, 5.6 mensagem de voz — não foi iniciada.


---

## Iteração 5.1 — Arquivo público indexável

Abre a Onda 5. Tudo o que um grupo sabe morre dentro da sala onde foi dito —
é a queixa número um contra as plataformas fechadas e a razão de ninguém novo
chegar sozinho: não há o que encontrar. Um canal que opta por isso ganha uma
página por dia, em texto puro, que um mecanismo de busca consegue ler.

**O que ficou**

- `public_archive` e `archive_since` em `registered_channels`. A segunda coluna
  é a ética: **nada dito antes do interruptor é publicado, nunca**. Desligar
  mantém o instante, para que religar não publique o trecho em que esteve
  desligado.
- `Chat.Archive` com `publish/1`, `unpublish/1`, `published?/1`, `days_for/1`,
  `messages_for/2` e `published_channels/0`. Uma consulta compartilhada carrega
  as duas metades do recurso: o corte por `archive_since` e o que conta como
  alguém falando (`message` e `action`, nada de `system`/`service`/`notice`).
- Publica-se o **texto visível**, nunca a fonte: uma página que imprimisse o
  formato de fio mostraria os dígitos do código de cor ao leitor.
- Rotas `/archive/:channel` e `/archive/:channel/:date`, sem prefixo **e** no
  loop de locales, com canônica sempre sem prefixo e **zero alternates de
  hreflang** — uma conversa não tem versão traduzida.
- Pedaço próprio no sitemap, `robots.txt` liberando `/archive/`, interruptor em
  Channel Central (só fundador) e mensagem de sistema no canal quando muda.

**Desvios do plano, conscientes**

- **Controller, não `ArchiveLive`.** O plano nomeava uma LiveView na atividade
  4 e, na mesma respiração, pedia `etag`/`304`/gzip na atividade 5 e `get/2`
  nos testes — que são coisas de controller. Nada nesta página se mexe; uma
  LiveView abriria um socket para desenhar texto do passado. O plano
  contradizia a si mesmo e eu segui a metade que os testes descreviam.
- **Nada é cacheado entre requisições**, ao contrário do `SitemapController`
  que o plano mandou copiar. Desligar o arquivo, apagar uma linha ou tornar o
  canal secreto tem de derrubar a página na requisição seguinte, e um corpo em
  `:persistent_term` continuaria respondendo. O pedaço do sitemap é construído
  por requisição pelo mesmo motivo.

**Aprendizados**

- **O CSRF do layout tornava o `etag` inútil.** A primeira versão fazia hash do
  documento renderizado; o layout carrega um token novo a cada requisição, e
  nenhum robô jamais teria revalidado nada. O `etag` passou a sair dos **dados**
  (as linhas e o que muda como elas leem), o que também permite responder 304
  antes de renderizar.
- **`max-age=300` mantinha no ar uma página já retirada.** O Playwright provou:
  o leitor voltou ao endereço depois de o fundador desligar e o próprio browser
  serviu a página do cache, sem consultar o servidor. Virou
  `max-age=0, must-revalidate` — revalidar não custa nada ao robô, que recebe
  304, e é a única configuração em que desligar realmente desliga.
- **A tela nova não renderizava sem o `landing_layout`.** Um `desktop_window`
  solto não tem workspace; a auditoria visual pegou na primeira foto, e a
  segunda mostrou a janela deslocada atrás do About — passou a `default_centered`
  com altura própria.
- **O erro de escopo do i18n se repetiu duas vezes na mesma iteração.** O passe
  de overrides casa **msgid**, não msgid+domínio: 41 entradas alheias na
  primeira passada ("Pinned Window", "(edited)", "Join %{channel}") e mais 14
  na segunda (Kick, Status, Auto — que o próprio `i18n.quality.check` acusou
  como desvio de glossário). Todas revertidas contra o snapshot, e os msgid
  compartilhados saíram do bloco. **Auditar depois de cada passada, não no fim.**
- **O palpite fuzzy de novo.** "That change could not be saved." veio copiado de
  "That note could not be saved." e "channel logs" de "channel list". Desta vez
  li antes de limpar a marca, que é o que faltou no 4.4.
- **Inventei uma `@section` que não existia** no spec de e2e, e `batches.mjs
  --check` recusou na hora: uma seção fora de batch é um spec que a varredura
  pula. Passou para `PW`, que é o batch que o Gate do item nomeia.

**Arquivos tocados** — migration `add_public_archive_to_registered_channels`,
`chat/archive.ex`, `services/registered_channel.ex`, `services/chan_serv.ex`,
`channels/server.ex`, `controllers/archive_controller.ex`,
`controllers/archive_html.ex` + dois `.heex`, `controllers/sitemap_controller.ex`,
`components/layouts/landing_live.html.heex`,
`components/ui/dialogs/channel_central_dialog.ex`,
`chat_live/components/channel_central_dialog.ex`,
`chat_live/pubsub_handlers/channel_state.ex`, `router.ex`,
`priv/static/robots.txt`, `help_topics/features.ex`,
`help_content/feature_public_archive.html.heex`,
`e2e/tests/archive-public.spec.ts`, e os catálogos `channels`, `chat`,
`dialogs`, `help`, `help_features`, `landing`.

---

## Iteração 5.2 — Threads

A maior mudança de interface do plano, e a que mais depende de não exagerar.
Responder já era bom; o que faltava era **saber que a conversa aconteceu**: uma
linha que juntou seis respostas parecia idêntica a uma que não juntou nenhuma, e
as seis ficavam espalhadas por trinta linhas de outro assunto.

**O que ficou**

- `Chat.Replies` resolve a raiz antes de montar a citação. `reply_to_id` passa a
  ser **o ponteiro da thread**, e o invariante "uma resposta nunca tem
  respostas" vira testável. Sem coluna nova, sem CTE recursiva, sem migração de
  dados: cadeias antigas continuam como sempre foram, apenas fora da contagem.
- `Queries.thread_for/2` — página ascendente (`id > cursor`), porque uma thread
  se lê para a frente e a linha que a começou já está acima — e
  `thread_counts_for_many/2`, um `group_by` só para a página inteira, na forma
  de `Reactions.summary_for_many/2`.
- Índice composto `(reply_to_id, id)` nas duas tabelas, substituindo os de
  coluna única de 2026-02: o composto responde às duas perguntas e cobre o que o
  antigo cobria.
- `StreamItem` busca reações **e** contagens na mesma passada; `reply_count`
  ausente e zero são a mesma frase e a linha não desenha nenhuma das duas.
- Janela Thread: raiz no topo, respostas em ordem, "Responder nesta thread" no
  rodapé. Tudo desenhado por `MessageRow` — o painel não tem ideia própria de
  como é uma mensagem.
- A ajuda ganhou `feature-threads` e o tópico de resposta foi **corrigido**:
  descrevia um botão ↩ de hover que não existe e pedia para escolher
  "Responder" dentro de uma frase em inglês. Ajuda que nomeia um controle
  inexistente é defeito, não estilo.

**Desvios do plano, conscientes**

- **Aplanamento na escrita, não na leitura.** O plano dizia "aplanadas na raiz"
  e "não uma coluna nova". Com `reply_to_id` apontando para o pai real, ler uma
  thread exigiria CTE recursiva em duas consultas e seria a primeira do
  repositório. Resolver a raiz em `Replies.attrs/2` custa um hop, e só quando o
  pai já é resposta. Consequência assumida: responder a uma resposta passa a
  citar a **raiz**, e a citação vira o marcador de qual conversa aquela linha
  continua.
- **A janela não ganhou composer.** `Components.Composer` é ilha de id fixo e o
  `send_update` do pai é roteado por `Composer.id()`: uma segunda instância
  dentro do ChatLive colidiria. O botão arma o composer da sala — que é
  literalmente "o `reply_to_id` vem do painel", sem forkar o componente.
- **Janela do desktop, não faixa lateral.** O plano dizia "painel lateral";
  neste produto toda lista é janela gerenciada. Uma faixa fixa na casca seria um
  conceito de layout novo para nada.

**Aprendizados**

- **`stream_insert` de um id que o stream não tem acrescenta a linha no fim.**
  Recontar a raiz quando chega uma resposta desenharia a raiz de novo lá
  embaixo, fora de ordem, se ela já tivesse rolado para fora da página
  carregada. `MessageViewport` ganhou `insert_if_present/2`, que usa o
  `rendered` que a ilha já mantinha — ela sempre soube o que tem na tela,
  ninguém tinha perguntado. Vermelho visto por sabotagem e revertido.
- **O script de overrides reescreveu 13 entradas alheias outra vez** (Kick,
  Auto, Status), o mesmo defeito do 5.1 — ele casa **msgid**, não msgid+domínio,
  e o valor curado no script já divergia do catálogo. A auditoria depois de cada
  passada pegou na hora; revertido contra o snapshot.
- **As chaves do override são texto desescapado.** Duas entradas com aspas
  internas não casaram e ficaram vazias, porque eu escrevi a chave com `\"` e o
  parser do script já desescapa. Só o gate `i18n.catalog.check` contou a
  verdade: `empty=2` em treze locales.
- **Todo palpite fuzzy do merge estava errado**, sem exceção: "%{count} reply"
  veio de "%{count} user", "Could not load more of this thread." veio das
  menções, "Opening a Thread" veio de "Opening". Lidos antes de limpar a marca,
  como manda a memória.
- **A auditoria visual pegou o que nenhum teste pegaria:** dentro da janela,
  cada resposta repetia a citação da raiz que já estava fixa no topo — três
  cópias da mesma frase. `without_quote/1` no painel. A janela é a citação.
- **O teste que conta consultas precisa ser `async: false`.** Verde sozinho,
  vermelho no `make ci`: o handler de telemetria conta as consultas de todos os
  testes assíncronos da partição. 97 em vez de 1. `reactions_test` já era
  síncrono pelo mesmo motivo, e eu não tinha lido por quê.

**Gates** — `make ci` 18/18 · `make e2e.batch BATCH=messages` 43 passed ·
`make e2e.batch BATCH=shell` 58 passed · auditoria visual em três quadros.

**Arquivos tocados** — migration `index_replies_by_parent`, `chat/replies.ex`,
`chat/queries.ex`, `chat_live/stream_item.ex`, `chat_live/thread_events.ex`,
`chat_live/components/thread_dialog.ex`,
`chat_live/components/message_viewport.ex`,
`components/ui/dialogs/thread_dialog.ex`,
`components/ui/chat/message_indicators.ex`, `components/ui/chat/message_row.ex`,
`components/ui/chat/chat_context_menu.ex`, `chat_live/context_menu_events.ex`,
`chat_live/pubsub_handlers/messages.ex`, `chat_live/window_registry.ex`,
`live/paginated_list.ex` + `state.ex`, `app/chat_live.ex` + `.html.heex`,
`assets/css/retrohex/components/chat-message.css`, `help_topics/features.ex`,
`help_content/feature_threads.html.heex` +
`feature_message_reply.html.heex`, `e2e/tests/chat-threads.spec.ts`, e os
catálogos `chat`, `dialogs`, `help`, `help_features`.

---

## Iteração 5.3 — Eventos agendados

O mecanismo que faz servidor pequeno voltar toda semana. Um canal que só existe
enquanto alguém está digitando não tem próxima vez; um evento **é** a próxima
vez, escrita onde a sala inteira vê.

**O que ficou**

- `channel_events` + `channel_event_attendees`, e `Channels.ScheduledEvents` com
  `create/3`, `list/2` (Page), `cancel/2`, `attend/2`, `unattend/2`,
  `attending_many/2`, `due_for_reminder/2`, `mark_reminded/2` e
  `cards_for_messages/1`.
- **Tudo em UTC, desenhado no fuso do leitor.** É o único valor do produto que
  erra nos dois sentidos se você escolher um lado só. Nada no domínio formata
  hora; `TimeFormatter` e o fuso da sessão fazem isso na borda.
- `TimeFormatter.format_until/1`, o espelho de `format_relative/1` — e separado
  dele porque são frases diferentes, não a mesma com sinal trocado. Algo já
  começado diz "agora" em vez de contar para trás.
- `EventReminderWorker` **varre** em vez de agendar um job por evento: um job já
  na fila para uma linha que mudou é como chega lembrete de algo que não vai
  acontecer. Lê as linhas no momento de lembrar, e `reminded_at` é o que impede
  a varredura seguinte de achar o mesmo evento.
- Duas entregas, ambas já existentes: a sala ouve como linha, e quem disse que
  vai recebe push. Sem canal de aviso próprio, sem ajuste próprio.
- Comando `/event` com o tempo como **atraso** (2h, 30m, 3d), nunca leitura de
  relógio — um comando não tem como perguntar de que fuso você falou.
- Card na conversa **e** linha na janela, os dois desenhados pelo mesmo
  `event_card`. O card resolve por id da mensagem de anúncio, uma query por
  página, na forma das reações.

**Desvios do plano, conscientes**

- **`announcement_message_id` no evento, não uma coluna em `messages`.** O plano
  não dizia como o card chega à conversa. A tabela de mensagens não precisa
  saber o que é um evento; o evento é que sabe qual linha o anunciou.
- **O card resolve no `MessageViewport`, junto com os share cards.** Mesma
  passada, mesma razão: uma página é o único lugar que sabe que é página.
- **Permissão no `Channels.Server`, não no handler.** Se alguém pode agendar é
  pergunta sobre este canal agora, e se responde onde a membership mora — a
  mesma regra que o `/pin` já seguia.

**Aprendizados**

- **As chaves do pass de overrides são texto desescapado, inclusive `\n`.** Em
  5.2 foi a aspa; aqui foi a quebra de linha. O parser roda `ast.literal_eval`,
  então `\n` na chave vira newline de verdade — escrever `\\n` não casa nada,
  em silêncio, e a descrição longa do `/event` saiu vazia em treze locales. Só
  `i18n.catalog.check` contou.
- **Dois msgid meus já existiam traduzidos em outro domínio** ("Events", "Could
  not load more events."). O pass casa msgid em qualquer domínio, então o certo
  não era traduzir de novo: foi **adotar a tradução existente** como valor do
  override. O produto já tinha decidido como se chama.
- **O guard de fallback pega coincidência entre idiomas.** "in %{span}" em
  alemão é literalmente "in %{span}", e o `i18n.source-fallback.check` acusa
  igualdade como inglês não traduzido. Virou "noch %{span}", que aliás lê melhor
  como fragmento solto.
- **`dgettext("errors", …)` no app de domínio cria um catálogo novo do nada** —
  `errors.pot` apareceu, e com ele 14 locales a encher. As mensagens de canal
  já têm casa: o domínio `channels`.
- **A auditoria visual pegou o card em itálico.** Ele pendura numa linha de
  sistema, que é cinza itálico — certo para "a sala falou de si mesma", errado
  para o objeto embaixo. Um card é coisa em que se clica, e voltou a ter o corpo
  de texto do resto da conversa.

**Gates** — `make ci` 18/18 · `make e2e.batch BATCH=channels` 32 passed ·
`BATCH=shell` 58 passed · `BATCH=commands` 40 passed · auditoria visual em
quatro quadros, com uma correção.

**Arquivos tocados** — migration `create_channel_events`,
`channels/scheduled_events.ex`, `channels/schemas/channel_event.ex` +
`channel_event_attendee.ex`, `channels/policy.ex`, `channels/server.ex`,
`chat/time_formatter.ex`, `notifications.ex`, `jobs/event_reminder_worker.ex`,
`jobs/push_dispatch_worker.ex`, `commands/handlers/event.ex`,
`commands/registry.ex`, `config/config.exs`,
`components/ui/chat/event_card.ex`, `components/ui/chat/message_row.ex`,
`components/ui/dialogs/events_dialog.ex`,
`components/ui/layout/list_states.ex`, `components/ui/shell/start_menu_app.ex`,
`chat_live/components/events_dialog.ex`,
`chat_live/components/message_viewport.ex`, `chat_live/event_events.ex`,
`chat_live/ui_actions/events.ex`, `chat_live/ui_action_handlers.ex`,
`chat_live/pubsub_handlers/channel_state.ex`, `chat_live/window_registry.ex`,
`app/chat_live.ex` + `.html.heex`,
`assets/css/retrohex/components/chat-message.css`, `help_topics/commands.ex` +
`features.ex`, `help_content/cmd_event.html.heex` +
`feature_channel_events.html.heex`, `e2e/tests/chat-channel-events.spec.ts`, e
os catálogos `chat`, `channels`, `commands`, `dialogs`, `help`,
`help_commands`, `help_features`, `ui`.

---

## Iteração 5.4 — Avatar no chat

O personagem que alguém escolheu no espaço passa a estar ao lado do apelido no
chat: na conversa, na lista de usuários e no card de consulta.

**A premissa do plano estava errada**

O plano dizia "ler a escolha de personagem **que já é persistida**". Não era. A
escolha vivia no processo do espaço e no `localStorage` do navegador — o próprio
moduledoc do picker diz por quê: "nada no servidor sobrevive a uma visita". Ela
sumia quando a pessoa saía, e o chat nunca teve como saber. Metade deste item
virou **fazer a escolha durar**, que é o que torna "o avatar do chat é o mesmo do
espaço" uma frase verdadeira em vez de uma intenção.

E a segunda parte também estava vencida: a preferência iria para
`user_preferences.display_settings`, mas essa tabela foi **removida** na migration
`20260904120000_drop_unwritten_columns`. Preferências de exibição vivem na
`Session`, como `strip_formatting` — é onde `show_avatars` foi.

**O que ficou**

- `avatar` em `registered_nicks` e `Accounts.Avatars` com `remember/2`,
  `for_nick/1` e `for_nicks/1` (uma query por roster / por página). Coluna na
  linha do apelido porque é identidade: some com o apelido, como o resto.
- As duas portas do espaço gravam — o picker do `SpaceLive` e o canal do espaço,
  porque o personagem também muda de dentro do mundo rodando.
- `Roster` carrega `avatar`; `MessageViewport` preenche na decoração, que é o
  ponto por onde **toda** linha passa — página, página anterior e mensagem que
  chega ao vivo.
- Retrato em `MessageRow`, nicklist e hover card, com o nome da classe no card.
- View ▸ Retratos de personagem, na barra e no Start.

**Desvios do plano, conscientes**

- **24×24, não 16×16.** A arte é autorada num tamanho e mostrada nesse tamanho;
  16×16 só sairia encolhendo, que a memória `no-aspect-ratio-deform` proíbe. O
  recorte fica em CSS — que é o que o próprio arquivo do picker já dizia:
  "cropping and positioning live here (CSS)". Testei quatro janelas e li as oito
  classes lado a lado antes de escolher; em 16 e 18 o herói e o bárbaro perdiam
  metade do rosto.
- **Sem arte nova.** A cabeça do primeiro quadro de cada classe, na folha que o
  picker já usa. Recortar não é redimensionar.

**Aprendizados**

- **Um `<span>` é inline, e inline ignora largura e altura.** O retrato estava no
  documento e em tela nenhuma — o Playwright achava o elemento e dizia "hidden".
  Nenhum teste de servidor pegaria isso; a auditoria visual pegou na primeira
  execução.
- **Duas listas são streams, e um stream não redesenha o que ninguém reinsere.**
  Escrever o teste já achou a primeira (a nicklist mantinha os retratos depois de
  desligar) e o e2e achou a segunda (a nicklist dos outros mantinha o rosto
  antigo depois de alguém trocar de personagem). A segunda virou broadcast
  `{:avatar_changed, …}` — e a rota dele em `PubsubHandlers` tem de ser
  **explícita**: caiu no catch-all e sumiu em silêncio, exatamente o que o
  comentário três linhas abaixo dela avisa.
- **Quebrei minha própria regra de dois commits atrás:** o teste que conta
  consultas nasceu `async: true`, verde sozinho e vermelho no `make ci` com 4 em
  vez de 1. A regra está em `docs/guide/testing.md` desde `14032e991`.
- **Uma categoria de ajuda inventada passa no compilador e falha no teste.**
  "Display & Appearance" não existe; a que existe é "Chat Display", e
  `topics_by_category` conta 294 contra 295 até alguém consertar.

**Gates** — `make ci` 18/18 · `make e2e.batch BATCH=shell` 59 passed ·
`BATCH=media` 57 passed (é onde vivem as specs de espaço) · auditoria visual em
três quadros, com um defeito encontrado.

**Arquivos tocados** — migration `add_avatar_to_registered_nicks`,
`accounts/avatars.ex`, `accounts/session.ex`, `services/registered_nick.ex`,
`chat/roster.ex`, `components/ui/chat/nick_portrait.ex`,
`components/ui/chat/chat_message.ex`, `components/ui/chat/message_row.ex`,
`components/ui/chat/nicklist.ex`, `components/ui/chat/hover_card.ex`,
`components/ui/shell/menu_bar_app.ex` + `start_menu_app.ex`,
`chat_live/components/message_viewport.ex` + `message_row.ex` + `nicklist.ex` +
`hover_card.ex`, `chat_live/stream_item.ex`, `chat_live/menu_toolbar_events.ex`,
`chat_live/hover_events.ex`, `chat_live/pubsub_handlers.ex` + `presence.ex`,
`live/app/space_live.ex`, `channels/space_channel.ex`,
`assets/css/retrohex/features/space-character-picker.css`,
`help_topics/features.ex`, `help_content/feature_character_portraits.html.heex`,
`e2e/tests/chat-character-portraits.spec.ts`, e os catálogos `chat`, `help`,
`help_features`, `ui`.

---

## Iteração 5.5 — Emoji do servidor

Um servidor pode aprender imagens e responder a elas pelo nome. Escreve-se
`:shrug:` e todo mundo **naquele servidor** vê a figura; quem está em outro
nunca vê, porque o conjunto pertence ao servidor.

**O que ficou**

- `custom_emojis` (nome único por `lower(name)`, arquivo, quem adicionou) e
  `Chat.CustomEmojis` com cache ETS semeado no boot e escrito em toda mudança,
  no formato do `Admin.RoleCache`. É ETS porque a leitura está no caminho de
  render de **toda** linha: resolver `:shrug:` por query seria uma query por
  linha.
- Nome de 2 a 32 caracteres, minúsculas/dígitos/sublinhado — o que alguém digita
  entre dois-pontos sem pensar. Um nome que não dá para digitar é um emoji que
  só existe pela metade.
- Resolução sobre o **texto** do markup renderizado, na mesma passada dos links
  de canal, e o nome vai escapado para dentro de dois atributos. Nome
  desconhecido fica exatamente como foi escrito — nunca vira imagem quebrada.
- Rota `/chat/emoji/:id` redirecionando para URL assinada, endereçada por **id**
  e não por nome: um nome liberado e retomado devolveria o que o navegador
  guardou. Assinar na renderização faria cada mensagem custar uma assinatura.
- Janela Admin ▸ Server Emoji, com upload pelo caminho presignado que os anexos
  já usam — é o que dá limite de tamanho, storage e limpeza de órfãos sem
  escrever nenhum dos três de novo. Teto de 100.
- Seção "Este servidor" no topo do seletor de emoji, inserindo `:nome:`.

**Desvios do plano, conscientes**

- **O plano dizia "`Chat.EmojiData` passa a compor catálogo padrão + custom".**
  Não compus: o catálogo padrão são caracteres Unicode, e `EmojiData.known?/1`
  é o que decide o que vale como **reação**. Misturar os dois faria uma reação
  aceitar um nome que a tabela de reações não sabe guardar. O seletor compõe na
  tela; o domínio segue separado.

**Aprendizados**

- **Uma sabotagem que não falha é um teste que passa pelo motivo errado.**
  O teste de "nome desconhecido fica texto" passava porque o resolvedor sai cedo
  quando o servidor não tem emoji nenhum — nunca chegava a olhar o nome. Agora o
  teste adiciona um emoji antes, e a sabotagem vermelha.
- **O alinhamento do `en` precisa corrigir divergência, não só preencher vazio.**
  Enchi os `msgstr` vazios e deixei os palpites fuzzy de pé: a janela ficou
  intitulada **"Server"** em vez de "Server Emoji", e só a auditoria visual viu.
  A varredura correta é a do 5.1 — todo `en` lê de volta o próprio msgid — e ela
  também achou dois defeitos antigos, um deles deixado pelo 5.4 ("Who Has One"
  exibindo "Who can").
- **A segunda lista à mão outra vez.** O Start monta o submenu Admin filtrando
  `family == :admin or id == "bot-management-dialog"` — uma lista de exceções
  mantida à mão. A janela nova entrou na barra e ficou fora do Start, e o teste
  de superconjunto acusou. Virou derivação: `render_when == :admin and family
  != :system`.
- **Um input de arquivo nativo é a única coisa nesta mesa que parece de outra
  década.** Escondido atrás de um rótulo com o mesmo relevo dos outros controles,
  como o composer já fazia.

**Gates** — `make ci` 18/18 · `make e2e.batch BATCH=shell` 60 passed ·
`BATCH=messages` 43 passed · auditoria visual em três quadros, com dois defeitos
encontrados e corrigidos.

**Arquivos tocados** — migration `create_custom_emojis`,
`chat/custom_emojis.ex`, `chat/schemas/custom_emoji.ex`, `chat/attachments.ex`,
`chat/queries.ex`, `application.ex`,
`controllers/app/emoji_controller.ex`, `router.ex`,
`live/app/chat_helpers.ex`, `components/ui/chat/emoji_picker.ex`,
`components/ui/dialogs/server_emoji_dialog.ex`,
`chat_live/components/emoji_picker_dialog.ex`,
`chat_live/components/server_emoji_dialog.ex`,
`chat_live/ui_actions/bots.ex`, `chat_live/ui_action_handlers.ex`,
`chat_live/bot_events.ex`, `chat_live/window_registry.ex`,
`components/ui/shell/menu_bar_app.ex` + `start_menu_app.ex`,
`live/app/chat_live.html.heex`,
`assets/css/retrohex/components/chat-message.css`, `help_topics/features.ex`,
`help_content/feature_server_emoji.html.heex`,
`e2e/tests/chat-server-emoji.spec.ts`, e os catálogos `chat`, `dialogs`,
`help`, `help_features`, `ui`.

## Iteração 5.6 — Mensagem de voz

Algumas coisas saem mais rápido faladas que digitadas. No celular o composer
oferece uma tira de gravação: até um minuto, e a gravação sobe pelo caminho de
anexo que já existe.

**O que ficou**

- `js/lib/uploads/voice_recorder.js` — a máquina de estados sobre `MediaRecorder`
  e o fluxo de mídia, sem nada de LiveView. Toda saída solta as faixas: a que
  terminou, a descartada, a que bateu no teto e a janela fechada no meio.
  `destroy` é o espelho exato do `mount`.
- `js/lib/uploads/voice_recorder_panel.js` — o controller de DOM que escolhe
  qual parte da tira aparece. Nenhuma palavra em JS: as três mensagens e os
  três botões são renderizados pelo servidor, e a tira carrega
  `phx-update="ignore"` porque o composer re-renderiza a cada tecla.
- Hook fino de 45 linhas: cria o controller, empurra `voice_recorded` e chama
  `uploadTo`. `navigator.mediaDevices` é primitivo proibido dentro de hook, e
  este é o motivo da regra existir.
- Domínio: `Chat.VoiceMessages` com o teto de 60 s e a lista de contêineres que
  uma gravação pode ser, e uma porta única em `prepare_direct_upload` — metadado
  que não declara gravação é descartado inteiro, e um tipo fora da lista não
  reserva linha nem URL assinada.
- A duração vive no `preview_metadata` que a tabela já tinha; nenhuma migração.
  Ela é escrita no único instante possível: a reserva do upload, empurrada pelo
  hook logo antes do `uploadTo`.
- Ladrilho próprio: "Mensagem de voz", a duração e o player. Sem nome de
  arquivo — é um timestamp que o gravador inventou, e pôr isso onde vão as
  palavras de alguém é a interface admitindo que não tem o que dizer.

**Desvios do plano, conscientes**

- **O plano dizia "grava só no mobile e em navegador com permissão" sem dizer
  quem decide.** Ficaram dois portões, cada um do lado que sabe: o servidor não
  renderiza a tira fora de `mobile_viewport`, e o controller esconde a tira num
  navegador que não grava. Um botão que pede microfone e depois se explica é
  pior que botão nenhum.

**Aprendizados**

- **O contêiner WebM guarda os dois, e a extensão decidia.** `Preview.classify`
  perguntava a extensão antes do tipo, então uma gravação `audio/webm` chamada
  `.webm` era classificada **vídeo** — um retângulo preto onde vai um player.
  Áudio passou a ser consultado antes de vídeo, e o arquivo gravado sai `.weba`.
  Defeito que já estava lá para qualquer anexo de áudio em WebM.
- **Uma segunda declaração do mesmo alvo é uma segunda coisa para manter
  verdadeira.** O hook lia `data-voice-target` enquanto o elemento já dizia a
  quem pertence em `phx-target` — e o teste de LiveView provou a diferença: um
  evento disparado no elemento sem `phx-target` vai para o LiveView raiz e some
  no log de "evento não roteado". Ficou uma declaração só.
- **Uma sabotagem que não falha, de novo, e por um motivo diferente.** "O teto
  para a gravação" passava mesmo trocando `stop()` por `finish()`, porque os
  dois zeram o estado deste lado. O que a troca quebra é o `MediaRecorder`, que
  continua com o microfone aberto. A asserção virou o estado do dublê, não o
  deste lado.
- **A auditoria visual pegou uma tira desequilibrada, não um bug.** O rodapé do
  ladrilho tinha só "Open" encostado à direita e um vão cinza à esquerda; ganhou
  o tamanho do arquivo, que num celular é informação e não enfeite.
