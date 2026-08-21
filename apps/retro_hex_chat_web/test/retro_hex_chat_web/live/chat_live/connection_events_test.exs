defmodule RetroHexChatWeb.ChatLive.ConnectionEventsTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias RetroHexChatWeb.ChatLive.ConnectionEvents

  @moduletag :unit

  setup do
    on_exit(fn -> Logger.reset_metadata() end)
    :ok
  end

  defp socket, do: %Phoenix.LiveView.Socket{}

  describe "rum_session" do
    test "adopts the browser's session id into this process's metadata" do
      assert {:halt, _socket} =
               ConnectionEvents.handle_event("rum_session", %{"id" => "abc123"}, socket())

      assert Logger.metadata()[:rum_session_id] == "abc123"
    end

    test "records the join, so a quiet session still leaves a trace of it" do
      # The suite runs at level `none` by default, which would swallow the line
      # this test exists to see.
      previous = Logger.level()
      Logger.configure(level: :info)
      on_exit(fn -> Logger.configure(level: previous) end)

      log =
        capture_log(fn ->
          ConnectionEvents.handle_event("rum_session", %{"id" => "abc123"}, socket())
        end)

      assert log =~ "rum_session_adopted"
    end

    test "the formatter is configured to emit the key" do
      # Setting metadata the formatter drops is silent: the code looks right,
      # the tests pass, and nothing reaches Loki. This is the coupling that
      # failed in production on 2026-08-21.
      metadata = Application.get_env(:logger, :default_formatter)[:metadata]

      assert :rum_session_id in metadata
    end

    test "ignores an id that is missing, empty or implausibly long" do
      for params <- [%{}, %{"id" => ""}, %{"id" => String.duplicate("x", 65)}, %{"id" => 42}] do
        assert {:halt, _socket} = ConnectionEvents.handle_event("rum_session", params, socket())
        refute Logger.metadata()[:rum_session_id]
      end
    end
  end

  describe "unknown events" do
    test "are passed along untouched" do
      assert {:cont, _socket} = ConnectionEvents.handle_event("something_else", %{}, socket())
    end
  end
end
