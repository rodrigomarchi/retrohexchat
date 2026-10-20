defmodule RetroHexChat.Services.NickServRaceTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Services.NickServ

  describe "identify timer race condition" do
    test "timeout fires before identify sends force_rename" do
      server_name = :"test_nickserv_timeout_#{rem(System.unique_integer([:positive]), 100_000)}"
      {:ok, _pid} = NickServ.start_link(name: server_name, identify_timeout_ms: 100)

      nickname = unique_nick("TimeoutNick")
      password = "secret123"

      # Register the nick using a separate server
      reg_server = :"test_nickserv_reg_#{rem(System.unique_integer([:positive]), 100_000)}"
      {:ok, _} = NickServ.start_link(name: reg_server)
      {:ok, _} = NickServ.register(nickname, password, reg_server)

      # Subscribe to PubSub before starting timer
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, RetroHexChat.Topics.inbox(nickname))

      # Start the identify timer on the short-timeout server
      NickServ.start_identify_timer(nickname, server_name)

      # Do NOT identify -- let the timeout fire
      assert_receive {:force_rename, %{reason: reason}}, 500
      assert reason =~ "Identify timeout"
    end

    test "GenServer serialization ensures identify before queued timeout" do
      # This test verifies that GenServer call/cast serialization works:
      # if identify is called before the timer message is processed,
      # the timer is cancelled during identify.
      server_name = :"test_nickserv_serial_#{rem(System.unique_integer([:positive]), 100_000)}"
      {:ok, _pid} = NickServ.start_link(name: server_name, identify_timeout_ms: 100)

      nickname = unique_nick("SerialNick")
      password = "secret123"

      # Register via this server (auto-identifies)
      {:ok, _} = NickServ.register(nickname, password, server_name)

      # New server without identified state
      serial_server = :"test_nickserv_serial2_#{System.unique_integer([:positive])}"
      {:ok, _pid} = NickServ.start_link(name: serial_server, identify_timeout_ms: 100)

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, RetroHexChat.Topics.inbox(nickname))

      # Start timer
      NickServ.start_identify_timer(nickname, serial_server)

      # Immediately identify (synchronous call processed before async timer message)
      {:ok, _} = NickServ.identify(nickname, password, serial_server)

      # Timer should have been cancelled during identify, leaving the nick identified
      assert :sys.get_state(serial_server).timers == %{}
      assert NickServ.identified?(nickname, serial_server)
      refute_receive {:force_rename, _}, 150
    end
  end

  defp unique_nick(prefix) do
    suffix =
      [:positive]
      |> System.unique_integer()
      |> rem(10_000)

    "#{prefix}#{suffix}"
  end
end
