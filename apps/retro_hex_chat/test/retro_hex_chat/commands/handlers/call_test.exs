defmodule RetroHexChat.Commands.Handlers.CallTest do
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Commands.Handlers.Call
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
      assert {:error, _} = Call.validate("")
    end

    test "accepts valid nick" do
      assert :ok = Call.validate("mario")
    end
  end

  describe "execute/2" do
    test "returns p2p_invite with audio_call session_type" do
      {:ok, _creator} =
        %RegisteredNick{}
        |> RegisteredNick.registration_changeset(%{
          nickname: "call_cr",
          password: "password123"
        })
        |> Repo.insert()

      {:ok, _peer} =
        %RegisteredNick{}
        |> RegisteredNick.registration_changeset(%{
          nickname: "call_pe",
          password: "password123"
        })
        |> Repo.insert()

      context = %{@base_context | nickname: "call_cr"}
      result = Call.execute(["call_pe"], context)

      assert {:ok, :ui_action, :p2p_invite, payload} = result
      assert payload.target == "call_pe"
      assert payload.session_type == "audio_call"
      assert payload.token != nil
    end

    test "rejects empty args" do
      assert {:error, _} = Call.execute([], @base_context)
    end
  end

  describe "help/0" do
    test "returns help map" do
      help = Call.help()
      assert help.name == "call"
      assert help.syntax =~ "/call"
    end
  end

  describe "category/0" do
    test "returns :user" do
      assert Call.category() == :user
    end
  end
end
