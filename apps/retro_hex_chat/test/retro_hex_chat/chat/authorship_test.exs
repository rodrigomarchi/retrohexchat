defmodule RetroHexChat.Chat.AuthorshipTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Chat.{Authorship, Message, PrivateMessage}

  describe "author/1" do
    test "reads a channel message's author" do
      assert Authorship.author(%Message{author_nickname: "Ada"}) == "Ada"
    end

    test "reads a private message's sender as its author" do
      assert Authorship.author(%PrivateMessage{sender_nickname: "Ada"}) == "Ada"
    end

    test "reads the shapes the web layer carries" do
      assert Authorship.author(%{author: "Ada"}) == "Ada"
      assert Authorship.author(%{sender: "Ada"}) == "Ada"
      assert Authorship.author(%{author_nickname: "Ada"}) == "Ada"
      assert Authorship.author(%{sender_nickname: "Ada"}) == "Ada"
    end

    test "a message stating no author has none" do
      assert Authorship.author(%Message{author_nickname: nil}) == nil
      assert Authorship.author(%{}) == nil
      assert Authorship.author(nil) == nil
      assert Authorship.author("not a message") == nil
    end
  end

  describe "written_by?/2" do
    test "recognises the writer of either kind" do
      assert Authorship.written_by?(%Message{author_nickname: "Ada"}, "Ada")
      assert Authorship.written_by?(%PrivateMessage{sender_nickname: "Ada"}, "Ada")
    end

    test "does not recognise anyone else" do
      refute Authorship.written_by?(%Message{author_nickname: "Ada"}, "Mario")
      refute Authorship.written_by?(%PrivateMessage{sender_nickname: "Ada"}, "Mario")
    end

    test "is case sensitive, as the nickname comparison has always been" do
      refute Authorship.written_by?(%Message{author_nickname: "Ada"}, "ada")
    end

    test "a message with no author was written by nobody" do
      refute Authorship.written_by?(%Message{author_nickname: nil}, "Ada")
      refute Authorship.written_by?(%{}, "Ada")
    end

    test "nobody is not a nickname" do
      refute Authorship.written_by?(%Message{author_nickname: "Ada"}, nil)
    end
  end
end
