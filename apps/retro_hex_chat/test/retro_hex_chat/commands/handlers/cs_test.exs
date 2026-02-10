defmodule RetroHexChat.Commands.Handlers.CsTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Commands.Handlers.Cs
  alias RetroHexChat.Services.ChanServ
  alias RetroHexChat.Services.NickServ

  setup do
    nick_server = :"nickserv_cs_h_#{System.unique_integer([:positive])}"
    {:ok, _} = NickServ.start_link(name: nick_server)

    cs_server = :"chanserv_h_#{System.unique_integer([:positive])}"
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

  describe "execute/2 - info" do
    test "returns channel info", ctx do
      {:ok, :system, _} = Cs.execute(["register"], ctx.context)

      assert {:ok, :system, %{content: content}} = Cs.execute(["info"], ctx.context)
      assert content =~ "#testchan"
      assert content =~ "CsTestUser"
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

  describe "execute/2 - help" do
    test "returns help ui_action" do
      context = %{
        nickname: "Tester",
        active_channel: "#test",
        channels: ["#test"],
        identified: false,
        operator_in: [],
        chan_serv: nil
      }

      assert {:ok, :ui_action, :show_help, %{commands: commands}} =
               Cs.execute(["help"], context)

      assert is_list(commands)
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
end
