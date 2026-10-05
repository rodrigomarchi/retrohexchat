defmodule RetroHexChat.Chat.Archive do
  @moduledoc """
  The part of a channel that a channel agreed to publish.

  Everything a group knows currently dies inside the room it was said in. That
  is the complaint people make about the closed chats, and it is also why
  nobody new ever arrives on their own: there is nothing to find. A channel
  that opts in gets a page per day, plain text, that a search engine can read.

  **Nothing said before the switch is ever published.** `archive_since` records
  the instant somebody agreed, and every query here starts from it. The people
  who spoke before that wrote into a room, not onto the internet, and no later
  decision by an operator can reach back and change what they agreed to. This
  is the one rule in the module that is not a convenience.

  Three more follow from the same idea. Deleted lines are absent, because a
  deletion is a person withdrawing what they said. System, service and notice
  lines are absent, because nobody meant them as speech. And what is published
  is the **visible text**, never the stored source: a page that printed the
  wire format would print a colour code's digits at the reader.

  Turning the switch off unpublishes. There is no "it is already on the
  internet, what can we do" here — the day index empties and every page stops
  answering, because the flag is read on the way in rather than baked into
  something generated once.
  """

  import Ecto.Query

  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Channels.Modes
  alias RetroHexChat.Chat.Attachment
  alias RetroHexChat.Chat.Message
  alias RetroHexChat.Page
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.RegisteredChannel

  # The two things a person can mean to say. Everything else in the table is
  # the room talking about itself.
  @publishable_types ~w(message action)

  # Lines per page of a day. A news room passes two thousand a day, and a page
  # of two thousand is one nobody reads to the end.
  @page_size 200

  @typedoc "One published line, as a page renders it."
  @type entry :: %{
          id: integer(),
          author: String.t(),
          text: String.t(),
          at: DateTime.t(),
          action?: boolean(),
          edited?: boolean(),
          attachment?: boolean()
        }

  @typedoc "One page of a day, and the way back to the page before it."
  @type day_page :: %{page: Page.t(), previous: nil | :start | integer()}

  @doc """
  Starts publishing `channel_name` from this instant on.

  Publishing again does not move the instant: the second press is the same
  decision as the first, and moving it would quietly unpublish everything
  between them.
  """
  @spec publish(String.t()) :: {:ok, RegisteredChannel.t()} | {:error, String.t()}
  def publish(channel_name) do
    with {:ok, channel} <- registered(channel_name),
         :ok <- check_publishable(channel) do
      if channel.public_archive and channel.archive_since do
        {:ok, channel}
      else
        save(channel, %{public_archive: true, archive_since: DateTime.utc_now()})
      end
    end
  end

  @doc """
  Stops publishing `channel_name`.

  `archive_since` is kept rather than cleared: turning the archive back on
  later must not publish the stretch it was off for, and the instant is the
  only record of what was ever agreed to.
  """
  @spec unpublish(String.t()) :: {:ok, RegisteredChannel.t()} | {:error, String.t()}
  def unpublish(channel_name) do
    with {:ok, channel} <- registered(channel_name) do
      save(channel, %{public_archive: false})
    end
  end

  @doc "Whether anything of `channel_name` may be read from outside."
  @spec published?(String.t()) :: boolean()
  def published?(channel_name) do
    case registered(channel_name) do
      {:ok, channel} -> publishing?(channel)
      {:error, _reason} -> false
    end
  end

  @doc """
  The days of `channel_name` that have something to show, newest first.

  Dates rather than timestamps, because the day is the unit: it is what a
  search engine can index and what a person can link to.
  """
  @spec days_for(String.t()) :: [String.t()]
  def days_for(channel_name) do
    case publishing_channel(channel_name) do
      nil ->
        []

      channel ->
        channel
        |> publishable_messages()
        |> select([m], fragment("date(? at time zone 'UTC')", m.inserted_at))
        |> distinct(true)
        |> order_by([m], desc: fragment("date(? at time zone 'UTC')", m.inserted_at))
        |> Repo.all()
        |> Enum.map(&Date.to_iso8601/1)
    end
  end

  @doc """
  One page of what `channel_name` said on `date`, oldest first.

  `date` is an ISO-8601 day. A busy channel says thousands of lines in one, so
  a day is read in pages of `:limit` lines (#{@page_size} unless given), each
  starting after the line id in `:after`. An id is a cursor that stays put:
  deleting a line removes it from its page without shifting every later line
  onto a different URL, which page numbers would do.

  `previous` is how to reach the page before this one: `nil` on the first page,
  `:start` when the previous page is the first, otherwise the `:after` that
  opens it.

  A day nobody can read, a day with nothing in it, and an `:after` that is not
  a line of that day all answer an empty page rather than an error. The last
  one matters: an id from another day would otherwise serve the first page of
  this one under a second address.
  """
  @spec page_for(String.t(), String.t() | Date.t(), keyword()) :: day_page()
  def page_for(channel_name, date, opts \\ []) do
    limit = Keyword.get(opts, :limit, @page_size)
    cursor = Keyword.get(opts, :after)

    with channel when not is_nil(channel) <- publishing_channel(channel_name),
         {:ok, day} <- to_date(date),
         query = day_messages(channel, day),
         :ok <- check_cursor(channel, day, cursor) do
      page =
        query
        |> maybe_after(cursor)
        |> from(as: :message)
        |> order_by([m], asc: m.id)
        |> limit(^Page.limit_with_lookahead(limit))
        |> select([m], %{
          id: m.id,
          author: m.author_nickname,
          content: m.content,
          plain_content: m.plain_content,
          type: m.type,
          edited_at: m.edited_at,
          at: m.inserted_at,
          attachment?:
            exists(
              from(a in Attachment, where: parent_as(:message).id == a.message_id, select: 1)
            )
        })
        |> Repo.all()
        |> Page.new(limit, & &1.id)
        |> Page.map(&entry/1)

      %{page: page, previous: previous(query, cursor, limit)}
    else
      _ -> %{page: Page.empty(), previous: nil}
    end
  end

  @doc """
  Every channel with a page worth offering, in name order.

  A channel that switched the archive on and has said nothing since is not
  offered: a sitemap entry for an empty page is a promise the page cannot keep.
  """
  @spec published_channels() :: [String.t()]
  def published_channels do
    RegisteredChannel
    |> where([c], c.public_archive == true and not is_nil(c.archive_since))
    |> order_by([c], asc: c.name)
    |> Repo.all()
    |> Enum.filter(&Repo.exists?(publishable_messages(&1)))
    |> Enum.map(& &1.name)
  end

  @doc "The channel row, when it exists and is publishing; otherwise nil."
  @spec publishing_channel(String.t()) :: RegisteredChannel.t() | nil
  def publishing_channel(channel_name) when is_binary(channel_name) do
    case registered(channel_name) do
      {:ok, channel} -> if publishing?(channel), do: channel, else: nil
      {:error, _reason} -> nil
    end
  end

  def publishing_channel(_channel_name), do: nil

  # The one query every read shares. Both halves of it are the feature: the
  # cutoff, and what counts as somebody speaking.
  @spec publishable_messages(RegisteredChannel.t()) :: Ecto.Query.t()
  defp publishable_messages(channel) do
    Message
    |> where([m], m.channel_name == ^channel.name)
    |> where([m], m.inserted_at >= ^channel.archive_since)
    |> where([m], is_nil(m.deleted_at))
    |> where([m], m.type in @publishable_types)
  end

  @spec day_messages(RegisteredChannel.t(), Date.t()) :: Ecto.Query.t()
  defp day_messages(channel, day) do
    channel
    |> publishable_messages()
    |> where([m], fragment("date(? at time zone 'UTC')", m.inserted_at) == ^day)
  end

  # A cursor is any line said in this channel on this day — deleted, or a
  # notice, included. A page's address names the line it follows, and that
  # line being withdrawn later must not take the page after it down with it.
  @spec check_cursor(RegisteredChannel.t(), Date.t(), term()) :: :ok | :error
  defp check_cursor(_channel, _day, nil), do: :ok

  defp check_cursor(channel, day, cursor) when is_integer(cursor) do
    said_that_day =
      Message
      |> where([m], m.channel_name == ^channel.name and m.id == ^cursor)
      |> where([m], fragment("date(? at time zone 'UTC')", m.inserted_at) == ^day)

    if Repo.exists?(said_that_day), do: :ok, else: :error
  end

  defp check_cursor(_channel, _day, _cursor), do: :error

  defp maybe_after(query, nil), do: query
  defp maybe_after(query, cursor), do: where(query, [m], m.id > ^cursor)

  # The page before this one is the `limit` lines that precede its first line,
  # and it opens after the line before those. Fewer than a page's worth behind
  # means the previous page is the first, which has no cursor at all.
  @spec previous(Ecto.Query.t(), integer() | nil, pos_integer()) :: nil | :start | integer()
  defp previous(_query, nil, _limit), do: nil

  defp previous(query, cursor, limit) do
    behind =
      query
      |> where([m], m.id <= ^cursor)
      |> order_by([m], desc: m.id)
      |> limit(^Page.limit_with_lookahead(limit))
      |> select([m], m.id)
      |> Repo.all()

    case Enum.at(behind, limit) do
      nil -> :start
      id -> id
    end
  end

  @spec publishing?(RegisteredChannel.t()) :: boolean()
  defp publishing?(channel) do
    channel.public_archive and not is_nil(channel.archive_since) and publishable?(channel)
  end

  # A secret channel's whole mode is that its existence is not advertised, so
  # the switch cannot mean anything on one. Checked on the way out as well as
  # on the way in: a channel can be made secret after it was published.
  @spec publishable?(RegisteredChannel.t()) :: boolean()
  defp publishable?(channel) do
    not Modes.secret?(Modes.from_string(channel.modes || ""))
  end

  @spec check_publishable(RegisteredChannel.t()) :: :ok | {:error, String.t()}
  defp check_publishable(channel) do
    if publishable?(channel) do
      :ok
    else
      {:error, dgettext("chat", "A secret channel cannot have a public archive.")}
    end
  end

  @spec registered(String.t()) :: {:ok, RegisteredChannel.t()} | {:error, String.t()}
  defp registered(channel_name) when is_binary(channel_name) do
    case Repo.get_by(RegisteredChannel, name: channel_name) do
      nil -> {:error, dgettext("chat", "That channel is not registered.")}
      channel -> {:ok, channel}
    end
  end

  defp registered(_channel_name),
    do: {:error, dgettext("chat", "That channel is not registered.")}

  @spec save(RegisteredChannel.t(), map()) ::
          {:ok, RegisteredChannel.t()} | {:error, String.t()}
  defp save(channel, attrs) do
    channel
    |> Ecto.Changeset.change(attrs)
    |> Repo.update()
    |> case do
      {:ok, updated} -> {:ok, updated}
      {:error, _changeset} -> {:error, dgettext("chat", "That change could not be saved.")}
    end
  end

  @spec entry(map()) :: entry()
  defp entry(row) do
    %{
      id: row.id,
      author: row.author,
      text: row.plain_content || row.content || "",
      at: row.at,
      action?: row.type == "action",
      edited?: not is_nil(row.edited_at),
      attachment?: row.attachment?
    }
  end

  @spec to_date(String.t() | Date.t()) :: {:ok, Date.t()} | :error
  defp to_date(%Date{} = date), do: {:ok, date}
  # Only the canonical spelling of a day: `Date.from_iso8601/1` also reads
  # "+2026-10-05", and a second address for the same page is a duplicate.
  defp to_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> if Date.to_iso8601(date) == value, do: {:ok, date}, else: :error
      error -> error
    end
  end

  defp to_date(_value), do: :error
end
