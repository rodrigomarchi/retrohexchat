defmodule RetroHexChatWeb.SEO do
  @moduledoc """
  SEO helpers for public URLs and search metadata.
  """

  alias RetroHexChatWeb.I18n
  alias RetroHexChatWeb.I18n.Locales
  alias RetroHexChatWeb.PublicPages
  alias RetroHexChatWeb.ShowcaseCatalog

  @default_origin "https://retrohexchat.app"
  @social_image_path "/images/social/retrohexchat_og.png"
  @social_image_width 1200
  @social_image_height 630
  @social_image_type "image/png"

  @spec origin() :: String.t()
  def origin do
    :retro_hex_chat_web
    |> Application.get_env(:public_origin, @default_origin)
    |> to_string()
    |> String.trim()
    |> String.trim_trailing("/")
    |> case do
      "" -> @default_origin
      origin -> origin
    end
  end

  @spec canonical_url(String.t(), String.t() | nil) :: String.t()
  def canonical_url(path, locale \\ I18n.current_locale()) do
    path
    |> localized_path(locale)
    |> site_url()
  end

  @spec site_url(String.t()) :: String.t()
  def site_url(path), do: origin() <> normalize_path(path)

  @typedoc "The picture a page is shared with."
  @type social_image :: %{
          url: String.t(),
          width: pos_integer(),
          height: pos_integer(),
          type: String.t(),
          alt: String.t()
        }

  @doc "The site's own sharing card, for every page without a picture of its own."
  @spec social_image() :: social_image()
  def social_image do
    %{
      url: social_image_url(),
      width: @social_image_width,
      height: @social_image_height,
      type: @social_image_type,
      alt: "Retro Hex Chat peer-to-peer chat preview"
    }
  end

  @spec social_image_url() :: String.t()
  def social_image_url, do: site_url(@social_image_path)

  @spec social_image_width() :: pos_integer()
  def social_image_width, do: @social_image_width

  @spec social_image_height() :: pos_integer()
  def social_image_height, do: @social_image_height

  @spec social_image_type() :: String.t()
  def social_image_type, do: @social_image_type

  @spec alternate_links(String.t()) :: [%{href: String.t(), hreflang: String.t()}]
  def alternate_links(path) do
    locale_links =
      Enum.map(Locales.enabled(), fn locale ->
        %{
          hreflang: locale.bcp47,
          href: canonical_url(path, locale.code)
        }
      end)

    locale_links ++
      [
        %{
          hreflang: "x-default",
          href: canonical_url(path, I18n.default_locale())
        }
      ]
  end

  @spec open_graph_alternate_locales() :: [String.t()]
  def open_graph_alternate_locales do
    current_locale = I18n.current_locale()

    Locales.enabled()
    |> Enum.reject(&(&1.code == current_locale))
    |> Enum.map(& &1.open_graph)
  end

  @spec landing_paths() :: [String.t()]
  def landing_paths, do: PublicPages.paths()

  @spec localized_locale_segments() :: [String.t()]
  def localized_locale_segments do
    Locales.enabled()
    |> Enum.reject(&(&1.code == I18n.default_locale()))
    |> Enum.map(& &1.bcp47)
  end

  @spec localized_urls(String.t()) :: [
          %{href: String.t(), hreflang: String.t(), locale: String.t()}
        ]
  def localized_urls(path) do
    Enum.map(Locales.enabled(), fn locale ->
      %{
        locale: locale.code,
        hreflang: locale.bcp47,
        href: canonical_url(path, locale.code)
      }
    end)
  end

  @spec noindex_content() :: String.t()
  def noindex_content, do: "noindex, nofollow, noarchive"

  @spec locale_segment(String.t() | nil) :: String.t() | nil
  def locale_segment(locale) do
    normalized_locale = I18n.normalize_locale(locale)

    cond do
      is_nil(normalized_locale) -> nil
      normalized_locale == I18n.default_locale() -> nil
      true -> Locales.bcp47(normalized_locale)
    end
  end

  @spec locale_from_segment(String.t() | nil) :: String.t() | nil
  def locale_from_segment(segment), do: I18n.normalize_locale(segment)

  @spec software_application_json_ld(String.t()) :: String.t()
  def software_application_json_ld(description) do
    %{
      "@context" => "https://schema.org",
      "@type" => "SoftwareApplication",
      "name" => "Retro Hex Chat",
      "applicationCategory" => "CommunicationApplication",
      "operatingSystem" => "Web",
      "description" => description,
      "license" => "https://opensource.org/licenses/MIT",
      "url" => site_url("/"),
      "image" => social_image_url(),
      "author" => %{
        "@type" => "Person",
        "name" => "Rodrigo Marchi"
      },
      "offers" => %{
        "@type" => "Offer",
        "price" => "0",
        "priceCurrency" => "USD"
      }
    }
    |> Jason.encode!()
  end

  @doc """
  The site itself, stated once.

  `SoftwareApplication` used to be emitted on all ninety-eight landing URLs with
  `url` pointing at `/` on every one of them — the same entity claimed ninety-
  eight times. The application is described where it lives, on the home page,
  and the other pages describe themselves.
  """
  @spec website_json_ld() :: String.t()
  def website_json_ld do
    %{
      "@context" => "https://schema.org",
      "@type" => "WebSite",
      "name" => "Retro Hex Chat",
      "url" => site_url("/"),
      "inLanguage" => Enum.map(Locales.enabled(), & &1.bcp47)
    }
    |> Jason.encode!()
  end

  @spec organization_json_ld() :: String.t()
  def organization_json_ld do
    %{
      "@context" => "https://schema.org",
      "@type" => "Organization",
      "name" => "Retro Hex Chat",
      "url" => site_url("/"),
      "logo" => social_image_url(),
      "sameAs" => ["https://github.com/rodrigomarchi/retro_hex_chat"]
    }
    |> Jason.encode!()
  end

  @doc """
  A page of questions and the answers it actually prints.

  The caller passes the same list the page renders from, never a second copy:
  structured data that quotes an answer the page no longer gives is worse than
  no structured data, because a search engine will show it.
  """
  @spec faq_page_json_ld([{String.t(), String.t()}], String.t()) :: String.t()
  def faq_page_json_ld(questions, path) do
    %{
      "@context" => "https://schema.org",
      "@type" => "FAQPage",
      "url" => canonical_url(path),
      "mainEntity" =>
        Enum.map(questions, fn {question, answer} ->
          %{
            "@type" => "Question",
            "name" => question,
            "acceptedAnswer" => %{"@type" => "Answer", "text" => answer}
          }
        end)
    }
    |> Jason.encode!()
  end

  @doc """
  One help topic, as the documentation it is.
  """
  @spec tech_article_json_ld(String.t(), String.t(), String.t()) :: String.t()
  def tech_article_json_ld(title, description, path) do
    %{
      "@context" => "https://schema.org",
      "@type" => "TechArticle",
      "headline" => title,
      "description" => description,
      "url" => canonical_url(path),
      "inLanguage" => Locales.bcp47(I18n.current_locale()),
      "isPartOf" => %{
        "@type" => "WebSite",
        "name" => "Retro Hex Chat",
        "url" => site_url("/")
      },
      "publisher" => %{"@type" => "Organization", "name" => "Retro Hex Chat"}
    }
    |> Jason.encode!()
  end

  @doc """
  Structured data for a showcase page.

  The index is a collection; a component page is the source code it documents.
  """
  @spec showcase_json_ld(String.t(), String.t(), String.t()) :: String.t()
  def showcase_json_ld("index", title, description) do
    %{
      "@context" => "https://schema.org",
      "@type" => "CollectionPage",
      "name" => title,
      "description" => description,
      "url" => site_url(ShowcaseCatalog.root()),
      "isPartOf" => %{"@type" => "WebSite", "name" => "Retro Hex Chat", "url" => site_url("/")}
    }
    |> Jason.encode!()
  end

  def showcase_json_ld(id, title, description) do
    %{
      "@context" => "https://schema.org",
      "@type" => "SoftwareSourceCode",
      "name" => title,
      "description" => description,
      "url" => site_url(ShowcaseCatalog.canonical_path(id)),
      "programmingLanguage" => "Elixir",
      "runtimePlatform" => "Phoenix LiveView",
      "license" => "https://opensource.org/licenses/MIT",
      "isPartOf" => %{
        "@type" => "CollectionPage",
        "name" => "RetroHexChat Component Showcase",
        "url" => site_url(ShowcaseCatalog.root())
      }
    }
    |> Jason.encode!()
  end

  @doc """
  A game's page as `VideoGame` structured data. Its `url` and `inLanguage` are
  the page's own: on `/pt-BR/games/x` they name that page, not the English one.
  There is no rating to offer, so the markup describes rather than competes for
  a rich result.
  """
  @spec video_game_json_ld(map(), String.t()) :: String.t()
  def video_game_json_ld(game, path) do
    %{
      "@context" => "https://schema.org",
      "@type" => "VideoGame",
      "name" => game.name,
      "description" => game.description,
      "url" => canonical_url(path),
      "inLanguage" => I18n.html_lang(),
      "gamePlatform" => "Web browser",
      "operatingSystem" => "Web browser",
      "applicationCategory" => "GameApplication",
      "playMode" => if(game.kind == :arcade, do: "SinglePlayer", else: "MultiPlayer"),
      "isAccessibleForFree" => true,
      "offers" => %{"@type" => "Offer", "price" => "0", "priceCurrency" => "USD"}
    }
    |> put_image(game)
    |> Jason.encode!(escape: :html_safe)
  end

  defp put_image(data, %{screenshot: %{path: path}}), do: Map.put(data, "image", site_url(path))
  defp put_image(data, _game), do: data

  @doc """
  `text` cut to what a search result shows — about 155 characters — at a word,
  with an ellipsis when anything was cut. A description that ends mid-word
  ("…started it al") reads as broken in the one place a page is judged.
  """
  @spec meta_description(String.t(), pos_integer()) :: String.t()
  def meta_description(text, limit \\ 155) do
    if String.length(text) <= limit do
      text
    else
      cut = String.slice(text, 0, limit - 1)

      head =
        case Regex.run(~r/^(.*)\s\S*$/su, cut) do
          [_, head] -> head
          nil -> cut
        end

      String.trim_trailing(head, " ,;:—-") <> "…"
    end
  end

  @spec breadcrumb_json_ld([{String.t(), String.t()}]) :: String.t()
  def breadcrumb_json_ld(items) do
    %{
      "@context" => "https://schema.org",
      "@type" => "BreadcrumbList",
      "itemListElement" =>
        items
        |> Enum.with_index(1)
        |> Enum.map(fn {{name, path}, position} ->
          %{
            "@type" => "ListItem",
            "position" => position,
            "name" => name,
            "item" => site_url(path)
          }
        end)
    }
    |> Jason.encode!()
  end

  @spec localized_path(String.t(), String.t() | nil) :: String.t()
  def localized_path(path, locale) do
    normalized_path = path |> normalize_path() |> strip_locale_prefix()
    normalized_locale = I18n.normalize_locale(locale) || I18n.default_locale()

    case locale_segment(normalized_locale) do
      nil -> normalized_path
      segment -> prefix_path(segment, normalized_path)
    end
  end

  defp normalize_path(nil), do: "/"
  defp normalize_path(""), do: "/"
  defp normalize_path("http" <> _rest = url), do: URI.parse(url).path || "/"
  defp normalize_path("/" <> _rest = path), do: path
  defp normalize_path(path), do: "/" <> path

  defp strip_locale_prefix(path) do
    case String.split(path, "/", parts: 3) do
      ["", segment] ->
        if locale_from_segment(segment), do: "/", else: path

      ["", segment, rest] ->
        if locale_from_segment(segment), do: "/" <> rest, else: path

      _other ->
        path
    end
  end

  defp prefix_path(segment, "/"), do: "/" <> segment
  defp prefix_path(segment, path), do: "/" <> segment <> path
end
