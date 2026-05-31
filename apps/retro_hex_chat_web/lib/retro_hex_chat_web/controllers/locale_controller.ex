defmodule RetroHexChatWeb.LocaleController do
  use RetroHexChatWeb, :controller

  alias RetroHexChatWeb.I18n

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"locale" => requested_locale} = params) do
    locale = I18n.normalize_locale(requested_locale) || I18n.default_locale()
    return_to = safe_return_to(params["return_to"])

    I18n.put_locale(locale)

    conn
    |> put_session(:locale, locale)
    |> redirect(to: return_to)
  end

  defp safe_return_to(path) when is_binary(path) do
    if String.starts_with?(path, "/") and
         not String.starts_with?(path, "//") and
         not String.contains?(path, "://") do
      path
    else
      ~p"/connect"
    end
  end

  defp safe_return_to(_path), do: ~p"/connect"
end
