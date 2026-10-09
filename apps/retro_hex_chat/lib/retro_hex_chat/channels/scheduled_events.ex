defmodule RetroHexChat.Channels.ScheduledEvents do
  @moduledoc """
  Something a channel has agreed to do together, at a time.

  This is the one thing a small server has that a big one does not: a reason to
  come back on Tuesday. A channel that only exists while somebody happens to be
  typing has no next time; an event is the next time, written down where the
  whole room can see it.

  Two rules carry the feature, and both are about clocks:

  **Everything is stored in UTC and drawn in the reader's own zone.** A time is
  the one value in this product that is wrong in both directions if you pick
  either side — store a local time and the row lies to everybody who is not the
  author; render UTC and it lies to the author too. Nothing here ever formats a
  time; `Chat.TimeFormatter` and the session's zone do that, at the edge.

  **An event that has already started never reminds anybody.** A notification
  about something you can no longer get to is the product wasting the one
  interruption it is allowed.

  Cancelling keeps the row. A channel that was going to meet and then did not is
  a fact worth seeing, and deleting would take the answers people gave with it.
  """

  import Ecto.Query

  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Channels.Schemas.ChannelEvent
  alias RetroHexChat.Channels.Schemas.ChannelEventAttendee
  alias RetroHexChat.Page
  alias RetroHexChat.Repo

  @default_limit 25

  # A channel that can announce a hundred things at once is a channel nobody
  # reads. Past this the list stops being "what is coming up".
  @max_upcoming 50

  @typedoc "The event as a card draws it, with nothing a card cannot use."
  @type card :: %{
          event_id: integer(),
          title: String.t(),
          description: String.t() | nil,
          starts_at: DateTime.t(),
          surface_hint: String.t() | nil,
          cancelled?: boolean(),
          attendee_count: non_neg_integer()
        }

  @doc "How many upcoming events one channel may hold."
  @spec max_upcoming() :: pos_integer()
  def max_upcoming, do: @max_upcoming

  @doc """
  Writes down something the channel is going to do.

  Refuses a time that has already passed, because an event nobody can still get
  to is a row that only ever produces a wrong reminder.
  """
  @spec create(String.t(), String.t(), map()) :: {:ok, ChannelEvent.t()} | {:error, String.t()}
  def create(channel_name, created_by, attrs) do
    with :ok <- future?(Map.get(attrs, :starts_at)),
         :ok <- room_left?(channel_name) do
      %ChannelEvent{}
      |> ChannelEvent.changeset(
        attrs
        |> Map.take([:title, :description, :starts_at, :surface_hint])
        |> Map.merge(%{channel_name: channel_name, created_by: created_by})
      )
      |> Repo.insert()
      |> case do
        {:ok, event} -> {:ok, event}
        {:error, changeset} -> {:error, first_error(changeset)}
      end
    end
  end

  @doc "One page of what a channel has coming up, soonest first."
  @spec list(String.t(), keyword()) :: Page.t()
  def list(channel_name, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)

    ChannelEvent
    |> where([e], e.channel_name == ^channel_name)
    |> where([e], is_nil(e.cancelled_at))
    |> maybe_after(Keyword.get(opts, :cursor))
    |> order_by([e], asc: e.starts_at, asc: e.id)
    |> limit(^Page.limit_with_lookahead(limit))
    |> Repo.all()
    |> with_attendee_counts()
    |> Page.new(limit, &{&1.starts_at, &1.id})
  end

  @doc "One event, cancelled or not, or nil."
  @spec get(integer()) :: ChannelEvent.t() | nil
  def get(id), do: Repo.get(ChannelEvent, id)

  @doc "Stops an event from happening, keeping the record that it was going to."
  @spec cancel(integer(), String.t()) :: {:ok, ChannelEvent.t()} | {:error, String.t()}
  def cancel(id, nickname) do
    case get(id) do
      nil ->
        {:error, dgettext("channels", "That event could not be found.")}

      %ChannelEvent{created_by: ^nickname} = event ->
        event
        |> ChannelEvent.cancel_changeset(DateTime.utc_now())
        |> Repo.update()
        |> case do
          {:ok, cancelled} -> {:ok, cancelled}
          {:error, changeset} -> {:error, first_error(changeset)}
        end

      %ChannelEvent{} ->
        {:error, dgettext("channels", "Only whoever scheduled it can call it off.")}
    end
  end

  @doc """
  Records that somebody will be there.

  Saying it twice is saying it once: the caller is a person pressing a button,
  and the honest answer to "you already said that" is yes.
  """
  @spec attend(integer(), String.t()) :: :ok | {:error, String.t()}
  def attend(id, nickname) do
    case get(id) do
      nil ->
        {:error, dgettext("channels", "That event could not be found.")}

      %ChannelEvent{cancelled_at: nil} = event ->
        %ChannelEventAttendee{}
        |> ChannelEventAttendee.changeset(%{event_id: event.id, nickname: nickname})
        |> Repo.insert(
          on_conflict: :nothing,
          conflict_target: {:unsafe_fragment, "(event_id, lower(nickname))"}
        )
        |> case do
          {:ok, _row} -> :ok
          {:error, changeset} -> {:error, first_error(changeset)}
        end

      %ChannelEvent{} ->
        {:error, dgettext("channels", "That event was called off.")}
    end
  end

  @doc "Takes somebody back off the list, and says nothing about one who was never on it."
  @spec unattend(integer(), String.t()) :: :ok
  def unattend(id, nickname) do
    ChannelEventAttendee
    |> where([a], a.event_id == ^id and a.nickname == ^nickname)
    |> Repo.delete_all()

    :ok
  end

  @doc "Whether this person said they would be there."
  @spec attending?(integer(), String.t()) :: boolean()
  def attending?(id, nickname) do
    ChannelEventAttendee
    |> where([a], a.event_id == ^id and a.nickname == ^nickname)
    |> Repo.exists?()
  end

  @doc """
  Which of these events one person already said they would be at, in one query.

  The card draws a pressed button for the reader's own answer, and a page can
  carry several cards — asking per card is the shape that turns one screenful
  into a query a row.
  """
  @spec attending_many(String.t(), [integer()]) :: MapSet.t()
  def attending_many(_nickname, []), do: MapSet.new()

  def attending_many(nickname, event_ids) do
    ChannelEventAttendee
    |> where([a], a.nickname == ^nickname and a.event_id in ^event_ids)
    |> select([a], a.event_id)
    |> Repo.all()
    |> MapSet.new()
  end

  @doc "Who said they would be there, in the order they said it."
  @spec attendees(integer()) :: [String.t()]
  def attendees(id) do
    ChannelEventAttendee
    |> where([a], a.event_id == ^id)
    |> order_by([a], asc: a.id)
    |> select([a], a.nickname)
    |> Repo.all()
  end

  @doc """
  The events starting inside the next `window_seconds` that nobody has been told about.

  The lower bound is `now`, which is the whole point: something that has already
  started is not something to remind anybody about.
  """
  @spec due_for_reminder(DateTime.t(), pos_integer()) :: [ChannelEvent.t()]
  def due_for_reminder(%DateTime{} = now, window_seconds) do
    horizon = DateTime.add(now, window_seconds, :second)

    ChannelEvent
    |> where([e], is_nil(e.cancelled_at))
    |> where([e], is_nil(e.reminded_at))
    |> where([e], e.starts_at >= ^now and e.starts_at <= ^horizon)
    |> order_by([e], asc: e.starts_at)
    |> Repo.all()
  end

  @doc "Marks these events as told, so the next sweep leaves them alone."
  @spec mark_reminded([integer()], DateTime.t()) :: {non_neg_integer(), nil}
  def mark_reminded([], _at), do: {0, nil}

  def mark_reminded(ids, %DateTime{} = at) do
    ChannelEvent
    |> where([e], e.id in ^ids)
    |> Repo.update_all(set: [reminded_at: at])
  end

  @doc "Points an event at the line the channel got when it was announced."
  @spec attach_announcement(ChannelEvent.t(), integer()) ::
          {:ok, ChannelEvent.t()} | {:error, String.t()}
  def attach_announcement(%ChannelEvent{} = event, message_id) do
    event
    |> ChannelEvent.announcement_changeset(message_id)
    |> Repo.update()
    |> case do
      {:ok, updated} -> {:ok, updated}
      {:error, changeset} -> {:error, first_error(changeset)}
    end
  end

  @doc """
  The cards for a page of messages, keyed by the message that announced each.

  Asked for the page rather than the row for the same reason the reactions are:
  a screenful is fifty lines and a card that costs a query a line costs fifty.
  """
  @spec cards_for_messages([integer()]) :: %{integer() => card()}
  def cards_for_messages([]), do: %{}

  def cards_for_messages(message_ids) do
    ChannelEvent
    |> where([e], e.announcement_message_id in ^message_ids)
    |> Repo.all()
    |> with_attendee_counts()
    |> Map.new(&{&1.announcement_message_id, card(&1)})
  end

  @doc "The event as a card draws it."
  @spec card(ChannelEvent.t()) :: card()
  def card(%ChannelEvent{} = event) do
    %{
      event_id: event.id,
      title: event.title,
      description: event.description,
      starts_at: event.starts_at,
      surface_hint: event.surface_hint,
      cancelled?: not is_nil(event.cancelled_at),
      attendee_count: Map.get(event, :attendee_count) || 0
    }
  end

  # One query for the counts of a whole list, in the shape the reactions use.
  @spec with_attendee_counts([ChannelEvent.t()]) :: [ChannelEvent.t()]
  defp with_attendee_counts([]), do: []

  defp with_attendee_counts(events) do
    ids = Enum.map(events, & &1.id)

    counts =
      ChannelEventAttendee
      |> where([a], a.event_id in ^ids)
      |> group_by([a], a.event_id)
      |> select([a], {a.event_id, count(a.id)})
      |> Repo.all()
      |> Map.new()

    Enum.map(events, &Map.put(&1, :attendee_count, Map.get(counts, &1.id, 0)))
  end

  @spec future?(term()) :: :ok | {:error, String.t()}
  defp future?(%DateTime{} = starts_at) do
    if DateTime.compare(starts_at, DateTime.utc_now()) == :gt do
      :ok
    else
      {:error, dgettext("channels", "That time is already in the past.")}
    end
  end

  defp future?(_other), do: {:error, dgettext("channels", "When does it start?")}

  @spec room_left?(String.t()) :: :ok | {:error, String.t()}
  defp room_left?(channel_name) do
    count =
      ChannelEvent
      |> where([e], e.channel_name == ^channel_name)
      |> where([e], is_nil(e.cancelled_at))
      |> where([e], e.starts_at >= ^DateTime.utc_now())
      |> Repo.aggregate(:count)

    if count < @max_upcoming do
      :ok
    else
      {:error,
       dgettext("channels", "This channel already has %{count} events coming up.",
         count: @max_upcoming
       )}
    end
  end

  # The cursor is the pair the list is ordered by, because two events can start
  # at the same instant and an id alone would then skip one of them.
  defp maybe_after(query, nil), do: query

  defp maybe_after(query, {starts_at, id}) do
    where(query, [e], e.starts_at > ^starts_at or (e.starts_at == ^starts_at and e.id > ^id))
  end

  @spec first_error(Ecto.Changeset.t()) :: String.t()
  defp first_error(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {message, _opts} -> message end)
    |> Enum.flat_map(fn {field, messages} -> Enum.map(messages, &"#{field} #{&1}") end)
    |> List.first()
    |> Kernel.||(dgettext("channels", "That event could not be saved."))
  end
end
