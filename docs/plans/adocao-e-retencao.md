# Adoção e retenção

Plano para fechar as lacunas que impedem uma pessoa de **entrar, voltar e
interagir** no RetroHexChat. Não é um plano de features novas de profundidade —
em profundidade de IRC, bots, WebRTC, espaços e arcade o produto já passa de
Discord e Slack. É um plano sobre o que as pessoas fazem todo dia sem pensar e
que aqui não existe.

Este documento descreve trabalho em aberto. Quando cada onda shippar, apagar a
seção correspondente e mover só as decisões duráveis para o guia adequado.
Quando a última onda shippar, apagar o arquivo.

## Decisões de produto já travadas

- **Não existe entrada como convidado.** Entrar exige um nick válido e
  registrado. A tela de conexão continua sendo nick → senha (ou nick → registro)
  como está hoje em `ConnectForm.route_valid_nickname/2`. Nenhum item deste
  plano enfraquece isso, e qualquer proposta de "entrar sem senha" está fora de
  escopo permanentemente.
- **O que atrapalha a adoção não é falta de profundidade, é atrito e ausência de
  retorno.** As ondas estão ordenadas por isso: primeiro parar de perder o que
  já existe, depois existir fora da aba, depois o laço social, depois uso diário
  de verdade, e por último crescimento orgânico.
- **Nada aqui é publicidade.** Todo item é uma capacidade que a pessoa usa.

## Regras que valem para todos os itens

Não repetidas em cada seção — valem em todas.

1. **TDD é não-negociável (`AGENT-GUIDE` §1.4).** O teste é escrito antes do
   código. Cada item abaixo lista o que testar, em que arquivo e em que nível.
   A ordem dentro de um item é sempre: teste de domínio puro → teste de
   domínio com banco → teste de componente → teste de LiveView → Playwright.
2. **A pirâmide vale.** Muito `:unit` sem banco, `:integration` focado,
   `:liveview`/`:liveview_feature` mínimo. `@moduletag` correto ou o teste roda
   na partição errada de CI.
3. **Nunca assertar em `send_update`/stream assíncrono.** Assertar em estado
   síncrono (`:sys.get_state`), em unidade de domínio/componente, ou em dado
   persistido. Sem `sleep`, sem render-retry (`docs/guide/testing.md`).
4. **Uma asserção de ausência só vale se você a viu ficar vermelha.** Reverter a
   correção uma vez e confirmar a falha é a única prova de que o teste funciona.
5. **`@spec` em toda função pública.** Dialyzer e Credo `--strict` são gate.
6. **Ajuda é obrigatória para qualquer coisa acionável** (`AGENT-GUIDE` §12).
   Comando novo → categoria Commands. Feature nova → Features. Janela/diálogo
   novo → User Interface. Atalho novo → atualizar Keyboard Shortcuts. Reusar id
   de tópico existente em vez de duplicar. Nada que a pessoa não possa acionar
   ganha tópico.
7. **i18n pelo pipeline, nunca `mix gettext` cru.** `make i18n.gettext.extract`
   e depois `make i18n.gettext.merge DOMAINS=<domínio> APP=web|domain`. Rótulo
   curto de botão/menu entra em `scripts/i18n/glossary.py`, não vai para a
   máquina traduzir.
8. **Ícone novo**: módulo em `components/icons/` escolhido pelo que o ícone
   **desenha**, uma linha em `components/icons/registry.ex`, SVG plano sem
   `id`/`defs`/gradiente. `icons_registry_test.exs` pega o esquecimento.
9. **Zero cor em Elixir ou JS.** `make lint.css` (`mix audit.styles --strict`)
   precisa fechar com 0 LOW / 0 MEDIUM / 0 HIGH.
10. **Hook JS é ligação fina** (`AGENT-GUIDE` §15.1): listeners, `handleEvent`,
    `pushEvent`, criar/destruir um controller de `js/lib/`. Toda decisão vai
    para `js/lib/<área>/<nome>.js` e é testada sem LiveView, em Vitest. Teto de
    200 linhas por hook, sem escopo mutável em `js/lib/`.
11. **Janela nova é declarada uma vez** em `ChatLive.WindowRegistry`; markup,
    taskbar, menu Iniciar e barra de menus derivam de lá. Estado inicial de ilha
    gerenciada carrega no `mount` da ilha, nunca num `send_update` pós-mount.
12. **Toda rota pública entra também no loop de locales do router.**
    `/join/:slug` já quebrou em `/pt-BR/join/…` uma vez; o primeiro segmento
    novo não pode colidir com tag de locale (`config/i18n_locales.exs`).
13. **Spec Playwright nova leva `@section`/`@flow` e depois `make e2e.catalog`.**
    `make ci` falha com o catálogo desatualizado.
14. **Gate final é `make ci` inteiro, sem pipe.** `make ci > log 2>&1; echo $?`.
    `mix format` antes. Playwright nunca é o gate e nunca roda como suíte
    inteira — `make e2e.batch BATCH=<nome>`.
15. **Cada item é um commit coerente.** Direto na `main`, com
    `git fetch origin` + `git pull --ff-only origin main` antes, e
    `git add <caminhos exatos>` — nunca `-A`.

---

# Onda 1 — parar de perder o que já existe

Três itens baratos cujo efeito é impedir que a pessoa que já chegou seja
expulsa por decisão nossa.

## 1.1 — A identidade e o canal deixam de expirar em 7 dias

### Estado hoje

- `apps/retro_hex_chat/lib/retro_hex_chat/services/nick_expiry.ex` —
  `@default_expiration_days 7`.
- `apps/retro_hex_chat/lib/retro_hex_chat/services/chan_expiry.ex` —
  `@default_expiration_days 7`.
- `config/config.exs` roda os dois workers a cada 6 h
  (`{"15 */6 * * *", RegisteredNickExpiryWorker}` e
  `{"0 */6 * * *", RegisteredChannelExpiryWorker}`) e mais uma vez em `@reboot`.
- `NickExpiry.purge/1` protege **apenas** quem está identificado naquele
  instante (`protected_nicks/1`) e administradores
  (`admin_protected_nicks/0`). Quem não está conectado no momento da varredura
  não é protegido por nada.
- A purga não remove só a linha: ela promove sucessão de fundador
  (`handle_founder_succession/1`), remove canais órfãos, entradas de access
  list, bans, exceções de ban e de convite, e mensagens de boas-vindas. O
  resultado é medido em `purge_result`.

Ou seja: quem passa duas semanas fora volta e o nick sumiu, o canal que fundou
sumiu, e o nick pode estar com outra pessoa. Isso faz sentido num IRC com
namespace disputado; num produto que quer adesão é a maior autossabotagem do
código.

### Decisões

- **Nick expira em 180 dias de inatividade. Canal registrado, em 90.**
- **O prazo sai da constante de módulo e passa a ser configuração lida em
  runtime.** Um servidor auto-hospedado precisa mudar isso sem recompilar, e a
  landing vende exatamente auto-hospedagem. A constante permanece como default.
- **A cadência do cron não muda.** Continua de 6 em 6 horas: o custo é uma
  query, e diminuir a frequência só esconderia erro.
- **O aviso antes de expirar fica para a onda 4**, porque depende de e-mail
  (item 4.2). Nesta onda entra só o prazo e a leitura de config.
- **O `opts[:expiration_days]` continua existindo** — é como os testes
  constroem a borda sem mexer no relógio.

### Atividades

1. `config/config.exs`: adicionar
   `config :retro_hex_chat, :expiry, nick_days: 180, channel_days: 90`.
2. `config/runtime.exs`: sobrescrever com `RHC_NICK_EXPIRY_DAYS` e
   `RHC_CHANNEL_EXPIRY_DAYS` quando presentes, validando que são inteiros
   positivos e falhando no boot quando não são (o arquivo já usa esse padrão
   para as credenciais do admin).
3. `services/nick_expiry.ex`: trocar `@default_expiration_days` por um
   `defp configured_expiration_days/0` que lê `Application.get_env/3` com o
   default atual. `expired_count/1` e `purge/1` passam a usar
   `Keyword.get(opts, :expiration_days, configured_expiration_days())`.
4. `services/chan_expiry.ex`: mesma mudança.
5. `jobs/oban_health.ex`: conferir a linha que chama
   `NickExpiry.expired_count(now: now)` e o painel que mostra `expired` — se
   algum texto cita "7 dias", passa a citar o valor configurado.
6. Texto da tela de conexão: `connect_form_panel.ex` diz hoje
   *"Nicknames unused for 7 days are automatically released"*. Passa a citar o
   prazo configurado, via interpolação — **não** um novo literal com "180"
   dentro, que apodrece no dia em que o operador mudar a variável.

### Testes (escrever primeiro)

- `apps/retro_hex_chat/test/retro_hex_chat/services/nick_expiry_test.exs`
  (já existe): novo caso provando que, **sem** `opts[:expiration_days]`, um nick
  visto há 30 dias **não** é candidato, e um visto há 200 dias é. Hoje o teste
  passa `expiration_days` explicitamente em todo lugar — é exatamente por isso
  que a constante de 7 nunca foi questionada por um teste.
- Mesmo par em
  `apps/retro_hex_chat/test/retro_hex_chat/services/chan_expiry_test.exs`.
- Caso de configuração: com `Application.put_env(:retro_hex_chat, :expiry, ...)`
  dentro do teste (e `on_exit` restaurando), a varredura respeita o valor. Usar
  valor neutro no `on_exit`, nunca `delete_env` — teste de feature roda
  concorrente e apagar config global já derrubou mount alheio.
- LiveView/componente: `connect_form_panel` renderiza o prazo configurado.
  Asserção em `data-testid` explícito, porque extração de texto do Floki
  vaza texto de ícone.

### Ajuda e i18n

- Atualizar o tópico de NickServ em
  `chat/help_topics/services.ex` (o que hoje fala em liberação de nick) e o
  tópico de ChanServ.
- A frase da tela de conexão muda de msgid: `make i18n.gettext.extract` +
  `make i18n.gettext.merge DOMAINS=connect APP=web`. O msgid antigo sai; o novo
  carrega `%{days}` e o gate de placeholder cobre.

### Gate

`make ci` verde. Sem Playwright — não há superfície nova.

---

## 1.2 — O catálogo passa a mostrar salas que estão vazias agora

### Estado hoje

- `Channels.Directory.all/0` faz um `Registry.select` sobre os GenServers vivos.
  Canal sem processo **não existe** para o catálogo.
- `Channels.Supervisor` para o processo de canal vazio (`restart: :transient`).
- `Commands.Autocomplete.list_visible_channels/2` lê `Directory.all/0` ou
  `Directory.search/1` e filtra `secret?`/`private?`.
