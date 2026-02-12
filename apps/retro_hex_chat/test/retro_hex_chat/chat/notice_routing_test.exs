defmodule RetroHexChat.Chat.NoticeRoutingTest do
  use RetroHexChat.DataCase, async: true

  alias RetroHexChat.Chat.NoticeRouting

  describe "new/0" do
    @tag :unit
    test "returns default routing map with :active" do
      settings = NoticeRouting.new()
      assert settings == %{routing: :active}
    end
  end

  describe "get_routing/1" do
    @tag :unit
    test "returns the current routing atom" do
      settings = %{routing: :status}
      assert NoticeRouting.get_routing(settings) == :status
    end

    @tag :unit
    test "returns :active for default settings" do
      settings = NoticeRouting.new()
      assert NoticeRouting.get_routing(settings) == :active
    end
  end

  describe "set_routing/2" do
    @tag :unit
    test "updates routing to :active" do
      settings = %{routing: :status}
      result = NoticeRouting.set_routing(settings, :active)
      assert result == %{routing: :active}
    end

    @tag :unit
    test "updates routing to :status" do
      settings = NoticeRouting.new()
      result = NoticeRouting.set_routing(settings, :status)
      assert result == %{routing: :status}
    end

    @tag :unit
    test "updates routing to :sender" do
      settings = NoticeRouting.new()
      result = NoticeRouting.set_routing(settings, :sender)
      assert result == %{routing: :sender}
    end

    @tag :unit
    test "rejects invalid routing atoms" do
      settings = NoticeRouting.new()
      assert {:error, :invalid_routing} = NoticeRouting.set_routing(settings, :invalid)
      assert {:error, :invalid_routing} = NoticeRouting.set_routing(settings, :channel)
      assert {:error, :invalid_routing} = NoticeRouting.set_routing(settings, :pm)
    end
  end

  describe "save/2 and load/1" do
    @tag :integration
    test "round-trips routing preference for registered user" do
      # Create a registered nick first
      RetroHexChat.Repo.insert!(%RetroHexChat.Services.RegisteredNick{
        nickname: "SaveUser",
        password_hash: Bcrypt.hash_pwd_salt("pass123")
      })

      settings = %{routing: :status}
      assert :ok = NoticeRouting.save("SaveUser", settings)

      assert {:ok, loaded} = NoticeRouting.load("SaveUser")
      assert loaded.routing == :status
    end

    @tag :integration
    test "load returns error for unknown user" do
      assert {:error, :not_found} = NoticeRouting.load("UnknownUser")
    end

    @tag :integration
    test "save upserts existing row" do
      RetroHexChat.Repo.insert!(%RetroHexChat.Services.RegisteredNick{
        nickname: "UpsertUser",
        password_hash: Bcrypt.hash_pwd_salt("pass123")
      })

      settings1 = %{routing: :status}
      assert :ok = NoticeRouting.save("UpsertUser", settings1)

      settings2 = %{routing: :sender}
      assert :ok = NoticeRouting.save("UpsertUser", settings2)

      assert {:ok, loaded} = NoticeRouting.load("UpsertUser")
      assert loaded.routing == :sender
    end
  end
end
