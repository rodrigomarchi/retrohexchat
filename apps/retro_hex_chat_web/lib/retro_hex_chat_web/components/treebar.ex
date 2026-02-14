defmodule RetroHexChatWeb.Components.Treebar do
  @moduledoc """
  Treebar component with Services/Channels/Private sections.
  Active channel highlighted, unread channels bold.
  """
  use Phoenix.Component

  attr :channels, :list, default: []
  attr :active_channel, :string, default: nil
  attr :unread_channels, :list, default: []
  attr :highlight_channels, :list, default: []
  attr :flash_channels, :list, default: []
  attr :pm_conversations, :list, default: []
  attr :active_pm, :string, default: nil

  @spec treebar(map()) :: Phoenix.LiveView.Rendered.t()
  def treebar(assigns) do
    ~H"""
    <div class="treebar" id="treebar" phx-hook="TreebarHook">
      <div
        :if={@channels == [] and @pm_conversations == []}
        class="empty-state treebar-empty-state"
        data-testid="treebar-empty-state"
      >
        <p>Nenhum canal — /join #canal para começar</p>
        <button type="button" class="empty-state-action" phx-click="open_channel_list">
          Explorar canais
        </button>
      </div>
      <ul :if={@channels != [] or @pm_conversations != []} class="tree-view">
        <li>
          <details open>
            <summary>Channels</summary>
            <ul>
              <li
                :for={channel <- @channels}
                class={
                  treebar_item_class(
                    channel,
                    @active_channel,
                    @unread_channels,
                    @highlight_channels,
                    @flash_channels
                  )
                }
                data-testid={"channel-#{channel}"}
                data-channel={channel}
                phx-click="switch_channel"
                phx-value-channel={channel}
                phx-dblclick="open_channel_central"
                phx-value-cc_channel={channel}
              >
                {channel}
              </li>
            </ul>
          </details>
        </li>
        <li>
          <details open>
            <summary>Private</summary>
            <ul>
              <li
                :for={pm <- @pm_conversations}
                class={pm_item_class(pm, @active_pm, @unread_channels, @flash_channels)}
                data-testid={"pm-#{pm}"}
                phx-click="switch_pm"
                phx-value-nickname={pm}
              >
                {pm}
              </li>
            </ul>
          </details>
        </li>
      </ul>
    </div>
    """
  end

  @spec treebar_item_class(
          String.t(),
          String.t() | nil,
          list(String.t()),
          list(String.t()),
          list(String.t())
        ) :: String.t()
  defp treebar_item_class(channel, active, unread, highlight, flash) do
    classes = []
    classes = if channel == active, do: ["tree-active" | classes], else: classes
    classes = if channel in unread, do: ["tree-unread" | classes], else: classes

    classes =
      if channel in highlight or channel in flash,
        do: ["tree-highlight" | classes],
        else: classes

    Enum.join(classes, " ")
  end

  @spec pm_item_class(String.t(), String.t() | nil, list(String.t()), list(String.t())) ::
          String.t()
  defp pm_item_class(pm, active_pm, unread, flash) do
    classes = []
    classes = if pm == active_pm, do: ["tree-active" | classes], else: classes
    classes = if "pm:#{pm}" in unread, do: ["tree-unread" | classes], else: classes
    classes = if "pm:#{pm}" in flash, do: ["tree-highlight" | classes], else: classes
    Enum.join(classes, " ")
  end
end
