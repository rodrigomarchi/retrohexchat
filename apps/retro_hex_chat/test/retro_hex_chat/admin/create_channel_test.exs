defmodule RetroHexChat.Admin.CreateChannelTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Admin
  alias RetroHexChat.Services.{NickServ, Queries}

  defp channel, do: "#adm#{rem(System.unique_integer([:positive]), 100_000)}"

  test "an identified admin's channel is created and registered" do
    admin = "Adm#{rem(System.unique_integer([:positive]), 100_000)}"
    {:ok, _} = NickServ.register(admin, "password123")
    name = channel()

    assert {:ok, message} = Admin.create_channel(name, admin)
    assert message =~ "registered"
    assert Queries.find_registered_channel(name)
  end

  test "when ChanServ refuses the registration, the admin is told so, not that it worked" do
    name = channel()

    assert {:error, message} = Admin.create_channel(name, "NobodyRegistered")
    refute message =~ "created and registered"
    refute Queries.find_registered_channel(name)
  end
end
