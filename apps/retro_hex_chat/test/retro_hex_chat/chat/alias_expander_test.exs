defmodule RetroHexChat.Chat.AliasExpanderTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Chat.AliasExpander

  describe "expand/3" do
    test "substitutes positional args $1 through $9" do
      template = "$1 $2 $3"
      args = ["Alice", "Bob", "Charlie"]
      context = %{nick: "me", chan: "#test"}

      assert AliasExpander.expand(template, args, context) == "Alice Bob Charlie"
    end

    test "replaces missing positional args with empty string" do
      template = "Hello $1 and $2!"
      args = ["Alice"]
      context = %{nick: "me", chan: "#test"}

      assert AliasExpander.expand(template, args, context) == "Hello Alice and !"
    end

    test "substitutes $nick with own nickname" do
      template = "/me ($nick) waves"
      args = []
      context = %{nick: "CoolUser", chan: "#test"}

      assert AliasExpander.expand(template, args, context) == "/me (CoolUser) waves"
    end

    test "substitutes $chan with current channel name" do
      template = "Welcome to $chan!"
      args = []
      context = %{nick: "me", chan: "#elixir"}

      assert AliasExpander.expand(template, args, context) == "Welcome to #elixir!"
    end

    test "replaces $chan with empty string when channel is nil" do
      template = "Channel: $chan"
      args = []
      context = %{nick: "me", chan: nil}

      assert AliasExpander.expand(template, args, context) == "Channel: "
    end

    test "escapes $$ to literal $" do
      template = "Price: $$5.00"
      args = []
      context = %{nick: "me", chan: "#test"}

      assert AliasExpander.expand(template, args, context) == "Price: $5.00"
    end

    test "passes through text with no variables" do
      template = "/me says hello everyone!"
      args = []
      context = %{nick: "me", chan: "#test"}

      assert AliasExpander.expand(template, args, context) == "/me says hello everyone!"
    end

    test "handles multiple variable types in one template" do
      template = "$nick greets $1 in $chan"
      args = ["Alice"]
      context = %{nick: "Bob", chan: "#lobby"}

      assert AliasExpander.expand(template, args, context) == "Bob greets Alice in #lobby"
    end

    test "handles $1 through $9 positional arguments" do
      template = "$1 $2 $3 $4 $5 $6 $7 $8 $9"
      args = ["a", "b", "c", "d", "e", "f", "g", "h", "i"]
      context = %{nick: "me", chan: "#test"}

      assert AliasExpander.expand(template, args, context) == "a b c d e f g h i"
    end

    test "handles adjacent variables without spaces" do
      template = "$nick$chan"
      args = []
      context = %{nick: "Bob", chan: "#test"}

      assert AliasExpander.expand(template, args, context) == "Bob#test"
    end
  end

  describe "validate_expansion/1" do
    test "accepts clean expansion" do
      assert :ok = AliasExpander.validate_expansion("/me says hello!")
    end

    test "accepts expansion with variables" do
      assert :ok = AliasExpander.validate_expansion("/me waves at $1 in $chan")
    end

    test "rejects expansion containing pipe" do
      assert {:error, _msg} = AliasExpander.validate_expansion("/me hello | /msg NickServ")
    end

    test "rejects expansion containing &&" do
      assert {:error, _msg} = AliasExpander.validate_expansion("/me hello && /quit")
    end

    test "rejects expansion containing semicolon" do
      assert {:error, _msg} = AliasExpander.validate_expansion("/me hello; /quit")
    end

    test "rejects expansion containing newlines" do
      assert {:error, _msg} = AliasExpander.validate_expansion("/me hello\n/quit")
    end

    test "rejects expansion containing carriage return" do
      assert {:error, _msg} = AliasExpander.validate_expansion("/me hello\r/quit")
    end
  end

  describe "contains_chaining?/1" do
    test "returns true for pipe" do
      assert AliasExpander.contains_chaining?("cmd1 | cmd2")
    end

    test "returns true for &&" do
      assert AliasExpander.contains_chaining?("cmd1 && cmd2")
    end

    test "returns true for semicolon" do
      assert AliasExpander.contains_chaining?("cmd1; cmd2")
    end

    test "returns true for newline" do
      assert AliasExpander.contains_chaining?("cmd1\ncmd2")
    end

    test "returns false for clean text" do
      refute AliasExpander.contains_chaining?("/me says hello!")
    end

    test "returns false for text with dollar signs" do
      refute AliasExpander.contains_chaining?("/me says $1 hello $nick")
    end
  end
end
