defmodule RetroHexChat.Chat.SavedMessages do
  @moduledoc """
  The pile a person keeps for themselves.

  A chat loses things. The address somebody typed, the link to the build, the
  one paragraph worth reading again — all of it scrolls, and the only recovery
  the product offered was search, which needs you to remember a word from it.
  Saving is the answer for the case where you know *now* that you will want it
  *later*, and it costs one menu item.

  Two properties decide everything below.

  It is **private**. Nobody is told what you kept, no count is broadcast, and
  the list is read by nickname or not at all. There is deliberately no "saved
  by 3 people" anywhere: the moment saving is visible it becomes a vote, and a
  vote is a different feature with different consequences.

  And a saved line **outlives the scrollback without outliving the message**.
  A line that was deleted keeps its row, marked as deleted and stripped of its
  content: a row that simply vanished would teach the reader that saving does
  not work, and a row still showing the text would undo the deletion. A line
  that is genuinely gone from the database takes the row with it, which the
  foreign key does rather than any code here remembering to.
  """

  import Ecto.Query

  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Chat.Message
  alias RetroHexChat.Chat.PrivateMessage
  alias RetroHexChat.Chat.Schemas.SavedMessage
  alias RetroHexChat.Page
  alias RetroHexChat.Repo

  # Far past what anybody curates and far short of a second scrollback. Past
  # this the list stops being a place you find things.
  @max_per_owner 500

  @default_limit 25

  @typedoc "Which of the two message tables a saved row hangs off."
  @type kind :: :message | :private_message

  @typedoc "One row as the window reads it."
  @type entry :: %{
          id: integer(),
          note: String.t() | nil,
          saved_at: DateTime.t(),
          message_id: integer() | nil,
          private_message_id: integer() | nil,
          channel_name: String.t() | nil,
          pm_sender: String.t() | nil,
          pm_recipient: String.t() | nil,
          counterpart: String.t() | nil,
          author_nickname: String.t() | nil,
          content: String.t() | nil,
          plain_content: String.t() | nil,
          content_format: String.t() | nil,
          deleted?: boolean(),
          inserted_at: DateTime.t() | nil
        }

  @doc "How many lines one person may keep."
  @spec max_per_owner() :: pos_integer()
  def max_per_owner, do: @max_per_owner

  @doc """
  Keeps `message` for `owner_nickname`.

  Saving the same line twice is the same save, not two — the caller is somebody
  pressing a menu item, and the honest answer to "it is already saved" is the
  save.
  """
  @spec save(String.t(), Message.t() | PrivateMessage.t(), String.t() | nil) ::
          {:ok, SavedMessage.t()} | {:error, String.t()}
  def save(owner_nickname, message, note \\ nil) do
    case existing(owner_nickname, message) do
      %SavedMessage{} = saved -> {:ok, saved}
      nil -> insert(owner_nickname, message, note)
    end
  end

  @doc "Stops keeping it, and says nothing about one that was never kept."
  @spec unsave(String.t(), Message.t() | PrivateMessage.t()) :: :ok
  def unsave(owner_nickname, message) do
    {kind, id} = parent(message)
    field = parent_field(kind)

    SavedMessage
    |> where([s], s.owner_nickname == ^owner_nickname and field(s, ^field) == ^id)
    |> Repo.delete_all()

    :ok
  end

  @doc """
  Stops keeping the row `saved_id`, which must belong to `owner_nickname`.

  The window has a row id, not a message; and the id travels through the
  client, so the owner is part of the question rather than something checked
  afterwards.
  """
  @spec unsave_id(String.t(), integer()) :: :ok | {:error, String.t()}
  def unsave_id(owner_nickname, saved_id) do
    case Repo.get_by(SavedMessage, id: saved_id, owner_nickname: owner_nickname) do
      nil ->
        {:error, dgettext("chat", "That saved message is not yours.")}

      saved ->
        Repo.delete(saved)
        :ok
    end
  end

  @doc """
  What `owner_nickname` kept, most recently saved first.

  Channel and private lines come back in one list, because the person who saved
  them was not sorting by which table they landed in. Each entry carries the
  line itself rather than only its id — a window that fetched per row would pay
  a query a row, and a saved line with nothing to show is not a saved line.
  """
  @spec list(String.t(), keyword()) :: Page.t()
  def list(owner_nickname, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)
    cursor = Keyword.get(opts, :cursor)

    from(s in SavedMessage,
      left_join: m in Message,
      on: m.id == s.message_id,
      left_join: p in PrivateMessage,
      on: p.id == s.private_message_id,
      where: s.owner_nickname == ^owner_nickname,
      order_by: [desc: s.id],
      limit: ^Page.limit_with_lookahead(limit),
      select: %{
        id: s.id,
        note: s.note,
        saved_at: s.inserted_at,
        message_id: s.message_id,
        private_message_id: s.private_message_id,
        channel_name: m.channel_name,
        pm_sender: p.sender_nickname,
        pm_recipient: p.recipient_nickname,
        # Who the conversation was with, from this reader's side: the window
        # opens a private conversation by the other person's name, and only
        # the owner of the row can say which of the two that is.
        counterpart:
          fragment(
            "CASE WHEN ? = ? THEN ? ELSE ? END",
            p.sender_nickname,
            ^owner_nickname,
            p.recipient_nickname,
            p.sender_nickname
          ),
        author_nickname: coalesce(m.author_nickname, p.sender_nickname),
        content: coalesce(m.content, p.content),
        plain_content: coalesce(m.plain_content, p.plain_content),
        content_format: coalesce(m.content_format, p.content_format),
        deleted_at: coalesce(m.deleted_at, p.deleted_at),
        inserted_at: coalesce(m.inserted_at, p.inserted_at)
      }
    )
    |> then(&if cursor, do: where(&1, [s], s.id < ^cursor), else: &1)
    |> Repo.all()
    |> Enum.map(&redact_deleted/1)
    |> Page.new(limit, & &1.id)
  end

  @doc "How many lines `owner_nickname` is keeping."
  @spec count(String.t()) :: non_neg_integer()
  def count(owner_nickname) do
    SavedMessage
    |> where([s], s.owner_nickname == ^owner_nickname)
    |> Repo.aggregate(:count)
  end

  @doc "Whether `owner_nickname` already kept this line."
  @spec saved?(String.t(), Message.t() | PrivateMessage.t()) :: boolean()
  def saved?(owner_nickname, message),
    do: existing(owner_nickname, message) != nil

  @doc """
  The ids `owner_nickname` kept, out of `ids` of one kind, as a set.

  The context menu asks this about the line under the pointer and the row it
  draws asks it about a page of lines; both want one query, not one per line.
  """
  @spec saved_ids(String.t(), kind(), [integer()]) :: MapSet.t(integer())
  def saved_ids(_owner_nickname, _kind, []), do: MapSet.new()

  def saved_ids(owner_nickname, kind, ids) do
    field = parent_field(kind)

    SavedMessage
    |> where([s], s.owner_nickname == ^owner_nickname and field(s, ^field) in ^ids)
    |> select([s], field(s, ^field))
    |> Repo.all()
    |> MapSet.new()
  end

  @doc """
  Replaces the note on one of `owner_nickname`'s rows.

  Scoped by owner rather than by row id alone: the id travels through the
  client, and a row anybody could rewrite by guessing a number is not private.
  """
  @spec set_note(String.t(), integer(), String.t() | nil) :: :ok | {:error, String.t()}
  def set_note(owner_nickname, saved_id, note) do
    case Repo.get_by(SavedMessage, id: saved_id, owner_nickname: owner_nickname) do
      nil ->
        {:error, dgettext("chat", "That saved message is not yours.")}

      saved ->
        saved
        |> SavedMessage.changeset(%{note: normalize_note(note)})
        |> Repo.update()
        |> case do
          {:ok, _saved} -> :ok
          {:error, _changeset} -> {:error, dgettext("chat", "That note could not be saved.")}
        end
    end
  end

  @spec insert(String.t(), Message.t() | PrivateMessage.t(), String.t() | nil) ::
          {:ok, SavedMessage.t()} | {:error, String.t()}
  defp insert(owner_nickname, message, note) do
    {kind, id} = parent(message)

    with :ok <- check_alive(message),
         :ok <- check_room(owner_nickname) do
      %SavedMessage{}
      |> SavedMessage.changeset(%{
        parent_field(kind) => id,
        :owner_nickname => owner_nickname,
        :note => normalize_note(note)
      })
      |> Repo.insert()
      |> case do
        {:ok, saved} -> {:ok, saved}
        {:error, _changeset} -> {:error, dgettext("chat", "That message could not be saved.")}
      end
    end
  end

  # Saving something already deleted would create a row that can only ever
  # render as "this was deleted" — a saved item with nothing in it.
  @spec check_alive(Message.t() | PrivateMessage.t()) :: :ok | {:error, String.t()}
  defp check_alive(message) do
    if Map.get(message, :deleted_at),
      do: {:error, dgettext("chat", "That message was deleted.")},
      else: :ok
  end

  @spec check_room(String.t()) :: :ok | {:error, String.t()}
  defp check_room(owner_nickname) do
    if count(owner_nickname) < @max_per_owner do
      :ok
    else
      {:error,
       dgettext(
         "chat",
         "You have already saved %{count} messages. Remove one first.",
         count: @max_per_owner
       )}
    end
  end

  @spec existing(String.t(), Message.t() | PrivateMessage.t()) :: SavedMessage.t() | nil
  defp existing(owner_nickname, message) do
    {kind, id} = parent(message)

    Repo.get_by(SavedMessage, [{parent_field(kind), id}, {:owner_nickname, owner_nickname}])
  end

  # A deleted line keeps its row and loses its text. Both halves matter: the
  # row is the evidence that saving worked, and the text is what the deletion
  # was for.
  @spec redact_deleted(map()) :: entry()
  defp redact_deleted(%{deleted_at: nil} = row) do
    row |> Map.delete(:deleted_at) |> Map.put(:deleted?, false)
  end

  defp redact_deleted(row) do
    row
    |> Map.delete(:deleted_at)
    |> Map.merge(%{deleted?: true, content: nil, plain_content: nil})
  end

  @spec normalize_note(String.t() | nil) :: String.t() | nil
  defp normalize_note(nil), do: nil

  defp normalize_note(note) when is_binary(note) do
    case note |> String.trim() |> String.slice(0, 200) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  @spec parent(Message.t() | PrivateMessage.t()) :: {kind(), integer()}
  defp parent(%Message{id: id}), do: {:message, id}
  defp parent(%PrivateMessage{id: id}), do: {:private_message, id}

  @spec parent_field(kind()) :: atom()
  defp parent_field(:message), do: :message_id
  defp parent_field(:private_message), do: :private_message_id
end
