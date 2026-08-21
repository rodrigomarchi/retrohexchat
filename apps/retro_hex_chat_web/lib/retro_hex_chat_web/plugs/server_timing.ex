defmodule RetroHexChatWeb.Plugs.ServerTiming do
  @moduledoc """
  Publishes the request's trace to the browser through the `Server-Timing` header.

  Grafana Faro reads the `traceparent` entry from this header and records it
  against the session, which is what lets a browser session be followed into
  the backend trace that served it. It is a link, not a join: the document's
  own page-load trace is parented by the `<meta name="traceparent">` the layout
  renders instead.

  The header is only written for a request that runs under a valid span, so
  tracing being off leaves the response untouched.
  """

  import Plug.Conn

  alias RetroHexChatWeb.TraceContext

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    case TraceContext.traceparent() do
      nil -> conn
      traceparent -> put_resp_header(conn, "server-timing", ~s(traceparent;desc="#{traceparent}"))
    end
  end
end
