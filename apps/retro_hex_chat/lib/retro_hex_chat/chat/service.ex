defmodule RetroHexChat.Chat.Service do
  @moduledoc """
  Orchestrates message sending: policy check -> persist -> PubSub broadcast.
  """

  require Logger

  alias RetroHexChat.Chat.{Policy, Queries}

  @max_preview_length 100

  @spec send_message(String.t(), String.t(), String.t(), String.t(), keyword()) ::
          {:ok, RetroHexChat.Chat.Message.t()} | {:error, String.t()}
  def send_message(channel_name, nickname, content, type \\ "message", opts \\ []) do
    reply_to_id = Keyword.get(opts, :reply_to_id)

    with :ok <- Policy.validate_content(content),
         {:ok, reply_attrs} <- resolve_reply_attrs(reply_to_id, :message),
         {:ok, message} <- do_insert_message(channel_name, nickname, content, type, reply_attrs) do
      broadcast_message(channel_name, message)
      {:ok, message}
    end
  end

  @spec edit_message(integer(), String.t(), String.t()) ::
          {:ok, RetroHexChat.Chat.Message.t()} | {:error, String.t()}
  def edit_message(message_id, nickname, new_content) do
    with :ok <- Policy.validate_content(new_content),
         %{} = message <- Queries.get_message(message_id) || {:error, "Message not found."},
         :ok <- Policy.can_edit?(message, nickname),
         now <- DateTime.utc_now(),
         {:ok, updated} <- Queries.update_message_content(message, new_content, now) do
      broadcast_edit(message.channel_name, updated)
      update_reply_previews_if_needed(message.id, new_content, message.channel_name)
      {:ok, updated}
    end
  end

  @spec edit_private_message(integer(), String.t(), String.t()) ::
          {:ok, RetroHexChat.Chat.PrivateMessage.t()} | {:error, String.t()}
  def edit_private_message(pm_id, nickname, new_content) do
    with :ok <- Policy.validate_content(new_content),
         %{} = pm <-
           Queries.get_private_message(pm_id) || {:error, "Message not found."},
         :ok <- Policy.can_edit?(Map.put(pm, :author_nickname, pm.sender_nickname), nickname),
         now <- DateTime.utc_now(),
         {:ok, updated} <- Queries.update_pm_content(pm, new_content, now) do
      broadcast_pm_edit(pm.sender_nickname, pm.recipient_nickname, updated)

      update_pm_reply_previews_if_needed(
        pm.id,
        new_content,
        pm.sender_nickname,
        pm.recipient_nickname
      )

      {:ok, updated}
    end
  end

  @spec delete_message(integer(), String.t()) ::
          {:ok, RetroHexChat.Chat.Message.t()} | {:error, String.t()}
  def delete_message(message_id, nickname) do
    with %{} = message <- Queries.get_message(message_id) || {:error, "Message not found."},
         :ok <- Policy.can_delete?(message, nickname),
         now <- DateTime.utc_now(),
         {:ok, deleted} <- Queries.soft_delete_message(message, now) do
      broadcast_delete(message.channel_name, deleted)
      {:ok, deleted}
    end
  end

  @spec delete_private_message(integer(), String.t()) ::
          {:ok, RetroHexChat.Chat.PrivateMessage.t()} | {:error, String.t()}
  def delete_private_message(pm_id, nickname) do
    with %{} = pm <- Queries.get_private_message(pm_id) || {:error, "Message not found."},
         :ok <- Policy.can_delete?(Map.put(pm, :author_nickname, pm.sender_nickname), nickname),
         now <- DateTime.utc_now(),
         {:ok, deleted} <- Queries.soft_delete_pm(pm, now) do
      broadcast_pm_delete(pm.sender_nickname, pm.recipient_nickname, deleted)
      {:ok, deleted}
    end
  end

  @spec send_system_message(String.t(), String.t()) ::
          {:ok, RetroHexChat.Chat.Message.t()} | {:error, any()}
  def send_system_message(channel_name, content) do
    case Queries.insert_message(%{
           channel_name: channel_name,
           author_nickname: "System",
           content: content,
           type: "system"
         }) do
      {:ok, message} ->
        broadcast_message(channel_name, message)
        {:ok, message}

      {:error, _} = err ->
        err
    end
  end

  @spec send_private_message(String.t(), String.t(), String.t(), String.t(), keyword()) ::
          {:ok, RetroHexChat.Chat.PrivateMessage.t()} | {:error, String.t()}
  def send_private_message(sender, recipient, content, type \\ "message", opts \\ []) do
    reply_to_id = Keyword.get(opts, :reply_to_id)

    with :ok <- Policy.validate_content(content),
         {:ok, reply_attrs} <- resolve_reply_attrs(reply_to_id, :pm),
         {:ok, pm} <- do_insert_pm(sender, recipient, content, type, reply_attrs) do
      broadcast_private_message(sender, recipient, pm)
      {:ok, pm}
    end
  end

  # ── Reply resolution ──

  defp resolve_reply_attrs(nil, _kind), do: {:ok, %{}}

  defp resolve_reply_attrs(reply_to_id, :message) do
    case Queries.get_message(reply_to_id) do
      nil ->
        {:error, "Original message not found."}

      parent ->
        preview = truncate_preview(parent.content)

        {:ok,
         %{
           reply_to_id: parent.id,
           reply_to_author: parent.author_nickname,
           reply_to_preview: preview
         }}
    end
  end

  defp resolve_reply_attrs(reply_to_id, :pm) do
    case Queries.get_private_message(reply_to_id) do
      nil ->
        {:error, "Original message not found."}

      parent ->
        preview = truncate_preview(parent.content)

        {:ok,
         %{
           reply_to_id: parent.id,
           reply_to_author: parent.sender_nickname,
           reply_to_preview: preview
         }}
    end
  end

  defp truncate_preview(content) when byte_size(content) == 0, do: ""

  defp truncate_preview(content) do
    if String.length(content) > @max_preview_length do
      String.slice(content, 0, @max_preview_length - 3) <> "..."
    else
      content
    end
  end

  # ── Insert helpers ──

  defp do_insert_message(channel_name, nickname, content, type, reply_attrs) do
    attrs =
      Map.merge(
        %{channel_name: channel_name, author_nickname: nickname, content: content, type: type},
        reply_attrs
      )

    if map_size(reply_attrs) > 0 do
      Queries.insert_reply_message(attrs)
    else
      Queries.insert_message(attrs)
    end
  end

  defp do_insert_pm(sender, recipient, content, type, reply_attrs) do
    attrs =
      Map.merge(
        %{sender_nickname: sender, recipient_nickname: recipient, content: content, type: type},
        reply_attrs
      )

    if map_size(reply_attrs) > 0 do
      Queries.insert_reply_pm(attrs)
    else
      Queries.insert_private_message(attrs)
    end
  end

  # ── Reply preview updates ──

  defp update_reply_previews_if_needed(parent_id, new_content, channel_name) do
    reply_ids = Queries.get_reply_ids(parent_id)

    if reply_ids != [] do
      preview = truncate_preview(new_content)
      Queries.update_reply_previews(parent_id, preview)

      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        "channel:#{channel_name}",
        %{
          event: "reply_quote_updated",
          payload: %{parent_id: parent_id, new_preview: preview, reply_ids: reply_ids}
        }
      )
    end
  end

  defp update_pm_reply_previews_if_needed(parent_id, new_content, sender, recipient) do
    reply_ids = Queries.get_pm_reply_ids(parent_id)

    if reply_ids != [] do
      preview = truncate_preview(new_content)
      Queries.update_pm_reply_previews(parent_id, preview)

      topic = "pm:#{pm_topic(sender, recipient)}"

      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        topic,
        %{
          event: "reply_quote_updated",
          payload: %{parent_id: parent_id, new_preview: preview, reply_ids: reply_ids}
        }
      )
    end
  end

  # ── Broadcasts ──

  defp broadcast_private_message(sender, recipient, pm) do
    topic = "pm:#{pm_topic(sender, recipient)}"

    payload = %{
      sender: pm.sender_nickname,
      recipient: pm.recipient_nickname,
      content: pm.content,
      type: safe_type_atom(pm.type),
      timestamp: pm.inserted_at,
      id: pm.id,
      reply_to_id: pm.reply_to_id,
      reply_to_author: pm.reply_to_author,
      reply_to_preview: pm.reply_to_preview
    }

    case Phoenix.PubSub.broadcast(RetroHexChat.PubSub, topic, %{event: "new_pm", payload: payload}) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("PubSub broadcast to #{topic} failed: #{inspect(reason)}")
    end
  end

  defp broadcast_message(channel_name, message) do
    payload = %{
      channel: channel_name,
      author: message.author_nickname,
      content: message.content,
      type: safe_type_atom(message.type),
      timestamp: message.inserted_at,
      id: message.id,
      reply_to_id: message.reply_to_id,
      reply_to_author: message.reply_to_author,
      reply_to_preview: message.reply_to_preview
    }

    case Phoenix.PubSub.broadcast(RetroHexChat.PubSub, "channel:#{channel_name}", %{
           event: "new_message",
           payload: payload
         }) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("PubSub broadcast to channel:#{channel_name} failed: #{inspect(reason)}")
    end
  end

  defp broadcast_edit(channel_name, message) do
    Phoenix.PubSub.broadcast(
      RetroHexChat.PubSub,
      "channel:#{channel_name}",
      %{
        event: "message_edited",
        payload: %{id: message.id, content: message.content, edited_at: message.edited_at}
      }
    )
  end

  defp broadcast_pm_edit(sender, recipient, pm) do
    topic = "pm:#{pm_topic(sender, recipient)}"

    Phoenix.PubSub.broadcast(
      RetroHexChat.PubSub,
      topic,
      %{
        event: "message_edited",
        payload: %{id: pm.id, content: pm.content, edited_at: pm.edited_at}
      }
    )
  end

  defp broadcast_delete(channel_name, message) do
    Phoenix.PubSub.broadcast(
      RetroHexChat.PubSub,
      "channel:#{channel_name}",
      %{
        event: "message_deleted",
        payload: %{id: message.id, deleted_at: message.deleted_at}
      }
    )
  end

  defp broadcast_pm_delete(sender, recipient, pm) do
    topic = "pm:#{pm_topic(sender, recipient)}"

    Phoenix.PubSub.broadcast(
      RetroHexChat.PubSub,
      topic,
      %{
        event: "message_deleted",
        payload: %{id: pm.id, deleted_at: pm.deleted_at}
      }
    )
  end

  @known_types ~w(message action system service error p2p_invite)a
  @known_type_strings Enum.map(@known_types, &Atom.to_string/1)

  defp safe_type_atom(type) when type in @known_type_strings do
    String.to_existing_atom(type)
  end

  defp safe_type_atom(type), do: type

  defp pm_topic(nick_a, nick_b) do
    [nick_a, nick_b] |> Enum.sort() |> Enum.join(":")
  end
end
