defmodule RetroHexChat.Notifications.CandidatesTest do
  @moduledoc """
  Who a channel line could possibly be about.

  The list is read straight off the text because the people it has to reach are
  precisely the ones the runtime cannot see: a person who is offline is not in
  the channel's membership any more. So the text is the only evidence left, and
  everything this module does is about not turning that evidence into spam —
  a bounded number of tokens, only shapes that could be a nickname at all, and
  nothing that was merely part of a link.
  """
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Notifications.Candidates

  describe "nick_tokens/2" do
    # Every ordinary word is a candidate shape, and that is on purpose: this
    # module has no way to tell a name from a noun, and the one thing that can
    # — the table of registered nicknames — is a query away.
    test "finds a nickname written as a plain word" do
      assert "Bob" in Candidates.nick_tokens("hey Bob are you there")
    end

    test "finds one written with the @ people expect to work" do
      assert "Bob" in Candidates.nick_tokens("@Bob look at this")
    end

    test "keeps the case it was written with" do
      assert Candidates.nick_tokens("BoB and bob") == ["BoB", "and"]
    end

    # The cap is small, so a long line can spend it entirely on ordinary words
    # before reaching the one name that was the point of writing it. A person
    # who reached for the @ said who they meant, and that has to survive.
    test "puts an @ mention ahead of the words that came before it" do
      text = Enum.map_join(1..20, " ", &"word#{&1}") <> " @Bob"

      assert "Bob" in Candidates.nick_tokens(text)
    end

    test "keeps the IRC specials a nickname is allowed to carry" do
      assert "Nick[away]" in Candidates.nick_tokens("ping Nick[away] please")
      assert "we_ird" in Candidates.nick_tokens("ping we_ird please")
    end

    test "drops a token that could not be a nickname" do
      refute "9lives" in Candidates.nick_tokens("9lives is not a nick")
      refute "-dash" in Candidates.nick_tokens("-dash is not a nick")
    end

    test "drops a single letter" do
      assert Candidates.nick_tokens("a b c d") == []
    end

    test "drops a token longer than a nickname can be" do
      tokens = Candidates.nick_tokens("seventeencharacters here")

      assert tokens == ["here"]
    end

    # The same mask the highlight engine uses, for the same reason: a URL is
    # full of words, and every one of them would otherwise be somebody.
    test "ignores everything inside a URL" do
      assert Candidates.nick_tokens("see https://example.com/Bob/alice now") == ["see", "now"]
    end

    test "counts what a URL hid against nobody" do
      refute "alice" in Candidates.nick_tokens("read https://example.com/alice")
    end

    test "stops at eight" do
      text = Enum.map_join(1..20, " ", &"user#{&1}")

      assert length(Candidates.nick_tokens(text)) == 8
    end

    test "counts a repeated nickname once" do
      assert Candidates.nick_tokens("Bob Bob bob BOB") == ["Bob"]
    end

    test "reads the visible text, not the markup" do
      assert Candidates.nick_tokens("**Bob** look", :markdown) == ["Bob", "look"]
    end

    test "has nothing to say about an empty line" do
      assert Candidates.nick_tokens("") == []
      assert Candidates.nick_tokens("   ") == []
    end
  end
end
