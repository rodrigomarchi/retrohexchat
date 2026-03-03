defmodule RetroHexChat.Commands.Handlers.BioTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.Bio

  @base_context %{
    nickname: "Alice",
    active_channel: "#lobby",
    channels: ["#lobby"],
    identified: false,
    operator_in: []
  }

  describe "validate/1" do
    test "accepts empty args" do
      assert :ok = Bio.validate("")
    end

    test "accepts non-empty args" do
      assert :ok = Bio.validate("some text")
    end
  end

  describe "execute/2" do
    test "returns view_bio when no args" do
      assert {:ok, :ui_action, :view_bio, %{}} = Bio.execute([], @base_context)
    end

    test "returns clear_bio for 'clear' arg" do
      assert {:ok, :ui_action, :clear_bio, %{}} = Bio.execute(["clear"], @base_context)
    end

    test "returns set_bio with text" do
      assert {:ok, :ui_action, :set_bio, %{text: "Elixir fan", truncated: false}} =
               Bio.execute(["Elixir", "fan"], @base_context)
    end

    test "joins multiple args with spaces" do
      assert {:ok, :ui_action, :set_bio, %{text: "Hello world test", truncated: false}} =
               Bio.execute(["Hello", "world", "test"], @base_context)
    end

    test "truncates bio over 200 graphemes" do
      long_text = String.duplicate("a", 250)
      args = String.split(long_text, " ", trim: true)

      assert {:ok, :ui_action, :set_bio, %{text: truncated, truncated: true}} =
               Bio.execute(args, @base_context)

      assert String.length(truncated) == 200
    end

    test "does not truncate bio at exactly 200 graphemes" do
      text = String.duplicate("b", 200)
      args = [text]

      assert {:ok, :ui_action, :set_bio, %{text: ^text, truncated: false}} =
               Bio.execute(args, @base_context)
    end
  end

  describe "help/0" do
    test "returns help map" do
      help = Bio.help()
      assert help.name == "bio"
      assert is_binary(help.syntax)
      assert is_binary(help.description)
      assert is_list(help.examples)
    end
  end
end
