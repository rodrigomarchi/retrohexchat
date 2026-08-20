defmodule RetroHexChatWeb.BuildInfo do
  @moduledoc """
  Build identity surfaced to the browser.

  The version is stamped onto a `<meta name="faro-app-version">` tag so
  Grafana Faro can label every RUM event and trace with the release that
  produced it. In production the release version carries the git SHA
  (`deploy.sh` builds `<mix-vsn>-<short-sha>`, which the release exposes as
  `RELEASE_VSN`); `APP_VERSION` can override it, and outside a release the
  compiled application version is used.
  """

  @spec version() :: String.t()
  def version do
    case System.get_env("APP_VERSION") || System.get_env("RELEASE_VSN") do
      value when is_binary(value) and value != "" -> value
      _ -> Application.spec(:retro_hex_chat_web, :vsn) |> to_string()
    end
  end
end
