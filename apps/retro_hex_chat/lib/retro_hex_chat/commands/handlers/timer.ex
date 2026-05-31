defmodule RetroHexChat.Commands.Handlers.Timer do
  @moduledoc "Handler for /timer [subcommand] [args]"
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Chat.TimerManager
  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_raw_args), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:ok, :system,
     %{
       content:
         gettext("Usage: /timer <name> <seconds> <command> — one-shot timer\n") <>
           gettext("       /timer <name> repeat <seconds> <command> — repeating timer\n") <>
           gettext("       /timer list — show active timers\n") <>
           gettext("       /timer stop <name> — cancel a timer")
     }}
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

  @impl true
  @spec help() :: %{
          name: String.t(),
          syntax: String.t(),
          description: String.t(),
          examples: [String.t()]
        }
  def help do
    %{
      name: "timer",
      syntax: gettext("/timer <name> [repeat] <seconds> <command>"),
      description:
        gettext(
          "Schedule a command to run after a delay or on a repeating interval.\nCreate: /timer <name> <seconds> <command>. Repeat: /timer <name> repeat <seconds> <command>.\nTimers run in the window that was active when they were created and do not switch your current window when they fire.\nManage: /timer list, /timer stop <name>.\nMax 5 timers. One-shot: 1-86400s. Repeat minimum: 10s. Session-only (lost on disconnect)."
        ),
      examples: [
        gettext("/timer remind 1800 /me reminds everyone: standup in 30 minutes"),
        gettext("/timer heartbeat repeat 600 /me is still here"),
        gettext("/timer list"),
        gettext("/timer stop heartbeat")
      ]
    }
  end

  @impl true
  def category, do: :config

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax
    alias RetroHexChat.Commands.CommandSyntax.Parameter

    %CommandSyntax{
      command: "timer",
      syntax: gettext("/timer <name> [repeat] <seconds> <command>"),
      description:
        gettext(
          "Schedule a command to run after a delay or on a repeating interval. The command runs in the window that was active when the timer was created."
        ),
      category: :config,
      parameters: [
        %Parameter{
          name: "name",
          required: true,
          type: :text,
          position: 0,
          description: gettext("Timer name")
        },
        %Parameter{
          name: "args",
          required: true,
          type: :text,
          position: 1,
          description: gettext("Configuration: [repeat] <seconds> <command>")
        }
      ],
      examples: [
        gettext("/timer remind 1800 /me reminds everyone: standup in 30 minutes"),
        gettext("/timer heartbeat repeat 600 /me is still here"),
        gettext("/timer list"),
        gettext("/timer stop heartbeat")
      ],
      subcommands: [
        %{name: "list", description: gettext("Show active timers")},
        %{name: "stop", description: gettext("Stop a running timer")}
      ]
    }
  end
end
