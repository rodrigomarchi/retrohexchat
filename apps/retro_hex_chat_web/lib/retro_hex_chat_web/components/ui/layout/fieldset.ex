defmodule RetroHexChatWeb.Components.UI.Fieldset do
  @moduledoc false
  use RetroHexChatWeb.Component

  @doc "Renders a Win98-style fieldset (groupbox) with etched groove border."
  attr :legend, :string, default: nil
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  @spec retro_fieldset(map()) :: Phoenix.LiveView.Rendered.t()
  def retro_fieldset(assigns) do
    ~H"""
    <fieldset class={classes(["retro-fieldset p-4 pt-2 m-0", @class])} {@rest}>
      <legend :if={@legend} class="bg-surface px-1 text-sm font-bold">{@legend}</legend>
      {render_slot(@inner_block)}
    </fieldset>
    """
  end

  @doc "Renders a horizontal form row within a fieldset."
  attr :class, :any, default: nil
  attr :stacked, :boolean, default: false
  attr :rest, :global
  slot :inner_block, required: true

  @spec field_row(map()) :: Phoenix.LiveView.Rendered.t()
  def field_row(assigns) do
    ~H"""
    <div
      class={
        classes([
          if(@stacked,
            do: "flex flex-col gap-1",
            else: "flex items-center gap-2"
          ),
          "mt-1.5 first:mt-0",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Renders a named region of a dialog: a groove-bordered groupbox whose legend
  carries an icon, with an optional one-line explanation of what the region
  does and the `/` command that does the same thing from the composer.

  The description answers "what happens if I use this"; the command teaches
  the equivalent keystroke, which is how this product is meant to be driven.
  """
  attr :legend, :string, required: true

  attr :description, :string,
    default: nil,
    doc: "One line on what the region does — the same sentence its help topic uses"

  attr :command, :string,
    default: nil,
    doc: "The equivalent `/` command, shown as a right-aligned hint"

  attr :class, :any, default: nil
  attr :rest, :global
  slot :icon, doc: "16×16 icon for the legend"
  slot :inner_block, required: true

  @spec dialog_section(map()) :: Phoenix.LiveView.Rendered.t()
  def dialog_section(assigns) do
    ~H"""
    <fieldset
      class={classes(["retro-fieldset dlg-section px-retro-8 pb-retro-8 pt-0", @class])}
      {@rest}
    >
      <legend class="dlg-section__legend flex items-center gap-retro-4 bg-surface px-1 text-xs font-bold">
        <span :if={@icon != []} class="dlg-section__legend-icon flex h-4 w-4 shrink-0 items-center">
          {render_slot(@icon)}
        </span>
        {@legend}
      </legend>

      <p :if={@description} class="dlg-section__description mb-retro-6 text-xs text-muted-foreground">
        {@description}
      </p>

      {render_slot(@inner_block)}

      <p :if={@command} class="dlg-section__hint mt-retro-6 text-right text-xs text-muted-foreground">
        <span class="dlg-section__hint-label">{dgettext("dialogs", "Same as")}</span>
        <code class="dlg-section__command">{@command}</code>
      </p>
    </fieldset>
    """
  end
end
