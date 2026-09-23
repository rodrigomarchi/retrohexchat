defmodule RetroHexChat.Notifications.QueriesTest do
  @moduledoc """
  The stored side of push: whose browsers we can reach, and which of them a
  channel line is actually about.

  The interesting function here is `candidates_for_channel_message/2`, because
  it runs on the hot path of every human channel message. It has to answer with
  one query, and it has to answer "nobody" far more often than "somebody".
  """
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Chat.Schemas.ReconnectState
  alias RetroHexChat.Notifications.Queries
  alias RetroHexChat.Services.RegisteredNick

  setup do
    %{channel: "#push#{System.unique_integer([:positive])}"}
  end

  describe "subscribe/2" do
    test "stores a browser against its owner" do
      nick = register("Sub")

      assert {:ok, sub} = Queries.subscribe(nick, params("https://push.example/a"))
      assert sub.owner_nickname == nick
      assert sub.failure_count == 0
    end

    # The same browser subscribing again is the same browser, and two rows would
    # be two notifications for one person looking at one screen.
    test "replaces a row for an endpoint that is already known" do
      nick = register("Again")
      {:ok, _} = Queries.subscribe(nick, params("https://push.example/same"))
      {:ok, _} = Queries.subscribe(nick, params("https://push.example/same", auth: "second"))

      assert [only] = Queries.list_for(nick)
      assert only.auth == "second"
    end

    test "refuses a nickname that is not registered" do
      assert {:error, %Ecto.Changeset{}} =
               Queries.subscribe("NeverRegistered", params("https://push.example/x"))
    end
  end

  describe "unsubscribe/2" do
    test "forgets one browser and leaves the others" do
      nick = register("Two")
      {:ok, _} = Queries.subscribe(nick, params("https://push.example/one"))
      {:ok, _} = Queries.subscribe(nick, params("https://push.example/two"))

      assert :ok = Queries.unsubscribe(nick, "https://push.example/one")
      assert [%{endpoint: "https://push.example/two"}] = Queries.list_for(nick)
    end

    test "is quiet about a browser it never knew" do
      nick = register("Quiet")

      assert :ok = Queries.unsubscribe(nick, "https://push.example/never")
    end
  end

  describe "candidates_for_channel_message/2" do
    test "returns a subscriber who was named and was in the channel", ctx do
      nick = register("Named")
      {:ok, _} = Queries.subscribe(nick, params("https://push.example/named"))
      remembers(nick, [ctx.channel])

      assert [%{owner_nickname: ^nick}] =
               Queries.candidates_for_channel_message(ctx.channel,
                 tokens: [nick],
                 except: "Author"
               )
    end

    test "matches the nickname however it was typed", ctx do
      nick = register("MiXed")
      {:ok, _} = Queries.subscribe(nick, params("https://push.example/mixed"))
      remembers(nick, [ctx.channel])

      assert [_] =
               Queries.candidates_for_channel_message(ctx.channel,
                 tokens: [String.downcase(nick)],
                 except: "Author"
               )
    end

    # Being reachable is not the same as belonging here. Somebody who never had
    # this channel open is being named in a room they do not read.
    test "skips a subscriber who was never in the channel", ctx do
      nick = register("Elsewhere")
      {:ok, _} = Queries.subscribe(nick, params("https://push.example/elsewhere"))
      remembers(nick, ["#somewhere-else"])

      assert [] =
               Queries.candidates_for_channel_message(ctx.channel,
                 tokens: [nick],
                 except: "Author"
               )
    end

    test "skips a channel member with no browser to reach", ctx do
      nick = register("Unreachable")
      remembers(nick, [ctx.channel])

      assert [] =
               Queries.candidates_for_channel_message(ctx.channel,
                 tokens: [nick],
                 except: "Author"
               )
    end

    test "never returns the person who wrote the line", ctx do
      nick = register("Selfie")
      {:ok, _} = Queries.subscribe(nick, params("https://push.example/selfie"))
      remembers(nick, [ctx.channel])

      assert [] =
               Queries.candidates_for_channel_message(ctx.channel,
                 tokens: [nick],
                 except: String.downcase(nick)
               )
    end

    test "has nothing to answer when the line named nobody", ctx do
      assert [] =
               Queries.candidates_for_channel_message(ctx.channel, tokens: [], except: "Author")
    end

    # This runs on every human channel message. Two queries here is two queries
    # per message on a busy server.
    test "asks the database exactly once", ctx do
      nick = register("Counted")
      {:ok, _} = Queries.subscribe(nick, params("https://push.example/counted"))
      remembers(nick, [ctx.channel])

      count =
        count_queries(fn ->
          Queries.candidates_for_channel_message(ctx.channel,
            tokens: [nick, "Someone", "Else"],
            except: "Author"
          )
        end)

      assert count == 1
    end
  end

  describe "failure bookkeeping" do
    test "a success clears the count and stamps the time" do
      nick = register("Healthy")
      {:ok, sub} = Queries.subscribe(nick, params("https://push.example/healthy"))
      {:ok, sub} = Queries.record_failure(sub)

      assert {:ok, healed} = Queries.record_success(sub)
      assert healed.failure_count == 0
      assert healed.last_success_at
    end

    test "failures accumulate until the row is dropped" do
      nick = register("Failing")
      {:ok, sub} = Queries.subscribe(nick, params("https://push.example/failing"))

      sub =
        Enum.reduce(1..(Queries.max_failures() - 1), sub, fn _i, acc ->
          {:ok, next} = Queries.record_failure(acc)
          next
        end)

      assert sub.failure_count == Queries.max_failures() - 1
      assert [_] = Queries.list_for(nick)

      assert {:ok, :dropped} = Queries.record_failure(sub)
      assert [] = Queries.list_for(nick)
    end

    test "a gone endpoint is removed outright" do
      nick = register("Gone")
      {:ok, sub} = Queries.subscribe(nick, params("https://push.example/gone"))

      assert :ok = Queries.drop(sub)
      assert [] = Queries.list_for(nick)
    end
  end

  defp params(endpoint, overrides \\ []) do
    %{
      endpoint: endpoint,
      p256dh: Keyword.get(overrides, :p256dh, "p256dh-key"),
      auth: Keyword.get(overrides, :auth, "auth-secret"),
      user_agent: Keyword.get(overrides, :user_agent, "Test/1.0")
    }
  end

  defp register(prefix) do
    nickname = "#{prefix}#{System.unique_integer([:positive])}" |> String.slice(0, 16)

    {:ok, _} =
      Repo.insert(%RegisteredNick{
        nickname: nickname,
        password_hash: "x",
        registered_at: DateTime.utc_now(),
        last_seen_at: DateTime.utc_now()
      })

    nickname
  end

  defp remembers(nickname, channels) do
    {:ok, _} =
      Repo.insert(%ReconnectState{
        owner_nickname: nickname,
        channels: channels
      })
  end

  defp count_queries(fun) do
    ref = make_ref()
    parent = self()
    handler = "push-query-count-#{inspect(ref)}"

    :telemetry.attach(
      handler,
      [:retro_hex_chat, :repo, :query],
      fn _event, _measurements, _metadata, _config -> send(parent, {ref, :query}) end,
      nil
    )

    try do
      fun.()
      drain(ref, 0)
    after
      :telemetry.detach(handler)
    end
  end

  defp drain(ref, count) do
    receive do
      {^ref, :query} -> drain(ref, count + 1)
    after
      0 -> count
    end
  end
end
