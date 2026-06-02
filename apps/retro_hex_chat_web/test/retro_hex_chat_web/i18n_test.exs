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
      assert I18n.normalize_locale("pt-PT") == "pt_PT"
      assert I18n.normalize_locale("es-MX") == "es"
      assert I18n.normalize_locale("fr-CA") == "fr"
      assert I18n.normalize_locale("de-AT") == "de"
      assert I18n.normalize_locale("it-IT") == "it"
      assert I18n.normalize_locale("ja-JP") == "ja"
      assert I18n.normalize_locale("nl-BE") == "nl"
      assert I18n.normalize_locale("pl-PL") == "pl"
      assert I18n.normalize_locale("zh-CN") == "zh_hans"
      assert I18n.normalize_locale("zh-TW") == "zh_hant"
      assert I18n.normalize_locale("zh-HK") == "zh_hant"
      assert I18n.normalize_locale("id-ID") == "id"
      assert I18n.normalize_locale("ar-SA") == "ar"
      assert I18n.normalize_locale("bn-BD") == "bn"
      assert I18n.normalize_locale("bn-IN") == "bn"
      assert I18n.normalize_locale("ru-RU") == "ru"
      assert I18n.normalize_locale("hi-IN") == "hi"
      assert I18n.normalize_locale("ko-KR") == "ko"
      assert I18n.normalize_locale("tr-TR") == "tr"
      assert I18n.normalize_locale("ur-PK") == "ur"
      assert I18n.normalize_locale("ur-IN") == "ur"
      assert I18n.normalize_locale("vi-VN") == "vi"
    end

    test "rejects unsupported locales" do
      assert I18n.normalize_locale("../pt_BR") == nil
      assert I18n.normalize_locale(nil) == nil
    end
  end

  describe "resolve_locale/3" do
    test "uses param, then session, then accept-language, then default" do
      assert I18n.resolve_locale("pt-BR", "en", "en-US,en;q=0.9") == "pt_BR"
      assert I18n.resolve_locale(nil, "pt_BR", "en-US,en;q=0.9") == "pt_BR"
      assert I18n.resolve_locale(nil, nil, "pt-BR,pt;q=0.9,en;q=0.8") == "pt_BR"
      assert I18n.resolve_locale(nil, nil, "es-ES,es;q=0.9") == "es"
      assert I18n.resolve_locale(nil, nil, "fr;q=0.4,de;q=0.9") == "de"
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
    test "returns native labels for enabled locales" do
      on_exit(fn -> I18n.put_locale("en") end)

      I18n.put_locale("en")
      assert {"en", "English"} in I18n.supported_locales()
      assert {"pt_BR", "Português (Brasil)"} in I18n.supported_locales()
      assert {"pt_PT", "Português (Portugal)"} in I18n.supported_locales()
      assert {"es", "Español"} in I18n.supported_locales()
      assert {"it", "Italiano"} in I18n.supported_locales()
      assert {"nl", "Nederlands"} in I18n.supported_locales()
      assert {"pl", "Polski"} in I18n.supported_locales()
      assert {"zh_hans", "简体中文"} in I18n.supported_locales()
      assert {"zh_hant", "繁體中文"} in I18n.supported_locales()
      assert {"ar", "العربية"} in I18n.supported_locales()
      assert {"bn", "বাংলা"} in I18n.supported_locales()
      assert {"ru", "Русский"} in I18n.supported_locales()
      assert {"hi", "हिन्दी"} in I18n.supported_locales()
      assert {"ko", "한국어"} in I18n.supported_locales()
      assert {"tr", "Türkçe"} in I18n.supported_locales()
      assert {"ur", "اردو"} in I18n.supported_locales()
      assert {"vi", "Tiếng Việt"} in I18n.supported_locales()
    end
  end

  test "html_lang/0 returns a BCP 47 language tag" do
    on_exit(fn -> I18n.put_locale("en") end)

    I18n.put_locale("pt_BR")

    assert I18n.html_lang() == "pt-BR"
  end

  test "html_dir/0 returns the text direction for the active locale" do
    on_exit(fn -> I18n.put_locale("en") end)

    I18n.put_locale("ar")

    assert I18n.html_dir() == "rtl"

    I18n.put_locale("ur")

    assert I18n.html_dir() == "rtl"
  end

  test "open_graph_locale/0 returns a locale tag for SEO metadata" do
    on_exit(fn -> I18n.put_locale("en") end)

    I18n.put_locale("fr-CA")

    assert I18n.open_graph_locale() == "fr_FR"
  end
end
