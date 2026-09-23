defmodule RetroHexChatWeb.App.BrowserIdCookie do
  @moduledoc """
  The long-lived, opaque name of one browser.

  It identifies a browser, never a person: nothing is stored against it but what
  that browser had on screen, and two people sharing a machine but not a browser
  profile have two of these. It exists because "what did I have open" is a fact
  about a screen — a desktop and a phone signed in as the same person are two
  screens — and without a name for the screen the second one would overwrite the
  first.

  Read on the initial page load, like the trusted-device cookie beside it: a
  LiveView mounted over the socket cannot set a cookie, so the plug is where the
  value is minted and mirrored into the session.
  """

  import Plug.Conn

  @cookie_name "_rhc_browser"

  # Long enough that coming back next season still finds the conversation where
  # it was left; the value is worthless to anybody who steals it.
  @max_age 400 * 24 * 60 * 60

  @spec name() :: String.t()
  def name, do: @cookie_name

  @spec max_age() :: pos_integer()
  def max_age, do: @max_age

  @spec fetch(Plug.Conn.t()) :: String.t() | nil
  def fetch(conn) do
    conn = fetch_cookies(conn)
    conn.req_cookies[@cookie_name]
  end

  @spec put(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def put(conn, value) do
    put_resp_cookie(conn, @cookie_name, value,
      max_age: @max_age,
      http_only: true,
      same_site: "Lax",
      secure: conn.scheme == :https
    )
  end

  @spec generate() :: String.t()
  def generate, do: 18 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
end
