defmodule RetroHexChatWeb.App.ChatHelpersEmojiTest do
  @moduledoc """
  `:name:` turning into the picture this server answers to.

  The two that matter are both about restraint: a name the server does not have
  stays exactly as it was typed — never a broken image — and the name goes into
  the markup escaped, because it is administrator input and administrator input
  is still input.
  """
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Chat.CustomEmojis
  alias RetroHexChat.Chat.Queries
  alias RetroHexChatWeb.App.ChatHelpers

  setup do
    CustomEmojis.reset_cache()
    on_exit(&CustomEmojis.reset_cache/0)
    :ok
  end

  defp add(name) do
    unique = System.unique_integer([:positive])

    {:ok, file} =
      Queries.insert_uploaded_file(%{
        owner_nickname: "Admin",
        original_filename: "#{name}.png",
        content_type: "image/png",
        byte_size: 1024,
        storage_bucket: "test",
        storage_key: "emoji/#{unique}.png",
        directory_path: "/emoji/#{unique}",
        logical_path: "/emoji/#{unique}/#{name}.png",
        status: "uploaded"
      })

    {:ok, emoji} = CustomEmojis.add(name, file.id, "Admin")
    emoji
  end

  defp render(text), do: ChatHelpers.format_content(text, "irc", false)

  test "a name this server has becomes its picture" do
    emoji = add("shrug")

    html = render("well :shrug: then")

    assert html =~ ~s(src="/chat/emoji/#{emoji.id}")
    assert html =~ ~s(alt=":shrug:")
    assert html =~ "chat-emoji"
    assert html =~ "well "
    assert html =~ " then"
  end

  # The absence that keeps this honest: an unknown name is a word somebody
  # typed, not a picture that failed to load.
  #
  # The server deliberately has an emoji here. Without one the resolver short
  # circuits before it looks at any name, and this would pass while proving
  # nothing about the name at all — which is exactly how it was written first.
  test "a name this server does not have stays as text" do
    add("shrug")

    html = render("time is :money:")

    assert html =~ ":money:"
    refute html =~ "chat-emoji"
    refute html =~ "<img"
  end

  test "it reads the name however it was typed" do
    emoji = add("shrug")

    assert render("go :SHRUG: on") =~ ~s(src="/chat/emoji/#{emoji.id}")
  end

  test "a colon pair with nothing usable between it is left alone" do
    add("shrug")

    assert render("10:30:00") =~ "10:30:00"
    assert render("a :: b") =~ "::"
  end

  # Administrator input is still input, and it lands inside an attribute.
  test "the name is escaped on the way into the markup" do
    emoji = add("shrug")

    html = render(":shrug:")

    refute html =~ ~s(alt=":shrug:"><)
    assert html =~ ~s(data-emoji-id="#{emoji.id}")
  end

  test "an emoji inside formatted text survives the formatting" do
    emoji = add("shrug")

    html = render("\x02bold :shrug: here\x02")

    assert html =~ ~s(src="/chat/emoji/#{emoji.id}")
    assert html =~ "irc-bold"
  end
end
