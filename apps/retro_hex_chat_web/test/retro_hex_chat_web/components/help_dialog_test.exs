defmodule RetroHexChatWeb.Components.HelpDialogTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChat.Chat.HelpTopics
  alias RetroHexChatWeb.Components.HelpDialog

  @moduletag :unit

  @default_attrs %{
    visible: true,
    active_tab: "contents",
    selected_topic: nil,
    topics_by_category: HelpTopics.topics_by_category(),
    index_keywords: HelpTopics.all_keywords(),
    index_filter: "",
    search_query: "",
    search_results: []
  }

  describe "help_dialog/1" do
    test "renders when visible" do
      html = render_component(&HelpDialog.help_dialog/1, @default_attrs)

      assert html =~ "help-dialog"
      assert html =~ "RetroHexChat Help"
      assert html =~ "help-nav-pane"
      assert html =~ "help-content-pane"
    end

    test "does not render when not visible" do
      html = render_component(&HelpDialog.help_dialog/1, %{@default_attrs | visible: false})

      refute html =~ "help-dialog"
      refute html =~ "RetroHexChat Help"
    end

    test "shows Contents tab tree with all categories" do
      html = render_component(&HelpDialog.help_dialog/1, @default_attrs)

      assert html =~ "Getting Started"
      assert html =~ "Commands"
      assert html =~ "Services"
      assert html =~ "Channel Modes"
      assert html =~ "Text Formatting"
      assert html =~ "Features"
      assert html =~ "User Interface"
      assert html =~ "Keyboard Shortcuts"
    end

    test "shows empty state when no topic selected" do
      html = render_component(&HelpDialog.help_dialog/1, @default_attrs)

      assert html =~ "Select a topic from the navigation pane to get started."
    end

    test "shows selected topic content" do
      topic = HelpTopics.get_topic("welcome")

      html =
        render_component(&HelpDialog.help_dialog/1, %{@default_attrs | selected_topic: topic})

      assert html =~ "Welcome to RetroHexChat"
      refute html =~ "Select a topic from the navigation pane"
    end

    test "renders Index tab with filter input and keywords" do
      html =
        render_component(&HelpDialog.help_dialog/1, %{@default_attrs | active_tab: "index"})

      assert html =~ "help-index-filter"
      assert html =~ "help-tab-index"
    end

    test "renders filtered index keywords" do
      filtered =
        Enum.filter(HelpTopics.all_keywords(), fn {kw, _} -> String.contains?(kw, "join") end)

      html =
        render_component(&HelpDialog.help_dialog/1, %{
          @default_attrs
          | active_tab: "index",
            index_keywords: filtered,
            index_filter: "join"
        })

      assert html =~ "join"
      assert html =~ "help-index-filter"
    end

    test "renders Search tab with input and button" do
      html =
        render_component(&HelpDialog.help_dialog/1, %{@default_attrs | active_tab: "search"})

      assert html =~ "help-search-input"
      assert html =~ "help-search-btn"
    end

    test "renders search results" do
      results = HelpTopics.search("join")

      html =
        render_component(&HelpDialog.help_dialog/1, %{
          @default_attrs
          | active_tab: "search",
            search_query: "join",
            search_results: results
        })

      assert html =~ "help-result-cmd-join"
    end

    test "shows no results message for empty search" do
      html =
        render_component(&HelpDialog.help_dialog/1, %{
          @default_attrs
          | active_tab: "search",
            search_query: "zzzznonexistent",
            search_results: []
        })

      assert html =~ "No results found."
    end

    test "has close button" do
      html = render_component(&HelpDialog.help_dialog/1, @default_attrs)
      assert html =~ "help-dialog-close"
    end

    test "has all three tab buttons" do
      html = render_component(&HelpDialog.help_dialog/1, @default_attrs)
      assert html =~ "help-tab-contents"
      assert html =~ "help-tab-index"
      assert html =~ "help-tab-search"
    end
  end
end
