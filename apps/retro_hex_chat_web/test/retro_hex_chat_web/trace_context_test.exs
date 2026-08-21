defmodule RetroHexChatWeb.TraceContextTest do
  use ExUnit.Case, async: true

  require OpenTelemetry.Tracer

  alias OpenTelemetry.Span
  alias OpenTelemetry.Tracer
  alias RetroHexChatWeb.TraceContext

  @moduletag :unit

  # A W3C traceparent: version, 32-hex trace id, 16-hex span id, flags.
  @traceparent ~r/^00-[0-9a-f]{32}-[0-9a-f]{16}-0[01]$/

  describe "traceparent/0" do
    test "renders the active span in W3C format" do
      value =
        Tracer.with_span "test span" do
          TraceContext.traceparent()
        end

      assert value =~ @traceparent
    end

    test "carries the ids of the span that is actually current" do
      {value, span_ctx} =
        Tracer.with_span "test span" do
          {TraceContext.traceparent(), Tracer.current_span_ctx()}
        end

      assert value =~ Span.hex_trace_id(span_ctx)
      assert value =~ Span.hex_span_id(span_ctx)
    end

    test "gives each span its own span id under one trace" do
      {outer, inner} =
        Tracer.with_span "outer" do
          nested =
            Tracer.with_span "inner" do
              TraceContext.traceparent()
            end

          {TraceContext.traceparent(), nested}
        end

      assert outer != inner
      assert trace_id(outer) == trace_id(inner)
    end

    test "is nil outside a span, so a response without tracing is left alone" do
      refute TraceContext.traceparent()
    end
  end

  defp trace_id(traceparent), do: traceparent |> String.split("-") |> Enum.at(1)
end
