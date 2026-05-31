defmodule RetroHexChatWeb.I18nTest do
  use ExUnit.Case, async: true

  alias RetroHexChatWeb.I18n

  describe "normalize_locale/1" do
    test "normalizes supported locale aliases" do
      assert I18n.normalize_locale("en") == "en"
      assert I18n.normalize_locale("en-US") == "en"
      assert I18n.normalize_locale("pt") == "pt_BR"
      assert I18n.normalize_locale("pt-BR") == "pt_BR"
      assert I18n.normalize_locale("pt_BR") == "pt_BR"
    end

    test "rejects unsupported locales" do
      assert I18n.normalize_locale("es") == nil
      assert I18n.normalize_locale("../pt_BR") == nil
      assert I18n.normalize_locale(nil) == nil
    end
  end

  describe "resolve_locale/3" do
    test "uses param, then session, then accept-language, then default" do
      assert I18n.resolve_locale("pt-BR", "en", "en-US,en;q=0.9") == "pt_BR"
      assert I18n.resolve_locale(nil, "pt_BR", "en-US,en;q=0.9") == "pt_BR"
      assert I18n.resolve_locale(nil, nil, "pt-BR,pt;q=0.9,en;q=0.8") == "pt_BR"
      assert I18n.resolve_locale(nil, nil, "es-ES,es;q=0.9") == "en"
    end
  end

  describe "put_locale/1" do
    test "sets both application Gettext backends" do
      on_exit(fn -> I18n.put_locale("en") end)

      assert I18n.put_locale("pt-BR") == "pt_BR"
      assert Gettext.get_locale(RetroHexChat.Gettext) == "pt_BR"
      assert Gettext.get_locale(RetroHexChatWeb.Gettext) == "pt_BR"

      assert I18n.put_locale("unsupported") == "en"
      assert Gettext.get_locale(RetroHexChat.Gettext) == "en"
      assert Gettext.get_locale(RetroHexChatWeb.Gettext) == "en"
    end
  end

  describe "supported_locales/0" do
    test "returns labels translated for the active locale" do
      on_exit(fn -> I18n.put_locale("en") end)

      I18n.put_locale("en")
      assert I18n.supported_locales() == [{"en", "English"}, {"pt_BR", "Português (Brasil)"}]

      I18n.put_locale("pt_BR")
      assert I18n.supported_locales() == [{"en", "Inglês"}, {"pt_BR", "Português (Brasil)"}]
    end
  end

  test "html_lang/0 returns a BCP 47 language tag" do
    on_exit(fn -> I18n.put_locale("en") end)

    I18n.put_locale("pt_BR")

    assert I18n.html_lang() == "pt-BR"
  end
end
