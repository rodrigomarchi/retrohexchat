defmodule RetroHexChat.Commands.Handlers.Admin.ServerTest do
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Commands.Handlers.Admin.Server
  alias RetroHexChat.Services.Queries

  @moduletag :integration

  defp context do
    %{
      nickname: "AdminNick",
      active_channel: nil,
      channels: [],
      identified: true,
      owner_in: [],
      operator_in: [],
      half_operator_in: [],
      is_admin: true,
      is_server_operator: false
    }
  end

  describe "space_max_participants setting" do
    test "accepts a positive integer within the ceiling" do
      assert {:ok, :system, _} =
               Server.execute(["set", "space_max_participants", "16"], context())

      assert Queries.get_setting("space_max_participants") == "16"
    end

    test "rejects a non-integer, zero and values above the ceiling" do
      assert {:error, _} = Server.execute(["set", "space_max_participants", "lots"], context())
      assert {:error, _} = Server.execute(["set", "space_max_participants", "0"], context())
      assert {:error, _} = Server.execute(["set", "space_max_participants", "999"], context())
    end
  end
end
