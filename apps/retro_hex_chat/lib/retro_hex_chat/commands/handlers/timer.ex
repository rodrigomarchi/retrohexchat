defmodule RetroHexChat.Commands.Handlers.Timer do
  @moduledoc "Handler for /timer [subcommand] [args]"
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Chat.TimerManager
  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler

  use RetroHexChat.Commands.Handler,
    name: "timer",
    category: :config,
    syntax: dgettext("commands", "/timer <name> [repeat] <seconds> <command>"),
    summary:
      dgettext(
        "commands",
        "Schedule a command to run after a delay or on a repeating interval. The command runs in the window that was active when the timer was created."
      ),
    description:
      dgettext(
        "commands",
        "Schedule a command to run after a delay or on a repeating interval.\nCreate: /timer <name> <seconds> <command>. Repeat: /timer <name> repeat <seconds> <command>.\nTimers run in the window that was active when they were created and do not switch your current window when they fire.\nManage: /timer list, /timer stop <name>.\nMax 5 timers. One-shot: 1-86400s. Repeat minimum: 10s. Session-only (lost on disconnect)."
      ),
    examples: [
      dgettext("commands", "/timer remind 1800 /me reminds everyone: standup in 30 minutes"),
      dgettext("commands", "/timer heartbeat repeat 600 /me is still here"),
      dgettext("commands", "/timer list"),
      dgettext("commands", "/timer stop heartbeat")
    ],
    parameters: [
      %Parameter{
        name: "name",
        required: true,
        type: :text,
        position: 0,
        description: dgettext("commands", "Timer name")
      },
      %Parameter{
        name: "args",
        required: true,
        type: :text,
        position: 1,
        description: dgettext("commands", "Configuration: [repeat] <seconds> <command>")
      }
    ],
    subcommands: [
      %{name: "list", description: dgettext("commands", "Show active timers")},
      %{name: "stop", description: dgettext("commands", "Stop a running timer")}
    ]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:ok, :ui_action, :open_timers_dialog, %{}}
  end

  def execute(args, _context) do
    case TimerManager.parse_timer_args(args) do
      {:ok, %{action: :list}} ->
        {:ok, :ui_action, :timer_list, %{}}

      {:ok, %{action: :stop, name: name}} ->
        {:ok, :ui_action, :timer_stop, %{name: name}}

      {:ok, %{action: :create} = data} ->
        {:ok, :ui_action, :timer_create,
         %{
           name: data.name,
           type: data.type,
           interval: data.interval,
           command: data.command
         }}

      {:error, msg} ->
        {:error, msg}
    end
  end
end
