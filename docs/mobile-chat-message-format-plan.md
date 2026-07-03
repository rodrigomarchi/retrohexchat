# Plano: formato mobile das mensagens do chat

Status: proposta para revisao. Nenhuma implementacao feita ainda.

## Objetivo

Trocar a leitura atual estilo IRC por um formato mais amigavel para mobile:

- remover a dependencia visual de uma coluna fixa grande para nick;
- remover os marcadores IRC como `<nick>` no fluxo principal;
- manter o timestamp completo o suficiente para contexto, mas como metadado secundario;
- reduzir a fonte do timestamp e deixar nick/origem acima dele;
- aumentar um pouco a fonte do texto da mensagem;
- preservar os seletores usados por hooks JS e testes.

## Pontos de codigo mapeados

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/chat/chat_message.ex`
  - Define o envelope visual de cada linha.
  - Hoje usa `grid-cols-[auto_10ch_1fr] md:grid-cols-[auto_18ch_1fr]`.
  - Hoje renderiza nick normal como `<nick>`.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/message_row.ex`
  - Escolhe o corpo visual para `:message`, `:action`, `:system`, `:service`, `:error`, `:notice`, `:inline_help`, `:arcade_link`, `:p2p_invite`.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_helpers.ex`
  - Formata timestamps.
  - Hoje coloca colchetes no proprio texto: `[DD/MM HH:MM]`.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/message_viewport.ex`
  - Stream principal de mensagens.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/status_viewport.ex`
  - Stream da aba Status; tambem usa `chat_message/1`.
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/message.ex`
  - Tipos persistidos em canal: `message`, `action`, `system`, `service`, `error`, `notice`.
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/private_message.ex`
  - Tipos persistidos em PM: `message`, `action`, `system`, `p2p_invite`.

## Contratos que precisam ser preservados

- `.chat-nick[data-nick]`
  - Usado para clique em nick, hover card, PM por duplo clique e menu de contexto.
- `.chat-content`
  - Usado por busca/highlight e contexto de mensagem.
- `.chat-action`
  - Usado por busca/highlight para mensagens de acao.
- `data-testid="chat-message-timestamp"`
  - Usado em testes E2E.
- `data-message-id`, `data-author`, `data-msg-status`, `data-system-message`
  - Usados por interacoes, retry, edicao, scroll e menus.

## Layout atual

Modelo atual, simplificado:

```text
[timestamp]      [nick fixo 10ch mobile / 18ch desktop] [texto]
[01/01 12:00]                         <alice> mensagem normal
```

Problemas no mobile:

- o timestamp com colchetes ocupa espaco horizontal;
- o nick tem uma coluna fixa grande;
- `<nick>` adiciona caracteres pouco uteis em tela pequena;
- o texto fica comprimido na terceira coluna;
- todos os tipos de mensagem herdam a mesma estrutura, mesmo quando nao ha nick.

## Layout mobile proposto

Modelo base:

```text
+-------------+--------------------------------+
|       alice | mensagem principal com fonte   |
| 01/01 12:00 | um pouco maior e quebra livre  |
+-------------+--------------------------------+
```

Regras visuais propostas:

- coluna lateral compacta para metadados;
- primeira linha da coluna lateral: nick real ou origem da mensagem;
- segunda linha da coluna lateral: timestamp menor, cinza;
- conteudo da coluna lateral alinhado a direita, para ficar mais perto do texto;
- texto principal a direita;
- nick/origem em fonte menor que o texto, com peso visual;
- timestamp em fonte menor que nick/origem;
- texto da mensagem em fonte maior que hoje;
- usar `leading-snug` ou equivalente para compactar altura sem apertar leitura;
- manter `break-words` no corpo para URLs e palavras longas.
- nicks tem limite de 16 caracteres no backend; a coluna deve truncar com ellipsis quando necessario.

Exemplo de markup alvo, conceitual:

```html
<div class="chat-message-row grid grid-cols-[5.8rem_1fr] gap-x-2 items-start py-0.5">
  <span class="chat-message-meta min-w-0 leading-tight text-right">
    <span class="chat-nick block max-w-full truncate text-[11px] font-bold" data-nick="alice">
      alice
    </span>
    <time class="chat-timestamp block text-[10px] text-gray-500 whitespace-nowrap">
      01/01 12:00
    </time>
  </span>

  <span class="chat-content text-[15px] leading-snug break-words">
    mensagem aqui
  </span>
