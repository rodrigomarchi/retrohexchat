defmodule RetroHexChatWeb.ChatLive.WindowOpenEventsTest do
  @moduledoc """
  The menu, toolbar and Start menu entries that do nothing but open a window:
  each one opens (or focuses) the window it names.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Services.NickServ

  @opens [
    {"toggle_address_book", "address-book"},
    {"open_autojoin_dialog", "autojoin"},
    {"open_highlight_dialog", "highlight"},
    {"open_ignore_list_dialog", "ignore-list"},
    {"open_nick_colors_dialog", "nick-colors"},
    {"open_perform_dialog", "perform"},
    {"open_trusted_terminals_dialog", "trusted-terminals"},
    {"toggle_notify_list", "notify-list"},
    {"toggle_url_catcher", "url-catcher"}
  ]

  setup ctx do
    nick = "Win#{uid()}"
    {:ok, _} = NickServ.register(nick, "password123")
    {:ok, view, _html} = ctx.conn |> chat_conn(nick, pre_identified: true) |> live("/")
    %{view: view}
  end

  for {event, window} <- @opens do
    test "#{event} opens the #{window} window", ctx do
      render_click(ctx.view, unquote(event), %{})

      assert_push_event(ctx.view, "window_command", %{action: "open", id: unquote(window)})
    end
  end
end
