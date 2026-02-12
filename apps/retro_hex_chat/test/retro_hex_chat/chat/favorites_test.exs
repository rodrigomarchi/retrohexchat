defmodule RetroHexChat.Chat.FavoritesTest do
  use RetroHexChat.DataCase, async: true

  alias RetroHexChat.Chat.Favorites

  describe "new/0" do
    test "returns empty favorites" do
      favorites = Favorites.new()
      assert favorites.entries == []
    end
  end

  describe "add_entry/2" do
    test "adds a favorite" do
      favorites = Favorites.new()
      assert {:ok, updated} = Favorites.add_entry(favorites, %{channel_name: "#elixir"})
      [entry] = Favorites.entries(updated)
      assert entry.channel_name == "#elixir"
      assert entry.description == ""
      assert entry.password == nil
      assert entry.auto_join == false
      assert entry.position == 0
    end

    test "adds with all fields" do
      favorites = Favorites.new()

      assert {:ok, updated} =
               Favorites.add_entry(favorites, %{
                 channel_name: "#secret",
                 description: "Secret channel",
                 password: "pass123",
                 auto_join: true
               })

      [entry] = Favorites.entries(updated)
      assert entry.channel_name == "#secret"
      assert entry.description == "Secret channel"
      assert entry.password == "pass123"
      assert entry.auto_join == true
    end

    test "appends in order" do
      favorites = Favorites.new()
      {:ok, favorites} = Favorites.add_entry(favorites, %{channel_name: "#a"})
      {:ok, favorites} = Favorites.add_entry(favorites, %{channel_name: "#b"})
      {:ok, favorites} = Favorites.add_entry(favorites, %{channel_name: "#c"})

      entries = Favorites.entries(favorites)
      assert length(entries) == 3
      assert Enum.at(entries, 0).channel_name == "#a"
      assert Enum.at(entries, 1).channel_name == "#b"
      assert Enum.at(entries, 2).channel_name == "#c"
    end

    test "rejects duplicate (case-insensitive)" do
      favorites = Favorites.new()
      {:ok, favorites} = Favorites.add_entry(favorites, %{channel_name: "#Elixir"})
      assert {:error, :duplicate} = Favorites.add_entry(favorites, %{channel_name: "#elixir"})
      assert {:error, :duplicate} = Favorites.add_entry(favorites, %{channel_name: "#ELIXIR"})
    end
  end

  describe "update_entry/3" do
    test "updates description" do
      favorites = Favorites.new()

      {:ok, favorites} =
        Favorites.add_entry(favorites, %{channel_name: "#ch", description: "old"})

      {:ok, updated} = Favorites.update_entry(favorites, "#ch", %{description: "new"})
      entry = Favorites.find_entry(updated, "#ch")
      assert entry.description == "new"
    end

    test "updates password" do
      favorites = Favorites.new()
      {:ok, favorites} = Favorites.add_entry(favorites, %{channel_name: "#ch", password: "old"})

      {:ok, updated} = Favorites.update_entry(favorites, "#ch", %{password: "new"})
      entry = Favorites.find_entry(updated, "#ch")
      assert entry.password == "new"
    end

    test "updates auto_join" do
      favorites = Favorites.new()
      {:ok, favorites} = Favorites.add_entry(favorites, %{channel_name: "#ch"})

      {:ok, updated} = Favorites.update_entry(favorites, "#ch", %{auto_join: true})
      entry = Favorites.find_entry(updated, "#ch")
      assert entry.auto_join == true
    end

    test "is case-insensitive" do
      favorites = Favorites.new()
      {:ok, favorites} = Favorites.add_entry(favorites, %{channel_name: "#Secret"})
      {:ok, updated} = Favorites.update_entry(favorites, "#secret", %{description: "updated"})
      entry = Favorites.find_entry(updated, "#Secret")
      assert entry.description == "updated"
    end

    test "returns error for non-existent channel" do
      favorites = Favorites.new()

      assert {:error, :not_found} =
               Favorites.update_entry(favorites, "#missing", %{description: "x"})
    end
  end

  describe "remove_entry/2" do
    test "removes entry by channel name" do
      favorites = Favorites.new()
      {:ok, favorites} = Favorites.add_entry(favorites, %{channel_name: "#a"})
      {:ok, favorites} = Favorites.add_entry(favorites, %{channel_name: "#b"})

      {:ok, updated} = Favorites.remove_entry(favorites, "#a")
      entries = Favorites.entries(updated)
      assert length(entries) == 1
      assert hd(entries).channel_name == "#b"
      assert hd(entries).position == 0
    end

    test "is case-insensitive" do
      favorites = Favorites.new()
      {:ok, favorites} = Favorites.add_entry(favorites, %{channel_name: "#Elixir"})
      {:ok, updated} = Favorites.remove_entry(favorites, "#elixir")
      assert Favorites.entries(updated) == []
    end

    test "returns error for non-existent channel" do
      favorites = Favorites.new()
      assert {:error, :not_found} = Favorites.remove_entry(favorites, "#missing")
    end

    test "reindexes after removal" do
      favorites = Favorites.new()
      {:ok, favorites} = Favorites.add_entry(favorites, %{channel_name: "#a"})
      {:ok, favorites} = Favorites.add_entry(favorites, %{channel_name: "#b"})
      {:ok, favorites} = Favorites.add_entry(favorites, %{channel_name: "#c"})

      {:ok, updated} = Favorites.remove_entry(favorites, "#b")
      entries = Favorites.entries(updated)
      assert Enum.at(entries, 0).position == 0
      assert Enum.at(entries, 1).position == 1
    end
  end

  describe "find_entry/2" do
    test "finds entry by channel name" do
      favorites = Favorites.new()

      {:ok, favorites} =
        Favorites.add_entry(favorites, %{channel_name: "#elixir", description: "Elixir"})

      entry = Favorites.find_entry(favorites, "#elixir")
      assert entry.channel_name == "#elixir"
      assert entry.description == "Elixir"
    end

    test "is case-insensitive" do
      favorites = Favorites.new()
      {:ok, favorites} = Favorites.add_entry(favorites, %{channel_name: "#Elixir"})
      assert Favorites.find_entry(favorites, "#elixir") != nil
    end

    test "returns nil when not found" do
      favorites = Favorites.new()
      assert Favorites.find_entry(favorites, "#missing") == nil
    end
  end

  describe "has_entry?/2" do
    test "returns true when present" do
      favorites = Favorites.new()
      {:ok, favorites} = Favorites.add_entry(favorites, %{channel_name: "#elixir"})
      assert Favorites.has_entry?(favorites, "#elixir")
    end

    test "returns false when absent" do
      favorites = Favorites.new()
      refute Favorites.has_entry?(favorites, "#missing")
    end
  end

  describe "move_up/2" do
    test "moves entry up one position" do
      favorites = Favorites.new()
      {:ok, favorites} = Favorites.add_entry(favorites, %{channel_name: "#a"})
      {:ok, favorites} = Favorites.add_entry(favorites, %{channel_name: "#b"})
      {:ok, favorites} = Favorites.add_entry(favorites, %{channel_name: "#c"})

      updated = Favorites.move_up(favorites, "#b")
      entries = Favorites.entries(updated)
      assert Enum.at(entries, 0).channel_name == "#b"
      assert Enum.at(entries, 1).channel_name == "#a"
      assert Enum.at(entries, 2).channel_name == "#c"
    end

    test "no-op when already first" do
      favorites = Favorites.new()
      {:ok, favorites} = Favorites.add_entry(favorites, %{channel_name: "#a"})
      {:ok, favorites} = Favorites.add_entry(favorites, %{channel_name: "#b"})

      updated = Favorites.move_up(favorites, "#a")
      entries = Favorites.entries(updated)
      assert Enum.at(entries, 0).channel_name == "#a"
      assert Enum.at(entries, 1).channel_name == "#b"
    end

    test "no-op for non-existent channel" do
      favorites = Favorites.new()
      {:ok, favorites} = Favorites.add_entry(favorites, %{channel_name: "#a"})
      updated = Favorites.move_up(favorites, "#missing")
      assert updated == favorites
    end
  end

  describe "move_down/2" do
    test "moves entry down one position" do
      favorites = Favorites.new()
      {:ok, favorites} = Favorites.add_entry(favorites, %{channel_name: "#a"})
      {:ok, favorites} = Favorites.add_entry(favorites, %{channel_name: "#b"})
      {:ok, favorites} = Favorites.add_entry(favorites, %{channel_name: "#c"})

      updated = Favorites.move_down(favorites, "#b")
      entries = Favorites.entries(updated)
      assert Enum.at(entries, 0).channel_name == "#a"
      assert Enum.at(entries, 1).channel_name == "#c"
      assert Enum.at(entries, 2).channel_name == "#b"
    end

    test "no-op when already last" do
      favorites = Favorites.new()
      {:ok, favorites} = Favorites.add_entry(favorites, %{channel_name: "#a"})
      {:ok, favorites} = Favorites.add_entry(favorites, %{channel_name: "#b"})

      updated = Favorites.move_down(favorites, "#b")
      entries = Favorites.entries(updated)
      assert Enum.at(entries, 0).channel_name == "#a"
      assert Enum.at(entries, 1).channel_name == "#b"
    end
  end

  describe "auto_join_entries/1" do
    test "returns only auto-join entries" do
      favorites = Favorites.new()
      {:ok, favorites} = Favorites.add_entry(favorites, %{channel_name: "#a", auto_join: true})
      {:ok, favorites} = Favorites.add_entry(favorites, %{channel_name: "#b", auto_join: false})
      {:ok, favorites} = Favorites.add_entry(favorites, %{channel_name: "#c", auto_join: true})

      auto = Favorites.auto_join_entries(favorites)
      assert length(auto) == 2
      assert Enum.at(auto, 0).channel_name == "#a"
      assert Enum.at(auto, 1).channel_name == "#c"
    end

    test "returns empty list when none are auto-join" do
      favorites = Favorites.new()
      {:ok, favorites} = Favorites.add_entry(favorites, %{channel_name: "#a"})
      assert Favorites.auto_join_entries(favorites) == []
    end
  end

  describe "entries/1" do
    test "returns entries sorted by position" do
      favorites = Favorites.new()
      {:ok, favorites} = Favorites.add_entry(favorites, %{channel_name: "#a"})
      {:ok, favorites} = Favorites.add_entry(favorites, %{channel_name: "#b"})

      entries = Favorites.entries(favorites)
      assert Enum.at(entries, 0).position == 0
      assert Enum.at(entries, 1).position == 1
    end

    test "returns empty list for new favorites" do
      assert Favorites.entries(Favorites.new()) == []
    end
  end

  describe "save/2 and load/1" do
    @tag :integration
    test "persists and loads favorites with encrypted password" do
      owner = "FavUser#{System.unique_integer([:positive])}"
      register_nick(owner)

      favorites = Favorites.new()

      {:ok, favorites} =
        Favorites.add_entry(favorites, %{channel_name: "#elixir", description: "Elixir lang"})

      {:ok, favorites} =
        Favorites.add_entry(favorites, %{
          channel_name: "#secret",
          description: "Secret",
          password: "pass123",
          auto_join: true
        })

      assert :ok = Favorites.save(owner, favorites)

      assert {:ok, loaded} = Favorites.load(owner)
      entries = Favorites.entries(loaded)
      assert length(entries) == 2

      assert Enum.at(entries, 0).channel_name == "#elixir"
      assert Enum.at(entries, 0).description == "Elixir lang"
      assert Enum.at(entries, 0).password == nil
      assert Enum.at(entries, 0).auto_join == false

      assert Enum.at(entries, 1).channel_name == "#secret"
      assert Enum.at(entries, 1).description == "Secret"
      assert Enum.at(entries, 1).password == "pass123"
      assert Enum.at(entries, 1).auto_join == true
    end

    @tag :integration
    test "save replaces previous entries" do
      owner = "FavUser#{System.unique_integer([:positive])}"
      register_nick(owner)

      {:ok, fav1} = Favorites.add_entry(Favorites.new(), %{channel_name: "#old"})
      assert :ok = Favorites.save(owner, fav1)

      {:ok, fav2} = Favorites.add_entry(Favorites.new(), %{channel_name: "#new"})
      assert :ok = Favorites.save(owner, fav2)

      assert {:ok, loaded} = Favorites.load(owner)
      entries = Favorites.entries(loaded)
      assert length(entries) == 1
      assert hd(entries).channel_name == "#new"
    end

    @tag :integration
    test "load returns error for unknown user" do
      assert {:error, :not_found} = Favorites.load("NonExistent")
    end

    @tag :integration
    test "preserves entry order across save/load" do
      owner = "FavUser#{System.unique_integer([:positive])}"
      register_nick(owner)

      favorites = Favorites.new()
      {:ok, favorites} = Favorites.add_entry(favorites, %{channel_name: "#c"})
      {:ok, favorites} = Favorites.add_entry(favorites, %{channel_name: "#a"})
      {:ok, favorites} = Favorites.add_entry(favorites, %{channel_name: "#b"})

      # Reorder: move #a up so order is #a, #c, #b
      favorites = Favorites.move_up(favorites, "#a")

      assert :ok = Favorites.save(owner, favorites)
      assert {:ok, loaded} = Favorites.load(owner)
      entries = Favorites.entries(loaded)
      assert Enum.at(entries, 0).channel_name == "#a"
      assert Enum.at(entries, 1).channel_name == "#c"
      assert Enum.at(entries, 2).channel_name == "#b"
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
