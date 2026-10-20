defmodule RetroHexChatWeb.ChatLive.LocaleFlagsTest do
  @moduledoc """
  The flag of the language each person uses the chat in, beside their nickname.

  The language is the chat's own — the address's locale — so opening the chat
  is what records it; every other screen reads it back beside the name.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Accounts.NickLocales
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Presence.Tracker
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.NickServ
  alias RetroHexChat.Services.RegisteredNick
  alias RetroHexChat.Topics

  setup ctx do
    viewer = register("Vie")
    author = register("Aut")
    channel = "#flag#{uid()}"

    :ok = NickLocales.remember(author, "ja", store: true)

    {:ok, view, _html} =
      ctx.conn |> chat_conn(viewer, pre_identified: true) |> live("/pt-BR")

    submit_command_sync(view, "/join #{channel}")
    {:ok, _state} = Server.join(channel, author)
    {:ok, _id} = Server.send_message(channel, author, "konnichiwa")

    render_click(view, "switch_channel", %{"channel" => channel})

    %{view: view, viewer: viewer, author: author, channel: channel}
  end

  test "opening the chat records its language, for the screen and the row", ctx do
    assert %{locale: "pt_BR"} = Tracker.meta(Topics.presence(), ctx.viewer)
    assert Repo.get_by!(RegisteredNick, nickname: ctx.viewer).locale == "pt_BR"
  end

  test "an author's flag is drawn beside their line and in the user list", ctx do
    assert head_of(render(ctx.view), ctx.author) =~ ~s(data-locale="ja")

    assert Enum.find(assigns(ctx.view).conversation_members, &(&1.nickname == ctx.author)).locale ==
             "ja"
  end

  test "the viewer's own flag is the language they opened the chat in", ctx do
    assert Enum.find(assigns(ctx.view).conversation_members, &(&1.nickname == ctx.viewer)).locale ==
             "pt_BR"

    assert render(ctx.view) =~ ~s(data-locale="pt_BR")
  end

  test "another language opened elsewhere repaints the row in the user list", ctx do
    :ok = NickLocales.remember(ctx.author, "de", store: true)

    assert Enum.find(assigns(ctx.view).conversation_members, &(&1.nickname == ctx.author)).locale ==
             "de"
  end

  # Absence: somebody nobody knows a language for gets no stand-in flag.
  test "a person with no known language gets no flag", ctx do
    stranger = "Str#{uid()}"
    {:ok, _state} = Server.join(ctx.channel, stranger)
    {:ok, _id} = Server.send_message(ctx.channel, stranger, "hello from nowhere")

    html = render(ctx.view)

    assert html =~ "hello from nowhere"
    refute head_of(html, stranger) =~ "nick-flag"
    # The same head carries the author's flag, so the absence is the stranger's.
    assert head_of(html, ctx.author) =~ "nick-flag"
  end

  test "whois shows the flag beside the nickname", ctx do
    submit_command_sync(ctx.view, "/whois #{ctx.viewer}")

    assert %{rows: [%{locale: "pt_BR", value: viewer} | _]} = assigns(ctx.view).lookup_result
    assert viewer == ctx.viewer
  end

  defp register(prefix) do
    nickname = "#{prefix}#{uid()}"
    {:ok, _} = NickServ.register(nickname, "password123")
    nickname
  end

  # The head of the last line `nick` wrote: the portrait, the flag and the name.
  defp head_of(html, nick) do
    ~r/<div class="chat-message__head">((?:(?!chat-message__head).)*?)<span class="chat-nick chat-message__author[^"]*"\s+data-nick="#{nick}"/s
    |> Regex.scan(html, capture: :all_but_first)
    |> List.last()
    |> List.first()
  end

  defp assigns(view), do: :sys.get_state(view.pid).socket.assigns
end
