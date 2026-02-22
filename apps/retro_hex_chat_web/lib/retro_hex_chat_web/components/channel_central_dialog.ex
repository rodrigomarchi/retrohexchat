defmodule RetroHexChatWeb.Components.ChannelCentralDialog do
  @moduledoc """
  Channel Central dialog — retro-style tabbed dialog for channel
  administration. Shows channel info, topic, modes, bans, ban exceptions,
  and invite exceptions. Operators see editable controls; non-operators
  see a fully read-only view.
  """
  use Phoenix.Component

  alias RetroHexChatWeb.Icons

  attr :visible, :boolean, default: false
  attr :active_tab, :string, default: "general"
  attr :channel_state, :map, default: nil
  attr :operator, :boolean, default: false

  # Ban management
  attr :ban_selected, :string, default: nil
  attr :show_add_ban_dialog, :boolean, default: false

  # Ban exception management
  attr :ban_ex_selected, :string, default: nil
  attr :show_add_ban_ex_dialog, :boolean, default: false

  # Invite exception management
  attr :invite_ex_selected, :string, default: nil
  attr :show_add_invite_ex_dialog, :boolean, default: false

  # Modes form state
  attr :modes_form, :map, default: %{}
  attr :timezone, :string, default: "Etc/UTC"

  @spec channel_central_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def channel_central_dialog(assigns) do
    ~H"""
    <div
      :if={@visible and @channel_state != nil}
      class="dialog-overlay"
      data-testid="channel-central-dialog"
    >
      <div class="window dialog-window--channel-central">
        <div class="title-bar">
          <Icons.icon_dialog_channel_central class="title-bar-icon" />
          <div class="title-bar-text">
            Channel Central — {@channel_state.name}
          </div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="close_channel_central"></button>
          </div>
        </div>
        <div class="window-body u-flex-1 u-flex-col u-p-4 u-overflow-hidden">
          <menu role="tablist" class="u-mb-4 tab-menu-reset">
            <li
              role="tab"
              aria-selected={@active_tab == "general"}
              phx-click="channel_central_tab"
              phx-value-tab="general"
              data-testid="cc-tab-general"
            >
              <span class="tab-icon">
                <Icons.icon_tab_general class="btn-icon__svg" /> General
              </span>
            </li>
            <li
              role="tab"
              aria-selected={@active_tab == "modes"}
              phx-click="channel_central_tab"
              phx-value-tab="modes"
              data-testid="cc-tab-modes"
            >
              <span class="tab-icon">
                <Icons.icon_tab_modes class="btn-icon__svg" /> Modes
              </span>
            </li>
            <li
              role="tab"
              aria-selected={@active_tab == "bans"}
              phx-click="channel_central_tab"
              phx-value-tab="bans"
              data-testid="cc-tab-bans"
            >
              <span class="tab-icon">
                <Icons.icon_tab_bans class="btn-icon__svg" /> Bans
              </span>
            </li>
            <li
              role="tab"
              aria-selected={@active_tab == "ban_exceptions"}
              phx-click="channel_central_tab"
              phx-value-tab="ban_exceptions"
              data-testid="cc-tab-ban-ex"
            >
              <span class="tab-icon">
                <Icons.icon_tab_exceptions class="btn-icon__svg" /> Ban Exceptions
              </span>
            </li>
            <li
              role="tab"
              aria-selected={@active_tab == "invite_exceptions"}
              phx-click="channel_central_tab"
              phx-value-tab="invite_exceptions"
              data-testid="cc-tab-invite-ex"
            >
              <span class="tab-icon">
                <Icons.icon_tab_exceptions class="btn-icon__svg" /> Invite Exceptions
              </span>
            </li>
          </menu>

          <div role="tabpanel" class="u-flex-1 u-overflow-y-auto">
            {render_tab(assigns)}
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_tab(%{active_tab: "general"} = assigns), do: general_tab(assigns)
  defp render_tab(%{active_tab: "modes"} = assigns), do: modes_tab(assigns)
  defp render_tab(%{active_tab: "bans"} = assigns), do: bans_tab(assigns)
  defp render_tab(%{active_tab: "ban_exceptions"} = assigns), do: ban_exceptions_tab(assigns)

  defp render_tab(%{active_tab: "invite_exceptions"} = assigns),
    do: invite_exceptions_tab(assigns)

  defp render_tab(assigns), do: general_tab(assigns)

  # ── T014: General Tab ─────────────────────────────────────

  defp general_tab(assigns) do
    ~H"""
    <div data-testid="cc-general-panel" class="u-p-4">
      <fieldset>
        <legend>Channel Info</legend>
        <div class="u-text-sm">
          <div><strong>Name:</strong> {@channel_state.name}</div>
          <div><strong>Created:</strong> {format_datetime(@channel_state.created_at, @timezone)}</div>
          <div><strong>Members:</strong> {@channel_state.member_count}</div>
        </div>
      </fieldset>
      <fieldset class="u-mt-8">
        <legend>Topic</legend>
        <div :if={@operator}>
          <form phx-submit="cc_set_topic" class="u-flex-col u-gap-4">
            <textarea
              name="topic"
              rows="3"
              class="textarea-resizable u-text-sm"
              data-testid="cc-topic-input"
            >{@channel_state.topic}</textarea>
            <div class="u-flex-end u-gap-4">
              <button type="submit" data-testid="cc-set-topic-btn" class="btn-sm btn-icon">
                <Icons.icon_btn_set_topic class="btn-icon__svg" /> Set Topic
              </button>
            </div>
          </form>
        </div>
        <div :if={!@operator} class="u-text-sm">
          <div :if={@channel_state.topic != ""}>
            {@channel_state.topic}
          </div>
          <div :if={@channel_state.topic == ""} class="u-text-muted">
            No topic set
          </div>
        </div>
        <div
          :if={@channel_state.topic_set_by}
          class="u-text-xs u-text-muted u-mt-4"
        >
          Set by {@channel_state.topic_set_by}
          <span :if={@channel_state.topic_set_at}>
            at {format_datetime(@channel_state.topic_set_at, @timezone)}
          </span>
        </div>
      </fieldset>
    </div>
    """
  end

  # ── T015: Modes Tab ───────────────────────────────────────

  defp modes_tab(assigns) do
    modes_detail = assigns.channel_state.modes_detail
    form = assigns.modes_form

    assigns =
      assigns
      |> assign(:md, modes_detail)
      |> assign(:form, form)

    ~H"""
    <div data-testid="cc-modes-panel" class="u-p-4">
      <form :if={@operator} phx-submit="cc_apply_modes">
        <fieldset>
          <legend>Channel Modes</legend>
          <div class="u-flex-col u-gap-4 u-text-sm">
            <label>
              <input
                type="checkbox"
                name="moderated"
                value="true"
                checked={Map.get(@form, "moderated", @md.moderated)}
              /> Moderated (+m)
            </label>
            <label>
              <input
                type="checkbox"
                name="invite_only"
                value="true"
                checked={Map.get(@form, "invite_only", @md.invite_only)}
              /> Invite Only (+i)
            </label>
            <label>
              <input
                type="checkbox"
                name="topic_lock"
                value="true"
                checked={Map.get(@form, "topic_lock", @md.topic_lock)}
              /> Topic Lock (+t)
            </label>
            <div class="u-flex u-items-center u-gap-4">
              <label>
                <input
                  type="checkbox"
                  name="has_key"
                  value="true"
                  checked={Map.get(@form, "has_key", @md.key != nil)}
                /> Key (+k):
              </label>
              <input
                type="text"
                name="key_value"
                value={Map.get(@form, "key_value", @md.key || "")}
                class="cc-key-input"
                data-testid="cc-key-input"
              />
            </div>
            <div class="u-flex u-items-center u-gap-4">
              <label>
                <input
                  type="checkbox"
                  name="has_limit"
                  value="true"
                  checked={Map.get(@form, "has_limit", @md.limit != nil)}
                /> Limit (+l):
              </label>
              <input
                type="number"
                name="limit_value"
                min="1"
                value={Map.get(@form, "limit_value", @md.limit || "")}
                class="u-w-80"
                data-testid="cc-limit-input"
              />
            </div>
          </div>
        </fieldset>
        <div class="u-flex-end u-gap-4 u-mt-8">
          <button type="submit" data-testid="cc-apply-modes-btn" class="btn-sm btn-icon">
            <Icons.icon_btn_apply class="btn-icon__svg" /> Apply
          </button>
        </div>
      </form>
      <fieldset :if={!@operator}>
        <legend>Channel Modes</legend>
        <div class="u-flex-col u-gap-4 u-text-sm">
          <label>
            <input type="checkbox" disabled checked={@md.moderated} /> Moderated (+m)
          </label>
          <label>
            <input type="checkbox" disabled checked={@md.invite_only} /> Invite Only (+i)
          </label>
          <label>
            <input type="checkbox" disabled checked={@md.topic_lock} /> Topic Lock (+t)
          </label>
          <label>
            <input type="checkbox" disabled checked={@md.key != nil} /> Key (+k)
            <span :if={@md.key}>(set)</span>
          </label>
          <label>
            <input type="checkbox" disabled checked={@md.limit != nil} /> Limit (+l)
            <span :if={@md.limit}>({@md.limit})</span>
          </label>
        </div>
      </fieldset>
    </div>
    """
  end

  # ── T016: Bans Tab ────────────────────────────────────────

  defp bans_tab(assigns) do
    ~H"""
    <div
      data-testid="cc-bans-panel"
      class="list-tab-panel"
    >
      <div class="sunken-panel u-flex-1 u-overflow-y-auto">
        <table class="table-standard">
          <thead>
            <tr class="u-sticky-top">
              <th>Nickname</th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={nick <- @channel_state.bans}
              phx-click="cc_ban_select"
              phx-value-nickname={nick}
              class={["table-row--selectable", nick == @ban_selected && "table-row--selected"]}
              data-testid={"cc-ban-entry-#{nick}"}
            >
              <td>{nick}</td>
            </tr>
          </tbody>
        </table>
        <div :if={@channel_state.bans == []} class="table-empty">
          No bans
        </div>
      </div>
      <div :if={@operator} class="toolbar-row u-mt-4">
        <button
          phx-click="cc_open_add_ban"
          data-testid="cc-add-ban-btn"
          class="btn-sm btn-icon"
        >
          <Icons.icon_btn_add class="btn-icon__svg" /> Add Ban
        </button>
        <button
          phx-click="cc_remove_ban"
          data-testid="cc-remove-ban-btn"
          class="btn-sm btn-icon"
          disabled={is_nil(@ban_selected)}
        >
          <Icons.icon_btn_remove class="btn-icon__svg" /> Remove Ban
        </button>
      </div>
      {render_add_ban_dialog(assigns)}
    </div>
    """
  end

  defp render_add_ban_dialog(assigns) do
    ~H"""
    <div
      :if={@show_add_ban_dialog}
      class="dialog-overlay dialog-overlay--above"
      data-testid="cc-add-ban-dialog"
    >
      <div class="window dialog-window--sm">
        <div class="title-bar">
          <Icons.icon_dialog_channel_central class="title-bar-icon" />
          <div class="title-bar-text">Add Ban</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="cc_close_add_ban"></button>
          </div>
        </div>
        <div class="window-body dialog-body--p8">
          <form phx-submit="cc_add_ban">
            <div class="field-row-stacked">
              <label for="cc-ban-nick">Nickname:</label>
              <input type="text" id="cc-ban-nick" name="nickname" data-testid="cc-ban-nick-input" />
            </div>
            <div class="u-flex-end u-gap-4 u-mt-8">
              <button type="submit" class="btn-sm btn-icon">
                <Icons.icon_btn_ok class="btn-icon__svg" /> OK
              </button>
              <button type="button" phx-click="cc_close_add_ban" class="btn-sm btn-icon">
                <Icons.icon_btn_cancel class="btn-icon__svg" /> Cancel
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  # ── T017: Ban Exceptions Tab ──────────────────────────────

  defp ban_exceptions_tab(assigns) do
    ~H"""
    <div
      data-testid="cc-ban-ex-panel"
      class="list-tab-panel"
    >
      <div class="sunken-panel u-flex-1 u-overflow-y-auto">
        <table class="table-standard">
          <thead>
            <tr class="u-sticky-top">
              <th>Nickname</th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={nick <- @channel_state.ban_exceptions}
              phx-click="cc_ban_ex_select"
              phx-value-nickname={nick}
              class={["table-row--selectable", nick == @ban_ex_selected && "table-row--selected"]}
              data-testid={"cc-ban-ex-entry-#{nick}"}
            >
              <td>{nick}</td>
            </tr>
          </tbody>
        </table>
        <div :if={@channel_state.ban_exceptions == []} class="table-empty">
          No ban exceptions
        </div>
      </div>
      <div :if={@operator} class="toolbar-row u-mt-4">
        <button
          phx-click="cc_open_add_ban_ex"
          data-testid="cc-add-ban-ex-btn"
          class="btn-sm btn-icon"
        >
          <Icons.icon_btn_add class="btn-icon__svg" /> Add Exception
        </button>
        <button
          phx-click="cc_remove_ban_exception"
          data-testid="cc-remove-ban-ex-btn"
          class="btn-sm btn-icon"
          disabled={is_nil(@ban_ex_selected)}
        >
          <Icons.icon_btn_remove class="btn-icon__svg" /> Remove Exception
        </button>
      </div>
      {render_add_ban_ex_dialog(assigns)}
    </div>
    """
  end

  defp render_add_ban_ex_dialog(assigns) do
    ~H"""
    <div
      :if={@show_add_ban_ex_dialog}
      class="dialog-overlay dialog-overlay--above"
      data-testid="cc-add-ban-ex-dialog"
    >
      <div class="window dialog-window--sm">
        <div class="title-bar">
          <Icons.icon_dialog_channel_central class="title-bar-icon" />
          <div class="title-bar-text">Add Ban Exception</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="cc_close_add_ban_ex"></button>
          </div>
        </div>
        <div class="window-body dialog-body--p8">
          <form phx-submit="cc_add_ban_exception">
            <div class="field-row-stacked">
              <label for="cc-ban-ex-nick">Nickname:</label>
              <input
                type="text"
                id="cc-ban-ex-nick"
                name="nickname"
                data-testid="cc-ban-ex-nick-input"
              />
            </div>
            <div class="u-flex-end u-gap-4 u-mt-8">
              <button type="submit" class="btn-sm btn-icon">
                <Icons.icon_btn_ok class="btn-icon__svg" /> OK
              </button>
              <button type="button" phx-click="cc_close_add_ban_ex" class="btn-sm btn-icon">
                <Icons.icon_btn_cancel class="btn-icon__svg" /> Cancel
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  # ── T018: Invite Exceptions Tab ───────────────────────────

  defp invite_exceptions_tab(assigns) do
    ~H"""
    <div
      data-testid="cc-invite-ex-panel"
      class="list-tab-panel"
    >
      <div class="sunken-panel u-flex-1 u-overflow-y-auto">
        <table class="table-standard">
          <thead>
            <tr class="u-sticky-top">
              <th>Nickname</th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={nick <- @channel_state.invite_exceptions}
              phx-click="cc_invite_ex_select"
              phx-value-nickname={nick}
              class={["table-row--selectable", nick == @invite_ex_selected && "table-row--selected"]}
              data-testid={"cc-invite-ex-entry-#{nick}"}
            >
              <td>{nick}</td>
            </tr>
          </tbody>
        </table>
        <div :if={@channel_state.invite_exceptions == []} class="table-empty">
          No invite exceptions
        </div>
      </div>
      <div :if={@operator} class="toolbar-row u-mt-4">
        <button
          phx-click="cc_open_add_invite_ex"
          data-testid="cc-add-invite-ex-btn"
          class="btn-sm btn-icon"
        >
          <Icons.icon_btn_add class="btn-icon__svg" /> Add Exception
        </button>
        <button
          phx-click="cc_remove_invite_exception"
          data-testid="cc-remove-invite-ex-btn"
          class="btn-sm btn-icon"
          disabled={is_nil(@invite_ex_selected)}
        >
          <Icons.icon_btn_remove class="btn-icon__svg" /> Remove Exception
        </button>
      </div>
      {render_add_invite_ex_dialog(assigns)}
    </div>
    """
  end

  defp render_add_invite_ex_dialog(assigns) do
    ~H"""
    <div
      :if={@show_add_invite_ex_dialog}
      class="dialog-overlay dialog-overlay--above"
      data-testid="cc-add-invite-ex-dialog"
    >
      <div class="window dialog-window--sm">
        <div class="title-bar">
          <Icons.icon_dialog_channel_central class="title-bar-icon" />
          <div class="title-bar-text">Add Invite Exception</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="cc_close_add_invite_ex"></button>
          </div>
        </div>
        <div class="window-body dialog-body--p8">
          <form phx-submit="cc_add_invite_exception">
            <div class="field-row-stacked">
              <label for="cc-invite-ex-nick">Nickname:</label>
              <input
                type="text"
                id="cc-invite-ex-nick"
                name="nickname"
                data-testid="cc-invite-ex-nick-input"
              />
            </div>
            <div class="u-flex-end u-gap-4 u-mt-8">
              <button type="submit" class="btn-sm btn-icon">
                <Icons.icon_btn_ok class="btn-icon__svg" /> OK
              </button>
              <button type="button" phx-click="cc_close_add_invite_ex" class="btn-sm btn-icon">
                <Icons.icon_btn_cancel class="btn-icon__svg" /> Cancel
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  # ── Helpers ───────────────────────────────────────────────

  defp format_datetime(nil, _tz), do: "—"

  defp format_datetime(%DateTime{} = dt, tz) do
    dt |> RetroHexChatWeb.Timezone.shift(tz) |> Calendar.strftime("%Y-%m-%d %H:%M")
  end

  defp format_datetime(_, _tz), do: "—"
end
