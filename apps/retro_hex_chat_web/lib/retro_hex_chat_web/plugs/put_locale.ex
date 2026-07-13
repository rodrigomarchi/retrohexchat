defmodule RetroHexChatWeb.Plugs.PutLocale do
  @moduledoc """
  Restores the Gettext locale for browser requests and stores inferred locale in session.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  alias RetroHexChatWeb.I18n
  alias RetroHexChatWeb.SEO

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, :public) do
    path_locale = path_locale(conn)
    session_locale = conn |> get_session(:locale) |> I18n.normalize_locale()
    accept_language = conn |> get_req_header("accept-language") |> List.first()

    locale =
      path_locale ||
        session_locale ||
        I18n.locale_from_accept_language(accept_language) ||
        I18n.default_locale()

    if should_redirect_public_locale?(conn, path_locale, locale) do
      I18n.put_locale(locale)

      conn
      |> put_session(:locale, locale)
      |> redirect(to: SEO.localized_path(conn.request_path, locale))
      |> halt()
    else
      render_locale = path_locale || I18n.default_locale()
      I18n.put_locale(render_locale)

      conn
      |> maybe_put_public_locale(path_locale)
      |> assign(:locale, render_locale)
    end
  end

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

  defp path_locale(%{path_info: [segment | _rest]}) do
    SEO.locale_from_segment(segment)
  end

  defp path_locale(_conn), do: nil

  defp should_redirect_public_locale?(conn, path_locale, locale) do
    is_nil(path_locale) &&
      locale != I18n.default_locale() &&
      redirectable_public_path?(conn.request_path)
  end

  defp redirectable_public_path?("/sitemap.xml"), do: false
  defp redirectable_public_path?(_path), do: true

  defp maybe_put_public_locale(conn, nil), do: conn
  defp maybe_put_public_locale(conn, locale), do: put_session(conn, :locale, locale)
end
