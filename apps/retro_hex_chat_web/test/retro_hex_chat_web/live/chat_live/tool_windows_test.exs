defmodule RetroHexChatWeb.ChatLive.ToolWindowsTest do
  @moduledoc """
  Hex Paint and ASCII Art, from the desktop: each opens from its menu entry,
  and what it makes is posted into a conversation the person is in — a
  drawing as a picture with a line of text, text art as one message in its own
  format. A conversation the person is not in is never one it can post to,
  whatever the form says.

  The drawing and the art are made in the browser; here they arrive as the
  hook sends them (a PNG on the upload, the art as text).
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Chat.Queries
  alias RetroHexChat.Services.NickServ

  setup ctx do
    owner = "Art#{uid()}"
    {:ok, _} = NickServ.register(owner, "password123")
    channel = "#art#{uid()}"

    {:ok, view, _html} = ctx.conn |> chat_conn(owner, pre_identified: true) |> live("/")
    submit_command_sync(view, "/join #{channel}")

    %{view: view, owner: owner, channel: channel}
  end

  test "/paint and /ascii open their windows, as their menu entries do", ctx do
    submit_command_sync(ctx.view, "/paint")
    submit_command_sync(ctx.view, "/ascii")
    html = render(ctx.view)

    assert html =~ ~s(data-testid="paint-window")
    assert html =~ ~s(data-testid="ascii-art-window")
  end

  describe "Hex Paint" do
    test "opens from its menu entry with its menus, tools and colours", ctx do
      render_hook(ctx.view, "open_paint", %{})
      html = render(ctx.view)

      assert html =~ ~s(data-testid="paint-window")
      assert html =~ ~s(data-testid="hex-paint-menu-bar")
      assert html =~ ~s(data-paint-tool="bucket")
      assert html =~ ~s(data-irc-colour="15")
    end

    test "posts the drawing into the channel chosen, with its line of text", ctx do
      render_hook(ctx.view, "open_paint", %{})
      render_hook(element(ctx.view, "#hex-paint"), "paint_post_open", %{})
      assert render(ctx.view) =~ ~s(data-testid="hex-paint-post-form")

      upload =
        file_input(ctx.view, "#hex-paint-upload", :drawing, [
          %{name: "hex-paint-1.png", content: png(), type: "image/png"}
        ])

      render_upload(upload, "hex-paint-1.png")

      ctx.view
      |> form("#hex-paint-post-form", %{target: "channel:#{ctx.channel}", caption: "my cat"})
      |> render_submit()

      message = latest_message(ctx.channel)
      assert message.author_nickname == ctx.owner
      assert message.content == "my cat"
      assert [%{file: %{content_type: "image/png"}}] = message.attachments
      refute render(ctx.view) =~ ~s(data-testid="hex-paint-post-form")
    end

    test "never posts into a conversation the person is not in", ctx do
      render_hook(ctx.view, "open_paint", %{})
      render_hook(element(ctx.view, "#hex-paint"), "paint_post_open", %{})

      upload =
        file_input(ctx.view, "#hex-paint-upload", :drawing, [
          %{name: "hex-paint-2.png", content: png(), type: "image/png"}
        ])

      render_upload(upload, "hex-paint-2.png")

      html =
        ctx.view
        |> form("#hex-paint-post-form", %{target: "channel:#{ctx.channel}"})
        |> render_submit(%{target: "channel:#elsewhere#{uid()}"})

      assert html =~ ~s(data-testid="hex-paint-post-error")
      assert latest_message(ctx.channel) == nil
    end
  end

  describe "ASCII Art" do
    test "posts the art as one message, shown in the dialog as the chat draws it", ctx do
      render_hook(ctx.view, "open_ascii_art", %{})
      assert render(ctx.view) =~ ~s(data-testid="ascii-art-window")

      art =
        Enum.map_join(1..12, "\n", fn i -> "\x03#{rem(i, 16)}" <> String.duplicate("█", 30) end)

      html = render_hook(element(ctx.view, "#ascii-art-root"), "ascii_post_open", %{"art" => art})
      assert html =~ ~s(<pre class="irc-art">)

      ctx.view
      |> form("#ascii-art-post-form", %{target: "channel:#{ctx.channel}"})
      |> render_submit()

      assert [message] = messages(ctx.channel)
      assert message.content == art
      assert message.content_format == "irc_art"
    end

    test "says why art too large for one message cannot be posted", ctx do
      render_hook(ctx.view, "open_ascii_art", %{})
      art = Enum.map_join(1..31, "\n", fn _ -> "#" end)

      html = render_hook(element(ctx.view, "#ascii-art-root"), "ascii_post_open", %{"art" => art})

      assert html =~ ~s(data-testid="ascii-art-post-error")
      assert html =~ "30"
    end
  end

  # The smallest PNG: what the browser sends is opaque to the server.
  defp png,
    do:
      Base.decode64!(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="
      )

  defp messages(channel) do
    channel
    |> Queries.list_messages(limit: 20)
    |> Map.fetch!(:items)
    |> Enum.filter(&(&1.type == "message"))
  end

  defp latest_message(channel) do
    channel |> messages() |> List.last() |> then(&(&1 && Queries.preload_attachments(&1)))
  end
end
