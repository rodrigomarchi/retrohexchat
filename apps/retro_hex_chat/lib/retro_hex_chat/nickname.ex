defmodule RetroHexChat.Nickname do
  @moduledoc """
  The one rule for telling nicknames apart: case does not make a different person.

  `Alice`, `alice` and `AlIcE` are one nickname, as they were on IRC — one
  registration, one person online at a time, one inbox. What a person typed is
  still what everyone sees: identity compares `key/1`, display keeps the string.

  Anything that asks "is this the same person?" asks here, never `==` on two
  nicknames and never a `String.downcase` of its own; `mix lint.nickname_casemap`
  holds the rest of the code to that.

  The fold is ASCII lowercase on purpose. It is what Postgres `lower()` does to
  this charset (`Accounts.NicknameValidator` admits ASCII letters, digits and
  `[]\\^_{|}` and backtick), so a key computed here and a `lower()` index on the
  database agree. RFC1459 casemapping would also fold `[` into `{`; the indexes
  would not, so neither does this — changing the fold means a migration.
  """

  @typedoc "A nickname folded for comparison. Never shown to anybody."
  @type key :: String.t()

  @doc "The comparison key of a nickname."
  @spec key(String.t()) :: key()
  def key(nickname) when is_binary(nickname), do: String.downcase(nickname, :ascii)

  @doc "Whether two nicknames name the same person. Anything that is not a nickname names nobody."
  @spec equal?(String.t() | nil, String.t() | nil) :: boolean()
  def equal?(a, b) when is_binary(a) and is_binary(b), do: key(a) == key(b)
  def equal?(_a, _b), do: false

  @doc "Whether any nickname in `nicknames` names the same person as `nickname`."
  @spec member?(Enumerable.t(), String.t()) :: boolean()
  def member?(nicknames, nickname) when is_binary(nickname) do
    wanted = key(nickname)
    Enum.any?(nicknames, &(key(&1) == wanted))
  end

  @doc """
  The first element whose nickname — read by `nick_of` — names the same person,
  returned as stored, so its display spelling survives.
  """
  @spec find(Enumerable.t(), String.t(), (term() -> String.t())) :: term() | nil
  def find(enumerable, nickname, nick_of \\ & &1) when is_binary(nickname) do
    wanted = key(nickname)
    Enum.find(enumerable, &(key(nick_of.(&1)) == wanted))
  end

  @doc "`nicknames` without `nickname`, in whatever case it appears."
  @spec without([String.t()], String.t()) :: [String.t()]
  def without(nicknames, nickname) when is_list(nicknames) do
    wanted = key(nickname)
    Enum.reject(nicknames, &(key(&1) == wanted))
  end

  @doc """
  `set` holding `nickname` once, in the spelling given: any other case of it is
  replaced, so a set of nicknames never names one person twice.
  """
  @spec put(MapSet.t(String.t()), String.t()) :: MapSet.t(String.t())
  def put(%MapSet{} = set, nickname), do: set |> delete(nickname) |> MapSet.put(nickname)

  @doc "`set` without `nickname`, in whatever case it was stored."
  @spec delete(MapSet.t(String.t()), String.t()) :: MapSet.t(String.t())
  def delete(%MapSet{} = set, nickname) do
    wanted = key(nickname)
    MapSet.reject(set, &(key(&1) == wanted))
  end

  @doc """
  An Ecto condition: `field` names the same person as `nickname`.

      import RetroHexChat.Nickname, only: [matches: 2]
      where(query, [n], matches(n.nickname, ^nickname))

  It compares `lower(field)` with the key, so a `lower(...)` index serves it.
  """
  defmacro matches(field, nickname) do
    quote do
      fragment("lower(?)", unquote(field)) == ^RetroHexChat.Nickname.key(unquote(nickname))
    end
  end

  @doc """
  The key of a nickname column, in SQL — what `key/1` is to a string. For lookups
  of many nicknames at once: `where(q, [n], key_of(n.nickname) in ^keys)`.
  """
  defmacro key_of(field) do
    quote do
      fragment("lower(?)", unquote(field))
    end
  end
end
