defmodule RetroHexChat.Arcade.ContentTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Arcade.{Catalog, Content}

  @tag :unit
  test "get_content/1 returns content for each catalog game" do
    for game_id <- Catalog.game_ids() do
      assert {:ok, content} = Content.get_content(game_id),
             "missing content for game: #{game_id}"

      assert is_list(content.about), "about should be a list for #{game_id}"
      assert is_list(content.controls), "controls should be a list for #{game_id}"
      assert is_list(content.tips), "tips should be a list for #{game_id}"
    end
  end

  @tag :unit
  test "get_content/1 returns error for unknown game" do
    assert {:error, :not_found} = Content.get_content("nonexistent_game")
  end

  @tag :unit
  test "has_content?/1 returns true for all catalog games" do
    for game_id <- Catalog.game_ids() do
      assert Content.has_content?(game_id), "has_content? should be true for #{game_id}"
    end
  end

  @tag :unit
  test "has_content?/1 returns false for unknown game" do
    refute Content.has_content?("nonexistent_game")
  end

  @tag :unit
  test "content sections have meaningful data" do
    {:ok, content} = Content.get_content("doom_shareware")

    assert length(content.about) >= 2
    assert length(content.controls) >= 5
    assert length(content.tips) >= 3

    assert Enum.all?(content.about, &is_binary/1)

    assert Enum.all?(content.controls, fn {key, action} ->
             is_binary(key) and is_binary(action)
           end)

    assert Enum.all?(content.tips, &is_binary/1)
  end
end
