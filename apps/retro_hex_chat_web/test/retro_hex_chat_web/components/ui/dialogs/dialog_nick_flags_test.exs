defmodule RetroHexChatWeb.Components.UI.DialogNickFlagsTest do
  @moduledoc """
  The language flag beside every nickname a list window names: the author of
  a mention, a pin or a saved line, and the people Channel Central lists.

  The windows read the language from the row (`:author_locale`) or from a map
  by nickname that their island looked up once; a row nobody knows a language
  for draws no flag at all.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChat.Page
  alias RetroHexChatWeb.ChatLive.Helpers.NickFlags
  alias RetroHexChatWeb.Components.UI.ChannelCentralDialog
  alias RetroHexChatWeb.Components.UI.MentionsDialog
  alias RetroHexChatWeb.Components.UI.PinnedDialog
  alias RetroHexChatWeb.Components.UI.SavedDialog
  alias RetroHexChatWeb.PaginatedList.State

  @moduletag :unit

  @at ~U[2026-10-20 12:00:00Z]

  defp loaded(items) do
    State.new(page_size: 25) |> State.from_page(%Page{items: items, has_more: false})
  end

  defp flags(html, selector) do
    html |> Floki.parse_fragment!() |> Floki.find(selector <> ~s( [data-testid="nick-flag"]))
  end

  test "a mention carries its author's flag, and a row with none carries nothing" do
    rows = [
      %{
        id: 1,
        channel_name: "#a",
        author_nickname: "Ana",
        author_locale: "pt_BR",
        inserted_at: @at
      },
      %{id: 2, channel_name: "#a", author_nickname: "Bob", author_locale: nil, inserted_at: @at}
    ]

    html =
      render_component(&MentionsDialog.mentions_panel/1,
        id: "mentions-dialog",
        mentions: Enum.map(rows, &{"mention-#{&1.id}", &1}),
        state: loaded(rows)
      )

    assert [flag] = flags(html, ~s([data-testid="mention-row-1"]))
    assert Floki.attribute(flag, "data-locale") == ["pt_BR"]
    assert [] = flags(html, ~s([data-testid="mention-row-2"]))
  end

  test "a pin carries its author's flag" do
    rows = [
      %{
        message_id: 5,
        author_nickname: "Ana",
        author_locale: "ja",
        pinned_by: "Op",
        inserted_at: @at,
        content: "rules"
      }
    ]

    html =
      render_component(&PinnedDialog.pinned_panel/1,
        id: "pinned-dialog",
        pins: Enum.map(rows, &{"pin-#{&1.message_id}", &1}),
        state: loaded(rows)
      )

    assert [flag] = flags(html, ~s([data-testid="pinned-open-5"]))
    assert Floki.attribute(flag, "data-locale") == ["ja"]
  end

  test "a saved line carries its author's flag" do
    rows = [
      %{
        id: 9,
        author_nickname: "Ana",
        author_locale: "de",
        channel_name: "#a",
        counterpart: nil,
        message_id: 3,
        private_message_id: nil,
        deleted?: false,
        note: nil,
        inserted_at: @at,
        content: "kept"
      }
    ]

    html =
      render_component(&SavedDialog.saved_panel/1,
        id: "saved-dialog",
        entries: Enum.map(rows, &{"saved-#{&1.id}", &1}),
        state: loaded(rows)
      )

    assert [flag] = flags(html, ~s([data-testid="saved-open-9"]))
    assert Floki.attribute(flag, "data-locale") == ["de"]
  end

  test "Channel Central flags the founder, the access lists and who added each entry" do
    registration = %{
      registered?: true,
      channel_name: "#a",
      founder: "Ana",
      registered_at: @at,
      viewer_role: "founder",
      access: %{
        "sop" => [%{nickname: "Bob", level: "sop", added_by: "Ana"}],
        "aop" => [],
        "vop" => []
      }
    }

    html =
      render_component(&ChannelCentralDialog.channel_central_panel/1,
        id: "channel-central-dialog",
        channel_name: "#a",
        active_tab: "registration",
        registration: registration,
        identified: true,
        nick_locales: %{"Ana" => "pt_BR", "Bob" => "ja"}
      )

    assert [bob, ana] = flags(html, ~s([data-testid="cc-cs-access-row-Bob"]))
    assert Floki.attribute(bob, "data-locale") == ["ja"]
    assert Floki.attribute(ana, "data-locale") == ["pt_BR"]

    assert html |> Floki.parse_fragment!() |> Floki.find(~s([data-locale="pt_BR"])) |> length() ==
             2
  end

  test "a page of rows is given its authors' languages in one pass" do
    page = %Page{items: [%{author_nickname: nil}], has_more: true, next_cursor: 4}

    assert %Page{items: [%{author_locale: nil}], has_more: true, next_cursor: 4} =
             NickFlags.put_author_locales(page, :author_nickname)
  end

  test "the same people are not looked up twice" do
    cached = {["Ana"], %{"Ana" => "pt_BR"}}

    assert NickFlags.locales(["Ana"], cached) == cached
    assert NickFlags.locales([], cached) == {[], %{}}
  end

  test "a window keeps the languages and the pair that spares the next lookup" do
    cached = {["Ana"], %{"Ana" => "pt_BR"}}
    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}, cache: cached}}

    assert %{locales: %{"Ana" => "pt_BR"}, cache: ^cached} =
             NickFlags.assign_locales(socket, ["Ana"], :locales, :cache).assigns
  end

  test "a member's language is read off the roster, whatever case the name is in" do
    members = [%{nickname: "Ana", locale: "pt_BR"}, %{nickname: "Bob"}]

    assert NickFlags.member_locale(members, "ana") == "pt_BR"
    assert NickFlags.member_locale(members, "Bob") == nil
    assert NickFlags.member_locale(members, "Carl") == nil
    assert NickFlags.member_locale(nil, "Ana") == nil
    assert NickFlags.member_locale(members, nil) == nil
  end
end
