# Onda 2 — conferência em aba própria (`/call/:token`)

**Depende de:** ondas 0 e 1.

**Entrega:** a conferência sai da janela do chat e vira uma superfície própria,
com link, com pré-join na própria página, e sobrevivendo ao chat inteiro
reiniciar.

**Por que ela é a primeira feature real:** a sinalização dela já não passa pelo
`ChatLive`. `GroupCallChannel` é um Phoenix Channel cru autorizado por token
assinado (`channels/group_call_channel.ex:22`). Uma página nova precisa do
token e de nada mais. Nenhum transporte muda nesta onda — só o host.

---

## 1. O que existe hoje

```
domínio      RetroHexChat.GroupCall   (RoomServer 2.541, PeerServer 687 linhas)
sinalização  channel cru "group_call:<room_token>"  ← já pronto
autorização  GroupCall.JoinToken (assinado) + GroupCall.Policy
host         ChatLive
             live/chat_live/group_call_events.ex        2.603 linhas
             live/app/group_call_stats.ex                 271 linhas
             janela "group-call"  chat_live.html.heex:584
             pré-join             chat_live.html.heex:1186
UI           components/ui/group_call/**  (12 módulos, já compartilháveis)
JS           hooks/group_call/group_call_webrtc_hook.js (lazy, chunk 85 KB)
             lib/group_call/conference_connection.js     2.037 linhas
```

Os 12 módulos de `components/ui/group_call/**` são componentes de função sem
estado. Eles não mudam nesta onda — é justamente por isso que D2 funciona.

## 2. O que muda

### 2.1 `RetroHexChatWeb.App.CallLive`

Um LiveView, dois pontos de montagem (D2):

* **root** em `/call/:token` — `token` é o `group_call_rooms.token`, resolvido
  pelo `/join/:slug` da onda 1 ou colado direto;
* **nested** via `live_render/3` no slot da janela `group-call` do chat, para
  mobile (D5) e para quem escolhe não sair da aba.

O `mount/3` faz, na ordem:

1. `Live.Surface` (onda 0) — nickname, ban, tópico de superfícies;
2. `GroupCall.get_room/1` — inexistente ou terminal → card de "acabou";
3. `Membership` do canal + `GroupCall.Policy.can_join?/4` — negado → o motivo,
   na linguagem da política, não uma tela genérica;
4. `JoinToken.sign/4` e assign — o hook entra no channel com ele;
5. estado de pré-join **no próprio mount**, nunca por `send_update` pós-mount.
   Essa classe de bug é invisível para o ExUnit e só o E2E pega
   ([`guide/windowed-desktop.md` §7.1](../../guide/windowed-desktop.md)).

### 2.2 A antessala: o pré-join promovido a tela, com roster

Desenho: [`ux.md` §2.3](ux.md).

`/call/:token` tem dois estados: **antessala** e **dentro**. A antessala é uma
*sala de chegada* (P1): sem host, sem `[Iniciar]` — cada um clica `[Entrar]`
quando quiser. Isso preserva o comportamento de hoje, em que qualquer membro do
canal abre uma chamada e qualquer um entra na hora.

Ela é, quase inteira, coisa que já existe:

| Parte | De onde vem |
|---|---|
| preview de câmera, selects de dispositivo, toggles de entrada | `components/ui/group_call/pre_join_dialog.ex` — promovido de diálogo do chat a tela |
| **"Já estão dentro"** | `GroupCall.get_summary/1` — **novo na tela**, não novo no domínio |
| chrome (menu, status, título) | `desktop_window/1` slots `:menu` e `:status` |

Efeito no chat: `group_call_pre_join_dialog` sai do `chat_live.html.heex:1186`.
O `GroupCallPreJoinHook` continua existindo e continua lazy — muda de página, não
de forma. (`P2PSetupHook` aponta para o mesmo módulo hoje
(`lazy_feature_hooks.js`); ele fica onde está até a onda 4.)

**Quem chega depois que a chamada já rolou** (P4) não vê "espere": vê a mesma
antessala, com o roster cheio, e entra. Não existe estado "já começou" para uma
chamada de canal.

**A preferência de dispositivo é da pessoa, não da tela.** O
`@prejoin_preference_namespace` (`group_call_events.ex:31`) migra de chave, não é
recriado — senão todo mundo perde a escolha de câmera no dia do deploy.

### 2.3 O que sai do `ChatLive` e o que fica

**Sai** (vai para `CallLive`): tudo que é *estar dentro* da chamada —
`@group_call`, estado de mídia, layout, foco, reações, screen share,
`App.GroupCallStats`, `GroupCallConfirmDialog`, e o corpo de
`group_call_events.ex`.

