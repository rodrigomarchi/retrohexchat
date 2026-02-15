defmodule RetroHexChatWeb.Components.LoadingSpinnerTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.LoadingSpinner

  describe "loading_spinner/1" do
    test "renders spinner with text when loading is true" do
      html =
        render_component(&LoadingSpinner.loading_spinner/1,
          loading: true,
          text: "Loading messages...",
          timeout: false
        )

      assert html =~ "loading-spinner"
      assert html =~ "Loading messages..."
    end

    test "renders nothing when loading is false" do
      html =
        render_component(&LoadingSpinner.loading_spinner/1,
          loading: false,
          text: "Loading messages...",
          timeout: false
        )

      refute html =~ "loading-spinner"
    end

    test "renders retry button when timeout is true" do
      html =
        render_component(&LoadingSpinner.loading_spinner/1,
          loading: true,
          text: "Loading messages...",
          timeout: true
        )

      assert html =~ "Retry"
      assert html =~ "loading-spinner__retry"
    end

    test "does not render retry button when timeout is false" do
      html =
        render_component(&LoadingSpinner.loading_spinner/1,
          loading: true,
          text: "Loading messages...",
          timeout: false
        )

      refute html =~ "Retry"
    end

    test "spinner does not block pointer events" do
      html =
        render_component(&LoadingSpinner.loading_spinner/1,
          loading: true,
          text: "Loading...",
          timeout: false
        )

      assert html =~ "loading-spinner"
    end

    test "uses default text when not provided" do
      html =
        render_component(&LoadingSpinner.loading_spinner/1,
          loading: true,
          timeout: false
        )

      assert html =~ "Loading messages..."
    end
  end
end
