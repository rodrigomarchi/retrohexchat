defmodule RetroHexChat.Jobs.PushDispatchWorkerTest do
  @moduledoc """
  Turning one enqueued message into the notifications it earned.

  The enqueue side already decided the message was worth considering. What is
  left is the part that can only be known now: whether the person is sitting in
  front of the product, and whether their browser still answers.
  """
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Chat.Schemas.ReconnectState
  alias RetroHexChat.Jobs.PushDispatchWorker
  alias RetroHexChat.Notifications.Queries
  alias RetroHexChat.Services.RegisteredNick
  alias RetroHexChat.Surfaces

  setup do
    {public_key, private_key} = :crypto.generate_key(:ecdh, :prime256v1)

    Application.put_env(:web_push_ex, :vapid,
      public_key: Base.url_encode64(public_key, padding: false),
      private_key: Base.url_encode64(private_key, padding: false),
      subject: "mailto:push@example.com"
    )

    Application.put_env(:retro_hex_chat, :push_req_options, plug: {Req.Test, __MODULE__})
    Req.Test.stub(__MODULE__, &accept/1)

    on_exit(fn ->
      Application.delete_env(:web_push_ex, :vapid)
      Application.delete_env(:retro_hex_chat, :push_req_options)
    end)

    channel = "#push#{System.unique_integer([:positive])}"
    reader = subscriber("Reader", channel)

    %{channel: channel, reader: reader}
  end

  describe "a channel mention" do
    test "reaches a subscriber with nothing open", ctx do
      assert {:ok, %{sent: 1}} = perform(channel_args(ctx))
    end

    # Somebody with the chat open has already had the sound, the title and — if
    # they asked for it — a desktop notification. A push on top is the product
    # shouting at somebody who is already listening.
    test "does not reach one who has a screen open", ctx do
      open_surface(ctx.reader)

      assert {:ok, %{sent: 0, skipped: 1}} = perform(channel_args(ctx))
    end

    test "does not reach somebody who was not named", ctx do
      assert {:ok, %{sent: 0, skipped: 0}} =
               perform(%{channel_args(ctx) | "tokens" => ["SomebodyElse"]})
    end

    test "carries the room and the author, and nothing else", ctx do
      Req.Test.stub(__MODULE__, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        # What crosses a third party's push service is ciphertext.
        refute body =~ ctx.channel
        accept(conn)
      end)

      assert {:ok, %{sent: 1}} = perform(channel_args(ctx))
    end
  end

  describe "a private message" do
    test "reaches the recipient with nothing open", ctx do
      assert {:ok, %{sent: 1}} = perform(pm_args(ctx))
    end

    test "does not reach one who has a screen open", ctx do
      open_surface(ctx.reader)

      assert {:ok, %{sent: 0, skipped: 1}} = perform(pm_args(ctx))
    end
  end

  describe "what the endpoint answers" do
    test "a gone endpoint costs the subscription its row", ctx do
      Req.Test.stub(__MODULE__, &Plug.Conn.send_resp(&1, 410, ""))

      assert {:ok, %{sent: 0}} = perform(channel_args(ctx))
      assert [] = Queries.list_for(ctx.reader)
    end

    test "a transient failure counts without dropping the row", ctx do
      Req.Test.stub(__MODULE__, &Plug.Conn.send_resp(&1, 503, ""))

      assert {:ok, %{sent: 0}} = perform(channel_args(ctx))
      assert [%{failure_count: 1}] = Queries.list_for(ctx.reader)
    end
  end

  test "a server with no keys cancels the job outright", ctx do
    Application.delete_env(:web_push_ex, :vapid)

    Req.Test.stub(__MODULE__, fn _conn ->
      flunk("a push was sent by a server with no VAPID keys")
    end)

    assert {:cancel, "push_disabled"} = perform(channel_args(ctx))
  end

  defp perform(args), do: perform_job(PushDispatchWorker, args)

  defp channel_args(ctx) do
    %{
      "kind" => "channel",
      "conversation" => ctx.channel,
      "author" => "Author",
      "tokens" => [ctx.reader],
      "body" => "hey #{ctx.reader} are you there"
    }
  end

  defp pm_args(ctx) do
    %{
      "kind" => "pm",
      "conversation" => "pm:Author",
      "nickname" => ctx.reader,
      "author" => "Author",
      "body" => "psst"
    }
  end

  defp accept(conn), do: Plug.Conn.send_resp(conn, 201, "")

  defp subscriber(prefix, channel) do
    nickname = "#{prefix}#{System.unique_integer([:positive])}" |> String.slice(0, 16)
    {public_key, _private_key} = :crypto.generate_key(:ecdh, :prime256v1)

    {:ok, _} =
      Repo.insert(%RegisteredNick{
        nickname: nickname,
        password_hash: "x",
        registered_at: DateTime.utc_now(),
        last_seen_at: DateTime.utc_now()
      })

    {:ok, _} = Repo.insert(%ReconnectState{owner_nickname: nickname, channels: [channel]})

    {:ok, _} =
      Queries.subscribe(nickname, %{
        endpoint: "https://push.example/#{nickname}",
        p256dh: Base.url_encode64(public_key, padding: false),
        auth: Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false),
        user_agent: "Test/1.0"
      })

    nickname
  end

  # A surface is a process, so a fake one is a process. It reports back when it
  # has registered, so the test never races the monitor.
  defp open_surface(nickname) do
    test = self()

    pid =
      spawn(fn ->
        :ok = Surfaces.open(nickname, __MODULE__)
        send(test, {:registered, self()})

        receive do
          :stop -> :ok
        end
      end)

    assert_receive {:registered, ^pid}
    on_exit(fn -> if Process.alive?(pid), do: send(pid, :stop) end)

    pid
  end
end
