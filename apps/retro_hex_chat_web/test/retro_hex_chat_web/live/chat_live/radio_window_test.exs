defmodule RetroHexChatWeb.ChatLive.RadioWindowTest do
  @moduledoc """
  Hex Radio, from the desktop: it opens from `/radio` and its menu entry,
  lists the most played stations, a genre's, a search and the favourites,
  and hands the station chosen to the browser to play.

  The stations are `RetroHexChat.Radio.Fixture`'s; the stream itself is the
  browser's, so here a play is the `radio:play` event the hook receives.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Radio.Cache
  alias RetroHexChat.Services.NickServ

  setup ctx do
    Cache.clear()
    owner = "Dj#{uid()}"
    {:ok, _} = NickServ.register(owner, "password123")
    {:ok, view, _html} = ctx.conn |> chat_conn(owner, pre_identified: true) |> live("/")
    %{view: view}
  end

  # The window as the browser opens it: the player says it is ready, with the
  # favourites it kept, and the first list comes.
  defp open(view, favorites \\ []) do
    submit_command_sync(view, "/radio")
    render_hook(element(view, "#hex-radio"), "radio_ready", %{"ids" => favorites})
    _ = render_async(view)
    view
  end

  test "/radio opens the window on the most played stations", ctx do
    html = ctx.view |> open() |> render()

    assert html =~ ~s(data-testid="radio-window")
    assert html =~ ~s(data-testid="hex-radio-equalizer")
    assert html =~ "Pixel Wave FM"
    assert html =~ "Starfield Ambient"

    assert ctx.view
           |> element(~s([data-testid="hex-radio-section-top"][aria-pressed="true"]))
           |> has_element?()
  end

  test "its menu entry opens it too, waiting for the player before listing", ctx do
    render_hook(ctx.view, "open_radio", %{})
    html = render(ctx.view)
    assert html =~ ~s(data-testid="radio-window")
    assert html =~ ~s(data-testid="hex-radio-loading")

    render_hook(element(ctx.view, "#hex-radio"), "radio_ready", %{"ids" => []})
    assert render_async(ctx.view) =~ "Pixel Wave FM"
  end

  test "a genre lists its stations and a search finds one by name", ctx do
    view = open(ctx.view)

    refute render(view) =~ ~s(data-testid="hex-radio-genres")
    view |> element(~s([data-testid="hex-radio-genre-menu"])) |> render_click()
    view |> element(~s([data-testid="hex-radio-section-jazz"])) |> render_click()
    html = render_async(view)
    assert html =~ "Eight Bits Jazz"
    refute html =~ "Pixel Wave FM"
    refute html =~ ~s(data-testid="hex-radio-genres")

    view |> element(~s([data-testid="hex-radio-find"])) |> render_click()
    view |> form("#hex-radio-search", %{q: "neon"}) |> render_submit()
    html = render_async(view)
    assert html =~ "Neon Highway"
    refute html =~ "Eight Bits Jazz"

    view |> form("#hex-radio-search", %{q: "zzzz"}) |> render_submit()
    assert render_async(view) =~ ~s(data-testid="hex-radio-empty")
  end

  test "a search of one letter is not sent", ctx do
    view = open(ctx.view)
    view |> element(~s([data-testid="hex-radio-find"])) |> render_click()
    html = view |> form("#hex-radio-search", %{q: "n"}) |> render_submit()
    assert html =~ ~s(data-testid="hex-radio-error")
  end

  test "choosing a station hands it to the browser and shows it on the display", ctx do
    view = open(ctx.view)

    view |> element(~s([data-testid="hex-radio-station-e2e-neon"])) |> render_click()

    assert_push_event(view, "radio:play", %{
      id: "e2e-neon",
      name: "Neon Highway",
      stream: "https://radio.e2e.test/e2e-neon.mp3"
    })

    assert view |> element(~s([data-testid="hex-radio-station-name"])) |> render() =~
             "Neon Highway"

    facts = view |> element(~s([data-testid="hex-radio-station-facts"])) |> render()
    assert facts =~ "192"
    assert facts =~ "MP3"
    assert facts =~ "US"
  end

  test "Play with nothing chosen plays the first, and the steps go round the list", ctx do
    view = open(ctx.view)

    view |> element(~s([data-testid="hex-radio-play"])) |> render_click()
    assert_push_event(view, "radio:play", %{id: "e2e-pixel"})

    view |> element(~s([data-testid="hex-radio-next"])) |> render_click()
    assert_push_event(view, "radio:play", %{id: "e2e-neon"})

    view |> element(~s([data-testid="hex-radio-prev"])) |> render_click()
    view |> element(~s([data-testid="hex-radio-prev"])) |> render_click()
    assert_push_event(view, "radio:play", %{id: "e2e-pixel"})
    assert_push_event(view, "radio:play", %{id: "e2e-star"})
  end

  test "a station not in the list is not played", ctx do
    view = open(ctx.view)
    render_hook(element(view, "#hex-radio"), "radio_play", %{"id" => "elsewhere"})
    refute_push_event(view, "radio:play", %{})
  end

  test "stars a station, keeps the stars in the browser and lists them", ctx do
    view = open(ctx.view, ["e2e-star"])

    view |> element(~s([data-testid="hex-radio-star-e2e-pixel"])) |> render_click()
    assert_push_event(view, "radio:favorites", %{ids: ["e2e-star", "e2e-pixel"]})

    view |> element(~s([data-testid="hex-radio-section-favorites"])) |> render_click()
    html = render_async(view)
    assert html =~ "Starfield Ambient"
    assert html =~ "Pixel Wave FM"
    refute html =~ "Neon Highway"

    view |> element(~s([data-testid="hex-radio-star-e2e-star"])) |> render_click()
    assert_push_event(view, "radio:favorites", %{ids: ["e2e-pixel"]})
    refute render(view) =~ "Starfield Ambient"
  end

  test "favourites the browser sends are kept only as ids", ctx do
    view = open(ctx.view, ["e2e-bits", 42, "", "e2e-bits"])

    view |> element(~s([data-testid="hex-radio-section-favorites"])) |> render_click()
    html = render_async(view)
    assert html =~ "Eight Bits Jazz"
    refute html =~ "Pixel Wave FM"
  end
end
