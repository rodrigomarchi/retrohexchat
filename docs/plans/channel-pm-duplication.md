# Canal e PM são a mesma coisa escrita duas vezes

> **STATUS: EM ANDAMENTO.** O passo 1a e metade do passo 2 shiparam; o §7 marca o
> que foi feito e o que não foi, com o motivo. O resto da ordem de ataque é
> proposta, não decisão travada. Apagar quando a unificação tiver shipado, movendo
> a regra durável (§9) para o `AGENT-GUIDE.md` antes.

Uma mensagem de canal e uma mensagem privada são o mesmo conceito — alguém escreveu
um texto, num formato, numa conversa, e outras pessoas leem. O código as trata como
duas entidades independentes, do schema Ecto até o componente que desenha a linha.
O resultado previsível é que toda funcionalidade precisa ser escrita duas vezes, e
quando alguém escreve só uma, ninguém percebe.

## 1. Como ver com os próprios olhos

Os dois schemas são o mesmo arquivo com dois campos renomeados. Normalize os nomes
pela posição e compare:

```sh
diff \
  <(sed 's/channel_name/FIELD_1/; s/author_nickname/FIELD_2/' \
      apps/retro_hex_chat/lib/retro_hex_chat/chat/message.ex) \
  <(sed 's/sender_nickname/FIELD_1/; s/recipient_nickname/FIELD_2/' \
      apps/retro_hex_chat/lib/retro_hex_chat/chat/private_message.ex)
```

O que sobra do diff é o nome do módulo, o moduledoc, a lista de `@type_values`, o nome
da tabela (e os `check_constraint` derivados dele), o limite de tamanho do primeiro
campo, e o nome da variável nos changesets. **A estrutura não difere em nada**: os
mesmos campos de conteúdo, os mesmos quatro changesets com os mesmos passos, o mesmo
`has_many :attachments`, os mesmos `timestamps`.

Repare de passagem que nem a ordem dos campos corresponde: na primeira posição um
schema tem **onde** a mensagem foi escrita e o outro tem **quem** a escreveu. Não é
uma abstração que divergiu; é uma cópia que envelheceu.

## 2. A confissão do próprio código — resolvida

```elixir
:ok <- Policy.can_edit?(Map.put(pm, :author_nickname, pm.sender_nickname), nickname),
```

O domínio **traduzia o PM para o formato de canal** para conseguir reusar a política
de edição. Eram **três** ocorrências, não uma: `can_edit?` e `can_delete?` no
`Service`, e uma terceira na camada web, onde `editable_message?/3` tinha uma
cláusula que despachava por `active_pm` só para renomear o campo antes de chamar
uma regra de domínio.

Quando é preciso renomear um campo para reaproveitar uma regra, a regra já sabe que
as duas coisas são uma só. `Chat.Authorship.author/1` passou a ser esse lugar:
`Policy` pergunta quem escreveu em vez de ler um nome de campo, os três `Map.put`
sumiram e a camada web deixou de decidir tipo de conversa para poder validar.

O que a `Policy` lia de uma mensagem eram quatro campos, e **só um** diferia.

## 3. Onde o fork se propaga

| Onde | Canal | PM |
|---|---|---|
| Schema | `Chat.Message` | `Chat.PrivateMessage` |
| `chat/queries.ex` | `list_messages` | `list_private_messages` |
| `chat/service.ex` | `send_message` | `send_private_message` |
| `chat/service.ex` | `edit_message` | `edit_private_message` |
| `chat/service.ex` | `delete_message` | `delete_private_message` |
| `pubsub_handlers/messages.ex` | `do_handle_new_message` | `do_handle_new_pm` |
| `pubsub_handlers/messages.ex` | `apply_new_message` | `apply_new_pm` |
| `helpers/messages.ex` | `visible_channel_message?` | `visible_private_message?` |
| `helpers/{channel,pm}.ex` | `load_channel_messages_with_pagination` | `load_pm_messages_with_pagination` |
| camada web, ver abaixo | `message_to_stream_item` | `pm_to_stream_item` |

O construtor de item de stream é o caso mais claro, e mostra que o fork já se forkou:
**os dois lados existem duplicados dentro da própria camada web.**

```sh
grep -rn "message_to_stream_item\|pm_to_stream_item" apps/retro_hex_chat_web/lib | grep def
```

A versão de canal vive em `core_events.ex` e em `helpers/channel.ex`; a de PM, em
`pubsub_handlers/messages.ex` e em `helpers/pm.ex`. O helper `pm_field/2` acompanha as
duas cópias de PM. Nenhuma delas sabe das outras — mudar o formato da linha exige
achar todas.

