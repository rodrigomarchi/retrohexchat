defmodule RetroHexChatWeb.ChatLive.Helpers.NickFlags do
  @moduledoc """
  The languages a dialog's list of people is drawn with, looked up once for
  the whole list when the list is built.

  A window that names people — the authors of its mentions, pins or saved
  lines, the contacts it keeps — draws a flag beside each nickname
  (`Components.UI.NickFlag`). Asking `RetroHexChat.Accounts.NickLocales` per
  row would be a lookup per name on every render; these ask once per page or
  per list, and the windows keep the answer while the list is the same.

  A conversation's own roster already carries each member's language, so what
  is drawn beside a member (a PM tab, the reply bar) is read from it with
  `member_locale/2` rather than looked up again.
  """

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.Accounts.NickLocales
  alias RetroHexChat.Nickname
  alias RetroHexChat.Page

  @doc """
  Gives every row of `page` the language of the nickname under `nick_key`,
  as `:author_locale` — nil when nobody knows it, which draws no flag.
  """
  @spec put_author_locales(Page.t(), atom()) :: Page.t()
  def put_author_locales(%Page{items: items} = page, nick_key) do
    locales = items |> Enum.map(&Map.get(&1, nick_key)) |> NickLocales.for_nicks()

    Page.map(page, &Map.put(&1, :author_locale, Map.get(locales, Map.get(&1, nick_key))))
  end

  @doc """
  The languages of `nicknames`, keyed by nickname, reusing `cached` while the
  nicknames are the ones it was built for.

  `cached` is `{nicknames, locales}` from a previous call, or nil. The answer
  is the same pair, for the caller to keep.
  """
  @spec locales([String.t()], {[String.t()], map()} | nil) :: {[String.t()], map()}
  def locales(nicknames, {nicknames, _locales} = cached), do: cached
  def locales(nicknames, _cached), do: {nicknames, NickLocales.for_nicks(nicknames)}

  @doc """
  Assigns the languages of `nicknames` under `key`, keeping the
  `locales/2` pair under `cache_key` so the next call with the same
  nicknames asks nobody.
  """
  @spec assign_locales(Socket.t(), [String.t()], atom(), atom()) :: Socket.t()
  def assign_locales(socket, nicknames, key, cache_key) do
    {_nicknames, locales} = cache = locales(nicknames, socket.assigns[cache_key])
    Phoenix.Component.assign(socket, [{key, locales}, {cache_key, cache}])
  end

  @doc """
  The language of `nickname` as the conversation's roster carries it
  (`Chat.Roster` members), or nil when they are not on it.
  """
  @spec member_locale([map()] | nil, String.t() | nil) :: String.t() | nil
  def member_locale(members, nickname) do
    Enum.find_value(members || [], fn member ->
      if Nickname.equal?(member.nickname, nickname), do: Map.get(member, :locale)
    end)
  end
end
