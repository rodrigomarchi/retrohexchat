defmodule RetroHexChat.Chat.Service do
  @moduledoc """
  Orchestrates message sending: policy check -> persist -> PubSub broadcast.
  """
  use Gettext, backend: RetroHexChat.Gettext

  require Logger

  alias RetroHexChat.Chat.{Policy, Queries}
  alias RetroHexChat.Observability

  @max_preview_length 100

  @spec send_message(String.t(), String.t(), String.t(), String.t(), keyword()) ::
          {:ok, RetroHexChat.Chat.Message.t()} | {:error, String.t()}
  def send_message(channel_name, nickname, content, type \\ "message", opts \\ []) do
    Observability.span(
      [:retro_hex_chat, :chat, :message, :send],
      message_metadata(:channel, type, content, opts, %{"chat.channel" => channel_name}),
      fn -> do_send_message(channel_name, nickname, content, type, opts) end
    )
  end

  defp do_send_message(channel_name, nickname, content, type, opts) do
    reply_to_id = Keyword.get(opts, :reply_to_id)

    with :ok <- Policy.validate_content(content),
         {:ok, reply_attrs} <- resolve_reply_attrs(reply_to_id, :message),
         {:ok, message} <- do_insert_message(channel_name, nickname, content, type, reply_attrs) do
      Observability.set_current_span_attributes(%{"chat.message.id" => message.id})
      broadcast_message(channel_name, message)
      {:ok, message}
    end
  end

  @spec edit_message(integer(), String.t(), String.t()) ::
          {:ok, RetroHexChat.Chat.Message.t()} | {:error, String.t()}
  def edit_message(message_id, nickname, new_content) do
    Observability.span(
      [:retro_hex_chat, :chat, :message, :edit],
      %{
        "chat.message.id" => message_id,
        conversation_type: "channel",
        message_size_bytes: byte_size(new_content)
      },
      fn -> do_edit_message(message_id, nickname, new_content) end
    )
  end

  defp do_edit_message(message_id, nickname, new_content) do
    with :ok <- Policy.validate_content(new_content),
         %{} = message <-
           Queries.get_message(message_id) || {:error, dgettext("chat", "Message not found.")},
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
    Observability.span(
      [:retro_hex_chat, :chat, :message, :edit],
      %{
        "chat.message.id" => pm_id,
        conversation_type: "private",
        message_size_bytes: byte_size(new_content)
      },
      fn -> do_edit_private_message(pm_id, nickname, new_content) end
    )
  end

  defp do_edit_private_message(pm_id, nickname, new_content) do
    with :ok <- Policy.validate_content(new_content),
         %{} = pm <-
           Queries.get_private_message(pm_id) || {:error, dgettext("chat", "Message not found.")},
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
    Observability.span(
      [:retro_hex_chat, :chat, :message, :delete],
      %{"chat.message.id" => message_id, conversation_type: "channel"},
      fn -> do_delete_message(message_id, nickname) end
    )
  end

  defp do_delete_message(message_id, nickname) do
    with %{} = message <-
           Queries.get_message(message_id) || {:error, dgettext("chat", "Message not found.")},
         :ok <- Policy.can_delete?(message, nickname),
         now <- DateTime.utc_now(),
         {:ok, deleted} <- Queries.soft_delete_message(message, now) do
      broadcast_delete(message.channel_name, deleted)
      clear_reply_previews_if_needed(message.id, message.channel_name)
      {:ok, deleted}
    end
  end

  @spec delete_private_message(integer(), String.t()) ::
          {:ok, RetroHexChat.Chat.PrivateMessage.t()} | {:error, String.t()}
  def delete_private_message(pm_id, nickname) do
    Observability.span(
      [:retro_hex_chat, :chat, :message, :delete],
      %{"chat.message.id" => pm_id, conversation_type: "private"},
      fn -> do_delete_private_message(pm_id, nickname) end
    )
  end

  defp do_delete_private_message(pm_id, nickname) do
    with %{} = pm <-
           Queries.get_private_message(pm_id) || {:error, dgettext("chat", "Message not found.")},
         :ok <- Policy.can_delete?(Map.put(pm, :author_nickname, pm.sender_nickname), nickname),
         now <- DateTime.utc_now(),
         {:ok, deleted} <- Queries.soft_delete_pm(pm, now) do
      broadcast_pm_delete(pm.sender_nickname, pm.recipient_nickname, deleted)
      clear_pm_reply_previews_if_needed(pm.id, pm.sender_nickname, pm.recipient_nickname)
      {:ok, deleted}
    end
  end

  @spec send_system_message(String.t(), String.t()) ::
          {:ok, RetroHexChat.Chat.Message.t()} | {:error, any()}
  def send_system_message(channel_name, content) do
    Observability.span(
      [:retro_hex_chat, :chat, :message, :send],
      message_metadata(:channel, "system", content, [], %{"chat.channel" => channel_name}),
      fn -> do_send_system_message(channel_name, content) end
    )
  end

  defp do_send_system_message(channel_name, content) do
    case Queries.insert_message(%{
           channel_name: channel_name,
           author_nickname: dgettext("chat", "System"),
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
    Observability.span(
      [:retro_hex_chat, :chat, :message, :send],
      message_metadata(:private, type, content, opts, %{}),
      fn -> do_send_private_message(sender, recipient, content, type, opts) end
    )
  end

  defp do_send_private_message(sender, recipient, content, type, opts) do
    reply_to_id = Keyword.get(opts, :reply_to_id)

    with :ok <- Policy.validate_content(content),
         {:ok, reply_attrs} <- resolve_reply_attrs(reply_to_id, :pm),
         {:ok, pm} <- do_insert_pm(sender, recipient, content, type, reply_attrs) do
      Observability.set_current_span_attributes(%{"chat.message.id" => pm.id})
      broadcast_private_message(sender, recipient, pm)
      broadcast_private_activity(sender, recipient, pm)
      {:ok, pm}
    end
  end

  # ── Reply resolution ──

  defp resolve_reply_attrs(nil, _kind), do: {:ok, %{}}

  defp resolve_reply_attrs(reply_to_id, :message) do
    case Queries.get_message(reply_to_id) do
      nil ->
        {:error, dgettext("chat", "Original message not found.")}

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
        {:error, dgettext("chat", "Original message not found.")}

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

  defp clear_reply_previews_if_needed(parent_id, channel_name) do
    reply_ids = Queries.get_reply_ids(parent_id)

    if reply_ids != [] do
      Queries.update_reply_previews(parent_id, nil)

      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        "channel:#{channel_name}",
        %{
          event: "reply_quote_updated",
          payload: %{parent_id: parent_id, new_preview: nil, reply_ids: reply_ids}
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

  defp clear_pm_reply_previews_if_needed(parent_id, sender, recipient) do
    reply_ids = Queries.get_pm_reply_ids(parent_id)

    if reply_ids != [] do
      Queries.update_pm_reply_previews(parent_id, nil)

      topic = "pm:#{pm_topic(sender, recipient)}"

      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        topic,
        %{
          event: "reply_quote_updated",
          payload: %{parent_id: parent_id, new_preview: nil, reply_ids: reply_ids}
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

    Observability.span(
      [:retro_hex_chat, :chat, :message, :broadcast],
      broadcast_metadata(:private, payload.type, "new_pm", pm.id),
      fn ->
        case Phoenix.PubSub.broadcast(RetroHexChat.PubSub, topic, %{
               event: "new_pm",
               payload: payload
             }) do
          :ok ->
            :ok

          {:error, reason} ->
            Logger.warning("PubSub broadcast for private message failed: #{inspect(reason)}")
            {:error, reason}
        end
      end
    )
  end

  defp broadcast_private_activity(sender, recipient, pm) do
    timestamp = pm.inserted_at
    type = safe_type_atom(pm.type)

    broadcast_user_pm_activity(sender, %{
      peer: recipient,
      message_id: pm.id,
      type: type,
      timestamp: timestamp,
      direction: :outgoing
    })

    broadcast_user_pm_activity(recipient, %{
      peer: sender,
      message_id: pm.id,
      type: type,
      timestamp: timestamp,
      direction: :incoming
    })
  end

  defp broadcast_user_pm_activity(nickname, payload) do
    topic = "user:#{nickname}"

    Observability.span(
      [:retro_hex_chat, :chat, :message, :broadcast],
      broadcast_metadata(
        :private,
        Map.get(payload, :type),
        "pm_activity",
        Map.get(payload, :message_id)
      ),
      fn ->
        case Phoenix.PubSub.broadcast(RetroHexChat.PubSub, topic, {:pm_activity, payload}) do
          :ok ->
            :ok

          {:error, reason} ->
            Logger.warning(
              "PubSub broadcast for private message activity failed: #{inspect(reason)}"
            )

            {:error, reason}
        end
      end
    )
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

    Observability.span(
      [:retro_hex_chat, :chat, :message, :broadcast],
      broadcast_metadata(:channel, payload.type, "new_message", message.id, %{
        "chat.channel" => channel_name
      }),
      fn ->
        case Phoenix.PubSub.broadcast(RetroHexChat.PubSub, "channel:#{channel_name}", %{
               event: "new_message",
               payload: payload
             }) do
          :ok ->
            :ok

          {:error, reason} ->
            Logger.warning(
              "PubSub broadcast to channel:#{channel_name} failed: #{inspect(reason)}"
            )

            {:error, reason}
        end
      end
    )
  end

  defp broadcast_edit(channel_name, message) do
    Phoenix.PubSub.broadcast(
      RetroHexChat.PubSub,
      "channel:#{channel_name}",
      %{
        event: "message_edited",
        payload: %{
          id: message.id,
          content: message.content,
          edited_at: message.edited_at,
          channel: channel_name
        }
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
        payload: %{
          id: pm.id,
          content: pm.content,
          edited_at: pm.edited_at,
          sender: sender
        }
      }
    )
  end

  defp broadcast_delete(channel_name, message) do
    Phoenix.PubSub.broadcast(
      RetroHexChat.PubSub,
      "channel:#{channel_name}",
      %{
        event: "message_deleted",
        payload: %{id: message.id, deleted_at: message.deleted_at, channel: channel_name}
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
        payload: %{id: pm.id, deleted_at: pm.deleted_at, sender: sender}
      }
    )
  end

  @known_types ~w(message action system service error notice p2p_invite p2p_system)a
  @type_string_to_atom Map.new(@known_types, fn a -> {Atom.to_string(a), a} end)

  defp safe_type_atom(type) when is_binary(type) do
    Map.get(@type_string_to_atom, type, type)
  end

  defp safe_type_atom(type), do: type

  defp pm_topic(nick_a, nick_b) do
    [nick_a, nick_b] |> Enum.sort() |> Enum.join(":")
  end

  defp message_metadata(conversation_type, type, content, opts, extra) do
    Map.merge(
      %{
        conversation_type: Atom.to_string(conversation_type),
        message_type: normalize_message_type(type),
        message_size_bytes: byte_size(content),
        has_reply: Keyword.has_key?(opts, :reply_to_id)
      },
      extra
    )
  end

  defp broadcast_metadata(conversation_type, type, event, message_id, extra \\ %{}) do
    Map.merge(
      %{
        "chat.message.id" => message_id,
        conversation_type: Atom.to_string(conversation_type),
        message_type: normalize_message_type(type),
        event: event
      },
      extra
    )
  end

  defp normalize_message_type(type) when is_atom(type), do: Atom.to_string(type)
  defp normalize_message_type(type) when is_binary(type), do: type
  defp normalize_message_type(_type), do: "unknown"
end
