defmodule RetroHexChatWeb.Components.UI.AutoRespondDialog do
  @moduledoc """
  Auto-respond rules CRUD dialog component for the showcase design system.

  Composed from dialog + button + input + checkbox primitives.
  List of auto-respond rules with trigger type, channel filter, and command.
  Supports Add/Edit/Remove and an inline edit form panel.

  ## Usage

      <.auto_respond_dialog
        id="auto-respond"
        show={true}
        rules={@rules}
        on_add="ar-add"
        on_close="ar-close"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.ActionList
  import RetroHexChatWeb.Components.UI.DialogBanner
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Textarea
  import RetroHexChatWeb.Components.UI.Checkbox
  import RetroHexChatWeb.Components.UI.Label
  import RetroHexChatWeb.Components.UI.Select

  alias RetroHexChatWeb.Components.Diagrams
  alias RetroHexChatWeb.Icons

  @trigger_keys ~w(on_join on_part on_nick_change)

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
    <.dialog id={@id} show={@show} on_cancel={@on_close}>
      <.dialog_header id={@id} title={dgettext("dialogs", "Auto Respond")} on_close={@on_close}>
        <:icon><Icons.icon_dialog_auto_respond class="w-4 h-4" /></:icon>
      </.dialog_header>

      <.dialog_body>
        <.auto_respond_panel
          id={@id}
          rules={@rules}
          selected_position={@selected_position}
          editing={@editing}
          draft_trigger={@draft_trigger}
          draft_channel={@draft_channel}
          draft_command={@draft_command}
          error_message={@error_message}
          on_toggle={@on_toggle}
          on_add={@on_add}
          on_edit={@on_edit}
          on_delete={@on_delete}
          on_save={@on_save}
          on_cancel_edit={@on_cancel_edit}
        />
      </.dialog_body>
    </.dialog>
    """
  end

  @doc """
  Renders the auto-respond rules editor (list + edit form) without any frame — compose it inside a dialog or a
  desktop window body.
  """
  attr :id, :string, required: true
  attr :rules, :any, default: nil
  attr :selected_position, :any, default: nil
  attr :editing, :any, default: nil
  attr :draft_trigger, :any, default: nil
  attr :draft_channel, :any, default: nil
  attr :draft_command, :any, default: nil
  attr :error_message, :any, default: nil
  attr :on_toggle, :any, default: nil
  attr :on_add, :any, default: nil
  attr :on_edit, :any, default: nil
  attr :on_delete, :any, default: nil
  attr :on_save, :any, default: nil
  attr :on_cancel_edit, :any, default: nil

  @spec auto_respond_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def auto_respond_panel(assigns) do
    assigns = assign(assigns, :respond_lines, respond_lines(assigns.rules))

    ~H"""
    <div id={"#{@id}-panel-root"} class="contents">
      <.focus_wrap id={"#{@id}-focus-wrap"} class="contents">
        <div
          id={"#{@id}-content"}
          data-testid="auto-respond-panel"
          role="dialog"
          aria-modal="false"
          tabindex="0"
          phx-mounted={JS.focus(to: "##{@id}-content")}
          class="ar-dialog flex h-full min-h-0 flex-col gap-retro-8"
        >
          <.dialog_banner heading={dgettext("dialogs", "What the room sees you do")}>
            <:art>
              <Diagrams.diagram_dialog_preview
                title={dgettext("dialogs", "Channel")}
                kind={:query}
                lines={@respond_lines}
                label={dgettext("dialogs", "A miniature of a rule firing in a channel")}
              />
            </:art>
            <:glyph><Icons.icon_dialog_auto_respond class="h-8 w-8" /></:glyph>
            {dgettext(
              "dialogs",
              "A rule watches for something happening in a channel and answers with a command. Everyone present sees the answer — it is you talking, not a note to yourself."
            )}
          </.dialog_banner>

          <div class={
            classes([
              "ar-editor min-h-0 flex-1",
              @editing && "ar-editor--editing"
            ])
          }>
            <div class="ar-list-pane min-h-0">
              <div class="ar-rule-list overflow-y-auto">
                <div :if={@rules == []} class="ar-empty-state text-center text-muted-foreground">
                  {dgettext("dialogs", "No auto-respond rules configured. Click Add to create one.")}
                </div>

                <.action_list
                  :if={@rules != []}
                  id={"#{@id}-rules"}
                  label={dgettext("dialogs", "Auto Respond")}
                >
                  <.action_row
                    :for={rule <- @rules}
                    on_activate={@on_edit}
                    value={%{"position" => rule.position}}
                    current={@selected_position == rule.position}
                    data-testid="autorespond-rule-row"
                    data-position={rule.position}
                  >
                    <:title>{trigger_label(rule_trigger(rule))}</:title>
                    <:meta>
                      <code class="ar-rule-command">{Map.get(rule, :command, "")}</code>
                    </:meta>
                    <:trailing>
                      <.action_figure
                        label={dgettext("dialogs", "Channel")}
                        value={rule_channel_label(rule)}
                      />
                      <.action_figure
                        label={dgettext("dialogs", "Position")}
                        value={rule.position}
                      />
                    </:trailing>
                    <:control>
                      <.checkbox
                        value={rule_enabled?(rule)}
                        phx-click={@on_toggle}
                        phx-value-position={rule.position}
                        aria-label={rule_accessible_name(rule)}
                      />
                      <span>
                        {if rule_enabled?(rule),
                          do: dgettext("dialogs", "On"),
                          else: dgettext("dialogs", "Off")}
                      </span>
                    </:control>
                    <:action
                      event={@on_delete}
                      value={%{"position" => rule.position}}
                      label={dgettext("dialogs", "Remove rule %{position}", position: rule.position)}
                      variant="destructive"
                      testid={"autorespond-remove-#{rule.position}"}
                    >
                      <Icons.icon_btn_remove class="w-4 h-4" />
                    </:action>
                  </.action_row>
                </.action_list>
              </div>

              <div class="ar-action-row flex gap-retro-4">
                <.button
                  size="sm"
                  variant="outline"
                  phx-click={@on_add}
                  class="ar-action-button"
                >
                  <:icon><Icons.icon_btn_add class="w-4 h-4" /></:icon>
                  {dgettext("dialogs", "Add")}
                </.button>
              </div>
            </div>

            <form
              :if={@editing}
              phx-submit={@on_save}
              data-testid="autorespond-edit-form"
              class="ar-edit-form shadow-retro-field bg-white p-retro-8"
            >
              <h3 class="font-bold text-xs">
                {if @selected_position == nil,
                  do: dgettext("dialogs", "Add Rule"),
                  else: dgettext("dialogs", "Edit Rule")}
              </h3>

              <div class="ar-form-fields">
                <div class="ar-field">
                  <.label class="ar-form-label">
                    {dgettext("dialogs", "Trigger")}
                  </.label>
                  <.select
                    :let={builder}
                    id="draft-trigger-select"
                    name="trigger"
                    value={@draft_trigger}
                    label={trigger_label(@draft_trigger)}
                    class="ar-input w-full"
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

                <div class="ar-field">
                  <.label class="ar-form-label">
                    {dgettext("dialogs", "Channel (optional)")}
                  </.label>
                  <.input
                    type="text"
                    name="channel"
                    value={@draft_channel}
                    placeholder="#channel"
                    class="ar-input w-full"
                    maxlength="50"
                  />
                </div>

                <div class="ar-field">
                  <.label class="ar-form-label">
                    {dgettext("dialogs", "Command")}
                  </.label>
                  <.textarea
                    name="command"
                    value={@draft_command}
                    placeholder={dgettext("dialogs", "/say Hello!")}
                    class="ar-command-input ar-input w-full resize-none text-xs"
                    maxlength="500"
                    rows="3"
                  />
                </div>

                <p :if={@error_message} class="ar-error text-xs text-destructive">
                  {@error_message}
                </p>
              </div>

              <div class="ar-form-actions flex gap-retro-4 pt-retro-4">
                <.button type="submit" size="sm" variant="default" class="ar-action-button">
                  <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
                  {dgettext("dialogs", "Save")}
                </.button>
                <.button
                  type="button"
                  size="sm"
                  variant="outline"
                  phx-click={@on_cancel_edit}
                  class="ar-action-button"
                >
                  <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
                  {dgettext("dialogs", "Cancel")}
                </.button>
              </div>
            </form>
          </div>
        </div>
      </.focus_wrap>
    </div>
    """
  end

  @spec trigger_label(String.t()) :: String.t()
  defp trigger_label("on_join"), do: dgettext("dialogs", "On Join")
  defp trigger_label("on_part"), do: dgettext("dialogs", "On Part")
  defp trigger_label("on_nick_change"), do: dgettext("dialogs", "On Nick Change")
  defp trigger_label(trigger), do: trigger

  @spec trigger_options() :: [{String.t(), String.t()}]
  defp trigger_options do
    Enum.map(@trigger_keys, fn key -> {key, trigger_label(key)} end)
  end

  defp rule_trigger(rule) do
    rule
    |> Map.get(:trigger, Map.get(rule, :trigger_event, "on_join"))
    |> to_string()
  end

  defp rule_channel(rule) do
    Map.get(rule, :channel, Map.get(rule, :channel_filter, "")) || ""
  end

  defp rule_channel_label(rule) do
    case rule_channel(rule) do
      "" -> dgettext("dialogs", "Any")
      channel -> channel
    end
  end

  defp rule_enabled?(rule), do: Map.get(rule, :enabled, true)

  defp rule_accessible_name(rule) do
    "#{trigger_label(rule_trigger(rule))} #{rule_channel_label(rule)} #{Map.get(rule, :command, "")}"
  end

  # The first enabled rule is the one drawn: the event that trips it, then
  # the command everybody in the channel will see it send.
  @spec respond_lines(list() | nil) :: [map()]
  defp respond_lines(rules) when is_list(rules) do
    case Enum.find(rules, &Map.get(&1, :enabled, true)) do
      nil ->
        []

      rule ->
        [
          %{text: trigger_caption(Map.get(rule, :trigger_event, "on_join")), tone: :system},
          %{text: Map.get(rule, :command, ""), tone: :accent}
        ]
    end
  end

  defp respond_lines(_rules), do: []

  @spec trigger_caption(String.t()) :: String.t()
  defp trigger_caption("on_join"), do: system_line(dgettext("dialogs", "somebody joined"))
  defp trigger_caption("on_part"), do: system_line(dgettext("dialogs", "somebody left"))
  defp trigger_caption(_other), do: system_line(dgettext("dialogs", "something happened"))

  # The chat's own marker for a line nobody typed. It is punctuation, not
  # prose: inside a msgid the engine reads it as list markup and mangles the
  # sentence after it, so it is prefixed here instead.
  @spec system_line(String.t()) :: String.t()
  defp system_line(text), do: "* " <> text
end