- `ChatLive.ChannelListEvents.open/1` e o filtro alimentam a ilha
  `ChannelListDialog`; a mesma função serve `/list`, o botão "browse all" e o
  menu.
- `registered_channels` já tem `last_activity_at` (não-nulo, com índice
  `add_registered_channels_last_activity_index`) e `modes` como string.

O efeito é um catálogo que só mostra o que os bots mantêm de pé. Uma sala boa
que esvaziou deixa de existir para quem chega.

### Decisões

- **O catálogo é a união de duas metades:** os canais vivos (Registry) e os
  canais registrados sem processo (Postgres).
- **A metade fria nunca mente.** Mostra `member_count: 0` e a última atividade,
  não uma contagem inventada.
- **Ordenação:** vivos primeiro, por número de membros desc; depois frios, por
  `last_activity_at` desc. Um catálogo que intercala vivo e frio esconde onde
  há gente.
- **Visibilidade continua valendo na metade fria**: um canal registrado cujo
  `modes` persistido contém `s` não entra; `p` entra como a linha `Prv` que já
  existe. A regra é a mesma de `Autocomplete.visible_channel/2` — parametrizada,
  não copiada (`AGENT-GUIDE` §1.12).
- **A sidebar de "populares" continua só com vivos.** Sugerir sala vazia a quem
  acabou de entrar não ajuda; o catálogo é onde a pessoa procura de propósito.
- **O filtro de busca da metade fria roda no `WHERE`**, nunca em `Enum.filter`
  sobre a tabela inteira (`AGENT-GUIDE` §5).

### Atividades

1. `apps/retro_hex_chat/lib/retro_hex_chat/services/queries.ex`: nova
   `list_cold_registered_channels/1` com `opts[:search]` e `opts[:exclude]`
   (os nomes já vivos), devolvendo `%{name, topic, last_activity_at, modes}`.
   `exclude` no `WHERE` com `not in ^names`.
2. `apps/retro_hex_chat/lib/retro_hex_chat/channels/directory.ex`: nova
   `catalog/1` que une `all/0`/`search/1` com a query acima e marca cada linha
   com `live?: true|false`. A união é decisão de domínio e mora aqui, não no web.
3. `commands/autocomplete.ex`: `list_visible_channels/2` passa a ler
   `Directory.catalog/1`. `visible_channel/2` ganha a leitura de `modes` a
   partir da string persistida para a linha fria — extrair um
   `Channels.Modes.secret?/1`/`private?/1` sobre string se ainda não existir,
   em vez de um `String.contains?` solto no `Autocomplete`.
4. `components/ui/dialogs/channel_list.ex`: a tabela ganha a coluna de última
   atividade, preenchida só na linha fria. A linha fria recebe um
   `data-testid="channel-row-cold"`.
5. `chat_live/components/channel_list_dialog.ex`: nada de novo na filtragem
   local — a ilha já recebe a lista pronta do parent.
6. Confirmar que entrar num canal frio funciona pelo caminho normal: o join
   levanta o GenServer via `Channels.Supervisor`. Se `ChannelListEvents` tiver
   algum guard de "canal existe no diretório", removê-lo.

### Testes (escrever primeiro)

- `apps/retro_hex_chat/test/retro_hex_chat/channels/directory_test.exs`
  (criar se não existir): união não duplica o canal que está vivo **e**
  registrado; ordenação vivos→frios; `live?` correto em cada metade.
- `apps/retro_hex_chat/test/retro_hex_chat/services/queries_channel_test.exs`:
  `list_cold_registered_channels/1` respeita `exclude`, aplica `search` no
  `WHERE`, e **não** devolve canal com `s` nos modos persistidos.
- `apps/retro_hex_chat/test/retro_hex_chat/commands/autocomplete_test.exs`:
  canal frio secreto ausente, canal frio privado como `Prv`, canal frio público
  presente com contagem zero.
- Componente:
  `apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/dialogs/…`
  — a linha fria renderiza a última atividade e **não** renderiza contagem de
  membros. Essa é uma asserção de ausência: revertê-la uma vez e ver vermelho.
- LiveView: abrir a janela de canais com um canal registrado e sem processo
  lista esse canal; clicar em Join entra nele.
- E2E: `make e2e.batch BATCH=channels`, spec nova com `@section` existente de
  canais, cobrindo "registro um canal, saio, e ele continua no catálogo".

### Ajuda e i18n

- Tópico de canais (categoria Channels) e o tópico do comando `/list` passam a
  explicar que a lista inclui salas sem ninguém agora.
- `make i18n.gettext.merge DOMAINS=dialogs APP=web` para a coluna nova.

### Gate

`make ci` + `make e2e.batch BATCH=channels`.

---

## 1.3 — Link de convite para canal, com prévia do que se fala lá

### Estado hoje

- `ShareLinks.Schema.Link` tem `@kinds ~w(call space p2p play)`. **Não existe
  kind `channel`** — hoje é impossível compartilhar um canal.
- `ShareLinks.Liveness.live?/2` e `ShareLinks.Card.of/1` despacham por kind.
- `JoinLive` monta o card: `subject/1` por kind, `surface_path/1` por kind,
  `enter_path/3` manda para `/connect?return_to=/join/<slug>` quem não tem
  sessão.
- `ChatLive.mount_connected_chat/5` já lê `params["join"]` e chama
  `Helpers.maybe_join_channel/2`. Ou seja, `/chat?join=%23sala` **já funciona**.
- `App.ReturnTo` já permite prefixo `/chat`, com query.
- `share_links` já guarda `creator_nick` — quem convidou já está no banco.
- `Channels.Visibility.nameable?/1` já decide se o nome de um canal pode
  aparecer para um estranho; `call`/`space` usam isso.
- `JoinLive` é `noindex` sempre.

### Decisões

- **Novo kind `channel`, target `%{"channel" => nome}`.**
- **O card mostra prévia real:** nome (quando `nameable?`), tópico, quantas
  pessoas dentro agora, e as **últimas 5 mensagens visíveis**. É a diferença
  entre "alguém te mandou um link" e "olha do que estão falando".
- **A prévia é texto visível, nunca fonte.** Lê `plain_content`
  (`coalesce(plain_content, content)`), sem renderizar cor de IRC — uma página
  pública não deve executar formatação que veio de qualquer pessoa.
- **A prévia só existe para canal listável e aberto.** Com `+s`, `+p` ou `+i`,
  o card diz o que é e não mostra nada do conteúdo. A mesma regra que impede o
  `call` de nomear um canal secreto.
- **O link continua sem conceder acesso.** Seguir um link de canal `+i` leva ao
  `/chat`, e o canal recusa com a política dele. O link nomeia a sala; quem
  decide é a sala.
- **O card diz quem convidou** — `creator_nick` já está lá.
- **O controle é "copiar convite", não escrever um card na conversa.** A regra
  "o card é a única porta" existe porque uma surface precisa ser anunciada para
  quem está na conversa. Um convite de canal serve para sair do produto: quem
  está na conversa já está lá. O controle copia o link e ponto.
- **`JoinLive` continua `noindex`.** Um convite não é conteúdo. Quem indexa é o
  arquivo público (item 5.1).

### Atividades

1. `share_links/schema/link.ex`: `@kinds` ganha `"channel"`; o changeset passa a
   validar o formato do `target` por kind — hoje qualquer mapa passa. Para
   `channel`, exigir `"channel"` string começando por `#` e com até 50 chars.
2. `share_links/liveness.ex`: cláusula `live?("channel", target)` — o canal está
   vivo se existe processo **ou** linha em `registered_channels`, e não é `+s`.
3. `share_links/card.ex`: cláusula `channel` — `count` = membros agora,
   `participants` continua vazio (a lista de quem está numa sala não é assunto
   de um card público), `channel_name` só quando `nameable?`.
4. `share_links/policy.ex`: `can_create?/2` hoje ignora o kind. Para `channel`,
   passa a exigir que o criador seja membro do canal, e operador quando o canal
   é `+i`. `channel_of/1` ganha a cláusula `channel` para que a revogação por
   operador funcione (hoje só `call` e `space` a têm).
5. **Nova query de domínio**, `Chat.Queries.preview_messages/2`: últimas N de um
   canal com `type in ~w(message action)`, `deleted_at is nil`,
   `select` de `author_nickname` + `coalesce(plain_content, content)` truncado,
   `order by id desc`, `limit`. **Não** reusar `list_messages/2`: ela traz linha
   inteira e pagina, e a prévia não pagina nada.
6. `RetroHexChatWeb.JoinLive`: `subject/1` e `surface_path/1` ganham a cláusula
   `channel`; `surface_path` devolve `~p"/chat?join=#{name}"`. Novo assign
   `preview` alimentado só quando a política permite.
7. `components/ui/join_card.ex`: novo slot para a prévia, texto puro, com
   `data-testid="join-preview"` e as cinco linhas como `<li>`.
8. Controle no chat: item no menu da conversa (via `WindowRegistry`/menu já
   existente) e no menu de contexto do canal na sidebar →
   `copy_channel_invite`, que chama `ShareLinks.create/1` e devolve o slug para
   `CopyValueHook` (já é hook crítico, nada novo em JS).
9. Ícone: reusar `icon_channels`. Nenhum ícone novo.

### Testes (escrever primeiro)

- `apps/retro_hex_chat/test/retro_hex_chat/share_links/…`: changeset aceita
  `channel` com target válido e recusa target sem `#`, com nome longo, ou vazio.
- Liveness: canal vivo → `true`; canal só registrado → `true`; canal `+s` →
  `false`; canal inexistente → `false`.
- Card: `channel_name` presente para canal listável, ausente para `+s`.
- Policy: não-membro recusado; membro de canal aberto aceito; membro comum de
  canal `+i` recusado; operador de `+i` aceito; operador revoga link de canal
  alheio.
