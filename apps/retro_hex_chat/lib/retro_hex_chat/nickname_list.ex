defmodule RetroHexChat.NicknameList do
  @moduledoc """
  A list of people someone keeps, by nickname, with a note against each.

  The address book and the notify list are both one of these. They differ in
  what they are for — one remembers who you have talked to, the other watches
  who comes online — and in how many entries they hold, but the list itself
  behaves the same way in both: a nickname appears once regardless of case, the
  list is capped, notes are cut to length rather than rejected, and entries are
  shown alphabetically rather than in the order they were added.

  Case is the reason this is worth having in one place. IRC nicknames compare
  case-insensitively, and every operation here has to remember that — finding,
  removing, updating, sorting. A copy that forgets it in one function looks
  right until someone types `Alice` where they once typed `alice`.

  The entries themselves stay each module's own, including which field holds
  the nickname, because the two carry genuinely different things beside it: a
  first-contact date on one, an online flag on the other.
  """

  @typedoc "How a particular list is shaped: where the nickname is, and its limits."
  @type t :: %__MODULE__{
          field: atom(),
          max_entries: pos_integer(),
          max_note_length: pos_integer()
        }

  @typedoc "Whatever holds the entries. Each list keeps its own extras beside them."
  @type kept :: %{required(:entries) => [struct()], optional(any()) => any()}

  @enforce_keys [:field, :max_entries, :max_note_length]
  defstruct [:field, :max_entries, :max_note_length]

  @doc "Declares a list's shape. Cheap enough to hold in a module attribute."
  @spec new(keyword()) :: t()
  def new(opts) do
    %__MODULE__{
      field: Keyword.fetch!(opts, :field),
      max_entries: Keyword.fetch!(opts, :max_entries),
      max_note_length: Keyword.fetch!(opts, :max_note_length)
    }
  end

  @doc "Whether `nickname` is already on the list, however it was typed."
  @spec member?(t(), kept(), String.t()) :: boolean()
  def member?(spec, list, nickname) do
    wanted = String.downcase(nickname)

    Enum.any?(list.entries, &(nickname_of(spec, &1) == wanted))
  end

  @doc "Whether the list has no room left."
  @spec full?(t(), kept()) :: boolean()
  def full?(%__MODULE__{max_entries: max}, list), do: length(list.entries) >= max

  @doc """
  Entries alphabetically, which is how a person reads a list of names.

  Takes entries rather than the whole list, because a caller often orders only
  part of one — the buddies who are online, then the buddies who are not.
  """
  @spec sorted(t(), [struct()]) :: [struct()]
  def sorted(spec, entries), do: Enum.sort_by(entries, &nickname_of(spec, &1))

  @doc """
  The list without `nickname`, or `:not_found` if it was never on it.

  `:not_found` rather than the unchanged list, because removing someone who is
  not there is worth telling the person who asked.
  """
  @spec remove(t(), kept(), String.t()) :: {:ok, kept()} | {:error, :not_found}
  def remove(spec, list, nickname) do
    wanted = String.downcase(nickname)

    case Enum.split_with(list.entries, &(nickname_of(spec, &1) == wanted)) do
      {[], _remaining} -> {:error, :not_found}
      {_removed, remaining} -> {:ok, %{list | entries: remaining}}
    end
  end

  @doc """
  The list with `nickname`'s note replaced, cut to what an entry holds.

  Cutting here rather than at each caller is what keeps a note the same length
  whether it arrived when the entry was added or long afterwards.
  """
  @spec put_note(t(), kept(), String.t(), String.t() | nil) ::
          {:ok, kept()} | {:error, :not_found}
  def put_note(spec, list, nickname, note) do
    cut = truncate_note(spec, note)

    update(spec, list, nickname, &%{&1 | note: cut})
  end

  @doc """
  The list with `nickname`'s entry replaced by `fun` applied to it.

  Keeps the order, so an update never reshuffles what the person is looking at.
  """
  @spec update(t(), kept(), String.t(), (struct() -> struct())) ::
          {:ok, kept()} | {:error, :not_found}
  def update(spec, list, nickname, fun) when is_function(fun, 1) do
    wanted = String.downcase(nickname)

    {found?, reversed} =
      Enum.reduce(list.entries, {false, []}, fn entry, {found?, acc} ->
        if nickname_of(spec, entry) == wanted do
          {true, [fun.(entry) | acc]}
        else
          {found?, [entry | acc]}
        end
      end)

    if found?,
      do: {:ok, %{list | entries: Enum.reverse(reversed)}},
      else: {:error, :not_found}
  end

  @doc "A note cut to what the list holds, rather than refused for being long."
  @spec truncate_note(t(), String.t() | nil) :: String.t() | nil
  def truncate_note(_spec, nil), do: nil

  def truncate_note(%__MODULE__{max_note_length: max}, note) when is_binary(note),
    do: String.slice(note, 0, max)

  defp nickname_of(%__MODULE__{field: field}, entry),
    do: entry |> Map.fetch!(field) |> String.downcase()
end