Os pares de `Service` não são só nomes parecidos — são `with` chains com os mesmos
passos na mesma ordem, diferindo em qual query chamam, qual tópico avisam, e no
`Map.put` do §2.

## 4. O que isso custou até agora

### 4.1 Preview de link em PM — corrigido em `e617ac6f`

Um link colado numa conversa privada não ganhava card e nem entrava no URL Catcher.
Eram **três** causas independentes, todas do mesmo formato "o canal tem, o PM não":

- o remetente nunca entrava no tópico da própria conversa, então nada que o broadcast
  dirige rodava para ele — em canal isso não acontece porque o `/join` assina antes de
  qualquer mensagem;
- o destinatário assina o tópico **por causa da** primeira mensagem, que portanto não
  podia chegar por ele — canal não tem esse problema pela mesma razão;
- `Phoenix.PubSub.subscribe/2` não é idempotente e a função chamada `ensure_pm_subscription`
  só chamava `subscribe`. Quem entrava na mesma conversa várias vezes rodava a captura
  de URL, o flood tracker e o duplicate tracker uma vez por visita, a cada mensagem
  recebida. Nada mostrava isso: o stream é chaveado por id e apenas redesenhava a
  linha que já existia.

O texto de ajuda afirmava que o URL Catcher captura links "em canais e PMs". Não
capturava. A documentação descrevia a intenção; o código tinha metade dela.

### 4.2 Palavras de destaque em PM — era esquecimento, e foi corrigido

`SessionHelpers.maybe_highlight/2` era chamada apenas do caminho de canal. A função
não tem nada de específico de canal — recebe conteúdo, formato, nick, palavras e
autor — e funcionava sem alteração num payload de PM.

A ambiguidade que este parágrafo registrava ("decisão de produto ou esquecimento?")
tinha resposta no próprio código, e o caminho da evidência é o que importa guardar:

- `message_row.ex` lê `Map.get(@msg, :highlighted)` sem saber se a linha é canal ou
  PM, e o `message_viewport.ex` renderiza **um único stream** para os dois tipos de
  conversa;
- `pm_to_stream_item/1` já normalizava `sender_nickname` para a chave `author` —
  exatamente a chave que `maybe_highlight/2` lê;
- não existia, em lugar nenhum, um ramo que recusasse highlight em PM.

Renderizador agnóstico, payload já compatível e nenhuma regra que recuse não é uma
decisão de produto: é a mesma assinatura do §4.1, uma capacidade inteira menos uma
chamada no caminho de PM. Medida com precisão, a assimetria eram três chamadas
(`maybe_highlight`, `maybe_play_highlight_sound`, `maybe_push_highlight_tip`).

Fechado no passo 1a. A lição para o §9: quando a pergunta é "isso é intencional?",
ela quase sempre se responde procurando o ramo que implementaria a intenção — e
descobrindo que ele não existe.

### 4.4 Mensagem do sistema em PM era filtrada como spam — corrigido

Encontrada **procurando**, não por acidente: comparando chamada a chamada
`do_handle_new_message` com `do_handle_new_pm`.

O caminho de canal isenta `:system` das duas metades da proteção contra
repetição — não conta a linha e não a descarta:

```elixir
defp check_channel_duplicate(socket, %{type: :system}), do: socket
if payload.type != :system and DuplicateTracker.duplicate?(...)
```

O caminho de PM não isentava nada. Com o limiar padrão (**3 mensagens idênticas
em 10 segundos**), três linhas `p2p_system` iguais do mesmo par — "P2P session
connected", que reaparece a cada reconexão de um link instável — perdiam a
terceira, em silêncio. Exatamente a que dizia que a conexão voltou.

A isenção agora existe uma vez (`MessageHelpers.from_system?/1`) e os dois
caminhos perguntam. `p2p_system` é o tipo de sistema de uma conversa privada
segundo o comentário do próprio schema; uma mensagem de canal não pode
carregá-lo, então a mesma pergunta serve para os dois.

### 4.5 Highlight em PM não marcava a conversa na barra lateral — corrigido

Mesma varredura, segunda assimetria. Eram **quatro** pontas, não uma:

- `apply_background_message` chama `maybe_add_highlight_channel`, que põe o canal
  em `highlight_channels`. O caminho de PM não tem equivalente, e nada em lugar
  nenhum põe uma chave `pm:<nick>` nesse conjunto.
- `channel_item` recebe `highlight={member?(@highlight_channels, ch) or ...}`;
  `pm_item` **não tem o atributo `highlight`**.
- `activity_channels/1` inclui um canal por estar em `highlight_channels`;
  `activity_pms/1` não considerava isso.
