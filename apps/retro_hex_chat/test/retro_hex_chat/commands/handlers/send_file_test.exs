defmodule RetroHexChat.Commands.Handlers.SendFileTest do
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Commands.Handlers.SendFile
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
      assert {:error, _} = SendFile.validate("")
    end

    test "accepts valid nick" do
      assert :ok = SendFile.validate("mario")
    end
  end

  describe "execute/2" do
    test "returns p2p_invite with file_transfer session_type" do
      {:ok, _creator} =
        %RegisteredNick{}
        |> RegisteredNick.registration_changeset(%{
          nickname: "sf_cr",
          password: "password123"
        })
        |> Repo.insert()

      {:ok, _peer} =
        %RegisteredNick{}
        |> RegisteredNick.registration_changeset(%{
          nickname: "sf_pe",
          password: "password123"
        })
        |> Repo.insert()

      context = %{@base_context | nickname: "sf_cr"}
      result = SendFile.execute(["sf_pe"], context)

      assert {:ok, :ui_action, :p2p_invite, payload} = result
      assert payload.target == "sf_pe"
      assert payload.session_type == "file_transfer"
      assert payload.token != nil
    end

    test "rejects empty args" do
      assert {:error, _} = SendFile.execute([], @base_context)
    end
  end

  describe "help/0" do
    test "returns help map" do
      help = SendFile.help()
      assert help.name == "sendfile"
      assert help.syntax =~ "/sendfile"
    end
  end

  describe "category/0" do
    test "returns :user" do
      assert SendFile.category() == :user
    end
  end
end
