defmodule RetroHexChatWeb.Plugs.PutLocale do
  @moduledoc """
  Restores the Gettext locale for browser requests and stores inferred locale in session.
  """

  import Plug.Conn

  alias RetroHexChatWeb.I18n

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    param_locale = conn.params["locale"]
    session_locale = get_session(conn, :locale)
    accept_language = conn |> get_req_header("accept-language") |> List.first()
    locale = I18n.resolve_locale(param_locale, session_locale, accept_language)

    I18n.put_locale(locale)

    conn
    |> put_session(:locale, locale)
    |> assign(:locale, locale)
  end
end
