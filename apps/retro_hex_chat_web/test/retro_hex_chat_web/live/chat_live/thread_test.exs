defmodule RetroHexChatWeb.ChatLive.ThreadTest do
  @moduledoc """
  Reading a scattered conversation together, from the chat.

  The line that collected the replies says so, and that is the way in. What
  must not happen while it does: the replies leaving the room. Everything here
  checks the room still has them, because a thread that hides its own replies
  is the choice that empties a small channel.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Chat.Queries
  alias RetroHexChat.Chat.Replies
  alias RetroHexChat.Services.NickServ
  alias RetroHexChatWeb.ChatLive.Components.Composer
  alias RetroHexChatWeb.ChatLive.Components.MessageViewport
  alias RetroHexChatWeb.ChatLive.Components.ThreadDialog
  alias RetroHexChatWeb.ChatLive.StreamItem

  setup ctx do
    owner = register("Own")
    other = register("Oth")
    channel = "#thr#{uid()}"

    {:ok, view, _html} = ctx.conn |> chat_conn(owner, pre_identified: true) |> live(~p"/chat")
    submit_command_sync(view, "/join #{channel}")
    {:ok, _state} = Server.join(channel, other)
    {:ok, root_id} = Server.send_message(channel, owner, "where should the notes live?")

    %{view: view, owner: owner, other: other, channel: channel, root_id: root_id}
  end

  defp reply(ctx, text) do
    {:ok, id} = Server.send_message(ctx.channel, ctx.other, text, reply_to_id: ctx.root_id)
    id
  end

  test "the line that was answered says how many times", ctx do
    reply(ctx, "the wiki")
    reply(ctx, "or the topic")

    render_click(ctx.view, "switch_channel", %{"channel" => ctx.channel})

    assert Queries.thread_counts_for_many(:message, [ctx.root_id]) == %{ctx.root_id => 2}
  end

  test "opening the thread mounts the window on that root", ctx do
    reply(ctx, "the wiki")

    render_click(ctx.view, "open_thread", %{"message_id" => to_string(ctx.root_id)})

    assert "thread" in assigns(ctx.view).open_windows
    assert thread_state(ctx.view).root_id == ctx.root_id
    assert thread_state(ctx.view).root.content == "where should the notes live?"
    assert thread_replies(ctx.view) == 1
  end

  # Opening from a reply opens the conversation it belongs to, not a thread of
  # its own — a reply never collects replies.
  test "opening from a reply opens the same thread", ctx do
    reply_id = reply(ctx, "the wiki")

    render_click(ctx.view, "open_thread", %{"message_id" => to_string(reply_id)})

    assert thread_state(ctx.view).root_id == ctx.root_id
  end

  test "the panel's Reply button aims the conversation's own composer", ctx do
    reply(ctx, "the wiki")
    render_click(ctx.view, "open_thread", %{"message_id" => to_string(ctx.root_id)})

    send(ctx.view.pid, {:thread_reply, :message, ctx.root_id})
    _rendered = render(ctx.view)

    assert composer_state(ctx.view).reply_to.id == ctx.root_id
  end

  # The point of the whole item: what is read together is still read in place.
  test "a reply is in the room as well as in the thread", ctx do
    render_click(ctx.view, "open_thread", %{"message_id" => to_string(ctx.root_id)})
    reply_id = reply(ctx, "the wiki")

    _rendered = render(ctx.view)

    assert Enum.any?(viewport_rendered(ctx.view), &(&1.id == reply_id))
  end

  # The absence this item can introduce: a root that is not on screen must not
  # be drawn a second time at the bottom because something answered it.
  describe "re-counting a root" do
    test "refreshes the row when the viewport is holding it", ctx do
      render_click(ctx.view, "switch_channel", %{"channel" => ctx.channel})
      reply(ctx, "the wiki")
      _rendered = render(ctx.view)

      rows = Enum.filter(viewport_rendered(ctx.view), &(&1.id == ctx.root_id))

      assert length(rows) == 1
      assert hd(rows).reply_count == 1
    end

    test "does not add a row the viewport had scrolled past", ctx do
      render_click(ctx.view, "switch_channel", %{"channel" => ctx.channel})
      before_ids = ctx.view |> viewport_rendered() |> Enum.map(& &1.id)

      {:ok, elsewhere} =
        Queries.insert_message(%{
          channel_name: "#gone#{uid()}",
          author_nickname: ctx.other,
          content: "a line this viewport never loaded",
          type: "message"
        })

      viewport_action(ctx.view, {:insert_if_present, StreamItem.from_message(elsewhere)})

      assert ctx.view |> viewport_rendered() |> Enum.map(& &1.id) == before_ids
    end
  end

  test "a thread the reader cannot resolve says so instead of opening", ctx do
    render_click(ctx.view, "open_thread", %{"message_id" => "999999"})

    refute "thread" in assigns(ctx.view).open_windows
  end

  test "replies stay flat however deep the answering went", ctx do
    first = reply(ctx, "the wiki")
    {:ok, second} = Server.send_message(ctx.channel, ctx.owner, "which wiki?", reply_to_id: first)

    assert Queries.get_message(second).reply_to_id == ctx.root_id
    assert Replies.root_id(:message, second) == ctx.root_id
  end

  defp register(prefix) do
    nickname = "#{prefix}#{uid()}"
    {:ok, _} = NickServ.register(nickname, "password123")
    nickname
  end

  defp assigns(view), do: :sys.get_state(view.pid).socket.assigns

  defp thread_state(view), do: component_assigns(view, ThreadDialog)

  # How many lines the thread is holding. Read from the list's own state rather
  # than from the stream: a stream's inserts are consumed by the render that
  # drew them, so a list that is on screen looks empty a moment later.
  defp thread_replies(view) do
    view |> thread_state() |> Map.fetch!(:paginated) |> Map.fetch!(:replies) |> Map.fetch!(:count)
  end

  defp composer_state(view), do: component_assigns(view, Composer)

  defp viewport_rendered(view) do
    view |> component_assigns(MessageViewport) |> Map.fetch!(:rendered)
  end

  # The island's own assigns, read the way the pagination tests read them.
  defp component_assigns(view, module) do
    {components, _ids, _uuid} = view.pid |> :sys.get_state() |> Map.fetch!(:components)

    Enum.find_value(components, fn
      {_cid, {^module, _id, assigns, _private, _prints}} -> assigns
      _other -> nil
    end)
  end

  # The one hop the host already has for delivering a directive to an island.
  defp viewport_action(view, action) do
    send(
      view.pid,
      {:window_send_update, MessageViewport, [id: MessageViewport.id(), action: action]}
    )

    render(view)
  end
end
