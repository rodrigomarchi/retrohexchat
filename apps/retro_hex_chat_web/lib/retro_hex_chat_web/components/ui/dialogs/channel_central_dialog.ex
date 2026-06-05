defmodule RetroHexChatWeb.Components.UI.ChannelCentralDialog do
  @moduledoc """
  Win98-style Channel Central dialog component for the showcase design system.

  Provides a 5-tab dialog for viewing and managing channel properties:
  General (topic, info), Modes (moderated, invite-only, etc.),
  Bans, Ban Exceptions, and Invite Exceptions.

  Matches v1 event contracts: tab switching via `on_tab`, topic save via
  `phx-submit`, modes via `phx-submit`, ban selection via per-list callbacks.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Tabs
  import RetroHexChatWeb.Components.UI.Table
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Separator
  import RetroHexChatWeb.Components.UI.Textarea

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
        on_tab="channel_central_tab"
        on_ban_select="cc_ban_select"
        on_ban_ex_select="cc_ban_ex_select"
        on_invite_ex_select="cc_invite_ex_select"
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
  attr :owner, :boolean, default: false
  attr :welcome_message, :string, default: ""
  attr :throttle_seconds, :integer, default: 0
  attr :notice, :string, default: nil
  attr :transfer_error, :string, default: nil
  attr :registration, :map, default: nil
  attr :access_tab, :string, default: "sop"
  attr :access_selected, :string, default: nil
  attr :access_nick, :string, default: ""
  attr :cs_error, :string, default: nil
  attr :cs_confirm_drop, :boolean, default: false
  attr :identified, :boolean, default: false
  attr :modes, :map, default: %{}
  attr :bans, :list, default: []
  attr :ban_exceptions, :list, default: []
  attr :invite_exceptions, :list, default: []
  attr :ban_selected, :string, default: nil
  attr :ban_ex_selected, :string, default: nil
  attr :invite_ex_selected, :string, default: nil
  attr :on_tab, :any, default: nil, doc: "Tab switch event (phx-value-tab=value)"
  attr :on_topic_save, :any, default: nil
  attr :on_welcome_save, :any, default: nil
  attr :on_welcome_clear, :any, default: nil
  attr :on_throttle_apply, :any, default: nil
  attr :on_transfer_open, :any, default: nil
  attr :on_transfer_close, :any, default: nil
  attr :on_transfer_submit, :any, default: nil
  attr :on_mode_apply, :any, default: nil
  attr :on_ban_add, :any, default: nil
  attr :on_ban_remove, :any, default: nil
  attr :on_ban_select, :any, default: nil, doc: "Ban row select event (phx-value-nickname)"
  attr :on_ban_ex_add, :any, default: nil
  attr :on_ban_ex_remove, :any, default: nil
  attr :on_ban_ex_select, :any, default: nil, doc: "Ban exception row select event"
  attr :on_invite_ex_add, :any, default: nil
  attr :on_invite_ex_remove, :any, default: nil
  attr :on_invite_ex_select, :any, default: nil, doc: "Invite exception row select event"
  attr :on_cs_register, :any, default: nil
  attr :on_cs_drop_request, :any, default: nil
  attr :on_cs_drop, :any, default: nil
  attr :on_cs_drop_cancel, :any, default: nil
  attr :on_cs_access_tab, :any, default: nil
  attr :on_cs_access_change, :any, default: nil
  attr :on_cs_access_add, :any, default: nil
  attr :on_cs_access_select, :any, default: nil
  attr :on_cs_access_remove, :any, default: nil
  attr :show_add_ban_dialog, :boolean, default: false
  attr :show_add_ban_ex_dialog, :boolean, default: false
  attr :show_add_invite_ex_dialog, :boolean, default: false
  attr :show_transfer_dialog, :boolean, default: false
  attr :on_close, :any, default: nil

  @spec channel_central_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def channel_central_dialog(assigns) do
    modes = Map.merge(default_modes(), assigns.modes)
    assigns = assign(assigns, :modes, modes)

    ~H"""
    <.dialog
      id={@id}
      show={@show}
      class="max-w-xl"
      lock={
        @show_add_ban_dialog || @show_add_ban_ex_dialog || @show_add_invite_ex_dialog ||
          @show_transfer_dialog
      }
      on_cancel={@on_close}
    >
      <.dialog_header
        id={@id}
        title={
          dgettext("dialogs", "Channel Central: %{channel}", channel: display_channel(@channel_name))
        }
        on_close={@on_close}
      >
        <:icon><Icons.icon_dialog_channel_central /></:icon>
      </.dialog_header>
      <.dialog_body>
        <.tabs :let={builder} id={"#{@id}-tabs"} default={@active_tab}>
          <.tabs_list class="flex flex-wrap">
            <.tabs_trigger
              builder={builder}
              value="general"
              phx-click={@on_tab}
              phx-value-tab="general"
            >
              <:icon><Icons.icon_tab_general class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "General")}
            </.tabs_trigger>
            <.tabs_trigger
              builder={builder}
              value="modes"
              phx-click={@on_tab}
              phx-value-tab="modes"
            >
              <:icon><Icons.icon_tab_modes class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Modes")}
            </.tabs_trigger>
            <.tabs_trigger
              builder={builder}
              value="bans"
              phx-click={@on_tab}
              phx-value-tab="bans"
            >
              <:icon><Icons.icon_tab_bans class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Bans")}
            </.tabs_trigger>
            <.tabs_trigger
              builder={builder}
              value="ban_exceptions"
              phx-click={@on_tab}
              phx-value-tab="ban_exceptions"
            >
              <:icon><Icons.icon_tab_exceptions class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Ban Exc.")}
            </.tabs_trigger>
            <.tabs_trigger
              builder={builder}
              value="invite_exceptions"
              phx-click={@on_tab}
              phx-value-tab="invite_exceptions"
            >
              <:icon><Icons.icon_tab_exceptions class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Invite Exc.")}
            </.tabs_trigger>
            <.tabs_trigger
              builder={builder}
              value="registration"
              phx-click={@on_tab}
              phx-value-tab="registration"
            >
              <:icon><Icons.icon_tab_registration class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Registration")}
            </.tabs_trigger>
          </.tabs_list>

          <.tabs_content value="general" builder={builder}>
            <.general_tab
              channel_name={@channel_name}
              topic={@topic}
              topic_set_by={@topic_set_by}
              topic_set_at={@topic_set_at}
              created_at={@created_at}
              member_count={@member_count}
              operator={@operator}
              owner={@owner}
              welcome_message={@welcome_message}
              throttle_seconds={@throttle_seconds}
              notice={@notice}
              on_topic_save={@on_topic_save}
              on_welcome_save={@on_welcome_save}
              on_welcome_clear={@on_welcome_clear}
              on_throttle_apply={@on_throttle_apply}
              on_transfer_open={@on_transfer_open}
            />
          </.tabs_content>

          <.tabs_content value="modes" builder={builder}>
            <.modes_tab
              modes={@modes}
              operator={@operator}
              on_mode_apply={@on_mode_apply}
            />
          </.tabs_content>

          <.tabs_content value="bans" builder={builder}>
            <.list_tab
              entries={@bans}
              selected={@ban_selected}
              operator={@operator}
              on_add={@on_ban_add}
              on_remove={@on_ban_remove}
              on_select={@on_ban_select}
              empty_label={dgettext("dialogs", "No bans set on this channel.")}
            />
          </.tabs_content>

          <.tabs_content value="ban_exceptions" builder={builder}>
            <.list_tab
              entries={@ban_exceptions}
              selected={@ban_ex_selected}
              operator={@operator}
              on_add={@on_ban_ex_add}
              on_remove={@on_ban_ex_remove}
              on_select={@on_ban_ex_select}
              empty_label={dgettext("dialogs", "No ban exceptions set.")}
            />
          </.tabs_content>

          <.tabs_content value="invite_exceptions" builder={builder}>
            <.list_tab
              entries={@invite_exceptions}
              selected={@invite_ex_selected}
              operator={@operator}
              on_add={@on_invite_ex_add}
              on_remove={@on_invite_ex_remove}
              on_select={@on_invite_ex_select}
              empty_label={dgettext("dialogs", "No invite exceptions set.")}
            />
          </.tabs_content>

          <.tabs_content value="registration" builder={builder}>
            <.registration_tab
              channel_name={@channel_name}
              operator={@operator}
              identified={@identified}
              registration={@registration}
              access_tab={@access_tab}
              access_selected={@access_selected}
              access_nick={@access_nick}
              error_message={@cs_error}
              confirm_drop={@cs_confirm_drop}
              on_register={@on_cs_register}
              on_drop_request={@on_cs_drop_request}
              on_drop={@on_cs_drop}
              on_drop_cancel={@on_cs_drop_cancel}
              on_access_tab={@on_cs_access_tab}
              on_access_change={@on_cs_access_change}
              on_access_add={@on_cs_access_add}
              on_access_select={@on_cs_access_select}
              on_access_remove={@on_cs_access_remove}
            />
          </.tabs_content>
        </.tabs>
      </.dialog_body>
      <.dialog_footer>
        <.button variant="outline" phx-click={@on_close || hide_modal(@id)}>
          <:icon><Icons.icon_close /></:icon>
          {dgettext("dialogs", "Close")}
        </.button>
      </.dialog_footer>
    </.dialog>

    <%!-- Ban Add Sub-Dialog --%>
    <.ban_add_sub_form :if={@show_add_ban_dialog} />
    <%!-- Ban Exception Add Sub-Dialog --%>
    <.ban_ex_add_sub_form :if={@show_add_ban_ex_dialog} />
    <%!-- Invite Exception Add Sub-Dialog --%>
    <.invite_ex_add_sub_form :if={@show_add_invite_ex_dialog} />
    <%!-- Ownership Transfer Sub-Dialog --%>
    <.transfer_confirm_sub_form
      :if={@show_transfer_dialog}
      channel_name={@channel_name}
      error_message={@transfer_error}
      on_close={@on_transfer_close}
      on_submit={@on_transfer_submit}
    />
    """
  end

  # ── Registration Tab ───────────────────────────────────

  attr :channel_name, :string, default: nil
  attr :operator, :boolean, default: false
  attr :identified, :boolean, default: false
  attr :registration, :map, default: nil
  attr :access_tab, :string, default: "sop"
  attr :access_selected, :string, default: nil
  attr :access_nick, :string, default: ""
  attr :error_message, :string, default: nil
  attr :confirm_drop, :boolean, default: false
  attr :on_register, :any, default: nil
  attr :on_drop_request, :any, default: nil
  attr :on_drop, :any, default: nil
  attr :on_drop_cancel, :any, default: nil
  attr :on_access_tab, :any, default: nil
  attr :on_access_change, :any, default: nil
  attr :on_access_add, :any, default: nil
  attr :on_access_select, :any, default: nil
  attr :on_access_remove, :any, default: nil

  defp registration_tab(assigns) do
    registration = assigns.registration || default_registration(assigns.channel_name)
    active_level = normalize_access_level(assigns.access_tab)
    role = Map.get(registration, :viewer_role)

    assigns =
      assigns
      |> assign(:registration, registration)
      |> assign(:active_level, active_level)
      |> assign(:viewer_role, role)
      |> assign(:registered?, Map.get(registration, :registered?, false))
      |> assign(:access_entries, active_access_entries(registration, active_level))
      |> assign(:can_manage_active?, can_manage_access?(role, active_level, assigns.identified))
      |> assign(:can_remove?, removable?(assigns.access_selected, assigns.access_nick))

    ~H"""
    <div class="space-y-2">
      <div class="shadow-retro-field bg-white p-2" data-testid="cc-cs-status">
        <div class="flex items-center gap-2 mb-2">
          <Icons.icon_shield class="w-[16px] h-[16px]" />
          <span class="text-sm font-bold">{display_channel(@channel_name)}</span>
        </div>

        <div class="grid grid-cols-[86px_1fr] gap-1 text-xs">
          <span class="text-muted-foreground">{dgettext("dialogs", "Status")}:</span>
          <span>
            {if @registered?,
              do: dgettext("dialogs", "Registered"),
              else: dgettext("dialogs", "Not registered")}
          </span>
          <%= if @registered? do %>
            <span class="text-muted-foreground">{dgettext("dialogs", "Founder")}:</span>
            <span>{Map.get(@registration, :founder)}</span>
            <span class="text-muted-foreground">{dgettext("dialogs", "Since")}:</span>
            <span>{format_registered_at(Map.get(@registration, :registered_at))}</span>
          <% end %>
        </div>

        <p :if={!@identified} class="text-[10px] text-muted-foreground italic mt-2">
          {dgettext("dialogs", "You must be identified with NickServ to use ChanServ.")}
        </p>
        <p :if={!@registered? && !@operator} class="text-[10px] text-muted-foreground italic mt-2">
          {dgettext("dialogs", "Only channel operators can register this channel.")}
        </p>

        <div :if={!@registered? && @operator} class="mt-2">
          <.button
            :if={@identified}
            type="button"
            size="sm"
            phx-click={@on_register}
            phx-value-channel={@channel_name}
            phx-disable-with={dgettext("dialogs", "Registering...")}
            data-testid="cc-cs-register"
          >
            <:icon><Icons.icon_shield /></:icon>
            {dgettext("dialogs", "Register Channel")}
          </.button>
          <.button
            :if={!@identified}
            type="button"
            size="sm"
            disabled
            data-testid="cc-cs-register-disabled"
          >
            <:icon><Icons.icon_shield /></:icon>
            {dgettext("dialogs", "Register Channel")}
          </.button>
        </div>

        <div :if={@registered? && @viewer_role == "founder"} class="mt-2 space-y-2">
          <.button
            :if={!@confirm_drop}
            type="button"
            size="sm"
            variant="destructive"
            phx-click={@on_drop_request}
            phx-value-channel={@channel_name}
            disabled={!@identified}
            data-testid="cc-cs-drop-request"
          >
            <:icon><Icons.icon_trash /></:icon>
            {dgettext("dialogs", "Drop Registration")}
          </.button>

          <div :if={@confirm_drop} class="shadow-retro-field bg-surface p-2 space-y-2">
            <p class="text-xs text-destructive">
              {dgettext("dialogs", "Are you sure you want to drop %{channel}? This cannot be undone.",
                channel: display_channel(@channel_name)
              )}
            </p>
            <div class="flex gap-1">
              <.button
                type="button"
                size="sm"
                variant="destructive"
                phx-click={@on_drop}
                phx-value-channel={@channel_name}
                phx-disable-with={dgettext("dialogs", "Dropping...")}
                data-testid="cc-cs-drop-confirm"
              >
                <:icon><Icons.icon_trash /></:icon>
                {dgettext("dialogs", "Confirm Drop")}
              </.button>
              <.button type="button" size="sm" variant="outline" phx-click={@on_drop_cancel}>
                <:icon><Icons.icon_close /></:icon>
                {dgettext("dialogs", "Cancel")}
              </.button>
            </div>
          </div>
        </div>
      </div>

      <p :if={@error_message} class="text-xs text-destructive shadow-retro-field bg-white p-2">
        {@error_message}
      </p>

      <div :if={@registered?} class="space-y-2" data-testid="cc-cs-access-section">
        <div class="inline-flex shadow-retro-field bg-surface p-[2px] gap-[2px]">
          <button
            :for={level <- access_levels()}
            type="button"
            class={[
              "px-2 py-1 text-xs shadow-retro-raised active:shadow-retro-sunken",
              @active_level == level && "bg-selection-bg text-selection-fg"
            ]}
            phx-click={@on_access_tab}
            phx-value-level={level}
            data-testid={"cc-cs-access-tab-#{level}"}
          >
            {String.upcase(level)}
          </button>
        </div>

        <div class="overflow-y-auto max-h-[160px] shadow-retro-field bg-white">
          <.table>
            <.table_header>
              <.table_row>
                <.table_head class="text-xs px-2 py-1">
                  {dgettext("dialogs", "Nickname")}
                </.table_head>
                <.table_head class="text-xs px-2 py-1">
                  {dgettext("dialogs", "Added By")}
                </.table_head>
              </.table_row>
            </.table_header>
            <.table_body>
              <.table_row
                :for={entry <- @access_entries}
                class={
                  classes([
                    "cursor-pointer text-xs",
                    @access_selected == entry.nickname && "bg-selection-bg text-selection-fg"
                  ])
                }
                phx-click={@on_access_select}
                phx-value-nick={entry.nickname}
                data-testid={"cc-cs-access-row-#{entry.nickname}"}
              >
                <.table_cell class="px-2 py-1 text-xs font-mono">{entry.nickname}</.table_cell>
                <.table_cell class="px-2 py-1 text-xs">{entry.added_by}</.table_cell>
              </.table_row>
              <tr :if={@access_entries == []}>
                <td colspan="2" class="px-2 py-4 text-xs text-center text-muted-foreground">
                  {dgettext("dialogs", "No %{level} entries", level: String.upcase(@active_level))}
                </td>
              </tr>
            </.table_body>
          </.table>
        </div>

        <form
          :if={@can_manage_active?}
          phx-submit={@on_access_add}
          phx-change={@on_access_change}
          data-testid="cc-cs-access-form"
          class="flex flex-wrap items-end gap-1"
        >
          <input type="hidden" name="level" value={@active_level} />
          <div class="flex flex-col gap-1">
            <label class="text-xs font-bold" for="cc-cs-access-nick">
              {dgettext("dialogs", "Nick")}:
            </label>
            <.input
              type="text"
              id="cc-cs-access-nick"
              name="nickname"
              value={@access_nick}
              class="text-xs h-7 w-32"
              data-testid="cc-cs-access-nick"
            />
          </div>
          <.button
            type="submit"
            size="sm"
            phx-disable-with={dgettext("dialogs", "Adding...")}
            data-testid="cc-cs-access-add"
          >
            <:icon><Icons.icon_btn_add /></:icon>
            {dgettext("dialogs", "Add")}
          </.button>
          <.button
            type="button"
            size="sm"
            variant="destructive"
            phx-click={@on_access_remove}
            phx-value-level={@active_level}
            disabled={!@can_remove?}
            phx-disable-with={dgettext("dialogs", "Removing...")}
            data-testid="cc-cs-access-remove"
          >
            <:icon><Icons.icon_btn_remove /></:icon>
            {dgettext("dialogs", "Remove")}
          </.button>
        </form>

        <p :if={!@can_manage_active?} class="text-[10px] text-muted-foreground italic">
          <%= if @identified do %>
            {dgettext("dialogs", "You do not have permission to manage this list.")}
          <% else %>
            {dgettext("dialogs", "You must be identified with NickServ to use ChanServ.")}
          <% end %>
        </p>
      </div>
    </div>
    """
  end

  # ── Sub-Forms ─────────────────────────────────────────

  defp ban_add_sub_form(assigns) do
    ~H"""
    <div
      class="fixed inset-0 z-modal-above bg-black/50 flex items-center justify-center"
      data-testid="cc-add-ban-dialog"
    >
      <div class="bg-surface shadow-retro-window p-[3px] w-full max-w-sm">
        <div class="bg-title-bar flex items-center gap-retro-4 px-retro-2 py-retro-2">
          <span class="text-xs font-bold text-white truncate select-none">
            {dgettext("dialogs", "Add Ban")}
          </span>
          <div class="ml-auto">
            <button
              type="button"
              aria-label={dgettext("dialogs", "Close")}
              phx-click="cc_close_add_ban"
            />
          </div>
        </div>
        <div class="p-2">
          <form phx-submit="cc_add_ban">
            <div class="flex flex-col gap-1.5">
              <label class="text-xs font-bold" for="cc-ban-nick">
                {dgettext("dialogs", "Hostmask")}:
              </label>
              <.input
                type="text"
                id="cc-ban-nick"
                name="nickname"
                autofocus
                class="w-full"
                data-testid="cc-ban-nick-input"
              />
            </div>
            <div class="flex justify-end gap-1 mt-2">
              <.button type="submit" size="sm">
                <:icon><Icons.icon_checkmark /></:icon>
                {dgettext("dialogs", "OK")}
              </.button>
              <.button type="button" size="sm" variant="outline" phx-click="cc_close_add_ban">
                <:icon><Icons.icon_close /></:icon>
                {dgettext("dialogs", "Cancel")}
              </.button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  defp ban_ex_add_sub_form(assigns) do
    ~H"""
    <div
      class="fixed inset-0 z-modal-above bg-black/50 flex items-center justify-center"
      data-testid="cc-add-ban-ex-dialog"
    >
      <div class="bg-surface shadow-retro-window p-[3px] w-full max-w-sm">
        <div class="bg-title-bar flex items-center gap-retro-4 px-retro-2 py-retro-2">
          <span class="text-xs font-bold text-white truncate select-none">
            {dgettext("dialogs", "Add Ban Exception")}
          </span>
          <div class="ml-auto">
            <button
              type="button"
              aria-label={dgettext("dialogs", "Close")}
              phx-click="cc_close_add_ban_ex"
            />
          </div>
        </div>
        <div class="p-2">
          <form phx-submit="cc_add_ban_exception">
            <div class="flex flex-col gap-1.5">
              <label class="text-xs font-bold" for="cc-ban-ex-nick">
                {dgettext("dialogs", "Hostmask")}:
              </label>
              <.input
                type="text"
                id="cc-ban-ex-nick"
                name="nickname"
                autofocus
                class="w-full"
                data-testid="cc-ban-ex-nick-input"
              />
            </div>
            <div class="flex justify-end gap-1 mt-2">
              <.button type="submit" size="sm">
                <:icon><Icons.icon_checkmark /></:icon>
                {dgettext("dialogs", "OK")}
              </.button>
              <.button type="button" size="sm" variant="outline" phx-click="cc_close_add_ban_ex">
                <:icon><Icons.icon_close /></:icon>
                {dgettext("dialogs", "Cancel")}
              </.button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  defp invite_ex_add_sub_form(assigns) do
    ~H"""
    <div
      class="fixed inset-0 z-modal-above bg-black/50 flex items-center justify-center"
      data-testid="cc-add-invite-ex-dialog"
    >
      <div class="bg-surface shadow-retro-window p-[3px] w-full max-w-sm">
        <div class="bg-title-bar flex items-center gap-retro-4 px-retro-2 py-retro-2">
          <span class="text-xs font-bold text-white truncate select-none">
            {dgettext("dialogs", "Add Invite Exception")}
          </span>
          <div class="ml-auto">
            <button
              type="button"
              aria-label={dgettext("dialogs", "Close")}
              phx-click="cc_close_add_invite_ex"
            />
          </div>
        </div>
        <div class="p-2">
          <form phx-submit="cc_add_invite_exception">
            <div class="flex flex-col gap-1.5">
              <label class="text-xs font-bold" for="cc-invite-ex-nick">
                {dgettext("dialogs", "Hostmask")}:
              </label>
              <.input
                type="text"
                id="cc-invite-ex-nick"
                name="nickname"
                autofocus
                class="w-full"
                data-testid="cc-invite-ex-nick-input"
              />
            </div>
            <div class="flex justify-end gap-1 mt-2">
              <.button type="submit" size="sm">
                <:icon><Icons.icon_checkmark /></:icon>
                {dgettext("dialogs", "OK")}
              </.button>
              <.button
                type="button"
                size="sm"
                variant="outline"
                phx-click="cc_close_add_invite_ex"
              >
                <:icon><Icons.icon_close /></:icon>
                {dgettext("dialogs", "Cancel")}
              </.button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  attr :channel_name, :string, default: nil
  attr :error_message, :string, default: nil
  attr :on_close, :any, default: nil
  attr :on_submit, :any, default: nil

  defp transfer_confirm_sub_form(assigns) do
    ~H"""
    <div
      class="fixed inset-0 z-modal-above bg-black/50 flex items-center justify-center"
      data-testid="cc-transfer-dialog"
    >
      <div class="bg-surface shadow-retro-window p-[3px] w-full max-w-sm">
        <div class="bg-title-bar flex items-center gap-retro-4 px-retro-2 py-retro-2">
          <Icons.icon_role_owner class="w-4 h-4 text-white" />
          <span class="text-xs font-bold text-white truncate select-none">
            {dgettext("dialogs", "Transfer Ownership")}
          </span>
          <div class="ml-auto">
            <button
              type="button"
              aria-label={dgettext("dialogs", "Close")}
              phx-click={@on_close}
            />
          </div>
        </div>
        <div class="p-2">
          <form phx-submit={@on_submit}>
            <div class="flex flex-col gap-1.5">
              <label class="text-xs font-bold" for="cc-transfer-nick">
                {dgettext("dialogs", "Transfer ownership of %{channel} to:",
                  channel: display_channel(@channel_name)
                )}
              </label>
              <.input
                type="text"
                id="cc-transfer-nick"
                name="nickname"
                autofocus
                class="w-full"
                data-testid="cc-transfer-nick-input"
              />
            </div>
            <p class="text-xs text-destructive mt-2">
              {dgettext("dialogs", "This cannot be undone without the new owner's cooperation.")}
            </p>
            <p :if={@error_message} class="text-xs text-destructive mt-1">
              {@error_message}
            </p>
            <div class="flex justify-end gap-1 mt-2">
              <.button type="submit" size="sm" variant="destructive">
                <:icon><Icons.icon_role_owner /></:icon>
                {dgettext("dialogs", "Transfer")}
              </.button>
              <.button type="button" size="sm" variant="outline" phx-click={@on_close}>
                <:icon><Icons.icon_close /></:icon>
                {dgettext("dialogs", "Cancel")}
              </.button>
            </div>
          </form>
        </div>
      </div>
    </div>
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
  attr :owner, :boolean, default: false
  attr :welcome_message, :string, default: ""
  attr :throttle_seconds, :integer, default: 0
  attr :notice, :string, default: nil
  attr :on_topic_save, :any, default: nil
  attr :on_welcome_save, :any, default: nil
  attr :on_welcome_clear, :any, default: nil
  attr :on_throttle_apply, :any, default: nil
  attr :on_transfer_open, :any, default: nil

  defp general_tab(assigns) do
    ~H"""
    <div class="space-y-2">
      <div class="shadow-retro-field bg-white p-2">
        <div class="flex items-center gap-2 mb-2">
          <Icons.icon_tab_channel class="w-[16px] h-[16px]" />
          <span class="text-sm font-bold">{display_channel(@channel_name)}</span>
        </div>
        <div class="grid grid-cols-2 gap-1 text-xs">
          <span class="text-muted-foreground">{dgettext("dialogs", "Created")}:</span>
          <span>{@created_at || dgettext("dialogs", "Unknown")}</span>
          <span class="text-muted-foreground">{dgettext("dialogs", "Members")}:</span>
          <span>{@member_count}</span>
        </div>
      </div>

      <.separator />

      <form :if={@operator} phx-submit={@on_topic_save}>
        <label class="text-xs font-bold block mb-1">{dgettext("dialogs", "Topic")}:</label>
        <.input
          type="text"
          name="topic"
          value={@topic}
          placeholder={dgettext("dialogs", "No topic set")}
          class="text-xs h-8"
        />
        <div :if={@topic_set_by} class="text-[10px] text-muted-foreground mt-1">
          {dgettext("dialogs", "Set by %{nick}", nick: @topic_set_by)}
          <span :if={@topic_set_at}>{dgettext("dialogs", "on %{date}", date: @topic_set_at)}</span>
        </div>
        <.button type="submit" size="sm" class="mt-2">
          <:icon><Icons.icon_btn_set_topic /></:icon>
          {dgettext("dialogs", "Save Topic")}
        </.button>
      </form>

      <div :if={!@operator}>
        <label class="text-xs font-bold block mb-1">{dgettext("dialogs", "Topic")}:</label>
        <.input
          type="text"
          name="topic"
          value={@topic}
          placeholder={dgettext("dialogs", "No topic set")}
          disabled
          class="text-xs h-8"
        />
        <div :if={@topic_set_by} class="text-[10px] text-muted-foreground mt-1">
          {dgettext("dialogs", "Set by %{nick}", nick: @topic_set_by)}
          <span :if={@topic_set_at}>{dgettext("dialogs", "on %{date}", date: @topic_set_at)}</span>
        </div>
        <p class="text-[10px] text-muted-foreground italic mt-2">
          {dgettext("dialogs", "You must be a channel operator to edit the topic.")}
        </p>
      </div>

      <.separator />

      <section class="space-y-2">
        <form :if={@operator} phx-submit={@on_welcome_save}>
          <label class="text-xs font-bold block mb-1">
            {dgettext("dialogs", "Welcome Message")}:
          </label>
          <.textarea
            id="cc-welcome-message"
            name="message"
            value={@welcome_message}
            rows="3"
            placeholder={dgettext("dialogs", "No welcome message set.")}
            class="text-xs"
            data-testid="cc-welcome-message-input"
          />
          <div class="flex gap-1 mt-2">
            <.button type="submit" size="sm">
              <:icon><Icons.icon_checkmark /></:icon>
              {dgettext("dialogs", "Save Welcome")}
            </.button>
            <.button type="button" size="sm" variant="outline" phx-click={@on_welcome_clear}>
              <:icon><Icons.icon_close /></:icon>
              {dgettext("dialogs", "Clear Welcome")}
            </.button>
          </div>
        </form>

        <div :if={!@operator}>
          <label class="text-xs font-bold block mb-1">
            {dgettext("dialogs", "Welcome Message")}:
          </label>
          <.textarea
            id="cc-welcome-message"
            name="message"
            value={@welcome_message}
            rows="3"
            placeholder={dgettext("dialogs", "No welcome message set.")}
            class="text-xs"
            disabled
            data-testid="cc-welcome-message-input"
          />
          <p class="text-[10px] text-muted-foreground italic mt-2">
            {dgettext("dialogs", "You must be a channel operator to edit the welcome message.")}
          </p>
        </div>
      </section>

      <section class="space-y-2">
        <form :if={@operator} phx-submit={@on_throttle_apply}>
          <label class="text-xs font-bold block mb-1" for="cc-throttle-seconds">
            {dgettext("dialogs", "Join throttle (seconds)")}:
          </label>
          <div class="flex items-center gap-2">
            <.input
              type="number"
              id="cc-throttle-seconds"
              name="seconds"
              min="0"
              value={@throttle_seconds}
              class="text-xs h-7 w-20"
              data-testid="cc-throttle-seconds-input"
            />
            <.button type="submit" size="sm">
              <:icon><Icons.icon_btn_apply /></:icon>
              {dgettext("dialogs", "Apply Throttle")}
            </.button>
          </div>
        </form>

        <div :if={!@operator}>
          <label class="text-xs font-bold block mb-1" for="cc-throttle-seconds">
            {dgettext("dialogs", "Join throttle (seconds)")}:
          </label>
          <.input
            type="number"
            id="cc-throttle-seconds"
            name="seconds"
            min="0"
            value={@throttle_seconds}
            class="text-xs h-7 w-20"
            disabled
            data-testid="cc-throttle-seconds-input"
          />
          <p class="text-[10px] text-muted-foreground italic mt-2">
            {dgettext("dialogs", "You must be a channel operator to change the join throttle.")}
          </p>
        </div>
      </section>

      <p :if={@notice} class="text-xs text-accent-foreground bg-accent px-2 py-1">
        {@notice}
      </p>

      <.button
        :if={@owner}
        type="button"
        size="sm"
        variant="destructive"
        phx-click={@on_transfer_open}
        data-testid="cc-transfer-open"
      >
        <:icon><Icons.icon_role_owner /></:icon>
        {dgettext("dialogs", "Transfer Ownership")}
      </.button>
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
      <form :if={@operator} phx-submit={@on_mode_apply}>
        <div class="shadow-retro-field bg-white p-2">
          <p class="text-xs font-bold mb-2">{dgettext("dialogs", "Channel Modes")}:</p>

          <div class="space-y-1">
            <label class="inline-flex items-center gap-2 text-xs cursor-pointer">
              <input
                type="checkbox"
                name="moderated"
                value="true"
                checked={@modes[:moderated] || false}
              /> {dgettext("dialogs", "Moderated (+m)")}
            </label>
          </div>
          <div class="space-y-1 mt-1">
            <label class="inline-flex items-center gap-2 text-xs cursor-pointer">
              <input
                type="checkbox"
                name="invite_only"
                value="true"
                checked={@modes[:invite_only] || false}
              /> {dgettext("dialogs", "Invite Only (+i)")}
            </label>
          </div>
          <div class="space-y-1 mt-1">
            <label class="inline-flex items-center gap-2 text-xs cursor-pointer">
              <input
                type="checkbox"
                name="topic_lock"
                value="true"
                checked={@modes[:topic_lock] || false}
              /> {dgettext("dialogs", "Topic Lock (+t)")}
            </label>
          </div>

          <div class="mt-2 flex items-center gap-2">
            <label class="inline-flex items-center gap-2 text-xs cursor-pointer">
              <input
                type="checkbox"
                name="has_key"
                value="true"
                checked={@modes[:key] != nil}
              /> {dgettext("dialogs", "Key (+k)")}:
            </label>
            <.input
              type="text"
              name="key_value"
              value={@modes[:key] || ""}
              class="text-xs h-7 w-24"
              data-testid="cc-key-input"
            />
          </div>
          <div class="mt-2 flex items-center gap-2">
            <label class="inline-flex items-center gap-2 text-xs cursor-pointer">
              <input
                type="checkbox"
                name="has_limit"
                value="true"
                checked={@modes[:limit] != nil}
              /> {dgettext("dialogs", "Limit (+l)")}:
            </label>
            <.input
              type="number"
              name="limit_value"
              min="1"
              value={@modes[:limit] || ""}
              class="text-xs h-7 w-20"
              data-testid="cc-limit-input"
            />
          </div>
        </div>

        <.button type="submit" size="sm" class="mt-2">
          <:icon><Icons.icon_btn_apply /></:icon>
          {dgettext("dialogs", "Apply Modes")}
        </.button>
      </form>

      <div :if={!@operator} class="shadow-retro-field bg-white p-2">
        <p class="text-xs font-bold mb-2">{dgettext("dialogs", "Channel Modes")}:</p>
        <div class="space-y-1">
          <label class="inline-flex items-center gap-2 text-xs opacity-50">
            <input type="checkbox" disabled checked={@modes[:moderated] || false} />
            {dgettext("dialogs", "Moderated (+m)")}
          </label>
        </div>
        <div class="space-y-1 mt-1">
          <label class="inline-flex items-center gap-2 text-xs opacity-50">
            <input type="checkbox" disabled checked={@modes[:invite_only] || false} />
            {dgettext("dialogs", "Invite Only (+i)")}
          </label>
        </div>
        <div class="space-y-1 mt-1">
          <label class="inline-flex items-center gap-2 text-xs opacity-50">
            <input type="checkbox" disabled checked={@modes[:topic_lock] || false} />
            {dgettext("dialogs", "Topic Lock (+t)")}
          </label>
        </div>
        <div class="mt-1">
          <label class="inline-flex items-center gap-2 text-xs opacity-50">
            <input type="checkbox" disabled checked={@modes[:key] != nil} />
            {dgettext("dialogs", "Key (+k)")}
            <span :if={@modes[:key]}>({dgettext("dialogs", "set")})</span>
          </label>
        </div>
        <div class="mt-1">
          <label class="inline-flex items-center gap-2 text-xs opacity-50">
            <input type="checkbox" disabled checked={@modes[:limit] != nil} />
            {dgettext("dialogs", "Limit (+l)")}
            <span :if={@modes[:limit]}>({@modes[:limit]})</span>
          </label>
        </div>
        <p class="text-[10px] text-muted-foreground italic mt-2">
          {dgettext("dialogs", "You must be a channel operator to change modes.")}
        </p>
      </div>
    </div>
    """
  end

  # ── List Tab (Bans / Ban Exceptions / Invite Exceptions) ──

  attr :entries, :list, required: true
  attr :selected, :string, default: nil
  attr :operator, :boolean, default: false
  attr :on_add, :any, default: nil
  attr :on_remove, :any, default: nil
  attr :on_select, :any, default: nil, doc: "Row select event (phx-value-nickname)"
  attr :empty_label, :string, default: nil

  defp list_tab(assigns) do
    has_selection = assigns.selected != nil

    assigns =
      assigns
      |> assign(:has_selection, has_selection)
      |> assign(:empty_label, assigns.empty_label || dgettext("dialogs", "No entries."))

    ~H"""
    <div class="overflow-y-auto max-h-[180px] shadow-retro-field bg-white mb-2">
      <.table>
        <.table_header>
          <.table_row>
            <.table_head class="text-xs px-2 py-1">{dgettext("dialogs", "Mask")}</.table_head>
            <.table_head class="w-[80px] text-xs px-2 py-1">
              {dgettext("dialogs", "Set By")}
            </.table_head>
            <.table_head class="w-[100px] text-xs px-2 py-1">
              {dgettext("dialogs", "Set At")}
            </.table_head>
          </.table_row>
        </.table_header>
        <.table_body>
          <.table_row
            :for={entry <- @entries}
            class={
              classes(["cursor-pointer text-xs", @selected == entry.mask && "bg-primary text-white"])
            }
            phx-click={@on_select}
            phx-value-nickname={entry.mask}
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
        {dgettext("dialogs", "Add")}
      </.button>
      <.button size="sm" variant="destructive" phx-click={@on_remove} disabled={!@has_selection}>
        <:icon><Icons.icon_btn_remove /></:icon>
        {dgettext("dialogs", "Remove")}
      </.button>
    </div>

    <p :if={!@operator} class="text-[10px] text-muted-foreground italic">
      {dgettext("dialogs", "You must be a channel operator to manage this list.")}
    </p>
    """
  end

  # ── Private Helpers ───────────────────────────────────

  @spec default_modes() :: map()
  defp default_modes do
    %{moderated: false, invite_only: false, topic_lock: false, key: nil, limit: nil}
  end

  @spec default_registration(String.t() | nil) :: map()
  defp default_registration(channel_name) do
    %{
      registered?: false,
      channel_name: channel_name,
      founder: nil,
      registered_at: nil,
      viewer_role: nil,
      access: Map.new(access_levels(), &{&1, []})
    }
  end

  @spec access_levels() :: [String.t()]
  defp access_levels, do: ~w(sop aop vop)

  @spec normalize_access_level(String.t() | nil) :: String.t()
  defp normalize_access_level(level) when level in ~w(sop aop vop), do: level
  defp normalize_access_level(_level), do: "sop"

  @spec active_access_entries(map(), String.t()) :: [map()]
  defp active_access_entries(registration, level) do
    registration
    |> Map.get(:access, %{})
    |> Map.get(level, [])
  end

  @spec can_manage_access?(String.t() | nil, String.t(), boolean()) :: boolean()
  defp can_manage_access?("founder", _level, true), do: true
  defp can_manage_access?("sop", level, true), do: level in ~w(aop vop)
  defp can_manage_access?("aop", "vop", true), do: true
  defp can_manage_access?(_role, _level, _identified), do: false

  @spec removable?(String.t() | nil, String.t() | nil) :: boolean()
  defp removable?(selected, nickname) do
    selected not in [nil, ""] or String.trim(to_string(nickname)) != ""
  end

  @spec format_registered_at(DateTime.t() | String.t() | nil) :: String.t()
  defp format_registered_at(nil), do: dgettext("dialogs", "Unknown")
  defp format_registered_at(%DateTime{} = date_time), do: DateTime.to_string(date_time)
  defp format_registered_at(value), do: to_string(value)

  @spec display_channel(String.t() | nil) :: String.t()
  defp display_channel(nil), do: "#unknown"
  defp display_channel(name), do: name
end
