defmodule RetroHexChat.P2P.SessionTokenTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.P2P.SessionToken

  @moduletag :unit

  describe "sign/3" do
    test "returns a non-empty string" do
      token = SessionToken.sign(1, 2, 100)
      assert is_binary(token)
      assert byte_size(token) > 0
    end
  end

  describe "verify/1" do
    test "returns {:ok, data} with correct fields for valid token" do
      token = SessionToken.sign(1, 2, 100)
      assert {:ok, data} = SessionToken.verify(token)
      assert data.creator_id == 1
      assert data.peer_id == 2
      assert data.session_id == 100
    end

    test "round-trip sign and verify" do
      creator_id = 42
      peer_id = 99
      session_id = 555

      token = SessionToken.sign(creator_id, peer_id, session_id)
      assert {:ok, data} = SessionToken.verify(token)
      assert data == %{creator_id: creator_id, peer_id: peer_id, session_id: session_id}
    end

    test "returns {:error, :invalid} for tampered token" do
      token = SessionToken.sign(1, 2, 100)
      tampered = token <> "tampered"
      assert {:error, :invalid} = SessionToken.verify(tampered)
    end

    test "returns {:error, :invalid} for garbage token" do
      assert {:error, :invalid} = SessionToken.verify("not-a-valid-token")
    end
  end
end
