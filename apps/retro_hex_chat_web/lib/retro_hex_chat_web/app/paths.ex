defmodule RetroHexChatWeb.App.Paths do
  @moduledoc """
  The app's own routes, built once.

  These were chat helpers until a surface that is not the chat — a call, a
  space, a game in its own tab — needed the same two paths: where a session
  goes when it is cleared, and where someone goes when they have no session.
  Both are properties of the app, not of the chat, and a second copy of
  `/chat/session/clear` is a string nobody would think to keep in step.
  """

  alias RetroHexChat.Games.Catalog
  alias RetroHexChatWeb.I18n
  alias RetroHexChatWeb.SEO
  alias RetroHexChatWeb.Site.Address
  alias RetroHexChatWeb.SpaceRef

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  @spec connect_path(Phoenix.LiveView.Socket.t()) :: String.t()
  def connect_path(_socket), do: localized(~p"/connect")

  @spec connect_path(Phoenix.LiveView.Socket.t(), String.t()) :: String.t()
  def connect_path(_socket, reason), do: localized(~p"/connect?reason=#{reason}")

  @doc """
  Where every surface's way back points.

  Takes no socket, unlike its neighbours here: they still do because they are
  called from places that have one, and this one is now also called from a
  component, which does not. A parameter that is ignored and then cannot be
  supplied is a signature that describes nothing — and Dialyzer said so.
  """
  @spec chat_path() :: String.t()
  def chat_path, do: localized("/")

  @doc """
  The chat, opened on a named channel: `/c/retro` for `#retro`. An ended
  call's card uses it, which is what keeps that card from being a dead end.
  """
  @spec chat_path(String.t()) :: String.t()
  def chat_path(channel) when is_binary(channel) and channel != "",
    do: localized(Address.channel_path(channel))

  def chat_path(_channel), do: chat_path()

  @doc """
  The sign-in window on the desktop, saying `feature` needs an account.
  Signing in there returns to `return_to`.

  Where every entry point sends somebody without an account — a game, a call,
  a space, the arcade — so the explanation and the way back are the same
  everywhere.
  """
  @spec visitor_sign_in_path(atom(), String.t()) :: String.t()
  def visitor_sign_in_path(feature, return_to) when is_atom(feature) and is_binary(return_to),
    do: localized(~p"/connect?#{[signup: feature, return_to: return_to]}")

  @doc """
  The desktop with the arcade open on one game, by its catalogue id — or,
  with no id, on its catalogue.
  """
  @spec chat_arcade_path(String.t()) :: String.t()
  def chat_arcade_path(game_id \\ ""), do: localized(~p"/?arcade=#{game_id}")

  @doc "The programs a link may open on the desktop, by window id."
  @spec linkable_windows() :: [String.t()]
  def linkable_windows, do: ~w(paint ascii-art)

  @doc "The desktop with one of `linkable_windows/0` open."
  @spec chat_window_path(String.t()) :: String.t()
  def chat_window_path(id), do: localized(~p"/?open=#{id}")

  @doc "`path` in the language of the current reader."
  @spec localized(String.t()) :: String.t()
  def localized(path), do: SEO.localized_path(path, I18n.current_locale())

  @doc """
  A channel's public archive. The `#` cannot travel in a URL — everything
  after it belongs to the browser — so the address carries the name without it.
  """
  @spec archive_path(String.t()) :: String.t()
  def archive_path("#" <> slug), do: ~p"/archive/#{slug}"
  def archive_path(slug), do: ~p"/archive/#{slug}"

  @doc """
  A Retro Game's own page — its home in the desktop: how to play it, who is
  playing it now and who is winning. A mode's id leads to its game's page.
  """
  @spec game_page_path(String.t()) :: String.t()
  def game_page_path(game_id),
    do: localized("/games/" <> Catalog.slug(Catalog.base_id(game_id)))

  @doc "A game at its own address, by its catalogue id."
  @spec play_path(String.t()) :: String.t()
  def play_path(game_id), do: ~p"/play/#{game_id}"

  @doc "A conference at an address of its own, by its room token."
  @spec call_path(String.t()) :: String.t()
  def call_path(room_token), do: ~p"/call/#{room_token}"

  @doc """
  A space at an address of its own, by the id of the place itself.

  A space has no token because it has no session: it does not begin and does not
  end, so what a link to it names is the place. `SpaceRef` is what makes that id
  fit in a path segment.
  """
  @spec space_path(String.t()) :: String.t()
  def space_path(space_id), do: ~p"/space/#{SpaceRef.slug(space_id)}"

  @doc """
  A P2P session at an address of its own, by its session token.

  A session has a token because it *is* an event, with a beginning and an end —
  unlike a space, whose address names a place that has neither.
  """
  @spec p2p_path(String.t()) :: String.t()
  def p2p_path(session_token), do: ~p"/p2p/#{session_token}"

  @doc """
  A multiplayer match at an address of its own — the game, and the session it
  runs over.

  It is the same surface as `p2p_path/1` and deliberately not a second one: a
  match *is* a P2P session, and the game in the path is what the surface opens
  on rather than a different thing to open.
  """
  @spec play_match_path(String.t(), String.t()) :: String.t()
  def play_match_path(game_id, session_token), do: ~p"/play/#{game_id}/#{session_token}"

  @doc "A match offered in the open, watched: `/watch/<token>`."
  @spec watch_path(String.t()) :: String.t()
  def watch_path(session_token), do: ~p"/watch/#{session_token}"

  @doc """
  An arcade game at an address of ours.

  The bundle lives on a static host whose URL is a deployment detail; this is
  the name that can be pasted, and it redirects.
  """
  @spec arcade_path(String.t()) :: String.t()
  def arcade_path(game_id), do: ~p"/play/arcade/#{game_id}"

  @spec session_clear_path(Phoenix.LiveView.Socket.t(), String.t()) :: String.t()
  def session_clear_path(socket, reason), do: session_clear_path(socket, reason, [])

  @spec session_clear_path(Phoenix.LiveView.Socket.t(), String.t(), keyword()) :: String.t()
  def session_clear_path(_socket, reason, opts) do
    query =
      [reason: reason]
      |> maybe_put_query(:forget_device, "true", Keyword.get(opts, :forget_device, false))

    ~p"/chat/session/clear?#{query}"
  end

  defp maybe_put_query(query, key, value, true) when is_binary(value) and value != "" do
    Keyword.put(query, key, value)
  end

  defp maybe_put_query(query, _key, _value, _condition), do: query
end
