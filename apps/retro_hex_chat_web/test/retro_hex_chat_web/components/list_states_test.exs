defmodule RetroHexChatWeb.Components.UI.ListStatesTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.ListStates

  @moduletag :unit

  describe "list_empty_state/1" do
    test "renders the title it was given" do
      html = render_component(&list_empty_state/1, title: "No contacts saved")

      assert html =~ "No contacts saved"
      assert html =~ ~s(data-testid="list-empty-state")
    end

    test "renders the optional supporting text" do
      html =
        render_component(&list_empty_state/1,
          title: "No channels found",
          text: "Try a different filter."
        )

      assert html =~ "Try a different filter."
    end

    test "omits the supporting text when there is none" do
      html = render_component(&list_empty_state/1, title: "Nothing here")

      refute html =~ "list-empty-state__text"
    end
  end

  describe "list_end_marker/1" do
    test "tells the reader the list is exhausted" do
      html = render_component(&list_end_marker/1, %{})

      assert html =~ ~s(data-testid="list-end-marker")
    end

    test "is announced politely rather than interrupting" do
      html = render_component(&list_end_marker/1, %{})

      assert html =~ ~s(role="status")
      assert html =~ ~s(aria-live="polite")
    end
  end

  describe "list_load_more_button/1" do
    test "is a real button, reachable by keyboard" do
      html = render_component(&list_load_more_button/1, target: "1")

      assert html =~ "<button"
      assert html =~ ~s(data-testid="list-load-more")
    end

    test "reports the in-flight state to assistive tech" do
      html = render_component(&list_load_more_button/1, target: "1", loading: true)

      assert html =~ ~s(aria-busy="true")
      assert html =~ "disabled"
    end

    test "is not busy when idle" do
      html = render_component(&list_load_more_button/1, target: "1")

      assert html =~ ~s(aria-busy="false")
    end
  end

  describe "list_count_strip/1" do
    test "shows the shown-of-total counter that a truncated list must never hide" do
      html = render_component(&list_count_strip/1, shown: 100, total: 5000)

      assert html =~ "100"
      assert html =~ "5000"
      assert html =~ ~s(data-testid="list-count-strip")
    end

    test "renders nothing when the total is unknown" do
      html = render_component(&list_count_strip/1, shown: 100, total: nil)

      refute html =~ "list-count-strip"
    end

    test "renders nothing when everything is on screen" do
      # A counter that always says "12 of 12" is noise; it exists to disclose
      # truncation, so it only appears when something is actually hidden.
      html = render_component(&list_count_strip/1, shown: 12, total: 12)

      refute html =~ "list-count-strip"
    end
  end

  describe "list_error_retry/1" do
    test "surfaces the failure and offers a way out" do
      html = render_component(&list_error_retry/1, on_retry: "reload_bans", target: "1")

      assert html =~ ~s(data-testid="list-error-retry")
      assert html =~ "reload_bans"
      assert html =~ "<button"
    end

    test "is announced assertively, unlike the other states" do
      # A failed page is the one list state the reader must not scroll past
      # without noticing.
      html = render_component(&list_error_retry/1, on_retry: "reload", target: "1")

      assert html =~ ~s(role="alert")
    end
  end

  describe "list_announcer/1" do
    test "is an empty polite live region when there is nothing to say" do
      html = render_component(&list_announcer/1, %{})

      assert html =~ ~s(aria-live="polite")
      assert html =~ ~s(aria-atomic="true")
    end

    test "announces what arrived, not merely that something is loading" do
      html = render_component(&list_announcer/1, message: "20 items loaded")

      assert html =~ "20 items loaded"
    end

    test "is hidden from sight but present for screen readers" do
      html = render_component(&list_announcer/1, message: "20 items loaded")

      assert html =~ "sr-only"
    end
  end

  describe "list_skeleton/1" do
    test "renders a placeholder row per expected item" do
      html = render_component(&list_skeleton/1, rows: 5)

      assert html =~ ~s(data-testid="list-skeleton")
      assert length(String.split(html, "list-skeleton__row")) - 1 == 5
    end

    test "is hidden from assistive tech — it carries no information" do
      html = render_component(&list_skeleton/1, rows: 3)

      assert html =~ ~s(aria-hidden="true")
    end
  end
end
