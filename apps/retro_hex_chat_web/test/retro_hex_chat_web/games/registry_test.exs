defmodule RetroHexChatWeb.Games.RegistryTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Games.Catalog

  @moduletag :unit

  # The browser finds a game's engine through this file; a game the catalog
  # offers but the registry lacks opens onto an empty canvas.
  @registry Path.expand("../../../assets/js/lib/games/registry.json", __DIR__)
  @external_resource @registry

  setup_all do
    {:ok, registry: @registry |> File.read!() |> Jason.decode!()}
  end

  test "names the same games the catalog offers", %{registry: registry} do
    assert registry |> Map.keys() |> Enum.sort() == Enum.sort(Catalog.game_ids())
  end

  test "offers solo play for exactly the games the catalog plays solo", %{registry: registry} do
    for {id, %{"solo" => solo}} <- registry do
      assert solo == Catalog.solo_game_id?(id), "#{id}: registry solo #{solo}"
    end
  end

  test "marks one-player games exactly as the catalog does", %{registry: registry} do
    for {id, entry} <- registry do
      solo_only = Map.get(entry, "soloOnly", false)
      assert solo_only == Catalog.solo_only?(id), "#{id}: registry soloOnly #{solo_only}"
    end
  end
end
