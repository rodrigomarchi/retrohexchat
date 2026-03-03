defmodule RetroHexChat.Services.RegisteredNickTest do
  use RetroHexChat.DataCase, async: true

  alias RetroHexChat.Services.RegisteredNick

  @moduletag :unit

  describe "registration_changeset/2" do
    test "valid attrs with password hashing" do
      attrs = %{nickname: "Alice", password: "secret123"}
      changeset = RegisteredNick.registration_changeset(%RegisteredNick{}, attrs)
      assert changeset.valid?
      assert changeset.changes.password_hash
      assert changeset.changes.password_hash != attrs.password
    end

    test "requires nickname and password" do
      changeset = RegisteredNick.registration_changeset(%RegisteredNick{}, %{})
      refute changeset.valid?
      assert %{nickname: ["can't be blank"], password: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates nickname max length 16" do
      attrs = %{nickname: String.duplicate("a", 17), password: "secret123"}
      changeset = RegisteredNick.registration_changeset(%RegisteredNick{}, attrs)
      refute changeset.valid?
    end

    test "validates password min length 5" do
      attrs = %{nickname: "Alice", password: "ab"}
      changeset = RegisteredNick.registration_changeset(%RegisteredNick{}, attrs)
      refute changeset.valid?
    end

    test "sets registered_at timestamp" do
      attrs = %{nickname: "Alice", password: "secret123"}
      changeset = RegisteredNick.registration_changeset(%RegisteredNick{}, attrs)
      assert changeset.changes.registered_at
    end

    test "sets last_seen_at timestamp" do
      attrs = %{nickname: "Alice", password: "secret123"}
      changeset = RegisteredNick.registration_changeset(%RegisteredNick{}, attrs)
      assert changeset.changes.last_seen_at
    end
  end

  describe "verify_password/2" do
    test "returns true for correct password" do
      hash = Bcrypt.hash_pwd_salt("secret123")
      nick = %RegisteredNick{password_hash: hash}
      assert RegisteredNick.verify_password(nick, "secret123")
    end

    test "returns false for wrong password" do
      hash = Bcrypt.hash_pwd_salt("secret123")
      nick = %RegisteredNick{password_hash: hash}
      refute RegisteredNick.verify_password(nick, "wrong")
    end
  end
end
