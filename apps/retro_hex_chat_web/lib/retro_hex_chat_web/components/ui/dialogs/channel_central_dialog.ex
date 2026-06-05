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

  @spec display_channel(String.t() | nil) :: String.t()
  defp display_channel(nil), do: "#unknown"
  defp display_channel(name), do: name
end
