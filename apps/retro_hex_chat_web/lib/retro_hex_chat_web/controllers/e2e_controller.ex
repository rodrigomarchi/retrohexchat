defmodule RetroHexChatWeb.E2EController do
  use RetroHexChatWeb, :controller

  alias RetroHexChat.Channels.Registry, as: ChannelRegistry
  alias RetroHexChat.Channels.Server, as: ChannelServer
  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor
  alias RetroHexChat.Chat.Content

  @message_types %{
    "message" => :message,
    "notice" => :notice,
    "action" => :action,
    "system" => :system
  }

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
    case ChannelRegistry.lookup(channel) do
      {:ok, _pid} ->
        :ok

      {:error, :not_found} ->
        case ChannelSupervisor.start_child(channel) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
          {:error, reason} -> {:error, "channel start failed: #{inspect(reason)}"}
        end
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