</div>
```

## Timestamp

Opcao recomendada:

```text
01/01 12:00
```

Motivo:

- preserva dia e hora;
- cabe em coluna compacta abaixo do nick/origem;
- remove colchetes;
- evita ocupar largura demais no mobile.

Timestamp completo pode ficar em `title` e/ou `aria-label`:

```text
01/01/2024 12:00:00
```

Decisao aberta:

- usar `DD/MM HH:MM` visivel e datetime completo no hover/acessibilidade;
- ou usar `DD/MM/YYYY HH:MM` visivel, aceitando uma coluna lateral maior.

## Mapa por tipo: stream principal

### `:message` / `:normal`

Atual:

```text
[01/01 12:00]                         <alice> hello world
```

Proposto:

```text
      alice  hello world
01/01 12:00
```

Notas:

- nick continua interativo com `.chat-nick[data-nick]`;
- remover `< >`;
- texto ganha prioridade visual.
- nick fica alinhado a direita dentro da coluna meta.

### `:action`

Atual:

```text
[01/01 12:00]                                 * alice waves
```

Proposto:

```text
      alice  * waves
01/01 12:00
```

Notas:

- passar o autor para a coluna meta;
- evitar repetir `alice` no corpo;
- manter classe `.chat-action` no texto.

### `:system`

Atual:

```text
[01/01 12:00]                                 * alice joined #lobby
```

Proposto:

```text
     System  * alice joined #lobby
01/01 12:00
```

Notas:

- usar origem `System` no lugar da coluna vazia;
- manter visual mais discreto/italico.

### `:service`

Atual:

```text
[01/01 12:00]                                 ChanServ has set mode +o alice
```

Proposto:

```text
    Service  ChanServ has set mode +o alice
01/01 12:00
```

Alternativa quando houver autor claro:

```text
   ChanServ  has set mode +o alice
01/01 12:00
```

Decisao aberta:

- manter origem generica `Service`;
- ou exibir `ChanServ` / `NickServ` como origem quando o autor estiver disponivel.

### `:error`

Atual:

```text
[01/01 12:00]                                 Cannot send to channel: you are banned
```

Proposto:

```text
      Error  Cannot send to channel: you are banned
01/01 12:00
```

Notas:

- origem `Error` ajuda scan visual;
- manter cor/weight de erro no texto ou na origem.

### `:notice`

Atual:

```text
[01/01 12:00]                         srv     notice text
```

Proposto:

```text
        srv  notice text
01/01 12:00
```

Notas:

- se `srv` for um nick real, manter `data-nick`;
- se for origem de sistema, pode virar apenas origem nao-interativa.

### `:inline_help`

Atual:

```text
[01/01 12:00]                                 [inline help card]
```

Proposto:

```text
       Help  [inline help card]
01/01 12:00
```

Notas:

- manter card no corpo;
- reduzir a competicao visual do timestamp.

### `:arcade_link`

Atual:

```text
[01/01 12:00]                                 [arcade session link]
```

Proposto:

```text
     Arcade  [arcade session link]
01/01 12:00
```

Notas:

- `MessageRow` ja tem branch dedicada;
- manter o componente de link no corpo.

### `:p2p_invite`

Atual:

```text
[01/01 12:00]                         <alice> [p2p invite card]
```

Proposto:

```text
      alice  [p2p invite card]
