defmodule RetroHexChatWeb.I18n do
  @moduledoc """
  Locale helpers for the web layer.
  """
  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChatWeb.I18n.Locales

  @default_locale "en"

  @spec default_locale() :: String.t()
  def default_locale, do: @default_locale

  @spec supported_locales() :: [{String.t(), String.t()}]
  def supported_locales do
    Enum.map(Locales.enabled(), &{&1.code, &1.label})
  end

  @spec supported_locale_codes() :: [String.t()]
  def supported_locale_codes, do: Locales.codes()

  @spec normalize_locale(String.t() | nil) :: String.t() | nil
  def normalize_locale(nil), do: nil
  def normalize_locale(""), do: nil

  def normalize_locale(locale) when is_binary(locale) do
    Locales.normalize(locale)
  end

  @spec resolve_locale(String.t() | nil, String.t() | nil, String.t() | nil) :: String.t()
  def resolve_locale(param_locale, session_locale, accept_language) do
    normalize_locale(param_locale) ||
      normalize_locale(session_locale) ||
      locale_from_accept_language(accept_language) ||
      @default_locale
  end

  @spec locale_from_accept_language(String.t() | nil) :: String.t() | nil
  def locale_from_accept_language(nil), do: nil
  def locale_from_accept_language(""), do: nil

  def locale_from_accept_language(header) when is_binary(header) do
    header
    |> String.split(",", trim: true)
    |> Enum.with_index()
    |> Enum.map(fn {entry, index} -> parse_accept_language_entry(entry, index) end)
    |> Enum.sort_by(fn {_locale, quality, index} -> {-quality, index} end)
    |> Enum.map(fn {locale, _quality, _index} -> locale end)
    |> Enum.find_value(&normalize_locale/1)
  end

  @spec put_locale(String.t() | nil) :: String.t()
  def put_locale(locale) do
    locale = normalize_locale(locale) || @default_locale
    Gettext.put_locale(RetroHexChat.Gettext, locale)
    Gettext.put_locale(RetroHexChatWeb.Gettext, locale)
    locale
  end

  @spec current_locale() :: String.t()
  def current_locale do
    RetroHexChatWeb.Gettext
    |> Gettext.get_locale()
    |> normalize_locale()
    |> Kernel.||(@default_locale)
  end

  @spec html_lang() :: String.t()
  def html_lang do
    current_locale()
    |> Locales.bcp47()
  end

  @spec html_dir() :: String.t()
  def html_dir do
    current_locale()
    |> Locales.direction()
  end

  @spec open_graph_locale() :: String.t()
  def open_graph_locale do
    current_locale()
    |> Locales.open_graph()
  end

  defp parse_accept_language_entry(entry, index) do
    [locale | params] = String.split(entry, ";", trim: true)

    quality =
      params
      |> Enum.find_value(1.0, fn param ->
        case param |> String.trim() |> String.split("=", parts: 2) do
          ["q", value] -> parse_quality(value)
          _other -> nil
        end
      end)

    {String.trim(locale), quality, index}
  end

  defp parse_quality(value) do
    case Float.parse(value) do
      {quality, ""} when quality >= 0.0 and quality <= 1.0 -> quality
      _invalid -> 0.0
    end
  end
end
