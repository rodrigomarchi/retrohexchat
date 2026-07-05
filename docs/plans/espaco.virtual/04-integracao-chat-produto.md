# Integração com chat e produto

Status: proposta para conversa. Nenhuma implementação feita ainda.

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

Registro:

```elixir
"space" => RetroHexChat.Commands.Handlers.Space
```

Categoria: `:user`.

Resultado do handler:

```elixir
{:ok, :ui_action, :space_invite, %{token: token, title: title}}
```

## UI action

Adicionar uma família de UI action, seguindo o padrão atual:

```text
RetroHexChatWeb.ChatLive.UiActions.Space
```

Responsabilidades:

- montar URL com `PathHelpers.activity_path(socket, "/space/#{token}")`;
- criar item de stream/card;
- publicar no canal alvo, nunca em PM na V1;
- empurrar status "Space created..." para o usuário.

Não criar caminho paralelo no menu. Menu e toolbar devem sintetizar o mesmo
comando ou chamar `CommandDispatch.dispatch_command`.

## Card de convite

Novo tipo:

```elixir
:space_invite
```

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

Helper novo ou extensão do existente:

```text
RetroHexChatWeb.ChatLive.Helpers.SessionCard
```

O card deve consultar:

```elixir
VirtualSpace.session_summary(token)
```

Importante: eventos de fim devem carregar `token`, para permitir refresh ao vivo
do card sem depender de reabrir a conversa.

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

Adicionar em `Router` dentro do live_session app:

```elixir
live "/space/:token", SpaceLive
```

Não localizar a rota com prefixo de idioma; ela deve seguir o padrão de `/chat`,
`/lobby/:token`, `/solo/:token` e `/arcade/:token/:game_id`.

## LiveView

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

Limite default V1: 20 participantes, configurável no painel de admin do
servidor.

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

O chat atualiza o card se ele estiver visível. Se não estiver, ele se corrige na
próxima montagem via `session_summary/1`.

## Poderes do criador

O criador do espaço deve conseguir:

- expulsar participante;
- fechar o espaço;
- trocar o mapa entre os mapas permitidos;
- mutar/desmutar chat de participante.

Essas ações passam pelo mesmo `SpaceChannel`/domínio e devem ser validadas no
servidor. UI do criador pode ser um painel simples dentro do canvas/HUD.

## i18n e help

Adicionar domínio gettext `space` se as strings crescerem. Strings curtas de
comando podem ficar em `commands`.

Help:

- `/help space`;
- tópico em `help_games` ou novo tópico "Virtual spaces", dependendo de como o
  projeto categorizar essa funcionalidade.

## Segurança

- token aleatório forte com `Base.url_encode64(:crypto.strong_rand_bytes(32))`;
- `join_token` assinado e curto; o token de URL é bearer capability, mas não
  autentica sozinho o Channel;
- criar e entrar exigem usuário registrado/identificado;
- validar permissão no canal de origem no LiveView e no Channel;
- não aceitar `map_id` arbitrário do cliente;
- rate limit para criação;
- rate limit para input/mensagem;
- validação de movimento no servidor;
- nenhum HTML vindo do balão deve ser renderizado como markup;
- cards e mensagens devem escapar conteúdo como o chat já faz.
