defmodule RetroHexChatWeb.ChatLive.StreamItem do
  @moduledoc """
  The row a conversation puts on screen, built the same way whatever kind of
  conversation it came from.

  A channel message and a private message land in the same stream and render
  through the same `MessageRow`, which never asks which it is looking at. What
  reaches that row therefore has to be one shape, and building it in one place
  is what keeps it one shape: a field added for channels used to be a field
  private messages silently went without.

  Only three things genuinely differ, and they are all about where a value is
  read from rather than what it means — who wrote it, when, and under which id.
  Either kind can arrive straight from the database or from a broadcast that
  spelled the same field differently, so the readers try each spelling in turn.

  A field the source does not carry is left out rather than written as `nil`,
  because the row distinguishes absent from empty: a message with no reply is
  not a message replying to nothing.
  """

  alias RetroHexChat.Chat.Attachments
  alias RetroHexChatWeb.ChatLive.Helpers.Messages

  @optional_fields [
    :reply_to_id,
    :reply_to_author,
    :reply_to_preview,
    :plain_content,
    :edited_at,
    :deleted_at
  ]

  @doc "The row for a message written in a channel."
  @spec from_message(map()) :: map()
  def from_message(message) do
    message
    |> base(
      first_present(message, [:id]),
      first_present(message, [:author, :author_nickname]),
      first_present(message, [:timestamp, :inserted_at])
    )
    |> put_optional(message)
  end

  @doc "The row for a message written in a private conversation."
  @spec from_private_message(map()) :: map()
  def from_private_message(pm) do
    pm
    |> base(
      first_present(pm, [:id]),
      first_present(pm, [:sender, :sender_nickname]),
      first_present(pm, [:timestamp, :inserted_at])
    )
    |> put_optional(pm)
  end

  defp base(source, id, author, timestamp) do
    %{
      id: id,
      author: author,
      content: source.content,
      content_format: Map.get(source, :content_format) || "irc",
      type: resolve_type(source),
      timestamp: timestamp,
      attachments: attachment_payloads(source)
    }
  end

  defp put_optional(item, source) do
    Enum.reduce(@optional_fields, item, fn key, acc ->
      case Map.get(source, key) do
        nil -> acc
        value -> Map.put(acc, key, value)
      end
    end)
  end

  defp first_present(source, keys) do
    Enum.find_value(keys, fn key -> Map.get(source, key) end)
  end

  defp resolve_type(%{type: type}), do: Messages.stream_type(type)
  defp resolve_type(_source), do: :message

  defp attachment_payloads(%{attachments: %Ecto.Association.NotLoaded{}}), do: []

  defp attachment_payloads(%{attachments: attachments}) when is_list(attachments) do
    attachments
    |> Enum.map(&attachment_payload/1)
    |> Enum.reject(&is_nil/1)
  end

  defp attachment_payloads(_source), do: []

  defp attachment_payload(%{file: %Ecto.Association.NotLoaded{}}), do: nil

  defp attachment_payload(%{file: file} = attachment) do
    Attachments.payload(%{attachment | file: file})
  end

  defp attachment_payload(%{id: _id} = attachment), do: attachment
end
