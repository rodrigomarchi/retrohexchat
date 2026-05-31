defmodule RetroHexChatWeb.I18n.Locales do
  @moduledoc """
  Supported locale metadata shared by locale negotiation and layouts.
  """

  @locales_file Path.expand("../../../../../config/i18n_locales.exs", __DIR__)
  @external_resource @locales_file
  @locales @locales_file |> Code.eval_file() |> elem(0)
  @enabled_statuses [:enabled]

  @spec all() :: [map()]
  def all, do: @locales

  @spec enabled() :: [map()]
  def enabled, do: Enum.filter(@locales, &(&1.status in @enabled_statuses))

  @spec codes() :: [String.t()]
  def codes, do: Enum.map(enabled(), & &1.code)

  @spec find(String.t()) :: map() | nil
  def find(code), do: Enum.find(@locales, &(&1.code == code))

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

  @spec bcp47(String.t()) :: String.t()
  def bcp47(code) do
    case find(code) do
      %{bcp47: bcp47} -> bcp47
      _missing -> "en"
    end
  end

  @spec direction(String.t()) :: String.t()
  def direction(code) do
    case find(code) do
      %{direction: direction} -> direction
      _missing -> "ltr"
    end
  end

  @spec open_graph(String.t()) :: String.t()
  def open_graph(code) do
    case find(code) do
      %{open_graph: open_graph} -> open_graph
      _missing -> "en_US"
    end
  end

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
