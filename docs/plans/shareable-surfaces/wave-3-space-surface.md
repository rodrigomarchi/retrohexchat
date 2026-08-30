# Onda 3 — o space em aba própria (`/space/:slug`)

**Depende de:** ondas 0, 1 e 2 (em especial a filiação a canal com contagem de
superfícies, §2.6 da onda 2).

**Entrega:** o renderer isométrico sai do event loop do chat, e um space vira um
lugar com endereço.

**Por que ela vem depois da conferência:** o transporte já está pronto do mesmo
jeito (channel cru + token assinado), então o padrão é idêntico e sai barato
depois que a onda 2 pagou o aprendizado. E o ganho de event loop aqui é o maior
de todos.

---

## 1. O que existe hoje

```
domínio      RetroHexChat.VirtualSpace  (ChannelSpaceServer 1.305 linhas)
sinalização  channel cru "space:#canal" e "space:dm:<key>"   ← já pronto
autorização  VirtualSpace.ChannelJoinToken (assinado)
             + validação de presença no canal no join
host         ChatLive — mas NÃO como janela: como aba da conversa
             chat_live.html.heex:192-250
             assigns: channel_view, space_avatars, space_avatar, space_last_avatar
                      (chat_live.ex:964-967)
             handlers: switch_channel_view, escolha de avatar (chat_live.ex:350-363)
             tokens:   conversation_space/2, channel_space/1, direct_message_space/1
                      (chat_live.ex:1015-1040)
UI           space_character_select, space_virtual_pad, space_fullscreen_toggle
JS           hooks/space/space_canvas_hook.js (lazy)
             chunk app-space_canvas_hook-*  → orçamento 120 KB, o maior do app
             lib/space/{renderer,sprite_atlas,engine}.js  ≈ 2.560 linhas
arte         SpaceAssets.sheet_urls_json(), sheets com cache de um ano
```

O space é o único caso em que a feature **não** é uma janela do desktop: ela
ocupa a região da conversa (`space_view?` esconde a coluna de mensagens). Isso
importa para o modo nested: aninhar aqui significa manter a aba de conversa,
não abrir uma janela.

## 2. O que muda

### 2.1 `RetroHexChatWeb.App.SpaceLive`

Dois pontos de montagem (D2):

* **root** em `/space/:slug` — o slug da onda 1 resolve para
  `{kind: "space", target: %{space_id: …, mode: "channel" | "direct_message"}}`;
* **nested** via `live_render/3` no lugar onde hoje está o bloco
  `chat_live.html.heex:192-250`, preservando a aba de conversa e o
  `data-testid="channel-space-shell"` que os specs já usam.

Migram para o `SpaceLive`: `space_avatars` e `space_avatar`, o handler
`space_select_avatar`, o seletor de personagem, o pad virtual, o toggle de
fullscreen e as funções de token.

Fica no `ChatLive`: a **aba** de space na barra
(`has_space={SpaceReadModel.has_space?(@session)}`) — saber que existe um space
é read-model de conversa, e a régua da onda 2 §2.3 se aplica igual.

**Correção feita ao implementar (2026-08-30):** o plano listava *quatro* assigns
que iam embora, e dois deles ficam:

* **`channel_view` fica.** É qual aba da conversa está na tela — dado que existe
  para quem está *olhando a barra de abas*, não para quem está dentro do space.
  Pela própria régua da onda 2, ele é do chat.
* **`space_last_avatar` fica.** É a memória do último personagem escolhido, e
  ela **sobrevive a cada visita**: o `SpaceLive` é montado de novo toda vez que a
  aba é aberta, então uma memória guardada dentro dele duraria uma visita só. O
  chat é o que sobrevive, então é o chat que lembra — e a promessa do help
  ("o seletor mostra de novo a cada entrada, com a sua última escolha") continua
  verdadeira. O filho avisa o pai por `{:space_surface_avatar, avatar}`.

`space_dom_id/1` não migrou: virou `RetroHexChatWeb.SpaceRef.dom_id/1`, ao lado
da codificação que também vira o slug da rota — porque são a mesma codificação e
escrevê-la duas vezes é como as duas divergem.

### 2.2 A antessala do space já existe: é o seletor de personagem

Desenho: [`ux.md` §2.4](ux.md).

P5: o seletor de personagem **é** a antessala. Ele já existe
(`components/ui/space_character_select.ex`), já é o primeiro estado ao entrar
(`chat_live.ex:353-357`), e ganha uma coisa só: **"lá dentro agora"**, lido de
`VirtualSpace.snapshot/1`.

Sem host e sem `[Iniciar]` (P1): um space não começa nem termina. Quem chega
depois entra igual a quem chegou primeiro (P4) — não existe "já começou" aqui.

Isso é a menor antessala do plano, e é de propósito: adicionar uma sala de espera
antes do seletor seria cerimônia para entrar num lugar que já está aberto.

**O roster não vem do `snapshot/1` direto, e o `ux.md` mudou junto:**

