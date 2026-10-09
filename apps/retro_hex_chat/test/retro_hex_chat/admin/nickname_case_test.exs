defmodule RetroHexChat.Admin.NicknameCaseTest do
  @moduledoc "Server roles and server bans hold for a nickname in any case."

  use ExUnit.Case, async: false

  @moduletag :unit

  alias RetroHexChat.Admin.{BanCache, RoleCache}

  test "a role granted to one case is held by every case, listed as granted" do
    nick = "RoLe#{System.unique_integer([:positive])}"
    RoleCache.add(nick, "admin")
    on_exit(fn -> RoleCache.remove_all(nick) end)

    assert RoleCache.admin?(String.downcase(nick))
    assert RoleCache.admin?(String.upcase(nick))
    assert nick in RoleCache.list_admin_nicks()

    RoleCache.remove(String.upcase(nick), "admin")
    refute RoleCache.admin?(nick)
  end

  test "a server ban on one case refuses every case, listed as banned" do
    nick = "BaN#{System.unique_integer([:positive])}"
    BanCache.add(nick)
    on_exit(fn -> BanCache.remove(nick) end)

    assert BanCache.banned?(String.downcase(nick))
    assert {nick, nil} in BanCache.list()

    BanCache.remove(String.upcase(nick))
    refute BanCache.banned?(nick)
  end
end
