defmodule RetroHexChatWeb.Components.UI.VariantsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  @moduletag :unit

  alias RetroHexChatWeb.Components.UI.{Badge, Variants}

  @spec_ Variants.new(
           tone: %{"default" => "tone-default", "loud" => "tone-loud"},
           size: %{"default" => "size-default", "sm" => "size-sm"}
         )

  defp badge(assigns) do
    render_component(
      &Badge.badge/1,
      Map.merge(
        %{inner_block: [%{inner_block: fn _a, _b -> "hi" end, __slot__: :inner_block}]},
        assigns
      )
    )
  end

  describe "new/1" do
    test "an axis with no default is refused where it is declared" do
      assert_raise ArgumentError, ~r/no "default" to fall back to/, fn ->
        Variants.new(tone: %{"loud" => "tone-loud"})
      end
    end

    test "names the axis that is missing one" do
      assert_raise ArgumentError, ~r/:size/, fn ->
        Variants.new(
          tone: %{"default" => "tone-default"},
          size: %{"sm" => "size-sm"}
        )
      end
    end
  end

  describe "classes/2" do
    test "the words a caller used" do
      assert Variants.classes(@spec_, %{tone: "loud", size: "sm"}) == "tone-loud size-sm"
    end

    test "an axis nobody mentioned falls back" do
      assert Variants.classes(@spec_, %{tone: "loud"}) == "tone-loud size-default"
    end

    test "nothing mentioned is every default" do
      assert Variants.classes(@spec_, %{}) == "tone-default size-default"
    end

    test "a word the table does not know falls back rather than vanishing" do
      assert Variants.classes(@spec_, %{tone: "typo"}) == "tone-default size-default"
    end

    test "a nil is a word nobody used" do
      assert Variants.classes(@spec_, %{tone: nil}) == "tone-default size-default"
    end

    test "only the declared axes are read" do
      props = %{tone: "loud", class: "caller-class", rest: %{}, __changed__: nil}

      assert Variants.classes(@spec_, props) == "tone-loud size-default"
    end

    test "the order is the one the component declared" do
      reversed =
        Variants.new(
          size: %{"default" => "size-default"},
          tone: %{"default" => "tone-default"}
        )

      assert Variants.classes(reversed, %{}) == "size-default tone-default"
    end
  end

  # The three primitives that vary this way had no test of their own, and the
  # fallback is what they were missing: a variant coming from a variable rather
  # than a literal is not checked by `attr ... values:`.
  describe "a badge, which is one of them" do
    test "a known variant styles it" do
      assert badge(%{variant: "success"}) =~ "text-success-dark"
    end

    test "no variant is the default one" do
      assert badge(%{}) =~ "text-primary"
    end

    test "a variant nobody defined still looks like a badge" do
      html = badge(%{variant: "no-such-variant"})

      assert html =~ "text-primary"
      assert html =~ "shadow-retro-field"
    end

    test "the caller's own class still lands" do
      assert badge(%{variant: "success", class: "mine"}) =~ "mine"
    end
  end
end
