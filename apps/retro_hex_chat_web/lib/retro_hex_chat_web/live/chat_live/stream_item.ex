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
  alias RetroHexChat.Chat.Queries
  alias RetroHexChat.Chat.Reactions
  alias RetroHexChatWeb.ChatLive.Helpers.Messages

  @optional_fields [
    :reply_to_id,
    :reply_to_author,
    :reply_to_preview,
    :plain_content,
    :edited_at,
    :deleted_at,
    :reactions,
    :reply_count,
    :avatar
  ]

  @doc """
  The rows for a page of channel messages, with their reactions and reply counts.

  Built as a page rather than row by row because both of those are: asking per
  line would be a hundred queries for one screenful, and a page is the only
  place that knows it is a page.
  """
  @spec from_messages([map()]) :: [map()]
  def from_messages(messages), do: decorated(messages, :message, &from_message/1)

  @doc "The same, for a page of private messages."
  @spec from_private_messages([map()]) :: [map()]
  def from_private_messages(messages),
    do: decorated(messages, :private_message, &from_private_message/1)

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

  defp decorated([], _kind, _builder), do: []

  defp decorated(messages, kind, builder) do
    ids =
      messages
      |> Enum.map(&Map.get(&1, :id))
      |> Enum.filter(&is_integer/1)

    summaries = Reactions.summary_for_many(kind, ids)
    counts = Queries.thread_counts_for_many(kind, ids)

    Enum.map(messages, fn message ->
      id = Map.get(message, :id)

      message
      |> builder.()
      |> put_reactions(Map.get(summaries, id))
      |> put_reply_count(Map.get(counts, id))
    end)
  end

  @doc """
  Put a message's reactions on a row that was built without them.

  A row rebuilt from a single broadcast — an edit, a delete, a reaction — comes
  through `from_message/1` rather than the page path, and the strip it draws is
  keyed on this field being present.
  """
  @spec put_reactions(map(), map() | nil) :: map()
  def put_reactions(item, nil), do: item
  def put_reactions(item, summary) when map_size(summary) == 0, do: item
  def put_reactions(item, summary), do: Map.put(item, :reactions, summary)

  @doc """
  Put a message's reply count on a row that was built without it.

  Absent and nought are the same sentence — "nobody answered this" — and the
  row draws nothing for either, so a count of zero is left off rather than
  written down.
  """
  @spec put_reply_count(map(), non_neg_integer() | nil) :: map()
  def put_reply_count(item, nil), do: item
  def put_reply_count(item, 0), do: item
  def put_reply_count(item, count), do: Map.put(item, :reply_count, count)

  @doc """
  Put the author's chosen character on a row that was built without it.

  Filled by the viewport rather than here, because every row reaches the
  viewport — a page, a prepended page and a single broadcast alike — and doing
  it in one place is what stops a live message arriving without the portrait
  every other line has.

  Absent means they never chose, and the row draws nothing for that rather than
  a placeholder silhouette — a stranger's face where a person is reads worse
  than the plain text this chat is made of.
  """
  @spec put_avatar(map(), String.t() | nil) :: map()
  def put_avatar(item, nil), do: item
  def put_avatar(item, avatar), do: Map.put(item, :avatar, avatar)

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
