defmodule RetroHexChatWeb.Components.ConnectionProgress do
  @moduledoc """
  Step-by-step connection progress indicator shown during initial connection.
  """
  use Phoenix.Component

  @steps [
    {1, "Resolving server..."},
    {2, "Connecting..."},
    {3, "Waiting for response..."}
  ]

  attr :step, :integer, default: 1
  attr :timeout, :boolean, default: false

  @spec connection_progress(map()) :: Phoenix.LiveView.Rendered.t()
  def connection_progress(assigns) do
    assigns = assign(assigns, :steps, @steps)

    ~H"""
    <div class="connection-progress" data-testid="connection-progress">
      <div :for={{num, label} <- @steps} class={step_class(num, @step)}>
        <span class="connection-progress__icon">{step_icon(num, @step)}</span>
        <span class="connection-progress__label">{label}</span>
      </div>
      <button :if={@timeout} class="connection-progress__retry" phx-click="retry_connection">
        Retry
      </button>
    </div>
    """
  end

  @spec step_class(integer(), integer()) :: String.t()
  defp step_class(num, current) when num < current,
    do: "connection-progress__step connection-progress__step--completed"

  defp step_class(num, current) when num == current,
    do: "connection-progress__step connection-progress__step--in-progress"

  defp step_class(_num, _current),
    do: "connection-progress__step connection-progress__step--pending"

  @spec step_icon(integer(), integer()) :: String.t()
  defp step_icon(num, current) when num < current, do: "✓"
  defp step_icon(num, current) when num == current, do: "⏳"
  defp step_icon(_num, _current), do: "○"
end
