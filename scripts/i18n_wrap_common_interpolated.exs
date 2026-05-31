#!/usr/bin/env elixir

# Focused migration helper for common interpolated command/service messages.
# It converts string interpolation to Gettext named bindings for patterns that
# appear repeatedly in command handlers.

defmodule I18nWrapCommonInterpolated do
  @paths [
    "apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers",
    "apps/retro_hex_chat/lib/retro_hex_chat/admin.ex",
    "apps/retro_hex_chat/lib/retro_hex_chat/services"
  ]

  @replacements [
    {~S|"*** #{msg}"|, ~S|gettext("*** %{message}", message: msg)|},
    {~S|"[ChanServ] #{msg}"|, ~S|gettext("[ChanServ] %{message}", message: msg)|},
    {~S|"[NickServ] #{msg}"|, ~S|gettext("[NickServ] %{message}", message: msg)|},
    {~S|"[BotService] #{msg}"|, ~S|gettext("[BotService] %{message}", message: msg)|},
    {~S|"[BotService] Bot '#{name}' created successfully."|,
     ~S|gettext("[BotService] Bot '%{name}' created successfully.", name: name)|},
    {~S|"[BotService] Bot '#{name}' destroyed."|,
     ~S|gettext("[BotService] Bot '%{name}' destroyed.", name: name)|},
    {~S|"[BotService] Bot '#{name}' not found."|,
     ~S|gettext("[BotService] Bot '%{name}' not found.", name: name)|},
    {~S|"[BotService] Bot '#{bot_name}' not found."|,
     ~S|gettext("[BotService] Bot '%{name}' not found.", name: bot_name)|},
    {~S|"[BotService] Bot '#{bot_name}' joined #{channel}."|,
     ~S|gettext("[BotService] Bot '%{name}' joined %{channel}.", name: bot_name, channel: channel)|},
    {~S|"[BotService] Bot '#{bot_name}' left #{channel}."|,
     ~S|gettext("[BotService] Bot '%{name}' left %{channel}.", name: bot_name, channel: channel)|},
    {~S|"[BotService] Bot '#{bot_name}' #{action}."|,
     ~S|gettext("[BotService] Bot '%{name}' %{action}.", name: bot_name, action: action)|},
    {~S|"[BotService] Bot '#{bot_name}' is already in #{channel}."|,
     ~S|gettext("[BotService] Bot '%{name}' is already in %{channel}.", name: bot_name, channel: channel)|},
    {~S|"[BotService] #{bot_name} has no custom commands."|,
     ~S|gettext("[BotService] %{name} has no custom commands.", name: bot_name)|},
    {~S|"[BotService] Command '#{trigger}' set for #{bot_name}."|,
     ~S|gettext("[BotService] Command '%{trigger}' set for %{name}.", trigger: trigger, name: bot_name)|},
    {~S|"[BotService] Command '#{trigger}' removed from #{bot_name}."|,
     ~S|gettext("[BotService] Command '%{trigger}' removed from %{name}.", trigger: trigger, name: bot_name)|},
    {~S|"[BotService] Failed to create bot: #{msg}"|,
     ~S|gettext("[BotService] Failed to create bot: %{message}", message: msg)|},
    {~S|"[BotService] Failed to add command '#{trigger}': #{msg}"|,
     ~S|gettext("[BotService] Failed to add command '%{trigger}': %{message}", trigger: trigger, message: msg)|}
  ]

  def run do
    files =
      @paths
      |> Enum.flat_map(&expand/1)
      |> Enum.uniq()
      |> Enum.sort()

    rewritten =
      Enum.reduce(files, 0, fn file, count ->
        source = File.read!(file)

        updated =
          Enum.reduce(@replacements, source, fn {from, to}, acc ->
            String.replace(acc, from, to)
          end)

        if updated != source do
          File.write!(file, updated)
          count + 1
        else
          count
        end
      end)

    IO.puts("rewritten=#{rewritten} scanned=#{length(files)}")
  end

  defp expand(path) do
    cond do
      File.dir?(path) -> Path.wildcard(Path.join(path, "**/*.ex"))
      File.regular?(path) -> [path]
      true -> []
    end
  end
end

I18nWrapCommonInterpolated.run()
