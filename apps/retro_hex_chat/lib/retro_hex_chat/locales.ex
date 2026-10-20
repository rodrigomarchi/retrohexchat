defmodule RetroHexChat.Locales do
  @moduledoc """
  The languages the chat is offered in, read from `config/i18n_locales.exs` —
  the single source of truth for the supported set.

  The domain asks it what a language code means (a channel's language, set by
  its founder, has to be one the chat speaks); the web layer adds what only a
  page needs — BCP 47 tags, text direction, Open Graph — on top of it.
  """

  @locales_file Path.expand("../../../../config/i18n_locales.exs", __DIR__)
  @external_resource @locales_file
  @locales @locales_file |> Code.eval_file() |> elem(0)
  @enabled_statuses [:enabled]

  @doc "Every locale in the file, offered or not."
  @spec all() :: [map()]
  def all, do: @locales

  @doc "The locales the chat is offered in."
  @spec enabled() :: [map()]
  def enabled, do: Enum.filter(@locales, &(&1.status in @enabled_statuses))

  @doc "The codes of the locales the chat is offered in (`\"pt_BR\"`)."
  @spec codes() :: [String.t()]
  def codes, do: Enum.map(enabled(), & &1.code)

  @doc "The locale whose code is exactly `code`, offered or not."
  @spec find(String.t()) :: map() | nil
  def find(code), do: Enum.find(@locales, &(&1.code == code))

  @doc """
  The offered locale `locale` names, as its code, or nil.

  Lenient about how it is written — case, `-` for `_`, a known alias such as
  `pt` or `en_GB` — and falls back from a region the chat does not know to the
  language alone, so `pt-br`, `PT_BR` and `pt` all answer `"pt_BR"`.
  """
  @spec normalize(String.t() | nil) :: String.t() | nil
  def normalize(nil), do: nil
  def normalize(""), do: nil

  def normalize(locale) when is_binary(locale) do
    key = locale_key(locale)

    cond do
      key == "" ->
        nil

      locale = alias_index()[key] ->
        normalize_found_locale(locale)

      locale = alias_index()[primary_key(key)] ->
        normalize_found_locale(locale)

      true ->
        nil
    end
  end

  @doc "The language's own name for itself (`\"Português (Brasil)\"`), or nil."
  @spec label(String.t() | nil) :: String.t() | nil
  def label(code) when is_binary(code) do
    case find(code) do
      %{status: status, label: label} when status in @enabled_statuses -> label
      _none -> nil
    end
  end

  def label(_code), do: nil

  defp normalize_found_locale(%{status: status, code: code}) when status in @enabled_statuses,
    do: code

  defp normalize_found_locale(_locale), do: nil

  defp alias_index do
    @locales
    |> Enum.flat_map(fn locale ->
      ([locale.code] ++ locale.aliases)
      |> Enum.map(&{locale_key(&1), locale})
    end)
    |> Map.new()
  end

  defp locale_key(locale) do
    locale
    |> String.trim()
    |> String.replace("-", "_")
    |> String.downcase()
  end

  defp primary_key(key) do
    key
    |> String.split("_", parts: 2)
    |> hd()
  end
end
