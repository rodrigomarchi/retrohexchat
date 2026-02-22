defmodule RetroHexChatWeb.Components.TabBar do
  @moduledoc """
  Minimal tab bar showing only Status + the active conversation.
  Navigation between channels/PMs is handled by the conversations sidebar.
  """
  use Phoenix.Component

  alias RetroHexChatWeb.Icons

  attr :active_channel, :string, default: nil
  attr :active_pm, :string, default: nil
  attr :show_status_tab, :boolean, default: false
  attr :status_unread, :boolean, default: false

  @spec tab_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def tab_bar(assigns) do
    ~H"""
    <div class="tab-bar" data-testid="tab-bar">
      <div
        class={status_tab_class(@show_status_tab, @status_unread)}
        phx-click="switch_to_status"
        data-testid="tab-status"
      >
        <Icons.icon_tab_status class="tab-item-icon" />
        <span class="tab-label">Status</span>
      </div>
      <div
        :if={@active_channel}
        class={conversation_tab_class(@show_status_tab, [])}
        phx-click="switch_channel"
        phx-value-channel={@active_channel}
        data-testid={"tab-#{@active_channel}"}
      >
        <Icons.icon_tab_channel class="tab-item-icon" />
        <span class="tab-label">{@active_channel}</span>
        <button
          type="button"
          class="tab-close"
          phx-click="close_channel_tab"
          phx-value-channel={@active_channel}
          data-testid={"tab-close-#{@active_channel}"}
          title={"Close #{@active_channel}"}
        >
          ×
        </button>
      </div>
      <div
        :if={@active_pm}
        class={conversation_tab_class(@show_status_tab, ["tab-item--pm"])}
        phx-click="switch_pm"
        phx-value-nickname={@active_pm}
        data-testid={"tab-pm-#{@active_pm}"}
      >
        <Icons.icon_tab_pm class="tab-item-icon" />
        <span class="tab-label">{@active_pm}</span>
        <button
          type="button"
          class="tab-close"
          phx-click="close_pm_tab"
          phx-value-nickname={@active_pm}
          data-testid={"tab-close-pm-#{@active_pm}"}
          title={"Close #{@active_pm}"}
        >
          ×
        </button>
      </div>
    </div>
    """
  end

  @spec conversation_tab_class(boolean(), [String.t()]) :: String.t()
  defp conversation_tab_class(status_active, extras) do
    classes = ["tab-item" | extras]
    classes = if status_active, do: classes, else: ["tab-active" | classes]
    Enum.join(Enum.reverse(classes), " ")
  end

  @spec status_tab_class(boolean(), boolean()) :: String.t()
  defp status_tab_class(active, unread) do
    classes = ["tab-item", "tab-item--status"]
    classes = if active, do: ["tab-active" | classes], else: classes
    classes = if unread and not active, do: ["tab-unread" | classes], else: classes
    Enum.join(Enum.reverse(classes), " ")
  end
end
