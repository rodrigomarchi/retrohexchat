defmodule RetroHexChatWeb.ChatLive.Components.HighlightDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.HighlightWords
  alias RetroHexChatWeb.ChatLive.Components.HighlightDialog

  @moduletag :unit

  defp session(highlight_words \\ HighlightWords.new()) do
    "Nick" |> Session.new() |> Session.set_highlight_words(highlight_words)
  end

  defp dialog(overrides) do
    base = %{id: HighlightDialog.id(), session: session()}
    render_component(HighlightDialog, Map.merge(base, overrides))
  end

  test "exposes a stable id" do
    assert HighlightDialog.id() == "highlight-dialog"
  end

  test "renders the bare panel with the own-nick row (the window provides the chrome)" do
    html = dialog(%{})

    assert html =~ ~s(data-testid="highlight-panel")
    assert html =~ "Nick"
    # No sub-form until requested.
    refute html =~ ~s(data-testid="highlight-add-form")
  end

  test "renders highlight word rows from the session with their color" do
    {:ok, words} = HighlightWords.add_entry(HighlightWords.new(), "spark", 9)

    html =
      render_component(HighlightDialog, %{
        id: HighlightDialog.id(),
        session: session(words)
      })

    assert html =~ ~s(data-testid="highlight-word-row-spark")
    assert html =~ "irc-bg-9"
  end

  test "renders the add sub-form as a window-scoped modal targeting the component" do
    html = dialog(%{show_highlight_add_dialog: true})

    assert html =~ ~s(data-testid="highlight-add-form")
    # Scoped to the enclosing desktop window, not the viewport.
    assert html =~ ~s(id="highlight-add-dialog-bg" class="absolute inset-0)
    # The form and its swatches submit to the island that owns their DOM (§0a-anti).
    assert html =~ ~s(phx-target=)
    assert html =~ ~s(id="highlight-add-color")
  end

  test "renders the edit sub-form with the selected word and color" do
    {:ok, words} = HighlightWords.add_entry(HighlightWords.new(), "spark", 4)

    html =
      render_component(HighlightDialog, %{
        id: HighlightDialog.id(),
        session: session(words),
        highlight_selected: "spark",
        show_highlight_edit_dialog: true
      })

    assert html =~ ~s(data-testid="highlight-edit-form")
    assert html =~ ~s(id="highlight-edit-dialog-bg" class="absolute inset-0)
  end
end
