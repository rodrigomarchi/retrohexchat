# Integração com chat e produto

Status: auditado contra o codebase em 2026-07-05. Decisões fechadas com o
usuário. Pronto para implementação.

Atenção à sobrecarga de nomes (auditado): a LiveView é
`RetroHexChatWeb.App.ChatLive` (`live/app/chat_live.ex`); o namespace de
helpers/ui-actions é `RetroHexChatWeb.ChatLive.*` (`live/chat_live/`). São
dois namespaces diferentes que compartilham o nome "ChatLive".

## Fluxo principal

1. Usuário identificado digita `/space [#canal-alvo] [nome-do-space] ttl=2h` em
   um contexto de canal.
2. Handler valida canal, permissão de fala/postagem, TTL e criação.
3. Chat recebe uma `:ui_action` para publicar o link no canal alvo.
4. Uma mensagem/card aparece no canal com `/space/:token`.
5. Usuário registrado/identificado abre o link.
6. `SpaceLive` valida sessão, identificação e permissão no canal de origem,
   assina um `join_token` curto e renderiza o canvas.
7. `SpaceCanvasHook` entra no `SpaceChannel` e recebe o snapshot inicial.
8. Espaço expira no TTL configurado ou é fechado pelo criador, e o card passa a
   mostrar estado terminal.

## Slash command

Comando recomendado:

```text
/space
/space #general
/space #general Taverna da Guilda
/space #general Taverna da Guilda ttl=2h
/space Taverna da Guilda ttl=2h
```

Sintaxe alvo:

```text
/space [#canal-alvo] [nome-do-space] ttl=[2h default]
```

Se `#canal-alvo` não vier, usar o canal ativo. PM, Status e lobby P2P não são
contextos válidos para criar espaço, mesmo com canal alvo. Subcomandos
administrativos podem vir depois, mas os poderes principais também devem existir
dentro do espaço para o criador.

Handler:

```text
apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/space.ex
```

Registro (auditado: mapa compile-time `@commands` em
`RetroHexChat.Commands.Registry`, mesmo formato de
`"p2p" => RetroHexChat.Commands.Handlers.Lobby`):

```elixir
"space" => RetroHexChat.Commands.Handlers.Space
```

O handler implementa o behaviour `RetroHexChat.Commands.Handler`:

- `category/0` retornando `:user` (categorias válidas:
  `[:basics, :channel, :user, :config, :advanced]`);
- `help/0` retornando `%{name, syntax, description, examples}`;
- `syntax_definition/0` opcional retornando `%RetroHexChat.Commands.CommandSyntax{}`.

Resultado do handler (contrato auditado no análogo `Handlers.Lobby`, que
retorna `{:ok, :ui_action, :lobby_invite, %{target: target, token: result.token,
creator_id: creator_id}}`):

```elixir
{:ok, :ui_action, :space_invite,
 %{target: channel_name, token: token, title: title, creator_id: creator_id}}
```

## UI action

Fluxo auditado: o retorno `{:ok, :ui_action, action, payload}` passa por
`CommandDispatch.handle_dispatch_result/3`, que especial-casa `:lobby_invite`
para `Helpers.LobbyInvite` antes de cair no roteador genérico
`UiActionHandlers.handle_ui_action/3`. O `:space_invite` segue o análogo do
invite:

```text
RetroHexChatWeb.ChatLive.Helpers.SpaceInvite
```

(análogo de `Helpers.LobbyInvite.lobby_invite_content/1`, com especial-case em
`CommandDispatch.handle_dispatch_result/3`.)

Responsabilidades:

- montar URL com `PathHelpers.activity_path(socket, "/space/#{token}")`
  (auditado: `Helpers.PathHelpers.activity_path/2`, hoje identidade);
- gerar o conteúdo do card e persistir a mensagem `space_invite` no canal alvo
  via domínio de chat (nunca em PM na V1);
- empurrar status "Space created..." para o usuário.

Não criar caminho paralelo no menu. Menu e toolbar devem sintetizar o mesmo
comando ou chamar `CommandDispatch.dispatch_command`.

## Card de convite

