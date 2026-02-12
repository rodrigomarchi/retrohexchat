defmodule RetroHexChat.Chat.CustomMenusTest do
  use RetroHexChat.DataCase, async: true

  alias RetroHexChat.Chat.CustomMenus

  # ── Unit Tests ──────────────────────────────────────────

  describe "new/0" do
    @tag :unit
    test "returns empty list" do
      menus = CustomMenus.new()
      assert menus.entries == []
    end
  end

  describe "add_entry/4" do
    @tag :unit
    test "adds a nicklist menu item" do
      menus = CustomMenus.new()
      assert {:ok, updated} = CustomMenus.add_entry(menus, :nicklist, "Greet", "/notice $1 Hi!")
      entries = CustomMenus.entries_for(updated, :nicklist)
      assert length(entries) == 1
      assert hd(entries).label == "Greet"
      assert hd(entries).command == "/notice $1 Hi!"
    end

    @tag :unit
    test "adds a channel menu item" do
      menus = CustomMenus.new()
      assert {:ok, updated} = CustomMenus.add_entry(menus, :channel, "Topic", "/topic $chan")
      entries = CustomMenus.entries_for(updated, :channel)
      assert length(entries) == 1
    end

    @tag :unit
    test "rejects duplicate label (case-insensitive, same menu_type)" do
      menus = CustomMenus.new()
      {:ok, menus} = CustomMenus.add_entry(menus, :nicklist, "Greet", "/notice $1 Hi!")

      assert {:error, :duplicate_label} =
               CustomMenus.add_entry(menus, :nicklist, "GREET", "/me test")
    end

    @tag :unit
    test "allows same label in different menu types" do
      menus = CustomMenus.new()
      {:ok, menus} = CustomMenus.add_entry(menus, :nicklist, "Greet", "/notice $1 Hi!")
      assert {:ok, _} = CustomMenus.add_entry(menus, :channel, "Greet", "/me hello")
    end

    @tag :unit
    test "rejects when menu is full (10 per type)" do
      menus =
        Enum.reduce(0..9, CustomMenus.new(), fn i, acc ->
          {:ok, updated} = CustomMenus.add_entry(acc, :nicklist, "Item#{i}", "/me test")
          updated
        end)

      assert {:error, :menu_full} = CustomMenus.add_entry(menus, :nicklist, "Extra", "/me test")
    end

    @tag :unit
    test "allows adding to other type even if one is full" do
      menus =
        Enum.reduce(0..9, CustomMenus.new(), fn i, acc ->
          {:ok, updated} = CustomMenus.add_entry(acc, :nicklist, "Item#{i}", "/me test")
          updated
        end)

      assert {:ok, _} = CustomMenus.add_entry(menus, :channel, "Item0", "/me test")
    end

    @tag :unit
    test "rejects empty label" do
      menus = CustomMenus.new()
      assert {:error, :invalid_label} = CustomMenus.add_entry(menus, :nicklist, "", "/me test")
    end

    @tag :unit
    test "rejects label too long" do
      menus = CustomMenus.new()
      long_label = String.duplicate("a", 51)

      assert {:error, :invalid_label} =
               CustomMenus.add_entry(menus, :nicklist, long_label, "/me test")
    end

    @tag :unit
    test "rejects command too long" do
      menus = CustomMenus.new()
      long_cmd = "/" <> String.duplicate("a", 500)

      assert {:error, :command_too_long} =
               CustomMenus.add_entry(menus, :nicklist, "Test", long_cmd)
    end
  end

  describe "remove_entry/3" do
    @tag :unit
    test "removes entry by menu_type and label" do
      menus = CustomMenus.new()
      {:ok, menus} = CustomMenus.add_entry(menus, :nicklist, "Greet", "/notice $1 Hi!")
      {:ok, updated} = CustomMenus.remove_entry(menus, :nicklist, "Greet")
      assert CustomMenus.entries_for(updated, :nicklist) == []
    end

    @tag :unit
    test "returns error for not found" do
      menus = CustomMenus.new()
      assert {:error, :not_found} = CustomMenus.remove_entry(menus, :nicklist, "Nope")
    end
  end

  describe "update_entry/5" do
    @tag :unit
    test "updates label and command" do
      menus = CustomMenus.new()
      {:ok, menus} = CustomMenus.add_entry(menus, :nicklist, "Greet", "/notice $1 Hi!")

      {:ok, updated} =
        CustomMenus.update_entry(menus, :nicklist, "Greet", "Wave", "/me waves at $1")

      entries = CustomMenus.entries_for(updated, :nicklist)
      assert hd(entries).label == "Wave"
      assert hd(entries).command == "/me waves at $1"
    end

    @tag :unit
    test "returns error for not found" do
      menus = CustomMenus.new()

      assert {:error, :not_found} =
               CustomMenus.update_entry(menus, :nicklist, "Nope", "New", "/me test")
    end
  end

  describe "entries_for/2" do
    @tag :unit
    test "returns entries filtered by menu_type ordered by position" do
      menus = CustomMenus.new()
      {:ok, menus} = CustomMenus.add_entry(menus, :nicklist, "A", "/me a")
      {:ok, menus} = CustomMenus.add_entry(menus, :channel, "B", "/me b")
      {:ok, menus} = CustomMenus.add_entry(menus, :nicklist, "C", "/me c")

      nicklist = CustomMenus.entries_for(menus, :nicklist)
      assert length(nicklist) == 2
      assert Enum.at(nicklist, 0).label == "A"
      assert Enum.at(nicklist, 1).label == "C"

      channel = CustomMenus.entries_for(menus, :channel)
      assert length(channel) == 1
      assert hd(channel).label == "B"
    end
  end

  # ── Integration Tests (Persistence) ─────────────────────

  describe "save/2 and load/1" do
    @tag :integration
    test "persists and loads custom menus" do
      owner = "MenuUser#{System.unique_integer([:positive])}"
      register_nick(owner)

      menus = CustomMenus.new()
      {:ok, menus} = CustomMenus.add_entry(menus, :nicklist, "Greet", "/notice $1 Hi!")
      {:ok, menus} = CustomMenus.add_entry(menus, :channel, "Topic", "/topic $chan")

      assert :ok = CustomMenus.save(owner, menus)

      assert {:ok, loaded} = CustomMenus.load(owner)
      assert length(CustomMenus.entries_for(loaded, :nicklist)) == 1
      assert length(CustomMenus.entries_for(loaded, :channel)) == 1
    end

    @tag :integration
    test "load returns error for unknown user" do
      assert {:error, :not_found} = CustomMenus.load("NonExistentUser")
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
