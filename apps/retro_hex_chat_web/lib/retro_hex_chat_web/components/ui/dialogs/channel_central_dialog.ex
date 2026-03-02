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
  attr :modes, :map, default: %{}
  attr :bans, :list, default: []
  attr :ban_exceptions, :list, default: []
  attr :invite_exceptions, :list, default: []
  attr :ban_selected, :string, default: nil
  attr :ban_ex_selected, :string, default: nil
  attr :invite_ex_selected, :string, default: nil
  attr :on_tab, :any, default: nil, doc: "Tab switch event (phx-value-tab=value)"
  attr :on_topic_save, :any, default: nil
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
            <.tabs_trigger
              builder={builder}
              value="general"
              phx-click={@on_tab}
              phx-value-tab="general"
            >
              <:icon><Icons.icon_tab_general class="w-4 h-4" /></:icon>
              General
            </.tabs_trigger>
            <.tabs_trigger
              builder={builder}
              value="modes"
              phx-click={@on_tab}
              phx-value-tab="modes"
            >
              <:icon><Icons.icon_tab_modes class="w-4 h-4" /></:icon>
              Modes
            </.tabs_trigger>
            <.tabs_trigger
              builder={builder}
              value="bans"
              phx-click={@on_tab}
              phx-value-tab="bans"
            >
              <:icon><Icons.icon_tab_bans class="w-4 h-4" /></:icon>
              Bans
            </.tabs_trigger>
            <.tabs_trigger
              builder={builder}
              value="ban_exceptions"
              phx-click={@on_tab}
              phx-value-tab="ban_exceptions"
            >
              <:icon><Icons.icon_tab_exceptions class="w-4 h-4" /></:icon>
              Ban Exc.
            </.tabs_trigger>
            <.tabs_trigger
              builder={builder}
              value="invite_exceptions"
              phx-click={@on_tab}
              phx-value-tab="invite_exceptions"
            >
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
              on_select={@on_ban_select}
              empty_label="No bans set on this channel."
            />
          </.tabs_content>

          <.tabs_content value="ban_exceptions">
            <.list_tab
              entries={@ban_exceptions}
              selected={@ban_ex_selected}
              operator={@operator}
              on_add={@on_ban_ex_add}
              on_remove={@on_ban_ex_remove}
              on_select={@on_ban_ex_select}
              empty_label="No ban exceptions set."
            />
          </.tabs_content>

          <.tabs_content value="invite_exceptions">
            <.list_tab
              entries={@invite_exceptions}
              selected={@invite_ex_selected}
              operator={@operator}
              on_add={@on_invite_ex_add}
              on_remove={@on_invite_ex_remove}
              on_select={@on_invite_ex_select}
              empty_label="No invite exceptions set."
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

    <%!-- Ban Add Sub-Dialog --%>
    <.ban_add_sub_form :if={@show_add_ban_dialog} />
    <%!-- Ban Exception Add Sub-Dialog --%>
    <.ban_ex_add_sub_form :if={@show_add_ban_ex_dialog} />
    <%!-- Invite Exception Add Sub-Dialog --%>
    <.invite_ex_add_sub_form :if={@show_add_invite_ex_dialog} />
    """
  end

  # ── Sub-Forms ─────────────────────────────────────────

  defp ban_add_sub_form(assigns) do
    ~H"""
    <div class="dialog-overlay dialog-overlay--above" data-testid="cc-add-ban-dialog">
      <div class="window dialog-window--sm">
        <div class="title-bar">
          <div class="title-bar-text">Add Ban</div>
          <div class="title-bar-controls">
            <button type="button" aria-label="Close" phx-click="cc_close_add_ban" />
          </div>
        </div>
        <div class="window-body dialog-body--p8">
          <form phx-submit="cc_add_ban">
            <div class="field-row-stacked">
              <label class="text-xs font-bold" for="cc-ban-nick">Hostmask:</label>
              <.input
                type="text"
                id="cc-ban-nick"
                name="nickname"
                autofocus
                class="u-w-full"
                data-testid="cc-ban-nick-input"
              />
            </div>
            <div class="u-flex-end u-gap-4 u-mt-8">
              <.button type="submit" size="sm">
                <:icon><Icons.icon_checkmark /></:icon>
                OK
              </.button>
              <.button type="button" size="sm" variant="outline" phx-click="cc_close_add_ban">
                <:icon><Icons.icon_close /></:icon>
                Cancel
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
    <div class="dialog-overlay dialog-overlay--above" data-testid="cc-add-ban-ex-dialog">
      <div class="window dialog-window--sm">
        <div class="title-bar">
          <div class="title-bar-text">Add Ban Exception</div>
          <div class="title-bar-controls">
            <button type="button" aria-label="Close" phx-click="cc_close_add_ban_ex" />
          </div>
        </div>
        <div class="window-body dialog-body--p8">
          <form phx-submit="cc_add_ban_exception">
            <div class="field-row-stacked">
              <label class="text-xs font-bold" for="cc-ban-ex-nick">Hostmask:</label>
              <.input
                type="text"
                id="cc-ban-ex-nick"
                name="nickname"
                autofocus
                class="u-w-full"
                data-testid="cc-ban-ex-nick-input"
              />
            </div>
            <div class="u-flex-end u-gap-4 u-mt-8">
              <.button type="submit" size="sm">
                <:icon><Icons.icon_checkmark /></:icon>
                OK
              </.button>
              <.button type="button" size="sm" variant="outline" phx-click="cc_close_add_ban_ex">
                <:icon><Icons.icon_close /></:icon>
                Cancel
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
    <div class="dialog-overlay dialog-overlay--above" data-testid="cc-add-invite-ex-dialog">
      <div class="window dialog-window--sm">
        <div class="title-bar">
          <div class="title-bar-text">Add Invite Exception</div>
          <div class="title-bar-controls">
            <button type="button" aria-label="Close" phx-click="cc_close_add_invite_ex" />
          </div>
        </div>
        <div class="window-body dialog-body--p8">
          <form phx-submit="cc_add_invite_exception">
            <div class="field-row-stacked">
              <label class="text-xs font-bold" for="cc-invite-ex-nick">Hostmask:</label>
              <.input
                type="text"
                id="cc-invite-ex-nick"
                name="nickname"
                autofocus
                class="u-w-full"
                data-testid="cc-invite-ex-nick-input"
              />
            </div>
            <div class="u-flex-end u-gap-4 u-mt-8">
              <.button type="submit" size="sm">
                <:icon><Icons.icon_checkmark /></:icon>
                OK
              </.button>
              <.button
                type="button"
                size="sm"
                variant="outline"
                phx-click="cc_close_add_invite_ex"
              >
                <:icon><Icons.icon_close /></:icon>
                Cancel
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

      <form :if={@operator} phx-submit={@on_topic_save}>
        <label class="text-xs font-bold block mb-1">Topic:</label>
        <.input
          type="text"
          name="topic"
          value={@topic}
          placeholder="No topic set"
          class="text-xs h-8"
        />
        <div :if={@topic_set_by} class="text-[10px] text-muted-foreground mt-1">
          Set by {@topic_set_by}
          <span :if={@topic_set_at}>on {@topic_set_at}</span>
        </div>
        <.button type="submit" size="sm" class="mt-2">
          <:icon><Icons.icon_btn_set_topic /></:icon>
          Save Topic
        </.button>
      </form>

      <div :if={!@operator}>
        <label class="text-xs font-bold block mb-1">Topic:</label>
        <.input
          type="text"
          name="topic"
          value={@topic}
          placeholder="No topic set"
          disabled
          class="text-xs h-8"
        />
        <div :if={@topic_set_by} class="text-[10px] text-muted-foreground mt-1">
          Set by {@topic_set_by}
          <span :if={@topic_set_at}>on {@topic_set_at}</span>
        </div>
        <p class="text-[10px] text-muted-foreground italic mt-2">
          You must be a channel operator to edit the topic.
        </p>
      </div>
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
          <p class="text-xs font-bold mb-2">Channel Modes:</p>

          <div class="space-y-1">
            <label class="inline-flex items-center gap-2 text-xs cursor-pointer">
              <input
                type="checkbox"
                name="moderated"
                value="true"
                checked={@modes[:moderated] || false}
              /> Moderated (+m)
            </label>
          </div>
          <div class="space-y-1 mt-1">
            <label class="inline-flex items-center gap-2 text-xs cursor-pointer">
              <input
                type="checkbox"
                name="invite_only"
                value="true"
                checked={@modes[:invite_only] || false}
              /> Invite Only (+i)
            </label>
          </div>
          <div class="space-y-1 mt-1">
            <label class="inline-flex items-center gap-2 text-xs cursor-pointer">
              <input
                type="checkbox"
                name="topic_lock"
                value="true"
                checked={@modes[:topic_lock] || false}
              /> Topic Lock (+t)
            </label>
          </div>

          <div class="mt-2 flex items-center gap-2">
            <label class="inline-flex items-center gap-2 text-xs cursor-pointer">
              <input
                type="checkbox"
                name="has_key"
                value="true"
                checked={@modes[:key] != nil}
              /> Key (+k):
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
              /> Limit (+l):
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
          Apply Modes
        </.button>
      </form>

      <div :if={!@operator} class="shadow-retro-field bg-white p-2">
        <p class="text-xs font-bold mb-2">Channel Modes:</p>
        <div class="space-y-1">
          <label class="inline-flex items-center gap-2 text-xs opacity-50">
            <input type="checkbox" disabled checked={@modes[:moderated] || false} /> Moderated (+m)
          </label>
        </div>
        <div class="space-y-1 mt-1">
          <label class="inline-flex items-center gap-2 text-xs opacity-50">
            <input type="checkbox" disabled checked={@modes[:invite_only] || false} />
            Invite Only (+i)
          </label>
        </div>
        <div class="space-y-1 mt-1">
          <label class="inline-flex items-center gap-2 text-xs opacity-50">
            <input type="checkbox" disabled checked={@modes[:topic_lock] || false} /> Topic Lock (+t)
          </label>
        </div>
        <div class="mt-1">
          <label class="inline-flex items-center gap-2 text-xs opacity-50">
            <input type="checkbox" disabled checked={@modes[:key] != nil} /> Key (+k)
            <span :if={@modes[:key]}>(set)</span>
          </label>
        </div>
        <div class="mt-1">
          <label class="inline-flex items-center gap-2 text-xs opacity-50">
            <input type="checkbox" disabled checked={@modes[:limit] != nil} /> Limit (+l)
            <span :if={@modes[:limit]}>({@modes[:limit]})</span>
          </label>
        </div>
        <p class="text-[10px] text-muted-foreground italic mt-2">
          You must be a channel operator to change modes.
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
  attr :empty_label, :string, default: "No entries."

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
