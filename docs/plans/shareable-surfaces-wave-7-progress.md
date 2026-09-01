# Onda 7 — diário

O que aconteceu a cada iteração, **com os erros**. O plano está em
[`shareable-surfaces-wave-7.md`](shareable-surfaces-wave-7.md); as evidências dos
achados estão em [`shareable-surfaces-audit.md`](shareable-surfaces-audit.md).

Este arquivo é para a próxima sessão, não para o histórico. Se uma coisa aqui
virar regra durável, ela sai daqui e vai para um guia **antes** do plano ser
apagado.

---

## Estado

| Fase | O que é | Situação |
|---|---|---|
| A | o render morto para de escrever (R.1) | **fechada** — commit desta iteração |
| B | o read-model para de mentir (R.6) | **fechada** — commit desta iteração |
| C | o silêncio do `← Chat` (R.10) e a barra coberta (R.7/R.13) | **fechada** — os dois specs de pré-join na Iteração 7 |
| D | o que vaza (R.3 metade barata, R.4) | **fechada** |
| E | o que apodrece (R.5, A.6, R.8) | **fechada** |
| F | o resto (R.9, R.11, R.12, R.14, R.15) | **fechada**, menos dois itens — ver Iteração 6 |

A §8 do plano deixou de ser quatro decisões e virou o **questionário de
fechamento**: doze perguntas, `Q1`–`Q12`, cada uma com opções, custo e
recomendação. As antigas `D7.1`–`D7.4` estão lá renumeradas (`Q4`, `Q2`, `Q5`,
`Q6`).

Três delas foram tomadas pela recomendação para não parar o trabalho, e estão
marcadas assim no questionário. Todas reversíveis; a que mais vale confirmar é a
`Q5`, porque a fase E já construiu em cima dela.

| Antiga | Tomada como | Onde ela já vale |
|---|---|---|
| D7.1 | metade barata feita, endereço opaco adiado | fase D |
| D7.2 | **consertada na Iteração 7** — três defeitos empilhados | fase C |
| D7.3 | **link não expira**; a revogação é a saída | fase E |
| D7.4 | barra de abas e zona de status agora; nicklist junto com o card | fase F |

---

## Iteração 1 — Fase A: o render morto para de escrever

### O que se descobriu antes de consertar

A auditoria (R.1) registrou **uma** escrita no `mount/3` sem guarda de
`connected?/1`: a reivindicação da vaga. São **duas**, e a segunda é pior.

`P2PLive.mount/3` → `enter/4` → `Events.attach_session/5` chama
`Lobby.join_session(token, user_id, takeover: true)`. Medido com um `GET` cru,
sem nenhum websocket:

```
BEFORE: connections: %{peer: nil, creator: nil}, peer_joined: false
AFTER : connections: %{peer: %{pid: #PID<0.682.0>, ref: #Reference<...>}}
```

O assento é anexado ao **processo da requisição HTTP**, que já morreu quando a
resposta saiu. Como o join é `takeover: true`, isso é o contrato do `ux.md §2.5`
disparando para quem só **buscou** a URL: a janela que estava com a sessão é
deslocada, e o `:DOWN` do processo morto abre a janela de graça de reconexão
contra ninguém.

### Correção de um achado meu, e ela importa

**R.1 dizia que a vaga queimada "nunca volta". Está errado.** Fui verificar antes
de escrever o conserto de `expires_at` que o plano previa, e o
`Lobby.SessionServer` agenda `:pending_expiry` em 5 minutos no `init`
(`session_server.ex:184`), e `handle_info({:timeout, :pending_expiry}, …)` fecha
a sessão se ela ainda estiver `pending` (`:374`). `claim_open_session/2` chama
`ensure_session_server/1`, então o timer começa junto com a reivindicação.

Ou seja: a linha **não** fica pendurada. O que acontece é `open → pending →
expired` em cinco minutos. A consequência real continua ruim e é outra frase: um
prefetch **mata o link da partida**, porque `open` é o único estado em que ele é
seguível e a máquina só anda para frente. Só não deixa lixo no banco.

Consequência prática: **a §2.3 do plano (pôr `expires_at` na reivindicação) foi
descartada.** Ela consertaria um problema que não existe, e mexeria numa
varredura que hoje está certa. O achado R.1 foi corrigido no arquivo da
auditoria com uma nota, em vez de reescrito — o texto errado fica visível.

Aprendizado, e é o de sempre nesta casa: **eu escrevi "nunca volta" lendo a
query da varredura e não o servidor.** A varredura era a única coisa que eu
tinha olhado, então virou a única coisa que podia me responder. O antídoto foi
procurar quem mais tem uma opinião sobre aquele estado antes de afirmar que
ninguém tem.

### O que mudou

`P2PLive`, três lugares:

* `resolve_session/3` ganhou `seating? = connected?(socket)`, e `take_seat/3`
  só reivindica quando ele é verdadeiro.
* `allowed_in?/3` — a política só é perguntada sobre um assento que existe. No
  primeiro render de uma partida com a vaga ainda vazia, perguntar recusaria
  exatamente a pessoa para quem o endereço foi escrito. **Todas as outras
  recusas continuam alcançando o primeiro paint**, que é o ponto: uma página que
  só diz "você não pode" depois do socket é uma página que mostra a sala antes.
* `enter/4` só anexa a conexão quando conectado.

E um estado novo de tela, `p2p_arriving/1` — o `boot_activity_panel` que o chat
já usa no seu próprio render morto. É a convenção da casa ("dead render só o que
é visível"), e ela vale aqui pelo mesmo motivo.

### O que **não** precisou mudar, e por quê

O plano mandava auditar as quatro superfícies. Feito:

| Superfície | Escreve no render morto? |
|---|---|
| `P2PLive` | **sim, duas vezes** — corrigido |
| `CallLive` | não. `mount_call/3` lê (`active_participant`, `get_summary`) e assina um token; quem entra na sala é o hook do navegador. `ensure_room_server/1` sobe um processo idempotente para uma sala que já existe |
| `SpaceLive` | não. `resolve_space/3`, `subscribe_to_roster/2`, `roster/1` — tudo leitura |
| `PlayLive` | não. `select_from_path/2` é catálogo |

### A armadilha que o plano previu e que era real

`role_of/2` cai em `:peer` por padrão. Se eu tivesse pulado só a reivindicação,
o render morto de um estranho numa partida aberta desenharia a sala como se ele
já fosse o par, e o mount conectado poderia recusá-lo — o primeiro paint
mentindo. Foi por isso que o portão ficou em três lugares e não em um.

### O teste

`test/retro_hex_chat_web/live/app/dead_render_test.exs`, novo. Ele usa `get/2` de
propósito: **`live/2` sempre conecta**, então o mount conectado conserta o que o
morto fez e a classe inteira fica invisível. Foi exatamente por isso que os ~150
testes do plano não pegaram nada disso.

Vermelho antes (3 de 6), verde depois. As três que já passavam antes do conserto
são as que provam o outro lado: abrir pelo socket **continua** tomando o assento,
e a recusa de quem chegou tarde **continua** aparecendo no render morto.

---

## Iteração 2 — Fase B: o read-model para de mentir

`Queries.active_sessions_for_user/1` ganhou `where status != "open"`, com o
porquê no `@doc`: uma linha aberta é não-terminal, tem o id do criador, e é mais
nova que a chamada em que ele já está — porque mintar o link foi a última coisa
que ele fez.

Teste em `open_session_test.exs`, no describe que já existia para `peer_id` nulo
atravessando código que assumia dois participantes. Vermelho antes, verde depois.

### Desvio do plano, deliberado

O plano dizia para **apagar** a cláusula `{"open", _role} -> socket` do
`P2PReadModel.refresh_all/1`, por ser código morto depois da mudança na query.
**Não apaguei.** O modo de falha que ela guarda é silencioso: se a query voltar
a devolver linhas abertas, o chat para de reabrir a sessão que está rodando e
nada levanta, nada loga, e o fallthrough desenha uma janela P2P sem ninguém do
outro lado. Duas travas para um erro invisível é barato; o comentário agora diz
que ela é a segunda e por que a primeira não basta.

---

## Iteração 3 — Fase C: três defeitos empilhados no mesmo clique

A fase C começou como "acrescentar a nota que falta no `← Chat`" e terminou
descobrindo que **a metade de focar a aba existente nunca rodou uma vez**. Três
defeitos independentes estavam empilhados nesse clique, e cada um sozinho já
matava o recurso:

1. **`back_to_chat/1` não renderizava a nota.** O hook a procura por
   `this.el.parentElement`, e o link não tinha pai próprio. Corrigido com um
   `<div class="contents">` — transparente para o layout, real para o DOM.
2. **`SurfacePresenceHook` não estava montado em lugar nenhum.** Ele está
   registrado em `critical_hooks.js` desde a onda 6 e **nenhum template carrega
   `phx-hook="SurfacePresenceHook"`**:

   ```sh
   grep -rn 'phx-hook="SurfacePresence' apps/retro_hex_chat_web/lib   # vazio, antes desta onda
   ```

   Ou seja: ninguém nunca respondeu a um pedido de foco. Todo clique em "ir para
   a aba" esperava 300 ms, não recebia resposta e caía no fallback. O passo 2 do
   contrato da onda 6 §1.1 (*"a aba satélite tenta `window.focus()`"*) não
   existia. Montado agora no chat e nas quatro superfícies, só no render raiz —
   embutida, a superfície está no endereço do chat, que já responde por ele.
3. **`log.info` não existe.** O `log` de `lib/logger.js` é
   `Object.freeze({debug, error, warn})`. O hook fazia:

   ```js
   requestFocus(...).then((answered) => {
     if (answered) return;
     log.info("[surfaces] no tab answered the focus request", { path });  // TypeError
     this._giveUp = true;
     this._note("true");
   });
   ```

   O `TypeError` acontece **dentro de um `.then`**, então vira uma rejeição não
   tratada: as duas linhas seguintes nunca rodam, a nota nunca aparece, e nada
   em lugar nenhum diz por quê. É exatamente a regra "No silent catch" do
   `AGENTS.md` sendo violada por uma promise em vez de um `try/catch`. O mesmo
   `log.info` estava no `onError` do `SurfacePresenceHook`, onde um throw escapa
   do handler e o `postMessage` da resposta abaixo dele nunca sai — então um
   navegador que recusasse `focus()` também deixaria de responder.

E um quarto, achado ao consertar os três: **a nota é estado de servidor que o JS
muta.** `data-visible="false"` vem renderizado do servidor e o hook escreve
`"true"` por cima; qualquer patch do LiveView naquela subárvore restaura o
`false` — e o conjunto de abas abertas muda com frequência suficiente para
causar um. Resolvido com `phx-update="ignore"` + `id` nas duas notas.

### Como isso foi encontrado, porque o método importa

Por eliminação, com o navegador, não por leitura. A sequência que resolveu:
patch no `postMessage` da aba do chat para derrubar a resposta → a aba do chat
logou que derrubou → sonda no DOM da aba da superfície mostrou o elemento certo,
no pai certo, ainda `false` → espião no `BroadcastChannel` da superfície mostrou
o pedido saindo e nenhuma resposta chegando. Nesse ponto só restava o
`.then`, e aí o `log.info` salta aos olhos.

Eu tinha teorizado quatro explicações antes disso e as quatro estavam erradas.
**A sonda custou menos que a terceira teoria.**

### O `default_maximized` não era o que eu escrevi na auditoria

R.7 dizia "a janela maximizada cobre a barra de status" como se fosse um defeito
de geometria. Os atributos das duas janelas são **idênticos** antes e depois do
plano (`git show 3076e54e^:…/chat_live.html.heex | grep -n default_maximized`), e
a barra de status em questão é a do **próprio chat**, no rodapé da janela do
chat — uma janela maximizada por cima dela é como um gerenciador de janelas
funciona.

O que mudou foi o **fluxo**: antes, `/p2p <nick>` abria um diálogo e o pré-join
era um diálogo; agora os dois são a antessala dentro de uma janela fixada e
maximizada, que abre mais cedo. Os dois specs clicavam num controle do chat num
momento em que ele não estava mais alcançável — e a capacidade não sumiu, mudou
de casa (`p2p-room-cancel`, que é o `[Cancelar]` do P7). Os specs foram
apontados para onde o controle está, e o de conferência agora minimiza a janela
antes — que é o único estado em que aquele atalho é o que uma pessoa usaria.

**Não verifiquei** se eles estavam verdes antes do plano: exigiria checkout de
uma revisão pré-plano e rodar, com risco para o banco de e2e, e o conserto é o
mesmo nos dois casos.

### Os dois specs de pré-join que continuam vermelhos

Eles **não** são o que o Apêndice A dizia, e eu repeti o erro dele na R.13:

* `pre-join can enter with microphone and camera disabled` — tirei a sondagem
  morta do `localStorage` (a preferência foi para o servidor no `78ef0529`), e
  ele passou a falhar uma linha adiante: depois de cancelar e reabrir, a caixa
  do microfone volta **marcada**. Ou seja, a preferência não está sendo
  lembrada. Isso é produto, não teste, e é uma investigação própria.
* `pre-join permission denial can retry and still enter receive-only` — a caixa
  de aviso aparece com o botão `Retry` e **texto vazio**. Localizei até
  `_showWarning(message)` receber uma mensagem vazia; não achei a origem e não
  fui adiante.

Os dois precedem o plano. Estão descritos aqui em vez de meio-consertados.

---

## Iteração 4 — Fase D: a regra de privacidade passa a ser uma coisa só

`listed_channel?/1` vivia privado no `JoinLive` e era a segunda implementação de
uma pergunta que o domínio já respondia em outro lugar. Virou
`Channels.Visibility.nameable?/1`, ao lado do `channels_of/2` que responde a
mesma família de pergunta para o `/whois` — com o `@doc` dizendo por que as duas
regras diferem (`+s` basta para quem já está dentro; para um estranho `+p` e
`+i` contam também).

Dois consumidores agora:

* **`SpaceLive.allowed?/2`** parou de nomear o canal na recusa. O `CallLive`
  nunca nomeou, o que já provava que a regra era conhecida — o space era a
  exceção, não o padrão.
* **`JoinLive`** passou a alimentar `page_title` e `page_description` com o
  `subject/1`, que é onde a regra mora. As meta tags eram a superfície para a
  qual a regra foi escrita (`wave-1 §2.5`) e nunca a receberam: até agora todo
  link compartilhado desdobrava como o texto genérico da landing.

O teste é `get/2` e não `live/2`, porque o `<head>` só existe no render morto —
que também é a única coisa que um crawler ou um desdobrador de link busca. Três
casos: o head diz o que foi compartilhado; nunca nomeia canal `+s`; e um link
morto não diz nada sobre o que ele apontava.

**A metade cara de R.3 não foi feita** — o endereço `/space/<base64>` continua
legível. É a decisão **D7.1**, ainda sem resposta.

---

## Iteração 5 — Fase E: um endereço por sala, e uma porta para fechá-lo

Três coisas que se sustentavam mutuamente, e por isso foram juntas.

### `create/1` devolve o link que já existe

Antes, cada clique em Compartilhar mintava um slug novo, todos vivos, nenhum
contável. Isso não era só lixo de tabela: era o que impedia "revogar o link" de
ser uma frase inteira, porque fechar um deixava os irmãos funcionando e ninguém
sabia quantos eram.

A chave é `{kind, target, creator_id}` e a comparação de `target` é igualdade de
jsonb — "a mesma sala" vira pergunta de banco em vez de esperança. Por criador e
não por sala: a linha registra quem fez, e a revogação é perguntada a essa
pessoa.

Efeito colateral que vale mais do que parece: `resolve_count` passa a significar
alguma coisa. Um endereço por pessoa por sala, e o número embaixo dele é quanta
gente seguiu **aquele**.

### `ShareLinks.Policy`, que a onda 1 pediu na §3.1 e nunca existiu

`revoke/2` aceitava qualquer `revoked_by` e fechava o link — o campo de auditoria
estava fazendo o trabalho que uma checagem de autorização devia fazer. Agora:

* **criar** exige apelido registrado, conferido no domínio em vez de confiado ao
  chamador (quatro superfícies chamam; a quinta é que esquece);
* **revogar** é do criador, **e de um operador do canal para onde o link leva**.
  Um operador que pode fechar a conferência mas não o endereço por onde as
  pessoas continuam chegando tem meia ferramenta de moderação.

A regra do operador alcança só os kinds que nomeiam um canal — `call` e `space`
de canal. Uma sessão P2P e um space privado não têm canal de que ser operador.

Uma armadilha no teste, e ela é do repositório inteiro: **a primeira pessoa a
entrar num canal é a fundadora**. O teste de "um membro comum não pode" passava
por engano porque o membro comum era o dono. Todo teste desse describe agora
estaciona um fundador antes.

### O botão que faltava

`ShareLinks.revoke/2` tinha zero chamadores fora de teste desde a onda 1 (A.6).
Agora tem: `Revoke` na `share_bar`, com confirmação, nas quatro superfícies. Mais
o tópico de ajuda `feature-share-revoke` — é controle acionável, logo é
obrigatório.

### E o convite parou de escrever um caminho morto

`/lobby/%{token}` → `/p2p/%{token}`, e o `LobbyRedirectController` passou a
redirecionar para lá em vez de para `/chat`. A justificativa que estava no
`@moduledoc` ("legacy token resolution") era falsa: ninguém lia aquele token.

**As traduções do `msgid` do convite foram portadas, não refeitas** — é a mesma
frase com outro caminho, então as 14 traduções curadas foram trazidas do `HEAD`
anterior com um `replace` de `/lobby/` por `/p2p/`. Refazê-las teria trocado
texto revisado por texto novo sem motivo.

### O que não deu para usar

Nem `argostranslate` nem `polib` existem nesta máquina, então
`make i18n.repair` e `make i18n.glossary` não rodam — é a mesma ausência que
gerou a dívida da A.1 na onda 0. As 13 strings novas foram traduzidas à mão nos
14 locales, e o rótulo `Revoke` veio do `scripts/i18n/glossary.py`, que já o
tinha curado.

**Erro cometido e corrigido no mesmo passo:** ao ler o glossário eu supus que
`GLOSSARY["Revoke"]` fosse uma tupla na ordem de `LOCALE_ORDER` e escrevi os
*códigos de locale* como tradução em 13 arquivos. É um dicionário por locale. Um
`grep` por `msgstr "pt_BR"` mostrou o estrago na hora; o mesmo grep confirmou que
os dois `msgstr "ja"` restantes são holandês legítimo ("yes"). **Ler a estrutura
antes de iterar sobre ela** — o mesmo tipo de suposição que já custou a Iteração 1.

---

## Iteração 6 — Fase F: o resto, e um número que faltava

**R.9 (D7.4, metade de agora).** A entrada `[Group Call]` na tira de abas ganhou
a segunda forma que o `ux.md §2.7` desenhava: com a chamada aberta numa aba desta
pessoa, ela deixa de ser um botão que abre a janela embutida e vira uma âncora
com o `SurfaceTabLinkHook` que vai para a aba que existe. Abrir a janela ao lado
poria a mesma conferência na tela duas vezes, e a pessoa não pediu nenhuma das
duas.

O teste é de componente e não de LiveView, de propósito: é síncrono, e o
`open_surfaces_test.exs` existente resolve a mesma pergunta com
`Process.sleep` em laço (`render_eventually/3`, `render_until_gone/3`) — o que a
regra da casa proíbe e a auditoria não pegou. Não reescrevi aqueles; anotei.

**R.14 (metade).** `PerfBudgets` para `:join`, com o número medido em
2026-09-01: **9.291 B cru / 2.936 B gzip, 99 elementos** — o menor da lista, e o
comentário diz por quê (pipeline da landing, uma janela, um card, nada de
`app.js`). Era a única página pública do plano sem orçamento.

**R.11.** O `@moduledoc` do `Slug` parou de creditar um rate limit que não existe
em rota nenhuma deste app. Agora diz isso em negrito e mostra que a entropia
sozinha carrega o argumento — e que encurtar o slug passaria a exigir o limite
que a frase antiga supunha.

**R.12.** Os 10 `msgid` do plano traduzidos à mão nos 14 locales:
`help_games.po` foi de `empty=8` para **`empty=0`**, e `help.po` de 11 para 9.

**R.15.** A mensagem de rate limit do lobby dizia "minutes" e recebia segundos —
errava por 60×. Virou `dngettext` com `%{count}` em segundos, que também resolve
o plural. E o catch-all de `media_event/3` passou a logar em vez de engolir.

### O que ficou de fora, e por quê

* **A zona de status ainda não diz *onde*** (`ux.md §2.7`, `wave-6 §1.2`). Ela é
  derivada de `@group_call`/`@p2p_session`, que só existem quando a superfície
  está embutida — com a chamada em outra aba o chat não tem nada para desenhar.
  Fazer isso direito é sintetizar um estado "em outra aba" a partir do
  read-model mais `@open_surface_paths`, e é trabalho de verdade, não uma linha.
* **A nicklist** marcando quem está na chamada: é a **D7.4**, adiada de propósito
  para ir junto com o card ao vivo, que lê o mesmo summary.
* **O spec "abrir a mesma chamada duas vezes não gera dois participantes"**
  (R.14, onda 6 §1.3). A tira de abas agora *impede* o segundo clique, mas a
  garantia de domínio continua sem spec.

### Os 9 `msgid` que continuam vazios não são desta onda

`help.po` mantém 9 vazios por locale, e `chat.po` 3: capacidade de saudação dos
bots, RSS, cards de link, lista de usuários, miniaturas. São de outras features,
e a atribuição da auditoria (A.1/R.12) já dizia isso. `make i18n.catalog.check`
continua reprovando por causa deles — não por causa do plano.

---

## Iteração 7 — Q2 + Q3: os três vermelhos, no navegador

Método imposto pelo handover e ele estava certo: **nada aqui foi diagnosticado
por leitura.** Cada um dos três tinha uma causa que a leitura do código não
sugeria, e dois deles tinham causas empilhadas. As sondas custaram menos que a
primeira teoria em todos os casos.

### `chat-group-call.spec.ts:1340` — o aviso de permissão em branco

A auditoria dizia "`_showWarning(message)` recebe string vazia, sem causa raiz".
**Estava errado.** A sonda: espião em `DOMTokenList.prototype.add/remove/toggle`
filtrado pelo elemento do aviso, mais um `MutationObserver` de `class` com
`attributeOldValue` na subárvore inteira.

```
t=1334  remove("hidden") de _showWarning  → classe fica "… flex", texto = "Permission denied. Retry after allowing access or join receive-only."
t=1340  class ← "mt-1 hidden items-start …"   (não passou por classList)   texto ← ""
```

Seis milissegundos depois de o hook escrever, o LiveView repinta a seção e o
template volta por cima — por `setAttribute("class", …)`, que é morphdom, não
`classList`. É o aprendizado 7 desta onda com nome e hora: **estado que o JS
escreve por cima de markup do servidor precisa de `phx-update="ignore"`**. O
"texto vazio" que a auditoria viu era a mesma corrida vista meio milissegundo
antes.

Consertado nas três regiões que o controlador do pré-join escreve — o aviso, a
sobreposição de preview vazio e a linha de estado dos dispositivos — e nas três
cópias equivalentes da antessala P2P (`starting_room.ex`), que têm o mesmo
defeito e o mesmo dono.

### `chat-group-call.spec.ts:1273` — a preferência que não é lembrada

Três camadas, e as duas primeiras eu não teria achado lendo:

1. A sonda mostrou que o servidor **recebe** a preferência (o atributo
   `checked` renderizado some depois de desmarcar) e que o `Cancelar`
   **desmonta o LiveView filho** — `data-phx-root-id` some da lista. O assign
   `group_call_prejoin_preferences` morre com ele.
2. Salvar no `cancel` não resolveu. A causa: `TrustedDevices.put_device_preference`
   exige `active_device_nick`, e no banco de e2e `trusted_device_nicks` tem
   **zero linhas** com 32 `trusted_devices`. Ou seja **nem o caminho do
   `[Entrar]` jamais persistiu** — e não é um artefato do teste: o connect tem
   `remember_device: false` por padrão, então a lembrança nunca existiu para o
   usuário comum. A afirmação do spec ("a preferência foi para o registro de
   dispositivo confiável") era a terceira teoria errada desta onda.

   ```sh
   PGPASSWORD=postgres psql -h localhost -p 5433 -U postgres -d retro_hex_chat_e2e \
     -c "select count(*) from trusted_device_nicks;"   # 0
   ```
3. Conserto: a escolha passa a viver no **hospedeiro**, que é o que continua de
   pé quando a antessala fecha. `SurfaceHost.remember/2` é a quarta coisa que
   difere entre os dois mounts; o chat guarda e devolve pelo `session` do
   `live_render`; o registro de dispositivo confiável continua sendo a camada
   durável para quem tem um.

### `chat-call-fault-injection.spec.ts:355` — o answerer que recarrega

**Três defeitos independentes, um atrás do outro.** Cada um sozinho matava o
recurso, e cada um só apareceu depois que o anterior foi consertado. A sonda foi
um grampo de `WebSocket` (`send` + `addEventListener("message")`) instalado por
`addInitScript` para sobreviver ao reload, um espião em `RTCPeerConnection` e um
`Logger` temporário no portão de sinalização.

1. **`resume_started/2` olhava para o status `"connected"` do banco.** Uma sessão
   fica em `lobby` do momento em que os dois chegam até a mídia subir, então
   quem recarrega no meio da primeira oferta voltava para a **antessala**, com
   `room_ready: false` — a âncora do WebRTC nem era renderizada
   (`PROBE state[bob]: anchorId: null`). O hook nunca montava, o
   `lobby_webrtc_ready` nunca saía, o portão nunca reabria. Agora a pergunta é
   do domínio: `Lobby.signaling_released?/1`, ligada na primeira vez que o
   portão abre e nunca desligada.
2. **`signaling_restart_required?/1` olhava para o mesmo status**, e o teste do
   replay era "está vazio". Com o portão reabrindo, o log mostrou
   `payload=%{}` — sem `restart`. Duas razões: o status era `lobby`, e o replay
   **não estava vazio**, porque quem ficou continua gotejando candidatos ICE
   dentro dele depois que o disconnect o zerou. Candidato solto não reconstrói
   nada: o teste passou a ser "o replay tem uma negociação" (descrição ou
   pedido de renegociação).
3. **A metade do servidor do protocolo de prontidão não existia para o
   `LobbyWebRTCHook`** (`AGENT-GUIDE` §15 manda o servidor reenviar o estado
   inicial no `*_ready`). A página que volta empurra `lobby_start_answer`
   durante o mount, enquanto o hook preguiçoso ainda está sendo importado — e o
   evento se perde. Como o servidor já registrou `webrtc_started: true`, ele
   nunca reenvia; o `lobby_restart` que vem depois chega a uma conexão sem
   `role` nem `iceServers` e sai por `restart_unavailable`, sem criar
   `RTCPeerConnection` nenhuma (`PCLOG` vazio a corrida inteira).

E um quarto, que só apareceu depois dos três: com o start reenviado, a página
recém-montada passou a receber **também** o `lobby_restart`, e derrubava a
conexão que acabara de construir — três `RTCPeerConnection` em sequência e uma
resposta para uma oferta que já não existia. Uma página que começou como
reconstrução é o **motivo** do restart, não o alvo dele; e uma que ainda não
começou precisa do start, não do restart. As duas metades dessa frase são a
guarda.

`webrtc_connection_reset` carrega "esta página começa como reconstrução" desde o
`resume_into/2`, e o `enter_connected` a aposenta — a partir daí esta é a página
que fica, e o próximo restart é sobre ela.

### O que ficou medido

* Isolado: 3/3 verde. Arquivo inteiro: 5/5 verde. As cinco suítes de chamada
  juntas (`chat-p2p`, `chat-p2p-negotiation`, `game-open-lobby`,
  `chat-group-call`, `chat-call-fault-injection`): **44 passam, 0 falham**.
* A progressão serviu de "reverter para ver ficar vermelho", ao contrário: cada
  conserto moveu a falha um passo adiante, e o passo estava na sonda antes de
  estar no código.

### Armadilha nova, cara

**O spec passava isolado e falhava no arquivo.** Rodar só `:355` deu verde três
vezes seguidas enquanto o arquivo inteiro falhava — porque a corrida entre o
mount da página e o import do hook preguiçoso depende do que o navegador já tem
em cache. Um spec de recuperação só vale rodado no arquivo dele.

**E a instrumentação move a corrida.** Ligar `LOG_LEVEL=debug` fez a falha
sumir. O que resolveu foi grampear o navegador (que não muda o tempo do
servidor) e subir o log do portão para `warning`, que o nível padrão já mostra.

---

## Iteração 8 — Q9 + Q10: o spec que faltava e os laços de sleep

### K7, e a coisa que ele prova não é a que o nome diz

O spec pedido pela onda 6 §1.3 é "abrir a mesma chamada duas vezes não gera
dois participantes". Escrito, ele mostrou onde o defeito **realmente** ficaria:
a segunda aba não entra pela porta — ela reidrata no assento que a pessoa já
tem, por `GroupCall.active_participant/2`. O `join` do `RoomServer` só reusa um
participante **desconectado**, então quebrá-lo não muda nada nesse caminho:

```sh
# quebrar join_authorized_participant  → K7 continua verde   (caminho errado)
# quebrar GroupCall.active_participant → K7 vermelho          (caminho certo)
```

O vermelho não é "dois participantes": é a segunda aba caindo **na antessala**,
que é o estado a um clique de `Entrar na chamada` do segundo assento. O spec
afirma nessa altura, que é mais cedo e mais honesta.

Duas coisas que a escrita corrigiu:

* **A barra do badge fica debaixo da janela maximizada** — a mesma R.7 da
  Iteração 3. Minimizar antes não é o teste sendo cuidadoso; é o único estado em
  que aquele controle é alcançável.
* **`data-surface-open` não significa "estou na sala"**, significa "já tenho
  *esse endereço* aberto". Eu afirmei `true` para quem está na conferência pelo
  chat e o atributo era `false` — corretamente. A forma do link acompanha o
  conjunto de abas abertas, não o assento.

### Os laços de `Process.sleep` viraram espera por mensagem

Os três (`render_eventually`, `render_until_gone`, `assert_eventually`) saíram.
O que os substitui não é um `sleep` menor: o teste **assina o mesmo tópico** que
a tela sob teste e espera a mensagem que interessa.

O que torna isso síncrono e não outra corrida: o registro publica para os dois
assinantes na mesma passagem, antes de qualquer coisa que o teste possa enviar
depois. Quando o `assert_receive` do teste volta, a cópia da tela já está na
caixa dela — e o `render/1` seguinte é um `call`, que processa a caixa antes de
responder.

**Erro no caminho:** a primeira versão contava anúncios (`await_change()` duas
vezes). Registrar uma superfície publica **duas** vezes — uma pelo processo,
outra pelo endereço — e o chat da própria página também publica as suas, então
a contagem ficou defasada em um e o `refute` final passou a ver o caminho ainda
presente. Esperar pelo **conteúdo** (`await_open/1`, `await_gone/1`) é imune a
quantas publicações existem.

E quatro assertivas nem precisavam esperar: `live/2` só volta depois do
`handle_params`, e registrar é um `call` síncrono para o registro a partir de
lá. Elas viraram assertivas diretas.

---

## Iteração 9 — Q6: a zona de status dizendo onde

A Iteração 6 deixou isto de fora com a razão certa: tudo o que o chat desenha
sobre uma chamada vem do assign da superfície embutida, e com a chamada em
outra aba esse assign não existe. O conserto é **derivar**, não assinar mais um
estado: as duas metades já estavam na tela.

`GroupCallReadModel.elsewhere/3` cruza os summaries (que sabem o token da sala)
com `@open_surface_paths` (que sabe quais endereços estão abertos) e devolve o
canal cuja chamada está numa aba desta pessoa. A zona ganha uma terceira forma:
âncora com o `SurfaceTabLinkHook` para o endereço, **sem o botão de sair** —
sair de uma chamada se faz na tela que está nela.

### Duas coisas que quase deram errado

* **`@socket` dentro de um template não carrega assigns.** A primeira versão era
  `elsewhere(@socket, @open_surface_paths)` e teria respondido "nada aberto"
  para sempre, em silêncio. É a mesma armadilha que o `@moduledoc` do
  `Live.OpenSurfaces` já documenta — e eu caí nela mesmo assim. A função passou
  a receber as peças (`canais, summaries, abertos`), o que também a deixou pura
  e testável sem socket.
* **Duas chamadas em duas abas são uma zona de uma linha.** Qual das duas ela
  nomeia não pode depender da ordem de um mapa; segue a ordem dos canais da
  sessão, como o `live_summaries/1` ao lado, e há um teste que troca a ordem
  para provar.

### O que ficou de fora, dito

**A zona de P2P não ganhou a terceira forma.** Quando a sessão vai para outra
aba, a página embutida não some — ela fica `displaced: true` e desenha o próprio
aviso com a oferta de retomar. O snapshot que o chat recebe (`host_snapshot/1`)
não carrega `displaced`, então a zona mostra o último estado conhecido. É um
defeito de mesma família e **não foi consertado aqui**: o caso da conferência
era o silêncio total, este é uma frase desatualizada ao lado de uma tela que já
diz a verdade.

### Verificado no navegador

`K8` em `surface-cross-tab.spec.ts`: Bob abre a chamada, Alice **nunca** abre a
janela embutida, segue o link da aba, e a barra de status do chat dela passa a
dizer o canal e "in another tab" — sem ela tocar no chat, porque a informação
vem do registro. Fecha a aba, a zona some. E o componente vai vermelho se a
terceira forma for removida (revertido uma vez para ver).

---

## Aprendizados que podem sair daqui

Candidatos a virar regra durável quando a onda fechar. **Ainda não movidos.**

1. **Um `mount/3` de superfície não escreve no domínio.** Ele roda duas vezes e a
   primeira é uma requisição HTTP comum, então toda escrita ali pertence a
   qualquer coisa que apenas *busque* o endereço. Destino provável:
   `guide/surfaces.md` §19, ao lado de "toda superfície carrega seu dado inicial
   no próprio mount" — que é a regra **de leitura** que esta é o par de.
2. **`live/2` esconde essa classe inteira**, porque sempre conecta. Um teste de
   `get/2` é o único que a vê. Destino provável: `guide/testing.md`.
3. **Uma recusa tem que sobreviver ao render morto**, mas uma recusa que depende
   de um assento ainda não tomado não pode. As duas metades juntas são o desenho
   do portão. Destino provável: `guide/surfaces.md`.
4. **Um teste de componente bate um teste de LiveView com `sleep`.** O
   `open_surfaces_test.exs` prova a mesma coisa com dois laços de
   `Process.sleep` — a regra da casa diz para asserir estado síncrono, e um
   `render_component` é exatamente isso. Candidato a reescrita, não feito aqui.
5. **Um hook registrado não é um hook montado.** `critical_hooks.js` aceita
   qualquer nome; só um `phx-hook=` no template o coloca para rodar, e não há
   nada que reclame de um hook registrado que ninguém monta. Candidato a virar
   uma checagem em vez de um parágrafo — `lint.hooks` já lê os dois lados.
   Destino provável: `AGENT-GUIDE §15`, ou melhor, o próprio linter.
6. **"No silent catch" vale para promises.** Um throw dentro de um `.then` come o
   resto do callback e não aparece em lugar nenhum. Destino provável:
   `.claude/rules/assets-js.md`, que hoje só fala de `try/catch`.
7. **Estado que o JS escreve por cima de markup do servidor precisa de
   `phx-update="ignore"`**, ou o próximo patch o apaga. Destino provável:
   `AGENT-GUIDE §15.1`.

---

## Armadilhas para a próxima sessão

* **Três specs continuam vermelhos e cada um é uma coisa diferente**: os dois de
  pré-join (produto, descritos na Iteração 3) e o do answerer que recarrega
  (**D7.2**, esperando decisão). Nenhum deles é regressão desta onda.
* **`RetroHexChat.GroupCall.RuntimeTest` "join_call/5 reconnects a briefly
  disconnected participant" falhou uma vez em `make ci` e passou sozinho e na
  execução seguinte** (`rejoined.participant.id == payload.participant.id`,
  9690 contra 9689). Não é desta onda — nada aqui toca `GroupCall` — mas é um
  teste sensível a ordem/semente e vale saber antes de culpar a sua mudança.
* **A fase E mexe em `ShareLinks.create/1`**, que quatro superfícies chamam.
  Reusar o link vivo muda o que "compartilhar" significa — ver o risco no plano.
* **O `msgid` do convite (fase E) muda em 13 locales** — `extract` e `merge` no
  mesmo commit, senão o `make ci` de outra pessoa quebra.
* **`make i18n.catalog.check` já reprova no `HEAD`** e não é culpa desta onda
  (R.12). Não confunda com regressão sua; `make ci` tem um estágio diferente e
  mais frouxo, "i18n Catalog Coverage", que passa.