- abrir um canal limpava `highlight_channels`; abrir uma conversa privada
  limpava `unread_counts` e `flash_channels` e **não** o highlight — de modo que
  a quarta ponta teria deixado a marca grudada mesmo depois de lida.

Consequência: uma palavra de destaque numa conversa privada em segundo plano
tocava o som e disparava a dica (§4.2 fechou isso), mas **não deixava marca na
barra lateral**. Quem não estava ouvindo não ficava sabendo.

A barra lateral já lia um conjunto só para os dois tipos de conversa —
`highlight_channels`. Só o lado do canal escrevia nele. O `pm_item` inclusive já
passava `status_bar_classes(@active, false, @unread)`, com o `false` literal no
lugar do highlight.

### 4.6 Edição e remoção vazavam entre conversas privadas — corrigido

Terceira assimetria da varredura, e a única que mostrava conteúdo de uma
conversa dentro de outra.

`message_edited` e `message_deleted` usam **o mesmo nome de evento** para os dois
tipos de conversa, então um handler só recebe as duas formas. Ele perguntava:

```elixir
Map.has_key?(payload, :channel) -> payload.channel == session.active_channel
Map.has_key?(payload, :sender)  -> session.active_pm != nil
```

O canal comparava com **o canal certo**. A conversa privada só verificava se
*alguma* estava aberta. E o construtor da linha buscava o PM por id sem checar
participantes — ao contrário do `stream_item_for_reply_quote`, ali do lado, que
sempre checou.

Alcançável: `pm_subscriptions` acumula um tópico por aba aberta e só solta ao
fechar a aba. Com as conversas com Alice e Bob abertas e a de Alice na tela,
Bob editar uma mensagem punha a linha dele **dentro da conversa da Alice**.

A pergunta virou nomeável — `MessageHelpers.in_active_conversation?/2` — e os
dois construtores passam por ela. Uma conversa privada é um **par**, e é por isso
que a checagem toma a mensagem e não o payload: o payload nomeia um participante
só. A duplicação entre os dois construtores sumiu junto.

### 4.3 O custo corrente

Toda feature que toca mensagem custa dois caminhos, dois testes e uma chance de
esquecer o segundo. Quem esquece não recebe nenhum sinal: compila, os testes do
caminho implementado passam, e o buraco só aparece quando um usuário reclama —
que foi exatamente como o preview em PM apareceu.

## 5. Por que acontece

A raiz é o §1: duas tabelas, dois schemas, nenhum tipo comum. Sem um tipo que diga
"isto é uma mensagem numa conversa", cada camada acima precisa perguntar *qual dos
dois* está manipulando, e a resposta vira um `if` — ou, mais frequentemente, uma
segunda função.

## 6. O que genuinamente difere (para não simplificar demais)

Nem tudo é cópia, e um merge ingênuo quebraria coisas reais:

- **A chave de roteamento.** Um canal é um nome; uma conversa privada é um **par não
  ordenado** de nicks — daí `PM.pm_topic/2` ordenar antes de juntar.
- **A visibilidade.** Canal é N participantes com histórico compartilhado; PM é dois,
  e as políticas de editar/apagar partem de premissas diferentes.
- **Os tipos.** `service`, `error` e `notice` só fazem sentido em canal; `p2p_invite`
  e `p2p_system` só fazem sentido em PM.
- **O ciclo de vida.** Em canal existe um momento explícito de entrar (`/join`) antes
  de qualquer mensagem. Numa conversa privada, a conversa **é criada pela primeira
  mensagem** — foi essa diferença que produziu 4.1.

Uma abstração que ignore isso vai vazar. A que serve precisa tratar a conversa como
um valor de primeira classe (chave, tipo, participantes) em vez de fingir que canal e
PM são intercambiáveis.

## 7. Ordem de ataque proposta

Do maior retorno por risco para o menor.

**Passo 1 — unificar a camada web.** Partido em dois na execução, porque juntos
viravam um diff em que ninguém enxerga o que mudou de comportamento.

**1a — o construtor de item de stream. FEITO.** As quatro cópias viraram
`ChatLive.StreamItem`, com `from_message/1` e `from_private_message/1` sobre um corpo
só. Fechou 4.2 e duas divergências que as cópias já carregavam: um PM ao vivo não
levava `plain_content` (o texto que vai para a área de transferência), e o fallback
de anexos devolvia `nil` no caminho de PM contra `[]` no de canal.

