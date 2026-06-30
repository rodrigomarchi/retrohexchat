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

  test "renders only the (empty) mount wrapper when closed (show defaults false)" do
    html = dialog(%{})

    assert html =~ ~s(id="highlight-dialog-mount")
    refute html =~ ~s(id="highlight-dialog-show-trigger")
  end

  test "renders the dialog and own-nick row when shown" do
    html = dialog(%{show: true})

    assert html =~ ~s(id="highlight-dialog-show-trigger")
    assert html =~ "Highlight Words"
    assert html =~ "Nick"
  end

  test "renders highlight word rows from the session with their color" do
    {:ok, words} = HighlightWords.add_entry(HighlightWords.new(), "spark", 9)

    html =
      render_component(HighlightDialog, %{
        id: HighlightDialog.id(),
        session: session(words),
        show: true
      })

    assert html =~ ~s(data-testid="highlight-word-row-spark")
    assert html =~ "irc-bg-9"
  end

  test "renders the add sub-form with its color picker targeting the component" do
    html = dialog(%{show: true, show_highlight_add_dialog: true})

    assert html =~ ~s(data-testid="highlight-add-form")
    # The form and its swatches submit to the island that owns their DOM (§0a-anti).
    assert html =~ ~s(phx-target=)
    assert html =~ ~s(id="highlight-add-color")
  end
end