01/01 12:00
```

Notas:

- nick continua interativo;
- card fica com mais largura no mobile.
- este card deve evoluir para o modelo rico de sessao descrito abaixo.

### `:announcement`

Atual:

```text
[01/01 12:00]                         <Server> maintenance in 5 minutes
```

Observacao:

- `:announcement` existe no stream principal, mas hoje cai no fallback de mensagem normal.

Proposto:

```text
     Server  maintenance in 5 minutes
01/01 12:00
```

Notas:

- adicionar branch visual propria em `MessageRow`;
- tratar `Server` como origem de sistema/importante, nao como nick normal;
- evitar `data-nick` para `Server`, a menos que exista uma razao funcional.

## Modificadores de mensagem

### `deleted_at`

Atual:

```text
[01/01 12:00]                                 [deleted placeholder]
```

Proposto:

```text
    Deleted  [deleted placeholder]
01/01 12:00
```

Notas:

- origem pode ser `Deleted` ou manter o autor original se disponivel;
- revisar com cuidado para nao sugerir interacao com conteudo removido.

### `edited_at`

Atual:

```text
[01/01 12:00]                         <alice> edited message [edited]
```

Proposto:

```text
      alice  edited message [edited]
01/01 12:00
```

Notas:

- manter `edited_tag`;
- talvez reduzir ainda mais o tamanho do tag.

### `status: :pending`

Atual:

```text
[01/01 12:00]                         <alice> sending...
```

Proposto:

```text
      alice  sending...
01/01 12:00  pending
```

Notas:

- pode usar opacity no corpo;
- estado secundario `pending` pode ficar discreto ou ser omitido para nao poluir.

### `status: :failed`

Atual:

```text
[01/01 12:00]                         <alice> failed text [retry]
```

Proposto:

```text
      alice  failed text [retry]
01/01 12:00  failed
```

Notas:

- manter botao de retry proximo ao corpo;
- indicar erro sem ocupar uma linha extra sempre que possivel.

### `highlighted`

Atual:

```text
[01/01 12:00]                         <alice> mentioned you
```

Proposto:

```text
      alice  mentioned you
01/01 12:00
```

Notas:

- manter classe `chat-message--highlighted`;
- usar destaque de fundo/borda sem quebrar o novo grid.

## Cards ricos de sessao: P2P lobby e Arcade

Objetivo: convites e links de atividade nao devem parecer apenas uma frase com link.
Eles devem mostrar o estado atual da sessao e responder perguntas basicas:

- quando foi criada/iniciada;
- por quem foi criada;
- quando expira;
- se ja iniciou;
- se ja terminou;
- se terminou, quanto tempo levou;
- qual foi o motivo de termino quando houver;
- usar SVGs do catalogo existente para tornar o card memoravel sem inventar
  novos assets.

### Dados que ja existem

P2P/lobby persistente (`lobby_sessions`):

- `creator_id`
- `peer_id`
- `status`: `pending`, `lobby`, `connected`, `closed`, `expired`, `failed`
- `inserted_at`
- `accepted_at`
- `connected_at`
- `closed_at`
- `closed_reason`
- `duration_seconds`

Arcade solo (`solo_sessions`):

- `creator_id`
- `status`: `pending`, `lobby`, `playing`, `finished`, `closed`, `expired`
- `game_id`
- `inserted_at`
- `lobby_at`
- `game_started_at`
- `closed_at`
- `closed_reason`
- `duration_seconds`

Ponto importante: o nome exibido precisa vir de `creator_id` / `peer_id` via
`registered_nicks`. O card nao deve mostrar apenas ids internos.

### Dados parcialmente disponiveis

O tempo de expiracao existe como regra, mas nao como campo persistido:

- pending expira depois de 5 minutos;
- lobby antes de conectar expira depois de 15 minutos de inatividade;
- ha aviso de inatividade aos 10 minutos;
- em alguns fluxos, o timer de inatividade e resetado no processo, mas esse novo
  prazo nao fica salvo no banco.

Conclusao: para mostrar `expira as 12:05` com precisao, a implementacao deve
persistir um `expires_at` ou guardar esse valor em `metadata` sempre que o timer
for criado/resetado. Sem isso, so da para mostrar algo aproximado como
`expira apos 15 min de inatividade`.

### P2P lobby card

Atual:

```text
      alice  [p2p invite card]
