defmodule RetroHexChatWeb.Components.UI.System.AppInfoPanel do
  @moduledoc """
  The product's own numbers: who is here and what they are doing.

  Every other runtime window would read the same for any Elixir program. This
  is the one that knows what this program is for — so it leads with occupancy
  and follows with the channels that occupancy is spread across.

  The per-channel listing is ordered by population rather than alphabetically:
  a monitor is looking for where everyone is, and an empty channel named `#ai`
  should not outrank a busy one named `#retro`.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.RetroTable
  import RetroHexChatWeb.Components.UI.MediaSession.SummaryCard

  alias RetroHexChatWeb.Components.UI.Format
  alias RetroHexChatWeb.Icons

  attr :id, :string, required: true
  attr :instance, :any, required: true, doc: "%SystemInfo.Instance{}"
  attr :table, :any, default: nil, doc: "%Table{} of per-channel occupancy"
  attr :target, :any, default: nil
  attr :on_refresh, :string, required: true
  attr :testid, :string, default: "system-app-info"

  @spec app_info_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def app_info_panel(assigns) do
    ~H"""
    <div
      id={"#{@id}-app-info"}
      class="adm-dialog flex h-full min-h-0 flex-col gap-retro-8"
      data-testid={@testid}
    >
      <h3 class="flex min-w-0 shrink-0 items-center gap-1 text-xs font-bold">
        <Icons.icon_hex_stone class="h-4 w-4 shrink-0" />
        <span class="min-w-0 flex-1 truncate">{dgettext("dialogs", "Application")}</span>
        <button
          type="button"
          class="shrink-0 p-retro-2 hover:bg-hover-bg"
          phx-click={@on_refresh}
          phx-target={@target}
          aria-label={dgettext("dialogs", "Refresh")}
          data-testid="system-app-info-refresh"
        >
          <Icons.icon_btn_refresh class="h-[14px] w-[14px]" />
        </button>
      </h3>

      <section class="grid shrink-0 grid-cols-2 gap-retro-6 sm:grid-cols-3">
        <.summary_card
          variant={:prominent}
          icon={:icon_channels}
          label={dgettext("dialogs", "Channels")}
          value={Format.number(@instance.channel_count)}
          detail={dgettext("dialogs", "live channel processes")}
          testid="system-app-info-channels"
        />
        <.summary_card
          variant={:prominent}
          icon={:icon_community}
          label={dgettext("dialogs", "People")}
          value={Format.number(@instance.user_count)}
          detail={dgettext("dialogs", "distinct nicknames present")}
          testid="system-app-info-users"
        />
        <.summary_card
          variant={:prominent}
          icon={:icon_toolbar_conference}
          label={dgettext("dialogs", "Calls")}
          value={Format.number(@instance.group_call_rooms)}
          detail={
            dgettext("dialogs", "%{peers} participants",
              peers: Format.number(@instance.group_call_peers)
            )
          }
          testid="system-app-info-calls"
        />
      </section>

      <section class="grid shrink-0 grid-cols-2 gap-retro-6 sm:grid-cols-3">
        <.summary_card
          variant={:prominent}
          icon={:icon_joystick}
          label={dgettext("dialogs", "Virtual spaces")}
          value={Format.number(@instance.virtual_spaces)}
          testid="system-app-info-spaces"
        />
      </section>

      <h4 class="flex min-w-0 shrink-0 items-center gap-1 text-xs font-bold">
        <Icons.icon_channels class="h-4 w-4 shrink-0" />
        <span class="truncate">{dgettext("dialogs", "Occupancy by channel")}</span>
      </h4>

      <div class="retro-scrollbar min-h-0 flex-1 overflow-auto bg-white shadow-retro-sunken">
        <.retro_table
          id={"#{@testid}-table"}
          table={@table}
          testid={"#{@testid}-table"}
          truncate
          empty_title={dgettext("dialogs", "No channels are live right now")}
        />
      </div>
    </div>
    """
  end
end
