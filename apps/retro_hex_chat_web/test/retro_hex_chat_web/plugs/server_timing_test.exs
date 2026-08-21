defmodule RetroHexChatWeb.Plugs.ServerTimingTest do
  use ExUnit.Case, async: true

  import Plug.Test, only: [conn: 3]

  require OpenTelemetry.Tracer

  alias OpenTelemetry.Tracer
  alias RetroHexChatWeb.Plugs.ServerTiming

  @moduletag :unit

  describe "call/2" do
    test "publishes the active span as a Server-Timing traceparent entry" do
      conn =
        Tracer.with_span "request" do
          call()
        end

      assert [value] = Plug.Conn.get_resp_header(conn, "server-timing")
      assert value =~ ~r/^traceparent;desc="00-[0-9a-f]{32}-[0-9a-f]{16}-0[01]"$/
    end

    test "omits the header entirely when there is no span to publish" do
      assert Plug.Conn.get_resp_header(call(), "server-timing") == []
    end

    test "leaves the rest of the response untouched" do
      conn =
        Tracer.with_span "request" do
          call()
        end

      refute conn.halted
      assert conn.status == nil
    end
  end

  defp call, do: ServerTiming.call(conn(:get, "/chat", nil), ServerTiming.init([]))
end