- `apps/retro_hex_chat/test/retro_hex_chat/chat/queries_test.exs`:
  `preview_messages/2` ignora `system`/`service`/`notice`, ignora apagadas,
  devolve texto visível (não a fonte com códigos de cor), e respeita o `limit`.
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/join_live_test.exs`:
  usar **`get/2`**, não `live/2`, para o render morto do card — `live/2` sempre
  conecta e um `mount/3` desconectado é justamente o que um crawler e um
  unfurler recebem. Casos: card de canal aberto mostra prévia; card de canal
  `+s` não mostra; sem sessão, o botão aponta para
  `/connect?return_to=/join/<slug>`.
- **`/pt-BR/join/<slug>` responde.** Essa rota já quebrou uma vez porque
  dezesseis testes construíam o caminho do mesmo jeito que o código. Construir
  o caminho à mão, com o segmento literal.
- E2E: `make e2e.batch BATCH=public` — copiar convite num navegador, abrir em
  outro contexto sem sessão, ver a prévia, conectar e cair dentro do canal.

### Ajuda e i18n

- Tópico novo em Features: "Convidar para um canal" — onde está o controle, o
  que o link mostra, que ele não dá acesso, e como revogar.
- Atualizar "See Also" do tópico de canais e do de convites (`cmd-invite`), sem
  criar id duplicado.
- `make i18n.gettext.merge DOMAINS=share APP=web` e `DOMAINS=chat APP=web`.

### Gate

`make ci` + `make e2e.batch BATCH=public`.

---

# Onda 2 — o produto passa a existir fora da aba

Hoje, fechou a aba, o RetroHexChat deixa de existir. Não há Notification API,
não há service worker, não há manifest, não há push. O único sinal é o título
da aba (`hooks/notifications/document_title_hook.js`). Esta é a maior alavanca
isolada de retenção do plano inteiro.

Os três itens são sequenciais: 2.1 é barato e vale sozinho; 2.2 é pré-requisito
técnico de 2.3; 2.3 é o que realmente traz a pessoa de volta.

## 2.1 — Notificação de desktop com a aba aberta em segundo plano

### Estado hoje

- Zero uso de `Notification` no bundle. Verificado por varredura em
  `assets/js`.
- O servidor **já sabe exatamente quando avisar**:
  `ChatLive.PubsubHandlers.Messages.maybe_notify_unmuted/4` decide silêncio por
  canal mudo, e `notify_channel/4` já escolhe entre `:message` e `:highlight`,
  tocando som (`play_event_sound/3`) e piscando a aba
  (`maybe_flash_channel/4`).
- `SoundSettings` já guarda preferência por evento em duas colunas `:map`
  (`sound_mappings`, `flash_settings`) na tabela `sound_settings`, com dez
  tipos de evento em `@event_types`.
- `AGENT-GUIDE` §15 já nomeia "sound/title/notification" como família de hook
  **crítica** — ou seja, o lugar deste hook na classificação já está decidido.

### Decisões

- **Notificação de desktop é uma terceira coluna na janela de Sons**, ao lado de
  som e flash, por tipo de evento. Não é um interruptor global: as mesmas dez
  linhas de evento que já existem ganham uma caixa.
- **Default: ligada só para `pm` e `highlight`.** Notificar toda mensagem de
  canal transforma o recurso em ruído no primeiro dia.
- **Só dispara com `document.hidden`.** Notificação com a aba na frente é
  redundante com a linha que já apareceu na tela.
- **A permissão nunca é pedida no mount.** É pedida no clique da pessoa na
  caixa, porque é exatamente o gesto que os navegadores exigem — e porque um
  pedido de permissão no primeiro segundo é o jeito mais rápido de receber um
  "bloquear para sempre".
- **Nada de payload sensível fora do necessário**: título é o nome da conversa,
  corpo é o texto visível truncado, e só. Quem tem a conversa mudada
  (`muted_channels`) não recebe.
- **Clique na notificação foca a aba e ativa aquela conversa**, reusando o
  caminho que `switch_channel`/`switch_pm` já têm.

### Atividades

1. Domínio: `Chat.SoundSettings` ganha `notify_settings` como terceiro mapa, com
   os mesmos `@event_types`, `get_notify/2`, `set_notify/3`, defaults, e
   `save/2`/`load/1` estendidos. Migration
   `add_notify_settings_to_sound_settings` (`:map`, `null: false, default: %{}`).
   **Nada de tabela nova**: é preferência por evento, e o lugar dela já existe.
2. `ChatLive.Helpers.Session`: nova `maybe_notify_desktop/4`, irmã de
   `maybe_flash_channel/4`, que empurra `push_event(socket, "desktop_notify",
   %{conversation, title, body, tag})` quando a preferência permite. `tag` é a
   chave da conversa, para que o navegador substitua a notificação anterior da
   mesma sala em vez de empilhar cinco.
3. `pubsub_handlers/messages.ex`: `notify_channel/4` e o caminho de PM
   (`mark_pm_background/3`) chamam a nova função. Um ponto de chamada em cada,
   ao lado do som — **não** um terceiro caminho paralelo.
4. JS controller `assets/js/lib/notifications/desktop_notifier.js`:
   `createDesktopNotifier(deps)` com `permission()`, `request()`,
   `notify({title, body, tag})`, `close()`. Sem `this`, sem LiveView, estado no
   closure. É quem decide `document.hidden` e quem segura a referência para
   fechar no clique.
5. Hook `assets/js/hooks/notifications/desktop_notify_hook.js`: registra
   `handleEvent("desktop_notify", …)` e `handleEvent("desktop_notify_permission",
   …)`, e faz `pushEvent("desktop_notify_click", {conversation})`. Nada além
   disso — o teto é 200 linhas e este fica em algumas dezenas.
6. `hooks/critical_hooks.js`: registrar. **Não** entra em
   `lazy_feature_hooks.js` — um hook crítico na lista lazy é uma das coisas que
   `make lint.hooks` rejeita. Colocar o `phx-hook` no mesmo elemento que já
   carrega `DocumentTitleHook` (ou num irmão), porque um hook registrado e sem
   markup é falha de guard.
7. `ChatLive`: `handle_event("desktop_notify_click", …)` ativa a conversa,
   reusando `Helpers.Conversation`.
8. Janela de Sons (`components/ui/dialogs/…` de som) ganha a coluna e a linha de
   estado da permissão ("não pedida" / "permitida" / "bloqueada pelo
   navegador"), com o texto que explica que bloqueado só se resolve nas
   configurações do navegador.
9. `assets/js/SURFACE.txt`: os nomes de evento novos entram no snapshot;
   `scripts/surface_snapshot.sh --check` roda no CI.

### Testes (escrever primeiro)

- `apps/retro_hex_chat/test/retro_hex_chat/chat/sound_settings_test.exs`:
  defaults de `notify_settings` (só `pm` e `highlight` ligados), `set/get`,
  round-trip de `save/load`, e um evento desconhecido rejeitado.
- LiveView: mensagem em canal de fundo com a preferência ligada empurra
  `desktop_notify`; com a conversa mudada (`muted_channels`) **não** empurra;
  com a conversa ativa **não** empurra. Assertar no `push_event` capturado pelo
  `LiveViewTest`, que é síncrono — não em stream.
- LiveView: `desktop_notify_click` com a chave de um canal aberto ativa aquele
  canal (assertar em `:sys.get_state` do socket, não no render).
- Vitest `assets/test/lib/notifications/desktop_notifier.test.js`: com
  `document.hidden = false` não notifica; com `hidden = true` e permissão
  `granted` notifica; com permissão `denied` não notifica e **não** pede de
  novo; `tag` igual substitui. Injetar um duplo de `Notification` via `deps` —
  o contrato de hook proíbe o teste alcançar método privado.
- Vitest do hook: registra os `handleEvent` e chama o controller. Sem
  `Object.create(Hook)`.
- E2E: nenhum. Permissão de notificação não é dirigível de forma estável no
  Playwright sem um contexto com permissão pré-concedida; a cobertura de valor
  está no Vitest e no LiveView. **Registrar essa ausência como decisão**, não
  deixá-la como esquecimento.

### Ajuda e i18n

- Tópico "Notificações do navegador" na categoria Notifications & Sounds:
  onde ligar, por que só com a aba em segundo plano, o que fazer quando o
  navegador bloqueou.
- `make i18n.gettext.merge DOMAINS=chat APP=web` e `DOMAINS=dialogs APP=web`.
  Rótulos das colunas ("Som", "Piscar", "Notificar") entram no glossário.

### Gate

`make ci` (inclui `make lint.hooks` e `make lint.bundle`).

---

## 2.2 — PWA: o produto vira um ícone na tela inicial

### Estado hoje

- `priv/static/` tem apenas `assets`, `favicon.ico`, `images`, `robots.txt`.
- `RetroHexChatWeb.static_paths/0` é
  `~w(assets fonts images favicon.ico robots.txt)`;
  `static_only_matching/0` é `~w(favicon robots)`.
- A página `/install` da landing é sobre **auto-hospedar um servidor**, não
  sobre instalar o app. Não é o mesmo assunto e não deve ser confundida.
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/endpoint_static_test.exs` já
  existe e é o lugar certo para provar que um arquivo estático é servido.

### Decisões

- **O manifest existe; o service worker existe; e o service worker não faz
  cache de HTML.** Um shell cacheado com LiveView por trás é o tipo de bug que
  aparece uma semana depois como "a tela ficou velha". O SW cacheia **apenas**
  `/assets/*` digestado, que é imutável por definição.
- **`start_url` é `/chat`.** Quem instalou já conhece o produto; devolvê-lo à
  landing é atrito.
- **`display: standalone`**, sem barra de URL — combina com a estética de
  desktop e é o que faz o ícone parecer um aplicativo.
- **O SW é servido em `/sw.js`**, escopo raiz. Qualquer outro caminho limita o
  escopo e quebra o push do item 2.3.
- **O SW não é um entrypoint do esbuild.** É um arquivo estático escrito à mão,
  pequeno, versionado por uma constante interna. Passá-lo pelo bundler o
  colocaria sob o orçamento de bundle sem motivo.

### Atividades

1. `priv/static/manifest.webmanifest`: `name`, `short_name`, `start_url: "/chat"`,
   `scope: "/"`, `display: "standalone"`, `background_color` e `theme_color`
   (JSON estático — o veto a cor literal vale para Elixir e JS, não para um
   manifest, mas os valores devem ser os mesmos tokens do CSS).
2. Ícones 192×192 e 512×512 (e um `maskable`) em `priv/static/images/`.
   **Atenção ao `.gitignore`**: nome com hífen já foi engolido neste repositório;
   conferir `git status` depois de adicionar e, se necessário, um `!` explícito.
3. `RetroHexChatWeb.static_paths/0` ganha `manifest.webmanifest` e `sw.js`;
   `static_only_matching/0` ganha `manifest` e `sw`, porque `phx.digest`
   reescreve o primeiro segmento.
4. `priv/static/sw.js`: `install` com `skipWaiting`, `activate` com
   `clients.claim` + limpeza de caches de versão antiga, e um `fetch` que só
   responde do cache para requisições cujo caminho começa com `/assets/`. Todo
   `catch` registra — nada de engolir silencioso.
5. Registro do SW: uma linha em `assets/js/app.js` (e **não** em
   `public_pages.js`, que tem orçamento de 80 KB e é o caminho crítico de todo
   crawler), atrás de `"serviceWorker" in navigator`.
6. `<link rel="manifest">` nos três layouts: `Layouts.chat`, `landing_live`,
   `help_live`. Mais `theme-color` e `apple-touch-icon`.
7. A landing ganha uma linha sobre instalar o app — **em `/how-it-works` ou na
   home, nunca em `/install`**, que é sobre servidor próprio.

### Testes (escrever primeiro)

