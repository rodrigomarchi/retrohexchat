defmodule RetroHexChatWeb.Components.UI.ChannelCentralDialog do
  @moduledoc """
  Win98-style Channel Central dialog component for the showcase design system.

  Provides a 4-tab dialog for viewing and managing channel properties:
  General (topic, info), Modes (moderated, invite-only, etc.), Access Lists
  (bans, ban exceptions and invite exceptions behind a type selector), and
  Registration (ChanServ).

  Matches v1 event contracts: tab switching via `on_tab`, topic save via
  `phx-submit`, modes via `phx-submit`, access-list selection via `on_list_*`
  callbacks carrying the active list type.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.ToolButton

  import RetroHexChatWeb.Components.UI.ActionList
  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.DialogBanner
  import RetroHexChatWeb.Components.UI.Fieldset
  import RetroHexChatWeb.Components.UI.ListStates
  import RetroHexChatWeb.Components.UI.Tabs
  import RetroHexChatWeb.Components.UI.Table
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Textarea

  alias RetroHexChatWeb.Components.Diagrams
  alias RetroHexChatWeb.Icons

  @doc """
  Renders a Win98-style Channel Central dialog with 4 tabs.

  ## Examples

      <.channel_central_dialog
        id="channel-central"
        show={true}
        channel_name="#lobby"
        topic="Welcome to the lobby!"
        operator={true}
        on_tab="channel_central_tab"
        list_type="bans"
        on_list_type="cc_list_type"
      />
  """
  attr :id, :string, required: true
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
  attr :access_nick, :string, default: ""
  attr :cs_error, :string, default: nil
  attr :cs_confirm_drop, :boolean, default: false
  attr :identified, :boolean, default: false
  attr :modes, :map, default: %{}
  attr :list_type, :string, default: "bans", doc: "Active access list (bans/exceptions)"
  attr :list_entries, :list, default: []

  attr :list_total, :integer,
    default: nil,
    doc: "How many entries the channel actually holds, for the truncation strip"

  attr :on_tab, :any, default: nil, doc: "Tab switch event (phx-value-tab=value)"
  attr :on_topic_save, :any, default: nil
  attr :on_welcome_save, :any, default: nil
  attr :on_welcome_clear, :any, default: nil
  attr :on_throttle_apply, :any, default: nil
  attr :on_transfer_open, :any, default: nil
  attr :on_transfer_close, :any, default: nil
  attr :on_transfer_submit, :any, default: nil
  attr :on_mode_apply, :any, default: nil
  attr :on_list_type, :any, default: nil, doc: "Access list switch event (phx-value-list=type)"
  attr :on_list_add, :any, default: nil
  attr :on_list_remove, :any, default: nil
  attr :on_cs_register, :any, default: nil
  attr :on_cs_archive_toggle, :any, default: nil
  attr :on_cs_drop_request, :any, default: nil
  attr :on_cs_drop, :any, default: nil
  attr :on_cs_drop_cancel, :any, default: nil
  attr :on_cs_access_tab, :any, default: nil
  attr :on_cs_access_change, :any, default: nil
  attr :on_cs_access_add, :any, default: nil
  attr :on_cs_access_remove, :any, default: nil
  attr :show_add_list_entry_dialog, :boolean, default: false
  attr :show_transfer_dialog, :boolean, default: false

  @spec channel_central_panel(map()) :: Phoenix.LiveView.Rendered.t()
  attr :target, :any, default: nil

  def channel_central_panel(assigns) do
    modes = Map.merge(default_modes(), assigns.modes)
    assigns = assign(assigns, :modes, modes)

    ~H"""
    <div
      id={"#{@id}-content"}
      data-testid="channel-central-panel"
      class="cc-dialog flex h-full min-h-0 flex-col overflow-y-auto"
    >
      <.tabs :let={builder} id={"#{@id}-tabs"} default={@active_tab}>
        <div class="cc-main-tabs-shell">
          <.tabs_list class="cc-main-tabs flex flex-wrap">
            <.tabs_trigger
              builder={builder}
              value="general"
              phx-click={@on_tab}
              phx-target={@target}
              phx-value-tab="general"
            >
              <:icon><Icons.icon_tab_general class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "General")}
            </.tabs_trigger>
            <.tabs_trigger
              builder={builder}
              value="modes"
              phx-click={@on_tab}
              phx-target={@target}
              phx-value-tab="modes"
            >
              <:icon><Icons.icon_tab_modes class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Modes")}
            </.tabs_trigger>
            <.tabs_trigger
              builder={builder}
              value="access_lists"
              phx-click={@on_tab}
              phx-target={@target}
              phx-value-tab="access_lists"
            >
              <:icon><Icons.icon_tab_bans class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Access Lists")}
            </.tabs_trigger>
            <.tabs_trigger
              builder={builder}
              value="registration"
              phx-click={@on_tab}
              phx-target={@target}
              phx-value-tab="registration"
            >
              <:icon><Icons.icon_tab_registration class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Registration")}
            </.tabs_trigger>
          </.tabs_list>
        </div>

        <.tabs_content value="general" builder={builder}>
          <.general_tab
            target={@target}
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
            target={@target}
            channel_name={@channel_name}
            modes={@modes}
            operator={@operator}
            on_mode_apply={@on_mode_apply}
          />
        </.tabs_content>

        <.tabs_content value="access_lists" builder={builder}>
          <.access_lists_tab
            target={@target}
            list_type={@list_type}
            entries={@list_entries}
            total={@list_total}
            operator={@operator}
            on_list_type={@on_list_type}
            on_add={@on_list_add}
            on_remove={@on_list_remove}
          />
        </.tabs_content>

        <.tabs_content value="registration" builder={builder}>
          <.registration_tab
            target={@target}
            channel_name={@channel_name}
            operator={@operator}
            identified={@identified}
            registration={@registration}
            access_tab={@access_tab}
            access_nick={@access_nick}
            error_message={@cs_error}
            confirm_drop={@cs_confirm_drop}
            on_register={@on_cs_register}
            on_archive_toggle={@on_cs_archive_toggle}
            on_drop_request={@on_cs_drop_request}
            on_drop={@on_cs_drop}
            on_drop_cancel={@on_cs_drop_cancel}
            on_access_tab={@on_cs_access_tab}
            on_access_change={@on_cs_access_change}
            on_access_add={@on_cs_access_add}
            on_access_remove={@on_cs_access_remove}
          />
        </.tabs_content>
      </.tabs>

      <%!-- Access List Entry Add Sub-Dialog --%>
      <.list_entry_add_sub_form
        :if={@show_add_list_entry_dialog}
        target={@target}
        list_type={@list_type}
      />
      <%!-- Ownership Transfer Sub-Dialog --%>
      <.transfer_confirm_sub_form
        :if={@show_transfer_dialog}
        target={@target}
        channel_name={@channel_name}
        error_message={@transfer_error}
        on_close={@on_transfer_close}
        on_submit={@on_transfer_submit}
      />
    </div>
    """
  end

  # ── Registration Tab ───────────────────────────────────

  attr :channel_name, :string, default: nil
  attr :operator, :boolean, default: false
  attr :identified, :boolean, default: false
  attr :registration, :map, default: nil
  attr :access_tab, :string, default: "sop"
  attr :access_nick, :string, default: ""
  attr :error_message, :string, default: nil
  attr :confirm_drop, :boolean, default: false
  attr :on_register, :any, default: nil
  attr :on_archive_toggle, :any, default: nil
  attr :on_drop_request, :any, default: nil
  attr :on_drop, :any, default: nil
  attr :on_drop_cancel, :any, default: nil
  attr :on_access_tab, :any, default: nil
  attr :on_access_change, :any, default: nil
  attr :on_access_add, :any, default: nil
  attr :on_access_remove, :any, default: nil

  attr :target, :any, default: nil

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
      |> assign(:public_archive?, Map.get(registration, :public_archive?, false))
      |> assign(:founder?, role == "founder")

    ~H"""
    <div class="space-y-2">
      <.dialog_banner heading={registration_heading(@registered?)}>
        <:art>
          <Diagrams.diagram_dialog_preview
            kind={:card}
            title={dgettext("dialogs", "ChanServ")}
            lines={registration_lines(@registration, @registered?)}
            label={dgettext("dialogs", "A miniature of the ChanServ record for this channel")}
          />
        </:art>
        <:glyph><Icons.icon_shield class="h-8 w-8" /></:glyph>
        {dgettext(
          "dialogs",
          "Registering hands the channel to ChanServ, which keeps the founder, the access lists and the settings even when nobody is inside. An unregistered channel stops existing the moment its last member leaves."
        )}
      </.dialog_banner>

      <div class="cc-status-card shadow-retro-field bg-white p-2" data-testid="cc-cs-status">
        <div class="cc-dialog-heading flex items-center gap-2 mb-2">
          <Icons.icon_shield class="w-[16px] h-[16px]" />
          <span class="cc-dialog-title text-sm font-bold">{display_channel(@channel_name)}</span>
        </div>

        <div class="cc-status-grid grid grid-cols-[86px_1fr] gap-1 text-xs">
          <span class="text-muted-foreground">
            {dgettext("dialogs", "Status")}:
          </span>
          <span class="cc-status-value">
            {if @registered?,
              do: dgettext("dialogs", "Registered"),
              else: dgettext("dialogs", "Not registered")}
          </span>
          <%= if @registered? do %>
            <span class="text-muted-foreground">
              {dgettext("dialogs", "Founder")}:
            </span>
            <span class="cc-status-value">{Map.get(@registration, :founder)}</span>
            <span class="text-muted-foreground">
              {dgettext("dialogs", "Since")}:
            </span>
            <span class="cc-status-value">
              {format_registered_at(Map.get(@registration, :registered_at))}
            </span>
          <% end %>
        </div>

        <p :if={!@identified} class="text-[10px] text-muted-foreground italic mt-2">
          {dgettext("dialogs", "You must be identified with NickServ to use ChanServ.")}
        </p>
        <p :if={!@registered? && !@operator} class="text-[10px] text-muted-foreground italic mt-2">
          {dgettext("dialogs", "Only channel operators can register this channel.")}
        </p>

        <%!-- The founder's decision, and nobody else's. An operator moderates
              the room; deciding that what is said in it becomes readable from
              outside is a different kind of decision. --%>
        <div :if={@registered? && @founder?} class="mt-3" data-testid="cc-archive-switch">
          <label class="flex items-start gap-2 text-xs">
            <input
              type="checkbox"
              checked={@public_archive?}
              phx-click={@on_archive_toggle}
              phx-target={@target}
              phx-value-enabled={to_string(!@public_archive?)}
              data-testid="cc-archive-toggle"
            />
            <span>
              <span class="font-bold">{dgettext("dialogs", "Public archive")}</span>
              <span class="block text-[10px] text-muted-foreground">
                {dgettext(
                  "dialogs",
                  "Publish a page per day that anybody can read and a search engine can index. Only what is said from the moment you switch this on — nothing already in the channel is ever published. Switching it off takes the pages down."
                )}
              </span>
            </span>
          </label>
        </div>

        <div :if={!@registered? && @operator} class="mt-2">
          <.button
            :if={@identified}
            type="button"
            size="sm"
            phx-click={@on_register}
            phx-target={@target}
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
            class="cc-danger-action"
            phx-click={@on_drop_request}
            phx-target={@target}
            phx-value-channel={@channel_name}
            disabled={!@identified}
            data-testid="cc-cs-drop-request"
          >
            <:icon><Icons.icon_trash /></:icon>
            {dgettext("dialogs", "Drop Registration")}
          </.button>

          <div
            :if={@confirm_drop}
            class="shadow-retro-field bg-surface p-2 space-y-2"
          >
            <p class="text-xs text-destructive">
              {dgettext("dialogs", "Are you sure you want to drop %{channel}? This cannot be undone.",
                channel: display_channel(@channel_name)
              )}
            </p>
            <div class="cc-action-row flex gap-1">
              <.button
                type="button"
                size="sm"
                variant="destructive"
                class="cc-action-button"
                phx-click={@on_drop}
                phx-target={@target}
                phx-value-channel={@channel_name}
                phx-disable-with={dgettext("dialogs", "Dropping...")}
                data-testid="cc-cs-drop-confirm"
              >
                <:icon><Icons.icon_trash /></:icon>
                {dgettext("dialogs", "Confirm Drop")}
              </.button>
              <.button
                type="button"
                size="sm"
                variant="outline"
                class="cc-action-button"
                phx-click={@on_drop_cancel}
                phx-target={@target}
              >
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
        <div class="cc-segmented-tabs inline-flex shadow-retro-field bg-surface p-[2px] gap-[2px]">
          <.tool_button
            :for={level <- access_levels()}
            label={String.upcase(level)}
            size="sm"
            active={@active_level == level}
            pressed={@active_level == level}
            class={[
              "cc-segmented-tab w-auto px-2 text-xs",
              @active_level == level && "bg-selection-bg text-selection-fg"
            ]}
            phx-click={@on_access_tab}
            phx-target={@target}
            phx-value-level={level}
            data-testid={"cc-cs-access-tab-#{level}"}
          >
            {String.upcase(level)}
          </.tool_button>
        </div>

        <div class="cc-list-table-wrap overflow-y-auto max-h-[160px] shadow-retro-field bg-white">
          <.table class="cc-mobile-list-table" data-cc-mobile-list-table>
            <.table_header>
              <.table_row>
                <.table_head class="text-xs px-2 py-1">
                  {dgettext("dialogs", "Nickname")}
                </.table_head>
                <.table_head class="text-xs px-2 py-1">
                  {dgettext("dialogs", "Added By")}
                </.table_head>
                <.table_head :if={@can_manage_active?} class="w-[44px] text-xs px-2 py-1">
                  <span class="sr-only">{dgettext("dialogs", "Remove")}</span>
                </.table_head>
              </.table_row>
            </.table_header>
            <.table_body>
              <.table_row
                :for={entry <- @access_entries}
                class="cc-mobile-list-row text-xs"
                data-testid={"cc-cs-access-row-#{entry.nickname}"}
              >
                <.table_cell
                  class="cc-mobile-list-primary px-2 py-1 text-xs font-mono"
                  data-label={dgettext("dialogs", "Nickname")}
                >
                  {entry.nickname}
                </.table_cell>
                <.table_cell
                  class="cc-mobile-list-meta px-2 py-1 text-xs"
                  data-label={dgettext("dialogs", "Added By")}
                >
                  {entry.added_by}
                </.table_cell>
                <.table_cell :if={@can_manage_active?} class="cc-mobile-list-action px-2 py-1">
                  <.row_action
                    event={@on_access_remove}
                    value={%{"level" => @active_level, "nickname" => entry.nickname}}
                    label={dgettext("dialogs", "Remove %{nickname}", nickname: entry.nickname)}
                    variant="destructive"
                    target={@target}
                    testid={"cc-cs-access-remove-#{entry.nickname}"}
                  >
                    <Icons.icon_btn_remove class="w-4 h-4" />
                  </.row_action>
                </.table_cell>
              </.table_row>
              <tr :if={@access_entries == []} class="cc-empty-row">
                <td
                  colspan={if @can_manage_active?, do: "3", else: "2"}
                  class="cc-empty-cell px-2 py-4 text-xs text-center text-muted-foreground"
                >
                  {dgettext("dialogs", "No %{level} entries", level: String.upcase(@active_level))}
                </td>
              </tr>
            </.table_body>
          </.table>
        </div>

        <form
          :if={@can_manage_active?}
          phx-submit={@on_access_add}
          phx-target={@target}
          phx-change={@on_access_change}
          data-testid="cc-cs-access-form"
          class="cc-action-form flex flex-wrap items-end gap-1"
        >
          <input type="hidden" name="level" value={@active_level} />
          <div class="cc-action-input flex flex-col gap-1">
            <label class="text-xs font-bold" for="cc-cs-access-nick">
              {dgettext("dialogs", "Nick")}:
            </label>
            <.input
              type="text"
              id="cc-cs-access-nick"
              name="nickname"
              value={@access_nick}
              class="cc-action-input-control text-xs h-7 w-32"
              data-testid="cc-cs-access-nick"
            />
          </div>
          <.button
            type="submit"
            size="sm"
            class="cc-action-button"
            phx-disable-with={dgettext("dialogs", "Adding...")}
            data-testid="cc-cs-access-add"
          >
            <:icon><Icons.icon_btn_add /></:icon>
            {dgettext("dialogs", "Add")}
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

  attr :list_type, :string, required: true

  attr :target, :any, default: nil

  defp list_entry_add_sub_form(assigns) do
    assigns = assign(assigns, :title, add_entry_title(assigns.list_type))

    ~H"""
    <.dialog
      id="cc-add-list-entry-modal"
      show
      scope={:window}
      on_cancel={JS.push("cc_close_add_list_entry", target: @target)}
      class="md:max-w-sm"
    >
      <.dialog_header
        id="cc-add-list-entry-modal"
        title={@title}
        on_close={JS.push("cc_close_add_list_entry", target: @target)}
      >
        <:icon><Icons.icon_dialog_channel_central class="w-4 h-4" /></:icon>
      </.dialog_header>
      <.dialog_body>
        <div data-access-list={@list_type} data-testid="cc-add-list-entry-dialog">
          <form phx-submit="cc_add_list_entry" phx-target={@target}>
            <input type="hidden" name="list" value={@list_type} />
            <div class="flex flex-col gap-1.5">
              <label class="text-xs font-bold" for="cc-list-entry-mask">
                {dgettext("dialogs", "Hostmask")}:
              </label>
              <.input
                type="text"
                id="cc-list-entry-mask"
                name="nickname"
                autofocus
                class="w-full"
                data-testid="cc-list-entry-input"
              />
            </div>
            <div class="cc-action-row flex justify-end gap-1 mt-2">
              <.button type="submit" size="sm" class="cc-action-button">
                <:icon><Icons.icon_checkmark /></:icon>
                {dgettext("dialogs", "OK")}
              </.button>
              <.button
                type="button"
                size="sm"
                variant="outline"
                class="cc-action-button"
                phx-click="cc_close_add_list_entry"
                phx-target={@target}
              >
                <:icon><Icons.icon_close /></:icon>
                {dgettext("dialogs", "Cancel")}
              </.button>
            </div>
          </form>
        </div>
      </.dialog_body>
    </.dialog>
    """
  end

  attr :channel_name, :string, default: nil
  attr :error_message, :string, default: nil
  attr :on_close, :any, default: nil
  attr :on_submit, :any, default: nil

  attr :target, :any, default: nil

  defp transfer_confirm_sub_form(assigns) do
    ~H"""
    <.dialog
      id="cc-transfer-modal"
      show
      scope={:window}
      on_cancel={JS.push(@on_close, target: @target)}
      class="md:max-w-sm"
    >
      <.dialog_header
        id="cc-transfer-modal"
        title={dgettext("dialogs", "Transfer Ownership")}
        on_close={JS.push(@on_close, target: @target)}
      >
        <:icon><Icons.icon_role_owner class="w-4 h-4" /></:icon>
      </.dialog_header>
      <.dialog_body>
        <div data-testid="cc-transfer-dialog">
          <form phx-submit={@on_submit} phx-target={@target}>
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
            <div class="cc-action-row flex justify-end gap-1 mt-2">
              <.button type="submit" size="sm" variant="destructive" class="cc-action-button">
                <:icon><Icons.icon_role_owner /></:icon>
                {dgettext("dialogs", "Transfer")}
              </.button>
              <.button
                type="button"
                size="sm"
                variant="outline"
                class="cc-action-button"
                phx-click={@on_close}
                phx-target={@target}
              >
                <:icon><Icons.icon_close /></:icon>
                {dgettext("dialogs", "Cancel")}
              </.button>
            </div>
          </form>
        </div>
      </.dialog_body>
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
  attr :owner, :boolean, default: false
  attr :welcome_message, :string, default: ""
  attr :throttle_seconds, :integer, default: 0
  attr :notice, :string, default: nil
  attr :on_topic_save, :any, default: nil
  attr :on_welcome_save, :any, default: nil
  attr :on_welcome_clear, :any, default: nil
  attr :on_throttle_apply, :any, default: nil
  attr :on_transfer_open, :any, default: nil

  attr :target, :any, default: nil

  defp general_tab(assigns) do
    ~H"""
    <div class="space-y-2">
      <.dialog_banner
        heading={dgettext("dialogs", "How this channel greets people")}
        data-testid="cc-general-banner"
      >
        <:art>
          <Diagrams.diagram_channel_preview
            channel_name={display_channel(@channel_name)}
            topic={@topic}
            welcome={@welcome_message}
          />
        </:art>
        <:glyph><Icons.icon_tab_channel class="h-8 w-8" /></:glyph>
        {dgettext(
          "dialogs",
          "The topic rides above every message for everyone in the channel; the welcome message is written once to each person as they arrive, and nobody else sees it."
        )}
      </.dialog_banner>

      <div class="cc-status-card shadow-retro-field bg-white p-2">
        <div class="cc-dialog-heading flex items-center gap-2 mb-2">
          <Icons.icon_tab_channel class="w-[16px] h-[16px]" />
          <span class="cc-dialog-title text-sm font-bold">{display_channel(@channel_name)}</span>
        </div>
        <div class="cc-status-grid grid grid-cols-2 gap-1 text-xs">
          <span class="text-muted-foreground">
            {dgettext("dialogs", "Created")}:
          </span>
          <span class="cc-status-value">{@created_at || dgettext("dialogs", "Unknown")}</span>
          <span class="text-muted-foreground">
            {dgettext("dialogs", "Members")}:
          </span>
          <span class="cc-status-value">{@member_count}</span>
        </div>
      </div>

      <.dialog_section
        legend={dgettext("dialogs", "Topic")}
        description={
          dgettext(
            "dialogs",
            "One line describing what the channel is for. Everyone already in the channel sees it change."
          )
        }
        command={command_syntax("topic")}
      >
        <:icon><Icons.icon_btn_set_topic class="h-4 w-4" /></:icon>

        <form :if={@operator} phx-submit={@on_topic_save} phx-target={@target} class="cc-form-block">
          <.input
            type="text"
            name="topic"
            value={@topic}
            placeholder={dgettext("dialogs", "No topic set")}
            class="cc-topic-input text-xs h-8"
          />
          <p :if={@topic != ""} class="cc-topic-preview text-xs shadow-retro-field bg-white p-2 mt-1">
            {@topic}
          </p>
          <div :if={@topic_set_by} class="text-[10px] text-muted-foreground mt-1">
            {dgettext("dialogs", "Set by %{nick}", nick: @topic_set_by)}
            <span :if={@topic_set_at}>{dgettext("dialogs", "on %{date}", date: @topic_set_at)}</span>
          </div>
          <div class="cc-action-row flex gap-1 mt-2">
            <.button type="submit" size="sm" class="cc-action-button">
              <:icon><Icons.icon_btn_set_topic /></:icon>
              {dgettext("dialogs", "Save Topic")}
            </.button>
          </div>
        </form>

        <div :if={!@operator} class="cc-form-block">
          <.input
            type="text"
            name="topic"
            value={@topic}
            placeholder={dgettext("dialogs", "No topic set")}
            disabled
            class="cc-topic-input text-xs h-8"
          />
          <p :if={@topic != ""} class="cc-topic-preview text-xs shadow-retro-field bg-white p-2 mt-1">
            {@topic}
          </p>
          <div :if={@topic_set_by} class="text-[10px] text-muted-foreground mt-1">
            {dgettext("dialogs", "Set by %{nick}", nick: @topic_set_by)}
            <span :if={@topic_set_at}>{dgettext("dialogs", "on %{date}", date: @topic_set_at)}</span>
          </div>
          <p class="text-[10px] text-muted-foreground italic mt-2">
            {dgettext("dialogs", "You must be a channel operator to edit the topic.")}
          </p>
        </div>
      </.dialog_section>

      <.dialog_section
        legend={dgettext("dialogs", "Welcome Message")}
        description={
          dgettext(
            "dialogs",
            "Sent privately to each person the moment they join — the house rules, the link, whatever they need before they speak."
          )
        }
        command={command_syntax("setwelcome")}
      >
        <:icon><Icons.icon_megaphone class="h-4 w-4" /></:icon>

        <form :if={@operator} phx-submit={@on_welcome_save} phx-target={@target} class="cc-form-block">
          <.textarea
            id="cc-welcome-message"
            name="message"
            value={@welcome_message}
            rows="3"
            placeholder={dgettext("dialogs", "No welcome message set.")}
            class="text-xs"
            data-testid="cc-welcome-message-input"
          />
          <div class="cc-action-row flex gap-1 mt-2">
            <.button type="submit" size="sm" class="cc-action-button">
              <:icon><Icons.icon_checkmark /></:icon>
              {dgettext("dialogs", "Save Welcome")}
            </.button>
            <.button
              type="button"
              size="sm"
              variant="outline"
              class="cc-action-button"
              phx-click={@on_welcome_clear}
              phx-target={@target}
            >
              <:icon><Icons.icon_close /></:icon>
              {dgettext("dialogs", "Clear Welcome")}
            </.button>
          </div>
        </form>

        <div :if={!@operator} class="cc-form-block">
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
      </.dialog_section>

      <.dialog_section
        legend={dgettext("dialogs", "Join throttle")}
        description={
          dgettext(
            "dialogs",
            "How long someone must wait between joins, which is what stops a join flood. Zero turns it off."
          )
        }
        command={command_syntax("slow")}
      >
        <:icon><Icons.icon_clock class="h-4 w-4" /></:icon>

        <form
          :if={@operator}
          phx-submit={@on_throttle_apply}
          phx-target={@target}
          class="cc-form-block"
        >
          <label class="text-xs font-bold block mb-1" for="cc-throttle-seconds">
            {dgettext("dialogs", "Seconds")}:
          </label>
          <div class="cc-inline-control flex items-center gap-2">
            <.input
              type="number"
              id="cc-throttle-seconds"
              name="seconds"
              min="0"
              value={@throttle_seconds}
              class="cc-short-input text-xs h-7 w-20"
              data-testid="cc-throttle-seconds-input"
            />
            <.button type="submit" size="sm" class="cc-action-button">
              <:icon><Icons.icon_btn_apply /></:icon>
              {dgettext("dialogs", "Apply Throttle")}
            </.button>
          </div>
        </form>

        <div :if={!@operator}>
          <label class="text-xs font-bold block mb-1" for="cc-throttle-seconds">
            {dgettext("dialogs", "Seconds")}:
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
      </.dialog_section>

      <p :if={@notice} class="text-xs text-accent-foreground bg-accent px-2 py-1">
        {@notice}
      </p>

      <.dialog_section
        :if={@owner}
        legend={dgettext("dialogs", "Ownership")}
        description={
          dgettext(
            "dialogs",
            "Hands the channel to somebody else. You keep operator status; they get everything that is founder-only, including this tab."
          )
        }
        command={command_syntax("transfer")}
      >
        <:icon><Icons.icon_role_owner class="h-4 w-4" /></:icon>

        <div class="cc-action-row flex gap-1">
          <%!-- Handing the channel over is not the destructive step; confirming
                it is. Only the confirmation is drawn in red. --%>
          <.button
            type="button"
            size="sm"
            variant="outline"
            class="cc-danger-action"
            phx-click={@on_transfer_open}
            phx-target={@target}
            data-testid="cc-transfer-open"
          >
            <:icon><Icons.icon_role_owner /></:icon>
            {dgettext("dialogs", "Transfer Ownership")}
          </.button>
        </div>
      </.dialog_section>
    </div>
    """
  end

  # ── Modes Tab ─────────────────────────────────────────

  attr :channel_name, :string, default: nil
  attr :modes, :map, required: true
  attr :operator, :boolean, default: false
  attr :on_mode_apply, :any, default: nil

  attr :target, :any, default: nil

  # The mode boxes carry no `phx-update="ignore"`, and that is the whole reason
  # they tell the truth. Frozen against the server, a box kept whatever the last
  # click left in it: `/mode -m` turned moderation off and this panel still drew
  # it on. LiveView already protects a toggle in progress — an unrelated
  # re-render sends no diff for a value that did not change — so ignoring the
  # element bought nothing and cost the one update that matters.
  defp modes_tab(assigns) do
    assigns = assign(assigns, :door_lines, door_lines(assigns.modes))

    ~H"""
    <div class="space-y-2">
      <.dialog_banner heading={dgettext("dialogs", "Who gets in, and who gets to talk")}>
        <:art>
          <Diagrams.diagram_dialog_preview
            kind={:query}
            title={display_channel(@channel_name)}
            lines={@door_lines}
            label={dgettext("dialogs", "A miniature of what a newcomer meets at the door")}
          />
        </:art>
        <:glyph><Icons.icon_tab_modes class="h-8 w-8" /></:glyph>
        {dgettext(
          "dialogs",
          "A mode changes the channel for everybody at once and takes effect the moment you apply it — people already inside are affected too, not just the next person through the door."
        )}
      </.dialog_banner>

      <form :if={@operator} phx-submit={@on_mode_apply} phx-target={@target}>
        <div class="cc-settings-panel shadow-retro-field bg-white p-2">
          <p class="text-xs font-bold mb-2">{dgettext("dialogs", "Channel Modes")}:</p>

          <div class="cc-mode-list space-y-1">
            <label class="cc-mode-row inline-flex items-center gap-2 text-xs cursor-pointer">
              <input
                type="checkbox"
                id="cc-mode-moderated"
                name="moderated"
                value="true"
                checked={@modes[:moderated] || false}
              /> {dgettext("dialogs", "Moderated (+m)")}
            </label>
            <label class="cc-mode-row inline-flex items-center gap-2 text-xs cursor-pointer">
              <input
                type="checkbox"
                id="cc-mode-invite_only"
                name="invite_only"
                value="true"
                checked={@modes[:invite_only] || false}
              /> {dgettext("dialogs", "Invite Only (+i)")}
            </label>
            <label class="cc-mode-row inline-flex items-center gap-2 text-xs cursor-pointer">
              <input
                type="checkbox"
                id="cc-mode-topic_lock"
                name="topic_lock"
                value="true"
                checked={@modes[:topic_lock] || false}
              /> {dgettext("dialogs", "Topic Lock (+t)")}
            </label>
          </div>

          <div class="cc-mode-pair mt-2 flex items-center gap-2">
            <label class="cc-mode-row inline-flex items-center gap-2 text-xs cursor-pointer">
              <input
                type="checkbox"
                id="cc-mode-has_key"
                name="has_key"
                value="true"
                checked={@modes[:key] != nil}
              /> {dgettext("dialogs", "Key (+k)")}:
            </label>
            <.input
              type="text"
              name="key_value"
              value={@modes[:key] || ""}
              class="cc-mode-input text-xs h-7 w-24"
              data-testid="cc-key-input"
            />
          </div>
          <div class="cc-mode-pair mt-2 flex items-center gap-2">
            <label class="cc-mode-row inline-flex items-center gap-2 text-xs cursor-pointer">
              <input
                type="checkbox"
                id="cc-mode-has_limit"
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
              class="cc-mode-input cc-short-input text-xs h-7 w-20"
              data-testid="cc-limit-input"
            />
          </div>
        </div>

        <div class="cc-action-row flex gap-1 mt-2">
          <.button type="submit" size="sm" class="cc-action-button">
            <:icon><Icons.icon_btn_apply /></:icon>
            {dgettext("dialogs", "Apply Modes")}
          </.button>
        </div>
      </form>

      <div :if={!@operator} class="cc-settings-panel shadow-retro-field bg-white p-2">
        <p class="text-xs font-bold mb-2">{dgettext("dialogs", "Channel Modes")}:</p>
        <div class="space-y-1">
          <label class="inline-flex items-center gap-2 text-xs">
            <input type="checkbox" disabled checked={@modes[:moderated] || false} />
            {dgettext("dialogs", "Moderated (+m)")}
          </label>
        </div>
        <div class="space-y-1 mt-1">
          <label class="inline-flex items-center gap-2 text-xs">
            <input type="checkbox" disabled checked={@modes[:invite_only] || false} />
            {dgettext("dialogs", "Invite Only (+i)")}
          </label>
        </div>
        <div class="space-y-1 mt-1">
          <label class="inline-flex items-center gap-2 text-xs">
            <input type="checkbox" disabled checked={@modes[:topic_lock] || false} />
            {dgettext("dialogs", "Topic Lock (+t)")}
          </label>
        </div>
        <div class="mt-1">
          <label class="inline-flex items-center gap-2 text-xs">
            <input type="checkbox" disabled checked={@modes[:key] != nil} />
            {dgettext("dialogs", "Key (+k)")}
            <span :if={@modes[:key]}>({dgettext("dialogs", "set")})</span>
          </label>
        </div>
        <div class="mt-1">
          <label class="inline-flex items-center gap-2 text-xs">
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

  # ── Access Lists Tab (Bans / Ban Exceptions / Invite Exceptions) ──

  attr :list_type, :string, required: true
  attr :entries, :list, required: true
  attr :total, :integer, default: nil, doc: "Entries the channel holds, for the truncation strip"
  attr :operator, :boolean, default: false
  attr :on_list_type, :any, default: nil
  attr :on_add, :any, default: nil
  attr :on_remove, :any, default: nil, doc: "Row remove event (phx-value-nickname)"

  attr :target, :any, default: nil

  defp access_lists_tab(assigns) do
    active = normalize_list_type(assigns.list_type)

    assigns =
      assigns
      |> assign(:active_list, active)
      |> assign(:empty_label, empty_list_label(active))

    ~H"""
    <div class="space-y-2">
      <.dialog_banner heading={dgettext("dialogs", "The names the door checks")}>
        <:art>
          <Diagrams.diagram_dialog_preview
            kind={:ordered}
            title={list_type_label(@active_list)}
            lines={mask_lines(@entries)}
            label={dgettext("dialogs", "A miniature of the masks this list is holding")}
          />
        </:art>
        <:glyph><Icons.icon_ban class="h-8 w-8" /></:glyph>
        {dgettext(
          "dialogs",
          "Each entry is a mask rather than a nickname, so it keeps matching after somebody renames. An exception outranks a ban, which is how you bar a range and still let one person through."
        )}
      </.dialog_banner>

      <div class="cc-segmented-tabs inline-flex shadow-retro-field bg-surface p-[2px] gap-[2px]">
        <.tool_button
          :for={list_type <- list_types()}
          label={list_type_label(list_type)}
          size="sm"
          active={@active_list == list_type}
          pressed={@active_list == list_type}
          class={[
            "cc-segmented-tab w-auto px-2 text-xs",
            @active_list == list_type && "bg-selection-bg text-selection-fg"
          ]}
          phx-click={@on_list_type}
          phx-target={@target}
          phx-value-list={list_type}
          data-testid={"cc-list-type-#{list_type}"}
        >
          {list_type_label(list_type)}
        </.tool_button>
      </div>

      <div class="cc-list-table-wrap overflow-y-auto max-h-[180px] shadow-retro-field bg-white">
        <.table class="cc-mobile-list-table" data-cc-mobile-list-table>
          <.table_header>
            <.table_row>
              <.table_head class="text-xs px-2 py-1">{dgettext("dialogs", "Mask")}</.table_head>
              <.table_head class="w-[80px] text-xs px-2 py-1">
                {dgettext("dialogs", "Set By")}
              </.table_head>
              <.table_head class="w-[100px] text-xs px-2 py-1">
                {dgettext("dialogs", "Set At")}
              </.table_head>
              <.table_head :if={@operator} class="w-[44px] text-xs px-2 py-1">
                <span class="sr-only">{dgettext("dialogs", "Remove")}</span>
              </.table_head>
            </.table_row>
          </.table_header>
          <.table_body>
            <.table_row :for={entry <- @entries} class="cc-mobile-list-row text-xs">
              <.table_cell
                class="cc-mobile-list-primary px-2 py-1 text-xs font-mono"
                data-label={dgettext("dialogs", "Mask")}
              >
                {entry.mask}
              </.table_cell>
              <.table_cell
                class="cc-mobile-list-meta px-2 py-1 text-xs"
                data-label={dgettext("dialogs", "Set By")}
              >
                {entry.set_by}
              </.table_cell>
              <.table_cell
                class="cc-mobile-list-meta px-2 py-1 text-xs"
                data-label={dgettext("dialogs", "Set At")}
              >
                {entry.set_at}
              </.table_cell>
              <.table_cell :if={@operator} class="cc-mobile-list-action px-2 py-1">
                <.row_action
                  event={@on_remove}
                  value={%{"nickname" => entry.mask}}
                  label={dgettext("dialogs", "Remove %{mask}", mask: entry.mask)}
                  variant="destructive"
                  target={@target}
                  testid={"cc-list-remove-#{entry.mask}"}
                >
                  <Icons.icon_btn_remove class="w-4 h-4" />
                </.row_action>
              </.table_cell>
            </.table_row>
            <tr :if={@entries == []} class="cc-empty-row">
              <td colspan={if @operator, do: "4", else: "3"} class="cc-empty-cell">
                <.list_empty_state title={@empty_label} icon={:people} />
              </td>
            </tr>
          </.table_body>
        </.table>
      </div>

      <.list_count_strip
        shown={length(@entries)}
        total={@total}
        data-testid="cc-list-count-strip"
      />

      <%!-- Add has no row to belong to, so it stays with the panel. --%>
      <div :if={@operator} class="cc-action-row flex gap-1">
        <.button size="sm" class="cc-action-button" phx-click={@on_add} phx-target={@target}>
          <:icon><Icons.icon_btn_add /></:icon>
          {dgettext("dialogs", "Add")}
        </.button>
      </div>

      <p :if={!@operator} class="text-[10px] text-muted-foreground italic">
        {dgettext("dialogs", "You must be a channel operator to manage this list.")}
      </p>
    </div>
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

  @spec list_types() :: [String.t()]
  defp list_types, do: ~w(bans ban_exceptions invite_exceptions)

  @spec normalize_list_type(String.t() | nil) :: String.t()
  defp normalize_list_type(list_type)
       when list_type in ~w(bans ban_exceptions invite_exceptions),
       do: list_type

  defp normalize_list_type(_list_type), do: "bans"

  @spec list_type_label(String.t()) :: String.t()
  defp list_type_label("bans"), do: dgettext("dialogs", "Bans")
  defp list_type_label("ban_exceptions"), do: dgettext("dialogs", "Ban Exc.")
  defp list_type_label("invite_exceptions"), do: dgettext("dialogs", "Invite Exc.")

  @spec empty_list_label(String.t()) :: String.t()
  defp empty_list_label("bans"), do: dgettext("dialogs", "No bans set on this channel.")
  defp empty_list_label("ban_exceptions"), do: dgettext("dialogs", "No ban exceptions set.")
  defp empty_list_label("invite_exceptions"), do: dgettext("dialogs", "No invite exceptions set.")

  @spec add_entry_title(String.t()) :: String.t()
  defp add_entry_title(list_type) do
    case normalize_list_type(list_type) do
      "bans" -> dgettext("dialogs", "Add Ban")
      "ban_exceptions" -> dgettext("dialogs", "Add Ban Exception")
      "invite_exceptions" -> dgettext("dialogs", "Add Invite Exception")
    end
  end

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

  @spec format_registered_at(DateTime.t() | String.t() | nil) :: String.t()
  defp format_registered_at(nil), do: dgettext("dialogs", "Unknown")
  defp format_registered_at(%DateTime{} = date_time), do: DateTime.to_string(date_time)
  defp format_registered_at(value), do: to_string(value)

  @spec display_channel(String.t() | nil) :: String.t()
  defp display_channel(nil), do: "#unknown"
  defp display_channel(name), do: name

  # What a newcomer actually meets at the door, in the order they meet it.
  @spec door_lines(map()) :: [map()]
  defp door_lines(modes) do
    cond do
      Map.get(modes, :invite_only) ->
        [
          %{text: system_line(dgettext("dialogs", "cannot join")), tone: :danger},
          %{text: dgettext("dialogs", "invite only"), tone: :muted}
        ]

      Map.get(modes, :moderated) ->
        [
          %{text: system_line(dgettext("dialogs", "joined")), tone: :system},
          %{text: dgettext("dialogs", "cannot speak"), tone: :danger}
        ]

      true ->
        [
          %{text: system_line(dgettext("dialogs", "joined")), tone: :system},
          %{text: dgettext("dialogs", "hello everyone")}
        ]
    end
  end

  @spec mask_lines([map()]) :: [map()]
  defp mask_lines(entries) do
    Enum.map(entries, &%{text: Map.get(&1, :mask, ""), tone: :normal})
  end

  @spec registration_heading(boolean()) :: String.t()
  defp registration_heading(true), do: dgettext("dialogs", "ChanServ is holding this channel")
  defp registration_heading(false), do: dgettext("dialogs", "This channel is not registered")

  @spec registration_lines(map(), boolean()) :: [map()]
  defp registration_lines(_registration, false), do: []

  defp registration_lines(registration, true) do
    [
      %{text: Map.get(registration, :founder) || "", tone: :accent},
      %{text: dgettext("dialogs", "founder"), tone: :muted}
    ]
  end

  # The chat's own marker for a line nobody typed. It is punctuation, not
  # prose: inside a msgid the engine reads it as list markup and mangles the
  # sentence after it, so it is prefixed here instead.
  @spec system_line(String.t()) :: String.t()
  defp system_line(text), do: "* " <> text
end
