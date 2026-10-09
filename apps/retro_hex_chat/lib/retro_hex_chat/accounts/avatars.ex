defmodule RetroHexChat.Accounts.Avatars do
  @moduledoc """
  Which character each person chose, kept past the visit that chose it.

  The virtual space has had a roster of characters since it existed, but the
  choice lived in the space's own process and the browser's localStorage — so it
  was gone the moment somebody walked out, and the chat could never know it. The
  chat is where a person spends the day, and the same figure standing beside
  their nickname there is what turns a chosen character into an identity rather
  than a costume worn for one visit.

  One short string on the nickname's own row, rather than a table: it is
  identity, and it should go when the nickname goes — which the row already
  arranges. `nil` means nobody chose, which is a different fact from choosing
  the first one in the list, and the reader draws nothing at all for it.

  The valid set is `VirtualSpace.avatars/0`, asked here rather than trusted from
  the caller: a build that retires a class must not be able to store a pointer
  at art it no longer ships.
  """

  import Ecto.Query
  import RetroHexChat.Nickname, only: [key_of: 1, matches: 2]

  alias RetroHexChat.Nickname
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.RegisteredNick
  alias RetroHexChat.Topics
  alias RetroHexChat.VirtualSpace

  @doc """
  Records the character `nickname` chose, and tells every open session.

  The broadcast is what keeps the user lists honest: they are streams, and a
  stream does not restyle a row nobody re-inserts — so without it everybody
  else would keep seeing the character this person left behind until their next
  channel switch.
  """
  @spec remember(String.t(), String.t()) :: :ok | {:error, :not_found | :invalid_avatar}
  def remember(nickname, avatar) do
    with true <- avatar in VirtualSpace.avatars(),
         :ok <- write(nickname, avatar) do
      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        Topics.presence(),
        {:avatar_changed, %{nickname: nickname, avatar: avatar}}
      )

      :ok
    else
      false -> {:error, :invalid_avatar}
      {:error, _reason} = error -> error
    end
  end

  @doc "The character this person chose, or nil if they never did."
  @spec for_nick(String.t()) :: String.t() | nil
  def for_nick(nickname) do
    nickname
    |> List.wrap()
    |> for_nicks()
    |> Map.values()
    |> List.first()
  end

  @doc """
  The characters these people chose, keyed by the nickname as it was asked for.

  One query for a whole roster or a whole page of messages: a portrait beside
  every line is exactly the feature that turns one screenful into a query a row.
  Somebody who never chose is absent rather than nil, because the row that draws
  them distinguishes the two.
  """
  @spec for_nicks([String.t()]) :: %{String.t() => String.t()}
  def for_nicks([]), do: %{}

  def for_nicks(nicknames) do
    # A nickname is spelled however it was typed, and the same person is the
    # same person: the lookup folds case, and the answer comes back under the
    # spelling the caller used.
    by_downcase =
      nicknames
      |> Enum.filter(&is_binary/1)
      |> Map.new(&{Nickname.key(&1), &1})

    stored =
      RegisteredNick
      |> where([n], key_of(n.nickname) in ^Map.keys(by_downcase))
      |> where([n], not is_nil(n.avatar))
      |> select([n], {key_of(n.nickname), n.avatar})
      |> Repo.all()

    Map.new(stored, fn {downcased, avatar} ->
      {Map.fetch!(by_downcase, downcased), avatar}
    end)
  end

  @spec write(String.t(), String.t()) :: :ok | {:error, :not_found}
  defp write(nickname, avatar) do
    {count, _} =
      RegisteredNick
      |> where([n], matches(n.nickname, nickname))
      |> Repo.update_all(set: [avatar: avatar])

    if count > 0, do: :ok, else: {:error, :not_found}
  end
end
