defmodule RetroHexChat.Chat.IgnoreEntryTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Chat.IgnoreEntry

  describe "new/1" do
    test "creates entry from keyword list" do
      entry =
        IgnoreEntry.new(
          nickname: "SpamBot",
          ignore_type: :all,
          created_at: DateTime.utc_now()
        )

      assert entry.nickname == "SpamBot"
      assert entry.ignore_type == :all
      assert entry.expires_at == nil
    end

    test "creates entry from map" do
      entry =
        IgnoreEntry.new(%{
          nickname: "Troll",
          ignore_type: :pms,
          created_at: DateTime.utc_now()
        })

      assert entry.nickname == "Troll"
      assert entry.ignore_type == :pms
    end

    test "creates entry with expires_at" do
      expires = DateTime.add(DateTime.utc_now(), 300, :second)

      entry =
        IgnoreEntry.new(
          nickname: "Loud",
          ignore_type: :all,
          expires_at: expires,
          created_at: DateTime.utc_now()
        )

      assert entry.expires_at == expires
    end

    test "raises on missing required keys" do
      assert_raise ArgumentError, fn ->
        IgnoreEntry.new(nickname: "Test")
      end
    end
  end

  describe "expired?/1" do
    test "returns false for permanent entry (nil expires_at)" do
      entry =
        IgnoreEntry.new(
          nickname: "Test",
          ignore_type: :all,
          created_at: DateTime.utc_now()
        )

      refute IgnoreEntry.expired?(entry)
    end

    test "returns false for future expires_at" do
      entry =
        IgnoreEntry.new(
          nickname: "Test",
          ignore_type: :all,
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
          created_at: DateTime.utc_now()
        )

      refute IgnoreEntry.expired?(entry)
    end

    test "returns true for past expires_at" do
      entry =
        IgnoreEntry.new(
          nickname: "Test",
          ignore_type: :all,
          expires_at: DateTime.add(DateTime.utc_now(), -60, :second),
          created_at: DateTime.utc_now()
        )

      assert IgnoreEntry.expired?(entry)
    end
  end

  describe "permanent?/1" do
    test "returns true when expires_at is nil" do
      entry =
        IgnoreEntry.new(
          nickname: "Test",
          ignore_type: :all,
          created_at: DateTime.utc_now()
        )

      assert IgnoreEntry.permanent?(entry)
    end

    test "returns false when expires_at is set" do
      entry =
        IgnoreEntry.new(
          nickname: "Test",
          ignore_type: :all,
          expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
          created_at: DateTime.utc_now()
        )

      refute IgnoreEntry.permanent?(entry)
    end
  end

  describe "remaining_seconds/1" do
    test "returns 0 for permanent entry" do
      entry =
        IgnoreEntry.new(
          nickname: "Test",
          ignore_type: :all,
          created_at: DateTime.utc_now()
        )

      assert IgnoreEntry.remaining_seconds(entry) == 0
    end

    test "returns positive seconds for future expiry" do
      entry =
        IgnoreEntry.new(
          nickname: "Test",
          ignore_type: :all,
          expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
          created_at: DateTime.utc_now()
        )

      remaining = IgnoreEntry.remaining_seconds(entry)
      assert remaining > 0
      assert remaining <= 300
    end

    test "returns 0 for expired entry" do
      entry =
        IgnoreEntry.new(
          nickname: "Test",
          ignore_type: :all,
          expires_at: DateTime.add(DateTime.utc_now(), -60, :second),
          created_at: DateTime.utc_now()
        )

      assert IgnoreEntry.remaining_seconds(entry) == 0
    end
  end

  describe "valid_type?/1" do
    test "returns true for valid types" do
      assert IgnoreEntry.valid_type?(:all)
      assert IgnoreEntry.valid_type?(:messages)
      assert IgnoreEntry.valid_type?(:pms)
      assert IgnoreEntry.valid_type?(:invites)
      assert IgnoreEntry.valid_type?(:actions)
    end

    test "returns false for invalid types" do
      refute IgnoreEntry.valid_type?(:invalid)
      refute IgnoreEntry.valid_type?(:everything)
      refute IgnoreEntry.valid_type?(:channel)
    end
  end
end
