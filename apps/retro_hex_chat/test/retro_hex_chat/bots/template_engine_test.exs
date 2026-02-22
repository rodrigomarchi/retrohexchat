defmodule RetroHexChat.Bots.TemplateEngineTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Bots.TemplateEngine

  describe "render/2" do
    test "replaces single placeholder" do
      assert TemplateEngine.render("Hello {nickname}!", %{"nickname" => "Alice"}) ==
               "Hello Alice!"
    end

    test "replaces multiple placeholders" do
      template = "Welcome to {channel}, {nickname}!"
      vars = %{"channel" => "#general", "nickname" => "Bob"}
      assert TemplateEngine.render(template, vars) == "Welcome to #general, Bob!"
    end

    test "replaces same placeholder multiple times" do
      template = "{nickname} said hi to {nickname}"

      assert TemplateEngine.render(template, %{"nickname" => "Eve"}) ==
               "Eve said hi to Eve"
    end

    test "leaves unmatched placeholders as-is" do
      assert TemplateEngine.render("Hello {unknown}!", %{"nickname" => "Alice"}) ==
               "Hello {unknown}!"
    end

    test "handles empty vars map" do
      assert TemplateEngine.render("Hello {nickname}!", %{}) == "Hello {nickname}!"
    end

    test "handles template with no placeholders" do
      assert TemplateEngine.render("Hello world!", %{"nickname" => "Alice"}) ==
               "Hello world!"
    end

    test "handles all standard placeholders" do
      template = "{botname} in {channel}: Try {prefix}help, {nickname}! Topic: {topic}"

      vars = %{
        "botname" => "GreeterBot",
        "channel" => "#help",
        "prefix" => "!",
        "nickname" => "Dave",
        "topic" => "Welcome"
      }

      assert TemplateEngine.render(template, vars) ==
               "GreeterBot in #help: Try !help, Dave! Topic: Welcome"
    end

    test "converts non-string values to string" do
      assert TemplateEngine.render("Count: {count}", %{"count" => 42}) == "Count: 42"
    end
  end
end
