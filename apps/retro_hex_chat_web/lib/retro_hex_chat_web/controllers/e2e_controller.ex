defmodule RetroHexChatWeb.E2EController do
  use RetroHexChatWeb, :controller

  alias RetroHexChat.Arcade
  alias RetroHexChat.Bots.Lifecycle, as: BotLifecycle
  alias RetroHexChat.Bots.Queries, as: BotQueries
  alias RetroHexChat.Bots.Server, as: BotServer
  alias RetroHexChat.Channels.Server, as: ChannelServer
  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor
  alias RetroHexChat.Chat.Archive
  alias RetroHexChat.Chat.Content
  alias RetroHexChat.Chat.ContextualTips
  alias RetroHexChat.Games.Catalog, as: GameCatalog
  alias RetroHexChat.Games.Results
  alias RetroHexChat.Services.Queries, as: ServiceQueries

  @message_types %{
    "message" => :message,
    "notice" => :notice,
    "action" => :action,
    "system" => :system
  }

  # The bots `docs/provisioning/en.md` puts in the Retro Games rooms and in
  # the arcade's.
  @announcer "Scoreboard"
  @arcade_announcer "Pixel"

  @channel_pattern ~r/^#[A-Za-z0-9_-]{1,48}$/
  @nickname_pattern ~r/^[A-Za-z][A-Za-z0-9_\-\[\]\\`^{}|]{0,15}$/
  @max_content_length 1_100

  @spec create_channel_message(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create_channel_message(conn, params) do
    if Application.get_env(:retro_hex_chat, :e2e_fault_injection?, false) do
      do_create_channel_message(conn, params)
    else
      not_found(conn)
    end
  end

  defp do_create_channel_message(conn, %{
         "channel" => channel,
         "author" => author,
         "content" => content
       })
       when is_binary(channel) and is_binary(author) and is_binary(content) do
    params = conn.body_params

    with :ok <- validate_channel(channel),
         :ok <- validate_author(author),
         :ok <- validate_content(content),
         {:ok, type} <- parse_message_type(Map.get(params, "type", "message")),
         {:ok, content_format} <-
           parse_content_format(Map.get(params, "content_format", "markdown")),
         :ok <- ensure_channel_started(channel),
         :ok <- ensure_bot_joined(channel, author),
         {:ok, id} <-
           ChannelServer.send_message(channel, author, content, type,
             content_format: content_format
           ) do
      json(conn, %{status: "created", id: id})
    else
      {:error, reason} -> error(conn, :unprocessable_entity, reason)
    end
  end

  defp do_create_channel_message(conn, _params), do: error(conn, :bad_request, "invalid params")

  @doc """
  Writes a finished Retro Games match through the real ledger, as if it had
  been played — so a spec sees its card in the game's channel and in the two
  players' conversation without driving a whole match on a canvas. The game's
  room and the feed are set up first with what `docs/provisioning/en.md` gives
  them that the spec relies on — registered by the host, archived, with the
  Scoreboard bot announcing in them — so the spec does not depend on a pasted
  script.
  """
  @spec record_game_result(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def record_game_result(conn, params) do
    if Application.get_env(:retro_hex_chat, :e2e_fault_injection?, false) do
      do_record_game_result(conn, params)
    else
      not_found(conn)
    end
  end

  defp do_record_game_result(
         conn,
         %{"game_id" => game_id, "p1" => p1, "payload" => payload} = params
       )
       when is_binary(game_id) and is_binary(p1) and is_map(payload) do
    seconds = Map.get(params, "duration_seconds", 120)

    with {:ok, host} <- registered_player(p1),
         {:ok, guest} <- optional_player(Map.get(params, "p2")),
         :ok <- provision_game_room(GameCatalog.channel_name(game_id), host.nickname, @announcer),
         :ok <- provision_game_room(GameCatalog.feed_channel(), host.nickname, @announcer),
         {:ok, row} <-
           Results.record(%{
             game_id: game_id,
             origin: if(guest, do: "p2p", else: "ai"),
             difficulty: if(guest, do: nil, else: Map.get(params, "difficulty", "normal")),
             p1: host,
             p2: guest,
             payload: payload,
             lobby_token:
               guest && "e2e-" <> Integer.to_string(System.unique_integer([:positive])),
             started_at: DateTime.add(DateTime.utc_now(), -seconds, :second)
           }) do
      json(conn, %{status: "created", id: row.id})
    else
      {:error, reason} -> error(conn, :unprocessable_entity, inspect(reason))
    end
  end

  defp do_record_game_result(conn, _params), do: error(conn, :bad_request, "invalid params")

  @doc """
  Sets an arcade game's room and `#arcade` up as `docs/provisioning/en.md`
  leaves them — registered by `founder`, archived, with Pixel announcing in
  them — so a spec that starts the game sees the line and its card.
  """
  @spec provision_arcade_rooms(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def provision_arcade_rooms(conn, params) do
    if Application.get_env(:retro_hex_chat, :e2e_fault_injection?, false) do
      do_provision_arcade_rooms(conn, params)
    else
      not_found(conn)
    end
  end

  defp do_provision_arcade_rooms(conn, %{"game_id" => game_id, "founder" => founder})
       when is_binary(game_id) and is_binary(founder) do
    with {:ok, _game} <- Arcade.get_game(game_id),
         {:ok, owner} <- registered_player(founder),
         :ok <-
           provision_game_room(Arcade.channel_name(game_id), owner.nickname, @arcade_announcer),
         :ok <- provision_game_room(Arcade.feed_channel(), owner.nickname, @arcade_announcer) do
      json(conn, %{status: "created", channel: Arcade.channel_name(game_id)})
    else
      {:error, reason} -> error(conn, :unprocessable_entity, inspect(reason))
    end
  end

  defp do_provision_arcade_rooms(conn, _params), do: error(conn, :bad_request, "invalid params")

  defp provision_game_room(channel, founder, announcer_name) do
    if is_nil(ServiceQueries.find_registered_channel(channel)) do
      {:ok, _row} = ServiceQueries.insert_registered_channel(channel, founder)
      {:ok, _access} = ServiceQueries.add_access(channel, founder, "founder", founder)
      {:ok, _published} = Archive.publish(channel)
      _ = ChannelServer.mark_registered(channel)
    end

    announcer =
      BotQueries.get_bot_by_name(announcer_name) || create_announcer(announcer_name, founder)

    # What `/bot join` does: the row, then the running bot into the room.
    with {:ok, _config} <- BotQueries.add_channel_config(announcer.id, channel),
         {:ok, _pid} <- BotLifecycle.ensure_started(announcer) do
      _ = BotServer.join_channel(announcer.nickname, channel)
    end

    :ok
  end

  defp create_announcer(name, founder) do
    {:ok, bot} =
      BotQueries.create_bot(%{
        name: name,
        nickname: name,
        created_by: founder,
        locale: "en",
        capabilities: %{"game" => %{"enabled" => true}}
      })

    bot
  end

  defp optional_player(nil), do: {:ok, nil}
  defp optional_player(nickname), do: registered_player(nickname)

  defp registered_player(nickname) do
    case ServiceQueries.find_by_nickname(nickname) do
      nil -> {:error, "#{nickname} is not registered"}
      nick -> {:ok, %{id: nick.id, nickname: nick.nickname}}
    end
  end

  @doc """
  Turns contextual tips off for a nickname, as "Don't show tips again" would.
  Saved before that person signs in, their session loads it and no tip opens.
  """
  @spec suppress_contextual_tips(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def suppress_contextual_tips(conn, params) do
    if Application.get_env(:retro_hex_chat, :e2e_fault_injection?, false) do
      do_suppress_contextual_tips(conn, params)
    else
      not_found(conn)
    end
  end

  defp do_suppress_contextual_tips(conn, %{"nickname" => nickname}) when is_binary(nickname) do
    with :ok <- validate_author(nickname),
         :ok <- ContextualTips.save(nickname, %{seen_tips: [], suppressed: true}) do
      json(conn, %{status: "suppressed"})
    else
      {:error, reason} -> error(conn, :unprocessable_entity, inspect(reason))
    end
  end

  defp do_suppress_contextual_tips(conn, _params), do: error(conn, :bad_request, "invalid params")

  defp validate_channel(channel) do
    if Regex.match?(@channel_pattern, channel) do
      :ok
    else
      {:error, "invalid channel"}
    end
  end

  defp validate_author(author) do
    if Regex.match?(@nickname_pattern, author) do
      :ok
    else
      {:error, "invalid author"}
    end
  end

  defp validate_content(content) do
    cond do
      String.length(content) > @max_content_length -> {:error, "content too large"}
      String.trim(content) == "" -> {:error, "content is blank"}
      true -> :ok
    end
  end

  defp parse_message_type(type) when is_binary(type) do
    case Map.fetch(@message_types, type) do
      {:ok, message_type} -> {:ok, message_type}
      :error -> {:error, "invalid message type"}
    end
  end

  defp parse_message_type(_type), do: {:error, "invalid message type"}

  defp parse_content_format(format) do
    case Content.normalize_format(format) do
      {:ok, normalized} -> {:ok, Atom.to_string(normalized)}
      :error -> {:error, "invalid content format"}
    end
  end

  defp ensure_channel_started(channel) do
    case ChannelSupervisor.ensure_started(channel) do
      {:ok, _pid} -> :ok
      {:error, reason} -> {:error, "channel start failed: #{inspect(reason)}"}
    end
  end

  defp ensure_bot_joined(channel, author) do
    with {:ok, %{members: members}} <- ChannelServer.get_state(channel),
         false <- Enum.any?(members, fn {nick, _role} -> nick == author end) do
      join_bot(channel, author)
    else
      true -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp join_bot(channel, author) do
    case ChannelServer.join(channel, author, nil, bot: true) do
      {:ok, _state} -> :ok
      {:error, "Already in channel"} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp error(conn, status, reason) do
    conn
    |> put_status(status)
    |> json(%{status: "error", error: to_string(reason)})
  end

  defp not_found(conn) do
    conn
    |> put_status(:not_found)
    |> json(%{status: "not_found"})
  end
end
