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
| C | o silêncio do `← Chat` (R.10) e a barra coberta (R.7/R.13) | **fechada**, menos dois specs — ver Iteração 3 |
| D | o que vaza (R.3 metade barata, R.4) | **fechada** |
| E | o que apodrece (R.5, A.6, R.8) | **fechada** |
| F | o resto (R.9, R.11, R.12, R.14, R.15) | aberta |

Decisões da §8: pedidas, não respondidas, e **tomadas pela recomendação escrita
no plano** para não parar o trabalho. Todas reversíveis; a que mais vale rever é
a D7.3.

| | Tomada como | Onde ela já vale |
|---|---|---|
| D7.1 | metade barata feita, endereço opaco adiado | fase D |
| D7.2 | ainda em aberto — o spec do answerer segue vermelho | fase C |
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
4. **Um hook registrado não é um hook montado.** `critical_hooks.js` aceita
   qualquer nome; só um `phx-hook=` no template o coloca para rodar, e não há
   nada que reclame de um hook registrado que ninguém monta. Candidato a virar
   uma checagem em vez de um parágrafo — `lint.hooks` já lê os dois lados.
   Destino provável: `AGENT-GUIDE §15`, ou melhor, o próprio linter.
5. **"No silent catch" vale para promises.** Um throw dentro de um `.then` come o
   resto do callback e não aparece em lugar nenhum. Destino provável:
   `.claude/rules/assets-js.md`, que hoje só fala de `try/catch`.
6. **Estado que o JS escreve por cima de markup do servidor precisa de
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
