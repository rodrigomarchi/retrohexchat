defmodule RetroHexChat.SignedTokenTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.SignedToken

  @secret "signed-token-test-secret-at-least-sixty-four-bytes-long-padding-x"
  @other_secret "another-signed-token-secret-at-least-sixty-four-bytes-long-pad-x"
  @salt "a_door"

  describe "sign/3 and verify/4" do
    test "a token says back what it was signed with" do
      token = SignedToken.sign(@secret, @salt, %{who: "alice"})

      assert {:ok, %{who: "alice"}} = SignedToken.verify(@secret, @salt, token)
    end

    test "a tampered token is invalid" do
      token = SignedToken.sign(@secret, @salt, %{who: "alice"})

      assert SignedToken.verify(@secret, @salt, token <> "x") == {:error, :invalid}
    end

    test "a token signed with another secret is invalid" do
      token = SignedToken.sign(@other_secret, @salt, %{who: "alice"})

      assert SignedToken.verify(@secret, @salt, token) == {:error, :invalid}
    end

    test "a token minted for another door is invalid, which is what a salt is for" do
      token = SignedToken.sign(@secret, "another_door", %{who: "alice"})

      assert SignedToken.verify(@secret, @salt, token) == {:error, :invalid}
    end

    test "something that was never a token is invalid rather than a crash" do
      assert SignedToken.verify(@secret, @salt, "not a token at all") == {:error, :invalid}
    end

    test "a rejection says nothing about why, so a forgery learns nothing" do
      forged = SignedToken.sign(@other_secret, @salt, %{who: "alice"})
      wrong_door = SignedToken.sign(@secret, "another_door", %{who: "alice"})

      assert SignedToken.verify(@secret, @salt, forged) ==
               SignedToken.verify(@secret, @salt, wrong_door)
    end
  end

  describe "expiry" do
    test "a token that ran out is expired, told apart from a bad one" do
      token = SignedToken.sign(@secret, @salt, %{who: "alice"})

      assert SignedToken.verify(@secret, @salt, token, max_age: -1) == {:error, :expired}
    end

    test "a caller can ask for a shorter life than the default" do
      token = SignedToken.sign(@secret, @salt, %{who: "alice"})

      assert {:ok, _data} =
               SignedToken.verify(@secret, @salt, token, max_age: SignedToken.default_max_age())
    end

    test "a token is good for an hour unless somebody says otherwise" do
      assert SignedToken.default_max_age() == 3_600
    end

    test "an expired forgery is still just invalid" do
      forged = SignedToken.sign(@other_secret, @salt, %{who: "alice"})

      assert SignedToken.verify(@secret, @salt, forged, max_age: -1) == {:error, :invalid}
    end
  end
end
