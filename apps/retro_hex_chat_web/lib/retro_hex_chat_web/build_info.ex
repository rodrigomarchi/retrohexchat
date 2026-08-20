defmodule RetroHexChatWeb.BuildInfo do
  @moduledoc """
  Build identity surfaced to the browser.

  The version is stamped onto a `<meta name="faro-app-version">` tag so
  Grafana Faro can label every RUM event and trace with the release that
  produced it. A release sets `APP_VERSION` (typically a git SHA); otherwise
  the compiled application version is used.
  """

  @spec version() :: String.t()
  def version do
    case System.get_env("APP_VERSION") do
      nil -> Application.spec(:retro_hex_chat_web, :vsn) |> to_string()
      "" -> Application.spec(:retro_hex_chat_web, :vsn) |> to_string()
      value -> value
    end
  end
end
