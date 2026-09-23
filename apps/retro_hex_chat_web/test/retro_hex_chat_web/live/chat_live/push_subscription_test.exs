defmodule RetroHexChatWeb.ChatLive.PushSubscriptionTest do
  @moduledoc """
  Turning "tell me even when this is closed" on and off.

  The exchange has two halves by necessity: only the browser can produce the
  address a push is delivered to, and only the server can hold the key that
  signs it. So the switch asks the browser, and the browser answers with what
  it got.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Notifications

  setup ctx do
    Application.put_env(:web_push_ex, :vapid,
      public_key: "test-public-key",
      private_key: "test-private-key",
      subject: "mailto:push@example.com"
    )

    on_exit(fn -> Application.delete_env(:web_push_ex, :vapid) end)

    nick = "Pusher#{uid()}"
    {:ok, _} = register(nick)
    {:ok, view, html} = ctx.conn |> chat_conn(nick) |> live(~p"/chat")

    %{view: view, html: html, nick: nick}
  end

  test "the browser is asked to subscribe, with this server's key", ctx do
    render_click(ctx.view, "push_toggle", %{})

    assert_push_event(ctx.view, "push_subscribe", %{public_key: "test-public-key"})
  end

  test "what the browser answers with is stored against the nickname", ctx do
    render_click(ctx.view, "push_subscription_created", subscription())

    assert [%{endpoint: "https://push.example/browser"}] = Notifications.list_for(ctx.nick)
  end

  test "turning it off asks the browser to give the subscription up", ctx do
    render_click(ctx.view, "push_subscription_created", subscription())
    render_click(ctx.view, "push_toggle", %{})

    assert_push_event(ctx.view, "push_unsubscribe", %{})
  end

  test "the row goes when the browser says it gave it up", ctx do
    render_click(ctx.view, "push_subscription_created", subscription())
    render_click(ctx.view, "push_subscription_removed", %{"endpoint" => endpoint()})

    assert Notifications.list_for(ctx.nick) == []
  end

  test "the hook is on the page when the server can send a push", ctx do
    assert ctx.html =~ ~s(phx-hook="PushSubscribeHook")
  end

  describe "with no VAPID keys" do
    setup ctx do
      Application.delete_env(:web_push_ex, :vapid)

      nick = "NoPush#{uid()}"
      {:ok, _} = register(nick)
      {:ok, view, html} = ctx.conn |> chat_conn(nick) |> live(~p"/chat")

      %{view: view, html: html, nick: nick}
    end

    # No key, no endpoint, no row — and so nothing on the page that would ask a
    # browser for permission it could never be used for.
    test "the hook is not on the page at all", ctx do
      refute ctx.html =~ ~s(phx-hook="PushSubscribeHook")
    end

    test "a subscription arriving anyway is refused", ctx do
      render_click(ctx.view, "push_subscription_created", subscription())

      assert Notifications.list_for(ctx.nick) == []
    end
  end

  defp endpoint, do: "https://push.example/browser"

  defp subscription do
    %{
      "endpoint" => endpoint(),
      "p256dh" => "p256dh-value",
      "auth" => "auth-value",
      "user_agent" => "Test/1.0"
    }
  end

  defp register(nickname) do
    RetroHexChat.Repo.insert(%RetroHexChat.Services.RegisteredNick{
      nickname: nickname,
      password_hash: "x",
      registered_at: DateTime.utc_now(),
      last_seen_at: DateTime.utc_now()
    })
  end
end
