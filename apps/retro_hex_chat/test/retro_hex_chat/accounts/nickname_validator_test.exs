defmodule RetroHexChat.Accounts.NicknameValidatorTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Accounts.NicknameValidator

  describe "valid?/1" do
    test "accepts a simple alphabetic nickname" do
      assert NicknameValidator.valid?("Alice")
    end

    test "accepts a nickname with underscores and digits" do
      assert NicknameValidator.valid?("Guest_12345")
    end

    test "accepts a nickname wrapped in brackets" do
      assert NicknameValidator.valid?("[Admin]")
    end

    test "accepts a nickname starting with underscore" do
      assert NicknameValidator.valid?("_nick_")
    end

    test "accepts a single letter nickname" do
      assert NicknameValidator.valid?("A")
    end

    test "accepts a nickname at the max length of 16 chars" do
      assert NicknameValidator.valid?(String.duplicate("a", 16))
    end

    test "accepts nicknames starting with each IRC special char" do
      for char <- ~w([ ] \\ ^ _ { | }) do
        nick = char <> "nick"
        assert NicknameValidator.valid?(nick), "Expected #{inspect(nick)} to be valid"
      end
    end

    test "accepts backtick after the first character" do
      assert NicknameValidator.valid?("nick`")
    end

    test "rejects an empty string" do
      refute NicknameValidator.valid?("")
    end

    test "rejects a nickname exceeding 16 characters" do
      refute NicknameValidator.valid?(String.duplicate("a", 17))
    end

    test "rejects a nickname starting with a space" do
      refute NicknameValidator.valid?(" spacey")
    end

    test "rejects a nickname starting with a digit" do
      refute NicknameValidator.valid?("123bad")
    end

    test "rejects a nickname containing a space" do
      refute NicknameValidator.valid?("nick name")
    end

    test "rejects a nickname starting with #" do
      refute NicknameValidator.valid?("#bad")
    end

    test "rejects a nickname starting with -" do
      refute NicknameValidator.valid?("-bad")
    end

    test "rejects a nickname starting with backtick" do
      refute NicknameValidator.valid?("`bad")
    end

    test "rejects a nickname containing invalid characters" do
      refute NicknameValidator.valid?("bad!")
    end

    test "rejects non-binary input" do
      refute NicknameValidator.valid?(nil)
      refute NicknameValidator.valid?(123)
      refute NicknameValidator.valid?(:atom)
    end
  end

  describe "validate/1" do
    test "returns :ok for a valid nickname" do
      assert :ok = NicknameValidator.validate("Alice")
    end

    test "returns error for empty nickname" do
      assert {:error, "Nickname cannot be empty"} = NicknameValidator.validate("")
    end

    test "returns error for nickname exceeding max length" do
      assert {:error, "Nickname must be at most 16 characters"} =
               NicknameValidator.validate(String.duplicate("a", 17))
    end

    test "returns error for nickname starting with a digit" do
      assert {:error, "Nickname must start with a letter or special character"} =
               NicknameValidator.validate("9bad")
    end

    test "returns error for nickname containing spaces" do
      assert {:error, "Nickname cannot contain spaces"} =
               NicknameValidator.validate("nick name")
    end

    test "returns error for nickname containing invalid characters" do
      assert {:error, "Nickname contains invalid characters"} =
               NicknameValidator.validate("nick!")
    end

    test "returns error for non-string input" do
      assert {:error, "Nickname must be a string"} = NicknameValidator.validate(nil)
    end
  end
end