01/01 12:00
```

Proposto quando pendente:

```text
      alice  P2P lobby com alice
01/01 12:00  Criado por bob · aguardando entrada · expira 12:05
             [Entrar no lobby]
```

Proposto quando conectado:

```text
      alice  P2P lobby com alice
01/01 12:00  Criado por bob · conectado desde 12:03
             [Abrir lobby]
```

Proposto quando encerrado:

```text
      alice  P2P lobby com alice
01/01 12:00  Encerrado · durou 18m 42s · motivo: peer left
```

Mapeamento sugerido:

- `inserted_at`: criado em;
- `creator_id`: criado por;
- `accepted_at`: ambos entraram no lobby;
- `connected_at`: conexao iniciou;
- `closed_at`: terminou em;
- `duration_seconds`: duracao;
- `closed_reason`: motivo final;
- `status`: badge visual.

### Arcade session card

Atual:

```text
     Arcade  [arcade session link]
01/01 12:00
```

Proposto quando pendente/lobby:

```text
     Arcade  Arcade session
01/01 12:00  Criado por bob · aguardando jogo · expira 12:05
             [Abrir Arcade]
```

Proposto quando jogando:

```text
     Arcade  DOOM Shareware
01/01 12:00  Criado por bob · iniciado 12:04
             [Abrir Arcade]
```

Proposto quando finalizado:

```text
     Arcade  DOOM Shareware
01/01 12:00  Finalizado · durou 07m 31s
```

Mapeamento sugerido:

- `inserted_at`: criado em;
- `creator_id`: criado por;
- `lobby_at`: entrou no lobby;
- `game_started_at`: jogo iniciou;
- `closed_at`: terminou em;
- `duration_seconds`: duracao;
- `closed_reason`: motivo final;
- `game_id`: nome do jogo via catalogo;
- `status`: badge visual.

### Catalogo SVG recomendado para os cards

Todos os nomes abaixo existem em `RetroHexChatWeb.Icons` e devem ser usados como
componentes HEEx, por exemplo:

```heex
<Icons.icon_p2p class="h-5 w-5" />
<Icons.game_icon game_id={@game_id} class="h-7 w-7" />
```

#### P2P lobby

Icone principal do card:

- `icon_p2p`: melhor escolha para o titulo do card P2P.
- `icon_webrtc`: alternativa quando a enfase visual for a conexao direta.

Metadados e timeline:

- `icon_status_user`: criado por / participante.
- `icon_clock`: horario criado, iniciado ou encerrado.
- `icon_btn_timers`: expiracao ou duracao.
- `icon_radio_dot`: etapa atual, por exemplo aguardando entrada.
- `icon_status_signal`: conectado / comunicacao ativa.
- `icon_btn_connect_lightning`: conexao iniciando ou estado de conexao forte.
- `icon_checkmark`: etapa concluida.
- `icon_warning`: expirado, quase expirando ou com atencao necessaria.
- `icon_reject`: falhou ou foi recusado/cancelado.
- `icon_btn_disconnect`: encerrado.
- `icon_phone_end`: alternativa para encerramento quando o card estiver mais
  proximo de chamada/midia.

CTA:

- `icon_btn_join`: entrar no lobby.
- `icon_btn_link`: abrir link do lobby.

Exemplo visual alvo:

```text
[icon_p2p]  P2P lobby
            criado por rodrigo

  [icon_checkmark]     criado       03/07 14:10
  [icon_radio_dot]     aguardando   expira 14:25
  [icon_status_signal] conectado    03/07 14:13
  [icon_btn_timers]    duracao      08m 42s

  [icon_btn_join] Entrar