Decisão fechada (2026-07-05): card persistido em mensagem de CANAL. Não existe
precedente disso no codebase — `:p2p_invite` só existe em `PrivateMessage`
(`@type_values ~w(message action system p2p_invite)`) e `:arcade_link` é item
efêmero de stream, não persistido. O `space_invite` será o primeiro tipo de
card rico em mensagem de canal. Pontos de mudança auditados:

1. `apps/retro_hex_chat/lib/retro_hex_chat/chat/message.ex` — adicionar
   `space_invite` ao `@type_values` (hoje `~w(message action system service
   error notice)`);
2. `apps/retro_hex_chat/lib/retro_hex_chat/chat/service.ex` — adicionar ao
   `@known_types`;
3. `helpers/session_card.ex` — clause `enrich/1` casando `type: :space_invite`
   com regex `/space/<token>` chamando `VirtualSpace.session_summary/1`;
4. `pubsub_handlers/messages.ex` — enrich no build da linha (padrão da linha
   ~467) e clauses de ignore-type;
5. `components/session_card.ex` + `components/message_row.ex` — render.

Conteúdo textual fallback:

```text
Virtual space ready. Join: /space/<token>
```

Card rico deve mostrar:

- título do espaço;
- criador;
- canal de origem;
- mapa atual;
- status: aberto, ativo, cheio, expirado, encerrado;
- participantes atuais / limite configurado;
- validade/expiração;
- botão "Enter space" enquanto vivo;
- sem CTA quando terminal.

Extensão do helper existente (auditado: `Helpers.SessionCard.enrich/1` consulta
o resumo no build da linha; `Components.SessionCard` renderiza):

```elixir
VirtualSpace.session_summary(token)
```

Decisão fechada (2026-07-05): SEM refresh ao vivo de card. O card mostra o
estado de quando a linha foi construída e se corrige em rebuild/remount — o
mesmo comportamento dos cards P2P/arcade hoje. Quem clicar num link expirado vê
a tela terminal do espaço, então card desatualizado não é problema. Refresh
push-driven fica fora da V1.

## Menu de contexto

Entradas possíveis:

- menu de canal/conversa: "Create virtual space";
- toolbar/menu Tools: "Create virtual space".

Mapeamento recomendado:

- "Create virtual space" em canal -> `/space`;
- "Create virtual space" em lista de canais -> `/space #canal`;
- toolbar/menu Tools deve exigir canal ativo ou pedir/usar `#canal-alvo`.

Não criar convite direto por nick na V1.

## Rota

Adicionar em `router.ex`, no scope `RetroHexChatWeb.App`, dentro da
`live_session :app_locale` (on_mount `{RetroHexChatWeb.Live.PutLocale,
:default}`), pipeline `:app`:

```elixir
live "/space/:token", SpaceLive
```

Não localizar a rota com prefixo de idioma (validado: as rotas do app não são
prefixadas; só landing e help são); ela segue o padrão de `/chat`,
`/lobby/:token`, `/solo/:token` e `/arcade/:token/:game_id`.

## LiveView

Mecanismo de auth auditado (não há on_mount de auth; é assign de sessão HTTP):
`mount/3` lê `session["chat_nickname"]` e usa
`RetroHexChatWeb.App.SessionHelpers.verify_nickname/2` (nil redireciona para
`/connect`) e `SessionHelpers.resolve_user_id/1` (lookup em `RegisteredNick`).
O estado terminal segue o análogo `LobbyLive` + componente
`RetroHexChatWeb.Components.UI.Lobby.LobbyTerminal` (criar o análogo
`SpaceTerminal` ou generalizar).

`SpaceLive` deve:

- verificar nickname da sessão;
- exigir usuário registrado/identificado;
- resolver `user_id`;
- verificar token não terminal/não expirado;
- verificar permissão no `channel_name` da sessão;
- assinar `join_token` curto com `Phoenix.Token`;
- renderizar terminal se inválido/expirado;
- renderizar canvas com `phx-hook="SpaceCanvasHook"`, `data-space-token` e
  `data-join-token`;
- não processar input de movimento.

## Channel

`SpaceChannel` deve:

- validar `join_token`;
- revalidar `user_id`, `channel_name` e permissão do espaço;
- chamar `VirtualSpace.join_session/2`;
- enviar `space_init` como resposta do join;
- repassar `space_input`, `space_chat_bubble`, `space_interact` e `space_leave`
  para o domínio;