- `endpoint_static_test.exs`: `/manifest.webmanifest` responde 200 com
  `application/manifest+json`; `/sw.js` responde 200 com
  `text/javascript`; ambos sobrevivem ao digest (rodar o teste no ambiente que
  o CI usa para estáticos).
- Teste de layout: cada um dos três layouts carrega `rel="manifest"`. Há
  precedente em `trace_context_layout_test.exs`.
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/payload_budget_test.exs`:
  confirmar que o registro do SW não entrou em `public_pages.js`.
- Vitest do registro: com `navigator.serviceWorker` ausente não lança.
- E2E: `make e2e.batch BATCH=public` — o manifest é alcançável e tem
  `start_url` `/chat`. Instalação real de PWA não é dirigível; não fingir que é.

### Ajuda e i18n

- Tópico na categoria User Interface: "Instalar no celular ou no desktop".
  Existe controle (o prompt do navegador), então existe tópico.
- Landing: `make i18n.gettext.merge DOMAINS=landing APP=web`.

### Gate

`make ci` + `make e2e.batch BATCH=public`.

---

## 2.3 — Web Push: a pessoa é avisada com a aba fechada

Este é o item mais pesado da onda e o de maior retorno. Depende de 2.2.

### Estado hoje

- Nada. Sem `push_subscriptions`, sem VAPID, sem worker.
- Existe, porém, tudo de que ele precisa para decidir:
  `Surfaces.count/1` diz quantas telas a pessoa tem abertas;
  `Presence` diz quem está online; `Chat.Highlight.check/4` já decide o que é
  menção; `reconnect_states.channels` guarda em que canais a pessoa estava
  quando saiu; Oban já está configurado com filas e observabilidade
  (`Jobs.ObanHealth`).

### Decisões

- **Push existe para dois eventos e só dois: mensagem privada e menção ao seu
  nick em canal.** Push de toda mensagem de canal é como se desinstala um app.
- **Push só sai quando a pessoa não tem nenhuma tela aberta.**
  `Surfaces.count(nick) == 0`. Quem está com o chat aberto já recebeu som,
  flash, título e, se quis, notificação de desktop.
- **Quem decide "quem deve saber" é o conjunto de nicks citados no texto, não a
  lista de membros do canal.** Membro de canal é quem está online — a pessoa
  offline já foi removida da `Membership`. Então: extrair os tokens do texto
  visível que **podem** ser um nick (charset de `Accounts.NicknameValidator`,
  2 a 16 chars, no máximo 8 tokens), e fazer **uma** query indexada cruzando
  `registered_nicks` × `push_subscriptions` × `reconnect_states.channels`.
- **O enfileiramento é barato e mensurável.** Uma job por PM sempre; uma job por
  mensagem de canal apenas quando o autor não é bot e o tipo é `message` ou
  `action`. Com `unique: [period: 60, keys: [:nickname, :conversation]]`, uma
  rajada numa sala vira um push, não vinte.
- **Bots nunca geram push.** Hoje praticamente todo o tráfego do servidor é
  bot; sem esse filtro o recurso nasce como spam.
- **Assinatura morta é removida.** 404/410 do endpoint apaga a linha; falhas
  transitórias incrementam `failure_count` e a linha sai depois de N.
- **Sem VAPID configurado, o recurso não existe** — nem tabela consultada, nem
  botão na interface. Um auto-hospedador sem chaves não pode ver um controle
  quebrado. A mesma disciplina do TURN.
- **O payload é cifrado e mínimo**: título com o nome da conversa, corpo com o
  texto visível truncado, e a chave da conversa. Nada mais atravessa um serviço
  de push de terceiros.

### Atividades

1. Dependência: `{:web_push_encryption, "~> 0.3"}` em
   `apps/retro_hex_chat/mix.exs`. Chaves VAPID por env em `config/runtime.exs`,
   com o recurso desligado quando ausentes.
2. Migration `create_push_subscriptions`: `owner_nickname` FK para
   `registered_nicks(nickname)` `on_delete: :delete_all`, `endpoint` texto com
   índice único, `p256dh`, `auth`, `user_agent`, `last_success_at`,
   `failure_count` inteiro default 0, timestamps. Índice em `owner_nickname`.
3. **Novo contexto `RetroHexChat.Notifications`**, com o layer interno da casa
   (Schema, Queries, Policy, Service):
   - `subscribe/2`, `unsubscribe/2`, `list_for/1`
   - `candidates_for_channel_message/2` — a query única descrita acima
   - `deliver/2` — cifra e envia uma assinatura, classificando o erro
   - `enabled?/0` — VAPID presente
4. `Jobs.PushDispatchWorker` na fila nova `push` (adicionar a fila em
   `config/config.exs`, ao lado de `rss`, `maintenance`, `bots`, `scrape`,
   `persistence`). O worker resolve candidatos, filtra por `Surfaces.count/1`,
   monta o payload e envia. Telemetria e `ResultMetadata` no padrão que
   `docs/guide/background-jobs.md` exige — observabilidade é parte de "pronto".
5. Ponto de enfileiramento: `Chat.Service.broadcast_message/2` e
   `broadcast_private_message/3`. É o único lugar por onde as duas metades
   passam; enfileirar aqui evita o terceiro caminho paralelo.
   **Atenção**: `Channels.Server` também insere e publica mensagem
   (`do_handle_send_message/5`, `insert_persisted_message/2`). As duas vias
   precisam do mesmo enfileiramento e de **testes de contrato duplicados**
   enquanto as duas existirem (`AGENT-GUIDE` §5).
6. `sw.js` ganha `push` e `notificationclick`. `notificationclick` abre
   `/chat?conversation=<chave>` ou foca um client já aberto.
7. Interface: a janela de Sons ganha a linha "Avisar mesmo com o RetroHexChat
   fechado", que pede permissão, assina e mostra o estado. Um botão para
   revogar neste dispositivo.
8. Privacidade: `/privacy` ganha um parágrafo dizendo o que sai do servidor,
   para onde, e como desligar. Isso não é formalidade num produto cuja landing
   vende soberania de dados.

### Testes (escrever primeiro)

- Domínio puro: extração de tokens candidatos a nick do texto visível — respeita
  o charset do `NicknameValidator`, corta em 8, ignora URL (o `Chat.Highlight`
  já mascara URL; reusar a mesma máscara, não escrever a segunda).
- Domínio com banco: `candidates_for_channel_message/2` devolve só quem tem
  assinatura **e** o canal em `reconnect_states.channels`; não devolve o próprio
  autor; **uma** query (há precedente de teste de contagem de query em
  `queries_performance_test.exs`).
- Worker: com `Surfaces.count(nick) > 0`, nada é enviado — asserção de ausência,
  revertida uma vez para ver vermelho. Com zero telas, envia. Com 410 do
  endpoint, a linha some. Com erro transitório, `failure_count` sobe.
- Unicidade: duas mensagens na mesma conversa dentro da janela geram **uma**
  job. Assertar na tabela `oban_jobs`, não no relógio.
- Bots: mensagem de bot não enfileira. É o caso que decide se o recurso nasce
  usável.
- Contrato duplicado: o mesmo par de asserções pela via `Chat.Service` e pela
  via `Channels.Server`.
- `enabled?/0` falso: nenhuma job enfileirada, nenhum controle renderizado
  (asserção de ausência revertida uma vez).
- Vitest: `sw.js` não é importável como módulo de teste direto; extrair a
  decisão (qual client focar, qual URL abrir) para
  `assets/js/lib/notifications/push_routing.js` e testar essa função pura.
- E2E: nenhum. Push real depende de serviço externo. Documentar a lacuna no
  `e2e/TEST_BACKLOG.md`.

### Ajuda e i18n

- Tópico "Avisos com o chat fechado" em Notifications & Sounds: o que dispara,
  o que não dispara, como desligar por dispositivo, e o que acontece quando o
  servidor não tem chaves.
- Atualizar o tópico de privacidade da ajuda, se houver, e `/privacy`.

### Gate

`make ci`. Validação manual do envio real contra um endpoint de push de teste,
registrada no PR — verde em teste não prova entrega, do mesmo jeito que o
parser de RSS passava em tudo e rejeitava todo feed real.

---

# Onda 3 — o laço social de menor custo

Hoje a única forma de responder a alguém é escrever. Quem chegou agora não
escreve. Os três itens desta onda são o que todo concorrente tem e o que faz
uma sala parecer viva.

## 3.1 — Reações em mensagem

### Estado hoje

- A migration `add_message_interactions` trouxe **reply, edit e delete** para
  `messages` e `private_messages`. Reação não existe.
- As únicas "reactions" do código são as da conferência
  (`GroupCall.RoomServer`), que são efêmeras e outro conceito.
- `Chat.Service` já tem o caminho inteiro de uma mudança em mensagem já
  existente: `broadcast_to_conversation/3` publica em
  `Conversation.topics/1` com `Conversation.address/1`, e o web recebe em
  `PubsubHandlers.Messages` (`message_edited`, `message_deleted`,
  `reply_quote_updated`) e reinsere a linha via `MessageViewport.insert/2`.
- `StreamItem.from_message/1` e `from_private_message/1` já montam uma linha só,
  qualquer que seja a conversa.
- `EmojiPickerHook` já é hook crítico e `Chat.EmojiData` já tem o catálogo.
- O menu de contexto de mensagem (`ChatContextMenu.message_menu_items/1`) já tem
  Copiar / Copiar fonte / Responder / Editar / Apagar / Ignorar autor.

### Decisões

- **Uma tabela para as duas conversas, não duas.** `message_reactions` com
  `message_id` e `private_message_id` anuláveis e um `CHECK` de exatamente um
  preenchido. Canal e privado já estão forkados em duas tabelas por herança
  (`messages`/`private_messages`); não se acrescenta o terceiro fork
  (`AGENT-GUIDE` §1.12).
- **Só emoji do catálogo.** `Chat.EmojiData` valida. String arbitrária não entra:
  seria conteúdo não moderável escondido num contador.
- **Sem otimismo no cliente.** Reação é server-authoritative. Uma reação
  otimista que falha é pior que meio segundo de espera, e o stream já sabe
  substituir uma linha pelo id real.
- **Máximo de 20 emoji distintos por mensagem e 1 por pessoa por emoji.** O
  unique index garante o segundo; a política garante o primeiro.
- **A barra de reação aparece no hover da linha no desktop e no long-press no
  mobile** — o long-press já abre o menu de contexto, então a entrada é "Reagir…"
  no menu que já existe, mais os cinco emoji mais usados na barra de hover.
- **Reação não conta como não lida e não toca som.** É o ato mais barato que
  existe; transformá-lo em notificação o encarece.

### Atividades

1. Migration `create_message_reactions`: `message_id` e `private_message_id`
   com `references(... on_delete: :delete_all)`, `owner_nickname` FK para
   `registered_nicks(nickname)` `on_delete: :delete_all`, `emoji` string 32,
   `inserted_at`. Dois índices únicos parciais
   (`(message_id, owner_nickname, emoji) WHERE message_id IS NOT NULL` e o par
   para PM) e um `CHECK` de exclusividade — o nome da constraint entra no
   changeset, no padrão que `MessageRules` já usa com
   `content_format_constraint`.
2. `RetroHexChat.Chat.Reaction` (schema) e `RetroHexChat.Chat.Reactions`
   (contexto): `toggle/3`, `summary_for/1`, `summary_for_many/1`. O `summary` é
   `%{emoji => %{count: n, actors: [nick]}}`; quem é "meu" é decidido no web,
   com o nick da sessão, para que a mesma leitura sirva todo mundo.
3. `Chat.Policy.can_react?/2`: emoji no catálogo, teto de 20 distintos,
   mensagem não apagada.
4. `Chat.Service.toggle_reaction/3`: valida, grava, e publica
   `"reaction_changed"` por `broadcast_to_conversation/3` com
   `%{emoji, count, actors}`. Um `Observability.span` no padrão dos irmãos.
5. Carga em lote: o caminho que monta uma página de histórico
   (`MessageViewport.reset`, alimentado pelo parent) chama `summary_for_many/1`
   **uma vez** por página. Nunca uma query por linha.
6. `StreamItem`: `reactions` entra em `@optional_fields` — ausente quando não há
   nenhuma, porque a linha distingue ausente de vazio.
7. `PubsubHandlers.Messages`: cláusula `"reaction_changed"` que reconstrói
   aquela linha e reinsere. Mesmo formato de `message_edited`.
8. `ChatLive.ContextMenuEvents` + `CoreEvents`: evento `toggle_reaction` com
   `message_id`/`emoji`, no mesmo desenho de `reply_to_message`.
9. Componentes: `MessageRow` renderiza a tira de reações sob o corpo;
   `ChatContextMenu` ganha "Reagir…"; a barra de hover é markup + `phx-click`,
   **sem hook novo** — não há estado a manter no cliente.
10. CSS em `assets/css/`, tokens existentes, zero hex.

### Testes (escrever primeiro)

- `apps/retro_hex_chat/test/retro_hex_chat/chat/reactions_test.exs`:
  `toggle` adiciona e remove; duas pessoas no mesmo emoji contam 2; a mesma
  pessoa duas vezes conta 1; emoji fora do catálogo é recusado; 21º emoji
  distinto é recusado; reagir a mensagem apagada é recusado.
- Integração: apagar a mensagem apaga as reações (cascade); o mesmo para PM;
  `summary_for_many/1` em **uma** query para 50 mensagens.
- `apps/retro_hex_chat/test/retro_hex_chat/chat/service_test.exs`:
  `toggle_reaction` publica `reaction_changed` no tópico do canal e nos dois
  inboxes quando é PM. Assinar o tópico no processo de teste, assertar no
  conteúdo da mensagem (nunca em contagem de broadcasts), e fechar com um
  `GenServer.call` ao publicador.
- Componente `MessageRow`: com `reactions` presente renderiza a tira com
  `data-testid`; sem `reactions` **não renderiza nada** — asserção de ausência,
  revertida uma vez.
- LiveView: `toggle_reaction` da própria sessão atualiza a linha; o
  `reaction_changed` de outra sessão também. Assertar em estado síncrono.
- E2E: `make e2e.batch BATCH=messages` — duas sessões, uma reage, a outra vê;
  clicar de novo remove.

### Ajuda e i18n

- Tópico novo em Features: "Reagir a uma mensagem" — onde clicar no desktop,
  o long-press no mobile, que a reação não notifica ninguém.
- "See Also" do tópico de menu de contexto de mensagem e do de emoji.
- `make i18n.gettext.merge DOMAINS=chat APP=web` e `DOMAINS=chat APP=domain`.

### Gate

`make ci` + `make e2e.batch BATCH=messages`.

---

## 3.2 — Menção deixa de ser só uma cor

### Estado hoje

- `Chat.Highlight.check/4` já decide menção: nick próprio + palavras de
  destaque, palavra inteira, ignorando código de formatação e texto dentro de
  URL. Isso funciona e não muda.
- `PubsubHandlers.Messages` mantém `highlight_channels` (um `MapSet` de
  conversas com destaque) e `unread_counts` (um mapa de contagem).
  **Não existe contagem de menções** e não existe lista.
- `Chat.UnreadTracker` é puro e genérico: `increment/2`, `reset/2`, `get/2`.
- `Chat.Search.count_matches/3` já tem um `apply_mention_filter/2` com
  `:mention_nick`. Mas o moduledoc diz explicitamente que **não há query de
  lista** ali, e que uma exigiria contrato `RetroHexChat.Page`.

### Decisões

- **Menção ganha contagem própria, separada da contagem de não lidas.** O
  badge cinza diz "tem coisa nova"; o badge de menção diz "é com você". São
  perguntas diferentes e um número só não responde as duas.
- **Reusar `UnreadTracker` com um segundo mapa**, não escrever um segundo
  módulo. É exatamente o mesmo tipo de estado.
- **A janela "Menções" é uma busca persistida, não uma tabela nova.** A
  pergunta "quem me citou" é a busca do próprio nick nos canais da pessoa, e a
  pilha de busca já existe. Escrever uma tabela `mentions` exigiria computar
  menção no momento da escrita, o que exige carregar as palavras de destaque de
  todo mundo a cada mensagem — custo que só se justifica quando o push precisar
  dele (item 2.3), e lá o recorte é bem menor.
- **`Chat.Search` ganha a query de lista que seu moduledoc já previu**, sob o
  contrato `Page`, keyset por id, com `has_more` vindo de `limit + 1`.
- **Clicar num resultado leva até a mensagem.** O caminho já existe:
  `scroll_to_reply_parent` e o fallback `scroll_to_message_missing` para quando
  a mensagem está fora da página carregada.

### Atividades

1. `ChatLive`: novo assign `mention_counts`, alimentado por
   `UnreadTracker.increment/2` em `apply_background_message/4` e em
   `mark_pm_background/3` quando `decorated.highlighted`. Zerado no mesmo lugar
   onde `unread_counts` zera, ao ativar a conversa
   (`Helpers.Conversation`).
2. Componentes: `Conversations`, `IrcTabs` e `ChatTaskbar` ganham o badge de
   menção, com classe própria. Zero cor em Elixir; a classe vive no CSS.
3. `Chat.Search`: nova `list_mentions/3` — `nick`, lista de canais, `opts` de
   `Page`. `WHERE channel_name = ANY($1) AND ilike(coalesce(plain_content,
   content), $2) AND deleted_at IS NULL AND type IN ('message','action')`,
   `ORDER BY id DESC`, keyset. Índice: conferir se
   `add_messages_channel_id_index` cobre; se não, migration nova.
4. `WindowRegistry`: janela `mentions`, ícone existente (`icon_btn_search` ou
   um novo em `components/icons/` se nenhum servir), `managed?: true`.
   Taskbar, Iniciar e barra de menus derivam sozinhos.
5. Ilha `ChatLive.Components.MentionsDialog`: carrega a primeira página **no
   próprio `mount`** da ilha, não num `send_update` pós-mount, que corre com o
   patch de montagem. Cinco estados de lista obrigatórios
   (`components/ui/layout/list_states.ex`): vazio, carregando, fim, erro,
   truncado. Stream com `limit:` negativo.
6. Navegação: clicar num resultado ativa a conversa e empurra o scroll até o
   `data-message-id`, com o mesmo fallback que já existe.

### Testes (escrever primeiro)

- `apps/retro_hex_chat/test/retro_hex_chat/chat/unread_tracker_test.exs`: já
  existe; acrescentar o uso do segundo mapa não muda o módulo, então o teste
  novo é de LiveView.
- `apps/retro_hex_chat/test/retro_hex_chat/chat/search_test.exs`:
  `list_mentions/3` devolve `Page`; `has_more` vem do banco e não do tamanho da
  lista; ignora apagadas, `system` e `service`; o cursor é o id da última linha
  **crua**; página seguinte não repete nem pula.
- LiveView: mensagem com destaque em canal de fundo incrementa
  `mention_counts` **e** `unread_counts`; sem destaque incrementa só
  `unread_counts`; ativar a conversa zera os dois. Assertar em
  `:sys.get_state`.
- Componente: badge de menção só renderiza com contagem > 0 — ausência
  revertida uma vez.
- LiveView da ilha: a primeira página chega no render inicial (prova de que a
  carga está no `mount` da ilha).
- E2E: `make e2e.batch BATCH=persistence` — citar alguém offline, ela entra e
  encontra na janela de Menções.

### Ajuda e i18n

- Tópico "Menções" em Features: o que conta como menção (nick e palavras de
  destaque), onde fica o badge, a janela e o atalho se houver.
- Atualizar Keyboard Shortcuts se a janela ganhar atalho.
- "See Also" do tópico de palavras de destaque.

### Gate

`make ci` + `make e2e.batch BATCH=persistence`.

---

## 3.3 — Linha de "novas mensagens" e pular para onde parei

### Estado hoje

- Existe contagem de não lidas por conversa. **Não existe marcador de posição.**
  Quem volta depois de quatro horas cai no fim do scroll.
- `MessageViewport` já carrega dois conceitos de corte:
  `chat_clear_token` e `cleared_conversation_cutoffs`. O moduledoc já explica
  por que um `limit:` negativo remove justamente o que um prepend acabou de
  inserir — prender a régua num item sintético do stream cairia nessa armadilha.
- `reconnect_states` já persiste o que a pessoa tinha aberto (canais, aba ativa,
  abas de PM), com normalização defensiva em `ReconnectState.normalize/1`.
- `scroll_to_reply_parent` e `scroll_to_message_missing` já implementam
  "levar até uma mensagem que pode não estar carregada".

### Decisões

- **O marcador é o id da última mensagem lida, por conversa.**
- **Ele mora em `reconnect_states`**, numa coluna `read_markers` (`:map`,
  default `%{}`). É exatamente o que essa tabela é: o que essa pessoa tinha
  aberto e onde estava. Nenhuma tabela nova.
- **O marcador não avança enquanto você está lendo.** Avança quando a conversa
  perde o foco, ou quando a aba é focada com a conversa aberta. Se avançasse na
  chegada da mensagem, a linha nunca apareceria — esse é o erro clássico.
- **A régua não é um item de stream.** `MessageRow` recebe
  `unread_boundary_id` e desenha a régua acima de si quando o id bate. Um item
  sintético no stream se reordena e é podado pelo `limit:` negativo.
- **"Pular para a primeira não lida" é um botão na barra da conversa**, usando o
  caminho de scroll que já existe, com o mesmo fallback quando a mensagem está
  fora da página carregada.
- **Conversa sem marcador não desenha régua.** Primeira visita não tem "novo".

### Atividades

1. Migration `add_read_markers_to_reconnect_states` (`:map`, `null: false,
   default: %{}`).
2. `Chat.ReconnectState`: `read_markers` entra no tipo, em `new/0` e em
   `normalize/1` — chaves são nome de canal ou `pm:<nick>`, valores inteiros
   positivos, mapa limitado (teto, como `@max_channels` e `@max_open_pm_tabs`
   já fazem).
3. `ChatLive`: assign `read_markers`, carregado em
   `maybe_restore_reconnect_state/2` e salvo pelo mesmo caminho que já persiste
   o snapshot. Avanço no `tab_focused` (o `DocumentTitleHook` já empurra esse
   evento) e na troca de conversa.
4. `MessageViewport` passa `unread_boundary_id` para `MessageRow`.
   `MessageRow` desenha a régua. Texto traduzido, `data-testid="unread-divider"`.
5. `conversation_toolbar_actions.ex`: botão "Ir para a primeira não lida",
   visível só quando há marcador e há mensagem depois dele.
6. Atalho de teclado: avaliar em `Chat.KeyBindings`; se entrar, atualizar o
   tópico Keyboard Shortcuts. `F1` continua reservado.

### Testes (escrever primeiro)

- `apps/retro_hex_chat/test/retro_hex_chat/chat/reconnect_state_test.exs`
  (já existe): `normalize/1` descarta chave inválida, valor não inteiro, valor
  negativo, e corta o mapa no teto.
- Integração: round-trip de `save`/`load` com marcadores.
- Componente `MessageRow`: desenha a régua na mensagem cujo id é o marcador, e
  em nenhuma outra da mesma página. As duas asserções, e a negativa revertida
  uma vez.
- LiveView: chegar mensagem em conversa **ativa** não avança o marcador;
  `tab_focused` avança; trocar de conversa avança a que foi deixada.
- LiveView: conversa nunca aberta não tem marcador e não desenha régua.
- E2E: `make e2e.batch BATCH=persistence` — ler, sair, receber, voltar, e a
  régua está no lugar certo depois do reload.

### Ajuda e i18n

- Tópico em Chat Display: "Onde eu parei" — a régua, o botão, quando o marcador
  avança.
- `make i18n.gettext.merge DOMAINS=chat APP=web`.

### Gate

`make ci` + `make e2e.batch BATCH=persistence`.

---

# Onda 4 — uso diário de verdade

## 4.1 — Duas telas do mesmo nick ao mesmo tempo

O item mais arriscado do plano. **Entrar em plan mode antes de começar** — ele
cruza mais de um contexto e mexe no caminho de sessão.

### Estado hoje

- `ChatLive.mount_connected_chat/5` chama
  `SessionControl.disconnect(nickname, …, :chat)` e espera a confirmação
  (`takeover_expected?/2`, `wait_for_takeover_cleanup/1`). Abrir no celular mata
  o desktop. A tela de conexão diz isso em voz alta:
  *"One session per nickname"*.
- O que **não** bloqueia, e é a boa notícia:
  - `Channels.Membership` é um mapa por nick — duas abas são um membro só.
  - `Phoenix.Presence` suporta vários metas por chave nativamente.
  - `Surfaces` já conta telas por pessoa e `ChatLive.terminate/2` já só
    abandona os canais quando é a última (`if Surfaces.count(...) > 1`).
  - `chat_device_sessions` já é **uma linha por sessão** (`session_ref` único),
    não uma por nick.
- O que bloqueia de verdade:
  - `reconnect_states` tem chave primária `owner_nickname`. **Uma linha por
    pessoa** — a segunda tela sobrescreve a primeira.
  - `PutTrustedDevice` só põe `trusted_device_id` na sessão quando a pessoa
    marcou "lembrar este terminal". Sem isso não há identidade de navegador
    para chavear nada.
  - Estado de leitura (item 3.3) e contagens não são sincronizados entre telas.

### Decisões

- **Até 3 sessões de chat simultâneas por nick.** Acima disso, a mais antiga
  cai. Um teto é obrigatório: cada sessão é um processo com assinaturas,
  timers e estado.
- **A derrubada deixa de ser automática e vira escolha.** A tela de conexão já
  mostra sessões (Trusted Terminals); ganha "encerrar as outras sessões".
- **`reconnect_states` passa a ser por (nick, navegador).** Chave primária
  composta `owner_nickname` + `browser_id`.
- **Todo navegador ganha um `browser_id`**, independente de "lembrar este
  terminal": um valor opaco em cookie de longa duração, sem relação com
  identidade de pessoa. Sem isso, snapshot de reabertura entre telas continua
  se atropelando. Privacidade: é um id de navegador, não de pessoa, e a página
  `/privacy` passa a dizer isso.
- **Ban, nuke, ghost e mudança de nick continuam `:all`** e derrubam tudo. Só o
  takeover do próprio chat deixa de existir.
- **Estado de leitura sincroniza pelo servidor, não entre clientes.** Quando
  uma tela avança o marcador, o servidor publica no `Topics.inbox/1` e as
  outras telas daquele nick atualizam. O inbox já é assinado por todas.

### Atividades

1. `App.BrowserId` (web): plug que lê/cria o cookie e espelha na sessão, no
   mesmo desenho de `PutTrustedDevice`. Entra nos pipelines `:app` e
   `:landing_live`.
2. Migration `rekey_reconnect_states_by_browser`: nova PK composta, com
   backfill dos registros existentes para um `browser_id` sentinela.
3. `Chat.ReconnectState`: `load/1` e `save/2` passam a receber o par.
4. `ChatLive.mount_connected_chat/5`: remover o `SessionControl.disconnect`
   incondicional. No lugar, `SessionControl.enforce_limit/2`, que derruba a
   mais antiga só quando o teto é ultrapassado. `takeover_expected?/2` e
   `wait_for_takeover_cleanup/1` passam a rodar só nesse caso.
5. `SessionControl`: nova `enforce_limit/2`, contando sessões vivas pela fonte
   autoritativa (`chat_device_sessions` abertas, não o Registry — o guia é
   explícito: a verificação de sessão duplicada é query, não lookup, porque um
   processo morto e ainda não reiniciado mente).
6. Sincronização do marcador de leitura: novo evento no `Topics.inbox/1`,
   tratado em `PubsubHandlers` com cláusula explícita — **nunca** num
   `handle_info` catch-all, que é a mesma classe de bug de um `try/catch` mudo.
7. Tela de conexão: a lista de sessões abertas com "encerrar as outras"; o
   texto "One session per nickname" sai e é substituído pelo teto real.
8. `ChatLive.terminate/2`: revisar a interação com `Surfaces.defer_part/3` para
   duas telas do mesmo nick — já está certo por construção, mas é o ponto exato
   onde um erro aqui vira "saí de um canal em que ainda estou".

### Testes (escrever primeiro)

- `apps/retro_hex_chat/test/retro_hex_chat/chat/reconnect_state_test.exs`:
  dois `browser_id` diferentes guardam snapshots independentes; o mesmo
  `browser_id` sobrescreve.
- `SessionControl`: com 2 sessões, montar a terceira não derruba ninguém; a
  quarta derruba a mais antiga; ban continua derrubando todas.
- LiveView: duas sessões do mesmo nick recebem a mesma mensagem de canal uma
  vez cada; a saída de uma **não** tira a outra do canal — asserção de ausência,
  revertida uma vez, porque é exatamente o bug que este item pode introduzir.
- LiveView: avançar o marcador numa sessão atualiza a outra.
- Presença: duas sessões contam como uma pessoa online no nicklist.
- E2E: `make e2e.batch BATCH=persistence` e `BATCH=foundation` — dois contextos
  de navegador, mesmo nick, ambos vivos.
- **Roda `BATCH=foundation` inteiro antes e depois.** É o batch de autenticação
  e ciclo de vida; se algo quebra aqui, quebra ali.

### Ajuda e i18n

- Tópico de sessões em Getting Started ou Users & Identity: quantas telas, o
  que derruba o quê, como encerrar as outras.
- `make i18n.gettext.merge DOMAINS=connect APP=web`.

### Gate

`make ci` + `BATCH=foundation` + `BATCH=persistence`. Este item ganha um commit
só dele e um plano de reversão escrito no PR.

---

## 4.2 — E-mail opcional: recuperar a senha e ser avisado

### Estado hoje

- **Não há nenhuma dependência de e-mail no projeto.** Nem `swoosh`, nem
  `bamboo`, nem `gen_smtp`. Verificado nos três `mix.exs`.
- `registered_nicks` tem `nickname`, `password_hash`, `registered_at`,
  `last_seen_at`. Nada mais.
- `NickServ.register/3` grava e marca identificado. Não há recuperação: esqueceu
  a senha, perdeu a identidade até ela expirar.

### Decisões

- **E-mail é sempre opcional e nunca visível para ninguém.** O cadastro
  continua nick + senha. O e-mail é adicionado depois, numa janela de conta.
- **SMTP, não API de terceiro, como padrão.** A landing vende auto-hospedagem;
  obrigar uma conta num provedor de e-mail transacional contradiz o produto.
  `Swoosh.Adapters.SMTP` em produção, `Local` em dev, `Test` em teste.
- **Sem SMTP configurado, o recurso não existe** — nenhum controle renderizado.
  Mesma disciplina do TURN e do VAPID.
- **Três usos, nesta ordem:** recuperar senha; avisar antes do nick expirar
  (fecha o item 1.1); avisar de mensagem privada quando a pessoa está fora há
  mais de N horas e optou por isso.
- **Nada de digest nem de "sentimos sua falta".** Só o que a pessoa pediu.
- **`/privacy` passa a dizer o que é guardado, por quanto tempo, e como
  apagar.**

### Atividades

1. Dependências: `{:swoosh, "~> 1.16"}` e `{:gen_smtp, "~> 1.2"}` no app de
   domínio. `Swoosh.Adapters.Test` em `config/test.exs`.
2. `RetroHexChat.Mailer` + configuração por env em `config/runtime.exs`, com
   `Mailer.configured?/0`.
3. Migration `add_email_to_registered_nicks`: `email` string,
   `email_verified_at`, `email_token_hash`, `email_token_sent_at`. Índice único
   sobre `lower(email)` **parcial**, `WHERE email IS NOT NULL` — dois nicks sem
   e-mail não podem colidir.
4. `Services.NickServ`: `set_email/3`, `verify_email/2`, `request_reset/1`,
   `reset_password/3`. Token por `Phoenix.Token`, 24 h, guardado só como hash.
5. Rotas públicas novas: `/account/verify/:token` e `/account/reset/:token`, no
   pipeline `:landing_live` (bundle público, não o da aplicação), **dentro do
   loop de locales**. `account` passa a ser primeiro segmento reservado — checar
   contra `config/i18n_locales.exs`.
6. Janela "Conta" no chat: adicionar/trocar/remover e-mail, reenviar
   verificação, e as preferências de aviso.
7. `Jobs.NickExpiryWarningWorker`: avisa por e-mail quem tem e-mail verificado e
   está a 14 dias de expirar. Fecha o item 1.1.
8. Tela de conexão: "esqueci a senha", visível só com `Mailer.configured?/0`.
9. Limite de envio: token novo só depois de N minutos do anterior; mesma ideia
   de `@edit_debounce_seconds` em `Chat.Policy`.

### Testes (escrever primeiro)

- Domínio: `set_email` recusa formato inválido, recusa e-mail já usado por outro
  nick, aceita dois nicks **sem** e-mail (o índice parcial).
- Token: verifica, expira em 24 h, não pode ser reusado, e o token de reset não
  serve para verificar (e vice-versa).
- Reset: troca a senha, invalida o token, e **não** revela se o nick existe —
  a resposta é a mesma nos dois casos. Asserção explícita: um teste que aceita
  as duas respostas não testa nada.
- Debounce de reenvio.
- `Mailer.configured?/0` falso: nenhum controle renderizado, nenhuma job
  enfileirada — ausência revertida uma vez.
- Worker de aviso: avisa uma vez, não repete no dia seguinte, ignora quem não
  verificou.
- Rota: `/pt-BR/account/verify/:token` responde.
- E2E: `make e2e.batch BATCH=foundation` com `Swoosh.Adapters.Local` e leitura
  da caixa local.

### Ajuda e i18n

- Tópico "E-mail da conta" em Users & Identity: para que serve, que é opcional,
  quem vê (ninguém), como remover.
- Atualizar o tópico de NickServ e o de expiração.
- `/privacy` e `make i18n.gettext.merge DOMAINS=landing APP=web`.

### Gate

`make ci` + `BATCH=foundation`. Um envio real contra um SMTP de teste,
registrado no PR.

---

## 4.3 — Fixar mensagem no canal

### Estado hoje

- O canal tem `topic` (uma linha) e mensagem de boas-vindas
  (`channel_welcome_messages`). Não há pin. "As regras", "o link do evento" e
  "o combinado" somem no scroll.
- `Channels.Policy.operator?/2` e `Membership.rank/1` já respondem quem pode.

### Decisões

- **Pin é propriedade da conversa, não da mensagem.** Tabela própria.
- **Só canal.** Fixar numa conversa entre duas pessoas é um recurso à procura de
  um uso; se pedirem, entra depois sem mudar o modelo.
- **Operador ou acima.** Teto de 50 por canal.
- **`/pin` e `/unpin` são dois Handlers**, um módulo cada
  (`AGENT-GUIDE` §1.5), registrados em `Commands.Registry`, mais o item no menu
  de contexto de mensagem.
- **Uma janela lista os fixados** do canal ativo.

### Atividades

1. Migration `create_pinned_messages`: `channel_name`, `message_id` FK
   `on_delete: :delete_all`, `pinned_by`, `inserted_at`; único
   `(channel_name, message_id)`; índice `(channel_name, id)` para a paginação.
2. `RetroHexChat.Channels.Pins`: `pin/3`, `unpin/2`, `list/2` sob contrato
   `Page`.
3. `Channels.Policy.can_pin?/2`.
4. Broadcast `"pinned_changed"` em `Topics.channel/1`; cláusula explícita em
   `PubsubHandlers.ChannelState`.
5. Handlers `Commands.Handlers.Pin` e `Unpin` com `execute/2`, `validate/1`,
   `help/0`, `category/0`, `syntax_definition/0`; registro em
   `Commands.Registry`.
6. Menu de contexto de mensagem: "Fixar"/"Desafixar", visível só para operador
   — escondido, não desabilitado.
7. `WindowRegistry`: janela `pinned`; ilha que carrega no próprio `mount`.
8. Indicador na barra do canal com a contagem, abrindo a janela.

### Testes (escrever primeiro)

- Domínio: fixar duas vezes é idempotente; 51º é recusado; apagar a mensagem
  tira o pin (cascade); `list/2` sob `Page` com `has_more` do banco.
- Policy: regular recusado, half-op conforme a regra escrita, op aceito.
- Command: `/pin` sem argumento, com id inexistente, com id de outro canal.
- LiveView: `pinned_changed` atualiza a contagem na barra; o menu não mostra
  "Fixar" para quem não é operador — ausência revertida uma vez.
- E2E: `make e2e.batch BATCH=channels`.

### Ajuda e i18n

- Tópicos `cmd-pin` e `cmd-unpin` em Commands; tópico da janela em User
  Interface; "See Also" no tópico de moderação e no de tópico do canal.

### Gate

`make ci` + `BATCH=channels`.

---

## 4.4 — Salvar mensagem para depois

### Decisões

- **Não segue o padrão de lista com `position`** (`AGENT-GUIDE` §5) porque a
  pessoa não ordena salvos: eles são cronológicos. Tabela própria, paginada por
  cursor sob `Page`.
- **Vale para canal e para privado**, com o mesmo par de FKs anuláveis e o
  mesmo `CHECK` do item 3.1 — o mesmo desenho, não um segundo.
- **Privado por pessoa.** Ninguém vê o que você salvou.
- Teto de 500.

### Atividades

1. Migration `create_saved_messages`: `owner_nickname` FK, `message_id`,
   `private_message_id`, `note` opcional, `inserted_at`; únicos parciais por
   par; índice `(owner_nickname, id)`.
2. `RetroHexChat.Chat.SavedMessages`: `save/3`, `unsave/2`, `list/2` sob `Page`.
3. Item no menu de contexto de mensagem.
4. `WindowRegistry`: janela `saved`, ilha com os cinco estados de lista.
5. Quando a mensagem original foi apagada, a linha salva mostra que foi apagada
   — não some sem explicação e não mostra o conteúdo.

### Testes (escrever primeiro)

- Domínio: salvar duas vezes é idempotente; 501º recusado; cascade no delete
  da mensagem; `list/2` com `has_more` do banco e cursor no id cru.
- Isolamento: os salvos de A não aparecem para B — ausência revertida uma vez.
- Componente: linha de mensagem apagada renderiza o estado apagado.
- E2E: `make e2e.batch BATCH=messages`.

### Ajuda e i18n

- Tópico em Features + entrada em User Interface para a janela.

---

# Onda 5 — crescer sem publicidade

## 5.1 — Arquivo público indexável

A única fonte de gente nova que não depende de alguém divulgar. Também a queixa
número um contra o Discord: conhecimento que morre lá dentro.

### Estado hoje

- Nenhuma conversa é legível de fora. `JoinLive` é `noindex` e as rotas da
  aplicação herdam `SEO.noindex_content/0`.
- `SitemapController` já tem o padrão inteiro de página pública em escala:
  cache em memória, `etag`, `304`, gzip por `accept-encoding`, e divisão em
  pedaços.
- O pipeline `:landing_live` já serve páginas públicas com o bundle pequeno
  (orçamento de 80 KB) — é onde isso tem de morar.

### Decisões

- **Opt-in por canal, ligado pelo fundador**, em Channel Central.
- **Nada de antes do interruptor é publicado.** `archive_since` marca o
  instante; mensagens anteriores ficam de fora para sempre. Quem escreveu antes
  escreveu sob outra expectativa, e isso é o centro ético do item.
- **Só texto visível.** `plain_content`, sem renderizar formatação de IRC numa
  página pública. Mensagens apagadas ausentes; editadas marcadas como editadas.
- **Anexos não são publicados.** O `AttachmentController` confere sessão e vai
  continuar conferindo; a linha mostra que havia um anexo e nada mais.
- **A página é por dia**, com URL própria — é a unidade que um mecanismo de
  busca consegue indexar e uma pessoa consegue linkar.
- **O arquivo é registrado no loop de locales** (senão `/pt-BR/archive/…`
  responde erro de rota, exatamente como `/join/:slug` já fez), **mas a
  canônica aponta sempre para a URL sem prefixo e não há alternates de
  hreflang**: uma conversa não tem versão traduzida. A exceção é deliberada e
  fica escrita aqui.
- **Um canal pode desligar, e desligar despublica.** Sem "já está na internet,
  fazer o quê".

### Atividades

1. Migration `add_public_archive_to_registered_channels`: `public_archive`
   booleano default `false` e `archive_since`.
2. `RetroHexChat.Chat.Archive`: `days_for/1` (dias com mensagem publicável) e
   `messages_for/2` (um dia, ordem cronológica, `Page`). Filtros no `WHERE`.
3. Rotas `/archive/:channel` e `/archive/:channel/:date` no pipeline
   `:landing_live`, dentro do loop de locales. `archive` entra na lista de
   primeiros segmentos reservados de `AGENT-GUIDE` §16 e é conferido contra
   `config/i18n_locales.exs`.
4. `ArchiveLive`: índice de dias e a página do dia, com canônica sem prefixo,
   `robots` indexável, Open Graph com o nome do canal e o primeiro trecho.
5. Cache: copiar o padrão de `SitemapController` — corpo pré-renderizado,
   `etag`, `304`, gzip. Essas páginas são varridas por robôs.
6. `SitemapController`: um novo pedaço com os dias arquivados.
7. `robots.txt`: liberar `/archive/`.
8. Channel Central: a aba de registro ganha o interruptor, com o texto que
   explica que só vale daqui pra frente.
9. Mensagem de sistema no canal quando o arquivo é ligado ou desligado. Quem
   está na sala tem de saber.

### Testes (escrever primeiro)

- Domínio: `messages_for/2` não devolve nada antes de `archive_since`; ignora
  apagadas, `system`, `service` e `notice`; devolve texto visível e nunca a
  fonte com códigos de cor.
- Desligar despublica: `days_for/1` fica vazio — ausência revertida uma vez.
- Controller/LiveView: canal sem o interruptor responde 404 (não 403, que
  confirmaria a existência do canal); `+s` responde 404 mesmo com o interruptor.
- `get/2`, não `live/2`, para o render morto — é o que um robô recebe.
- Canônica sem prefixo em `/pt-BR/archive/…`; `/pt-BR/archive/…` **responde**.
- `etag` e `304` no segundo pedido.
- `seo_test.exs`: a página do arquivo não carrega `SEO.noindex_content/0`.
- E2E: `make e2e.batch BATCH=public`.

### Ajuda e i18n

- Tópico "Arquivo público do canal" em Channel Settings: quem liga, o que é
  publicado, a partir de quando, e como desligar.
- `make i18n.gettext.merge DOMAINS=dialogs APP=web` e `DOMAINS=help APP=domain`.

### Gate

`make ci` + `BATCH=public`.

---

## 5.2 — Threads

A maior mudança de interface do plano. **Plan mode obrigatório.**

### Estado hoje

- Resposta existe e é de um nível: `reply_to_id`, `reply_to_author`,
  `reply_to_preview` nas duas tabelas, com `Chat.Replies.attrs/2`,
  `Queries.reply_ids/1` e o refresh de citação (`reply_quote_updated`) quando o
  pai é editado ou apagado.
- Não há contagem de respostas, não há lista, não há painel.

### Decisões

- **Thread é uma leitura sobre o que já existe, não uma coluna nova.** A raiz é
  a mensagem sem `reply_to_id`; a thread é o conjunto que aponta para ela.
  Respostas a respostas são aplanadas na raiz — dois níveis já são um fórum, e
  isso é outro produto.
- **A raiz ganha "N respostas"** na linha, abrindo um painel lateral.
- **Uma resposta continua aparecendo no fluxo principal.** Esconder a resposta é
  a escolha do Slack e é a que mata sala pequena.

### Atividades

1. `Chat.Queries.thread_for/2` (`Page`) e `thread_counts_for_many/1` — contagem
   em lote por página, uma query, como as reações.
2. Índice: conferir se `create index(:messages, [:reply_to_id])` basta para a
   contagem agregada; provavelmente um `(reply_to_id, id)`.
3. `StreamItem`: `reply_count` opcional.
4. Painel como ilha, com os cinco estados de lista, compondo `MessageRow` — sem
   markup próprio de mensagem (`AGENT-GUIDE` §9).
5. Enviar do painel já responde à raiz: o `reply_to_id` vem do painel.

### Testes

- Contagem em lote numa query; aplanamento de resposta-de-resposta na raiz;
  `thread_for/2` sob `Page`; apagar a raiz mantém as respostas visíveis com a
  citação limpa (o caminho de `reply_quote_updated` já cobre isso).
- Componente do painel com os cinco estados.
- E2E: `BATCH=messages`.

---

## 5.3 — Eventos agendados

O mecanismo que faz servidor pequeno de nicho voltar toda semana — e aqui tem o
gancho que ninguém mais tem: arcade e espaços.

### Decisões

- **Evento pertence a um canal**, criado por operador.
- **Um evento é um card na conversa e uma linha na janela de eventos.** Nada de
  uma terceira forma de tela (`AGENT-GUIDE` §19).
- **O lembrete usa o que já existe**: notificação de desktop (2.1) e push (2.3).
  Sem canal de aviso próprio.
- **"Vou" é a única interação.** Nada de níveis de resposta.

### Atividades

1. Migration `create_channel_events`: canal, título, descrição, `starts_at`,
   criador, `surface_hint` opcional (id de jogo ou espaço), timestamps; índice
   `(channel_name, starts_at)`.
2. `RetroHexChat.Channels.Events` com `Page`; lista de presença como tabela
   associada.
3. `Jobs.EventReminderWorker` na fila `maintenance`, com a observabilidade que
   `docs/guide/background-jobs.md` exige.
4. Comando `/event` como Handler, mais a janela.
5. Fuso: guardar sempre em UTC e renderizar com `Chat.TimeFormatter` e o
   `timezone` da sessão, que já existe em `ChatLive`.

### Testes

- Domínio com `Page`; evento passado não lembra; presença idempotente;
  worker enfileira uma vez por evento e por pessoa; renderização no fuso da
  sessão (a armadilha clássica).

---

## 5.4 — Avatar no chat

### Estado hoje

- Existe avatar isométrico só dentro do espaço
  (`components/ui/space_character_select.ex`, `space_assets.ex`, as classes
  PixelLab). Nicklist e linhas de mensagem não têm imagem nenhuma.
- Existe `components/ui/primitives/avatar.ex`.

### Decisões

- **O avatar do chat é o mesmo do espaço.** Nada de um segundo sistema de
  imagem, nada de upload de foto: a arte já existe, é nativa 1:1 e é a
  identidade visual do produto.
- **Retrato de 16×16 ao lado do nick**, opcional, desligável nas preferências de
  exibição — a estética mIRC é a estética principal e há quem queira o texto
  puro.
- **Nicklist e hover card também.**

### Atividades

- Ler a escolha de personagem que já é persistida e expô-la em
  `Chat.Roster`/hover card; renderizar via o primitivo de avatar; preferência
  nova sob `user_preferences.display_settings` (JSONB, sem migration —
  `AGENT-GUIDE` §5).

### Testes

- Componente com e sem avatar; preferência desligada não renderiza (ausência
  revertida); pessoa sem personagem escolhido não quebra a linha.

---

## 5.5 — Emoji do servidor

### Decisões

- **Por servidor, não por canal.** Um servidor auto-hospedado é a unidade de
  pertencimento aqui; canal seria granularidade sem dono.
- **Só administrador do servidor adiciona.** Teto de 100.
- **Sintaxe `:nome:`**, resolvida na renderização, nunca gravada como HTML.
- Armazenamento: o mesmo S3 de `Chat.Attachments`, que já tem limite, limpeza
  de órfãos e preview.

### Atividades

- Migration `create_custom_emojis` (nome único, chave no storage, quem
  adicionou); leitura via cache ETS semeada do banco no boot, no padrão de
  `RoleCache`/`BanCache` (`AGENT-GUIDE` §2); `Chat.EmojiData` passa a compor
  catálogo padrão + custom; o `EmojiPicker` ganha a seção; o formatter resolve
  `:nome:`.

### Testes

- Nome inválido recusado; nome duplicado recusado; `:desconhecido:` fica como
  texto literal e **não** vira imagem quebrada; o cache recarrega depois de
  adicionar; renderização escapa o nome (é entrada de administrador, mas é
  entrada).

---

## 5.6 — Mensagem de voz

### Decisões

- **Cai quase inteiro na infra que já existe**: `Chat.Attachments` com S3,
  teto de 25 MB, preview e limpeza de órfãos por Oban.
- **Teto de 60 segundos.**
- **Grava só no mobile e em navegador com permissão** — é onde o formato é
  usado; no desktop, anexar arquivo já resolve.
- **`navigator.mediaDevices` é primitivo proibido dentro de hook** (a lista do
  `enforce_hooks_contract`): a gravação vive num controller em
  `js/lib/uploads/`, e o hook é só a ligação.

### Atividades

- Controller de gravação em `js/lib/uploads/voice_recorder.js`; hook fino;
  o anexo sobe pelo caminho de upload que já existe; a linha renderiza um player
  com duração; o tipo de conteúdo entra na validação de `Attachments`.

### Testes

- Vitest do controller com duplo de `MediaRecorder`: começa, para, respeita o
  teto, libera as faixas no `destroy` (o `destroy` é o espelho exato do
  `mount`); domínio recusa tipo de conteúdo fora da lista; componente renderiza
  o player.

---

# O que este plano deliberadamente não faz

Escrito para não ser reaberto por esquecimento:

- **Entrada como convidado.** Decidido: não existe. Nick válido e registrado é
  requisito de entrada.
- **Caixa de entrada de menções persistida como tabela própria.** O item 3.2
  resolve pela busca, que já existe. Uma tabela exigiria computar menção na
  escrita, carregando as palavras de destaque de todo mundo a cada mensagem. O
  push (2.3) faz esse cálculo, mas com um recorte muito menor.
- **Cache de HTML no service worker.** Shell cacheado com LiveView atrás é
  suporte garantido, e o ganho é zero num produto que já entrega o render morto
  pequeno.
- **Digest por e-mail e "sentimos sua falta".** Só sai e-mail que a pessoa
  pediu.
- **Fixar mensagem em conversa privada.** Sem uso claro; entra depois sem mudar
  o modelo se alguém pedir.
- **Threads de mais de um nível.** Dois níveis são um fórum, e fórum é outro
  produto.
- **Publicar anexos no arquivo público.** O controle de anexo confere sessão e
  continua conferindo.

# Ordem de execução e dependências

```
1.1 ──────────────────────────────────┐
1.2                                   │
1.3                                   │
                                      │
