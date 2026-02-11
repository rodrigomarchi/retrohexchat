defmodule RetroHexChat.Chat.LinkPreview.HTTPTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Chat.LinkPreview.HTTP

  @moduletag :unit

  describe "parse_title/1" do
    test "extracts title from simple HTML" do
      html = "<html><head><title>Hello World</title></head></html>"
      assert HTTP.parse_title(html) == {:ok, "Hello World"}
    end

    test "extracts title with attributes" do
      html = ~s(<title lang="en">My Page</title>)
      assert HTTP.parse_title(html) == {:ok, "My Page"}
    end

    test "strips whitespace from title" do
      html = "<title>  spaced  title  </title>"
      assert HTTP.parse_title(html) == {:ok, "spaced title"}
    end

    test "handles multiline title" do
      html = "<title>\n  Multi\n  Line\n  Title\n</title>"
      assert HTTP.parse_title(html) == {:ok, "Multi Line Title"}
    end

    test "HTML-escapes title content" do
      html = "<title><script>alert('xss')</script></title>"

      assert HTTP.parse_title(html) ==
               {:ok, "&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;"}
    end

    test "truncates title over 200 chars" do
      long_title = String.duplicate("a", 250)
      {:ok, result} = HTTP.parse_title("<title>#{long_title}</title>")
      # 200 + "..."
      assert String.length(result) == 203
      assert String.ends_with?(result, "...")
    end

    test "returns error for no title tag" do
      html = "<html><head></head></html>"
      assert HTTP.parse_title(html) == {:error, :no_title}
    end

    test "returns error for empty title" do
      html = "<title></title>"
      assert HTTP.parse_title(html) == {:error, :no_title}
    end

    test "returns error for whitespace-only title" do
      html = "<title>   </title>"
      assert HTTP.parse_title(html) == {:error, :no_title}
    end

    test "case insensitive title tag" do
      html = "<TITLE>My Title</TITLE>"
      assert HTTP.parse_title(html) == {:ok, "My Title"}
    end
  end
end
