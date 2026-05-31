#!/usr/bin/env elixir

defmodule I18nAddLocales do
  @moduledoc false

  Code.require_file("scripts/i18n_locale_helpers.exs")

  def main(args) do
    locales = I18nLocaleHelpers.locales_from_args(args, [])

    if locales == [] do
      IO.puts(:stderr, "No locales selected. Use --locales es,fr or --wave 1.")
      System.halt(1)
    end

    codes = I18nLocaleHelpers.locale_codes(locales)
    IO.puts("Generating Gettext catalogs for locales: #{Enum.join(codes, ", ")}")

    run!(
      "mix",
      ["run", "--no-start", "scripts/i18n_rehydrate_domain_translations.exs", "--locales", Enum.join(codes, ",")]
    )

    normalize_paths =
      codes
      |> Enum.flat_map(fn locale ->
        [
          "apps/retro_hex_chat/priv/gettext/#{locale}/LC_MESSAGES/*.po",
          "apps/retro_hex_chat_web/priv/gettext/#{locale}/LC_MESSAGES/*.po"
        ]
      end)

    run!("elixir", ["scripts/i18n_normalize_po_headers.exs" | normalize_paths])
  end

  defp run!(command, args) do
    {output, status} = System.cmd(command, args, stderr_to_stdout: true)
    IO.write(output)

    if status != 0 do
      IO.puts(:stderr, "#{command} #{Enum.join(args, " ")} failed")
      System.halt(status)
    end
  end
end

I18nAddLocales.main(System.argv())