- receber broadcasts PubSub do `SessionServer` e empurrar eventos para o JS;
- chamar `VirtualSpace.leave/2` em `terminate/2`.

## Chat dentro do espaço

V1 tem chat textual global do espaço:

- usuário digita em uma caixa pequena ou usa o composer do espaço;
- servidor limita tamanho, por exemplo 160 chars;
- criador/admin pode mutar participantes dentro do espaço;
- mensagem não precisa ir para histórico do canal;
- todos no espaço veem balão sobre avatar e log lateral efêmero.

Depois podemos integrar com histórico real de canal, mas isso mistura histórico
de chat com presença espacial e aumenta o escopo.

## Capacidade

Limite default V1: 20 participantes, configurável pelo admin em runtime via
`server_settings` (chave `"space_max_participants"`): leitura com
`Services.Queries.get_setting/1` + fallback em atributo de módulo (padrão
auditado de `"max_channels"` em `Handlers.Join`), escrita whitelistada em
`Commands.Handlers.Admin.Server.validate_setting_value/2`.

Quando cheio:

- `join_session` retorna erro claro;
- `SpaceChannel.join/3` retorna erro claro, e o hook mostra terminal/estado de
  erro no canvas;
- card no chat mostra `current/max` se o resumo estiver atualizado.

## Expiração e encerramento

O card deve usar `expires_at`. O `SessionServer` deve transmitir:

```elixir
%{
  event: "space_session_ended",
  payload: %{
    token: token,
    reason: reason,
    duration_seconds: duration_seconds
  }
}
```

O card se corrige na próxima montagem/rebuild via `session_summary/1` (decisão
fechada: sem refresh ao vivo na V1). O broadcast de fim serve aos clientes
conectados no espaço, não ao card do chat.

## Poderes do criador

O criador do espaço deve conseguir:

- expulsar participante;
- fechar o espaço;
- trocar o mapa entre os mapas permitidos;
- mutar/desmutar chat de participante.

Essas ações passam pelo mesmo `SpaceChannel`/domínio e devem ser validadas no
servidor. UI do criador pode ser um painel simples dentro do canvas/HUD.

## i18n e help

Correção auditada: NÃO existe domínio gettext `commands` (existem `chat, games,
p2p, help, help_*` etc.). Criar domínio `space` para as strings do espaço
virtual; strings curtas de comando/status seguem no domínio `chat`, como os
comandos atuais. Cuidado com o débito conhecido do extract: manter apenas os
catálogos do domínio afetado e preencher msgstrs com traduções reais.

Help (mandatório pelo padrão do projeto — CLAUDE.md): tópicos vivem em
submódulos de categoria de `RetroHexChat.Chat.HelpTopics`
(`chat/help_topics/*.ex`), com shape
`%{id, title, category, keywords, icon, description}` e categoria como string
localizada. Não existe tópico `help_games`; as categorias de jogos são
"P2P Games: ..." e "Solo Arcade: ...". Adicionar:

- tópico do comando `/space` na categoria Commands;
- tópico "Virtual spaces" na categoria Features (ou nova categoria localizada
  "Virtual Spaces" se o conteúdo crescer);
- atualização do tópico de atalhos de teclado (teclas do canvas);
- cross-references "See Also" nos tópicos relacionados (P2P games, channels).

## Segurança

- token aleatório forte com
  `Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)` (padrão
  auditado de `Lobby.Service.insert_session/2`);
- `join_token` assinado e curto via `Phoenix.Token`, seguindo o padrão auditado
  de `RetroHexChat.P2P.SessionToken` (salt próprio, `max_age` curto, payload
  `%{space_token, channel_name, user_id, nickname}`); o token de URL é bearer
  capability, mas não autentica sozinho o Channel;
- criar e entrar exigem usuário registrado/identificado;
- validar permissão no canal de origem no LiveView e no Channel;
- não aceitar `map_id` arbitrário do cliente;
- rate limit para criação;
- rate limit para input/mensagem;
- validação de movimento no servidor;
- nenhum HTML vindo do balão deve ser renderizado como markup;
- cards e mensagens devem escapar conteúdo como o chat já faz.
