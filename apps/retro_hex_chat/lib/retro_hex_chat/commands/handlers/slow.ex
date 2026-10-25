defmodule RetroHexChat.Commands.Handlers.Slow do
  @moduledoc "Handler for /slow [seconds] — set join throttle on the channel. 0 to disable."
  use Gettext, backend: RetroHexChat.Gettext

  import RetroHexChat.Commands.Handler.Guards

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler

  use RetroHexChat.Commands.Handler,
    name: "slow",
    category: :channel,
    syntax: dgettext("commands", "/slow <seconds>"),
    summary: dgettext("commands", "Set join throttle. 0 to disable."),
    description:
      dgettext(
        "commands",
        "Set join throttle on the channel (5 joins per N seconds). Use /slow 0 to disable.\nRequires: channel operator or owner."
      ),
    examples: [dgettext("commands", "/slow 30"), dgettext("commands", "/slow 0")],
    parameters: [
      Parameter.required(
        :text,
        "seconds",
        dgettext("commands", "Throttle interval in seconds (0 to disable)")
      )
    ]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context),
    do: {:error, dgettext("commands", "Usage: /slow <seconds> (0 to disable)")}

  def execute(["0"], context) do
    with {:ok, channel} <- require_channel(context),
         :ok <- require_operator(context, channel) do
      {:ok, :ui_action, :set_mode, %{channel: channel, mode_string: "-j", params: []}}
    end
  end

  def execute([seconds_str | _], context) do
    with {:ok, channel} <- require_channel(context),
         :ok <- require_operator(context, channel),
         {seconds, ""} <- Integer.parse(seconds_str),
         true <- seconds > 0 do
      param = dgettext("commands", "5:%{seconds}", seconds: seconds)
      {:ok, :ui_action, :set_mode, %{channel: channel, mode_string: "+j", params: [param]}}
    else
      {:error, _} = err ->
        err

      _ ->
        {:error,
         dgettext("commands", "Usage: /slow <seconds> — must be a positive number (0 to disable)")}
    end
  end
end
