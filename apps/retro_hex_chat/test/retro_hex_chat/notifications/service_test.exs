defmodule RetroHexChat.Notifications.ServiceTest do
  @moduledoc """
  Sending one encrypted push, and what the answer means for the row that sent it.

  A push service answers with an HTTP status and nothing else, so the status is
  the only place the difference between "try again later" and "this browser is
  never coming back" is written down. Reading it wrong in one direction leaves
  dead rows forever; in the other it throws away a working subscription on a
  bad afternoon.
  """
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Notifications.Queries
  alias RetroHexChat.Notifications.Service
  alias RetroHexChat.Services.RegisteredNick

  setup do
    {public_key, private_key} = :crypto.generate_key(:ecdh, :prime256v1)

    Application.put_env(:web_push_ex, :vapid,
      public_key: Base.url_encode64(public_key, padding: false),
      private_key: Base.url_encode64(private_key, padding: false),
      subject: "mailto:push@example.com"
    )

    Application.put_env(:retro_hex_chat, :push_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:web_push_ex, :vapid)
      Application.delete_env(:retro_hex_chat, :push_req_options)
    end)

    %{subscription: subscribed()}
  end

  describe "enabled?/0" do
    test "is true with a key pair configured" do
      assert Service.enabled?()
    end

    test "is false without one" do
      Application.delete_env(:web_push_ex, :vapid)

      refute Service.enabled?()
    end

    test "is false with the keys half filled in" do
      Application.put_env(:web_push_ex, :vapid,
        public_key: "something",
        private_key: nil,
        subject: "mailto:push@example.com"
      )

      refute Service.enabled?()
    end
  end

  describe "deliver/2" do
    # `content-encoding: aes128gcm` is not asserted here and cannot be: Req's
    # plug adapter reads that header itself, tries to decompress the body with
    # it, and deletes it before the plug ever runs. The real adapter sends it.
    test "posts an encrypted body to the endpoint", ctx do
      Req.Test.stub(__MODULE__, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        assert body != ""
        refute body =~ "psst"
        assert [authorization] = Plug.Conn.get_req_header(conn, "authorization")
        assert authorization =~ "vapid t="
        assert Plug.Conn.get_req_header(conn, "ttl") != []

        Plug.Conn.send_resp(conn, 201, "")
      end)

      assert :ok = Service.deliver(ctx.subscription, payload())
    end

    test "a success clears the failures that came before", ctx do
      {:ok, subscription} = Queries.record_failure(ctx.subscription)
      Req.Test.stub(__MODULE__, &Plug.Conn.send_resp(&1, 201, ""))

      assert :ok = Service.deliver(subscription, payload())
      assert [%{failure_count: 0, last_success_at: %DateTime{}}] = Queries.list_for(owner())
    end

    # 410 Gone is the push service saying the browser unsubscribed or was wiped.
    # Keeping the row means paying for it on every message forever.
    test "a gone endpoint is forgotten", ctx do
      Req.Test.stub(__MODULE__, &Plug.Conn.send_resp(&1, 410, ""))

      assert {:error, :gone} = Service.deliver(ctx.subscription, payload())
      assert [] = Queries.list_for(owner())
    end

    test "an endpoint that is not there any more is forgotten too", ctx do
      Req.Test.stub(__MODULE__, &Plug.Conn.send_resp(&1, 404, ""))

      assert {:error, :gone} = Service.deliver(ctx.subscription, payload())
      assert [] = Queries.list_for(owner())
    end

    test "a server error counts against the subscription without dropping it", ctx do
      Req.Test.stub(__MODULE__, &Plug.Conn.send_resp(&1, 500, ""))

      assert {:error, :transient} = Service.deliver(ctx.subscription, payload())
      assert [%{failure_count: 1}] = Queries.list_for(owner())
    end

    test "a connection that never answers counts the same", ctx do
      Req.Test.stub(__MODULE__, &Req.Test.transport_error(&1, :econnrefused))

      assert {:error, :transient} = Service.deliver(ctx.subscription, payload())
      assert [%{failure_count: 1}] = Queries.list_for(owner())
    end

    test "a subscription that keeps failing is eventually dropped", ctx do
      Req.Test.stub(__MODULE__, &Plug.Conn.send_resp(&1, 500, ""))

      subscription =
        Enum.reduce(1..(Queries.max_failures() - 1), ctx.subscription, fn _i, acc ->
          assert {:error, :transient} = Service.deliver(acc, payload())
          [reloaded] = Queries.list_for(owner())
          reloaded
        end)

      assert {:error, :transient} = Service.deliver(subscription, payload())
      assert [] = Queries.list_for(owner())
    end

    test "refuses to send at all when there are no keys", ctx do
      Application.delete_env(:web_push_ex, :vapid)

      Req.Test.stub(__MODULE__, fn _conn ->
        flunk("a push was sent by a server with no VAPID keys")
      end)

      assert {:error, :disabled} = Service.deliver(ctx.subscription, payload())
    end
  end

  defp payload do
    %{title: "#room", body: "psst", conversation: "#room"}
  end

  defp owner, do: "Pushed"

  defp subscribed do
    {public_key, _private_key} = :crypto.generate_key(:ecdh, :prime256v1)

    {:ok, _} =
      Repo.insert(%RegisteredNick{
        nickname: owner(),
        password_hash: "x",
        registered_at: DateTime.utc_now(),
        last_seen_at: DateTime.utc_now()
      })

    {:ok, subscription} =
      Queries.subscribe(owner(), %{
        endpoint: "https://push.example/endpoint",
        p256dh: Base.url_encode64(public_key, padding: false),
        auth: Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false),
        user_agent: "Test/1.0"
      })

    subscription
  end
end
