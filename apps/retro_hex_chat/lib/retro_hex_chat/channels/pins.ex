defmodule RetroHexChat.Channels.Pins do
  @moduledoc """
  The lines a channel keeps in view: the rules, the link, what was agreed.

  A channel already had a topic — one line, replaced each time — and a welcome
  message nobody sees twice. What it had no way to do was keep several things
  findable, so they scrolled away and were retyped.

  A pin belongs to the **conversation**, not to the message. The same line is
  ordinary in every other context, and a column on `messages` would say
  otherwise; two channels can keep the same line for different reasons, and
  neither knows about the other. It also means a deleted line takes its pins
  with it, which the foreign key does rather than any code here remembering to.

  Only channels. Pinning inside a conversation between two people is a feature
  looking for a use; if anybody asks, it arrives later without changing this
  model.
  """

  import Ecto.Query

  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Channels.Schemas.PinnedMessage
  alias RetroHexChat.Chat.Message
  alias RetroHexChat.Page
  alias RetroHexChat.Repo

  # Enough for the rules, the links and the running jokes; past this the window
  # stops being a place you find things and becomes a second scrollback.
  @max_per_channel 50

  @default_limit 25

  @doc "How many lines one channel may keep."
  @spec max_per_channel() :: pos_integer()
  def max_per_channel, do: @max_per_channel

  @doc """
  Keeps `message_id` in view for `channel_name`.

  Pinning the same line twice is the same pin, not two — the caller is somebody
  pressing a menu item, and the honest answer to "it is already pinned" is the
  pin.
  """
  @spec pin(String.t(), integer(), String.t()) ::
          {:ok, PinnedMessage.t()} | {:error, String.t()}
  def pin(channel_name, message_id, pinned_by) do
    case existing(channel_name, message_id) do
      %PinnedMessage{} = pin -> {:ok, pin}
      nil -> insert(channel_name, message_id, pinned_by)
    end
  end

  @doc "Stops keeping it, and says nothing about one that was never kept."
  @spec unpin(String.t(), integer()) :: :ok
  def unpin(channel_name, message_id) do
    PinnedMessage
    |> where([p], p.channel_name == ^channel_name and p.message_id == ^message_id)
    |> Repo.delete_all()

    :ok
  end

  @doc """
  What `channel_name` is keeping, most recently pinned first.

  Each entry carries the line itself rather than only its id: the window that
  shows these would otherwise need a second query per row, and a pin with no
  line to show is not a pin.
  """
  @spec list(String.t(), keyword()) :: Page.t()
  def list(channel_name, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)
    cursor = Keyword.get(opts, :cursor)

    from(p in PinnedMessage,
      join: m in Message,
      on: m.id == p.message_id,
      where: p.channel_name == ^channel_name,
      order_by: [desc: p.id],
      limit: ^Page.limit_with_lookahead(limit),
      select: %{
        id: p.id,
        message_id: p.message_id,
        pinned_by: p.pinned_by,
        pinned_at: p.inserted_at,
        author_nickname: m.author_nickname,
        content: m.content,
        content_format: m.content_format,
        inserted_at: m.inserted_at
      }
    )
    |> then(&if cursor, do: where(&1, [p], p.id < ^cursor), else: &1)
    |> Repo.all()
    |> Page.new(limit, & &1.id)
  end

  @doc "How many lines `channel_name` is keeping."
  @spec count(String.t()) :: non_neg_integer()
  def count(channel_name) do
    PinnedMessage
    |> where([p], p.channel_name == ^channel_name)
    |> Repo.aggregate(:count)
  end

  @doc "Whether `message_id` is one of the lines `channel_name` keeps."
  @spec pinned?(String.t(), integer()) :: boolean()
  def pinned?(channel_name, message_id),
    do: existing(channel_name, message_id) != nil

  defp existing(channel_name, message_id) when is_integer(message_id) do
    Repo.get_by(PinnedMessage, channel_name: channel_name, message_id: message_id)
  end

  defp existing(_channel_name, _message_id), do: nil

  defp insert(channel_name, message_id, pinned_by) do
    with :ok <- check_room(channel_name),
         :ok <- check_belongs(channel_name, message_id) do
      %PinnedMessage{}
      |> PinnedMessage.changeset(%{
        channel_name: channel_name,
        message_id: message_id,
        pinned_by: pinned_by
      })
      |> Repo.insert()
      |> case do
        {:ok, pin} ->
          {:ok, pin}

        {:error, _changeset} ->
          {:error, dgettext("channels", "That message could not be pinned")}
      end
    end
  end

  defp check_room(channel_name) do
    if count(channel_name) < @max_per_channel do
      :ok
    else
      {:error,
       dgettext(
         "channels",
         "This channel already keeps %{count} messages. Unpin one first.",
         count: @max_per_channel
       )}
    end
  end

  # A line can only be kept by the conversation it was said in. Without this the
  # window would show somebody else's channel back to them.
  defp check_belongs(channel_name, message_id) when is_integer(message_id) do
    exists? =
      Message
      |> where([m], m.id == ^message_id and m.channel_name == ^channel_name)
      |> Repo.exists?()

    if exists?,
      do: :ok,
      else: {:error, dgettext("channels", "That message is not in this channel")}
  end

  defp check_belongs(_channel_name, _message_id),
    do: {:error, dgettext("channels", "That message is not in this channel")}
end
