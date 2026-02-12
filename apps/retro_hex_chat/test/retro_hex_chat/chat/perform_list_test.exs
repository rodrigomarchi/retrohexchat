defmodule RetroHexChat.Chat.PerformListTest do
  use RetroHexChat.DataCase, async: true

  alias RetroHexChat.Chat.PerformList

  describe "new/0" do
    test "returns empty list with defaults" do
      list = PerformList.new()
      assert list.entries == []
      assert list.settings.enable_on_connect == true
    end
  end

  describe "add_entry/2" do
    test "adds a command to the list" do
      list = PerformList.new()
      assert {:ok, updated} = PerformList.add_entry(list, "/join #elixir")
      assert PerformList.count(updated) == 1
      [entry] = PerformList.entries(updated)
      assert entry.command == "/join #elixir"
      assert entry.position == 0
    end

    test "appends commands in order" do
      list = PerformList.new()
      {:ok, list} = PerformList.add_entry(list, "/ns identify pass")
      {:ok, list} = PerformList.add_entry(list, "/join #elixir")
      {:ok, list} = PerformList.add_entry(list, "/join #phoenix")

      entries = PerformList.entries(list)
      assert length(entries) == 3
      assert Enum.at(entries, 0).command == "/ns identify pass"
      assert Enum.at(entries, 1).command == "/join #elixir"
      assert Enum.at(entries, 2).command == "/join #phoenix"
    end

    test "trims whitespace" do
      list = PerformList.new()
      {:ok, updated} = PerformList.add_entry(list, "  /join #elixir  ")
      [entry] = PerformList.entries(updated)
      assert entry.command == "/join #elixir"
    end

    test "rejects command not starting with /" do
      list = PerformList.new()
      assert {:error, :invalid_command} = PerformList.add_entry(list, "join #elixir")
    end

    test "rejects empty command" do
      list = PerformList.new()
      assert {:error, :invalid_command} = PerformList.add_entry(list, "/")
    end

    test "rejects just whitespace" do
      list = PerformList.new()
      assert {:error, :invalid_command} = PerformList.add_entry(list, "  ")
    end

    test "rejects disallowed /quit" do
      list = PerformList.new()
      assert {:error, :disallowed_command} = PerformList.add_entry(list, "/quit")
    end

    test "rejects disallowed /perform" do
      list = PerformList.new()
      assert {:error, :disallowed_command} = PerformList.add_entry(list, "/perform add /join #x")
    end

    test "rejects disallowed /autojoin" do
      list = PerformList.new()
      assert {:error, :disallowed_command} = PerformList.add_entry(list, "/autojoin add #x")
    end

    test "rejects disallowed /disconnect" do
      list = PerformList.new()
      assert {:error, :disallowed_command} = PerformList.add_entry(list, "/disconnect")
    end

    test "disallowed check is case-insensitive" do
      list = PerformList.new()
      assert {:error, :disallowed_command} = PerformList.add_entry(list, "/QUIT")
      assert {:error, :disallowed_command} = PerformList.add_entry(list, "/Perform list")
    end

    test "rejects command exceeding 500 characters" do
      list = PerformList.new()
      long_cmd = "/" <> String.duplicate("a", 500)
      assert {:error, :command_too_long} = PerformList.add_entry(list, long_cmd)
    end

    test "accepts command at exactly 500 characters" do
      list = PerformList.new()
      cmd = "/" <> String.duplicate("a", 499)
      assert {:ok, _} = PerformList.add_entry(list, cmd)
    end

    test "rejects when list is full (50 entries)" do
      list =
        Enum.reduce(0..49, PerformList.new(), fn i, acc ->
          {:ok, updated} = PerformList.add_entry(acc, "/join #ch#{i}")
          updated
        end)

      assert PerformList.full?(list)
      assert {:error, :list_full} = PerformList.add_entry(list, "/join #extra")
    end
  end

  describe "remove_entry/2" do
    test "removes entry by position" do
      list = PerformList.new()
      {:ok, list} = PerformList.add_entry(list, "/join #elixir")
      {:ok, list} = PerformList.add_entry(list, "/join #phoenix")
      assert PerformList.count(list) == 2

      {:ok, updated} = PerformList.remove_entry(list, 0)
      assert PerformList.count(updated) == 1
      [entry] = PerformList.entries(updated)
      assert entry.command == "/join #phoenix"
      assert entry.position == 0
    end

    test "returns error for non-existent position" do
      list = PerformList.new()
      assert {:error, :not_found} = PerformList.remove_entry(list, 0)
    end

    test "reindexes after removal" do
      list = PerformList.new()
      {:ok, list} = PerformList.add_entry(list, "/cmd1")
      {:ok, list} = PerformList.add_entry(list, "/cmd2")
      {:ok, list} = PerformList.add_entry(list, "/cmd3")

      {:ok, updated} = PerformList.remove_entry(list, 1)
      entries = PerformList.entries(updated)
      assert length(entries) == 2
      assert Enum.at(entries, 0).position == 0
      assert Enum.at(entries, 1).position == 1
      assert Enum.at(entries, 0).command == "/cmd1"
      assert Enum.at(entries, 1).command == "/cmd3"
    end
  end

  describe "move_entry/3" do
    test "moves entry from position 0 to position 2" do
      list = PerformList.new()
      {:ok, list} = PerformList.add_entry(list, "/cmd1")
      {:ok, list} = PerformList.add_entry(list, "/cmd2")
      {:ok, list} = PerformList.add_entry(list, "/cmd3")

      {:ok, updated} = PerformList.move_entry(list, 0, 2)
      entries = PerformList.entries(updated)
      assert Enum.at(entries, 0).command == "/cmd2"
      assert Enum.at(entries, 1).command == "/cmd3"
      assert Enum.at(entries, 2).command == "/cmd1"
    end

    test "moves entry from position 2 to position 0" do
      list = PerformList.new()
      {:ok, list} = PerformList.add_entry(list, "/cmd1")
      {:ok, list} = PerformList.add_entry(list, "/cmd2")
      {:ok, list} = PerformList.add_entry(list, "/cmd3")

      {:ok, updated} = PerformList.move_entry(list, 2, 0)
      entries = PerformList.entries(updated)
      assert Enum.at(entries, 0).command == "/cmd3"
      assert Enum.at(entries, 1).command == "/cmd1"
      assert Enum.at(entries, 2).command == "/cmd2"
    end

    test "returns error for same position" do
      list = PerformList.new()
      {:ok, list} = PerformList.add_entry(list, "/cmd1")
      assert {:error, :same_position} = PerformList.move_entry(list, 0, 0)
    end

    test "returns error for invalid from position" do
      list = PerformList.new()
      {:ok, list} = PerformList.add_entry(list, "/cmd1")
      assert {:error, :invalid_position} = PerformList.move_entry(list, 5, 0)
    end

    test "returns error for invalid to position" do
      list = PerformList.new()
      {:ok, list} = PerformList.add_entry(list, "/cmd1")
      assert {:error, :invalid_position} = PerformList.move_entry(list, 0, 5)
    end

    test "returns error for negative positions" do
      list = PerformList.new()
      {:ok, list} = PerformList.add_entry(list, "/cmd1")
      assert {:error, :invalid_position} = PerformList.move_entry(list, -1, 0)
    end
  end

  describe "clear/1" do
    test "removes all entries" do
      list = PerformList.new()
      {:ok, list} = PerformList.add_entry(list, "/cmd1")
      {:ok, list} = PerformList.add_entry(list, "/cmd2")
      assert PerformList.count(list) == 2

      {:ok, cleared} = PerformList.clear(list)
      assert PerformList.count(cleared) == 0
      assert PerformList.entries(cleared) == []
    end

    test "preserves settings" do
      list = PerformList.new() |> PerformList.set_enabled(false)
      {:ok, list} = PerformList.add_entry(list, "/cmd1")
      {:ok, cleared} = PerformList.clear(list)
      refute PerformList.enabled?(cleared)
    end
  end

  describe "entries/1" do
    test "returns entries sorted by position" do
      list = PerformList.new()
      {:ok, list} = PerformList.add_entry(list, "/cmd1")
      {:ok, list} = PerformList.add_entry(list, "/cmd2")

      entries = PerformList.entries(list)
      assert length(entries) == 2
      assert Enum.at(entries, 0).position == 0
      assert Enum.at(entries, 1).position == 1
    end

    test "returns empty list for new list" do
      assert PerformList.entries(PerformList.new()) == []
    end
  end

  describe "count/1" do
    test "returns 0 for empty list" do
      assert PerformList.count(PerformList.new()) == 0
    end

    test "returns correct count" do
      list = PerformList.new()
      {:ok, list} = PerformList.add_entry(list, "/cmd1")
      {:ok, list} = PerformList.add_entry(list, "/cmd2")
      assert PerformList.count(list) == 2
    end
  end

  describe "full?/1" do
    test "returns false for empty list" do
      refute PerformList.full?(PerformList.new())
    end

    test "returns true at 50 entries" do
      list =
        Enum.reduce(0..49, PerformList.new(), fn i, acc ->
          {:ok, updated} = PerformList.add_entry(acc, "/join #ch#{i}")
          updated
        end)

      assert PerformList.full?(list)
    end
  end

  describe "enabled?/1 and set_enabled/2" do
    test "defaults to true" do
      assert PerformList.enabled?(PerformList.new())
    end

    test "can be disabled" do
      list = PerformList.set_enabled(PerformList.new(), false)
      refute PerformList.enabled?(list)
    end

    test "can be re-enabled" do
      list =
        PerformList.new()
        |> PerformList.set_enabled(false)
        |> PerformList.set_enabled(true)

      assert PerformList.enabled?(list)
    end
  end

  describe "mask_command/1" do
    test "masks /ns identify password" do
      assert PerformList.mask_command("/ns identify secret123") == "/ns identify ****"
    end

    test "masks /NS IDENTIFY password (case-insensitive)" do
      assert PerformList.mask_command("/NS IDENTIFY MyPass") == "/NS IDENTIFY ****"
    end

    test "masks /msg NickServ identify password" do
      assert PerformList.mask_command("/msg NickServ identify pass123") ==
               "/msg NickServ identify ****"
    end

    test "masks /msg nickserv identify password (case-insensitive)" do
      assert PerformList.mask_command("/msg nickserv identify Pass") ==
               "/msg nickserv identify ****"
    end

    test "does not mask non-identify commands" do
      assert PerformList.mask_command("/join #elixir") == "/join #elixir"
    end

    test "does not mask /ns without identify" do
      assert PerformList.mask_command("/ns info Alice") == "/ns info Alice"
    end

    test "handles /ns identify with extra spaces" do
      assert PerformList.mask_command("/ns  identify  secret") == "/ns  identify  ****"
    end
  end

  describe "disallowed_command?/1" do
    test "returns true for /quit" do
      assert PerformList.disallowed_command?("/quit")
    end

    test "returns true for /perform" do
      assert PerformList.disallowed_command?("/perform")
    end

    test "returns true for /autojoin" do
      assert PerformList.disallowed_command?("/autojoin")
    end

    test "returns true for /disconnect" do
      assert PerformList.disallowed_command?("/disconnect")
    end

    test "is case-insensitive" do
      assert PerformList.disallowed_command?("/QUIT")
      assert PerformList.disallowed_command?("/Perform")
    end

    test "returns false for allowed commands" do
      refute PerformList.disallowed_command?("/join #elixir")
      refute PerformList.disallowed_command?("/ns identify pass")
      refute PerformList.disallowed_command?("/msg NickServ identify p")
    end
  end

  describe "valid_command?/1" do
    test "returns true for commands starting with /" do
      assert PerformList.valid_command?("/join #elixir")
      assert PerformList.valid_command?("/ns identify pass")
    end

    test "returns false for commands not starting with /" do
      refute PerformList.valid_command?("join #elixir")
      refute PerformList.valid_command?("hello")
    end

    test "returns false for just /" do
      refute PerformList.valid_command?("/")
    end

    test "returns false for empty string" do
      refute PerformList.valid_command?("")
    end
  end

  describe "save/2 and load/1" do
    @tag :integration
    test "persists and loads perform list with entries and settings" do
      owner = "PerfUser#{System.unique_integer([:positive])}"
      register_nick(owner)

      list = PerformList.new()
      {:ok, list} = PerformList.add_entry(list, "/ns identify secret")
      {:ok, list} = PerformList.add_entry(list, "/join #elixir")
      {:ok, list} = PerformList.add_entry(list, "/join #phoenix")

      assert :ok = PerformList.save(owner, list)

      assert {:ok, loaded} = PerformList.load(owner)
      entries = PerformList.entries(loaded)
      assert length(entries) == 3
      assert Enum.at(entries, 0).command == "/ns identify secret"
      assert Enum.at(entries, 1).command == "/join #elixir"
      assert Enum.at(entries, 2).command == "/join #phoenix"
      assert PerformList.enabled?(loaded)
    end

    @tag :integration
    test "persists disabled state" do
      owner = "PerfUser#{System.unique_integer([:positive])}"
      register_nick(owner)

      list = PerformList.new() |> PerformList.set_enabled(false)
      {:ok, list} = PerformList.add_entry(list, "/join #test")

      assert :ok = PerformList.save(owner, list)

      assert {:ok, loaded} = PerformList.load(owner)
      refute PerformList.enabled?(loaded)
    end

    @tag :integration
    test "save replaces previous entries" do
      owner = "PerfUser#{System.unique_integer([:positive])}"
      register_nick(owner)

      list1 = PerformList.new()
      {:ok, list1} = PerformList.add_entry(list1, "/join #old")
      assert :ok = PerformList.save(owner, list1)

      list2 = PerformList.new()
      {:ok, list2} = PerformList.add_entry(list2, "/join #new")
      assert :ok = PerformList.save(owner, list2)

      assert {:ok, loaded} = PerformList.load(owner)
      entries = PerformList.entries(loaded)
      assert length(entries) == 1
      assert Enum.at(entries, 0).command == "/join #new"
    end

    @tag :integration
    test "load returns error for unknown user" do
      assert {:error, :not_found} = PerformList.load("NonExistent")
    end

    @tag :integration
    test "save empty list with settings still loads" do
      owner = "PerfUser#{System.unique_integer([:positive])}"
      register_nick(owner)

      list = PerformList.new() |> PerformList.set_enabled(false)
      assert :ok = PerformList.save(owner, list)

      assert {:ok, loaded} = PerformList.load(owner)
      assert PerformList.count(loaded) == 0
      refute PerformList.enabled?(loaded)
    end
  end

  defp register_nick(nickname) do
    RetroHexChat.Repo.insert_all("registered_nicks", [
      %{
        nickname: nickname,
        password_hash: Bcrypt.hash_pwd_salt("password"),
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
    ])
  end
end
