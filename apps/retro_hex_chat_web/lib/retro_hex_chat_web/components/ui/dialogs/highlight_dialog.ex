defmodule RetroHexChatWeb.Components.UI.HighlightDialog do
  @moduledoc """
  Highlight dialog component for the showcase design system.

  Composed from dialog + color_picker + button + input primitives.
  Word list with color assignments, Add/Edit/Remove, own nick highlight.

  ## Usage

      <.highlight_dialog
        id="highlights"
        show={true}
        words={@words}
        own_nick="MyNick"
        on_add="hl-add"
        on_remove="hl-remove"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.ColorPicker
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Input

  alias RetroHexChatWeb.Icons

  @doc "Renders the highlight dialog."
  attr :id, :string, required: true
  attr :target, :any, default: nil
  attr :show, :boolean, default: false
  attr :words, :list, default: [], doc: "List of HighlightWord.t() structs"

  attr :own_nick, :string,
    default: nil,
    doc: "Current user's nick (shown as non-removable highlight)"

  attr :selected_word, :string, default: nil, doc: "Currently selected word text"
  attr :selected_color, :integer, default: nil, doc: "Selected color index from color picker"
  attr :on_select, :any, default: nil, doc: "Row selection callback (receives phx-value-word)"
  attr :on_add, :any, default: nil, doc: "Add word callback"
  attr :on_edit, :any, default: nil, doc: "Edit word callback"
  attr :on_remove, :any, default: nil, doc: "Remove word callback"
  attr :show_highlight_add_dialog, :boolean, default: false, doc: "Show inline add sub-form"
  attr :show_highlight_edit_dialog, :boolean, default: false, doc: "Show inline edit sub-form"
  attr :on_color_select, :any, default: nil, doc: "Color select callback"
  attr :on_ok, :any, default: nil, doc: "OK button callback"
  attr :on_cancel, :any, default: nil, doc: "Cancel button callback"

  @spec highlight_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def highlight_dialog(assigns) do
    ~H"""
    <.dialog
      id={@id}
      show={@show}
      lock={@show_highlight_add_dialog || @show_highlight_edit_dialog}
      on_cancel={@on_cancel}
    >
      <.dialog_header id={@id} title={dgettext("dialogs", "Highlight Words")} on_close={@on_cancel}>
        <:icon><Icons.icon_star class="w-4 h-4" /></:icon>
      </.dialog_header>

      <.dialog_body>
        <.highlight_panel
          id={@id}
          target={@target}
          words={@words}
          own_nick={@own_nick}
          selected_word={@selected_word}
          selected_color={@selected_color}
          show_highlight_add_dialog={@show_highlight_add_dialog}
          show_highlight_edit_dialog={@show_highlight_edit_dialog}
          on_select={@on_select}
          on_add={@on_add}
          on_edit={@on_edit}
          on_remove={@on_remove}
          on_color_select={@on_color_select}
          sub_scope={:viewport}
        />
      </.dialog_body>

      <.dialog_footer>
        <.button variant="default" phx-click={@on_ok || hide_modal(@id)}>
          <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
          {dgettext("dialogs", "OK")}
        </.button>
        <.button variant="outline" phx-click={@on_cancel || hide_modal(@id)}>
          <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
          {dgettext("dialogs", "Cancel")}
        </.button>
      </.dialog_footer>
    </.dialog>
    """
  end

  @doc """
  Renders the highlight content panel (word list + color picker + Add/Edit
  sub-form modals) without any frame — compose it inside a dialog or a desktop
  window body. `sub_scope` decides where the sub-form modals anchor:
  `:window` (default) centers them over the enclosing desktop window.
  """
  attr :id, :string, required: true
  attr :target, :any, default: nil
  attr :words, :list, default: []
  attr :own_nick, :string, default: nil
  attr :selected_word, :string, default: nil
  attr :selected_color, :integer, default: nil
  attr :on_select, :any, default: nil
  attr :on_add, :any, default: nil
  attr :on_edit, :any, default: nil
  attr :on_remove, :any, default: nil
  attr :show_highlight_add_dialog, :boolean, default: false
  attr :show_highlight_edit_dialog, :boolean, default: false
  attr :on_color_select, :any, default: nil
  attr :on_close, :any, default: nil
  attr :sub_scope, :atom, default: :window, values: [:viewport, :window]

  @spec highlight_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def highlight_panel(assigns) do
    ~H"""
    <div id={"#{@id}-panel-root"} class="contents">
      <.focus_wrap id={"#{@id}-focus-wrap"} class="contents">
        <div
          id={"#{@id}-content"}
          data-testid="highlight-panel"
          role="dialog"
          aria-modal="false"
          tabindex="0"
          phx-mounted={JS.focus(to: "##{@id}-content")}
          class="hl-dialog flex h-full min-h-0 flex-col gap-retro-8"
        >
          <div class="hl-content min-h-0 flex-1">
            <div class="hl-list-pane min-h-0">
              <div class="hl-entry-list overflow-y-auto retro-scrollbar">
                <div :if={@own_nick} class="hl-own-entry">
                  <span class="hl-entry-word">
                    <span>{@own_nick}</span>
                    <span class="hl-entry-tag">{dgettext("dialogs", "(you)")}</span>
                  </span>
                  <span class="hl-entry-color">
                    <span class="hl-color-swatch bg-warning" />
                    <span>{dgettext("dialogs", "Own nick")}</span>
                  </span>
                </div>

                <div
                  :if={@words == []}
                  class="hl-empty-state text-center text-muted-foreground"
                >
                  {dgettext("dialogs", "No highlight words configured. Click Add to create one.")}
                </div>

                <button
                  :for={word <- @words}
                  type="button"
                  data-testid={"highlight-word-row-#{word.word}"}
                  aria-pressed={@selected_word == word.word}
                  aria-label={word.word}
                  class={highlight_entry_class(@selected_word == word.word)}
                  phx-click={@on_select}
                  phx-target={@target}
                  phx-value-word={word.word}
                >
                  <span class="hl-entry-word">{word.word}</span>
                  <span class="hl-entry-color">
                    <span
                      class={["hl-color-swatch", color_class(word.bg_color)]}
                      data-testid={"highlight-word-color-#{word.word}"}
                    />
                    <span>{color_label(word.bg_color)}</span>
                  </span>
                </button>
              </div>

              <div class="hl-action-row flex gap-retro-4">
                <.button
                  size="sm"
                  variant="outline"
                  phx-click={@on_add}
                  phx-target={@target}
                  class="hl-action-button"
                >
                  <:icon><Icons.icon_btn_add class="w-4 h-4" /></:icon>
                  {dgettext("dialogs", "Add")}
                </.button>
                <.button
                  size="sm"
                  variant="outline"
                  phx-click={@on_edit}
                  phx-target={@target}
                  disabled={@selected_word == nil}
                  class="hl-action-button"
                >
                  <:icon><Icons.icon_btn_edit class="w-4 h-4" /></:icon>
                  {dgettext("dialogs", "Edit")}
                </.button>
                <.button
                  size="sm"
                  variant="outline"
                  phx-click={@on_remove}
                  phx-target={@target}
                  phx-value-word={@selected_word || ""}
                  disabled={@selected_word == nil}
                  class="hl-action-button"
                >
                  <:icon><Icons.icon_btn_remove class="w-4 h-4" /></:icon>
                  {dgettext("dialogs", "Remove")}
                </.button>
              </div>
            </div>

            <div class="hl-color-panel">
              <.color_picker
                id={"#{@id}-color-picker"}
                target={@target}
                selected={@selected_color}
                on_select={@on_color_select}
                class="hl-color-picker"
              />
            </div>
          </div>

          <div :if={@on_close} class="hl-dialog-footer flex justify-end">
            <.button
              type="button"
              size="sm"
              phx-click={@on_close}
              phx-target={@target}
              class="hl-action-button"
            >
              <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "OK")}
            </.button>
          </div>

          <%!-- Highlight Add Sub-Dialog (modal, scoped by @sub_scope) --%>
          <.highlight_add_sub_form
            :if={@show_highlight_add_dialog}
            target={@target}
            selected_color={@selected_color}
            scope={@sub_scope}
          />
          <%!-- Highlight Edit Sub-Dialog --%>
          <.highlight_edit_sub_form
            :if={@show_highlight_edit_dialog}
            target={@target}
            selected_word={@selected_word}
            selected_color={@selected_color}
            scope={@sub_scope}
          />
        </div>
      </.focus_wrap>
    </div>
    """
  end

  # ── Sub-Forms ────────────────────────────────────────
  # Modal child dialogs built on the dialog primitive: `scope` anchors them to
  # the enclosing desktop window (or the viewport in the showcase dialog), and
  # every close path routes to the owning component via JS.push target.

  attr :target, :any, default: nil
  attr :selected_color, :integer, default: nil
  attr :scope, :atom, default: :window

  defp highlight_add_sub_form(assigns) do
    ~H"""
    <.dialog
      id="highlight-add-dialog"
      show
      scope={@scope}
      on_cancel={JS.push("close_highlight_add_dialog", target: @target)}
      class="md:max-w-sm"
    >
      <.dialog_header
        id="highlight-add-dialog"
        title={dgettext("dialogs", "Add Highlight Word")}
        on_close={JS.push("close_highlight_add_dialog", target: @target)}
      >
        <:icon><Icons.icon_star class="w-4 h-4" /></:icon>
      </.dialog_header>
      <.dialog_body>
        <form
          phx-submit="highlight_add"
          phx-target={@target}
          data-testid="highlight-add-form"
          class="hl-sub-form"
        >
          <div class="flex flex-col gap-1.5 mb-2">
            <label class="text-xs font-bold" for="highlight-word-input">
              {dgettext("dialogs", "Word:")}
            </label>
            <%!--
                phx-update="ignore" keeps the typed word across the in-form
                color-pick re-render: the input is uncontrolled, so when picking
                a swatch re-renders this component, LiveView would otherwise reset
                it. (Routing alone — phx-target — only fixes cross-component
                clobber; the color pick re-renders THIS component.)
              --%>
            <.input
              type="text"
              id="highlight-word-input"
              name="word"
              maxlength="50"
              required
              autofocus
              phx-update="ignore"
              class="hl-input w-full"
            />
          </div>
          <input type="hidden" name="bg_color" value={to_string(@selected_color || "")} />
          <div class="flex flex-col gap-1.5 mt-2">
            <label class="text-xs font-bold">
              {dgettext("dialogs", "Background Color (optional):")}
            </label>
            <.color_picker
              id="highlight-add-color"
              target={@target}
              selected={@selected_color}
              on_select="highlight_color_pick"
              class="hl-color-picker"
            />
          </div>
          <div class="hl-form-actions flex justify-end gap-1 mt-3">
            <.button type="submit" size="sm" class="hl-action-button">
              <:icon><Icons.icon_btn_add class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Add")}
            </.button>
            <.button
              type="button"
              size="sm"
              variant="outline"
              phx-click="close_highlight_add_dialog"
              phx-target={@target}
              class="hl-action-button"
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
  attr :selected_word, :string, default: nil
  attr :selected_color, :integer, default: nil
  attr :scope, :atom, default: :window

  defp highlight_edit_sub_form(assigns) do
    ~H"""
    <.dialog
      id="highlight-edit-dialog"
      show
      scope={@scope}
      on_cancel={JS.push("close_highlight_edit_dialog", target: @target)}
      class="md:max-w-sm"
    >
      <.dialog_header
        id="highlight-edit-dialog"
        title={dgettext("dialogs", "Edit Highlight Color")}
        on_close={JS.push("close_highlight_edit_dialog", target: @target)}
      >
        <:icon><Icons.icon_star class="w-4 h-4" /></:icon>
      </.dialog_header>
      <.dialog_body>
        <form
          phx-submit="highlight_edit"
          phx-target={@target}
          data-testid="highlight-edit-form"
          class="hl-sub-form"
        >
          <input type="hidden" name="word" value={@selected_word || ""} />
          <input type="hidden" name="bg_color" value={to_string(@selected_color || "")} />
          <div class="flex flex-col gap-1.5">
            <label class="text-xs font-bold">{dgettext("dialogs", "Background Color:")}</label>
            <.color_picker
              id="highlight-edit-color"
              target={@target}
              selected={@selected_color}
              on_select="highlight_color_pick"
              class="hl-color-picker"
            />
          </div>
          <div class="hl-form-actions flex justify-end gap-1 mt-3">
            <.button type="submit" size="sm" class="hl-action-button">
              <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "OK")}
            </.button>
            <.button
              type="button"
              size="sm"
              variant="outline"
              phx-click="close_highlight_edit_dialog"
              phx-target={@target}
              class="hl-action-button"
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

  @spec color_class(any()) :: String.t()
  defp color_class(n) when is_integer(n), do: "irc-bg-#{n}"
  defp color_class(_), do: "highlight-bg-default"

  defp color_label(n) when is_integer(n),
    do: dgettext("dialogs", "Color %{index}", index: n)

  defp color_label(_), do: dgettext("dialogs", "Default")

  defp highlight_entry_class(true), do: "hl-highlight-entry bg-selection-bg text-selection-fg"
  defp highlight_entry_class(false), do: "hl-highlight-entry"
end
