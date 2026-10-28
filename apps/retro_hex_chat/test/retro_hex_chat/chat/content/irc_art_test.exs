defmodule RetroHexChat.Chat.Content.IrcArtTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Chat.Content
  alias RetroHexChat.Chat.Content.IrcArt

  @color <<0x03>>

  defp html({:safe, iodata}), do: IO.iodata_to_binary(iodata)

  describe "rendering" do
    test "keeps the lines one under the other in one fixed-width block, escaped" do
      art = "#{@color}4██#{@color}\n<b>#</b>\n"

      rendered = html(Content.render_html(art, :irc_art))

      assert rendered =~ ~r/^<pre class="irc-art">/
      assert rendered =~ "irc-fg-4"
      assert rendered =~ "\n&lt;b&gt;#&lt;/b&gt;</pre>"
      refute rendered =~ "<b>"
    end

    test "spends the limit on format codes line by line, not on the whole block" do
      row = String.duplicate("#{@color}4█", 100)
      art = Enum.map_join(1..3, "\n", fn _ -> row end)

      rendered = html(Content.render_html(art, :irc_art))

      assert length(String.split(rendered, "irc-fg-4")) - 1 == 3 * 100
    end
  end

  describe "visible text" do
    test "is the block without codes, and its preview the first drawn line" do
      art = "\n#{@color}4 /\\ #{@color}\n/__\\"

      assert Content.plain_text(art, :irc_art) == "\n /\\ \n/__\\"
      assert Content.preview(art, :irc_art) == "/\\ …"
    end
  end

  describe "validation" do
    test "takes a block within its lines and columns, past the length of a chat line" do
      row = String.duplicate("#{@color}4,4#", IrcArt.max_columns())
      art = Enum.map_join(1..IrcArt.max_lines(), "\n", fn _ -> row end)

      assert String.length(art) > 1000
      assert Content.validate(art, "irc_art") == :ok
    end

    test "refuses a line too wide or too many lines, in words" do
      wide = String.duplicate("#", IrcArt.max_columns() + 1)
      tall = Enum.map_join(1..(IrcArt.max_lines() + 1), "\n", fn _ -> "#" end)

      assert Content.validate(wide, :irc_art) == {:error, :art_too_large}
      assert Content.validate(tall, :irc_art) == {:error, :art_too_large}
      assert {:error, message} = Content.validate_message(tall, :irc_art)
      assert message =~ "#{IrcArt.max_lines()}"
    end

    test "refuses a block with nothing to see" do
      assert Content.validate("\n  \n", :irc_art) == {:error, :blank}
    end
  end
end
