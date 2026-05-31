defmodule RetroHexChat.Bots.Capabilities.Help do
  @moduledoc """
  Capability that responds to !prefix help with a list of available commands.
  """

  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Bots.Capability

  @impl true
  @spec name() :: atom()
  def name, do: :help

  @impl true
  @spec description() :: String.t()
  def description, do: gettext("Built-in !help command listing available commands")

  @impl true
  @spec handle_message(String.t(), String.t(), RetroHexChat.Bots.Capability.bot_context()) ::
          RetroHexChat.Bots.Capability.capability_result()
  def handle_message(content, _author, ctx) do
    prefix = ctx.command_prefix
    bot_name = ctx.bot_name
    full_prefix = prefix <> bot_name

    trimmed = String.trim(content)
    lower = String.downcase(trimmed)

    long_form_a = String.downcase(full_prefix <> " help")
    long_form_b = String.downcase(full_prefix <> "help")
    short_form = String.downcase(prefix <> "help")

    if lower == long_form_a or lower == long_form_b or lower == short_form do
      commands = Map.get(ctx.config, "commands", %{})
      {:multi_reply, build_help_lines(bot_name, prefix, commands)}
    else
      :ignore
    end
  end

  @impl true
  @spec handle_event(atom(), map(), RetroHexChat.Bots.Capability.bot_context()) ::
          RetroHexChat.Bots.Capability.capability_result()
  def handle_event(_event, _payload, _ctx), do: :ignore

  @impl true
  @spec default_config() :: map()
  def default_config, do: %{"enabled" => true}

  @impl true
  @spec validate_config(map()) :: :ok | {:error, String.t()}
  def validate_config(_), do: :ok

  @impl true
  @spec commands() :: [%{trigger: String.t(), description: String.t()}]
  def commands do
    [%{trigger: "help", description: gettext("Show this help message")}]
  end

  # ── Helpers ──

  @spec build_help_lines(String.t(), String.t(), map()) :: [String.t()]
  defp build_help_lines(bot_name, prefix, commands) do
    header = gettext("%{bot_name} — Available Commands:", bot_name: bot_name)

    cmd_lines =
      commands
      |> Enum.filter(fn {_trigger, cmd} -> Map.get(cmd, "enabled", true) end)
      |> Enum.sort_by(fn {trigger, _} -> trigger end)
      |> Enum.map(fn {trigger, cmd} ->
        desc = Map.get(cmd, "description", "")

        gettext("  %{prefix}%{trigger} — %{description}",
          prefix: prefix,
          trigger: trigger,
          description: desc
        )
      end)

    help_line = gettext("  %{prefix}help — Show this help message", prefix: prefix)

    if cmd_lines == [] do
      [header, help_line]
    else
      [header | cmd_lines] ++ [help_line]
    end
  end
end
