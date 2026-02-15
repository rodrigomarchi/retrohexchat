defmodule RetroHexChatWeb.Components.ConnectionProgressTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.ConnectionProgress

  describe "connection_progress/1" do
    test "renders steps with first step in-progress" do
      html =
        render_component(&ConnectionProgress.connection_progress/1,
          step: 1,
          timeout: false
        )

      assert html =~ "connection-progress"
      assert html =~ "connection-progress__step--in-progress"
      assert html =~ "connection-progress__step--pending"
    end

    test "shows completed step with checkmark" do
      html =
        render_component(&ConnectionProgress.connection_progress/1,
          step: 2,
          timeout: false
        )

      assert html =~ "✓"
      assert html =~ "connection-progress__step--completed"
    end

    test "shows in-progress step with hourglass" do
      html =
        render_component(&ConnectionProgress.connection_progress/1,
          step: 1,
          timeout: false
        )

      assert html =~ "⏳"
    end

    test "renders retry button when timeout is true" do
      html =
        render_component(&ConnectionProgress.connection_progress/1,
          step: 1,
          timeout: true
        )

      assert html =~ "Retry"
    end

    test "does not render retry button when timeout is false" do
      html =
        render_component(&ConnectionProgress.connection_progress/1,
          step: 1,
          timeout: false
        )

      refute html =~ "Retry"
    end

    test "renders all three steps" do
      html =
        render_component(&ConnectionProgress.connection_progress/1,
          step: 3,
          timeout: false
        )

      assert html =~ "Resolving server"
      assert html =~ "Connecting"
      assert html =~ "Waiting for response"
    end

    test "step 3 shows first two completed and third in-progress" do
      html =
        render_component(&ConnectionProgress.connection_progress/1,
          step: 3,
          timeout: false
        )

      # Two completed checkmarks
      assert length(Regex.scan(~r/connection-progress__step--completed/, html)) == 2
      # One in-progress
      assert length(Regex.scan(~r/connection-progress__step--in-progress/, html)) == 1
    end
  end
end
