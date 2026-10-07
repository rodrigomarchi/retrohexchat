defmodule RetroHexChatWeb.VersionController do
  @moduledoc """
  Serves `/version`: which build is answering this request.

  The deploy waits on it to know the new release is the one serving traffic —
  every backend, not the first to come up — before it does anything that
  depends on the new code being live. The release version is
  `<mix version>-<short git sha>` (see `RetroHexChatWeb.BuildInfo`); the
  commit is its last segment, or `null` outside a release.
  """
  use RetroHexChatWeb, :controller

  alias RetroHexChatWeb.BuildInfo

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, _params) do
    version = BuildInfo.version()

    conn
    |> put_resp_header("cache-control", "no-store")
    |> json(%{version: version, commit: commit(version)})
  end

  @spec commit(String.t()) :: String.t() | nil
  defp commit(version) do
    case Regex.run(~r/-([0-9a-f]{7,40})$/, version) do
      [_, sha] -> sha
      nil -> nil
    end
  end
end
