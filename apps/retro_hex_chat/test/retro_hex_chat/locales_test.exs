defmodule RetroHexChat.LocalesTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Locales

  test "every offered code answers for itself" do
    for code <- Locales.codes(), do: assert(Locales.normalize(code) == code)
  end

  test "a code is read however it is written" do
    assert Locales.normalize("pt-br") == "pt_BR"
    assert Locales.normalize("PT_BR") == "pt_BR"
    assert Locales.normalize("pt") == "pt_BR"
    assert Locales.normalize("en-GB") == "en"
  end

  test "a language the chat does not speak is nil" do
    assert Locales.normalize("klingon") == nil
    assert Locales.normalize("") == nil
    assert Locales.normalize(nil) == nil
  end

  test "a language is named in itself" do
    assert Locales.label("ja") == "日本語"
    assert Locales.label("xx") == nil
    assert Locales.label(nil) == nil
  end
end
