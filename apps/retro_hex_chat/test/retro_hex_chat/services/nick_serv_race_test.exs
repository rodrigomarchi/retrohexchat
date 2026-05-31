defmodule RetroHexChat.Services.NickServRaceTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Services.NickServ

  describe "identify timer race condition" do
    test "identify just before timeout cancels timer and keeps user identified" do
      server_name = :"test_nickserv_race_#{System.unique_integer([:positive])}"
      {:ok, _pid} = NickServ.start_link(name: server_name, identify_timeout_ms: 300)

      nickname = unique_nick("RaceNick")
      password = "secret123"

      # Register the nick
      {:ok, _} = NickServ.register(nickname, password, server_name)

      # Start a new server (without identified state) so we can test the timer
      race_server = :"test_nickserv_race2_#{System.unique_integer([:positive])}"
      {:ok, _pid} = NickServ.start_link(name: race_server, identify_timeout_ms: 300)

      # Subscribe to user PubSub to watch for force_rename
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "user:#{nickname}")

      # Start the identify timer
      NickServ.start_identify_timer(nickname, race_server)

      # Wait 150ms (intentional timing: ~50% of the 300ms timeout).
      # This is a deliberate race-condition test — we need the identify call
      # to arrive after meaningful timer progress but before expiry.
      # The wait_until/3 polling pattern doesn't apply here because we're
      # testing a specific timing window, not waiting for a state change.
      Process.sleep(150)

      # Identify just before timeout
      assert {:ok, msg} = NickServ.identify(nickname, password, race_server)
      assert msg =~ "identified"

      # Verify the timer was cancelled -- no force_rename should arrive
      refute_receive {:force_rename, _}, 500

      # Verify user remains identified
      {:ok, info} = NickServ.info(nickname, race_server)
      assert info.identified == true
    end

    test "timeout fires before identify sends force_rename" do
      server_name = :"test_nickserv_timeout_#{System.unique_integer([:positive])}"
      {:ok, _pid} = NickServ.start_link(name: server_name, identify_timeout_ms: 100)

      nickname = unique_nick("TimeoutNick")
      password = "secret123"

      # Register the nick using a separate server
      reg_server = :"test_nickserv_reg_#{System.unique_integer([:positive])}"
      {:ok, _} = NickServ.start_link(name: reg_server)
      {:ok, _} = NickServ.register(nickname, password, reg_server)

      # Subscribe to PubSub before starting timer
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "user:#{nickname}")

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
      server_name = :"test_nickserv_serial_#{System.unique_integer([:positive])}"
      {:ok, _pid} = NickServ.start_link(name: server_name, identify_timeout_ms: 100)

      nickname = unique_nick("SerialNick")
      password = "secret123"

      # Register via this server (auto-identifies)
      {:ok, _} = NickServ.register(nickname, password, server_name)

      # New server without identified state
      serial_server = :"test_nickserv_serial2_#{System.unique_integer([:positive])}"
      {:ok, _pid} = NickServ.start_link(name: serial_server, identify_timeout_ms: 100)

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "user:#{nickname}")

      # Start timer
      NickServ.start_identify_timer(nickname, serial_server)

      # Immediately identify (synchronous call processed before async timer message)
      {:ok, _} = NickServ.identify(nickname, password, serial_server)

      # Timer should have been cancelled during identify
      refute_receive {:force_rename, _}, 300
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
