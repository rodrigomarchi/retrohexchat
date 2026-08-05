defmodule RetroHexChatWeb.Components.UI.AdminChannelsDialog do
  @moduledoc """
  Admin Channels window — server-wide channel administration.

  Covers the channel registry (list, info, create), the destructive operations
  (delete, purge) and ChanServ registration admin (info, access lists, transfer
  founder, drop).

  Anything that destroys data asks for the channel name to be typed a second
  time into a confirm field. The server checks that too — the field is not a
  formality the client can skip.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.AdminShared
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog

  alias RetroHexChatWeb.Icons

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :target, :any, default: nil
  attr :text, :string, default: nil
  attr :table, :any, default: nil, doc: "%Admin.Table{} for the channel list"
  attr :banlist_text, :string, default: nil
  attr :result, :any, default: nil
  attr :search, :string, default: ""
  attr :info_channel, :string, default: ""
  attr :create_name, :string, default: ""
  attr :can_refresh, :boolean, default: false

  attr :action_channel, :string,
    default: "",
    doc: "Channel the destructive forms keep after an action they refused"

  attr :on_refresh, :any, default: nil
  attr :on_info, :any, default: nil
  attr :on_create, :any, default: nil
  attr :on_delete, :any, default: nil
  attr :on_purge, :any, default: nil
  attr :on_cs_info, :any, default: nil
  attr :on_cs_drop, :any, default: nil
  attr :on_cs_transfer, :any, default: nil
  attr :on_cs_access_list, :any, default: nil
  attr :on_cs_access_add, :any, default: nil
  attr :on_cs_access_del, :any, default: nil
  attr :on_cancel, :any, default: nil

  @doc """
  Framed variant with dialog chrome — used by the showcase page.

  The chat mounts `admin_channels_panel/1` inside a desktop window instead.
  """
  @spec admin_channels_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def admin_channels_dialog(assigns) do
    ~H"""
    <.dialog id={@id} show={@show} on_cancel={@on_cancel} class="max-w-3xl">
      <.dialog_header id={@id} title={dgettext("dialogs", "Channels")} on_close={@on_cancel}>
        <:icon><Icons.icon_channels class="w-[16px] h-[16px]" /></:icon>
      </.dialog_header>
      <.dialog_body>
        <.admin_channels_panel {assigns} />
      </.dialog_body>
    </.dialog>
    """
  end

  attr :id, :string, required: true
  attr :target, :any, default: nil
  attr :text, :string, default: nil
  attr :table, :any, default: nil, doc: "%Admin.Table{} for the channel list"
  attr :banlist_text, :string, default: nil
  attr :result, :any, default: nil
  attr :search, :string, default: ""
  attr :info_channel, :string, default: ""
  attr :create_name, :string, default: ""
  attr :can_refresh, :boolean, default: false

  attr :action_channel, :string,
    default: "",
    doc: "Channel the destructive forms keep after an action they refused"

  attr :on_refresh, :any, default: nil
  attr :on_info, :any, default: nil
  attr :on_create, :any, default: nil
  attr :on_delete, :any, default: nil
  attr :on_purge, :any, default: nil
  attr :on_cs_info, :any, default: nil
  attr :on_cs_drop, :any, default: nil
  attr :on_cs_transfer, :any, default: nil
  attr :on_cs_access_list, :any, default: nil
  attr :on_cs_access_add, :any, default: nil
  attr :on_cs_access_del, :any, default: nil

  @spec admin_channels_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def admin_channels_panel(assigns) do
    ~H"""
    <div
      id={"#{@id}-content"}
      data-testid="admin-channels-panel"
      class="adm-dialog flex h-full min-h-0 flex-col gap-retro-8"
    >
      <div class="adm-scroll min-h-0 flex-1 overflow-y-auto">
        <div class="space-y-retro-8">
          <form id="admin-channels-search-form" phx-submit={@on_refresh} phx-target={@target}>
            <div class="flex flex-wrap items-end gap-retro-6">
              <div class="flex-1 min-w-[160px]">
                <label for="admin-channels-search" class="block text-xs font-bold mb-retro-2">
                  {dgettext("dialogs", "Search")}
                </label>
                <input
                  id="admin-channels-search"
                  name="search"
                  type="text"
                  class="w-full shadow-retro-sunken bg-white px-retro-4 py-retro-2 text-sm"
                  value={@search}
                  autocomplete="off"
                  disabled={not @can_refresh}
                />
              </div>
              <.button type="submit" size="sm" variant="outline" disabled={not @can_refresh}>
                <:icon><Icons.icon_btn_refresh class="w-[14px] h-[14px]" /></:icon>
                {dgettext("dialogs", "Refresh")}
              </.button>
            </div>
          </form>

          <div
            id="admin-channels-output"
            class="shadow-retro-sunken bg-white min-h-[120px] max-h-[190px] overflow-y-auto retro-scrollbar"
          >
            <.admin_table
              table={@table}
              text={@text}
              testid="admin-channels-table"
              empty_title={dgettext("dialogs", "No active channels")}
            />
          </div>

          <div class="grid gap-retro-8 md:grid-cols-2">
            <form id="admin-channels-info-form" phx-submit={@on_info} phx-target={@target}>
              <div class="flex flex-wrap items-end gap-retro-6">
                <div class="flex-1 min-w-[140px]">
                  <label for="admin-channels-info-name" class="block text-xs font-bold mb-retro-2">
                    {dgettext("dialogs", "Channel")}
                  </label>
                  <input
                    id="admin-channels-info-name"
                    name="channel"
                    type="text"
                    class="w-full shadow-retro-sunken bg-white px-retro-4 py-retro-2 text-sm"
                    value={@info_channel}
                    autocomplete="off"
                    disabled={not @can_refresh}
                  />
                </div>
                <.button type="submit" size="sm" disabled={not @can_refresh}>
                  <:icon><Icons.icon_btn_info class="w-[14px] h-[14px]" /></:icon>
                  {dgettext("dialogs", "Info")}
                </.button>
              </div>
            </form>

            <form id="admin-channels-create-form" phx-submit={@on_create} phx-target={@target}>
              <div class="flex flex-wrap items-end gap-retro-6">
                <div class="flex-1 min-w-[140px]">
                  <label for="admin-channels-create-name" class="block text-xs font-bold mb-retro-2">
                    {dgettext("dialogs", "New channel")}
                  </label>
                  <input
                    id="admin-channels-create-name"
                    name="channel"
                    type="text"
                    class="w-full shadow-retro-sunken bg-white px-retro-4 py-retro-2 text-sm"
                    value={@create_name}
                    autocomplete="off"
                    disabled={not @can_refresh}
                  />
                </div>
                <.button type="submit" size="sm" disabled={not @can_refresh}>
                  <:icon><Icons.icon_btn_add class="w-[14px] h-[14px]" /></:icon>
                  {dgettext("dialogs", "Create")}
                </.button>
              </div>
            </form>
          </div>

          <div>
            <div class="text-xs font-bold mb-retro-4">
              {dgettext("dialogs", "Destructive actions")}
            </div>
            <div class="grid gap-retro-6 md:grid-cols-2">
              <.channel_action_form
                target={@target}
                id="admin-channels-delete-form"
                channel_value={@action_channel}
                event={@on_delete}
                title={dgettext("dialogs", "Delete channel")}
                button_label={dgettext("dialogs", "Confirm delete")}
                icon_fn={:icon_trash}
                include_confirm
                destructive
                disabled={not @can_refresh}
              />
              <.channel_action_form
                target={@target}
                id="admin-channels-purge-form"
                channel_value={@action_channel}
                event={@on_purge}
                title={dgettext("dialogs", "Purge messages")}
                button_label={dgettext("dialogs", "Confirm purge")}
                icon_fn={:icon_warning}
                include_from
                include_confirm
                destructive
                disabled={not @can_refresh}
              />
            </div>
          </div>

          <div>
            <div class="text-xs font-bold mb-retro-4">{dgettext("dialogs", "ChanServ admin")}</div>
            <div class="grid gap-retro-6 md:grid-cols-3">
              <.channel_action_form
                target={@target}
                id="admin-channels-cs-info-form"
                event={@on_cs_info}
                title={dgettext("dialogs", "ChanServ info")}
                button_label={dgettext("dialogs", "ChanServ info")}
                icon_fn={:icon_btn_info}
                disabled={not @can_refresh}
              />
              <.channel_action_form
                target={@target}
                id="admin-channels-cs-access-list-form"
                event={@on_cs_access_list}
                title={dgettext("dialogs", "Access list")}
                button_label={dgettext("dialogs", "Access list")}
                icon_fn={:icon_tab_registration}
                disabled={not @can_refresh}
              />
              <.channel_action_form
                target={@target}
                id="admin-channels-cs-transfer-form"
                event={@on_cs_transfer}
                title={dgettext("dialogs", "Transfer founder")}
                button_label={dgettext("dialogs", "Transfer founder")}
                icon_fn={:icon_shield}
                include_nick
                disabled={not @can_refresh}
              />
              <.channel_action_form
                target={@target}
                id="admin-channels-cs-access-add-form"
                event={@on_cs_access_add}
                title={dgettext("dialogs", "Add access")}
                button_label={dgettext("dialogs", "Add access")}
                icon_fn={:icon_btn_add}
                include_nick
                include_level
                disabled={not @can_refresh}
              />
              <.channel_action_form
                target={@target}
                id="admin-channels-cs-access-del-form"
                event={@on_cs_access_del}
                title={dgettext("dialogs", "Remove access")}
                button_label={dgettext("dialogs", "Remove access")}
                icon_fn={:icon_checkmark}
                include_nick
                include_level
                disabled={not @can_refresh}
              />
              <.channel_action_form
                target={@target}
                id="admin-channels-cs-drop-form"
                event={@on_cs_drop}
                title={dgettext("dialogs", "Drop registration")}
                button_label={dgettext("dialogs", "Drop registration")}
                icon_fn={:icon_trash}
                include_confirm
                destructive
                disabled={not @can_refresh}
              />
            </div>
          </div>

          <div>
            <div class="text-xs font-bold mb-retro-4">{dgettext("dialogs", "Ban list")}</div>
            <pre
              id="admin-channels-banlist"
              class="shadow-retro-sunken bg-white min-h-[84px] max-h-[150px] overflow-y-auto p-retro-8 text-xs whitespace-pre-wrap"
            ><%= @banlist_text || "" %></pre>
          </div>

          <.inline_result result={@result} />
        </div>
      </div>
    </div>
    """
  end

  # One channel plus whatever else the action needs — the shape every
  # destructive and ChanServ action in this window takes.
  attr :id, :string, required: true
  attr :event, :any, default: nil
  attr :title, :string, required: true
  attr :button_label, :string, required: true
  attr :icon_fn, :atom, required: true
  attr :include_nick, :boolean, default: false
  attr :include_from, :boolean, default: false
  attr :include_level, :boolean, default: false
  attr :include_confirm, :boolean, default: false
  attr :destructive, :boolean, default: false
  attr :disabled, :boolean, default: false

  attr :channel_value, :string,
    default: "",
    doc: """
    What the channel field should hold.

    A destructive action refused for a bad confirmation re-renders the window,
    and an uncontrolled input loses whatever was typed in that patch — leaving
    the admin to retype the channel name to correct a typo in the confirmation.
    """

  attr :target, :any, default: nil

  defp channel_action_form(assigns) do
    ~H"""
    <form
      id={@id}
      phx-submit={@event}
      phx-target={@target}
      class="shadow-retro-sunken bg-white p-retro-6 space-y-retro-4"
    >
      <div class={["text-xs font-bold", if(@destructive, do: "text-destructive")]}>
        {@title}
      </div>
      <input
        name="channel"
        type="text"
        class="w-full shadow-retro-sunken bg-white px-retro-4 py-retro-2 text-sm"
        placeholder={dgettext("dialogs", "Channel")}
        autocomplete="off"
        value={@channel_value}
        disabled={@disabled}
      />
      <input
        :if={@include_nick}
        name="nick"
        type="text"
        class="w-full shadow-retro-sunken bg-white px-retro-4 py-retro-2 text-sm"
        placeholder={dgettext("dialogs", "Nick")}
        autocomplete="off"
        disabled={@disabled}
      />
      <input
        :if={@include_from}
        name="from"
        type="text"
        class="w-full shadow-retro-sunken bg-white px-retro-4 py-retro-2 text-sm"
        placeholder={dgettext("dialogs", "From nick")}
        autocomplete="off"
        disabled={@disabled}
      />
      <select
        :if={@include_level}
        name="level"
        class="w-full shadow-retro-sunken bg-white px-retro-4 py-retro-2 text-sm"
        disabled={@disabled}
      >
        <option value="sop">{dgettext("dialogs", "sop")}</option>
        <option value="aop">{dgettext("dialogs", "aop")}</option>
        <option value="vop">{dgettext("dialogs", "vop")}</option>
      </select>
      <input
        :if={@include_confirm}
        name="confirm"
        type="text"
        class="w-full shadow-retro-sunken bg-white px-retro-4 py-retro-2 text-sm"
        placeholder={dgettext("dialogs", "Type channel name to confirm")}
        autocomplete="off"
        disabled={@disabled}
      />
      <div class="flex justify-end">
        <.button
          type="submit"
          size="sm"
          variant={if(@destructive, do: "destructive", else: "default")}
          disabled={@disabled}
        >
          <:icon>{apply(Icons, @icon_fn, [%{class: "w-[14px] h-[14px]"}])}</:icon>
          {@button_label}
        </.button>
      </div>
    </form>
    """
  end
end
