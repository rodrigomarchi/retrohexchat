defmodule RetroHexChat.Commands.Handlers.Mode do
  @moduledoc "Handler for /mode <+/-flags> [params]"
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:error, "Usage: /mode <+/-flags> [params]"}
  end

  def execute([mode_string | params], context) do
    with {:ok, channel} <- require_channel(context),
         :ok <- require_operator(context, channel) do
      {:ok, :ui_action, :set_mode, %{channel: channel, mode_string: mode_string, params: params}}
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
      name: "mode",
      syntax: "/mode <+/-flags> [params]",
      description: "Set or unset channel modes. Requires operator privilege.",
      examples: ["/mode +m", "/mode +k secret", "/mode -t", "/mode +o nickname"]
    }
  end

  defp require_channel(%{active_channel: nil}), do: {:error, "You are not in any channel"}
  defp require_channel(%{active_channel: channel}), do: {:ok, channel}

  defp require_operator(%{operator_in: operator_in}, channel) do
    if channel in operator_in do
      :ok
    else
      {:error, "You must be a channel operator to change modes"}
    end
  end
end
