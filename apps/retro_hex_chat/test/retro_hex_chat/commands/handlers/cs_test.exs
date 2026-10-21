defmodule RetroHexChat.Commands.Handlers.CsTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Channels
  alias RetroHexChat.Chat.Archive
  alias RetroHexChat.Commands.Dispatcher
  alias RetroHexChat.Commands.Handlers.Cs
  alias RetroHexChat.Services.ChanServ
  alias RetroHexChat.Services.NickServ
  alias RetroHexChat.Services.Queries

  setup do
    nick_server = :"nickserv_cs_h_#{rem(System.unique_integer([:positive]), 100_000)}"
    {:ok, _} = NickServ.start_link(name: nick_server)

    cs_server = :"chanserv_h_#{rem(System.unique_integer([:positive]), 100_000)}"
    {:ok, _} = ChanServ.start_link(name: cs_server, nick_serv: nick_server)

    {:ok, _} = NickServ.register("CsTestUser", "pass123", nick_server)

    context = %{
      nickname: "CsTestUser",
      active_channel: "#testchan",
      channels: ["#testchan"],
      identified: true,
      operator_in: ["#testchan"],
      chan_serv: cs_server
    }

    %{context: context, cs_server: cs_server, nick_server: nick_server}
  end

  describe "execute/2 - register" do
    test "registers a channel", ctx do
      assert {:ok, :system, %{content: content}} =
               Cs.execute(["register"], ctx.context)

      assert content =~ "ChanServ"
      assert content =~ "registered"
    end

    test "only an operator of the channel can register it", ctx do
      member = %{ctx.context | operator_in: []}

      assert {:error, msg} = Cs.execute(["register"], member)
      assert msg =~ "operator"

      assert {:ok, %{registered: false}} =
               ChanServ.info("#testchan", ctx.cs_server) |> registered?()
    end

    test "returns error for duplicate registration", ctx do
      {:ok, :system, _} = Cs.execute(["register"], ctx.context)
      assert {:error, msg} = Cs.execute(["register"], ctx.context)
      assert msg =~ "ChanServ"
    end
  end

  describe "execute/2 - drop" do
    test "drops a registered channel", ctx do
      {:ok, :system, _} = Cs.execute(["register"], ctx.context)
      assert {:ok, :system, %{content: content}} = Cs.execute(["drop"], ctx.context)
      assert content =~ "dropped"
    end

    test "returns error for unregistered channel", ctx do
      assert {:error, msg} = Cs.execute(["drop"], ctx.context)
      assert msg =~ "not registered"
    end
  end

  describe "execute/2 - archive" do
    setup ctx do
      channel = "#csarch#{rem(System.unique_integer([:positive]), 100_000)}"
      {:ok, _pid} = Channels.Supervisor.start_child(channel)

      context = %{
        ctx.context
        | active_channel: channel,
          channels: [channel],
          operator_in: [channel]
      }

      {:ok, :system, _} = Cs.execute(["register"], context)
      # The channel reads identification from the server's own NickServ.
      identify(context.nickname)
      %{context: context, channel: channel}
    end

    test "the founder switches it on and off", ctx do
      assert {:ok, :system, %{content: on}} = Cs.execute(["archive", "on"], ctx.context)
      assert on =~ "is on"
      assert Archive.published?(ctx.channel)

      assert {:ok, :system, %{content: off}} = Cs.execute(["archive", "off"], ctx.context)
      assert off =~ "is off"
      refute Archive.published?(ctx.channel)
    end

    test "nobody but the founder may", ctx do
      identify("NotTheFounder")
      stranger = %{ctx.context | nickname: "NotTheFounder"}

      assert {:error, msg} = Cs.execute(["archive", "on"], stranger)
      assert msg =~ "founder"
      refute Archive.published?(ctx.channel)
    end

    # A registered nickname can be held for a minute before NickServ enforces
    # it; whoever holds the founder's name in that minute may not publish.
    test "the founder's nickname, unidentified, may not", ctx do
      NickServ.remove_identified(ctx.context.nickname)
      # A cast; a call from this same process cannot overtake it.
      refute NickServ.identified?(ctx.context.nickname)

      assert {:error, msg} = Cs.execute(["archive", "on"], ctx.context)
      assert msg =~ "Identify"
      refute Archive.published?(ctx.channel)
    end

    test "asked later, it reports the state without promising anything new", ctx do
      {:ok, :system, _} = Cs.execute(["archive", "on"], ctx.context)

      assert {:ok, :system, %{content: content}} = Cs.execute(["archive"], ctx.context)
      assert content =~ "is on."
      refute content =~ "from now on"
    end

    test "outside a channel it asks for one", ctx do
      assert {:error, msg} = Cs.execute(["archive", "on"], %{ctx.context | active_channel: nil})
      assert msg =~ "channel"
    end

    test "a room nobody registered cannot be published", ctx do
      unregistered = "#csfree#{rem(System.unique_integer([:positive]), 100_000)}"
      {:ok, _pid} = Channels.Supervisor.start_child(unregistered)

      # An unregistered room has no founder, so nobody may.
      assert {:error, _msg} =
               Cs.execute(["archive", "on"], %{ctx.context | active_channel: unregistered})

      refute Archive.published?(unregistered)
    end

    test "without on or off it reports the state and the usage", ctx do
      assert {:ok, :system, %{content: content}} = Cs.execute(["archive"], ctx.context)
      assert content =~ "is off"
      assert content =~ "/cs archive <on|off>"
    end

    test "a channel with no running room is an error, not a crash", ctx do
      gone = %{ctx.context | active_channel: "#nobody#{System.unique_integer([:positive])}"}

      assert {:error, msg} = Cs.execute(["archive", "on"], gone)
      assert msg =~ "Channel not found"
    end
  end

  describe "execute/2 - language" do
    setup ctx do
      channel = "#cslang#{rem(System.unique_integer([:positive]), 100_000)}"
      {:ok, _pid} = Channels.Supervisor.start_child(channel)
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{channel}")

      context = %{
        ctx.context
        | active_channel: channel,
          channels: [channel],
          operator_in: [channel]
      }

      {:ok, :system, _} = Cs.execute(["register"], context)
      identify(context.nickname)
      %{context: context, channel: channel}
    end

    test "the founder sets it, written however they like, and the room hears", ctx do
      assert {:ok, :system, %{content: content}} =
               Cs.execute(["language", "pt-br"], ctx.context)

      assert content =~ "Português (Brasil)"
      assert stored_locale(ctx.channel) == "pt_BR"
      assert {:ok, %{locale: "pt_BR"}} = Channels.Server.get_state(ctx.channel)

      assert_receive {:channel_locale_changed,
                      %{channel: channel, nickname: "CsTestUser", locale: "pt_BR"}}

      assert channel == ctx.channel
    end

    test "none clears it", ctx do
      {:ok, :system, _} = Cs.execute(["language", "ja"], ctx.context)

      assert {:ok, :system, %{content: content}} = Cs.execute(["language", "none"], ctx.context)
      assert content =~ "no longer has a language"
      assert stored_locale(ctx.channel) == nil
      assert_receive {:channel_locale_changed, %{locale: nil}}
    end

    test "a language the chat does not speak is refused with the list", ctx do
      assert {:error, msg} = Cs.execute(["language", "klingon"], ctx.context)
      assert msg =~ "Unknown language: klingon"
      assert msg =~ "pt_BR"
      assert stored_locale(ctx.channel) == nil
    end

    test "nobody but the founder may", ctx do
      identify("NotTheFounder")
      stranger = %{ctx.context | nickname: "NotTheFounder"}

      assert {:error, msg} = Cs.execute(["language", "en"], stranger)
      assert msg =~ "founder"
      assert stored_locale(ctx.channel) == nil
    end

    test "a room nobody registered has none to set", ctx do
      unregistered = "#csfree#{rem(System.unique_integer([:positive]), 100_000)}"
      {:ok, _pid} = Channels.Supervisor.start_child(unregistered)

      assert {:error, msg} =
               Cs.execute(["language", "en"], %{ctx.context | active_channel: unregistered})

      assert msg =~ "founder"
    end

    test "alone it reports the language, the usage and the choices", ctx do
      assert {:ok, :system, %{content: content}} = Cs.execute(["language"], ctx.context)
      assert content =~ "has no language set"
      assert content =~ "/cs language <code|none>"
      assert content =~ "pt_BR"

      {:ok, :system, _} = Cs.execute(["language", "de"], ctx.context)
      assert {:ok, :system, %{content: content}} = Cs.execute(["language"], ctx.context)
      assert content =~ "Deutsch (de)"
    end

    # The form in Channel Central reaches the channel without the command's
    # check, so the channel checks again.
    test "the channel refuses a code the chat does not speak", ctx do
      assert {:error, msg} = Channels.Server.set_locale(ctx.channel, "CsTestUser", "xx")
      assert msg =~ "Unknown language"

      assert {:error, _msg} =
               Channels.Server.set_locale(ctx.channel, "CsTestUser", String.duplicate("a", 40))

      assert stored_locale(ctx.channel) == nil
      assert :ok = Channels.Server.set_locale(ctx.channel, "CsTestUser", "pt-br")
      assert stored_locale(ctx.channel) == "pt_BR"
    end

    # A registration written while the room is running — a Retro Games
    # channel is born with one — brings its language along.
    test "a registration written under a running room brings its language" do
      name = "#cslater#{rem(System.unique_integer([:positive]), 100_000)}"
      {:ok, _pid} = Channels.Supervisor.start_child(name)
      {:ok, _} = Queries.insert_registered_channel(name, "Somebody")
      Queries.update_registered_channel_settings(name, locale: "en")

      :ok = Channels.Server.mark_registered(name)

      assert {:ok, %{locale: "en"}} = Channels.Server.get_state(name)
    end

    test "dropping the registration takes the language with it", ctx do
      {:ok, :system, _} = Cs.execute(["language", "fr"], ctx.context)
      assert_receive {:channel_locale_changed, %{locale: "fr"}}

      {:ok, :system, _} = Cs.execute(["drop"], ctx.context)

      assert_receive {:channel_locale_changed, %{nickname: nil, locale: nil}}
      assert {:ok, %{locale: nil}} = Channels.Server.get_state(ctx.channel)
    end
  end

  describe "execute/2 - category" do
    setup ctx do
      channel = "#cscat#{rem(System.unique_integer([:positive]), 100_000)}"
      {:ok, _pid} = Channels.Supervisor.start_child(channel)
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{channel}")

      context = %{
        ctx.context
        | active_channel: channel,
          channels: [channel],
          operator_in: [channel]
      }

      {:ok, :system, _} = Cs.execute(["register"], context)
      identify(context.nickname)
      %{context: context, channel: channel}
    end

    test "the founder sets it, in any case, and the room hears", ctx do
      assert {:ok, :system, %{content: content}} = Cs.execute(["category", "NEWS"], ctx.context)
      assert content =~ "is about News (news)"
      assert Queries.find_registered_channel(ctx.channel).category == "news"
      assert {:ok, %{category: "news"}} = Channels.Server.get_state(ctx.channel)
      assert_receive {:channel_category_changed, %{nickname: "CsTestUser", category: "news"}}
    end

    test "none clears it, and a name outside the set is refused with the list", ctx do
      {:ok, :system, _} = Cs.execute(["category", "games"], ctx.context)
      assert {:ok, :system, %{content: c}} = Cs.execute(["category", "none"], ctx.context)
      assert c =~ "no longer has a category"
      assert Queries.find_registered_channel(ctx.channel).category == nil

      assert {:error, msg} = Cs.execute(["category", "cooking"], ctx.context)
      assert msg =~ "Unknown category: cooking"
      assert msg =~ "science"
    end

    test "nobody but the founder may", ctx do
      identify("NotTheFounder")
      stranger = %{ctx.context | nickname: "NotTheFounder"}

      assert {:error, msg} = Cs.execute(["category", "news"], stranger)
      assert msg =~ "founder"
    end

    test "alone it reports the category and the choices", ctx do
      assert {:ok, :system, %{content: content}} = Cs.execute(["category"], ctx.context)
      assert content =~ "has no category set"
      assert content =~ "/cs category <name|none>"
    end

    test "dropping the registration takes both badges with it", ctx do
      {:ok, :system, _} = Cs.execute(["category", "tech"], ctx.context)
      {:ok, :system, _} = Cs.execute(["language", "fr"], ctx.context)

      {:ok, :system, _} = Cs.execute(["drop"], ctx.context)

      assert_receive {:channel_category_changed, %{nickname: nil, category: nil}}
      assert {:ok, %{category: nil, locale: nil}} = Channels.Server.get_state(ctx.channel)
    end
  end

  describe "execute/2 - info" do
    test "returns channel info", ctx do
      {:ok, :system, _} = Cs.execute(["register"], ctx.context)

      assert {:ok, :system, %{content: content}} = Cs.execute(["info"], ctx.context)
      assert content =~ "#testchan"
      assert content =~ "CsTestUser"
      assert content =~ ~r/registered=\d{4}-\d{2}-\d{2} \d{2}:\d{2} UTC$/
    end

    test "returns error for unregistered channel", ctx do
      assert {:error, msg} = Cs.execute(["info"], ctx.context)
      assert msg =~ "not registered"
    end
  end

  describe "execute/2 - sop add" do
    test "adds user to sop list", ctx do
      {:ok, :system, _} = Cs.execute(["register"], ctx.context)

      NickServ.register("SopTarget", "pass123", ctx.nick_server)

      assert {:ok, :system, %{content: content}} =
               Cs.execute(["sop", "add", "SopTarget"], ctx.context)

      assert content =~ "SopTarget"
      assert content =~ "sop"
    end
  end

  describe "execute/2 - aop add" do
    test "adds user to aop list", ctx do
      {:ok, :system, _} = Cs.execute(["register"], ctx.context)

      NickServ.register("AopTarget", "pass123", ctx.nick_server)

      assert {:ok, :system, %{content: content}} =
               Cs.execute(["aop", "add", "AopTarget"], ctx.context)

      assert content =~ "AopTarget"
      assert content =~ "aop"
    end
  end

  describe "execute/2 - vop add" do
    test "adds user to vop list", ctx do
      {:ok, :system, _} = Cs.execute(["register"], ctx.context)

      NickServ.register("VopTarget", "pass123", ctx.nick_server)

      assert {:ok, :system, %{content: content}} =
               Cs.execute(["vop", "add", "VopTarget"], ctx.context)

      assert content =~ "VopTarget"
      assert content =~ "vop"
    end
  end

  describe "execute/2 - sop del" do
    test "removes user from access list", ctx do
      {:ok, :system, _} = Cs.execute(["register"], ctx.context)
      NickServ.register("SopDel", "pass123", ctx.nick_server)
      {:ok, :system, _} = Cs.execute(["sop", "add", "SopDel"], ctx.context)

      assert {:ok, :system, %{content: content}} =
               Cs.execute(["sop", "del", "SopDel"], ctx.context)

      assert content =~ "removed"
    end
  end

  describe "execute/2 - sop list" do
    test "lists access entries for channel", ctx do
      {:ok, :system, _} = Cs.execute(["register"], ctx.context)

      assert {:ok, :system, %{content: content}} = Cs.execute(["sop", "list"], ctx.context)
      assert content =~ "ChanServ"
    end
  end

  describe "execute/2 - help (via dispatcher)" do
    test "dispatcher intercepts help and returns show_command_help" do
      context = %{
        nickname: "Tester",
        active_channel: "#test",
        channels: ["#test"],
        identified: false,
        operator_in: [],
        chan_serv: nil
      }

      assert {:ok, :ui_action, :show_command_help, %{help: help}} =
               Dispatcher.dispatch("cs", ["help"], context)

      assert help.name == "cs"
      assert is_binary(help.syntax)
    end
  end

  describe "execute/2 - edge cases" do
    test "returns error for no subcommand" do
      context = %{
        nickname: "Tester",
        active_channel: "#test",
        channels: ["#test"],
        identified: false,
        operator_in: [],
        chan_serv: nil
      }

      assert {:error, msg} = Cs.execute([], context)
      assert msg =~ "Usage"
    end

    test "returns error for unknown subcommand" do
      context = %{
        nickname: "Tester",
        active_channel: "#test",
        channels: ["#test"],
        identified: false,
        operator_in: [],
        chan_serv: nil
      }

      assert {:error, msg} = Cs.execute(["invalid"], context)
      assert msg =~ "Unknown ChanServ command"
    end
  end

  describe "validate/1" do
    test "accepts any input" do
      assert :ok = Cs.validate("anything")
      assert :ok = Cs.validate("")
    end
  end

  describe "execute/2 - access level without subcommand" do
    test "sop without subcommand returns usage error" do
      context = %{
        nickname: "Tester",
        active_channel: "#test",
        channels: ["#test"],
        identified: false,
        operator_in: [],
        chan_serv: nil
      }

      assert {:error, msg} = Cs.execute(["sop"], context)
      assert msg =~ "Usage"
      assert msg =~ "sop"
    end

    test "aop without subcommand returns usage error" do
      context = %{
        nickname: "Tester",
        active_channel: "#test",
        channels: ["#test"],
        identified: false,
        operator_in: [],
        chan_serv: nil
      }

      assert {:error, msg} = Cs.execute(["aop"], context)
      assert msg =~ "aop"
    end

    test "vop without subcommand returns usage error" do
      context = %{
        nickname: "Tester",
        active_channel: "#test",
        channels: ["#test"],
        identified: false,
        operator_in: [],
        chan_serv: nil
      }

      assert {:error, msg} = Cs.execute(["vop"], context)
      assert msg =~ "vop"
    end
  end

  describe "execute/2 - manage_access error path" do
    test "manage_access returns error when manage_access fails", ctx do
      {:ok, :system, _} = Cs.execute(["register"], ctx.context)

      # Try to add access for a user without sufficient privilege
      # Create a non-founder user context
      NickServ.register("LowUser", "pass123", ctx.nick_server)

      low_context = %{
        ctx.context
        | nickname: "LowUser"
      }

      assert {:error, msg} = Cs.execute(["sop", "add", "SomeTarget"], low_context)
      assert msg =~ "ChanServ"
    end
  end

  describe "execute/2 - list_access error path" do
    test "list_access returns error for unregistered channel", ctx do
      # Use a context pointing to an unregistered channel
      context = %{ctx.context | active_channel: "#nonexistent_cs_list"}

      assert {:error, msg} = Cs.execute(["sop", "list"], context)
      assert msg =~ "ChanServ"
      assert msg =~ "not registered"
    end
  end

  # The outer setup registers CsTestUser with this password; a nickname it did
  # not register is registered with the same one.
  defp identify(nickname) do
    _ = NickServ.register(nickname, "pass123")
    {:ok, _} = NickServ.identify(nickname, "pass123")
  end

  defp stored_locale(channel) do
    Queries.find_registered_channel(channel).locale
  end

  defp registered?({:ok, _info}), do: {:ok, %{registered: true}}
  defp registered?({:error, _msg}), do: {:ok, %{registered: false}}
end
