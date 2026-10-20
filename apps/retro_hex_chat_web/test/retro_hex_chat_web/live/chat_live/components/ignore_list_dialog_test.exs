defmodule RetroHexChatWeb.ChatLive.Components.IgnoreListDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChat.Accounts.{NickLocales, Session}
  alias RetroHexChat.Chat.IgnoreList
  alias RetroHexChat.Services.NickServ
  alias RetroHexChatWeb.ChatLive.Components.IgnoreListDialog

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
    base = %{id: IgnoreListDialog.id(), session: sess}
    render_component(IgnoreListDialog, Map.merge(base, Map.delete(overrides, :session)))
  end

  test "renders the bare panel (no modal chrome)" do
    html = dialog(%{})

    assert html =~ "No ignored users. Click Add to ignore a nickname."
  end

  test "renders ignore rows from the session" do
    {:ok, list} = IgnoreList.add_entry(IgnoreList.new(), "Spammer", :all, nil)
    html = dialog(%{session: Session.set_ignore_list(Session.new("Nick"), list)})

    assert html =~ "Spammer"
    assert html =~ "Permanent"
  end

  test "draws each ignored nickname's language flag beside it" do
    nickname = speaker("Ign")
    {:ok, list} = IgnoreList.add_entry(IgnoreList.new(), nickname, :all, nil)
    html = dialog(%{session: Session.set_ignore_list(Session.new("Nick"), list)})

    assert [_flag] =
             html
             |> Floki.parse_fragment!()
             |> Floki.find(
               ~s(#control-entry-#{nickname} [data-testid="nick-flag"][data-locale="pt_BR"])
             )

    # The flag sits beside the nickname, never in what the row sends back.
    assert html =~ ~s(phx-value-nickname="#{nickname}")
  end

  test "renders the add sub-form targeting the component" do
    html = dialog(%{show_add_dialog: true})

    assert html =~ ~s(data-testid="control-add-form")
    assert html =~ ~s(phx-target=)
  end
end
