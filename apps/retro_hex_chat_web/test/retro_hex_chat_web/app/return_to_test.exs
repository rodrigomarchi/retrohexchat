defmodule RetroHexChatWeb.App.ReturnToTest do
  @moduledoc """
  Where a connect may send someone afterwards.

  This is the only open-redirect surface the shareable-surfaces work creates, so
  the negative cases are a table rather than a paragraph: a payload that slips
  through here turns the product's own login into a redirector to somewhere
  else.
  """
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChatWeb.App.ReturnTo

  test "accepts the app's own paths" do
    for path <- [
          "/chat",
          "/chat?join=%23lobby",
          "/join/abcdefghjk",
          "/play",
          "/play/hex_pong",
          "/call/tok",
          "/space/abcdefghjk",
          "/p2p/tok"
        ] do
      assert ReturnTo.sanitize(path) == path, "expected #{path} to be accepted"
    end
  end

  # A shared link may well be a localized one, because every public page in this
  # app exists under a locale segment. Refusing those would drop a visitor into
  # the chat instead of back on the card they were sent.
  test "accepts the same paths under a locale segment" do
    for path <- ["/pt-BR/join/abcdefghjk", "/zh-Hans/join/abcdefghjk", "/es/join/abcdefghjk"] do
      assert ReturnTo.sanitize(path) == path, "expected #{path} to be accepted"
    end
  end

  test "a segment that is not an enabled locale is not a free pass" do
    for path <- ["/xx-YY/join/abcdefghjk", "/evil/join/abcdefghjk", "/pt-BR2/join/abcdefghjk"] do
      assert ReturnTo.sanitize(path) == "/chat", "expected #{path} to be refused"
    end
  end

  # Each of these is a real technique, not a hypothetical: a scheme-relative
  # URL, an absolute one, a backslash browsers normalise to a slash, and a
  # traversal that leaves the app's own path space.
  test "falls back to the chat for anything that could leave this origin" do
    for path <- [
          "//evil.example",
          "///evil.example",
          "https://evil.example",
          "http://evil.example",
          "//evil.example/join/abcdefghjk",
          "/\\evil.example",
          "\\\\evil.example",
          "javascript:alert(1)",
          "/chat/../../etc/passwd",
          "/play/../../..",
          "/connect",
          "/unknown",
          "chat",
          "",
          nil,
          :not_a_string,
          String.duplicate("/play/", 200)
        ] do
      assert ReturnTo.sanitize(path) == "/chat", "expected #{inspect(path)} to be refused"
    end
  end

  # Refusing is not an error the caller handles: there is always somewhere
  # sensible to go, and the alternative is a login that dead-ends.
  test "always answers with a usable path" do
    assert ReturnTo.sanitize("//evil.example") =~ ~r{\A/}
  end
end
