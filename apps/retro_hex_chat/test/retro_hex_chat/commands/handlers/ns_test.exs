defmodule RetroHexChat.Commands.Handlers.NsTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Commands.Handlers.Ns
  alias RetroHexChat.Services.NickServ
  alias RetroHexChat.Services.Queries

  @base_context %{
    nickname: "TestUser",
    active_channel: "#lobby",
    channels: ["#lobby"],
    identified: false,
    operator_in: []
  }

  describe "validate/1" do
    test "accepts any args" do
      assert :ok = Ns.validate("register password123")
      assert :ok = Ns.validate("")
    end
  end

  describe "execute/2 - register" do
    test "registers a nickname" do
      context = %{@base_context | nickname: "NsRegUser"}

      assert {:ok, :system, %{content: content}} =
               Ns.execute(["register", "secret123"], context)

      assert content =~ "NickServ"
      assert content =~ "registered"
    end

    test "returns error without password" do
      assert {:error, msg} = Ns.execute(["register"], @base_context)
      assert msg =~ "Usage"
    end
  end

  describe "execute/2 - identify" do
    test "identifies a registered nickname" do
      # Register directly via Queries to avoid marking as identified in default NickServ
      {:ok, _} = Queries.insert_registered_nick("NsIdUser", "secret123")

      context = %{@base_context | nickname: "NsIdUser"}

      assert {:ok, :system, %{content: content}} =
               Ns.execute(["identify", "secret123"], context)

      assert content =~ "identified"
    end

    test "returns error without password" do
      assert {:error, msg} = Ns.execute(["identify"], @base_context)
      assert msg =~ "Usage"
    end
  end

  describe "execute/2 - ghost" do
    test "ghosts a target when identified" do
      {:ok, _} = NickServ.register("NsGhostTgt", "secret123")
      {:ok, _} = NickServ.register("NsGhoster", "secret456")

      context = %{@base_context | nickname: "NsGhoster"}

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "user:NsGhostTgt")

      assert {:ok, :system, %{content: content}} =
               Ns.execute(["ghost", "NsGhostTgt"], context)

      assert content =~ "Ghost command sent"
    end

    test "returns error without target" do
      assert {:error, msg} = Ns.execute(["ghost"], @base_context)
      assert msg =~ "Usage"
    end
  end

  describe "execute/2 - info" do
    test "shows info for a registered nickname" do
      {:ok, _} = NickServ.register("NsInfoNick", "secret123")
      context = %{@base_context | nickname: "NsInfoNick"}

      assert {:ok, :system, %{content: content}} =
               Ns.execute(["info", "NsInfoNick"], context)

      assert content =~ "NsInfoNick"
      assert content =~ "registered"
    end

    test "defaults to own nickname when no target given" do
      {:ok, _} = NickServ.register("NsSelfInfo", "secret123")
      context = %{@base_context | nickname: "NsSelfInfo"}

      assert {:ok, :system, %{content: content}} = Ns.execute(["info"], context)
      assert content =~ "NsSelfInfo"
    end

    test "returns error for unregistered nickname" do
      assert {:error, msg} = Ns.execute(["info", "NoSuchNs"], @base_context)
      assert msg =~ "not registered"
    end
  end

  describe "execute/2 - drop" do
    test "drops registration with correct password" do
      context = %{@base_context | nickname: "NsDropNick"}
      {:ok, _} = NickServ.register("NsDropNick", "secret123")

      assert {:ok, :system, %{content: content}} =
               Ns.execute(["drop", "secret123"], context)

      assert content =~ "dropped"
    end

    test "returns error without password" do
      assert {:error, msg} = Ns.execute(["drop"], @base_context)
      assert msg =~ "Usage"
    end
  end

  describe "execute/2 - help" do
    test "returns help ui_action" do
      assert {:ok, :ui_action, :show_help, %{commands: commands}} =
               Ns.execute(["help"], @base_context)

      assert is_list(commands)
    end
  end

  describe "execute/2 - edge cases" do
    test "returns error for no subcommand" do
      assert {:error, msg} = Ns.execute([], @base_context)
      assert msg =~ "Usage"
    end

    test "returns error for unknown subcommand" do
      assert {:error, msg} = Ns.execute(["invalid"], @base_context)
      assert msg =~ "Unknown NickServ command"
    end
  end

  describe "execute/2 - error paths via handler" do
    test "register returns error when nick already registered" do
      {:ok, _} = NickServ.register("NsDupeReg", "pass123")
      context = %{@base_context | nickname: "NsDupeReg"}

      # Second registration with different password should fail via handler
      assert {:error, msg} = Ns.execute(["register", "otherpass"], context)
      assert msg =~ "NickServ"
    end

    test "identify returns error with wrong password" do
      {:ok, _} = Queries.insert_registered_nick("NsBadPw", "correct123")
      context = %{@base_context | nickname: "NsBadPw"}

      assert {:error, msg} = Ns.execute(["identify", "wrong_password"], context)
      assert msg =~ "NickServ"
    end

    test "ghost returns error for unregistered nick" do
      context = %{@base_context | nickname: "GhostRequester"}

      assert {:error, msg} = Ns.execute(["ghost", "UnregisteredGhostTarget"], context)
      assert msg =~ "NickServ"
    end

    test "drop returns error with wrong password" do
      {:ok, _} = NickServ.register("NsDropBad", "correct123")
      context = %{@base_context | nickname: "NsDropBad"}

      assert {:error, msg} = Ns.execute(["drop", "wrong_password"], context)
      assert msg =~ "NickServ"
    end
  end

  describe "help/0" do
    test "returns help map" do
      help = Ns.help()
      assert help.name == "ns"
      assert is_binary(help.syntax)
      assert is_binary(help.description)
      assert is_list(help.examples)
    end
  end
end
