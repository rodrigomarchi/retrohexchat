defmodule RetroHexChat.Accounts.Avatars do
  @moduledoc """
  The character each person made in the Space's creator, kept past the visit
  that made it.

  The chat is where a person spends the day, and the same figure standing
  beside their nickname there is what turns a character into an identity rather
  than a costume worn for one visit.

  One short string on the nickname's own row, rather than a table: the
  character is a `VirtualSpace.CharacterRecipe`, and it is identity, so it
  should go when the nickname goes — which the row already arranges. `nil`
  means nobody made one, which is a different fact from making the default,
  and the reader draws nothing at all for it.

  A recipe is parsed here rather than trusted from the caller, and read back
  through `CharacterRecipe.coerce/1`: a build that retires a hat must not leave
  a row pointing at art it no longer ships.
  """

  import Ecto.Query
  import RetroHexChat.Nickname, only: [key_of: 1, matches: 2]

  alias RetroHexChat.Nickname
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.RegisteredNick
  alias RetroHexChat.Topics
  alias RetroHexChat.VirtualSpace.CharacterRecipe

  @doc """
  Records the character `nickname` made, and tells every open session.

  The broadcast is what keeps the user lists honest: they are streams, and a
  stream does not restyle a row nobody re-inserts — so without it everybody
  else would keep seeing the character this person left behind until their next
  channel switch.
  """
  @spec remember(String.t(), String.t()) :: :ok | {:error, :not_found | :invalid_avatar}
  def remember(nickname, avatar) do
    with true <- CharacterRecipe.valid?(avatar),
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

  @doc "The character this person made, or nil if they never did."
  @spec for_nick(String.t()) :: String.t() | nil
  def for_nick(nickname) do
    nickname
    |> List.wrap()
    |> for_nicks()
    |> Map.values()
    |> List.first()
  end

  @doc """
  The characters these people made, keyed by the nickname as it was asked for.

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
      {Map.fetch!(by_downcase, downcased), CharacterRecipe.coerce(avatar)}
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
