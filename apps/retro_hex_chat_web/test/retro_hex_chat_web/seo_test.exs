defmodule RetroHexChatWeb.SEOTest do
  use ExUnit.Case, async: false

  alias RetroHexChatWeb.I18n
  alias RetroHexChatWeb.I18n.Locales
  alias RetroHexChatWeb.SEO

  setup do
    public_origin = Application.get_env(:retro_hex_chat_web, :public_origin)

    on_exit(fn ->
      if is_nil(public_origin) do
        Application.delete_env(:retro_hex_chat_web, :public_origin)
      else
        Application.put_env(:retro_hex_chat_web, :public_origin, public_origin)
      end
    end)

    :ok
  end

  describe "origin and canonical URLs" do
    test "trims the configured public origin" do
      Application.put_env(:retro_hex_chat_web, :public_origin, "https://example.com///")

      assert SEO.origin() == "https://example.com"
      assert SEO.site_url("/features") == "https://example.com/features"
    end

    test "falls back to the production origin when the configured origin is blank" do
      Application.put_env(:retro_hex_chat_web, :public_origin, "   ")

      assert SEO.origin() == "https://retrohexchat.app"
    end

    test "canonical_url normalizes paths and strips queries from absolute URLs" do
      assert SEO.canonical_url("features", "en") == "https://retrohexchat.app/features"

      assert SEO.canonical_url("https://other.example/pt-BR/features?locale=pt_BR", "pt_BR") ==
               "https://retrohexchat.app/pt-BR/features"
    end
  end

  describe "localized_path/2" do
    test "keeps default locale public paths unprefixed" do
      assert SEO.localized_path("/", "en") == "/"
      assert SEO.localized_path("/features", "en") == "/features"
    end

    test "prefixes non-default locales with BCP 47 path segments" do
      assert SEO.localized_path("/", "pt_BR") == "/pt-BR"
      assert SEO.localized_path("/features", "pt_BR") == "/pt-BR/features"
      assert SEO.localized_path("/features", "zh_hans") == "/zh-Hans/features"
      assert SEO.localized_path("/features", "pt_PT") == "/pt-PT/features"
    end

    test "replaces existing locale prefixes instead of nesting them" do
      assert SEO.localized_path("/pt-BR/features", "es") == "/es/features"
      assert SEO.localized_path("/zh-Hans/chat/help", "pt_BR") == "/pt-BR/chat/help"
      assert SEO.localized_path("/pt-BR/features", "en") == "/features"
    end
  end

  describe "locale segments" do
    test "maps enabled locales to public URL segments" do
      assert SEO.locale_segment("en") == nil
      assert SEO.locale_segment("pt_BR") == "pt-BR"
      assert SEO.locale_segment("zh_hans") == "zh-Hans"
    end

    test "normalizes public URL segments back to locale codes" do
      assert SEO.locale_from_segment("pt-BR") == "pt_BR"
      assert SEO.locale_from_segment("zh-Hans") == "zh_hans"
      assert SEO.locale_from_segment("connect") == nil
    end
  end

  describe "alternate and localized URLs" do
    test "alternate_links returns every enabled locale plus x-default" do
      links = SEO.alternate_links("/pt-BR/features")
      hreflangs = Enum.map(links, & &1.hreflang)

      assert length(links) == length(Locales.enabled()) + 1
      assert "x-default" in hreflangs

      for locale <- Locales.enabled() do
        assert locale.bcp47 in hreflangs
      end

      assert Enum.find(links, &(&1.hreflang == "x-default")).href ==
               "https://retrohexchat.app/features"

      refute Enum.any?(links, &String.contains?(&1.href, "?locale="))
    end

    test "localized_urls returns canonical clean URLs for every enabled locale" do
      urls = SEO.localized_urls("/chat/help/cmd-join")

      assert length(urls) == length(Locales.enabled())

      assert Enum.find(urls, &(&1.locale == I18n.default_locale())).href ==
               "https://retrohexchat.app/chat/help/cmd-join"

      assert Enum.find(urls, &(&1.locale == "pt_BR")).href ==
               "https://retrohexchat.app/pt-BR/chat/help/cmd-join"

      refute Enum.any?(urls, &String.contains?(&1.href, "?locale="))
    end
  end

  describe "metadata helpers" do
    test "social image metadata is stable" do
      assert SEO.social_image_url() ==
               "https://retrohexchat.app/images/social/retrohexchat_og.png"

      assert SEO.social_image_width() == 1200
      assert SEO.social_image_height() == 630
      assert SEO.social_image_type() == "image/png"
    end

    test "noindex content is shared by non-public layouts" do
      assert SEO.noindex_content() == "noindex, nofollow, noarchive"
    end

    test "software application JSON-LD is parseable and canonical" do
      description = "Self-hosted chat with peer-to-peer calls."
      json_ld = SEO.software_application_json_ld(description) |> Jason.decode!()

      assert json_ld["@context"] == "https://schema.org"
      assert json_ld["@type"] == "SoftwareApplication"
      assert json_ld["name"] == "Retro Hex Chat"
      assert json_ld["description"] == description
      assert json_ld["url"] == "https://retrohexchat.app/"
      assert json_ld["image"] == SEO.social_image_url()
      assert json_ld["license"] == "https://opensource.org/licenses/MIT"
      assert json_ld["offers"]["price"] == "0"
      assert json_ld["offers"]["priceCurrency"] == "USD"
    end

    test "breadcrumb JSON-LD uses the configured canonical origin" do
      json_ld = SEO.breadcrumb_json_ld([{"Home", "/"}, {"Help", "/chat/help"}]) |> Jason.decode!()

      assert json_ld["@context"] == "https://schema.org"
      assert json_ld["@type"] == "BreadcrumbList"

      assert [
               %{"name" => "Home", "item" => "https://retrohexchat.app/"},
               %{"name" => "Help", "item" => "https://retrohexchat.app/chat/help"}
             ] =
               Enum.map(json_ld["itemListElement"], fn item ->
                 Map.take(item, ["name", "item"])
               end)
    end
  end
end
