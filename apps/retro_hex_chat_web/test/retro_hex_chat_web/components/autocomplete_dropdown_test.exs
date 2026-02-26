defmodule RetroHexChatWeb.Components.AutocompleteDropdownTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.AutocompleteDropdown

  @moduletag :liveview

  describe "autocomplete_dropdown/1" do
    test "does not render when not visible" do
      html =
        render_component(&AutocompleteDropdown.autocomplete_dropdown/1,
          visible: false,
          mode: :command,
          results: [],
          selected: 0
        )

      refute html =~ "autocomplete-dropdown"
    end

    test "renders command mode with results" do
      results = [
        %{name: "join", description: "Join a channel", matched_chars: [0, 1], score: 1004},
        %{name: "part", description: "Leave a channel", matched_chars: [], score: 500}
      ]

      html =
        render_component(&AutocompleteDropdown.autocomplete_dropdown/1,
          visible: true,
          mode: :command,
          results: results,
          selected: 0
        )

      assert html =~ "autocomplete-dropdown"
      assert html =~ "Commands"
      assert html =~ "join"
      assert html =~ "part"
    end

    test "applies selected class to correct item" do
      results = [
        %{name: "join", description: "Join a channel", matched_chars: [], score: 1000},
        %{name: "part", description: "Leave a channel", matched_chars: [], score: 500}
      ]

      html =
        render_component(&AutocompleteDropdown.autocomplete_dropdown/1,
          visible: true,
          mode: :command,
          results: results,
          selected: 1
        )

      assert html =~ "selected"
    end

    test "highlights fuzzy-matched characters with strong tags" do
      results = [
        %{name: "join", description: "Join a channel", matched_chars: [0, 1], score: 1004}
      ]

      html =
        render_component(&AutocompleteDropdown.autocomplete_dropdown/1,
          visible: true,
          mode: :command,
          results: results,
          selected: 0
        )

      assert html =~ "<strong>"
    end

    test "groups consecutive matched characters into a single strong tag" do
      # "alias" with matched_chars [0, 1, 2] should produce <strong>ali</strong><span>as</span>
      # NOT <strong>a</strong><strong>l</strong><strong>i</strong><span>a</span><span>s</span>
      results = [
        %{name: "alias", description: "Create alias", matched_chars: [0, 1, 2], score: 1000}
      ]

      html =
        render_component(&AutocompleteDropdown.autocomplete_dropdown/1,
          visible: true,
          mode: :command,
          results: results,
          selected: 0
        )

      assert html =~ "<strong>ali</strong>"
      assert html =~ "<span>as</span>"
      # Must NOT have individual character wrapping
      refute html =~ "<strong>a</strong>"
    end

    test "groups consecutive unmatched characters into a single span tag" do
      # "away" with matched_chars [0, 3] should produce:
      # <strong>a</strong><span>wa</span><strong>y</strong>
      results = [
        %{name: "away", description: "Go away", matched_chars: [0, 3], score: 1000}
      ]

      html =
        render_component(&AutocompleteDropdown.autocomplete_dropdown/1,
          visible: true,
          mode: :command,
          results: results,
          selected: 0
        )

      assert html =~ "<strong>a</strong>"
      assert html =~ "<span>wa</span>"
      assert html =~ "<strong>y</strong>"
    end

    test "renders all unmatched text in a single span when no matches" do
      results = [
        %{name: "help", description: "Show help", matched_chars: [], score: 1000}
      ]

      html =
        render_component(&AutocompleteDropdown.autocomplete_dropdown/1,
          visible: true,
          mode: :command,
          results: results,
          selected: 0
        )

      assert html =~ "<span>help</span>"
      refute html =~ "<strong>"
    end

    test "renders category headers as non-selectable items" do
      results = [
        "Básicos",
        %{name: "help", description: "Show help", matched_chars: [], score: 1000}
      ]

      html =
        render_component(&AutocompleteDropdown.autocomplete_dropdown/1,
          visible: true,
          mode: :command,
          results: results,
          selected: 0
        )

      assert html =~ "autocomplete-category-header"
      assert html =~ "Básicos"
    end

    test "renders nick mode with status indicators" do
      results = [
        %{
          nickname: "Mario",
          status: :online,
          color_class: "nick-color-3",
          joined?: false,
          score: 500
        }
      ]

      html =
        render_component(&AutocompleteDropdown.autocomplete_dropdown/1,
          visible: true,
          mode: :nick,
          results: results,
          selected: 0
        )

      assert html =~ "Nicknames"
      assert html =~ "Mario"
      assert html =~ "autocomplete-status-online"
    end

    test "renders channel mode with user counts and joined indicator" do
      results = [
        %{name: "#dev", user_count: 5, joined?: true, score: 800}
      ]

      html =
        render_component(&AutocompleteDropdown.autocomplete_dropdown/1,
          visible: true,
          mode: :channel,
          results: results,
          selected: 0
        )

      assert html =~ "Channels"
      assert html =~ "#dev"
      assert html =~ "5 users"
      assert html =~ "✓"
    end
  end
end
