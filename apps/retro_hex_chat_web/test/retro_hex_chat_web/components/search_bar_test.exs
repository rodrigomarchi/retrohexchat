defmodule RetroHexChatWeb.Components.SearchBarTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.SearchBar

  describe "search_bar/1" do
    test "does not render when visible is false" do
      html =
        render_component(&SearchBar.search_bar/1,
          visible: false,
          query: "",
          result_count: 0,
          current_index: 0
        )

      refute html =~ "search-bar"
    end

    test "renders input and buttons when visible" do
      html =
        render_component(&SearchBar.search_bar/1,
          visible: true,
          query: "",
          result_count: 0,
          current_index: 0
        )

      assert html =~ "search-bar"
      assert html =~ "Prev"
      assert html =~ "Next"
      assert html =~ "Find"
    end

    test "shows 'No results' when result_count is 0" do
      html =
        render_component(&SearchBar.search_bar/1,
          visible: true,
          query: "test",
          result_count: 0,
          current_index: 0
        )

      assert html =~ "No results"
    end

    test "shows 'X of Y' with results" do
      html =
        render_component(&SearchBar.search_bar/1,
          visible: true,
          query: "test",
          result_count: 5,
          current_index: 2
        )

      assert html =~ "2 of 5"
    end

    test "buttons are disabled when no results" do
      html =
        render_component(&SearchBar.search_bar/1,
          visible: true,
          query: "test",
          result_count: 0,
          current_index: 0
        )

      assert html =~ "disabled"
    end
  end
end
