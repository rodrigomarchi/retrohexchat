defmodule RetroHexChat.Chat.Content.HtmlTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Chat.Content.Html

  test "escape/1 covers text and attribute values alike" do
    assert Html.escape(~s(<a href="x">Tom & Jerry's</a>)) ==
             "&lt;a href=&quot;x&quot;&gt;Tom &amp; Jerry&#39;s&lt;/a&gt;"
  end

  test "unescape/1 reverses escape/1" do
    text = ~s(<b>"5 > 3" & 'x'</b>)
    assert text |> Html.escape() |> Html.unescape() == text
  end

  test "unescape/1 decodes once: an escaped entity stays an entity" do
    assert Html.unescape("&amp;lt;") == "&lt;"
    assert Html.unescape(nil) == ""
  end

  test "rewrite_text/2 leaves protected tags alone" do
    assert Html.rewrite_text("x <code>x</code> x", &String.upcase/1) == "X <code>x</code> X"
  end
end
