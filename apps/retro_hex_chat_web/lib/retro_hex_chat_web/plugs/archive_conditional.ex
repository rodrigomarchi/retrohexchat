defmodule RetroHexChatWeb.Plugs.ArchiveConditional do
  @moduledoc """
  The archive's HTTP manners, decided before the desktop renders a page of it.

  Archive pages exist to be swept by robots, and a robot that can revalidate
  cheaply sweeps more of them: a request whose `If-None-Match` matches the
  page's `etag` is answered `304` here, without rendering. A channel that does
  not publish is a `404` (never a `403`, which would confirm it exists).

  Every answer carries `max-age=0, must-revalidate`. Switching an archive off
  must take its pages down on the next request, and a cache holding one for
  even five minutes keeps serving what a founder withdrew. `private`, because
  the page is rendered on a desktop that can carry the reader's own session.
  """
  @behaviour Plug

  import Plug.Conn

  alias RetroHexChatWeb.Site.Pages.Archive

  @cache_control "private, max-age=0, must-revalidate"

  @impl Plug
  @spec init(keyword()) :: keyword()
  def init(opts), do: opts

  @impl Plug
  @spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def call(conn, _opts) do
    case Archive.data(conn.path_params |> Map.merge(conn.query_params)) do
      {:ok, data} -> conditional(conn, Archive.etag(data))
      :not_found -> not_found(conn)
    end
  end

  # An empty 404, answered before the desktop renders: whether the channel
  # exists, and what it is called, is not something this answer may show.
  defp not_found(conn) do
    conn
    |> put_resp_header("cache-control", @cache_control)
    |> put_resp_content_type("text/html")
    |> send_resp(404, "")
    |> halt()
  end

  defp conditional(conn, etag) do
    conn =
      conn
      |> put_resp_header("etag", etag)
      |> put_resp_header("cache-control", @cache_control)
      |> put_resp_header("vary", "cookie, accept-encoding")

    if etag_matches?(conn, etag) do
      conn
      |> send_resp(304, "")
      |> halt()
    else
      conn
    end
  end

  defp etag_matches?(conn, etag) do
    conn
    |> get_req_header("if-none-match")
    |> Enum.flat_map(&String.split(&1, ","))
    |> Enum.map(&String.trim/1)
    |> Enum.any?(&(&1 in ["*", etag]))
  end
end