2.1 ──► 2.2 ──► 2.3 ──┐               │
                      │               │
3.1                   │               │
3.2                   │               │
3.3 ──────────► 4.1   │               │
                      │               │
                4.2 ◄─┘ (aviso de expiração fecha ◄──┘ 1.1)
                4.3
                4.4
                5.1  5.2  5.3  5.4  5.5  5.6
```

- 2.3 depende de 2.2 (escopo do service worker).
- 4.1 depende de 3.3 (o marcador de leitura é o primeiro estado que precisa
  sincronizar entre telas).
- 4.2 fecha a pendência que 1.1 deixou aberta (aviso antes de expirar).
- A onda 5 não depende de nada além da 1, e pode começar em paralelo assim que
  houver mão livre — com a exceção de 5.3, que usa 2.1 e 2.3 para os lembretes.

# Registro de fatos medidos no código

O que foi verificado antes de escrever este plano, para que ninguém precise
verificar de novo:

| Fato | Onde |
|---|---|
| Nick e canal expiram em 7 dias, cron de 6 em 6 horas | `services/nick_expiry.ex`, `services/chan_expiry.ex`, `config/config.exs` |
| Só quem está identificado agora e admins são protegidos da purga | `NickExpiry.protected_nicks/1` |
| O catálogo lê só GenServers vivos | `Channels.Directory.all/0` |
| Não existe kind `channel` em share link | `ShareLinks.Schema.Link` `@kinds` |
| `/chat?join=#x` já funciona | `ChatLive.mount_connected_chat/5`, `params["join"]` |
| Zero Notification API, zero service worker, zero manifest | varredura em `assets/js` e `priv/static` |
| Reação em mensagem não existe; reply/edit/delete existem | migration `add_message_interactions` |
| Menção tem cor mas não tem contagem nem lista | `Chat.Highlight`, `Chat.UnreadTracker` |
| `Chat.Search` conta e não lista, por decisão escrita | moduledoc de `chat/search.ex` |
| Uma sessão de chat por nick, por takeover explícito | `ChatLive.mount_connected_chat/5` + `SessionControl` |
| `reconnect_states` tem uma linha por nick | migration `create_reconnect_states` |
| `chat_device_sessions` já aceita várias linhas por nick | migration `create_trusted_devices` |
| `Membership` é mapa por nick, idempotente | `Channels.Membership` |
| `Surfaces` já só abandona canal quando a última tela fecha | `ChatLive.terminate/2` |
| Nenhuma dependência de e-mail no projeto | os três `mix.exs` |
| Indicador de tempo real por conversa é PM-only | `components/ui/chat/typing_indicator.ex` |
| Conferência de canal já é join-based e aparece na sidebar | `Conversations` `group_call_channels` |
