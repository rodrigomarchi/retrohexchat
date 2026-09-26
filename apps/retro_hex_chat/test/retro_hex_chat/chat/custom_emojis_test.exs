defmodule RetroHexChat.Chat.CustomEmojisTest do
  @moduledoc """
  The pictures a server answers to by name.

  Two refusals carry this: a name nobody could type between two colons, and a
  name already taken. Both would produce an emoji that exists in the picker and
  does nothing when written by hand, which is worse than not having it.
  """
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Chat.CustomEmojis
  alias RetroHexChat.Chat.Queries

  setup do
    CustomEmojis.reset_cache()
    on_exit(&CustomEmojis.reset_cache/0)

    %{admin: "Admin"}
  end

  defp uploaded_file(name \\ "shrug.png") do
    unique = System.unique_integer([:positive])

    {:ok, file} =
      Queries.insert_uploaded_file(%{
        owner_nickname: "Admin",
        original_filename: name,
        content_type: "image/png",
        byte_size: 2048,
        storage_bucket: "test",
        storage_key: "emoji/#{unique}/#{name}",
        directory_path: "/emoji/#{unique}",
        logical_path: "/emoji/#{unique}/#{name}",
        status: "uploaded"
      })

    file
  end

  describe "add/3" do
    test "takes a name and gives the picture back under it", ctx do
      file = uploaded_file()

      assert {:ok, emoji} = CustomEmojis.add("shrug", file.id, ctx.admin)
      assert emoji.name == "shrug"
      assert CustomEmojis.get("shrug").uploaded_file_id == file.id
    end

    test "the colons people type around it are not part of the name", ctx do
      file = uploaded_file()

      assert {:ok, emoji} = CustomEmojis.add(":Shrug:", file.id, ctx.admin)
      assert emoji.name == "shrug"
    end

    # A name with a space or a dash renders in the picker and cannot be written
    # by hand, which is an emoji that only half exists.
    test "refuses a name nobody could type between two colons", ctx do
      file = uploaded_file()

      assert {:error, _reason} = CustomEmojis.add("two words", file.id, ctx.admin)
      assert {:error, _reason} = CustomEmojis.add("x", file.id, ctx.admin)
      assert CustomEmojis.all() == []
    end

    test "refuses a name this server already answers to", ctx do
      {:ok, _first} = CustomEmojis.add("shrug", uploaded_file().id, ctx.admin)

      assert {:error, _reason} = CustomEmojis.add("SHRUG", uploaded_file().id, ctx.admin)
      assert length(CustomEmojis.all()) == 1
    end

    test "refuses once the server is full", ctx do
      for i <- 1..CustomEmojis.max_count() do
        {:ok, _emoji} = CustomEmojis.add("e#{i}", uploaded_file().id, ctx.admin)
      end

      assert {:error, _reason} = CustomEmojis.add("one_too_many", uploaded_file().id, ctx.admin)
    end
  end

  describe "the cache" do
    # Read on the render path of every message, so it is ETS rather than a
    # query — and the write has to reach it or the picker offers something the
    # conversation cannot draw.
    test "an added emoji is readable without touching the database", ctx do
      {:ok, _emoji} = CustomEmojis.add("shrug", uploaded_file().id, ctx.admin)

      assert %{name: "shrug"} = CustomEmojis.get("shrug")
      assert [%{name: "shrug"}] = CustomEmojis.all()
    end

    test "a removed emoji stops being readable", ctx do
      {:ok, emoji} = CustomEmojis.add("shrug", uploaded_file().id, ctx.admin)

      :ok = CustomEmojis.remove(emoji.id)

      assert CustomEmojis.get("shrug") == nil
      assert CustomEmojis.all() == []
    end

    test "it comes back from the database when it is seeded", ctx do
      {:ok, _emoji} = CustomEmojis.add("shrug", uploaded_file().id, ctx.admin)

      CustomEmojis.reset_cache()

      assert %{name: "shrug"} = CustomEmojis.get("shrug")
    end

    test "a name this server does not have answers nothing" do
      assert CustomEmojis.get("nothing_here") == nil
    end

    # Case folds on the way in and on the way out: somebody typing `:SHRUG:`
    # means the same picture.
    test "a name is looked up however it was typed", ctx do
      {:ok, _emoji} = CustomEmojis.add("shrug", uploaded_file().id, ctx.admin)

      assert %{name: "shrug"} = CustomEmojis.get("SHRUG")
    end
  end
end
