defmodule RetroHexChat.Commands.Handlers.Slow do
  @moduledoc "Handler for /slow [seconds] — set join throttle on the channel. 0 to disable."
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, gettext("Usage: /slow <seconds> (0 to disable)")}

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
      param = gettext("5:%{seconds}", seconds: seconds)
      {:ok, :ui_action, :set_mode, %{channel: channel, mode_string: "+j", params: [param]}}
    else
      {:error, _} = err -> err
      _ -> {:error, gettext("Usage: /slow <seconds> — must be a positive number (0 to disable)")}
    end
  end

  @impl true
  def help do
    %{
      name: "slow",
      syntax: gettext("/slow <seconds>"),
      description:
        gettext(
          "Set join throttle on the channel (5 joins per N seconds). Use /slow 0 to disable.\nRequires: channel operator or owner."
        ),
      examples: [gettext("/slow 30"), gettext("/slow 0")]
    }
  end

  @impl true
  def category, do: :channel

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax
    alias RetroHexChat.Commands.CommandSyntax.Parameter

    %CommandSyntax{
      command: "slow",
      syntax: gettext("/slow <seconds>"),
      description: gettext("Set join throttle. 0 to disable."),
      category: :channel,
      parameters: [
        %Parameter{
          name: "seconds",
          required: true,
          type: :text,
          position: 0,
          description: gettext("Throttle interval in seconds (0 to disable)")
        }
      ],
      examples: [gettext("/slow 30"), gettext("/slow 0")]
    }
  end

  defp require_channel(%{active_channel: nil}),
    do: {:error, gettext("You are not in any channel")}

  defp require_channel(%{active_channel: ch}), do: {:ok, ch}

  defp require_operator(context, channel) do
    if channel in context.operator_in do
      :ok
    else
      {:error, gettext("You must be a channel operator to use this command")}
    end
  end
end
