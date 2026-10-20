defmodule RetroHexChatWeb.ChatLive.ChannelLocaleFlagsTest do
  @moduledoc """
  The flag of the language a channel is spoken in, beside the channel's name:
  its tab, its row in the conversations sidebar and the topic bar. Its founder
  sets it with `/cs language`; until they do there is no flag.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Services.NickServ

  setup ctx do
    founder = "Fdr#{uid()}"
    {:ok, _} = NickServ.register(founder, "password123")
    channel = "#lang#{uid()}"

    {:ok, view, _html} = ctx.conn |> chat_conn(founder, pre_identified: true) |> live("/")

    submit_command_sync(view, "/join #{channel}")
    submit_command_sync(view, "/cs register")

    %{view: view, channel: channel}
  end

  test "a channel nobody gave a language has no flag", ctx do
    html = render(ctx.view)

    refute flagged?(html, "tab-bar")
    refute flagged?(html, "topic-bar")
    refute flagged?(html, "channel-#{ctx.channel}")
  end

  test "the founder's choice is drawn beside the name everywhere it is shown", ctx do
    submit_command_sync(ctx.view, "/cs language ja")
    html = render(ctx.view)

    assert assigns(ctx.view).channel_locales[ctx.channel] == "ja"
    assert flagged?(html, "tab-bar", "ja")
    assert flagged?(html, "topic-bar", "ja")
    assert flagged?(html, "channel-#{ctx.channel}", "ja")
    assert html =~ "set this channel&#39;s language to 日本語"
  end

  test "clearing it takes the flag away", ctx do
    submit_command_sync(ctx.view, "/cs language ja")
    submit_command_sync(ctx.view, "/cs language none")

    html = render(ctx.view)

    refute flagged?(html, "tab-bar")
    refute flagged?(html, "channel-#{ctx.channel}")
  end

  # Whether the element whose test id is `testid` holds a channel flag — of
  # `locale`, when one is given. Scoped, because the sidebar suggests other
  # rooms, and the Retro Games ones are English.
  defp flagged?(html, testid, locale \\ nil) do
    flag =
      if locale,
        do: ~s([data-testid="channel-flag"][data-locale="#{locale}"]),
        else: ~s([data-testid="channel-flag"])

    html
    |> Floki.parse_document!()
    |> Floki.find(~s([data-testid="#{testid}"] #{flag}))
    |> Enum.any?()
  end

  defp assigns(view), do: :sys.get_state(view.pid).socket.assigns
end
