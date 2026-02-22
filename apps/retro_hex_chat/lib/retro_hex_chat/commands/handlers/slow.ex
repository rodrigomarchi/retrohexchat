defmodule RetroHexChat.Commands.Handlers.Slow do
  @moduledoc "Handler for /slow [seconds] — set join throttle on the channel. 0 to disable."
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, "Usage: /slow <seconds> (0 to disable)"}

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
      param = "5:#{seconds}"
      {:ok, :ui_action, :set_mode, %{channel: channel, mode_string: "+j", params: [param]}}
    else
      {:error, _} = err -> err
      _ -> {:error, "Usage: /slow <seconds> — must be a positive number (0 to disable)"}
    end
  end

  @impl true
  def help do
    %{
      name: "slow",
      syntax: "/slow <seconds>",
      description:
        "Set join throttle on the channel (5 joins per N seconds). Use /slow 0 to disable.\nRequires: channel operator or owner.",
      examples: ["/slow 30", "/slow 0"]
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
      syntax: "/slow <seconds>",
      description: "Set join throttle. 0 to disable.",
      category: :channel,
      parameters: [
        %Parameter{
          name: "seconds",
          required: true,
          type: :text,
          position: 0,
          description: "Throttle interval in seconds (0 to disable)"
        }
      ],
      examples: ["/slow 30", "/slow 0"]
    }
  end

  defp require_channel(%{active_channel: nil}), do: {:error, "You are not in any channel"}
  defp require_channel(%{active_channel: ch}), do: {:ok, ch}

  defp require_operator(context, channel) do
    if channel in context.operator_in do
      :ok
    else
      {:error, "You must be a channel operator to use this command"}
    end
  end
end
