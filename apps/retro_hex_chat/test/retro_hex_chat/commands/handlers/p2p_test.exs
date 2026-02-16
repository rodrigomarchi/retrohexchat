defmodule RetroHexChat.Commands.Handlers.P2pTest do
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Commands.Handlers.P2p
  alias RetroHexChat.Services.RegisteredNick

  @moduletag :integration

  @base_context %{
    nickname: "rodrigo",
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
      assert {:error, _} = P2p.validate("")
    end

    test "accepts valid nick" do
      assert :ok = P2p.validate("mario")
    end
  end

  describe "execute/2" do
    test "returns p2p_invite ui_action with target and token" do
      # Create registered nicks for the test
      {:ok, creator} =
        %RegisteredNick{}
        |> RegisteredNick.registration_changeset(%{
          nickname: "rodrigo",
          password: "password123"
        })
        |> Repo.insert()

      {:ok, _peer} =
        %RegisteredNick{}
        |> RegisteredNick.registration_changeset(%{
          nickname: "mario",
          password: "password123"
        })
        |> Repo.insert()

      context = %{@base_context | nickname: "rodrigo", identified: true}
      result = P2p.execute(["mario"], context)

      assert {:ok, :ui_action, :p2p_invite, payload} = result
      assert payload.target == "mario"
      assert payload.session_type == "generic"
      assert payload.token != nil
      assert payload.creator_id == creator.id
    end

    test "rejects empty args" do
      assert {:error, _} = P2p.execute([], @base_context)
    end

    test "rejects when not identified" do
      context = %{@base_context | identified: false}
      assert {:error, msg} = P2p.execute(["mario"], context)
      assert msg =~ "identificado"
    end

    test "rejects targeting self" do
      context = %{@base_context | nickname: "rodrigo"}
      assert {:error, msg} = P2p.execute(["rodrigo"], context)
      assert msg =~ "voce mesmo"
    end

    test "rejects unregistered target" do
      # Creator registered but target not
      {:ok, _creator} =
        %RegisteredNick{}
        |> RegisteredNick.registration_changeset(%{
          nickname: "p2p_cr1",
          password: "password123"
        })
        |> Repo.insert()

      context = %{@base_context | nickname: "p2p_cr1"}
      assert {:error, msg} = P2p.execute(["nobody"], context)
      assert msg =~ "registrado"
    end
  end

  describe "help/0" do
    test "returns help map with required keys" do
      help = P2p.help()
      assert help.name == "p2p"
      assert help.syntax =~ "/p2p"
      assert is_binary(help.description)
      assert is_list(help.examples)
    end
  end

  describe "category/0" do
    test "returns :user" do
      assert P2p.category() == :user
    end
  end
end