**1b — o pipeline de handlers.** Ainda em aberto: `do_handle_new_*` e `apply_new_*`
continuam gêmeos. Sobrou uma assimetria que 1a expôs sem resolver — o payload de
canal já chega no formato de linha, montado pelo `Service.broadcast_message/2`,
enquanto o de PM só vira linha na camada web. É isso que 1b tem de igualar.
*Risco:* baixo. Nenhuma migração, nenhuma mudança de dados.

**Passo 2 — um tipo de conversa no domínio.** Feito pela metade, de propósito.

**Feito:** as regras de conteúdo e a leitura do autor. `Chat.MessageRules` guarda o
que os dois schemas obedecem igual — conteúdo em branco, `plain_content` derivado e
nunca aceito do chamador, formato válido, campos de resposta exigidos — e cada
schema declara só o que o faz diferente: as colunas de endereçamento e os tipos que
pode carregar. `Chat.Authorship` resolveu o §2. O maior clone do repositório caiu de
416 para 193 nós, e o que sobra é o bloco `schema`, que Ecto exige declarado.

**Não feito, e por quê:** os gêmeos de `Service` e `Queries` (`send_*`, `edit_*`,
`delete_*`, `do_insert_*`, os previews de resposta, os três pares de broadcast).
Todos precisam da **chave da conversa** — um nome de canal contra um par não
ordenado — que o §6 lista como diferença genuína e cuja decisão está amarrada ao
passo 3. Unificá-los antes seria escolher a chave por acidente.
*Risco do que falta:* médio, e depende do passo 3.

**Passo 3 — entregar PM na caixa de entrada que já existe.** `new_pm` vai para
`user:<nick>` em vez de `pm:<par>`. Cada pessoa tem um tópico estável que sempre
assina, como já acontece com admin, bots, lobby, NickServ e o próprio `pm_activity`.
*Isso apaga* a máquina de assinatura idempotente e o caso especial da primeira
mensagem introduzidos em 4.1 — o desenho certo é **menos** código que o remendo atual.
*Risco:* médio-alto, e o motivo de não ser o passo 1: muda a entrega de todo PM, e
`pm:<par>` também carrega typing, stop_typing, edit e delete, que precisam ser
decididos junto.

**Passo 4 — tabela única.** Provavelmente **não**. Só se 1–3 mostrarem que a dor
continua. É migração de duas tabelas grandes com paginação por cursor em cima delas,
e o §6 mostra que a chave de roteamento difere de verdade.

## 8. Perguntas em aberto

- ~~Highlight em PM é decisão de produto ou esquecimento?~~ **Respondida no §4.2:
  esquecimento.** O código não tinha nenhum ramo que implementasse a suposta decisão.
- O passo 3 deve mover typing/edit/delete junto, ou o tópico do par continua existindo
  para esses?
- ~~Existem outras assimetrias além de 4.1 e 4.2?~~ **Respondida: existem, e
  procurar funciona.** Uma varredura comparando chamada a chamada
  `do_handle_new_message` com `do_handle_new_pm` — e depois o que cada lado faz
  com o resultado — achou duas: §4.4 e §4.5. A segunda passada, sobre `Service`
  e os handlers compartilhados, achou o §4.6. **Três defeitos, nenhum deles
  reclamado por ninguém em meses de uso.**

  O método, para as camadas ainda não varridas (`Queries`,
  `helpers/{channel,pm}.ex`, `core_events.ex`): listar as funções chamadas
  dentro de cada gêmeo, diferenciar os conjuntos, e para cada chamada que só
  existe de um lado perguntar se há um ramo que a recuse do outro. Quando não
  há, é esquecimento — o mesmo raciocínio do §4.2.

  Duas variações que renderam:

  - **`Service` estava simétrico.** Resultado negativo também é resultado: os
    três pares (`send`, `edit`, `delete`) têm os mesmos passos na mesma ordem, e
    os payloads de broadcast carregam os mesmos campos. Não procure ali de novo.
  - **Onde os dois tipos compartilham um handler, olhe a função que decide de
    qual conversa a coisa veio.** Foi assim que o §4.6 apareceu: não era um
    caminho faltando, era o mesmo caminho respondendo diferente para cada forma.

## 9. A regra durável que sai daqui

*(mover para `AGENT-GUIDE.md` quando este plano for apagado)*

**Não forke um conceito por contexto.** Quando duas superfícies manipulam a mesma
coisa — uma mensagem, um anexo, uma reação — o contexto é um **parâmetro**, não uma
segunda implementação. Duas implementações não divergem com aviso: elas divergem
quando alguém implementa uma funcionalidade em uma delas, e o único sinal é um
usuário reclamando meses depois.

O cheiro que denuncia é o adaptador: se para reusar uma regra é preciso renomear um
campo de A para o formato de B, A e B são o mesmo tipo com dois nomes.
