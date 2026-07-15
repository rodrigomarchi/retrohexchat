#!/usr/bin/env elixir

defmodule I18nMergeDomainCatalogs do
  @moduledoc false

  Code.require_file("scripts/i18n_locale_helpers.exs")

  @apps %{
    "domain" => "apps/retro_hex_chat",
    "retro_hex_chat" => "apps/retro_hex_chat",
    "apps/retro_hex_chat" => "apps/retro_hex_chat",
    "web" => "apps/retro_hex_chat_web",
    "retro_hex_chat_web" => "apps/retro_hex_chat_web",
    "apps/retro_hex_chat_web" => "apps/retro_hex_chat_web"
  }

  @default_apps ["apps/retro_hex_chat", "apps/retro_hex_chat_web"]

  def main(args) do
    {opts, _rest, invalid} =
      OptionParser.parse(args,
        strict: [
          app: :string,
          apps: :string,
          domain: :string,
          domains: :string,
          locale: :string,
          locales: :string,
          no_fuzzy: :boolean
        ],
        aliases: [a: :app, d: :domain, l: :locale]
      )

    if invalid != [] do
      IO.puts(:stderr, "Invalid options: #{inspect(invalid)}")
      System.halt(2)
    end

    domains = selected_domains(opts)

    if domains == [] do
      IO.puts(:stderr, "No domains selected. Use DOMAINS=landing or --domains landing.")
      System.halt(2)
    end

    apps = selected_apps(opts)
    locales = selected_locales(opts)
    merge_opts = if opts[:no_fuzzy], do: ["--no-fuzzy"], else: []

    apps
    |> Enum.flat_map(&merge_jobs(&1, domains, locales, merge_opts))
    |> run_jobs!()
  end

  defp selected_apps(opts) do
    case split_option(opts[:apps]) ++ split_option(opts[:app]) do
      [] -> @default_apps
      apps -> apps |> Enum.map(&normalize_app!/1) |> Enum.uniq()
    end
  end

  defp selected_domains(opts) do
    (split_option(opts[:domains]) ++ split_option(opts[:domain]))
    |> Enum.uniq()
  end

  defp selected_locales(opts) do
    case split_option(opts[:locales]) ++ split_option(opts[:locale]) do
      [] -> I18nLocaleHelpers.enabled_locales() |> I18nLocaleHelpers.locale_codes()
      locales -> locales |> Enum.uniq() |> validate_locales!()
    end
  end

  defp validate_locales!(locales) do
    Enum.each(locales, &I18nLocaleHelpers.locale!/1)
    locales
  end

  defp split_option(nil), do: []

  defp split_option(value) do
    value
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp normalize_app!(app) do
    Map.fetch!(@apps, app)
  rescue
    KeyError ->
      IO.puts(:stderr, "Unknown app #{inspect(app)}. Use domain, web, or an app path.")
      System.halt(2)
  end

  defp merge_jobs(app, domains, locales, merge_opts) do
    Enum.flat_map(domains, fn domain ->
      pot = Path.join(["priv/gettext", "#{domain}.pot"])

      if File.exists?(Path.join(app, pot)) do
        Enum.flat_map(locales, fn locale ->
          po = Path.join(["priv/gettext", locale, "LC_MESSAGES", "#{domain}.po"])

          if File.exists?(Path.join(app, po)) do
            [{app, po, pot, merge_opts}]
          else
            IO.puts(:stderr, "#{app}: skipping missing #{po}")
            []
          end
        end)
      else
        []
      end
    end)
  end

  defp run_jobs!([]) do
    IO.puts(:stderr, "No matching PO/POT pairs found.")
    System.halt(1)
  end

  defp run_jobs!(jobs) do
    Enum.each(jobs, fn {app, po, pot, opts} ->
      IO.puts("#{app}: mix gettext.merge #{po} #{pot} #{Enum.join(opts, " ")}")

      {output, status} =
        System.cmd("mix", ["gettext.merge", po, pot | opts], cd: app, stderr_to_stdout: true)

      IO.write(output)

      if status != 0 do
        IO.puts(:stderr, "mix gettext.merge failed for #{app}/#{po}")
        System.halt(status)
      end
    end)

    IO.puts("merged=#{length(jobs)}")
  end
end

I18nMergeDomainCatalogs.main(System.argv())
