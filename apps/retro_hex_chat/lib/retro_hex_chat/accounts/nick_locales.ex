defmodule RetroHexChat.Accounts.NickLocales do
  @moduledoc """
  The language each person uses the chat in, drawn as a flag beside their
  nickname wherever the nickname is.

  The language is the one the chat itself is shown in — the address's locale,
  which falls back to English — so everybody has one. It is answered from
  three places, freshest first:

    * the person's presence entry (`:locale` in its meta), for whoever is
      connected — registered or not, it is the language of the screen they
      have open right now;
    * `RetroHexChat.Accounts.GuestNames`, for a visitor watching under a
      guest name — they have no presence entry and no row;
    * the nickname's own row, for a registered person who is not here — the
      language they last used, so a message read after they left still has
      its flag;
    * a bot's row, where an admin said what language it speaks.

  Nobody found in any of them is absent from the answer, and the reader draws
  nothing for them. Locales are kept as the codes the web layer uses
  (`"pt_BR"`); this module only checks their shape, not that a flag exists.
  """

  import Ecto.Query
  import RetroHexChat.Nickname, only: [key_of: 1, matches: 2]

  alias RetroHexChat.Accounts.GuestNames
  alias RetroHexChat.Accounts.NicknameValidator
  alias RetroHexChat.Bots.Queries, as: BotQueries
  alias RetroHexChat.Nickname
  alias RetroHexChat.Presence.Tracker
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.RegisteredNick
  alias RetroHexChat.Topics

  @shape ~r/\A[a-z]{2,3}(_[A-Za-z]{2,4})?\z/

  @doc "Whether `locale` has the shape of a locale code."
  @spec valid?(term()) :: boolean()
  def valid?(locale) when is_binary(locale), do: Regex.match?(@shape, locale)
  def valid?(_locale), do: false

  @doc """
  Records the language `nickname` opened the chat in, and tells every open
  session.

  `store: true` writes it to the nickname's row as well — only for somebody
  who has proved the nickname, or whoever typed a registered name without
  its password would repaint its owner's flag — and then says nothing when
  the row already had it. Without a row there is nothing to compare with, so
  the news goes out every time and a screen that already shows that flag
  leaves its row alone. The broadcast is what restyles rows already on other
  screens: the user lists are streams, and a stream does not redraw a row
  nobody re-inserts.
  """
  @spec remember(String.t(), String.t(), keyword()) :: :ok | {:error, :invalid_locale}
  def remember(nickname, locale, opts \\ []) do
    cond do
      not valid?(locale) ->
        {:error, :invalid_locale}

      Keyword.get(opts, :store, false) and store(nickname, locale) == :unchanged ->
        :ok

      true ->
        announce(nickname, locale)
    end
  end

  @doc """
  Tells every open session that `nickname` now speaks `locale` — nil when it
  no longer has one — so the rows already drawn are drawn again. For a
  language kept somewhere this module does not write, such as a bot's.
  """
  @spec announce(String.t(), String.t() | nil) :: :ok
  def announce(nickname, locale) do
    Phoenix.PubSub.broadcast(
      RetroHexChat.PubSub,
      Topics.presence(),
      {:locale_changed, %{nickname: nickname, locale: locale}}
    )
  end

  @doc """
  Keeps the language of the screen `nickname` has open on their row, once they
  have proved the name from inside the chat — a registration or an
  identification there happens after the chat opened, so the opening could not
  store it. Nothing to keep for somebody not connected.
  """
  @spec adopt(String.t()) :: :ok
  def adopt(nickname) do
    case live_locale(nickname) do
      nil ->
        :ok

      locale ->
        _ = remember(nickname, locale, store: true)
        :ok
    end
  end

  @doc "The language `nickname` uses the chat in, or nil when nobody knows."
  @spec for_nick(String.t() | nil) :: String.t() | nil
  def for_nick(nickname) when is_binary(nickname), do: Map.get(for_nicks([nickname]), nickname)
  def for_nick(_nickname), do: nil

  @doc """
  The languages of these people, keyed by the nickname as it was asked for.

  At most one query for a whole roster or a page of messages, and only for the
  names nobody connected answered for. A guest name is asked of the visitors'
  registry alone and every other name of the rows alone: a guest name can
  never be registered, and a registered one is never a visitor's.
  """
  @spec for_nicks([String.t()]) :: %{String.t() => String.t()}
  def for_nicks(nicknames) do
    nicknames = nicknames |> Enum.filter(&is_binary/1) |> Enum.uniq()

    live = Map.new(for nick <- nicknames, locale = live_locale(nick), do: {nick, locale})

    {guests, members} =
      nicknames
      |> Enum.reject(&Map.has_key?(live, &1))
      |> Enum.split_with(&NicknameValidator.guest?/1)

    stored = stored(members)

    live
    |> Map.merge(guest_locales(guests))
    |> Map.merge(stored)
    |> Map.merge(bots(Enum.reject(members, &Map.has_key?(stored, &1))))
  end

  # Nobody registers a bot's nickname, so a name the rows did not answer for
  # may be one; the bot's own spelling is matched back to the one asked for.
  defp bots([]), do: %{}

  defp bots(nicknames) do
    by_key = Map.new(nicknames, &{Nickname.key(&1), &1})

    nicknames
    |> BotQueries.locales_by_nickname()
    |> Map.new(fn {nickname, locale} -> {Map.fetch!(by_key, Nickname.key(nickname)), locale} end)
  end

  defp live_locale(nickname) do
    case Tracker.meta(Topics.presence(), nickname) do
      %{locale: locale} when is_binary(locale) -> locale
      _absent -> nil
    end
  end

  # The registry is a process of the running application; a node without it
  # (a script, a test that started nothing) has no visitors to ask about.
  defp guest_locales([]), do: %{}

  defp guest_locales(nicknames) do
    if Process.whereis(GuestNames), do: GuestNames.locales(nicknames), else: %{}
  end

  defp stored([]), do: %{}

  defp stored(nicknames) do
    # The lookup folds case, and the answer comes back under the spelling the
    # caller used.
    by_key = Map.new(nicknames, &{Nickname.key(&1), &1})

    RegisteredNick
    |> where([n], key_of(n.nickname) in ^Map.keys(by_key))
    |> where([n], not is_nil(n.locale))
    |> select([n], {key_of(n.nickname), n.locale})
    |> Repo.all()
    |> Map.new(fn {key, locale} -> {Map.fetch!(by_key, key), locale} end)
  end

  # `:unchanged` when the row already said so — or there is no row: an
  # unregistered nickname is answered from presence alone, and its arrival is
  # told by the join that lists it.
  defp store(nickname, locale) do
    {count, _} =
      RegisteredNick
      |> where([n], matches(n.nickname, nickname))
      |> where([n], is_nil(n.locale) or n.locale != ^locale)
      |> Repo.update_all(set: [locale: locale])

    if count > 0, do: :changed, else: :unchanged
  end
end
