defmodule RetroHexChatWeb.Plugs.PutBrowserId do
  @moduledoc """
  Names this browser, minting the name on first sight, and mirrors it into the
  session for LiveViews.

  A browser that refuses the cookie is not a failure case with a branch of its
  own: it arrives with no name every time, and everything keyed on the name
  behaves the way it did when one nickname had one snapshot.
  """

  import Plug.Conn

  alias RetroHexChatWeb.App.BrowserIdCookie

  @spec init(keyword()) :: keyword()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def call(conn, _opts) do
    conn = fetch_cookies(conn)

    case BrowserIdCookie.fetch(conn) do
      value when is_binary(value) and value != "" ->
        put_session(conn, :browser_id, value)

      _missing ->
        value = BrowserIdCookie.generate()

        conn
        |> BrowserIdCookie.put(value)
        |> put_session(:browser_id, value)
    end
  end
end
