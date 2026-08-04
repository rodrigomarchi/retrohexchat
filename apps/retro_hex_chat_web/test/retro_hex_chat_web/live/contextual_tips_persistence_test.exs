defmodule RetroHexChatWeb.ContextualTipsPersistenceTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Chat.ContextualTips
  alias RetroHexChat.Services.Queries

  describe "contextual tips persistence" do
    test "registered identified user loads tips state from backend", %{conn: conn} do
      nick = "TipWeb#{uid()}"
      insert_registered_nick(nick)

      tips =
        ContextualTips.new()
        |> ContextualTips.mark_seen("first_join")
        |> ContextualTips.set_suppressed(true)

      assert :ok = ContextualTips.save(nick, tips)

      {:ok, view, html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      assert html =~ "data-tips-state="
      assert ContextualTips.suppressed?(assigns(view).session.contextual_tips)
      assert ContextualTips.seen?(assigns(view).session.contextual_tips, "first_join")
    end

    test "tips_seen persists known tips and ignores invalid ids", %{conn: conn} do
      nick = "TipSeen#{uid()}"
      insert_registered_nick(nick)

      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      render_hook(view, "tips_seen", %{"tips" => ["first_message", "unknown", nil]})

      assert ContextualTips.seen?(assigns(view).session.contextual_tips, "first_message")
      assert {:ok, loaded} = ContextualTips.load(nick)
      assert ContextualTips.seen_tips(loaded) == ["first_message"]
    end

    test "tips_suppressed_changed persists booleans only", %{conn: conn} do
      nick = "TipSupp#{uid()}"
      insert_registered_nick(nick)

      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      render_hook(view, "tips_suppressed_changed", %{"suppressed" => true})

      assert ContextualTips.suppressed?(assigns(view).session.contextual_tips)
      assert {:ok, loaded} = ContextualTips.load(nick)
      assert ContextualTips.suppressed?(loaded)

      render_hook(view, "tips_suppressed_changed", %{"suppressed" => "false"})

      assert ContextualTips.suppressed?(assigns(view).session.contextual_tips)
    end

    test "guest tips state stays in the LiveView process only", %{conn: conn} do
      nick = "TipGuest#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      render_hook(view, "tips_seen", %{"tips" => ["first_pm"]})

      assert ContextualTips.seen?(assigns(view).session.contextual_tips, "first_pm")
      assert {:error, :not_found} = ContextualTips.load(nick)
    end
  end

  defp assigns(view), do: :sys.get_state(view.pid).socket.assigns

  defp insert_registered_nick(nickname) do
    {:ok, _} = Queries.insert_registered_nick(nickname, "password123")
  end
end
