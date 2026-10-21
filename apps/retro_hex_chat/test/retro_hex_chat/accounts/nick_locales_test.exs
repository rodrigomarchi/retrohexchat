defmodule RetroHexChat.Accounts.NickLocalesTest do
  @moduledoc """
  The language each person uses the chat in, answered from whoever is connected
  first, then from the visitors' registry, then from the nickname's own row.
  """
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Accounts.GuestNames
  alias RetroHexChat.Accounts.NickLocales
  alias RetroHexChat.Bots.Queries, as: BotQueries
  alias RetroHexChat.Presence.Tracker
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.NickServ
  alias RetroHexChat.Services.RegisteredNick
  alias RetroHexChat.Topics

  setup do
    nickname = "Loc#{System.unique_integer([:positive])}"
    {:ok, _nick} = NickServ.register(nickname, "password123")
    %{nickname: nickname}
  end

  # Presence belongs to the process that holds the connection; this one stands
  # in for it until the test ends.
  defp connect(nickname, locale) do
    test = self()

    pid =
      spawn(fn ->
        Tracker.track_user(Topics.presence(), nickname, %{locale: locale})
        send(test, :tracked)

        receive do
          :stop -> :ok
        end
      end)

    assert_receive :tracked, 1_000
    on_exit(fn -> send(pid, :stop) end)
  end

  defp stored(nickname), do: Repo.get_by!(RegisteredNick, nickname: nickname).locale

  describe "remember/3" do
    test "stores the language on the row of somebody who proved the name", ctx do
      assert :ok = NickLocales.remember(ctx.nickname, "pt_BR", store: true)
      assert stored(ctx.nickname) == "pt_BR"
    end

    # Typing a registered name without its password must not repaint its
    # owner's flag for everybody reading their messages.
    test "leaves the row alone unless asked to store", ctx do
      assert :ok = NickLocales.remember(ctx.nickname, "ja")
      assert stored(ctx.nickname) == nil
    end

    test "tells every session when the language changed", ctx do
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.presence())
      nickname = ctx.nickname

      :ok = NickLocales.remember(nickname, "de", store: true)
      assert_receive {:locale_changed, %{nickname: ^nickname, locale: "de"}}

      # The same language again is no news.
      :ok = NickLocales.remember(nickname, "de", store: true)
      refute_receive {:locale_changed, %{nickname: ^nickname}}, 50
    end

    test "refuses what is not a locale", ctx do
      assert {:error, :invalid_locale} = NickLocales.remember(ctx.nickname, "<b>", store: true)
      assert {:error, :invalid_locale} = NickLocales.remember(ctx.nickname, nil, store: true)
      assert stored(ctx.nickname) == nil
    end
  end

  describe "adopt/1" do
    # Identifying from inside the chat happens after the chat opened, and the
    # opening could not store a language for a name it had not seen proved.
    test "identifying keeps the language of the screen already open", ctx do
      connect(ctx.nickname, "ru")

      assert {:ok, _} = NickServ.identify(ctx.nickname, "password123")
      assert stored(ctx.nickname) == "ru"
    end

    test "has nothing to keep for somebody not connected", ctx do
      assert :ok = NickLocales.adopt(ctx.nickname)
      assert stored(ctx.nickname) == nil
    end
  end

  describe "for_nicks/1" do
    test "answers from the row for somebody who is not here", ctx do
      :ok = NickLocales.remember(ctx.nickname, "fr", store: true)

      assert NickLocales.for_nicks([ctx.nickname, "Nobody"]) == %{ctx.nickname => "fr"}
    end

    # The screen open right now outranks the language the row remembers.
    test "answers from presence for somebody connected, registered or not", ctx do
      :ok = NickLocales.remember(ctx.nickname, "fr", store: true)
      unregistered = "Anon#{System.unique_integer([:positive])}"
      connect(ctx.nickname, "es")
      connect(unregistered, "it")

      assert NickLocales.for_nicks([ctx.nickname, unregistered]) == %{
               ctx.nickname => "es",
               unregistered => "it"
             }
    end

    test "answers for a visitor from the guest registry" do
      test = self()

      pid =
        spawn(fn ->
          name = GuestNames.claim("browser-#{System.unique_integer([:positive])}")
          :ok = GuestNames.put_locale("pl")
          send(test, {:guest, name})

          receive do
            :stop -> :ok
          end
        end)

      assert_receive {:guest, guest}, 1_000
      on_exit(fn -> send(pid, :stop) end)

      assert NickLocales.for_nick(guest) == "pl"
    end

    test "keys the answer by the spelling it was asked with", ctx do
      :ok = NickLocales.remember(ctx.nickname, "nl", store: true)
      upper = String.upcase(ctx.nickname)

      assert NickLocales.for_nicks([upper]) == %{upper => "nl"}
    end

    # Nobody registers a bot's name; its row says what it speaks.
    test "answers for a bot from its row, and for the games service" do
      {:ok, bot} =
        BotQueries.create_bot(%{
          name: "LocBot#{System.unique_integer([:positive])}" |> String.slice(0, 16),
          nickname: "LocBot#{rem(System.unique_integer([:positive]), 10_000)}",
          created_by: "Admin",
          locale: "ja"
        })

      silent = "Quiet#{rem(System.unique_integer([:positive]), 10_000)}"

      assert NickLocales.for_nicks([bot.nickname, "GameServ", silent]) == %{
               bot.nickname => "ja",
               "GameServ" => "en"
             }

      upper = String.upcase(bot.nickname)
      assert NickLocales.for_nicks([upper]) == %{upper => "ja"}
    end

    test "says nothing when asked about nobody" do
      assert NickLocales.for_nicks([]) == %{}
      assert NickLocales.for_nick(nil) == nil
    end
  end
end