**Fica** no `ChatLive`: tudo que é *saber que existe uma chamada* —
`@group_call_channels`, `@group_call_channel_summaries`,
`GroupCallEvents.rehydrate/1` reduzido a esses read-models, o
`group_call_channel_entry` na barra de abas (`chat_live.html.heex:321`) e o
badge na sidebar de conversas. Isso é read-model de canal e pertence ao chat.

A régua para decidir caso a caso: **se o dado só existe enquanto você está na
chamada, ele vai; se ele existe para quem está só olhando o canal, ele fica.**

Estimativa: `group_call_events.ex` deve ficar em algumas centenas de linhas no
`ChatLive` e o resto migrar. Não perseguir o número — perseguir a régua.

### 2.4 Ciclo de vida: fechar a aba não é sair da chamada

Regra já documentada e que esta onda **não pode** quebrar
([`guide/webrtc-p2p.md` §8.5](../../guide/webrtc-p2p.md)):

* `destroyed()` do hook e `terminate/2` do LiveView = saída inesperada →
  `disconnect_call/4`, status `disconnected`, janela de reconexão preservada;
* só o botão explícito (com confirmação) é terminal.

Numa aba própria isso fica mais visível, não menos: fechar a aba do navegador é o
caso comum agora. O teste de fault injection existente
(`e2e/tests/chat-call-fault-injection.spec.ts`) é a rede de segurança e precisa
ser portado para a superfície nova, não só mantido.

### 2.5 O chat, do lado de fora

* O `group_call_channel_entry` ganha dois caminhos: **abrir em aba**
  (`<a target="_blank" rel="noopener">` — sem JS, e `noopener` pelo motivo da
  onda 0 §2.4) e **abrir aqui** (janela com o `live_render` nested).
* Quando já existe uma aba aberta para aquela sala, o botão deve **focar** a aba
  em vez de abrir a segunda. Isso é coordenação entre abas e é onda 6; até lá,
  abrir duas abas da mesma sala precisa ser *correto* (a segunda vira
  `rejoin` com `previous_participant_id`, caminho que já existe) mesmo que
  ainda não seja *bonito*.
* A janela `group-call` do desktop continua existindo — ela só passa a hospedar
  o `live_render`.

### 2.6 A filiação a canal precisa sobreviver à aba do chat

Esta é a descoberta que muda o tamanho da onda, e ela não aparece em nenhum
diagrama — só no `terminate/2`.

`ChatLive.terminate/2` chama `ChatLive.Helpers.cleanup_channels/2`
(`live/app/chat_live.ex:303`): **fechar a aba do chat sai de todos os canais.**
E a conferência depende de filiação a canal em três lugares:

* `GroupCall.Policy.can_join?/4` → `check_member/2` (`group_call/policy.ex:35`)
* `can_kick_participant?/3` e `can_moderate_media?/3`, que delegam para
  `Channels.Policy.can_kick?/3` (`group_call/policy.ex:58-68`)
* o space, na onda 3, que valida presença no canal no join do channel

Consequência hoje, se nada for feito: você entra na chamada, fecha a aba do
chat, e vira alguém que está numa sala de um canal do qual não é mais membro. A
chamada continua (o `RoomServer` é dono do participante), mas um `rejoin` depois
de um reload é **negado**, e a moderação sobre você fica indefinida. É um bug
silencioso e intermitente — a pior forma.

**A solução: filiação com contagem de superfícies.** Um registro por nickname das
superfícies abertas (o mesmo registro que a onda 6 vai usar para decidir entre
"abrir" e "focar"):

1. `Live.Surface` (onda 0) registra a superfície no mount e a remove no
   `terminate`, monitorada — um LiveView que morre de crash decrementa igual.
2. `cleanup_channels/2` só efetiva a saída dos canais quando **a última**
   superfície daquele nickname fecha. O `ChatLive` deixa de ser o dono
   exclusivo do tempo de vida da filiação.
3. Sair do canal explicitamente (`/part`, botão) continua sendo imediato e
   terminal, independente de superfície aberta — isso é um ato, não um efeito
   colateral.

Alternativas rejeitadas: (a) congelar a autorização no momento do join — a
moderação passa a divergir em silêncio, que é o modo de falha do Princípio XII;
(b) exigir a aba do chat aberta — mata o valor do link compartilhado, que é o
motivo do plano.

**Isto é infraestrutura, não conveniência.** A onda 3 depende dela e a onda 6 a
reusa. Se ela escorregar, escorrega o plano inteiro — por isso ela está aqui, na
primeira onda que a exige, e não escondida numa onda de "polimento".

### 2.7 Bundle: nada muda ainda (D4)

`/call/:token` carrega `app.js`. O chunk do SFU já é lazy (85 KB de orçamento) e
continua sendo. A onda 6 mede e decide. Se esta onda criar uma entry, ela cria um
orçamento sem número medido — que é exatamente o que
`assets/scripts/bundle_budget.cjs:57-60` diz para não fazer.

