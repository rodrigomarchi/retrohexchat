defmodule RetroHexChatWeb.ChatLive.ChatContextTest do
  use ExUnit.Case, async: false

  @moduletag :unit

  alias RetroHexChat.Accounts.Session
  alias RetroHexChatWeb.ChatLive.ChatContext

  describe "from_session/2" do
    test "maps identity fields from the session" do
      session =
        Session.new("alice")
        |> Map.put(:active_channel, "#lobby")
        |> Map.put(:active_pm, "bob")

      ctx = ChatContext.from_session(session, "America/Sao_Paulo")

      assert ctx.nickname == "alice"
      assert ctx.active_channel == "#lobby"
      assert ctx.active_pm == "bob"
      assert ctx.timezone == "America/Sao_Paulo"
      assert ctx.identified == false
    end

    test "a fresh guest session has no elevated privileges" do
      ctx = ChatContext.from_session(Session.new("guest"), "Etc/UTC")

      refute ctx.admin?
      refute ctx.admin_only?
      refute ctx.root_admin?
    end
  end

  describe "authorization helpers" do
    setup do
      previous = Application.get_env(:retro_hex_chat, :root_admins, [])
      Application.put_env(:retro_hex_chat, :root_admins, ["rootadmin"])
      on_exit(fn -> Application.put_env(:retro_hex_chat, :root_admins, previous) end)
      :ok
    end

    test "root_admin? requires the session to be identified" do
      unidentified = %{Session.new("rootadmin") | identified: false}
      identified = %{Session.new("rootadmin") | identified: true}

      refute ChatContext.root_admin?(unidentified)
      assert ChatContext.root_admin?(identified)
    end

    test "an identified root admin counts as admin and admin_only" do
      session = %{Session.new("rootadmin") | identified: true}

      assert ChatContext.admin?(session)
      assert ChatContext.admin_only?(session)
    end

    test "an unrelated identified user is not an admin" do
      session = %{Session.new("nobody") | identified: true}

      refute ChatContext.admin?(session)
      refute ChatContext.admin_only?(session)
      refute ChatContext.root_admin?(session)
    end
  end
end
