defmodule RetroHexChat.Chat.CustomEmojis do
  @moduledoc """
  The pictures a server answers to by name.

  Per server, not per channel. A self-hosted server is the unit of belonging in
  this product — the inside joke belongs to the people who run it, not to one
  room — and a per-channel set would be the same picture uploaded five times
  with nobody to own any of them.

  Read from ETS rather than the database because the read is on the render path
  of **every message**: resolving `:shrug:` costs a lookup per line, and a query
  per line is how a feature that costs one upload costs the conversation. The
  table is seeded on boot and written through on every change, in the shape
  `Admin.RoleCache` already uses.

  The picture is an ordinary uploaded file. That is what gives this a size
  limit, a storage backend and orphan cleanup without any of the three being
  written a second time.
  """
  use GenServer

  import Ecto.Query

  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Chat.Schemas.CustomEmoji
  alias RetroHexChat.Repo

  @table :custom_emoji_cache

  # Enough for a server's whole vocabulary of jokes; past this the picker stops
  # being something you scan and becomes something you search.
  @max_count 100

  @typedoc "An emoji as the picker and the renderer read it."
  @type entry :: %{id: integer(), name: String.t(), uploaded_file_id: integer()}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc "How many pictures one server may answer to."
  @spec max_count() :: pos_integer()
  def max_count, do: @max_count

  @doc """
  Teaches the server a name.

  Refuses a name it already answers to, a name nobody could type between two
  colons, and anything past the ceiling.
  """
  @spec add(String.t(), integer(), String.t()) ::
          {:ok, CustomEmoji.t()} | {:error, String.t()}
  def add(name, uploaded_file_id, added_by) do
    with :ok <- room_left?() do
      %CustomEmoji{}
      |> CustomEmoji.changeset(%{
        name: name,
        uploaded_file_id: uploaded_file_id,
        added_by: added_by
      })
      |> Repo.insert()
      |> case do
        {:ok, emoji} ->
          cache_put(emoji)
          {:ok, emoji}

        {:error, changeset} ->
          {:error, first_error(changeset)}
      end
    end
  end

  @doc "Makes the server forget one, freeing the name."
  @spec remove(integer()) :: :ok
  def remove(id) do
    case Repo.get(CustomEmoji, id) do
      nil ->
        :ok

      emoji ->
        Repo.delete(emoji)
        cache_delete(emoji)
        :ok
    end
  end

  @doc "Everything this server answers to, in the order it learned them."
  @spec all() :: [entry()]
  def all do
    @table
    |> :ets.tab2list()
    |> Enum.map(fn {_name, entry} -> entry end)
    |> Enum.sort_by(& &1.id)
  rescue
    ArgumentError -> []
  end

  @doc "One entry by name, however it was typed, or nil."
  @spec get(String.t()) :: entry() | nil
  def get(name) when is_binary(name) do
    case :ets.lookup(@table, normalize(name)) do
      [{_name, entry}] -> entry
      [] -> nil
    end
  rescue
    ArgumentError -> nil
  end

  def get(_name), do: nil

  @doc "How many the server has."
  @spec count() :: non_neg_integer()
  def count, do: length(all())

  @doc """
  Empties the table and seeds it from the database again.

  For tests, and for the boot path — the one place where "what the database
  says" and "what the table says" are allowed to differ is before the first
  seed.
  """
  @spec reset_cache() :: :ok
  def reset_cache do
    ensure_table()
    :ets.delete_all_objects(@table)
    seed_from_db()
    :ok
  end

  @impl true
  def init(_opts) do
    ensure_table()
    seed_from_db()
    {:ok, %{}}
  end

  @spec ensure_table() :: :ok
  defp ensure_table do
    :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
    :ok
  rescue
    ArgumentError -> :ok
  end

  @spec seed_from_db() :: :ok
  defp seed_from_db do
    CustomEmoji
    |> order_by([e], asc: e.id)
    |> Repo.all()
    |> Enum.each(&cache_put/1)

    :ok
  rescue
    _database_not_ready -> :ok
  end

  defp cache_put(emoji) do
    :ets.insert(@table, {normalize(emoji.name), entry(emoji)})
  rescue
    ArgumentError -> false
  end

  defp cache_delete(emoji) do
    :ets.delete(@table, normalize(emoji.name))
  rescue
    ArgumentError -> false
  end

  defp entry(emoji) do
    %{id: emoji.id, name: emoji.name, uploaded_file_id: emoji.uploaded_file_id}
  end

  defp normalize(name), do: name |> String.trim() |> String.trim(":") |> String.downcase()

  @spec room_left?() :: :ok | {:error, String.t()}
  defp room_left?() do
    if count() < @max_count do
      :ok
    else
      {:error, dgettext("chat", "This server already has %{count} emoji.", count: @max_count)}
    end
  end

  @spec first_error(Ecto.Changeset.t()) :: String.t()
  defp first_error(changeset) do
    case changeset.errors do
      [{:name, {_msg, [constraint: :unique, constraint_name: _]}} | _rest] ->
        dgettext("chat", "This server already answers to that name.")

      [{:name, _} | _rest] ->
        dgettext(
          "chat",
          "An emoji name is 2 to 32 characters: lower-case letters, digits and underscores."
        )

      _other ->
        dgettext("chat", "That emoji could not be saved.")
    end
  end
end
