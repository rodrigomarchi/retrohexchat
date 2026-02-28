defmodule RetroHexChatWeb.Components.UI.ChannelCentralDialog do
  @moduledoc """
  Win98-style Channel Central dialog component for the showcase design system.

  Provides a 5-tab dialog for viewing and managing channel properties:
  General (topic, info), Modes (moderated, invite-only, etc.),
  Bans, Ban Exceptions, and Invite Exceptions.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Tabs
  import RetroHexChatWeb.Components.UI.Table
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Checkbox
  import RetroHexChatWeb.Components.UI.Separator

  alias RetroHexChatWeb.Icons

  @doc """
  Renders a Win98-style Channel Central dialog with 5 tabs.

  ## Examples

      <.channel_central_dialog
        id="channel-central"
        show={true}
        channel_name="#lobby"
        topic="Welcome to the lobby!"
        operator={true}
      />
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :active_tab, :string, default: "general"
  attr :channel_name, :string, default: nil
  attr :topic, :string, default: ""
  attr :topic_set_by, :string, default: nil
  attr :topic_set_at, :string, default: nil
  attr :created_at, :string, default: nil
  attr :member_count, :integer, default: 0
  attr :operator, :boolean, default: false
  attr :modes, :map, default: %{}
  attr :bans, :list, default: []
  attr :ban_exceptions, :list, default: []
  attr :invite_exceptions, :list, default: []
  attr :ban_selected, :string, default: nil
  attr :ban_ex_selected, :string, default: nil
  attr :invite_ex_selected, :string, default: nil
  attr :on_topic_save, :any, default: nil
  attr :on_mode_apply, :any, default: nil
  attr :on_ban_add, :any, default: nil
  attr :on_ban_remove, :any, default: nil
  attr :on_ban_ex_add, :any, default: nil
  attr :on_ban_ex_remove, :any, default: nil
  attr :on_invite_ex_add, :any, default: nil
  attr :on_invite_ex_remove, :any, default: nil
  attr :on_close, :any, default: nil

  @spec channel_central_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def channel_central_dialog(assigns) do
    modes = Map.merge(default_modes(), assigns.modes)
    assigns = assign(assigns, :modes, modes)

    ~H"""
    <.dialog id={@id} show={@show} class="max-w-xl">
      <.dialog_header id={@id} title={"Channel Central: #{display_channel(@channel_name)}"}>
        <:icon><Icons.icon_dialog_channel_central /></:icon>
      </.dialog_header>
      <.dialog_body>
        <.tabs :let={builder} id={"#{@id}-tabs"} default={@active_tab}>
          <.tabs_list class="flex flex-wrap">
            <.tabs_trigger builder={builder} value="general">
              <:icon><Icons.icon_tab_general class="w-4 h-4" /></:icon>
              General
            </.tabs_trigger>
            <.tabs_trigger builder={builder} value="modes">
              <:icon><Icons.icon_tab_modes class="w-4 h-4" /></:icon>
              Modes
            </.tabs_trigger>
            <.tabs_trigger builder={builder} value="bans">
              <:icon><Icons.icon_tab_bans class="w-4 h-4" /></:icon>
              Bans
            </.tabs_trigger>
            <.tabs_trigger builder={builder} value="ban_exceptions">
              <:icon><Icons.icon_tab_exceptions class="w-4 h-4" /></:icon>
              Ban Exc.
            </.tabs_trigger>
            <.tabs_trigger builder={builder} value="invite_exceptions">
              <:icon><Icons.icon_tab_exceptions class="w-4 h-4" /></:icon>
              Invite Exc.
            </.tabs_trigger>
          </.tabs_list>

          <.tabs_content value="general">
            <.general_tab
              channel_name={@channel_name}
              topic={@topic}
              topic_set_by={@topic_set_by}
              topic_set_at={@topic_set_at}
              created_at={@created_at}
              member_count={@member_count}
              operator={@operator}
              on_topic_save={@on_topic_save}
            />
          </.tabs_content>

          <.tabs_content value="modes">
            <.modes_tab
              modes={@modes}
              operator={@operator}
              on_mode_apply={@on_mode_apply}
            />
          </.tabs_content>

          <.tabs_content value="bans">
            <.list_tab
              entries={@bans}
              selected={@ban_selected}
              operator={@operator}
              on_add={@on_ban_add}
              on_remove={@on_ban_remove}
              empty_label="No bans set on this channel."
              select_param="mask"
            />
          </.tabs_content>

          <.tabs_content value="ban_exceptions">
            <.list_tab
              entries={@ban_exceptions}
              selected={@ban_ex_selected}
              operator={@operator}
              on_add={@on_ban_ex_add}
              on_remove={@on_ban_ex_remove}
              empty_label="No ban exceptions set."
              select_param="mask"
            />
          </.tabs_content>

          <.tabs_content value="invite_exceptions">
            <.list_tab
              entries={@invite_exceptions}
              selected={@invite_ex_selected}
              operator={@operator}
              on_add={@on_invite_ex_add}
              on_remove={@on_invite_ex_remove}
              empty_label="No invite exceptions set."
              select_param="mask"
            />
          </.tabs_content>
        </.tabs>
      </.dialog_body>
      <.dialog_footer>
        <.button variant="outline" phx-click={@on_close || hide_modal(@id)}>
          <:icon><Icons.icon_close /></:icon>
          Close
        </.button>
      </.dialog_footer>
    </.dialog>
    """
  end

  # ── General Tab ───────────────────────────────────────

  attr :channel_name, :string, default: nil
  attr :topic, :string, default: ""
  attr :topic_set_by, :string, default: nil
  attr :topic_set_at, :string, default: nil
  attr :created_at, :string, default: nil
  attr :member_count, :integer, default: 0
  attr :operator, :boolean, default: false
  attr :on_topic_save, :any, default: nil

  defp general_tab(assigns) do
    ~H"""
    <div class="space-y-2">
      <div class="shadow-retro-field bg-white p-2">
        <div class="flex items-center gap-2 mb-2">
          <Icons.icon_tab_channel class="w-[16px] h-[16px]" />
          <span class="text-sm font-bold">{display_channel(@channel_name)}</span>
        </div>
        <div class="grid grid-cols-2 gap-1 text-xs">
          <span class="text-muted-foreground">Created:</span>
          <span>{@created_at || "Unknown"}</span>
          <span class="text-muted-foreground">Members:</span>
          <span>{@member_count}</span>
        </div>
      </div>

      <.separator />

      <div>
        <label class="text-xs font-bold block mb-1">Topic:</label>
        <.input
          type="text"
          name="topic"
          value={@topic}
          placeholder="No topic set"
          disabled={!@operator}
          class="text-xs h-8"
        />
        <div :if={@topic_set_by} class="text-[10px] text-muted-foreground mt-1">
          Set by {@topic_set_by}
          <span :if={@topic_set_at}>on {@topic_set_at}</span>
        </div>
      </div>

      <.button :if={@operator} size="sm" phx-click={@on_topic_save}>
        <:icon><Icons.icon_btn_set_topic /></:icon>
        Save Topic
      </.button>

      <p :if={!@operator} class="text-[10px] text-muted-foreground italic">
        You must be a channel operator to edit the topic.
      </p>
    </div>
    """
  end

  # ── Modes Tab ─────────────────────────────────────────

  attr :modes, :map, required: true
  attr :operator, :boolean, default: false
  attr :on_mode_apply, :any, default: nil

  defp modes_tab(assigns) do
    ~H"""
    <div class="space-y-2">
      <div class="shadow-retro-field bg-white p-2">
        <p class="text-xs font-bold mb-2">Channel Modes:</p>

        <div class="space-y-1">
          <label class={
            classes([
              "inline-flex items-center gap-2 text-xs",
              if(@operator, do: "cursor-pointer", else: "opacity-50 pointer-events-none")
            ])
          }>
            <.checkbox
              name="mode_moderated"
              value={@modes[:moderated] || false}
            /> Moderated (+m)
          </label>
        </div>
        <div class="space-y-1 mt-1">
          <label class={
            classes([
              "inline-flex items-center gap-2 text-xs",
              if(@operator, do: "cursor-pointer", else: "opacity-50 pointer-events-none")
            ])
          }>
            <.checkbox
              name="mode_invite_only"
              value={@modes[:invite_only] || false}
            /> Invite Only (+i)
          </label>
        </div>
        <div class="space-y-1 mt-1">
          <label class={
            classes([
              "inline-flex items-center gap-2 text-xs",
              if(@operator, do: "cursor-pointer", else: "opacity-50 pointer-events-none")
            ])
          }>
            <.checkbox
              name="mode_topic_lock"
              value={@modes[:topic_lock] || false}
            /> Topic Lock (+t)
          </label>
        </div>
      </div>

      <div class="grid grid-cols-2 gap-2">
        <div>
          <label class="text-xs font-bold block mb-1">Channel Key (+k):</label>
          <.input
            type="text"
            name="mode_key"
            value={@modes[:key]}
            placeholder="No key set"
            disabled={!@operator}
            class="text-xs h-8"
          />
        </div>
        <div>
          <label class="text-xs font-bold block mb-1">User Limit (+l):</label>
          <.input
            type="number"
            name="mode_limit"
            value={@modes[:limit]}
            placeholder="No limit"
            disabled={!@operator}
            class="text-xs h-8"
          />
        </div>
      </div>

      <.button :if={@operator} size="sm" phx-click={@on_mode_apply}>
        <:icon><Icons.icon_btn_apply /></:icon>
        Apply Modes
      </.button>

      <p :if={!@operator} class="text-[10px] text-muted-foreground italic">
        You must be a channel operator to change modes.
      </p>
    </div>
    """
  end

  # ── List Tab (Bans / Ban Exceptions / Invite Exceptions) ──

  attr :entries, :list, required: true
  attr :selected, :string, default: nil
  attr :operator, :boolean, default: false
  attr :on_add, :any, default: nil
  attr :on_remove, :any, default: nil
  attr :empty_label, :string, default: "No entries."
  attr :select_param, :string, default: "mask"

  defp list_tab(assigns) do
    has_selection = assigns.selected != nil
    assigns = assign(assigns, :has_selection, has_selection)

    ~H"""
    <div class="overflow-y-auto max-h-[180px] shadow-retro-field bg-white mb-2">
      <.table>
        <.table_header>
          <.table_row>
            <.table_head class="text-xs px-2 py-1">Mask</.table_head>
            <.table_head class="w-[80px] text-xs px-2 py-1">Set By</.table_head>
            <.table_head class="w-[100px] text-xs px-2 py-1">Set At</.table_head>
          </.table_row>
        </.table_header>
        <.table_body>
          <.table_row
            :for={entry <- @entries}
            class={
              classes(["cursor-pointer text-xs", @selected == entry.mask && "bg-primary text-white"])
            }
            phx-click={@on_add && "select_entry"}
            phx-value-mask={entry.mask}
          >
            <.table_cell class="px-2 py-1 text-xs font-mono">{entry.mask}</.table_cell>
            <.table_cell class="px-2 py-1 text-xs">{entry.set_by}</.table_cell>
            <.table_cell class="px-2 py-1 text-xs">{entry.set_at}</.table_cell>
          </.table_row>
          <tr :if={@entries == []}>
            <td colspan="3" class="px-2 py-4 text-xs text-center text-muted-foreground">
              {@empty_label}
            </td>
          </tr>
        </.table_body>
      </.table>
    </div>

    <div :if={@operator} class="flex gap-1">
      <.button size="sm" phx-click={@on_add}>
        <:icon><Icons.icon_btn_add /></:icon>
        Add
      </.button>
      <.button size="sm" variant="destructive" phx-click={@on_remove} disabled={!@has_selection}>
        <:icon><Icons.icon_btn_remove /></:icon>
        Remove
      </.button>
    </div>

    <p :if={!@operator} class="text-[10px] text-muted-foreground italic">
      You must be a channel operator to manage this list.
    </p>
    """
  end

  # ── Private Helpers ───────────────────────────────────

  @spec default_modes() :: map()
  defp default_modes do
    %{moderated: false, invite_only: false, topic_lock: false, key: nil, limit: nil}
  end

  @spec display_channel(String.t() | nil) :: String.t()
  defp display_channel(nil), do: "#unknown"
  defp display_channel(name), do: name
end
