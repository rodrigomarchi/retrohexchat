defmodule RetroHexChatWeb.ComposerFormatTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.{Registry, Supervisor}
  alias RetroHexChat.Chat.Queries

  setup do
    channel = "#fmt#{uid()}"
    ensure_channel(channel)
    {:ok, channel: channel}
  end

  test "composer sends channel messages with the selected markdown format", %{
    conn: conn,
    channel: channel
  } do
    nick = "fmt#{uid()}"
    {:ok, view, _html} = live(chat_conn(conn, nick), "/")
    join_channel(view, channel)

    view
    |> element(~s([data-testid="composer-format-markdown"]))
    |> render_click()

    submit_composer_sync(view, "**Hello** [doc](https://example.com)")

    msg = newest_message(channel)
    assert msg.author_nickname == nick
    assert msg.content_format == "markdown"
    assert msg.plain_content == "Hello doc"
  end

  test "composer sends channel messages with the selected plain format", %{
    conn: conn,
    channel: channel
  } do
    nick = "fmt#{uid()}"
    {:ok, view, _html} = live(chat_conn(conn, nick), "/")
    join_channel(view, channel)

    view
    |> element(~s([data-testid="composer-format-plain"]))
    |> render_click()

    submit_composer_sync(view, "<b>plain</b>")

    msg = newest_message(channel)
    assert msg.author_nickname == nick
    assert msg.content_format == "plain"
    assert msg.plain_content == "<b>plain</b>"
  end

  test "markdown preview renders as a chat message popover", %{conn: conn} do
    nick = "fmt#{uid()}"
    {:ok, view, _html} = live(chat_conn(conn, nick), "/")

    view
    |> element(~s([data-testid="composer-format-markdown"]))
    |> render_click()

    view
    |> element(~s([data-testid="composer-markdown-preview-toggle"]))
    |> render_click()

    refute render(view) =~ ~s(data-testid="composer-markdown-preview")

    view
    |> element(~s([data-testid="chat-input-field"]))
    |> render_change(%{"input" => "**Preview** text"})

    document = view |> render() |> Floki.parse_document!()
    preview = Floki.find(document, ~s([data-testid="composer-markdown-preview"]))

    assert preview != []
    assert preview |> Floki.find(".chat-message__author") |> Floki.text() =~ nick
    assert preview |> Floki.find(~s([data-testid="chat-message-timestamp"])) |> Floki.text() != ""
    assert preview |> Floki.find("strong") |> Floki.text() == "Preview"

    view
    |> element(~s([data-testid="composer-format-plain"]))
    |> render_click()

    refute render(view) =~ ~s(data-testid="composer-markdown-preview")
  end

  test "editing opens in the original message format", %{conn: conn, channel: channel} do
    nick = "fmt#{uid()}"
    {:ok, view, _html} = live(chat_conn(conn, nick), "/")
    join_channel(view, channel)

    view
    |> element(~s([data-testid="composer-format-markdown"]))
    |> render_click()

    submit_composer_sync(view, "**Original**")

    msg = newest_message(channel)
    render_click(view, "edit_message", %{"message_id" => Integer.to_string(msg.id)})

    html = render(view)
    assert html =~ ~s(data-active-format="markdown")

    submit_composer_sync(view, "**Edited**")

    updated = Queries.get_message(msg.id)
    assert updated.content == "**Edited**"
    assert updated.content_format == "markdown"
    assert updated.plain_content == "Edited"
  end

  defp join_channel(view, channel) do
    submit_composer_sync(view, "/join #{channel}")
  end

  defp submit_composer_sync(view, input) do
    view
    |> element(~s([data-testid="chat-input-form"]))
    |> render_submit(%{"input" => input})

    render(view)
  end

  defp newest_message(channel) do
    channel
    |> Queries.list_messages(limit: 1)
    |> Map.fetch!(:items)
    |> hd()
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
