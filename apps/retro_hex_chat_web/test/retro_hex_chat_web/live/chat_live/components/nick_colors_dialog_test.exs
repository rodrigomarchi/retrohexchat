defmodule RetroHexChatWeb.ChatLive.Components.NickColorsDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChat.Accounts.{NickColors, NickLocales, Session}
  alias RetroHexChat.Services.NickServ
  alias RetroHexChatWeb.ChatLive.Components.NickColorsDialog

  @moduletag :unit

  # A registered nickname whose language is on its row, as it is for somebody
  # who opened the chat in Portuguese and left.
  defp speaker(prefix) do
    nickname = "#{prefix}#{System.unique_integer([:positive])}"
    {:ok, _nick} = NickServ.register(nickname, "password123")
    :ok = NickLocales.remember(nickname, "pt_BR", store: true)
    nickname
  end

  defp dialog(overrides) do
    sess = Map.get(overrides, :session, Session.new("Nick"))
    base = %{id: NickColorsDialog.id(), session: sess}
    render_component(NickColorsDialog, Map.merge(base, Map.delete(overrides, :session)))
  end

  test "renders the bare panel (no modal chrome)" do
    html = dialog(%{})

    assert html =~ "No custom colors set. Nicknames use automatic colors."
  end

  test "renders nick-color rows from the session" do
    {:ok, colors} = NickColors.add_entry(NickColors.new(), "ColorBud", 4)
    html = dialog(%{session: Session.set_nick_colors(Session.new("Nick"), colors)})

    assert html =~ "ColorBud"
    assert html =~ "irc-bg-4"
  end

  test "draws each coloured nickname's language flag beside it" do
    nickname = speaker("Col")
    {:ok, colors} = NickColors.add_entry(NickColors.new(), nickname, 4)
    html = dialog(%{session: Session.set_nick_colors(Session.new("Nick"), colors)})

    assert [_flag] =
             html
             |> Floki.parse_fragment!()
             |> Floki.find(
               ~s(#nick-color-entry-#{nickname} [data-testid="nick-flag"][data-locale="pt_BR"])
             )
  end

  test "renders the add sub-form targeting the component" do
    html = dialog(%{show_add_dialog: true})

    assert html =~ ~s(data-testid="nick-color-add-form")
    assert html =~ ~s(phx-target=)
  end
end