```

Estado terminal:

```text
[icon_p2p]  P2P lobby encerrado
            rodrigo com alice

  [icon_checkmark]      criado      03/07 14:10
  [icon_status_signal]  conectado   03/07 14:13
  [icon_btn_disconnect] encerrado   03/07 14:22
  [icon_btn_timers]     duracao     08m 42s
```

#### Arcade session

Icone principal do card:

- `game_icon game_id={...}`: escolha recomendada quando houver `game_id`, porque
  mostra o jogo real.
- `icon_game_arcade`: fallback generico para Arcade.
- `icon_joystick`: fallback mais simples quando o card precisar ser pequeno.

Metadados e timeline:

- `icon_status_user`: criado por.
- `icon_clock`: horario de criacao ou encerramento.
- `icon_btn_play`: jogo iniciado / em andamento.
- `icon_btn_timers`: duracao.
- `icon_radio_dot`: etapa atual, por exemplo aguardando jogo.
- `icon_checkmark`: etapa concluida ou finalizada normalmente.
- `icon_warning`: expirado ou encerrado com alerta.
- `icon_reject`: falhou/cancelado.

CTA:

- `icon_btn_open`: abrir Arcade, abrir sessao ou abrir historico.
- `icon_btn_join`: entrar quando ainda for uma sala aguardando.
- `icon_btn_link`: abrir por link quando o card representar explicitamente uma URL.

Exemplo visual alvo:

```text
[game_icon]  DOOM Shareware
             Arcade por rodrigo

  [icon_checkmark]  criada      03/07 14:10
  [icon_btn_play]   iniciada    03/07 14:12
  [icon_btn_timers] duracao     06m 18s
  [icon_checkmark]  finalizada  03/07 14:18

  [icon_btn_open] Abrir
```

Estado pendente:

```text
[icon_game_arcade]  Arcade session
                    criado por rodrigo

  [icon_checkmark] criada       03/07 14:10
  [icon_radio_dot] aguardando   expira 14:25

  [icon_btn_open] Abrir Arcade
