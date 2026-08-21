defmodule RetroHexChatWeb.TraceContextLayoutTest do
  @moduledoc """
  The layouts hand the server's trace to the browser, and a rendered page is the
  only place that claim is checkable: the meta is emitted by a conditional in
  HEEx that compiles happily whether or not it ever produces a tag.
  """
  use RetroHexChatWeb.ConnCase, async: true

  require OpenTelemetry.Tracer

  alias OpenTelemetry.Tracer

  @moduletag :integration

  @meta ~r/<meta name="traceparent" content="(00-[0-9a-f]{32}-[0-9a-f]{16}-0[01])"/

  describe "traceparent meta" do
    test "the chat layout renders the active span", %{conn: conn} do
      html =
        Tracer.with_span "request" do
          conn |> get(~p"/connect") |> html_response(200)
        end

      assert html =~ @meta
    end

    test "the landing layout renders the active span", %{conn: conn} do
      html =
        Tracer.with_span "request" do
          conn |> get(~p"/") |> html_response(200)
        end

      assert html =~ @meta
    end

    test "a page rendered without a span carries no traceparent", %{conn: conn} do
      html = conn |> get(~p"/connect") |> html_response(200)

      refute html =~ "traceparent"
    end
  end
end
