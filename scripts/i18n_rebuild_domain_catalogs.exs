#!/usr/bin/env elixir

defmodule I18nRebuildDomainCatalogs do
  @moduledoc false

  @apps ~w(apps/retro_hex_chat apps/retro_hex_chat_web)

  def main(args) do
    require_confirmation!(args)

    Enum.each(@apps, fn app ->
      {output, status} = System.cmd("mix", ["gettext.extract"], cd: app)
      IO.write(output)

      if status != 0 do
        IO.puts(:stderr, "mix gettext.extract failed for #{app}")
        System.halt(status)
      end
    end)

    run!(
      "mix",
      [
        "run",
        "--no-start",
        "scripts/i18n_rehydrate_domain_translations.exs",
        "--all",
        "--confirm-global-rebuild"
      ]
    )

    run!("elixir", ["scripts/i18n_normalize_po_headers.exs"])
  end

  defp require_confirmation!(args) do
    {opts, _paths, _invalid} =
      OptionParser.parse(args, strict: [confirm_global_rebuild: :boolean])

    if opts[:confirm_global_rebuild] != true do
      IO.puts(:stderr, "Refusing global i18n rebuild without --confirm-global-rebuild.")
      System.halt(2)
    end
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

I18nRebuildDomainCatalogs.main(System.argv())
