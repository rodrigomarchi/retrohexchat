defmodule RetroHexChatWeb.ChatLive.SavedTest do
  @moduledoc """
  Keeping a line for later, from the chat.

  The window is reached from Start ▸ Tools and the save is made from the
  message's own menu — nobody reads message ids off a screen, so the menu is
  the only practical way in, exactly as it turned out to be for pinning.

  The one thing that must hold no matter what the screen does: what somebody
  kept is theirs. A second person on the same channel, looking at the same
  line, sees an empty list.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Chat.Queries
  alias RetroHexChat.Chat.SavedMessages
  alias RetroHexChat.Services.NickServ

  setup ctx do
    owner = register("Own")
    other = register("Oth")
    channel = "#save#{uid()}"

    {:ok, view, _html} = ctx.conn |> chat_conn(owner, pre_identified: true) |> live(~p"/chat")
    submit_command_sync(view, "/join #{channel}")
    {:ok, message_id} = Server.send_message(channel, owner, "the address is on the wiki")

    %{view: view, owner: owner, other: other, channel: channel, message_id: message_id}
  end

  test "the menu keeps a line, and the window opens", ctx do
    render_click(ctx.view, "ctx_chat_save_message", %{"message_id" => to_string(ctx.message_id)})

    assert SavedMessages.count(ctx.owner) == 1

    render_click(ctx.view, "open_saved_dialog", %{})
    assert "saved" in assigns(ctx.view).open_windows
  end

  # The Start menu goes through the compound action event, not the bare one.
  test "Start ▸ Tools ▸ Saved Messages opens the window", ctx do
    render_click(ctx.view, "toolbar_action", %{"action" => "open_saved_dialog"})

    assert "saved" in assigns(ctx.view).open_windows
    assert render(ctx.view) =~ "saved-window"
  end

  test "keeping the same line twice keeps it once", ctx do
    render_click(ctx.view, "ctx_chat_save_message", %{"message_id" => to_string(ctx.message_id)})
    render_click(ctx.view, "ctx_chat_save_message", %{"message_id" => to_string(ctx.message_id)})

    assert SavedMessages.count(ctx.owner) == 1
  end

  test "the menu gives it back", ctx do
    render_click(ctx.view, "ctx_chat_save_message", %{"message_id" => to_string(ctx.message_id)})

    render_click(ctx.view, "ctx_chat_unsave_message", %{"message_id" => to_string(ctx.message_id)})

    assert SavedMessages.count(ctx.owner) == 0
  end

  test "a private line is kept the same way", ctx do
    {:ok, pm} =
      Queries.insert_private_message(%{
        sender_nickname: ctx.other,
        recipient_nickname: ctx.owner,
        content: "the address is here too",
        type: "message"
      })

    render_click(ctx.view, "switch_pm", %{"nickname" => ctx.other})
    render_click(ctx.view, "ctx_chat_save_message", %{"message_id" => to_string(pm.id)})

    assert [entry] = SavedMessages.list(ctx.owner).items
    assert entry.private_message_id == pm.id
  end

  # Absence assertion: the list is per person, and the screen must not be the
  # place that fact is decided.
  test "what one person kept does not reach another", ctx do
    render_click(ctx.view, "ctx_chat_save_message", %{"message_id" => to_string(ctx.message_id)})

    {:ok, other_view, _html} =
      build_conn() |> chat_conn(ctx.other, pre_identified: true) |> live(~p"/chat")

    submit_command_sync(other_view, "/join #{ctx.channel}")

    assert SavedMessages.count(ctx.other) == 0
    assert SavedMessages.list(ctx.other).items == []
  end

  # The menu is drawn by a component the host updates, so the assertion is on
  # what the screen ends up showing — `render/1` after an event is queued
  # behind it, which is what makes this synchronous.
  test "the menu offers Save, then Unsave", ctx do
    open_message_menu(ctx)
    html = render(ctx.view)

    assert html =~ "context-menu-item-ctx_chat_save_message"
    refute html =~ "context-menu-item-ctx_chat_unsave_message"

    render_click(ctx.view, "ctx_chat_save_message", %{"message_id" => to_string(ctx.message_id)})
    open_message_menu(ctx)
    html = render(ctx.view)

    assert html =~ "context-menu-item-ctx_chat_unsave_message"
    refute html =~ "context-menu-item-ctx_chat_save_message"
  end

  # The same question the Unpin item needed and never got asked: nothing ever
  # filled it in, so the menu drew Pin over an already pinned line and never
  # drew Unpin at all.
  test "the menu offers Unpin once the line is pinned", ctx do
    open_message_menu(ctx)
    assert render(ctx.view) =~ "context-menu-item-ctx_chat_pin_message"

    submit_command_sync(ctx.view, "/pin #{ctx.message_id}")
    open_message_menu(ctx)
    html = render(ctx.view)

    assert html =~ "context-menu-item-ctx_chat_unpin_message"
    refute html =~ "context-menu-item-ctx_chat_pin_message"
  end

  describe "the note" do
    test "is written on a row the person owns", ctx do
      render_click(ctx.view, "ctx_chat_save_message", %{"message_id" => to_string(ctx.message_id)})

      [entry] = SavedMessages.list(ctx.owner).items

      send(ctx.view.pid, {:set_saved_note, entry.id, "ask about this on Monday"})
      render(ctx.view)

      assert [%{note: "ask about this on Monday"}] = SavedMessages.list(ctx.owner).items
    end

    test "cannot be written on somebody else's", ctx do
      render_click(ctx.view, "ctx_chat_save_message", %{"message_id" => to_string(ctx.message_id)})

      [entry] = SavedMessages.list(ctx.owner).items

      assert {:error, _reason} = SavedMessages.set_note(ctx.other, entry.id, "not mine")
      assert [%{note: nil}] = SavedMessages.list(ctx.owner).items
    end
  end

  defp register(prefix) do
    nickname = "#{prefix}#{uid()}"
    {:ok, _} = NickServ.register(nickname, "password123")
    nickname
  end

  defp open_message_menu(ctx) do
    render_click(ctx.view, "chat_context_menu", %{
      "type" => "message",
      "message_id" => to_string(ctx.message_id),
      "author" => ctx.owner,
      "message_text" => "the address is on the wiki"
    })
  end

  defp assigns(view), do: :sys.get_state(view.pid).socket.assigns
end
