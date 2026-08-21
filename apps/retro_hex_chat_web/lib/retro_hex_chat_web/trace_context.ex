defmodule RetroHexChatWeb.TraceContext do
  @moduledoc """
  Renders the request's OpenTelemetry span as a W3C `traceparent`.

  The browser and the server each record their own trace for the same page
  view, and nothing joins them unless the server hands its context over. Two
  carriers do that, and they are not interchangeable:

    * the `Server-Timing` response header (`Plugs.ServerTiming`), which lets
      Grafana Faro *link* a session to the backend trace that served it;
    * a `<meta name="traceparent">` in the document head, which Faro's tracing
      instrumentation adopts as the parent of the page-load trace, putting
      browser and server spans in one trace.

  Both read the span that is current when they run, which is why the value
  lives here rather than in either caller.
  """

  require OpenTelemetry.Tracer

  alias OpenTelemetry.Span
  alias OpenTelemetry.Tracer

  @doc """
  The current span as a `traceparent` value, or nil when there is no valid span.
  """
  @spec traceparent() :: String.t() | nil
  def traceparent, do: format(Tracer.current_span_ctx())

  @spec format(:undefined | tuple()) :: String.t() | nil
  defp format(:undefined), do: nil

  defp format(span_ctx) do
    if Span.is_valid(span_ctx) do
      # The sampled flag reports what this node knows. A span the collector
      # drops downstream still advertises itself as sampled here — the browser
      # is being told what the server recorded, not what survived.
      flags = if Span.is_recording(span_ctx), do: "01", else: "00"

      "00-#{Span.hex_trace_id(span_ctx)}-#{Span.hex_span_id(span_ctx)}-#{flags}"
    end
  end
end
