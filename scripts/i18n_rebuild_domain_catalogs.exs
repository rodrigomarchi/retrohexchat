#!/usr/bin/env elixir

defmodule I18nRebuildDomainCatalogs do
  @moduledoc false

  @apps ~w(apps/retro_hex_chat apps/retro_hex_chat_web)

  def main(_args) do
    Enum.each(@apps, fn app ->
      {output, status} = System.cmd("mix", ["gettext.extract", "--merge", "--no-fuzzy"], cd: app)
      IO.write(output)

      if status != 0 do
        IO.puts(:stderr, "mix gettext.extract failed for #{app}")
        System.halt(status)
      end
    end)

    run!("mix", ["run", "--no-start", "scripts/i18n_rehydrate_domain_translations.exs"])
    run!("elixir", ["scripts/i18n_normalize_po_headers.exs"])
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