* A leitura virou `VirtualSpace.roster/1`, que responde às duas formas de space
  e responde **também para um space que ninguém abriu ainda** — um space de canal
  guarda quem está no canal, então um space sem processo guarda exatamente quem
  ele guardará quando um processo subir. Ligar um mundo só para perguntar quem
  está nele seria pior que ler a resposta fria.
* O ao vivo veio de um **tópico próprio**, `Topics.space_roster/1`, pelo mesmo
  motivo que a onda 2 criou `channel_calls`: o tópico do space carrega um delta
  de movimento por passo de cada personagem, e quem só desenha uma lista de
  nomes não pode assinar isso. Um publicador (`update_participant_counts/1`,
  o único ponto por onde toda mudança de presença passa), dois assinantes: a
  antessala agora, e o card ao vivo do chat depois.
* **Não existe `[Entrar]` separado.** Escolher o personagem é entrar; o `ux.md`
  §2.4 desenhava um botão a mais e contradizia o próprio P5. O arquivo mudou.

### 2.3 O token muda de emissor, não de forma

`ChannelJoinToken.sign/3` e `sign_direct_message/4` continuam idênticos
(`virtual_space/channel_join_token.ex`). O que muda é quem chama: hoje o
`ChatLive`, depois o `SpaceLive`. `SpaceChannel` não muda uma linha — e o teste
`channels/space_channel_test.exs` é a prova disso.

Nota que vale registrar: hoje o token é assinado com `user_id` **nil**
(`chat_live.ex:1014`), então o space nunca dependeu de registro. Isso é
importante para link compartilhável — é a superfície mais aberta que existe hoje.
Não mexer nisso nesta onda; só notar que a decisão D1 continua sendo o portão.

### 2.4 A filiação a canal, de novo

Space de canal valida presença no canal no join (`channels/space_channel.ex:6`).
Vale exatamente a mesma dependência da onda 2 §2.6: se a aba do chat fechar e a
filiação for embora, o space vira uma aba órfã na próxima reconexão do channel.
Esta onda **consome** o mecanismo da onda 2; não reimplementa.

Space de DM não depende de canal — depende de os dois nicknames serem os
participantes normalizados (`DirectMessageSpace.normalize_participants/1`). Esse
caminho fica mais simples e é o bom primeiro alvo de teste.

### 2.5 Onde o ganho de event loop aparece

O `space_canvas_hook` é o maior chunk do app (120 KB) e roda um render loop
contínuo: tiles isométricos, atlas de sprites, colisão, câmera, relógio de
animação. Hoje ele disputa a main thread com o patch de DOM do stream de
mensagens do LiveView.

A medição da onda 0 §2.4 se repete aqui com o alvo real. **Os dois números,
medidos (Chromium, macOS/Apple Silicon, servidor local):**

| medição | aba própria | mesma aba |
|---|---|---|
| **Onda 0** — maior intervalo entre frames na aba do chat, com a aba satélite bloqueando a thread por 1.200 ms | **12 ms** (`noopener`) | 1.203 ms (`_blank`) |
| **Onda 3** — frames desenhados pelo space em 8 s, sob 100 mensagens de canal chegando | **2.466** | 2.098 |
| **Onda 3** — p50 / p95 / máximo do intervalo entre frames do space | 8 / 9 / **14 ms** | 8 / 10 / **16 ms** |
| **Onda 3** — intervalos acima de 50 ms | 0 | 0 |

**E o segundo número não prova o que o plano supunha.** O isolamento é real —
17,5% mais frames desenhados na aba própria — mas o stream de mensagens do chat,
a ~25 mensagens por segundo, não chega perto de fazer o space engasgar nesta
máquina: nenhum dos dois modos teve um único intervalo acima de 50 ms, e a p50
é idêntica. O ganho de event loop é um **teto**, não um alívio que a pessoa
sente hoje; ele aparece num chat mais pesado ou numa máquina mais lenta.

O que justifica a aba própria, então, é o que a onda 0 mediu (uma aba travada
não trava a outra, e sem `noopener` trava), mais o endereço e a sobrevivência ao
chat reiniciar. Registrado aqui em vez de corrigido porque é a medição que
decide, não a intuição — e a intuição estava otimista.

### 2.6 Fullscreen deixa de ser um truque

`space_fullscreen_toggle` existe hoje porque o space vive espremido dentro de uma
aba dentro de uma janela. Numa aba própria, a página inteira é o space. O toggle
continua existindo para o modo nested; no modo root ele vira redundante e não deve
ser renderizado — ter dois jeitos de ficar em tela cheia numa aba que já é tela
cheia é ruído.

---

## 3. TDD

### 3.1 O que não pode regredir

`apps/retro_hex_chat_web/test/retro_hex_chat_web/channels/space_channel_test.exs`
não muda. Se ele precisar mudar, o transporte foi tocado sem querer — parar e
reavaliar.

Os quatro specs de space já existentes (`space-character-select`,
`space-end-of-time`, `space-fullscreen`, `space-virtual-pad`) precisam continuar
verdes no modo **nested** e ganhar par no modo root.

### 3.2 `:liveview` — `SpaceLive` root