```

Recomendacao visual:

- usar o icone principal em `h-6 w-6` ou `h-7 w-7`;
- usar icones da timeline em `h-3.5 w-3.5` ou `h-4 w-4`;
- manter texto da timeline menor que o titulo;
- nao usar icone em todas as palavras: um por linha de evento e suficiente;
- para status atual, combinar `icon_radio_dot` com cor de estado;
- para terminal, trocar o ponto atual por `icon_checkmark`, `icon_warning`,
  `icon_reject` ou `icon_btn_disconnect`, conforme o motivo.

### Arquitetura recomendada

Usar metadado estruturado na mensagem. Isso e melhor do que depender de regex no
texto (`/lobby/<token>` ou `/solo/<token>`), porque o card passa a ter uma
referencia estavel para o registro real da sessao.

Metadado recomendado na mensagem:

```elixir
%{
  session_kind: :lobby | :arcade,
  session_id: 123,
  session_token: "..."
}
```

Para mensagens persistidas, o ideal e esse metadado morar no banco junto da
mensagem, nao apenas no stream item em memoria. Hoje `messages` e
`private_messages` tem `content` e `type`, mas nao um campo `metadata`; a
implementacao provavelmente precisaria adicionar `metadata :map` nas duas
schemas, com migracao.

Nao consultar banco dentro de `chat_message/1` ou `MessageRow.message_row/1`.
Esses componentes devem continuar sendo renderizacao pura. A busca do registro
de sessao deve acontecer antes, ao montar/enriquecer o item do stream.

Criar um view-model para cards de sessao, por exemplo:

```elixir
%{
  kind: :lobby | :arcade,
  session_id: 123,
  token: token,
  title: "...",
  href: "/lobby/..." | "/solo/...",
  created_by: "alice",
  created_at: ~U[...],
  expires_at: ~U[...] | nil,
  started_at: ~U[...] | nil,
  ended_at: ~U[...] | nil,
  duration_seconds: 1122 | nil,
  status: "pending",
  reason: nil | "peer_left",
  terminal?: false
}
```

Onde resolver/enriquecer:

- ao transformar mensagens em stream items (`pm_to_stream_item`,
  `message_to_stream_item`, e insercoes efemeras de `:arcade_link`);
- usando `msg.metadata.session_kind` + `msg.metadata.session_id` como fonte
  primaria;
- mantendo `session_token` no metadata para montar o link e como fallback;
- buscando `Lobby.Queries.get_session_by_token/1` ou
  `Arcade.Queries.get_session_by_token/1` quando so houver token;
- fazendo join/resolucao de `creator_id` / `peer_id` para nick.

### Dois cenarios de renderizacao

1. Sessao ainda viva
   - O card deve buscar o registro atual por `session_id`/`session_token`.
   - Exibe status vivo: `pending`, `lobby`, `connected`, `playing`.
   - Exibe CTA ativo: `Entrar`, `Abrir lobby`, `Abrir Arcade`.
   - Pode atualizar no stream quando chegar evento de status/fim.

2. Sessao historica
   - O card busca o mesmo registro, agora terminal.
   - Exibe status final: `closed`, `expired`, `failed`, `finished`.
   - Exibe `closed_at`, `closed_reason`, `duration_seconds`.
   - CTA pode sumir ou virar secundario/desabilitado, conforme a rota ainda
     permita abrir a tela encerrada.

Para atualizacao ao vivo:

- incluir `session_id`, `session_kind` e `token` nos eventos
  `lobby_session_ended` e `arcade_session_ended`;
- quando o chat receber esses eventos, resolver novamente o resumo e reinserir
  o stream item correspondente;
- para mensagens persistidas de PM, localizar a mensagem por metadata
  (`session_kind/session_id`) e atualizar o stream item;
- para `:arcade_link` efemero, usar id estavel derivado do token, por exemplo
  `arcade-<token>`, para permitir update no mesmo row.

Fallback:

- se a sessao nao for encontrada pelo metadata/token, renderizar o card simples atual;
- se `expires_at` ainda nao existir, mostrar duracao/regra aproximada em vez de
  prometer horario exato.

## Mapa por tipo: Status tab

Status tab usa `StatusViewport` e tambem renderiza por `chat_message/1`.

### `:motd`

Atual:

```text
[01/01 12:00]                                 Message of the Day text
```

Proposto:

```text
       MOTD  Message of the Day text
01/01 12:00
```

### `:system`

Atual:

```text
[01/01 12:00]                                 System line
```

Proposto:

```text
     System  System line
01/01 12:00
```

### `:error`

Atual:

```text
[01/01 12:00]                                 Error line
```

Proposto:

```text
      Error  Error line
01/01 12:00
```

### `:service`

Atual:

```text
[01/01 12:00]                                 NickServ / ChanServ info line
```

Proposto:

```text
    Service  NickServ / ChanServ info line
01/01 12:00
```

### `:wallops`

Atual:

```text
[01/01 12:00]                                 [Wallops] admin: message
```

Proposto:

```text
   Wallops  admin: message
01/01 12:00
```

Notas:

- pode remover o prefixo `[Wallops]` do corpo se a origem ja comunica o tipo;
- ou manter o prefixo por compatibilidade textual.

### `:notify_online`

Atual:

```text
[01/01 12:00]                                 * alice is now online
```

Proposto:

```text
     Online  alice is now online
01/01 12:00
```

### `:notify_offline`

Atual:

```text
[01/01 12:00]                                 * alice has gone offline
```

Proposto:

```text
    Offline  alice has gone offline
01/01 12:00
```

### `:notify_rename`

Atual:

```text
[01/01 12:00]                                 * old is now known as new
```

Proposto:

```text
     Rename  old is now known as new
