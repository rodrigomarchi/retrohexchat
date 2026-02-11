defmodule RetroHexChatWeb.Components.ChannelCentralDialog do
  @moduledoc """
  Channel Central dialog — Windows 98-style tabbed dialog for channel
  administration. Shows channel info, topic, modes, bans, ban exceptions,
  and invite exceptions. Operators see editable controls; non-operators
  see a fully read-only view.
  """
  use Phoenix.Component

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

  @spec channel_central_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def channel_central_dialog(assigns) do
    ~H"""
    <div
      :if={@visible and @channel_state != nil}
      class="dialog-overlay"
      style="position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; z-index: 200; background: rgba(0,0,0,0.3);"
      data-testid="channel-central-dialog"
    >
      <div class="window" style="width: 520px; height: 440px; display: flex; flex-direction: column;">
        <div class="title-bar">
          <div class="title-bar-text">
            Channel Central — {@channel_state.name}
          </div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="close_channel_central"></button>
          </div>
        </div>
        <div
          class="window-body"
          style="flex: 1; display: flex; flex-direction: column; padding: 4px; overflow: hidden;"
        >
          <menu role="tablist" style="margin: 0 0 4px 0; padding: 0;">
            <li
              role="tab"
              aria-selected={@active_tab == "general"}
              phx-click="channel_central_tab"
              phx-value-tab="general"
              data-testid="cc-tab-general"
            >
              General
            </li>
            <li
              role="tab"
              aria-selected={@active_tab == "modes"}
              phx-click="channel_central_tab"
              phx-value-tab="modes"
              data-testid="cc-tab-modes"
            >
              Modes
            </li>
            <li
              role="tab"
              aria-selected={@active_tab == "bans"}
              phx-click="channel_central_tab"
              phx-value-tab="bans"
              data-testid="cc-tab-bans"
            >
              Bans
            </li>
            <li
              role="tab"
              aria-selected={@active_tab == "ban_exceptions"}
              phx-click="channel_central_tab"
              phx-value-tab="ban_exceptions"
              data-testid="cc-tab-ban-ex"
            >
              Ban Exceptions
            </li>
            <li
              role="tab"
              aria-selected={@active_tab == "invite_exceptions"}
              phx-click="channel_central_tab"
              phx-value-tab="invite_exceptions"
              data-testid="cc-tab-invite-ex"
            >
              Invite Exceptions
            </li>
          </menu>

          <div role="tabpanel" style="flex: 1; overflow: auto;">
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
    <div data-testid="cc-general-panel" style="padding: 4px;">
      <fieldset>
        <legend>Channel Info</legend>
        <div style="font-size: 11px;">
          <div><strong>Name:</strong> {@channel_state.name}</div>
          <div><strong>Created:</strong> {format_datetime(@channel_state.created_at)}</div>
          <div><strong>Members:</strong> {@channel_state.member_count}</div>
        </div>
      </fieldset>
      <fieldset style="margin-top: 8px;">
        <legend>Topic</legend>
        <div :if={@operator}>
          <form phx-submit="cc_set_topic" style="display: flex; flex-direction: column; gap: 4px;">
            <textarea
              name="topic"
              rows="3"
              style="width: 100%; resize: vertical; font-size: 11px;"
              data-testid="cc-topic-input"
            >{@channel_state.topic}</textarea>
            <div style="display: flex; justify-content: flex-end; gap: 4px;">
              <button type="submit" data-testid="cc-set-topic-btn" style="font-size: 11px;">
                Set Topic
              </button>
            </div>
          </form>
        </div>
        <div :if={!@operator} style="font-size: 11px;">
          <div :if={@channel_state.topic != ""}>
            {@channel_state.topic}
          </div>
          <div :if={@channel_state.topic == ""} style="color: #666;">
            No topic set
          </div>
        </div>
        <div
          :if={@channel_state.topic_set_by}
          style="font-size: 10px; color: #666; margin-top: 4px;"
        >
          Set by {@channel_state.topic_set_by}
          <span :if={@channel_state.topic_set_at}>
            at {format_datetime(@channel_state.topic_set_at)}
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
    <div data-testid="cc-modes-panel" style="padding: 4px;">
      <form :if={@operator} phx-submit="cc_apply_modes">
        <fieldset>
          <legend>Channel Modes</legend>
          <div style="display: flex; flex-direction: column; gap: 4px; font-size: 11px;">
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
            <div style="display: flex; align-items: center; gap: 4px;">
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
                style="width: 120px;"
                data-testid="cc-key-input"
              />
            </div>
            <div style="display: flex; align-items: center; gap: 4px;">
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
                style="width: 80px;"
                data-testid="cc-limit-input"
              />
            </div>
          </div>
        </fieldset>
        <div style="display: flex; justify-content: flex-end; gap: 4px; margin-top: 8px;">
          <button type="submit" data-testid="cc-apply-modes-btn" style="font-size: 11px;">
            Apply
          </button>
        </div>
      </form>
      <fieldset :if={!@operator}>
        <legend>Channel Modes</legend>
        <div style="display: flex; flex-direction: column; gap: 4px; font-size: 11px;">
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
      style="padding: 4px; display: flex; flex-direction: column; height: 100%;"
    >
      <div class="sunken-panel" style="flex: 1; overflow: auto;">
        <table style="width: 100%; border-collapse: collapse; font-size: 11px;">
          <thead>
            <tr style="position: sticky; top: 0; background: #c0c0c0;">
              <th style="text-align: left; padding: 2px 4px;">Nickname</th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={nick <- @channel_state.bans}
              phx-click="cc_ban_select"
              phx-value-nickname={nick}
              style={row_style(nick, @ban_selected)}
              data-testid={"cc-ban-entry-#{nick}"}
            >
              <td style="padding: 2px 4px;">{nick}</td>
            </tr>
          </tbody>
        </table>
        <div
          :if={@channel_state.bans == []}
          style="padding: 8px; text-align: center; color: #666; font-size: 11px;"
        >
          No bans
        </div>
      </div>
      <div :if={@operator} style="display: flex; gap: 4px; margin-top: 4px;">
        <button
          phx-click="cc_open_add_ban"
          data-testid="cc-add-ban-btn"
          style="font-size: 11px;"
        >
          Add Ban
        </button>
        <button
          phx-click="cc_remove_ban"
          data-testid="cc-remove-ban-btn"
          style="font-size: 11px;"
          disabled={is_nil(@ban_selected)}
        >
          Remove Ban
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
      class="dialog-overlay"
      style="position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; z-index: 210; background: rgba(0,0,0,0.5);"
      data-testid="cc-add-ban-dialog"
    >
      <div class="window" style="width: 300px;">
        <div class="title-bar">
          <div class="title-bar-text">Add Ban</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="cc_close_add_ban"></button>
          </div>
        </div>
        <div class="window-body" style="padding: 8px;">
          <form phx-submit="cc_add_ban">
            <div class="field-row-stacked">
              <label for="cc-ban-nick">Nickname:</label>
              <input type="text" id="cc-ban-nick" name="nickname" data-testid="cc-ban-nick-input" />
            </div>
            <div style="display: flex; gap: 4px; justify-content: flex-end; margin-top: 8px;">
              <button type="submit" style="font-size: 11px;">OK</button>
              <button type="button" phx-click="cc_close_add_ban" style="font-size: 11px;">
                Cancel
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
      style="padding: 4px; display: flex; flex-direction: column; height: 100%;"
    >
      <div class="sunken-panel" style="flex: 1; overflow: auto;">
        <table style="width: 100%; border-collapse: collapse; font-size: 11px;">
          <thead>
            <tr style="position: sticky; top: 0; background: #c0c0c0;">
              <th style="text-align: left; padding: 2px 4px;">Nickname</th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={nick <- @channel_state.ban_exceptions}
              phx-click="cc_ban_ex_select"
              phx-value-nickname={nick}
              style={row_style(nick, @ban_ex_selected)}
              data-testid={"cc-ban-ex-entry-#{nick}"}
            >
              <td style="padding: 2px 4px;">{nick}</td>
            </tr>
          </tbody>
        </table>
        <div
          :if={@channel_state.ban_exceptions == []}
          style="padding: 8px; text-align: center; color: #666; font-size: 11px;"
        >
          No ban exceptions
        </div>
      </div>
      <div :if={@operator} style="display: flex; gap: 4px; margin-top: 4px;">
        <button
          phx-click="cc_open_add_ban_ex"
          data-testid="cc-add-ban-ex-btn"
          style="font-size: 11px;"
        >
          Add Exception
        </button>
        <button
          phx-click="cc_remove_ban_exception"
          data-testid="cc-remove-ban-ex-btn"
          style="font-size: 11px;"
          disabled={is_nil(@ban_ex_selected)}
        >
          Remove Exception
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
      class="dialog-overlay"
      style="position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; z-index: 210; background: rgba(0,0,0,0.5);"
      data-testid="cc-add-ban-ex-dialog"
    >
      <div class="window" style="width: 300px;">
        <div class="title-bar">
          <div class="title-bar-text">Add Ban Exception</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="cc_close_add_ban_ex"></button>
          </div>
        </div>
        <div class="window-body" style="padding: 8px;">
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
            <div style="display: flex; gap: 4px; justify-content: flex-end; margin-top: 8px;">
              <button type="submit" style="font-size: 11px;">OK</button>
              <button type="button" phx-click="cc_close_add_ban_ex" style="font-size: 11px;">
                Cancel
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
      style="padding: 4px; display: flex; flex-direction: column; height: 100%;"
    >
      <div class="sunken-panel" style="flex: 1; overflow: auto;">
        <table style="width: 100%; border-collapse: collapse; font-size: 11px;">
          <thead>
            <tr style="position: sticky; top: 0; background: #c0c0c0;">
              <th style="text-align: left; padding: 2px 4px;">Nickname</th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={nick <- @channel_state.invite_exceptions}
              phx-click="cc_invite_ex_select"
              phx-value-nickname={nick}
              style={row_style(nick, @invite_ex_selected)}
              data-testid={"cc-invite-ex-entry-#{nick}"}
            >
              <td style="padding: 2px 4px;">{nick}</td>
            </tr>
          </tbody>
        </table>
        <div
          :if={@channel_state.invite_exceptions == []}
          style="padding: 8px; text-align: center; color: #666; font-size: 11px;"
        >
          No invite exceptions
        </div>
      </div>
      <div :if={@operator} style="display: flex; gap: 4px; margin-top: 4px;">
        <button
          phx-click="cc_open_add_invite_ex"
          data-testid="cc-add-invite-ex-btn"
          style="font-size: 11px;"
        >
          Add Exception
        </button>
        <button
          phx-click="cc_remove_invite_exception"
          data-testid="cc-remove-invite-ex-btn"
          style="font-size: 11px;"
          disabled={is_nil(@invite_ex_selected)}
        >
          Remove Exception
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
      class="dialog-overlay"
      style="position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; z-index: 210; background: rgba(0,0,0,0.5);"
      data-testid="cc-add-invite-ex-dialog"
    >
      <div class="window" style="width: 300px;">
        <div class="title-bar">
          <div class="title-bar-text">Add Invite Exception</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="cc_close_add_invite_ex"></button>
          </div>
        </div>
        <div class="window-body" style="padding: 8px;">
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
            <div style="display: flex; gap: 4px; justify-content: flex-end; margin-top: 8px;">
              <button type="submit" style="font-size: 11px;">OK</button>
              <button type="button" phx-click="cc_close_add_invite_ex" style="font-size: 11px;">
                Cancel
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  # ── Helpers ───────────────────────────────────────────────

  defp row_style(nick, selected) do
    if nick == selected do
      "background: #000080; color: #ffffff; cursor: pointer;"
    else
      "cursor: pointer;"
    end
  end

  defp format_datetime(nil), do: "—"

  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  end

  defp format_datetime(_), do: "—"
end
