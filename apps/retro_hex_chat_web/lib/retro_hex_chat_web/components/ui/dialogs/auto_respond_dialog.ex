defmodule RetroHexChatWeb.Components.UI.AutoRespondDialog do
  @moduledoc """
  Auto-respond rules CRUD dialog component for the showcase design system.

  Composed from dialog + table + button + input + checkbox primitives.
  List of auto-respond rules with trigger type, channel filter, and command.
  Supports Add/Edit/Remove and an inline edit form panel.

  ## Usage

      <.auto_respond_dialog
        id="auto-respond"
        show={true}
        rules={@rules}
        on_select="ar-select"
        on_add="ar-add"
        on_close="ar-close"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Table
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Checkbox
  import RetroHexChatWeb.Components.UI.Label
  import RetroHexChatWeb.Components.UI.Select

  alias RetroHexChatWeb.Icons

  @trigger_labels %{
    "on_join" => "On Join",
    "on_part" => "On Part",
    "on_nick_change" => "On Nick Change"
  }

  @doc "Renders the auto-respond rules dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false

  attr :rules, :list,
    default: [],
    doc: "List of %{trigger, channel, command, enabled, position} maps"

  attr :selected_position, :integer, default: nil, doc: "Currently selected rule position"
  attr :editing, :boolean, default: false, doc: "True when edit form is visible"
  attr :draft_trigger, :string, default: "on_join", doc: "Draft trigger type for edit form"
  attr :draft_channel, :string, default: "", doc: "Draft channel filter for edit form"
  attr :draft_command, :string, default: "", doc: "Draft command for edit form"
  attr :error_message, :string, default: nil, doc: "Validation error to display in the form"

  attr :on_select, :any, default: nil, doc: "Row click callback (phx-value-position)"
  attr :on_toggle, :any, default: nil, doc: "Enable checkbox callback (phx-value-position)"
  attr :on_add, :any, default: nil, doc: "Add button callback"
  attr :on_edit, :any, default: nil, doc: "Edit button callback"
  attr :on_delete, :any, default: nil, doc: "Remove button callback"
  attr :on_save, :any, default: nil, doc: "Save edit callback"
  attr :on_cancel_edit, :any, default: nil, doc: "Cancel edit callback"
  attr :on_close, :any, default: nil, doc: "Close (X) button callback"

  @spec auto_respond_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def auto_respond_dialog(assigns) do
    ~H"""
    <.dialog id={@id} show={@show}>
      <.dialog_header id={@id} title="Auto Respond">
        <:icon><Icons.icon_dialog_auto_respond class="w-4 h-4" /></:icon>
      </.dialog_header>

      <.dialog_body class="flex gap-retro-8 min-h-[260px]">
        <%!-- Rules list --%>
        <div class="flex-1 space-y-retro-4">
          <div class="max-h-[200px] overflow-y-auto retro-scrollbar">
            <.table>
              <.table_header>
                <.table_row>
                  <.table_head class="w-[40px]">Enable</.table_head>
                  <.table_head>Trigger</.table_head>
                  <.table_head>Channel</.table_head>
                  <.table_head>Command</.table_head>
                </.table_row>
              </.table_header>
              <.table_body>
                <.table_row
                  :for={rule <- @rules}
                  class={
                    if(@selected_position == rule.position,
                      do: "bg-selection-bg text-selection-fg",
                      else: ""
                    )
                  }
                  phx-click={@on_select}
                  phx-value-position={rule.position}
                >
                  <.table_cell>
                    <.checkbox
                      value={Map.get(rule, :enabled, true)}
                      phx-click={@on_toggle}
                      phx-value-position={rule.position}
                    />
                  </.table_cell>
                  <.table_cell>{trigger_label(Map.get(rule, :trigger, "on_join"))}</.table_cell>
                  <.table_cell>{Map.get(rule, :channel, "")}</.table_cell>
                  <.table_cell class="font-mono text-[11px]">
                    {Map.get(rule, :command, "")}
                  </.table_cell>
                </.table_row>
              </.table_body>
            </.table>
          </div>

          <div class="flex gap-retro-4">
            <.button size="sm" variant="outline" phx-click={@on_add}>
              <:icon><Icons.icon_btn_add class="w-4 h-4" /></:icon>
              Add
            </.button>
            <.button
              size="sm"
              variant="outline"
              phx-click={@on_edit}
              disabled={@selected_position == nil}
            >
              <:icon><Icons.icon_btn_edit class="w-4 h-4" /></:icon>
              Edit
            </.button>
            <.button
              size="sm"
              variant="outline"
              phx-click={@on_delete}
              disabled={@selected_position == nil}
            >
              <:icon><Icons.icon_btn_remove class="w-4 h-4" /></:icon>
              Remove
            </.button>
          </div>
        </div>

        <%!-- Edit form panel --%>
        <form
          :if={@editing}
          phx-submit={@on_save}
          class="w-[220px] shrink-0 shadow-retro-field bg-white p-retro-8 space-y-retro-8"
        >
          <h3 class="font-bold text-xs mb-retro-4">
            {if @selected_position == nil, do: "Add Rule", else: "Edit Rule"}
          </h3>

          <div class="space-y-retro-4">
            <div>
              <.label class="text-xs font-bold block mb-retro-2">Trigger</.label>
              <.select
                :let={builder}
                id="draft-trigger-select"
                name="trigger"
                value={@draft_trigger}
                label={trigger_label(@draft_trigger)}
                class="w-full"
              >
                <.select_trigger builder={builder} class="h-8 text-xs" />
                <.select_content builder={builder}>
                  <.select_group>
                    <.select_item
                      :for={{key, lbl} <- trigger_options()}
                      builder={builder}
                      value={key}
                      label={lbl}
                    >
                      {lbl}
                    </.select_item>
                  </.select_group>
                </.select_content>
              </.select>
            </div>

            <div>
              <.label class="text-xs font-bold block mb-retro-2">Channel (optional)</.label>
              <.input
                type="text"
                name="channel"
                value={@draft_channel}
                placeholder="#channel"
                class="w-full"
                maxlength="50"
              />
            </div>

            <div>
              <.label class="text-xs font-bold block mb-retro-2">Command</.label>
              <.input
                type="text"
                name="command"
                value={@draft_command}
                placeholder="/say Hello!"
                class="w-full"
                maxlength="500"
              />
            </div>

            <p :if={@error_message} class="text-xs text-destructive">{@error_message}</p>

            <div class="flex gap-retro-4 pt-retro-4">
              <.button type="submit" size="sm" variant="default">
                <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
                Save
              </.button>
              <.button type="button" size="sm" variant="outline" phx-click={@on_cancel_edit}>
                <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
                Cancel
              </.button>
            </div>
          </div>
        </form>
      </.dialog_body>

      <.dialog_footer>
        <.button variant="default" phx-click={@on_close || hide_modal(@id)}>
          <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
          OK
        </.button>
        <.button variant="outline" phx-click={@on_close || hide_modal(@id)}>
          <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
          Cancel
        </.button>
      </.dialog_footer>
    </.dialog>
    """
  end

  @spec trigger_label(String.t()) :: String.t()
  defp trigger_label(trigger), do: Map.get(@trigger_labels, trigger, trigger)

  @spec trigger_options() :: [{String.t(), String.t()}]
  defp trigger_options do
    Enum.map(@trigger_labels, fn {k, v} -> {k, v} end)
  end
end
