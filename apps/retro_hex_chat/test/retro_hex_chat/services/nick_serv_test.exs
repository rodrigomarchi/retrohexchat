defmodule RetroHexChat.Services.NickServTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Services.NickServ

  setup do
    server_name = :"nickserv_#{System.unique_integer([:positive])}"
    {:ok, pid} = NickServ.start_link(name: server_name)
    %{server: server_name, pid: pid}
  end

  describe "register/2" do
    test "registers a nickname successfully", %{server: server} do
      assert {:ok, msg} = NickServ.register("RegNick", "secret123", server)
      assert msg =~ "RegNick"
      assert msg =~ "registered"
    end

    test "returns error for duplicate registration", %{server: server} do
      {:ok, _} = NickServ.register("DupeReg", "secret123", server)
      assert {:error, msg} = NickServ.register("DupeReg", "secret456", server)
      assert is_binary(msg)
    end

    test "duplicate registration error contains descriptive message", %{server: server} do
      {:ok, _} = NickServ.register("DupeDesc", "pass1", server)
      assert {:error, msg} = NickServ.register("DupeDesc", "pass2", server)
      assert msg =~ "nickname" or msg =~ "already" or msg =~ "taken" or msg =~ "unique"
    end

    test "marks user as identified after registration", %{server: server} do
      {:ok, _} = NickServ.register("IdentReg", "secret123", server)
      {:ok, info} = NickServ.info("IdentReg", server)
      assert info.identified == true
    end
  end

  describe "identify/2" do
    test "identifies with correct password", %{server: server} do
      {:ok, _} = NickServ.register("IdNick", "secret123", server)

      # Start a new server to lose identified state
      new_server = :"nickserv_ident_#{System.unique_integer([:positive])}"
      {:ok, _} = NickServ.start_link(name: new_server)

      assert {:ok, msg} = NickServ.identify("IdNick", "secret123", new_server)
      assert msg =~ "identified"
    end

    test "returns error for wrong password", %{server: server} do
      {:ok, _} = NickServ.register("WrongPw", "secret123", server)
      assert {:error, "Invalid password"} = NickServ.identify("WrongPw", "wrongpwd", server)
    end

    test "returns error for unregistered nick", %{server: server} do
      assert {:error, msg} = NickServ.identify("NoReg", "secret123", server)
      assert msg =~ "not registered"
    end
  end

  describe "registered?/1" do
    test "returns true for registered nick", %{server: server} do
      {:ok, _} = NickServ.register("CheckReg", "secret123", server)
      assert NickServ.registered?("CheckReg", server) == true
    end

    test "returns false for unregistered nick", %{server: server} do
      assert NickServ.registered?("NotReg", server) == false
    end
  end

  describe "info/1" do
    test "returns info map for registered nick", %{server: server} do
      {:ok, _} = NickServ.register("InfoNick", "secret123", server)
      assert {:ok, info} = NickServ.info("InfoNick", server)
      assert info.nickname == "InfoNick"
      assert info.registered_at != nil
      assert info.identified == true
    end

    test "returns error for unregistered nick", %{server: server} do
      assert {:error, msg} = NickServ.info("NoInfo", server)
      assert msg =~ "not registered"
    end
  end

  describe "ghost/2" do
    test "sends force_disconnect with target password", %{server: server} do
      {:ok, _} = NickServ.register("GhostTarget", "secret123", server)

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "user:GhostTarget")

      assert {:ok, msg} = NickServ.ghost("GhostTarget", "secret123", "GhostReq", server)
      assert msg =~ "Ghost command sent"

      assert_receive {:force_disconnect, %{reason: reason}}
      assert reason =~ "GhostReq"
    end

    test "returns error with invalid target password", %{server: server} do
      {:ok, _} = NickServ.register("GhostTgt2", "secret123", server)
      assert {:error, msg} = NickServ.ghost("GhostTgt2", "wrong", "GhostReq2", server)
      assert msg =~ "Invalid password"
    end

    test "returns error when target not registered", %{server: server} do
      assert {:error, msg} = NickServ.ghost("NotRegged", "secret123", "GhostReq2", server)
      assert msg =~ "not registered"
    end
  end

  describe "drop/2" do
    test "drops registration with correct password", %{server: server} do
      {:ok, _} = NickServ.register("DropNick", "secret123", server)
      assert {:ok, msg} = NickServ.drop("DropNick", "secret123", server)
      assert msg =~ "dropped"
      assert NickServ.registered?("DropNick", server) == false
    end

    test "returns error with wrong password", %{server: server} do
      {:ok, _} = NickServ.register("DropWrong", "secret123", server)
      assert {:error, "Invalid password"} = NickServ.drop("DropWrong", "wrongpwd", server)
    end

    test "returns error for unregistered nick", %{server: server} do
      assert {:error, msg} = NickServ.drop("NoDrop", "secret123", server)
      assert msg =~ "not registered"
    end
  end

  describe "start_identify_timer/1 and cancel_identify_timer/1" do
    test "starts and cancels a timer", %{server: server} do
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "user:TimerNick")

      NickServ.start_identify_timer("TimerNick", server)
      NickServ.cancel_identify_timer("TimerNick", server)

      # Give a brief moment for cast processing
      Process.sleep(50)

      # Should NOT receive a timeout since timer was cancelled
      refute_receive {:force_rename, _}, 200
    end
  end

  describe "identify broadcasts :nickserv_identified" do
    test "identify broadcasts to user topic on success", %{server: server} do
      {:ok, _} = NickServ.register("BcastNick", "secret123", server)

      # New server to lose identified state
      new_server = :"nickserv_bcast_#{System.unique_integer([:positive])}"
      {:ok, _} = NickServ.start_link(name: new_server)

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "user:BcastNick")

      {:ok, _} = NickServ.identify("BcastNick", "secret123", new_server)

      assert_receive {:nickserv_identified, %{nickname: "BcastNick"}}
    end

    test "register does not broadcast :nickserv_identified", %{server: server} do
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "user:RegBcast")

      {:ok, _} = NickServ.register("RegBcast", "secret123", server)

      refute_receive {:nickserv_identified, _}, 100
    end
  end

  describe "identify timer expiry" do
    test "forces rename on timeout", _ctx do
      # Start a NickServ with a very short timeout for testing
      short_server = :"nickserv_short_#{System.unique_integer([:positive])}"
      {:ok, _pid} = NickServ.start_link(name: short_server, identify_timeout_ms: 100)

      {:ok, _} = NickServ.register("TimeoutNick", "secret123", short_server)

      # Start a new server for the timeout test (no identified state)
      timeout_server = :"nickserv_timeout_#{System.unique_integer([:positive])}"
      {:ok, _} = NickServ.start_link(name: timeout_server, identify_timeout_ms: 100)

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "user:TimeoutNick")

      NickServ.start_identify_timer("TimeoutNick", timeout_server)

      assert_receive {:force_rename, %{reason: reason}}, 500
      assert reason =~ "Identify timeout"
    end
  end
end
