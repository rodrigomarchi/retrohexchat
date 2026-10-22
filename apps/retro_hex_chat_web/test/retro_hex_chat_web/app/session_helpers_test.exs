defmodule RetroHexChatWeb.App.SessionHelpersTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Services.NickServ
  alias RetroHexChatWeb.App.SessionHelpers

  defp nick, do: "Sh#{rem(System.unique_integer([:positive]), 100_000)}"

  describe "sharable?/1" do
    test "a registered nickname may mint a link, anyone else may not" do
      registered = nick()
      {:ok, _} = NickServ.register(registered, "pass123")

      assert SessionHelpers.sharable?(registered)
      refute SessionHelpers.sharable?(nick())
      refute SessionHelpers.sharable?("")
      refute SessionHelpers.sharable?(nil)
    end
  end

  describe "require_identified/2" do
    test "asks NickServ, and refuses in the caller's words" do
      identified = nick()
      {:ok, _} = NickServ.register(identified, "pass123")

      assert :ok = SessionHelpers.require_identified(identified, "no")
      assert {:error, "no"} = SessionHelpers.require_identified(nick(), "no")
      assert {:error, "no"} = SessionHelpers.require_identified(nil, "no")
    end
  end
end
