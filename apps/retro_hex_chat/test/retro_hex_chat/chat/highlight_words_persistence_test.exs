defmodule RetroHexChat.Chat.HighlightWordsPersistenceTest do
  use RetroHexChat.DataCase, async: true

  alias RetroHexChat.Chat.HighlightWords

  @moduletag :integration

  setup do
    {:ok, _} =
      RetroHexChat.Repo.insert(%RetroHexChat.Services.RegisteredNick{
        nickname: "HLOwner",
        password_hash: Bcrypt.hash_pwd_salt("password123"),
        registered_at: DateTime.utc_now()
      })

    :ok
  end

  describe "save/2 and load/1" do
    test "save and load round-trip" do
      hw = HighlightWords.new()
      {:ok, hw} = HighlightWords.add_entry(hw, "phoenix", nil)
      {:ok, hw} = HighlightWords.add_entry(hw, "deploy", 4)

      assert :ok = HighlightWords.save("HLOwner", hw)

      assert {:ok, loaded} = HighlightWords.load("HLOwner")
      assert length(loaded.entries) == 2

      phoenix = Enum.find(loaded.entries, &(&1.word == "phoenix"))
      deploy = Enum.find(loaded.entries, &(&1.word == "deploy"))

      assert phoenix != nil
      assert phoenix.bg_color == nil
      assert deploy != nil
      assert deploy.bg_color == 4
    end

    test "load returns error for unknown user" do
      assert {:error, :not_found} = HighlightWords.load("UnknownUser")
    end

    test "save replaces all entries (full replace)" do
      hw = HighlightWords.new()
      {:ok, hw} = HighlightWords.add_entry(hw, "phoenix", nil)
      {:ok, hw} = HighlightWords.add_entry(hw, "elixir", nil)
      assert :ok = HighlightWords.save("HLOwner", hw)

      # Now save with different entries
      hw2 = HighlightWords.new()
      {:ok, hw2} = HighlightWords.add_entry(hw2, "deploy", 4)
      assert :ok = HighlightWords.save("HLOwner", hw2)

      {:ok, loaded} = HighlightWords.load("HLOwner")
      assert length(loaded.entries) == 1
      assert hd(loaded.entries).word == "deploy"
    end

    test "preserves position order on load" do
      hw = HighlightWords.new()
      {:ok, hw} = HighlightWords.add_entry(hw, "charlie", nil)
      {:ok, hw} = HighlightWords.add_entry(hw, "alpha", nil)
      {:ok, hw} = HighlightWords.add_entry(hw, "bravo", nil)

      assert :ok = HighlightWords.save("HLOwner", hw)

      {:ok, loaded} = HighlightWords.load("HLOwner")
      words = Enum.map(loaded.entries, & &1.word)
      assert words == ["charlie", "alpha", "bravo"]
    end

    test "cascade delete removes highlight words when user deleted" do
      hw = HighlightWords.new()
      {:ok, hw} = HighlightWords.add_entry(hw, "test", nil)
      assert :ok = HighlightWords.save("HLOwner", hw)

      # Delete the registered nick — should cascade
      RetroHexChat.Repo.delete_all(
        Ecto.Query.from(r in RetroHexChat.Services.RegisteredNick,
          where: r.nickname == "HLOwner"
        )
      )

      assert {:error, :not_found} = HighlightWords.load("HLOwner")
    end
  end
end
