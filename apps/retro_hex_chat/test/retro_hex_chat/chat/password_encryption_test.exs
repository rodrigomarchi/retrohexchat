defmodule RetroHexChat.Chat.PasswordEncryptionTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Chat.PasswordEncryption

  describe "encrypt/1 and decrypt/1" do
    test "round-trips a password" do
      plain = "my_secret_key"
      encrypted = PasswordEncryption.encrypt(plain)

      assert encrypted != plain
      assert {:ok, ^plain} = PasswordEncryption.decrypt(encrypted)
    end

    test "produces different ciphertext each time (nonce-based)" do
      plain = "same_password"
      enc1 = PasswordEncryption.encrypt(plain)
      enc2 = PasswordEncryption.encrypt(plain)

      # AES-GCM with random nonce should produce different ciphertext
      assert enc1 != enc2

      # Both should decrypt to the same value
      assert {:ok, ^plain} = PasswordEncryption.decrypt(enc1)
      assert {:ok, ^plain} = PasswordEncryption.decrypt(enc2)
    end

    test "returns :error for tampered ciphertext" do
      encrypted = PasswordEncryption.encrypt("valid_password")
      tampered = encrypted <> "tampered"

      assert :error = PasswordEncryption.decrypt(tampered)
    end

    test "decrypt/1 returns {:ok, nil} for nil" do
      assert {:ok, nil} = PasswordEncryption.decrypt(nil)
    end

    test "decrypt/1 returns {:ok, nil} for empty string" do
      assert {:ok, nil} = PasswordEncryption.decrypt("")
    end

    test "handles various password characters" do
      passwords = [
        "simple",
        "with spaces",
        "sp3c!@l#ch4rs",
        "unicode-José-日本語",
        String.duplicate("a", 200)
      ]

      for password <- passwords do
        encrypted = PasswordEncryption.encrypt(password)
        assert {:ok, ^password} = PasswordEncryption.decrypt(encrypted)
      end
    end
  end
end
