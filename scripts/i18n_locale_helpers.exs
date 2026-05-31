defmodule I18nLocaleHelpers do
  @moduledoc false

  @locales_file "config/i18n_locales.exs"

  def all_locales do
    @locales_file
    |> Code.eval_file()
    |> elem(0)
  end

  def enabled_locales do
    Enum.filter(all_locales(), &(&1.status == :enabled))
  end

  def locale_codes(locales), do: Enum.map(locales, & &1.code)

  def locales_from_args(args, default_locales \\ enabled_locales()) do
    {opts, _paths, _invalid} =
      OptionParser.parse(args,
        strict: [locale: :string, locales: :string, wave: :integer, all: :boolean]
      )

    cond do
      opts[:all] == true ->
        all_locales()

      wave = opts[:wave] ->
        all_locales()
        |> Enum.filter(&(&1.wave == wave))
        |> ensure_locale_statuses()

      locale_list = opts[:locales] || opts[:locale] ->
        requested =
          locale_list
          |> String.split(",", trim: true)
          |> Enum.map(&String.trim/1)

        all_locales()
        |> Enum.filter(&(&1.code in requested))
        |> ensure_requested_locales!(requested)

      true ->
        default_locales
    end
  end

  def locale!(code) do
    Enum.find(all_locales(), &(&1.code == code)) ||
      raise ArgumentError, "unknown locale: #{code}"
  end

  def headers(locale) do
    [
      "Project-Id-Version: RetroHexChat\n",
      "PO-Revision-Date: 2026-05-31 00:00+0000\n",
      "Last-Translator: RetroHexChat Team\n",
      "Language-Team: #{locale.code}\n",
      "Language: #{locale.code}\n",
      "MIME-Version: 1.0\n",
      "Content-Type: text/plain; charset=UTF-8\n",
      "Content-Transfer-Encoding: 8bit\n",
      "Plural-Forms: #{locale.plural_forms}\n"
    ]
  end

  def top_comments(domain, locale) do
    [
      [
        ~s( "msgid"s in this file come from #{domain}.pot.),
        " ",
        " Do not add, change, or remove msgids manually.",
        " Use mix gettext.extract --merge and the i18n scripts to refresh catalogs.",
        " ",
        " Locale: #{locale.code}; status: #{locale.status}; wave: #{locale.wave}."
      ]
    ]
  end

  defp ensure_locale_statuses(locales) do
    Enum.map(locales, fn
      %{status: :planned} = locale -> %{locale | status: :enabled}
      locale -> locale
    end)
  end

  defp ensure_requested_locales!(locales, requested) do
    found = MapSet.new(locale_codes(locales))
    missing = Enum.reject(requested, &MapSet.member?(found, &1))

    if missing != [] do
      raise ArgumentError, "unknown locales: #{Enum.join(missing, ", ")}"
    end

    ensure_locale_statuses(locales)
  end
end
