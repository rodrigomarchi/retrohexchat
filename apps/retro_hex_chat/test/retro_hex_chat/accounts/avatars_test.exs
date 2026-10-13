defmodule RetroHexChat.Accounts.AvatarsTest do
  @moduledoc """
  The character a person made, remembered past the visit that made it: the chat
  draws it in the ordinary case, somebody talking who is not in a space at all.
  """
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  import Ecto.Query

  alias RetroHexChat.Accounts.Avatars
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.NickServ
  alias RetroHexChat.Services.RegisteredNick
  alias RetroHexChat.VirtualSpace.CharacterRecipe

  @tunic "c1.b-av.s-2.o-tun-0-3.h-lng-2.w-0.f-0"
  @bald "c1.b-av.s-5.o-bas-0-0.h-0.w-0.f-0"

  setup do
    nickname = "Ava#{System.unique_integer([:positive])}"
    {:ok, _nick} = NickServ.register(nickname, "password123")
    %{nickname: nickname}
  end

  test "remembers what was made", ctx do
    assert :ok = Avatars.remember(ctx.nickname, @tunic)
    assert Avatars.for_nick(ctx.nickname) == @tunic
  end

  test "making another replaces it", ctx do
    :ok = Avatars.remember(ctx.nickname, @tunic)
    :ok = Avatars.remember(ctx.nickname, @bald)

    assert Avatars.for_nick(ctx.nickname) == @bald
  end

  # A caller must not be able to store a character the art cannot compose.
  test "refuses a recipe the catalog cannot compose", ctx do
    assert {:error, :invalid_avatar} = Avatars.remember(ctx.nickname, "knight")

    assert {:error, :invalid_avatar} =
             Avatars.remember(ctx.nickname, "c1.b-av.s-2.o-xyz-0-0.h-0.w-0.f-0")

    assert Avatars.for_nick(ctx.nickname) == nil
  end

  # A build that retires a piece must not leave a row drawing nothing: the
  # stored recipe is read back as the closest one the art still has.
  test "reads a stored recipe back as one the art can compose", ctx do
    Repo.update_all(where(RegisteredNick, nickname: ^ctx.nickname),
      set: [avatar: "c1.b-av.s-2.o-tun-0-3.h-gone-2.w-0.f-0"]
    )

    assert CharacterRecipe.valid?(Avatars.for_nick(ctx.nickname))
  end

  test "says nothing about a nickname nobody registered" do
    assert Avatars.for_nick("Nobody") == nil
    assert Avatars.remember("Nobody", @tunic) == {:error, :not_found}
  end

  describe "for_nicks/1" do
    test "answers for a whole roster in one query", ctx do
      other = "Oth#{System.unique_integer([:positive])}"
      {:ok, _} = NickServ.register(other, "password123")
      :ok = Avatars.remember(ctx.nickname, @tunic)

      {count, avatars} =
        count_queries(fn -> Avatars.for_nicks([ctx.nickname, other, "Nobody"]) end)

      assert count == 1
      assert avatars == %{ctx.nickname => @tunic}
    end

    test "says nothing at all when asked about nobody" do
      assert Avatars.for_nicks([]) == %{}
    end

    # The nicklist and the message rows spell a nickname however it was typed.
    test "matches however the nickname was capitalised", ctx do
      :ok = Avatars.remember(ctx.nickname, @bald)

      assert %{} = found = Avatars.for_nicks([String.upcase(ctx.nickname)])
      assert Map.values(found) == [@bald]
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
