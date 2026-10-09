defmodule RetroHexChat.Commands.Handlers.CsTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Channels
  alias RetroHexChat.Chat.Archive
  alias RetroHexChat.Commands.Dispatcher
  alias RetroHexChat.Commands.Handlers.Cs
  alias RetroHexChat.Services.ChanServ
  alias RetroHexChat.Services.NickServ

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
      operator_in: [],
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
      context = %{ctx.context | active_channel: channel, channels: [channel]}
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

  describe "help/0" do
    test "returns help map" do
      help = Cs.help()
      assert help.name == "cs"
      assert is_binary(help.syntax)
      assert is_binary(help.description)
      assert is_list(help.examples)
    end
  end

  # The outer setup registers CsTestUser with this password; a nickname it did
  # not register is registered with the same one.
  defp identify(nickname) do
    _ = NickServ.register(nickname, "pass123")
    {:ok, _} = NickServ.identify(nickname, "pass123")
  end
end
