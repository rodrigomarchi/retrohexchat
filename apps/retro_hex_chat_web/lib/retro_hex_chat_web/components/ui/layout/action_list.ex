defmodule RetroHexChatWeb.Components.UI.ActionList do
  @moduledoc """
  A list whose row is a control.

  Pressing a row does the thing the row is about — enter this channel, open this
  alias for editing. Everything else the row can do is a button on the row
  itself, beside its own subject.

  The alternative shape, a list that only paints a selection plus a button row
  underneath acting on "the selected item", costs two gestures for one intention
  and leaves the button without a subject until something is picked. The app
  already decided against it where a channel is picked from the sidebar tree:
  pressing a channel you are not in joins it.

  ## What lives where

    * **The row's own action** is the press. `on_activate` is required — a row
      that does nothing on press is a table row, and that is `UI.Table`.
    * **A second action on the same subject** — remove, stop, reorder — is an
      `<:action>`, rendered on the row.
    * **An action with no subject** — add, import — is not part of this list. It
      belongs to the panel around it, and stays in the panel's own button row.

  ## Structure, and why it is not one button

  A row is an `<li>` holding two siblings: the primary `<button>` and, when the
  caller passes any, a group of action buttons. It cannot be a single `<button>`
  wrapping the others — nested buttons are invalid HTML and the inner press has
  no defined behaviour. The primary stretches to fill whatever the actions leave,
  so the touch target is the row minus its controls.

  Actions are always visible. Touch has no hover, and an action revealed by
  hover is an action a finger cannot find (`docs/guide/mobile-touch.md`).

  ## Saying what the press does

  A row whose subject already implies the press — an alias you open to edit —
  needs no verb. A row where the press has consequences the reader would want
  named, or where neighbouring rows do different things, passes a `<:cta>`: it
  draws the verb on the row and the press stays the whole row. That is the
  difference between moving a button onto the row and deleting it.

  The `<:cta>` is a real `UI.Button` sitting beside the primary press, not a
  span wearing a button's face: the row would otherwise carry a second
  hand-drawn bevel that drifts from the one every other control in the app
  shares. It sends the row's own event, so pressing the row and pressing the
  verb are the same act — the button is the one the eye finds and the row is the
  larger target around it.

  ## Selection

  `current` marks the row a side panel is editing — a real state, and the reason
  the two-column dialogs keep a highlight. It renders `aria-current`, not
  `aria-pressed`: the row is not a toggle that stays down, it is a control that
  fires.

  ## Usage

      <.action_list id="channel-list" label={dgettext("dialogs", "Channels")}>
        <.action_row
          :for={entry <- @entries}
          id={"channel-list-row-\#{entry.name}"}
          on_activate={@on_join}
          value={%{"channel" => entry.name}}
          current={@editing == entry.name}
        >
          <:icon><Icons.icon_channels class="w-4 h-4" /></:icon>
          <:title>{entry.name}</:title>
          <:meta>{entry.topic}</:meta>
          <:action
            event={@on_remove}
            value={%{"channel" => entry.name}}
            label={dgettext("dialogs", "Remove %{channel}", channel: entry.name)}
            variant="destructive"
          >
            <Icons.icon_btn_remove class="w-4 h-4" />
          </:action>
        </.action_row>
      </.action_list>

  An empty list renders nothing here — the caller shows `list_empty_state/1`
  from `UI.ListStates`, which every list in the app already shares.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button

  @doc """
  The list that holds `action_row/1` children.

  `label` names the list for assistive technology; it is required because a
  bare list of rows in a dialog that holds more than one list is ambiguous.
  """
  attr :id, :string, required: true
  attr :label, :string, required: true, doc: "accessible name for the list"
  attr :class, :any, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  @spec action_list(map()) :: Phoenix.LiveView.Rendered.t()
  def action_list(assigns) do
    ~H"""
    <ul id={@id} class={classes(["action-list", @class])} aria-label={@label} {@rest}>
      {render_slot(@inner_block)}
    </ul>
    """
  end

  @doc """
  One row: a press that acts, and the buttons for anything else it can do.
  """
  attr :id, :string, default: nil
  attr :on_activate, :any, required: true, doc: "event the row press sends"
  attr :value, :map, default: %{}, doc: "params for the press, as phx-value-*"
  attr :target, :any, default: nil, doc: "phx-target for the row and its actions"

  attr :current, :boolean,
    default: false,
    doc: "true when a side panel is editing this row"

  attr :class, :any, default: nil
  attr :rest, :global

  slot :icon, doc: "leading 16×16 icon"
  slot :title, required: true, doc: "what the row is — the line that names it"
  slot :meta, doc: "supporting detail, rendered under the title"
  slot :trailing, doc: "figures that belong to the row, rendered before the actions"

  slot :cta, doc: "the verb for the press, as a button on the row; the block is its icon" do
    attr :label, :string, required: true
    attr :variant, :string, values: ~w(default secondary destructive outline ghost)
    attr :testid, :string
  end

  slot :action, doc: "a second action on this row's subject; the block is its icon" do
    attr :event, :any, required: true
    attr :value, :map
    attr :label, :string, required: true, doc: "accessible name — the control is icon-only"
    attr :variant, :string, values: ~w(default secondary destructive outline ghost)
    attr :target, :any, doc: "overrides the row's target"
    attr :disabled, :boolean
    attr :testid, :string
  end

  @spec action_row(map()) :: Phoenix.LiveView.Rendered.t()
  def action_row(assigns) do
    ~H"""
    <li
      id={@id}
      class={
        classes([
          "action-list__row",
          @current && "action-list__row--current",
          @class
        ])
      }
      aria-current={@current && "true"}
      {@rest}
    >
      <button
        type="button"
        class="action-list__primary"
        phx-click={@on_activate}
        phx-target={@target}
        {phx_values(@value)}
      >
        <span :if={@icon != []} class="action-list__icon" aria-hidden="true">
          {render_slot(@icon)}
        </span>
        <span class="action-list__copy">
          <span class="action-list__title">{render_slot(@title)}</span>
          <span :if={@meta != []} class="action-list__meta">{render_slot(@meta)}</span>
        </span>
        <span :if={@trailing != []} class="action-list__trailing">
          {render_slot(@trailing)}
        </span>
      </button>

      <span :if={@cta != [] or @action != []} class="action-list__actions">
        <.button
          :for={cta <- @cta}
          type="button"
          size="sm"
          variant={Map.get(cta, :variant, "default")}
          class="action-list__cta"
          phx-click={@on_activate}
          phx-target={@target}
          data-testid={Map.get(cta, :testid)}
          {phx_values(@value)}
        >
          <:icon>{render_slot(cta)}</:icon>
          {cta.label}
        </.button>
        <.button
          :for={action <- @action}
          type="button"
          size="icon"
          variant={Map.get(action, :variant, "outline")}
          class="action-list__action"
          phx-click={action.event}
          phx-target={Map.get(action, :target) || @target}
          disabled={Map.get(action, :disabled, false)}
          aria-label={action.label}
          title={action.label}
          data-testid={Map.get(action, :testid)}
          {phx_values(Map.get(action, :value, %{}))}
        >
          <:icon>{render_slot(action)}</:icon>
          <span class="sr-only">{action.label}</span>
        </.button>
      </span>
    </li>
    """
  end

  @doc """
  A labelled figure for a row's `<:trailing>` — how many people are in there,
  when it was last used, which mode it carries.

  Every migrated list needs the same chip, and each dialog had been drawing its
  own (`cl-meta-item`, and a near-identical box in the others). One component so
  they cannot drift apart.
  """
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :rest, :global

  @spec action_figure(map()) :: Phoenix.LiveView.Rendered.t()
  def action_figure(assigns) do
    ~H"""
    <span class="action-list__figure" {@rest}>
      <span class="action-list__figure-label">{@label}</span>
      <span class="action-list__figure-value">{@value}</span>
    </span>
    """
  end

  # Params travel as `phx-value-*`, and the caller names them in a map rather
  # than spelling each attribute out, so a row that carries two params reads the
  # same as a row that carries one.
  @spec phx_values(map()) :: list()
  defp phx_values(values) do
    Enum.map(values, fn {key, value} -> {"phx-value-#{key}", value} end)
  end
end
