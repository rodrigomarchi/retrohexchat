defmodule RetroHexChat.Chat.Reactions do
  @moduledoc """
  Answering a message without writing one.

  This is the cheapest thing a person can say here, and that is the point: the
  only way to respond to somebody in this product has been to type, and the
  person who just arrived does not type. A reaction is one click, and it still
  reaches the author.

  Cheap is also what it has to stay, so three limits are enforced rather than
  suggested. One person's one emoji counts once, which is what makes the click
  a toggle instead of a counter anybody can run up. A message carries a bounded
  number of distinct emoji, because twenty faces under one line is a wall
  nobody reads. And only emoji the picker offers get in — an arbitrary string
  would be unmoderatable text hiding inside a number.

  Deliberately not here: anything that makes a reaction feel like a message. It
  does not mark a conversation unread, it plays no sound, and it wakes nobody
  up. The moment it does, it stops being cheap and people stop using it.
  """

  import Ecto.Query

  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Chat.EmojiData
  alias RetroHexChat.Chat.Message
  alias RetroHexChat.Chat.PrivateMessage
  alias RetroHexChat.Chat.Schemas.MessageReaction
  alias RetroHexChat.Repo

  @max_distinct 20

  @typedoc "What a message's reactions look like to a reader."
  @type summary :: %{String.t() => %{count: non_neg_integer(), actors: [String.t()]}}

  @typedoc "Which of the two message tables a reaction hangs off."
  @type kind :: :message | :private_message

  @doc "How many distinct emoji one message can carry."
  @spec max_distinct() :: pos_integer()
  def max_distinct, do: @max_distinct

  @doc "Every emoji a reaction may use."
  @spec catalog_emoji() :: [String.t()]
  defdelegate catalog_emoji(), to: EmojiData, as: :chars

  @doc """
  Add `nickname`'s `emoji` to `message`, or take it away if it is already there.

  Answers with the emoji's state afterwards, which is exactly what a reader has
  to be told — the count and who is in it, never a delta.
  """
  @spec toggle(Message.t() | PrivateMessage.t(), String.t(), String.t()) ::
          {:ok, %{emoji: String.t(), count: non_neg_integer(), actors: [String.t()]}}
          | {:error, String.t()}
  def toggle(message, nickname, emoji) do
    with :ok <- allowed?(message, nickname, emoji) do
      case existing(message, nickname, emoji) do
        nil -> add(message, nickname, emoji)
        reaction -> Repo.delete(reaction)
      end
      |> case do
        {:ok, _row} -> {:ok, state_of(message, emoji)}
        {:error, _changeset} -> {:error, dgettext("chat", "Reaction could not be saved.")}
      end
    end
  end

  @doc "Every emoji on one message, with who put it there."
  @spec summary_for(Message.t() | PrivateMessage.t()) :: summary()
  def summary_for(message) do
    {kind, id} = parent(message)

    kind
    |> summary_for_many([id])
    |> Map.get(id, %{})
  end

  @doc """
  The same, for a whole page of messages, in one query.

  A page is fifty rows, and asking per row is how a feature that costs one
  click costs fifty queries. Messages nobody reacted to are absent rather than
  empty, because the row that renders them distinguishes the two.
  """
  @spec summary_for_many(kind(), [integer()]) :: %{integer() => summary()}
  def summary_for_many(_kind, []), do: %{}

  def summary_for_many(kind, ids) do
    field = parent_field(kind)

    MessageReaction
    |> where([r], field(r, ^field) in ^ids)
    |> order_by([r], asc: r.id)
    |> select([r], {field(r, ^field), r.emoji, r.owner_nickname})
    |> Repo.all()
    |> Enum.group_by(fn {parent_id, _emoji, _nick} -> parent_id end)
    |> Map.new(fn {parent_id, rows} -> {parent_id, group_emoji(rows)} end)
  end

  @spec allowed?(Message.t() | PrivateMessage.t(), String.t(), String.t()) ::
          :ok | {:error, String.t()}
  defp allowed?(message, nickname, emoji) do
    cond do
      not EmojiData.known?(emoji) ->
        {:error, dgettext("chat", "That is not an emoji you can react with.")}

      Map.get(message, :deleted_at) ->
        {:error, dgettext("chat", "That message was deleted.")}

      at_ceiling?(message, nickname, emoji) ->
        {:error,
         dgettext("chat", "This message already has %{count} different reactions.",
           count: @max_distinct
         )}

      true ->
        :ok
    end
  end

  # The ceiling is on distinct emoji, so joining one that is already under the
  # message is always allowed — otherwise the twentieth emoji would lock the
  # other nineteen out of gaining a second person.
  @spec at_ceiling?(Message.t() | PrivateMessage.t(), String.t(), String.t()) :: boolean()
  defp at_ceiling?(message, nickname, emoji) do
    summary = summary_for(message)

    not Map.has_key?(summary, emoji) and map_size(summary) >= @max_distinct and
      is_nil(existing(message, nickname, emoji))
  end

  @spec existing(Message.t() | PrivateMessage.t(), String.t(), String.t()) ::
          MessageReaction.t() | nil
  defp existing(message, nickname, emoji) do
    {kind, id} = parent(message)
    field = parent_field(kind)

    MessageReaction
    |> where([r], field(r, ^field) == ^id and r.owner_nickname == ^nickname and r.emoji == ^emoji)
    |> Repo.one()
  end

  @spec add(Message.t() | PrivateMessage.t(), String.t(), String.t()) ::
          {:ok, MessageReaction.t()} | {:error, Ecto.Changeset.t()}
  defp add(message, nickname, emoji) do
    {kind, id} = parent(message)

    %MessageReaction{}
    |> MessageReaction.changeset(%{
      parent_field(kind) => id,
      :owner_nickname => nickname,
      :emoji => emoji
    })
    |> Repo.insert()
  end

  @spec state_of(Message.t() | PrivateMessage.t(), String.t()) :: map()
  defp state_of(message, emoji) do
    case Map.get(summary_for(message), emoji) do
      nil -> %{emoji: emoji, count: 0, actors: []}
      %{count: count, actors: actors} -> %{emoji: emoji, count: count, actors: actors}
    end
  end

  @spec group_emoji([{integer(), String.t(), String.t()}]) :: summary()
  defp group_emoji(rows) do
    rows
    |> Enum.group_by(
      fn {_parent_id, emoji, _nick} -> emoji end,
      fn {_parent_id, _emoji, nick} -> nick end
    )
    |> Map.new(fn {emoji, actors} -> {emoji, %{count: length(actors), actors: actors}} end)
  end

  @spec parent(Message.t() | PrivateMessage.t()) :: {kind(), integer()}
  defp parent(%Message{id: id}), do: {:message, id}
  defp parent(%PrivateMessage{id: id}), do: {:private_message, id}

  @spec parent_field(kind()) :: atom()
  defp parent_field(:message), do: :message_id
  defp parent_field(:private_message), do: :private_message_id
end
