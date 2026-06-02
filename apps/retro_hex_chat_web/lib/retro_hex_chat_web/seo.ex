defmodule RetroHexChatWeb.SEO do
  @moduledoc """
  SEO helpers for public URLs and search metadata.
  """

  alias RetroHexChatWeb.I18n
  alias RetroHexChatWeb.I18n.Locales

  @default_origin "https://retrohexchat.com"
  @social_image_path "/images/social/retrohexchat_og.png"
  @social_image_width 1200
  @social_image_height 630
  @social_image_type "image/png"

  @landing_paths [
    "/",
    "/how-it-works",
    "/features",
    "/privacy",
    "/install",
    "/community",
    "/faq"
  ]

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
  def landing_paths, do: @landing_paths

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
