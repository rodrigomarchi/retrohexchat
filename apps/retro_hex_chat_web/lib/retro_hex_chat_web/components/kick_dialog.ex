defmodule RetroHexChatWeb.Components.KickDialog do
  @moduledoc """
  Windows 98-style kick notification dialog.
  Displays queued kick events one at a time. User must click OK to dismiss.
  """
  use Phoenix.Component

  alias RetroHexChatWeb.Icons

  attr :kick_queue, :list, default: []

  @spec kick_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def kick_dialog(assigns) do
    assigns =
      assigns
      |> assign(:current, List.first(assigns.kick_queue))
      |> assign_kick_message()

    ~H"""
    <div
      :if={@current}
      class="dialog-overlay"
      data-testid="kick-dialog"
    >
      <div class="window dialog-window--narrow">
        <div class="title-bar">
          <Icons.icon_dialog_kick class="title-bar-icon" />
          <div class="title-bar-text">Kicked</div>
        </div>
        <div class="window-body dialog-body--p16">
          <p>{@kick_message}</p>
          <div class="dialog-buttons dialog-buttons--center dialog-buttons--gap-8 u-mt-16">
            <button class="btn-icon" phx-click="kick_dialog_dismiss" data-testid="kick-dialog-ok">
              <Icons.icon_btn_ok class="btn-icon__svg" /> OK
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp assign_kick_message(%{current: nil} = assigns) do
    assign(assigns, :kick_message, "")
  end

  defp assign_kick_message(%{current: kick} = assigns) do
    assign(assigns, :kick_message, format_kick_message(kick))
  end

  @spec format_kick_message(map()) :: String.t()
  defp format_kick_message(%{channel: channel, operator: operator, reason: nil}) do
    "Você foi expulso de #{channel} por #{operator}"
  end

  defp format_kick_message(%{channel: channel, operator: operator, reason: ""}) do
    "Você foi expulso de #{channel} por #{operator}"
  end

  defp format_kick_message(%{channel: channel, operator: operator, reason: reason}) do
    "Você foi expulso de #{channel} por #{operator}: #{reason}"
  end
end
