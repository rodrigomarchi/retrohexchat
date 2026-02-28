defmodule RetroHexChatWeb.Components.UI.HighlightDialog do
  @moduledoc """
  Highlight dialog component for the showcase design system.

  Composed from dialog + table + color_picker + button + input primitives.
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
  import RetroHexChatWeb.Components.UI.Table
  import RetroHexChatWeb.Components.UI.ColorPicker
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Input

  alias RetroHexChatWeb.Icons

  @doc "Renders the highlight dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :words, :list, default: [], doc: "List of %{text, color} maps"

  attr :own_nick, :string,
    default: nil,
    doc: "Current user's nick (shown as non-removable highlight)"

  attr :selected_index, :integer, default: nil, doc: "Currently selected row index"
  attr :selected_color, :integer, default: nil
  attr :on_select, :any, default: nil, doc: "Row selection callback (receives phx-value-index)"
  attr :on_add, :any, default: nil, doc: "Add word callback"
  attr :on_edit, :any, default: nil, doc: "Edit word callback"
  attr :on_remove, :any, default: nil, doc: "Remove word callback"
  attr :on_color_select, :any, default: nil, doc: "Color select callback"
  attr :on_ok, :any, default: nil, doc: "OK button callback"
  attr :on_cancel, :any, default: nil, doc: "Cancel button callback"

  @spec highlight_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def highlight_dialog(assigns) do
    ~H"""
    <.dialog id={@id} show={@show}>
      <.dialog_header id={@id} title="Highlight Words">
        <:icon><Icons.icon_star class="w-4 h-4" /></:icon>
      </.dialog_header>

      <.dialog_body class="space-y-retro-8">
        <%!-- Add word input --%>
        <div class="flex items-center gap-retro-4">
          <.input type="text" placeholder="Add word..." class="flex-1" name="highlight_word" />
          <.button size="sm" variant="outline" phx-click={@on_add}>
            <:icon><Icons.icon_btn_add class="w-4 h-4" /></:icon>
            Add
          </.button>
        </div>

        <%!-- Word list table --%>
        <.table>
          <.table_header>
            <.table_row>
              <.table_head>Word</.table_head>
              <.table_head>Color</.table_head>
              <.table_head class="w-[40px]"></.table_head>
            </.table_row>
          </.table_header>
          <.table_body>
            <%!-- Own nick (non-removable) --%>
            <.table_row :if={@own_nick} class="bg-hover-bg">
              <.table_cell>
                <span class="font-bold">{@own_nick}</span>
                <span class="text-muted-foreground text-[10px] ml-retro-4">(you)</span>
              </.table_cell>
              <.table_cell>
                <div class="w-4 h-4 border border-border bg-warning" />
              </.table_cell>
              <.table_cell>&nbsp;</.table_cell>
            </.table_row>
            <%!-- User-defined words --%>
            <.table_row
              :for={{word, idx} <- Enum.with_index(@words)}
              class={if(@selected_index == idx, do: "bg-selection-bg text-selection-fg", else: "")}
              phx-click={@on_select}
              phx-value-index={idx}
            >
              <.table_cell>{word.text}</.table_cell>
              <.table_cell>
                <div class={["w-4 h-4 border border-border", color_class(word.color)]} />
              </.table_cell>
              <.table_cell>&nbsp;</.table_cell>
            </.table_row>
          </.table_body>
        </.table>

        <div class="flex gap-retro-4">
          <.button size="sm" variant="outline" phx-click={@on_edit} disabled={@selected_index == nil}>
            <:icon><Icons.icon_btn_edit class="w-4 h-4" /></:icon>
            Edit
          </.button>
          <.button
            size="sm"
            variant="outline"
            phx-click={@on_remove}
            disabled={@selected_index == nil}
          >
            <:icon><Icons.icon_btn_remove class="w-4 h-4" /></:icon>
            Remove
          </.button>
        </div>

        <%!-- Color picker for assignment --%>
        <.color_picker
          id={"#{@id}-color-picker"}
          selected={@selected_color}
          on_select={@on_color_select}
        />
      </.dialog_body>

      <.dialog_footer>
        <.button variant="default" phx-click={@on_ok || hide_modal(@id)}>
          <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
          OK
        </.button>
        <.button variant="outline" phx-click={@on_cancel || hide_modal(@id)}>
          <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
          Cancel
        </.button>
      </.dialog_footer>
    </.dialog>
    """
  end

  @spec color_class(any()) :: String.t()
  defp color_class(n) when is_integer(n), do: "irc-bg-#{n}"
  defp color_class(_), do: "highlight-bg-default"
end
