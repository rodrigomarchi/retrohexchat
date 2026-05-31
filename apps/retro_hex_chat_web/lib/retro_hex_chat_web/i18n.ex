defmodule RetroHexChatWeb.I18n do
  @moduledoc """
  Locale helpers for the web layer.
  """
  use Gettext, backend: RetroHexChatWeb.Gettext

  @default_locale "en"
  @supported_locales [
    {"en", gettext_noop("English")},
    {"pt_BR", gettext_noop("Português (Brasil)")}
  ]

  @spec default_locale() :: String.t()
  def default_locale, do: @default_locale

  @spec supported_locales() :: [{String.t(), String.t()}]
  def supported_locales do
    Enum.map(@supported_locales, fn {code, label} ->
      {code, Gettext.gettext(RetroHexChatWeb.Gettext, label)}
    end)
  end

  @spec supported_locale_codes() :: [String.t()]
  def supported_locale_codes, do: Enum.map(@supported_locales, &elem(&1, 0))

  @spec normalize_locale(String.t() | nil) :: String.t() | nil
  def normalize_locale(nil), do: nil
  def normalize_locale(""), do: nil

  def normalize_locale(locale) when is_binary(locale) do
    locale
    |> String.trim()
    |> String.replace("-", "_")
    |> String.downcase()
    |> case do
      "en" -> "en"
      "en_us" -> "en"
      "en_gb" -> "en"
      "pt" -> "pt_BR"
      "pt_br" -> "pt_BR"
      _ -> nil
    end
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
    |> Enum.map(fn entry -> entry |> String.split(";", parts: 2) |> hd() end)
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
    |> String.replace("_", "-")
  end
end