| Asserção |
|---|
| space de DM: participantes normalizados; um terceiro nickname é recusado |
| space de canal: não estar no canal recusa, com a mensagem da política |
| o token emitido verifica por `ChannelJoinToken.verify/2` com o `space_kind` certo |
| o seletor de personagem é o primeiro estado (o avatar começa `nil`, igual hoje — `chat_live.ex:353-357`) |
| escolher um avatar fora de `VirtualSpace.avatars()` não altera o assign |
| `space_dom_id/1` continua produzindo o mesmo id (é contrato com JS e com os specs) |

### 3.3 `:liveview` — a antessala

| Asserção |
|---|
| "lá dentro agora" lista os participantes de `VirtualSpace.snapshot/1` |
| space vazio mostra a lista vazia sem quebrar (é o caso comum fora do horário de pico) |
| não existe `[Iniciar]` nem host |
| `[← ao chat]` presente na antessala e dentro do space |

### 3.4 `:liveview` — `SpaceLive` nested

| Asserção |
|---|
| a aba de space da conversa renderiza o `live_render` e mantém `data-testid="channel-space-shell"` |
| trocar de conversa desmonta e remonta com o token da nova conversa |
| a coluna de mensagens continua escondida (`space_view?`) enquanto o space está em foco |

### 3.5 Vitest

`lib/space/**` já é testável sem LiveView (§15.1). Esta onda não deve precisar de
teste JS novo — se precisar, é sinal de que lógica desceu para o hook, o que o
`make lint.hooks` reprova de qualquer jeito (orçamento de 200 linhas por hook).

### 3.6 Playwright

* `space-surface.spec.ts` — `/space/:slug` direto, seletor de personagem,
  movimento, dois usuários se vendo;
* `space-from-link.spec.ts` — link → connect → space;
* medição de long task na aba do chat com o space rodando ao lado (§2.5).

---

## 4. Obrigações do repositório

- [ ] `PerfBudgets.html_bytes(:space)` / `dom_nodes(:space)`.
- [ ] Help topics: o space ganha endereço e link; "como convidar alguém pro
      space" é acionável.
- [ ] i18n dos textos que migrarem de módulo (o `.pot` muda mesmo quando a
      string não muda — é referência `#:`, e é esperado).
- [ ] `SURFACE.txt` para os datasets `data-space-*` que mudarem de dono.
- [ ] Preload das sheets: a superfície nova precisa do mesmo tratamento de
      `decode()` e cache de um ano que o chat já tem — não redescobrir isso.

## 5. Riscos

* **`space_dom_id/1` é contrato.** Ele é `Base.url_encode64` do id do space e
  aparece em specs e no hook. Mudar a codificação quebra tudo em silêncio.
* **Aba órfã.** Sem o mecanismo da onda 2 §2.6, a aba de space sobrevive à do
  chat e depois falha na primeira reconexão do channel. Não começar esta onda
  antes daquele mecanismo estar verde.
* **Arte não deforma.** A superfície nova renderiza em escala 1:1 nativa, igual
  ao chat. Ajustar tamanho por CSS numa tela nova é a armadilha conhecida:
  regerar no PixelLab, nunca escalar.

## 6. Pronto quando

- `make ci` verde.
- Os quatro specs de space existentes verdes em nested, com par em root.
- `space_channel_test.exs` inalterado.
- Os dois números de long task (onda 0 e esta) escritos aqui.

## 7. O que ficou (2026-08-30)

- `RetroHexChatWeb.App.SpaceLive`, montado nos dois hosts; `/space/:slug` no
  `live_session :app_surface`, com `Live.Surface` cuidando de nickname, ban e fim
  de sessão.
- `RetroHexChatWeb.SpaceRef` — a codificação do id do space, usada tanto pelo
  caminho quanto pelo id do elemento que o hook procura.
- `RetroHexChatWeb.ChatLive.SpaceReadModel` — o que o chat guardou.
- `RetroHexChatWeb.ChatLive.SpaceEvents` — as duas coisas que a superfície diz
  para cima: o personagem lembrado, e o que o canvas diz sobre um apelido.
- `VirtualSpace.roster/1`, `VirtualSpace.space_kind/1`, `Topics.space/1`,
  `Topics.space_roster/1`.
- `kind: "space"` ligado no `JoinLive`, com o mesmo cuidado do canal privado que
  a chamada já tinha.
- Help: `feature-space-tab` e `feature-space-share`.
- `PerfBudgets.html_bytes(:space)` = 12.481 B raw / 2.991 B gzip, 107 elementos.
- E2E: `space-surface.spec.ts` (SP6, SP7, SP8), verde em Chromium **e** Firefox.

**Nenhum `Host` novo.** A onda 2 deixou aberto se o `CallLive.Host` sobe de
namespace ou ganha um irmão; com o código na frente, a resposta é *nenhum dos
dois ainda*. O `Host` existe para os três desvios da chamada — um aviso, uma
janela, e o que o host desenha sobre a chamada — e o space **não tem nenhum
deles**: ele nunca foi uma janela, não emite aviso em runtime, e o chat não
desenha nada sobre um space em que não está. Promover agora seria um módulo
compartilhado com um usuário. A onda 4 decide com três pontos de dado.
