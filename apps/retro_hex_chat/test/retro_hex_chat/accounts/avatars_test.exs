defmodule RetroHexChat.Accounts.AvatarsTest do
  @moduledoc """
  The character a person chose, remembered past the visit that chose it.

  Until now the choice lived in the space's own process and the browser's
  localStorage, so it existed only while somebody was standing in a space. The
  chat needs it in the ordinary case — somebody talking who is not in a space at
  all — which is what makes it worth storing.
  """
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Accounts.Avatars
  alias RetroHexChat.Services.NickServ

  setup do
    nickname = "Ava#{System.unique_integer([:positive])}"
    {:ok, _nick} = NickServ.register(nickname, "password123")
    %{nickname: nickname}
  end

  test "remembers what was chosen", ctx do
    assert :ok = Avatars.remember(ctx.nickname, "knight")
    assert Avatars.for_nick(ctx.nickname) == "knight"
  end

  test "choosing again replaces the choice", ctx do
    :ok = Avatars.remember(ctx.nickname, "knight")
    :ok = Avatars.remember(ctx.nickname, "rogue")

    assert Avatars.for_nick(ctx.nickname) == "rogue"
  end

  # A build that removes a class must not leave rows pointing at art that is no
  # longer there, and a caller must not be able to write one either.
  test "refuses a character this build does not have", ctx do
    assert {:error, :invalid_avatar} = Avatars.remember(ctx.nickname, "wizard")
    assert Avatars.for_nick(ctx.nickname) == nil
  end

  test "says nothing about a nickname nobody registered" do
    assert Avatars.for_nick("Nobody") == nil
    assert Avatars.remember("Nobody", "knight") == {:error, :not_found}
  end

  describe "for_nicks/1" do
    test "answers for a whole roster in one query", ctx do
      other = "Oth#{System.unique_integer([:positive])}"
      {:ok, _} = NickServ.register(other, "password123")
      :ok = Avatars.remember(ctx.nickname, "cleric")

      {count, avatars} =
        count_queries(fn -> Avatars.for_nicks([ctx.nickname, other, "Nobody"]) end)

      assert count == 1
      assert avatars == %{ctx.nickname => "cleric"}
    end

    test "says nothing at all when asked about nobody" do
      assert Avatars.for_nicks([]) == %{}
    end

    # The nicklist and the message rows spell a nickname however it was typed.
    test "matches however the nickname was capitalised", ctx do
      :ok = Avatars.remember(ctx.nickname, "monk")

      assert %{} = found = Avatars.for_nicks([String.upcase(ctx.nickname)])
      assert Map.values(found) == ["monk"]
    end
  end

  defp count_queries(fun) do
    ref = make_ref()
    parent = self()
    handler = "avatar-query-count-#{inspect(ref)}"

    :telemetry.attach(
      handler,
      [:retro_hex_chat, :repo, :query],
      fn _event, _measurements, _metadata, _config -> send(parent, {ref, :query}) end,
      nil
    )

    try do
      result = fun.()
      {drain(ref, 0), result}
    after
      :telemetry.detach(handler)
    end
  end

  defp drain(ref, count) do
    receive do
      {^ref, :query} -> drain(ref, count + 1)
    after
      0 -> count
    end
  end
end