01/01 12:00
```

## Mudancas tecnicas sugeridas

1. Criar um formato de timestamp sem colchetes.
   - Exemplo: `:mobile_dd_mm_hh_mm`.
   - Saida: `01/01 12:00`.
   - Fallback invalido: `--:--`.

2. Atualizar `chat_message/1` para aceitar uma origem nao-interativa.
   - `nick` continua sendo interativo.
   - `source` cobre casos nao-interativos como `System`, `Error`, `MOTD`.
   - Apenas nick real deve renderizar `.chat-nick[data-nick]`.
   - Origem de sistema deve usar classe propria, por exemplo `.chat-source`, sem `data-nick`.
   - `meta_title` pode guardar datetime completo.

3. Trocar o layout base do componente.
   - De: `grid-cols-[auto_10ch_1fr] md:grid-cols-[auto_18ch_1fr]`.
   - Para: `grid-cols-[5.8rem_1fr]` ou equivalente responsivo.
   - A coluna meta deve usar `text-right` / `items-end`.
   - Nick/origem deve ficar na primeira linha; timestamp menor na segunda.
   - Nicks longos devem usar `truncate` e `title`.

4. Remover `< >` do nick normal.
   - Renderizar `alice`, nao `<alice>`.

5. Ajustar `MessageRow`.
   - `:message`: passa `nick`.
   - `:action`: passa `nick`, corpo vira apenas `* content`.
   - `:system`: passa origem `System`.
   - `:service`: passa origem `Service` ou autor do servico.
   - `:error`: passa origem `Error`.
   - `:notice`: passa `nick` ou origem nao-interativa conforme contexto.
   - `:announcement`: adicionar branch propria com origem `Server`.
   - `:inline_help`, `:arcade_link`: origens dedicadas.

6. Ajustar `StatusViewport`.
   - Passar origem por tipo para evitar coluna meta vazia.

7. Atualizar testes.
   - `ChatHelpersTest`: novo timestamp sem colchetes.
   - `MessageRowTest`: remover expectativa de `grid-cols-[auto_10ch_1fr]`.
   - `MessageRowTest`: garantir que normal nao renderiza `<nick>`.
   - `ChatMessageTest`: cobrir origem nao-interativa e preservacao de `.chat-nick[data-nick]`.
   - E2E: revisar seletores de timestamp/nick se necessario, preservando `data-testid`.

## Decisoes para revisao

1. Timestamp visivel:
   - Recomendado: `DD/MM HH:MM`.
   - Alternativa: `DD/MM/YYYY HH:MM`, com coluna lateral maior.

2. Fonte do corpo:
   - Recomendado: subir de `text-sm` para algo proximo de `15px`.
   - Alternativa: manter `text-sm` e compactar apenas metadados.

3. Fonte do chat:
   - Recomendado: manter mono apenas em timestamp/nick, e testar corpo sem mono.
   - Alternativa: manter tudo mono para preservar identidade retro.

4. Origens de sistema:
   - Recomendado: `System`, `Service`, `Error`, `MOTD`, `Wallops`, `Online`, `Offline`, `Rename`.
   - Alternativa: usar origens especificas quando disponiveis, como `Server`, `ChanServ`, `NickServ`.

5. `:announcement`:
   - Recomendado: criar visual proprio com origem `Server`.
   - Alternativa: manter como mensagem normal de `Server`.

## Criterios de aceite

- Em mobile, o texto da mensagem ocupa mais largura que hoje.
- Nicks nao aparecem entre `< >`.
- Timestamp nao aparece entre `[ ]`.
- Mensagens normais, acoes, sistema, erro, notice, cards e status continuam renderizando.
- Hooks de nick, busca, contexto, retry e scroll continuam funcionando.
- URLs longas e palavras longas nao quebram o layout.
- O status tab continua legivel com os mesmos tipos.