---

## 3. TDD

### 3.1 O que já existe e não pode regredir

`apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/group_call_channel_test.exs`
e `.../live/chat_live/group_call_flow_test.exs` cobrem hoje o join por token e o
fluxo pelo chat. O primeiro **não muda** (o transporte não mudou). O segundo é o
que se divide.

### 3.2 `:liveview` — `CallLive` root

| Asserção | Por quê |
|---|---|
| sala inexistente / terminal → card de encerrada | é o caso mais comum de link antigo |
| não registrado → mensagem da `Policy`, não tela genérica | a razão é o produto |
| não membro do canal → mensagem da `Policy` | idem |
| sala trancada + não moderador → `"Group call is locked"` | `group_call/policy.ex:118` |
| autorizado → assign com `JoinToken` verificável por `JoinToken.verify/2` | o token é a porta; ele é teste |
| **pré-join renderiza no primeiro render** (não depois) | a classe de bug de §2.1.5 |
| `terminate/2` inesperado chama `disconnect_call`, não a saída terminal | §2.4 |

### 3.3 `:liveview` — a antessala

| Asserção | Por quê |
|---|---|
| a antessala é o primeiro render, e lista quem já está dentro | é o dado novo da tela |
| o roster muda quando o summary muda, sem recarregar | o card e a antessala leem a mesma fonte |
| **não existe `[Iniciar]` nem host** numa chamada de canal | P1 — não regredir o modelo atual |
| `[Entrar]` com a chamada já em andamento funciona igual | P4 |
| a preferência de dispositivo salva na antessala é lida no próximo mount | migração de chave, não recriação |
| `[← ao chat]` está presente nos dois estados (antessala e dentro) | P2 — é a única saída para conversa |

### 3.4 `:liveview` — `CallLive` nested

O **mesmo** módulo montado dentro do chat, por `live_render/3`:

| Asserção |
|---|
| a janela `group-call` renderiza o painel (mesmo `data-testid` do modo root) |
| `pushEvent` do hook chega no LiveView aninhado, não no `ChatLive` |
| fechar a janela **não** desmonta o hook (regra de janela sempre montada) |
| o summary de taskbar/aba continua chegando no host |

Este par root/nested é o teste que garante D2. Se as duas montagens divergirem,
o fork voltou.

### 3.5 `:liveview` — o que sobrou no `ChatLive`

| Asserção |
|---|
| entrar num canal com chamada ativa marca `@group_call_channels` |
| a chamada fechar limpa o badge |
| `rehydrate/1` reconstrói os read-models depois de reconexão, com sessão identificada |
| o `ChatLive` **não** tem mais assign de mídia/layout/foco |

### 3.6 `:unit` / `:integration` — filiação com contagem de superfícies

| Asserção | Por quê |
|---|---|
| abrir chat + chamada = 2 superfícies; fechar a chamada mantém a filiação | o caso comum |
| fechar o chat com a chamada aberta **mantém** a filiação | é o bug de §2.6 |
| fechar a última superfície efetiva a saída dos canais | senão vaza membro fantasma |
| um LiveView que morre de crash decrementa (monitor, não `terminate`) | `terminate` não roda em todo caminho de morte |
| `/part` explícito sai na hora, mesmo com outra superfície aberta | ato ≠ efeito colateral |
| depois de fechar o chat, `rejoin` na chamada continua autorizado | é a asserção que fecha o buraco |

A última linha é o teste que prova a onda. Escrever primeiro; ele deve falhar
antes do mecanismo existir.

### 3.7 Playwright

Portar e dividir `e2e/tests/chat-group-call.spec.ts`:

* `call-surface.spec.ts` — duas abas de dois contextos entram em `/call/:token`,
  RTP real bidirecional, screen share, saída explícita;
* `call-surface-lifecycle.spec.ts` — **fechar a aba** não encerra a sala para o
  outro; reabrir reentra por `rejoin`;
* `call-from-link.spec.ts` — o fluxo da onda 1 até dentro da chamada;
* `chat-call-fault-injection.spec.ts` — portado para a superfície nova
  (`POST /api/e2e/group-call-peer/terminate` continua compilado só sob
  `e2e_fault_injection?`).

O cenário que mais regride continua sendo **vídeo bidirecional com
`track.muted === false` dos dois lados** ([`guide/webrtc-p2p.md` §8.3](../../guide/webrtc-p2p.md)).
Rodar depois de qualquer mexida em mídia.

E o lembrete que já custou tempo aqui: a suíte é **Chromium apenas**. Um defeito
de sinalização específico do Firefox — como o `candidate: ""` de fim de
candidatos — é invisível para o `make ci`
([`guide/webrtc-p2p.md` §8.6](../../guide/webrtc-p2p.md)). Ao mover o host,
reproduzir uma vez com um spec descartável em Firefox antes de fechar a onda.

