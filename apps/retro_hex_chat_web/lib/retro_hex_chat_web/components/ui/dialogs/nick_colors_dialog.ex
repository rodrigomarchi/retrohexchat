defmodule RetroHexChatWeb.Components.UI.NickColorsDialog do
  @moduledoc """
  Nick Colors dialog component for the showcase design system.

  Assigns a fixed IRC palette color to a nickname, overriding the automatic one.
  Composed from dialog + table + button + color_picker primitives.

  ## Usage

      <.nick_colors_panel
        id="nick-colors"
        nick_colors={@entries}
        on_select="nick_color_select"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Table
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.ColorPicker
  import RetroHexChatWeb.Components.UI.Input

  alias RetroHexChatWeb.Icons

  @doc """
  Renders the nick colors content (the table plus its two window-scoped add/edit
  sub-form modals) without any frame — compose it inside a desktop window body.
  """
  attr :id, :string, required: true
  attr :target, :any, default: nil
  attr :nick_colors, :list, default: [], doc: "List of %{target_nickname, color_index} maps"
  attr :selected, :string, default: nil, doc: "Selected nickname"
  attr :palette_editing_index, :integer, default: nil, doc: "Color index in the palette editor"
  attr :show_add_dialog, :boolean, default: false
  attr :show_edit_dialog, :boolean, default: false
  attr :on_select, :any, default: nil
  attr :on_add, :any, default: nil
  attr :on_edit, :any, default: nil
  attr :on_remove, :any, default: nil

  @spec nick_colors_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def nick_colors_panel(assigns) do
    ~H"""
    <div id={@id} class="contents">
      <.focus_wrap id={"#{@id}-focus-wrap"} class="contents">
        <div
          id={"#{@id}-content"}
          data-testid="nick-colors-panel"
          role="dialog"
          aria-modal="false"
          tabindex="0"
          phx-mounted={JS.focus(to: "#{@id}-content")}
          class="ab-dialog flex h-full min-h-0 flex-col gap-retro-8"
        >
          <.nick_colors_table
            target={@target}
            nick_colors={@nick_colors}
            selected={@selected}
            on_select={@on_select}
          />
          <.crud_buttons
            target={@target}
            on_add={@on_add}
            on_edit={@on_edit}
            on_remove={@on_remove}
            selected={@selected != nil}
            testid_prefix="nick-color"
          />

          <%!-- Add Sub-Dialog --%>
          <.nick_color_add_form
            :if={@show_add_dialog}
            target={@target}
            nick_palette_editing_index={@palette_editing_index}
          />
          <%!-- Edit Sub-Dialog --%>
          <.nick_color_edit_form
            :if={@show_edit_dialog}
            target={@target}
            nick_colors_selected={@selected}
            nick_palette_editing_index={@palette_editing_index}
          />
        </div>
      </.focus_wrap>
    </div>
    """
  end

  # ── Sub-Forms ──────────────────────────────────────────
  attr :target, :any, default: nil
  attr :nick_palette_editing_index, :integer, default: nil

  defp nick_color_add_form(assigns) do
    ~H"""
    <.dialog
      id="ab-nick-color-add-modal"
      show
      scope={:window}
      on_cancel={JS.push("nick_color_add_cancel", target: @target)}
      class="md:max-w-sm"
    >
      <.dialog_header
        id="ab-nick-color-add-modal"
        title={dgettext("dialogs", "Add Nick Color")}
        on_close={JS.push("nick_color_add_cancel", target: @target)}
      >
        <:icon><Icons.icon_dialog_address_book class="w-4 h-4" /></:icon>
      </.dialog_header>
      <.dialog_body>
        <form phx-submit="nick_color_add" phx-target={@target} data-testid="nick-color-add-form">
          <div class="flex flex-col gap-1.5 mb-2">
            <label class="text-xs font-bold" for="nick-color-add-nick">
              {dgettext("dialogs", "Nickname")}:
            </label>
            <.input
              type="text"
              id="nick-color-add-nick"
              name="nickname"
              maxlength="16"
              required
              phx-update="ignore"
              class="w-full"
            />
          </div>
          <div class="flex flex-col gap-1.5 mb-3">
            <label class="text-xs font-bold">{dgettext("dialogs", "Color")}:</label>
            <.color_picker
              id="nick-color-add-picker"
              selected={@nick_palette_editing_index}
              field="color_index"
            />
          </div>
          <div class="flex justify-end gap-2">
            <.button type="submit" size="sm">
              <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "OK")}
            </.button>
            <.button
              type="button"
              size="sm"
              variant="outline"
              phx-click="nick_color_add_cancel"
              phx-target={@target}
            >
              <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Cancel")}
            </.button>
          </div>
        </form>
      </.dialog_body>
    </.dialog>
    """
  end

  attr :target, :any, default: nil
  attr :nick_colors_selected, :string, default: nil
  attr :nick_palette_editing_index, :integer, default: nil

  defp nick_color_edit_form(assigns) do
    ~H"""
    <.dialog
      id="ab-nick-color-edit-modal"
      show
      scope={:window}
      on_cancel={JS.push("nick_color_edit_cancel", target: @target)}
      class="md:max-w-sm"
    >
      <.dialog_header
        id="ab-nick-color-edit-modal"
        title={dgettext("dialogs", "Edit Nick Color")}
        on_close={JS.push("nick_color_edit_cancel", target: @target)}
      >
        <:icon><Icons.icon_dialog_address_book class="w-4 h-4" /></:icon>
      </.dialog_header>
      <.dialog_body>
        <form phx-submit="nick_color_edit" phx-target={@target} data-testid="nick-color-edit-form">
          <div class="flex flex-col gap-1.5 mb-2">
            <label class="text-xs font-bold" for="nick-color-edit-nick">
              {dgettext("dialogs", "Nickname")}:
            </label>
            <.input
              type="text"
              id="nick-color-edit-nick"
              name="nickname"
              value={@nick_colors_selected}
              readonly
              class="w-full input-readonly"
            />
          </div>
          <div class="flex flex-col gap-1.5 mb-3">
            <label class="text-xs font-bold">{dgettext("dialogs", "Color")}:</label>
            <.color_picker
              id="nick-color-edit-picker"
              selected={@nick_palette_editing_index}
              field="color_index"
            />
          </div>
          <div class="flex justify-end gap-2">
            <.button type="submit" size="sm">
              <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "OK")}
            </.button>
            <.button
              type="button"
              size="sm"
              variant="outline"
              phx-click="nick_color_edit_cancel"
              phx-target={@target}
            >
              <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Cancel")}
            </.button>
          </div>
        </form>
      </.dialog_body>
    </.dialog>
    """
  end

  # ── Nick Colors Table ───────────────────────────────

  attr :target, :any, default: nil
  attr :nick_colors, :list, required: true
  attr :selected, :any, default: nil
  attr :on_select, :any, default: nil

  defp nick_colors_table(assigns) do
    ~H"""
    <div class="ab-table-wrap">
      <.table class="ab-mobile-list-table">
        <.table_header>
          <.table_row>
            <.table_head>{dgettext("dialogs", "Nick")}</.table_head>
            <.table_head>{dgettext("dialogs", "Color")}</.table_head>
          </.table_row>
        </.table_header>
        <.table_body>
          <.table_row :if={@nick_colors == []} class="ab-empty-row">
            <.table_cell colspan="2" class="ab-empty-cell text-center text-muted-foreground py-4">
              {dgettext("dialogs", "No custom colors set. Nicknames use automatic colors.")}
            </.table_cell>
          </.table_row>
          <.table_row
            :for={entry <- @nick_colors}
            id={"nick-color-entry-#{entry.target_nickname}"}
            data-color-index={entry.color_index}
            class={row_class("ab-mobile-list-row", @selected == entry.target_nickname)}
            phx-click={@on_select}
            phx-target={@target}
            phx-value-nickname={entry.target_nickname}
          >
            <.table_cell
              class="ab-mobile-list-primary"
              data-label={dgettext("dialogs", "Nick")}
            >
              {entry.target_nickname}
            </.table_cell>
            <.table_cell class="ab-mobile-list-meta" data-label={dgettext("dialogs", "Color")}>
              <div class={"ab-color-swatch w-4 h-4 border border-border #{nick_color_class(entry.color_index)}"} />
            </.table_cell>
          </.table_row>
        </.table_body>
      </.table>
    </div>
    """
  end

  # ── CRUD Buttons ────────────────────────────────────

  attr :target, :any, default: nil
  attr :on_add, :any, default: nil
  attr :on_edit, :any, default: nil
  attr :on_remove, :any, default: nil
  attr :selected, :boolean, default: false
  attr :testid_prefix, :string, default: nil

  defp crud_buttons(assigns) do
    ~H"""
    <div class="ab-action-row flex gap-retro-4 mt-retro-4">
      <.button
        size="sm"
        variant="outline"
        phx-click={@on_add}
        phx-target={@target}
        data-testid={@testid_prefix && "#{@testid_prefix}-add"}
        class="ab-action-button"
      >
        <:icon><Icons.icon_btn_add class="w-4 h-4" /></:icon>
        {dgettext("dialogs", "Add")}
      </.button>
      <.button
        size="sm"
        variant="outline"
        phx-click={@on_edit}
        phx-target={@target}
        disabled={!@selected}
        data-testid={@testid_prefix && "#{@testid_prefix}-edit"}
        class="ab-action-button"
      >
        <:icon><Icons.icon_btn_edit class="w-4 h-4" /></:icon>
        {dgettext("dialogs", "Edit")}
      </.button>
      <.button
        size="sm"
        variant="outline"
        phx-click={@on_remove}
        phx-target={@target}
        disabled={!@selected}
        data-testid={@testid_prefix && "#{@testid_prefix}-remove"}
        class="ab-action-button"
      >
        <:icon><Icons.icon_btn_remove class="w-4 h-4" /></:icon>
        {dgettext("dialogs", "Remove")}
      </.button>
    </div>
    """
  end

  # ── Helpers ────────────────────────────────────────

  defp row_class(base, true), do: "#{base} bg-selection-bg text-selection-fg"
  defp row_class(base, false), do: base

  @spec nick_color_class(any()) :: String.t()
  defp nick_color_class(n) when is_integer(n), do: "irc-bg-#{n}"
  defp nick_color_class(_), do: "bg-black"
end
