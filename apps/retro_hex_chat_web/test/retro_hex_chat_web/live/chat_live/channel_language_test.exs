defmodule RetroHexChatWeb.ChatLive.ChannelLanguageTest do
  @moduledoc """
  Naming the language a channel is spoken in, from Channel Central.

  The founder chooses it; everybody else on a registered channel sees what it
  is; an unregistered channel has nobody to keep the choice, so it offers none.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Services.NickServ
  alias RetroHexChat.Services.Queries

  setup ctx do
    founder = register("Fnd")
    other = register("Oth")
    channel = "#lang#{uid()}"

    {:ok, view, _html} = ctx.conn |> chat_conn(founder, pre_identified: true) |> live("/")
    submit_command_sync(view, "/join #{channel}")
    submit_command_sync(view, "/cs register #{channel}")
    open_cc(view, channel)

    %{view: view, founder: founder, other: other, channel: channel}
  end

  test "the founder chooses a language, and the channel keeps it", ctx do
    assert has_element?(ctx.view, "[data-testid='cc-language-select']")
    assert has_element?(ctx.view, "[data-testid='cc-language-option'] input[value='pt_BR']")

    html = choose(ctx.view, "pt_BR")

    assert Queries.find_registered_channel(ctx.channel).locale == "pt_BR"
    assert has_element?(ctx.view, "[data-testid='cc-cs-status'] [data-testid='channel-flag']")
    assert html =~ RetroHexChat.Locales.label("pt_BR")
  end

  test "and clears it again", ctx do
    choose(ctx.view, "pt_BR")
    choose(ctx.view, "")

    assert Queries.find_registered_channel(ctx.channel).locale == nil
    refute has_element?(ctx.view, "[data-testid='cc-cs-status'] [data-testid='channel-flag']")
  end

  test "somebody who is not the founder sees the language but cannot change it", ctx do
    choose(ctx.view, "pt_BR")

    {:ok, other_view, _html} =
      build_conn() |> chat_conn(ctx.other, pre_identified: true) |> live("/")

    submit_command_sync(other_view, "/join #{ctx.channel}")
    open_cc(other_view, ctx.channel)

    refute has_element?(other_view, "[data-testid='cc-language-select']")
    assert has_element?(other_view, "[data-testid='cc-language-value']")

    assert has_element?(
             other_view,
             "[data-testid='cc-language-value'] [data-testid='channel-flag'][data-locale='pt_BR']"
           )
  end

  # Absence assertion: an unregistered channel offers no language at all.
  test "an unregistered channel offers no language control", ctx do
    channel = "#nolang#{uid()}"
    submit_command_sync(ctx.view, "/join #{channel}")
    open_cc(ctx.view, channel)

    refute has_element?(ctx.view, "[data-testid='cc-language-switch']")
    refute has_element?(ctx.view, "[data-testid='cc-language-value']")
  end

  # The category is set beside the language, the same way.
  test "the founder chooses a category, and its plaque leads the channel's name", ctx do
    assert has_element?(ctx.view, "[data-testid='cc-category-option'] input[value='news']")

    ctx.view
    |> form("[data-testid='cc-category-form']", %{"category" => "news"})
    |> render_change()

    assert Queries.find_registered_channel(ctx.channel).category == "news"

    assert has_element?(
             ctx.view,
             "[data-testid='cc-cs-status'] [data-testid='channel-category'][data-category='news']"
           )

    ctx.view
    |> form("[data-testid='cc-category-form']", %{"category" => ""})
    |> render_change()

    assert Queries.find_registered_channel(ctx.channel).category == nil
  end

  defp open_cc(view, channel) do
    render_click(view, "open_channel_central", %{"cc_channel" => channel})
    render(view)
  end

  defp choose(view, locale) do
    view
    |> form("[data-testid='cc-language-form']", %{"locale" => locale})
    |> render_change()
  end

  defp register(prefix) do
    nickname = "#{prefix}#{uid()}"
    {:ok, _} = NickServ.register(nickname, "password123")
    nickname
  end
end
