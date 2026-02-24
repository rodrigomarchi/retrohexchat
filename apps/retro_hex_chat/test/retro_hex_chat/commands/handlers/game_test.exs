defmodule RetroHexChat.Commands.Handlers.GameTest do
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Commands.Handlers.Game
  alias RetroHexChat.Services.RegisteredNick

  @moduletag :integration

  @base_context %{
    nickname: "gcmd_rod",
    active_channel: "#lobby",
    channels: ["#lobby"],
    identified: true,
    operator_in: [],
    half_operator_in: [],
    is_admin: false,
    is_server_operator: false
  }

  describe "validate/1" do
    test "rejects empty args" do
      assert {:error, _} = Game.validate("")
    end

    test "accepts valid nick" do
      assert :ok = Game.validate("mario")
    end
  end

  describe "execute/2" do
    test "returns game_invite ui_action with target and token" do
      {:ok, creator} =
        %RegisteredNick{}
        |> RegisteredNick.registration_changeset(%{
          nickname: "gcmd_rod",
          password: "password123"
        })
        |> Repo.insert()

      {:ok, _peer} =
        %RegisteredNick{}
        |> RegisteredNick.registration_changeset(%{
          nickname: "gcmd_mario",
          password: "password123"
        })
        |> Repo.insert()

      context = %{@base_context | nickname: "gcmd_rod", identified: true}
      result = Game.execute(["gcmd_mario"], context)

      assert {:ok, :ui_action, :game_invite, payload} = result
      assert payload.target == "gcmd_mario"
      assert payload.token != nil
      assert payload.creator_id == creator.id
    end

    test "rejects empty args" do
      assert {:error, _} = Game.execute([], @base_context)
    end

    test "rejects when not identified" do
      context = %{@base_context | identified: false}
      assert {:error, msg} = Game.execute(["mario"], context)
      assert msg =~ "identified"
    end

    test "rejects targeting self" do
      context = %{@base_context | nickname: "gcmd_rod"}
      assert {:error, msg} = Game.execute(["gcmd_rod"], context)
      assert msg =~ "yourself"
    end

    test "rejects unregistered target" do
      {:ok, _creator} =
        %RegisteredNick{}
        |> RegisteredNick.registration_changeset(%{
          nickname: "gcmd_rod2",
          password: "password123"
        })
        |> Repo.insert()

      context = %{@base_context | nickname: "gcmd_rod2"}
      assert {:error, msg} = Game.execute(["gcmd_unreg"], context)
      assert msg =~ "not registered"
    end
  end

  describe "help/0" do
    test "returns help info" do
      help = Game.help()
      assert help.name == "game"
      assert help.syntax =~ "/game"
    end
  end

  describe "category/0" do
    test "returns :user" do
      assert :user = Game.category()
    end
  end

  describe "syntax_definition/0" do
    test "returns valid definition" do
      syntax = Game.syntax_definition()
      assert syntax.command == "game"
      assert length(syntax.parameters) == 1
    end
  end
end
