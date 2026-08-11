defmodule RetroHexChat.Chat.Service do
  @moduledoc """
  Orchestrates message sending: policy check -> persist -> PubSub broadcast.
  """
  use Gettext, backend: RetroHexChat.Gettext

  require Logger

  alias RetroHexChat.Chat.{Attachments, Content, Conversation, Policy, Queries, Replies}
  alias RetroHexChat.Observability
  alias RetroHexChat.Repo
  alias RetroHexChat.Topics

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
    content_format = content_format_from_opts(opts)
    attachment_ids = attachment_ids_from_opts(opts)

    with :ok <- Content.validate_message(content, content_format, attachment_ids),
         {:ok, reply_attrs} <- resolve_reply_attrs(reply_to_id, :message),
         {:ok, message} <-
           do_insert_message(
             channel_name,
             nickname,
             content,
             content_format,
             type,
             reply_attrs,
             attachment_ids
           ) do
      Observability.set_current_span_attributes(%{"chat.message.id" => message.id})
      broadcast_message(channel_name, message)
      {:ok, message}
    end
  end

  @spec edit_message(integer(), String.t(), String.t(), keyword()) ::
          {:ok, RetroHexChat.Chat.Message.t()} | {:error, String.t()}
  def edit_message(message_id, nickname, new_content, opts \\ []) do
    requested_format = Keyword.get(opts, :content_format)

    Observability.span(
      [:retro_hex_chat, :chat, :message, :edit],
      %{
        "chat.message.id" => message_id,
        conversation_type: "channel",
        message_size_bytes: byte_size(new_content),
        content_format: requested_format || "persisted"
      },
      fn -> do_edit_message(message_id, nickname, new_content, opts) end
    )
  end

  defp do_edit_message(message_id, nickname, new_content, opts) do
    message_id |> Queries.get_message() |> do_edit(nickname, new_content, opts)
  end

  @spec edit_private_message(integer(), String.t(), String.t(), keyword()) ::
          {:ok, RetroHexChat.Chat.PrivateMessage.t()} | {:error, String.t()}
  def edit_private_message(pm_id, nickname, new_content, opts \\ []) do
    requested_format = Keyword.get(opts, :content_format)

    Observability.span(
      [:retro_hex_chat, :chat, :message, :edit],
      %{
        "chat.message.id" => pm_id,
        conversation_type: "private",
        message_size_bytes: byte_size(new_content),
        content_format: requested_format || "persisted"
      },
      fn -> do_edit_private_message(pm_id, nickname, new_content, opts) end
    )
  end

  defp do_edit_private_message(pm_id, nickname, new_content, opts) do
    pm_id |> Queries.get_private_message() |> do_edit(nickname, new_content, opts)
  end

  # Only the lookup differs between the two kinds of conversation: which table
  # the row came from is written on the row, and everything after it — the
  # format, the policy, the update, who hears about it — reads it from there.
  defp do_edit(message, nickname, new_content, opts) do
    with %{} = message <- message || {:error, dgettext("chat", "Message not found.")},
         content_format <- edit_content_format(message, opts),
         :ok <- Content.validate_message(new_content, content_format),
         :ok <- Policy.can_edit?(message, nickname),
         now <- DateTime.utc_now(),
         {:ok, updated} <-
           Queries.update_content(message, new_content, now, content_format: content_format) do
      broadcast_to_conversation(updated, "message_edited", %{
        content: updated.content,
        content_format: content_format(updated),
        edited_at: updated.edited_at
      })

      refresh_reply_previews(updated, Content.reply_preview(updated))

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
    message_id |> Queries.get_message() |> do_delete(nickname)
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
    pm_id |> Queries.get_private_message() |> do_delete(nickname)
  end

  defp do_delete(message, nickname) do
    with %{} = message <- message || {:error, dgettext("chat", "Message not found.")},
         :ok <- Policy.can_delete?(message, nickname),
         now <- DateTime.utc_now(),
         {:ok, deleted} <- Queries.soft_delete(message, now) do
      broadcast_to_conversation(deleted, "message_deleted", %{deleted_at: deleted.deleted_at})
      refresh_reply_previews(deleted, nil)
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
    content_format = content_format_from_opts(opts)
    attachment_ids = attachment_ids_from_opts(opts)

    with :ok <- Content.validate_message(content, content_format, attachment_ids),
         {:ok, reply_attrs} <- resolve_reply_attrs(reply_to_id, :pm),
         {:ok, pm} <-
           do_insert_pm(
             sender,
             recipient,
             content,
             content_format,
             type,
             reply_attrs,
             attachment_ids
           ) do
      Observability.set_current_span_attributes(%{"chat.message.id" => pm.id})
      broadcast_private_message(sender, recipient, pm)
      {:ok, pm}
    end
  end

  # ── Reply resolution ──

  defp resolve_reply_attrs(nil, _kind), do: {:ok, %{}}

  # Refuses rather than sending a message whose quote would be missing. The
  # channel runtime answers `:not_found` the other way — see `Chat.Replies`.
  defp resolve_reply_attrs(reply_to_id, kind) do
    case Replies.attrs(kind, reply_to_id) do
      {:ok, attrs} -> {:ok, attrs}
      :not_found -> {:error, dgettext("chat", "Original message not found.")}
    end
  end

  # ── Insert helpers ──

  defp do_insert_message(
         channel_name,
         nickname,
         content,
         content_format,
         type,
         reply_attrs,
         attachment_ids
       ) do
    attrs =
      Map.merge(
        %{
          channel_name: channel_name,
          author_nickname: nickname,
          content: content,
          content_format: content_format,
          type: type,
          allow_blank_content: attachment_ids != []
        },
        reply_attrs
      )

    Repo.transaction(fn ->
      attrs
      |> insert_channel_message(reply_attrs)
      |> attach_attachments(nickname, attachment_ids)
    end)
    |> normalize_insert_result()
  end

  defp do_insert_pm(sender, recipient, content, content_format, type, reply_attrs, attachment_ids) do
    attrs =
      Map.merge(
        %{
          sender_nickname: sender,
          recipient_nickname: recipient,
          content: content,
          content_format: content_format,
          type: type,
          allow_blank_content: attachment_ids != []
        },
        reply_attrs
      )

    Repo.transaction(fn ->
      attrs
      |> insert_private_message(reply_attrs)
      |> attach_attachments(sender, attachment_ids)
    end)
    |> normalize_insert_result()
  end

  defp insert_channel_message(attrs, reply_attrs) do
    if map_size(reply_attrs) > 0 do
      Queries.insert_reply_message(attrs)
    else
      Queries.insert_message(attrs)
    end
  end

  defp insert_private_message(attrs, reply_attrs) do
    if map_size(reply_attrs) > 0 do
      Queries.insert_reply_pm(attrs)
    else
      Queries.insert_private_message(attrs)
    end
  end

  defp attach_attachments({:ok, message}, owner, attachment_ids) do
    case Queries.attach(message, attachment_ids, owner) do
      {:ok, attachments} -> %{message | attachments: attachments}
      {:error, reason} -> Repo.rollback(reason)
    end
  end

  defp attach_attachments({:error, reason}, _owner, _attachment_ids) do
    Repo.rollback(reason)
  end

  defp normalize_insert_result({:ok, message}), do: {:ok, message}

  defp normalize_insert_result({:error, :attachment_not_found}) do
    {:error, dgettext("chat", "Attachment could not be attached to the message")}
  end

  defp normalize_insert_result({:error, reason}), do: {:error, reason}

  # ── Reply preview updates ──

  # A message that was edited and one that was deleted refresh the quotes of
  # their replies the same way; deleting is refreshing to no preview at all.
  defp refresh_reply_previews(parent, preview) do
    case Queries.reply_ids(parent) do
      [] ->
        :ok

      reply_ids ->
        Queries.update_reply_previews(parent, preview)

        broadcast(Conversation.topics(parent), %{
          event: "reply_quote_updated",
          payload: %{parent_id: parent.id, new_preview: preview, reply_ids: reply_ids}
        })
    end
  end

  # ── Broadcasts ──

  # A private conversation has no join, so it has no topic of its own that both
  # people are reliably on: the conversation is created by its first message,
  # and the reader would have to be listening before it existed. Each person's
  # inbox is what a channel's topic is for a channel — always subscribed — so
  # the message is addressed to the two of them, once each.
  #
  # The copies differ only in who the other person is and which way the message
  # went, which is exactly what a reader needs to file it without asking who it
  # is again.
  defp broadcast_private_message(sender, recipient, pm) do
    payload = %{
      sender: pm.sender_nickname,
      recipient: pm.recipient_nickname,
      content: pm.content,
      content_format: content_format(pm),
      type: safe_type_atom(pm.type),
      timestamp: pm.inserted_at,
      id: pm.id,
      reply_to_id: pm.reply_to_id,
      reply_to_author: pm.reply_to_author,
      reply_to_preview: pm.reply_to_preview,
      attachments: Attachments.payloads(pm)
    }

    Observability.span(
      [:retro_hex_chat, :chat, :message, :broadcast],
      broadcast_metadata(:private, payload.type, "new_pm", pm.id),
      fn ->
        [{sender, recipient, :outgoing}, {recipient, sender, :incoming}]
        |> Enum.map(fn {nickname, peer, direction} ->
          deliver_private(nickname, Map.merge(payload, %{peer: peer, direction: direction}))
        end)
        |> Enum.find(:ok, &match?({:error, _reason}, &1))
      end
    )
  end

  defp deliver_private(nickname, payload) do
    case Phoenix.PubSub.broadcast(RetroHexChat.PubSub, Topics.inbox(nickname), %{
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

  defp broadcast_message(channel_name, message) do
    payload = %{
      channel: channel_name,
      author: message.author_nickname,
      content: message.content,
      content_format: content_format(message),
      type: safe_type_atom(message.type),
      timestamp: message.inserted_at,
      id: message.id,
      reply_to_id: message.reply_to_id,
      reply_to_author: message.reply_to_author,
      reply_to_preview: message.reply_to_preview,
      attachments: Attachments.payloads(message)
    }

    Observability.span(
      [:retro_hex_chat, :chat, :message, :broadcast],
      broadcast_metadata(:channel, payload.type, "new_message", message.id, %{
        "chat.channel" => channel_name
      }),
      fn ->
        case Phoenix.PubSub.broadcast(RetroHexChat.PubSub, Topics.channel(channel_name), %{
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

  # What happened to a message reaches whoever is in the conversation it was
  # written in, and says which conversation that was — a channel names itself, a
  # private one names a participant, and a reader tells them apart by that.
  defp broadcast_to_conversation(message, event, payload) do
    broadcast(Conversation.topics(message), %{
      event: event,
      payload:
        payload
        |> Map.put(:id, message.id)
        |> Map.merge(Conversation.address(message))
    })
  end

  defp broadcast(topics, message) do
    Enum.each(topics, &Phoenix.PubSub.broadcast(RetroHexChat.PubSub, &1, message))
  end

  @known_types ~w(message action system service error notice p2p_invite p2p_system)a
  @type_string_to_atom Map.new(@known_types, fn a -> {Atom.to_string(a), a} end)

  defp safe_type_atom(type) when is_binary(type) do
    Map.get(@type_string_to_atom, type, type)
  end

  defp safe_type_atom(type), do: type

  defp content_format_from_opts(opts) do
    opts
    |> Keyword.get(:content_format, "irc")
    |> normalize_content_format()
  end

  defp attachment_ids_from_opts(opts) do
    opts
    |> Keyword.get(:attachment_ids, [])
    |> List.wrap()
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_content_format(format) do
    case Content.normalize_format(format) do
      {:ok, normalized} -> Atom.to_string(normalized)
      :error -> format
    end
  end

  defp content_format(%{content_format: content_format}) when is_binary(content_format),
    do: content_format

  defp content_format(_message), do: "irc"

  defp edit_content_format(message, opts) do
    opts
    |> Keyword.get(:content_format, content_format(message))
    |> normalize_content_format()
  end

  defp message_metadata(conversation_type, type, content, opts, extra) do
    Map.merge(
      %{
        conversation_type: Atom.to_string(conversation_type),
        message_type: normalize_message_type(type),
        message_size_bytes: byte_size(content),
        content_format: content_format_from_opts(opts),
        has_reply: Keyword.has_key?(opts, :reply_to_id),
        has_attachments: attachment_ids_from_opts(opts) != []
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