---

## 4. Obrigações do repositório

- [ ] `PerfBudgets.html_bytes(:call)` / `dom_nodes(:call)`.
- [ ] `SURFACE.txt`: dezenas de eventos `group_call_*` mudam de LiveView de
      destino. `scripts/surface_snapshot.sh --check` vai reprovar até o snapshot
      subir — e é bom que reprove.
- [ ] Help topics: "P2P & Calls" já é um grupo (`help_topics.ex:59`). Entram:
      abrir chamada em aba, compartilhar link, o que acontece ao fechar a aba.
- [ ] i18n: `group_call` é um domínio gettext próprio; extract + merge nele.
- [ ] `e2e/TEST_CATALOG.md` regenerado.
- [ ] `docs/reference/conferencia-canal-permissoes.md` — checar se a política
      descrita ali continua verdadeira depois da mudança de host (deve continuar:
      a `Policy` não muda).

## 5. Riscos

* **`rehydrate` some sem ninguém notar.** Hoje ele reconstrói `@group_call` depois
  de reconexão, e ele exige sessão identificada. Ao migrar, o caminho de
  "canal restaurado depois do mount" (§8.5) precisa continuar coberto — é uma
  ordem de chamadas, não uma função.
* **Duas abas na mesma sala.** Legítimo hoje via `rejoin`, mas a segunda aba
  precisa não derrubar a primeira por acidente. Teste explícito.
* **O pré-join mudando de lugar mexe em preferências persistidas**
  (`@prejoin_preference_namespace`, `group_call_events.ex:31`). A preferência é
  da pessoa, não da tela: migrar a chave, não recriá-la, senão todo mundo perde a
  escolha de dispositivo no dia do deploy.
* **Identificação é um assign do `ChatLive`, não um fato do domínio.** O portão
  da conferência é `session.identified` (`group_call_events.ex:751`), que vive no
  processo do chat. Uma aba de chamada não tem como lê-lo: `chat_pre_identified`
  está no cookie, mas só para quem já chegou identificado. Três caminhos, a
  decidir aqui com o código na frente — token curto assinado pelo chat (padrão
  `JoinToken`, coerente com D3), identificação virando fato de domínio, ou
  tratar "segurar o nick registrado" como prova. Descoberto na iteração 2
  ([`PROGRESS.md`](PROGRESS.md)); **não decidir sem medir o que quebra**.
* **Filiação fantasma.** O contador da §2.6 erra para mais se um caminho de
  morte não decrementar — e o resultado é um membro que nunca sai do canal.
  Monitor, não `terminate`, e um teste de crash.
* **Migração de 2.603 linhas em um commit.** Fazer em duas etapas: primeiro
  `CallLive` nested renderizando dentro do chat (nada muda para o usuário, tudo
  muda por baixo), depois a rota root. A primeira etapa é reversível; a segunda é
  aditiva.

## 5.1 O que já shippou (2026-08-28)

Tudo desta onda menos a §2.6. Commits `7dc8245a` (normalizadores), `0b665bb2`
(read-model separado) e `5bb4091e` (`CallLive` nos dois hosts, `/call/:token`, a
antessala com roster, o Share e o card público de chamada).

Três coisas que o plano supôs e o código desmentiu, corrigidas aqui:

* **A identificação já era fato de domínio.** `Services.NickServ.identified?/1`
  mantém o conjunto em runtime e `session.identified` é espelho dele. Nenhum
  token novo; o risco da §5 está resolvido.
* **As duas etapas viraram uma.** O plano mandava montar aninhado primeiro e
  depois a rota, para que a primeira etapa fosse reversível. O que tornou a
  primeira etapa possível foi promover o pré-join a antessala, e isso já muda o
  chat — separar as duas teria movido o pré-join duas vezes.
* **O ciclo de vida das transmissões mudou de tópico.** A antessala precisa do
  roster ao vivo, e as transmissões de chamada saíam no tópico da conversa.
  Agora saem em `Topics.channel_calls/1`.

**Falta:** §2.6, a filiação com contagem de superfícies. Ela ainda não é um bug
porque a chamada embutida morre com o chat; passa a ser no momento em que alguém
fechar a aba do chat com `/call/:token` aberta.

## 6. Pronto quando

- `make ci` verde.
- `CallLive` passa a mesma bateria montado root e nested.
- Vídeo bidirecional real verde no Playwright, e uma passada manual em Firefox.
- Fechar a aba da chamada não encerra a sala para o outro participante.
- Fechar a aba do chat com a chamada aberta não tira você do canal.
- `ChatLive` não tem mais assign de estado interno de chamada.
