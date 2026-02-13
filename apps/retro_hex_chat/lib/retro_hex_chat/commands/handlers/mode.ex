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
         :ok <- require_mode_privilege(context, channel, mode_string) do
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

  defp require_mode_privilege(context, channel, mode_string) do
    is_operator = channel in context.operator_in
    is_half_op = channel in Map.get(context, :half_operator_in, [])

    cond do
      is_operator ->
        :ok

      is_half_op ->
        # Half-ops can only set +v/-v
        flags = extract_flags(mode_string)

        if Enum.all?(flags, &(&1 == "v")) do
          :ok
        else
          {:error, "Insufficient privileges to set channel modes"}
        end

      true ->
        {:error, "You must be a channel operator to change modes"}
    end
  end

  defp extract_flags(mode_string) do
    case String.split(mode_string, "", trim: true) do
      ["+" | flags] -> flags
      ["-" | flags] -> flags
      _ -> []
    end
  end

  @impl true
  def category, do: :channel
end
