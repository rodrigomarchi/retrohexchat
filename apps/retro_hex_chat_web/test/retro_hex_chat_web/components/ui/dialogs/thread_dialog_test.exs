defmodule RetroHexChatWeb.Components.UI.ThreadDialogTest do
  @moduledoc """
  The five things a list can be, in the Thread window.

  The one worth writing down is the difference between "no thread is open" and
  "this thread has no replies yet": they are the same empty box and completely
  different sentences, and the panel used to be able to say the wrong one.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.ThreadDialog

  alias RetroHexChat.Page
  alias RetroHexChatWeb.PaginatedList.State

  @moduletag :unit

  defp root do
    %{
      id: 7,
      author: "Ada",
      content: "where should the notes live?",
      content_format: "irc",
      type: :message,
      timestamp: ~U[2026-09-24 10:00:00Z],
      attachments: []
    }
  end

  defp reply(id, content) do
    %{
      id: id,
      author: "Grace",
      content: content,
      content_format: "irc",
      type: :message,
      timestamp: ~U[2026-09-24 10:01:00Z],
      attachments: []
    }
  end

  defp panel(opts) do
    render_component(&thread_panel/1,
      id: "thread-dialog",
      root: Keyword.get(opts, :root),
      replies: Keyword.get(opts, :replies, []),
      state: Keyword.get(opts, :state),
      nick_color_fn: fn _nick -> nil end
    )
  end

  defp loaded(items, opts \\ []) do
    page = %Page{
      items: items,
      has_more: Keyword.get(opts, :has_more, false),
      next_cursor: Keyword.get(opts, :cursor)
    }

    State.new(page_size: 25) |> State.from_page(page)
  end

  defp stream(items), do: Enum.map(items, &{"thread-reply-#{&1.id}", &1})

  test "with no thread open it says so, and offers no way to reply" do
    html = panel(state: State.new())

    assert html =~ "No thread is open."
    refute html =~ ~s(data-testid="thread-reply")
  end

  test "with a thread whose root nobody answered it invites the first reply" do
    html = panel(root: root(), state: loaded([]))

    assert html =~ "Nobody has answered this yet."
    assert html =~ "where should the notes live?"
    assert html =~ ~s(data-testid="thread-reply")
  end

  test "with replies it draws them under the root" do
    replies = [reply(8, "the wiki"), reply(9, "or the topic")]

    html = panel(root: root(), replies: stream(replies), state: loaded(replies))

    assert html =~ "the wiki"
    assert html =~ "or the topic"
    assert html =~ ~s(data-testid="thread-lines")
    refute html =~ "Nobody has answered this yet."
  end

  test "with more to fetch it offers the rest" do
    replies = [reply(8, "the wiki")]

    html =
      panel(
        root: root(),
        replies: stream(replies),
        state: loaded(replies, has_more: true, cursor: 8)
      )

    assert html =~ ~s(data-testid="thread-load-more")
    refute html =~ ~s(data-testid="thread-end")
  end

  test "with nothing left it closes the list" do
    replies = [reply(8, "the wiki")]

    html = panel(root: root(), replies: stream(replies), state: loaded(replies))

    assert html =~ ~s(data-testid="thread-end")
  end

  test "with a page that failed it offers to try again" do
    replies = [reply(8, "the wiki")]
    state = replies |> loaded(has_more: true, cursor: 8) |> State.failed()

    html = panel(root: root(), replies: stream(replies), state: state)

    assert html =~ "Could not load more of this thread."
  end
end
