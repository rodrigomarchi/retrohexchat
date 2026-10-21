defmodule RetroHexChatWeb.Components.UI.Badge do
  @moduledoc false
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Components.UI.Variants

  @doc """
  Renders a badge — a small, non-interactive status label: a flat, compact
  panel with a one-pixel border.

  ## Examples

      <.badge>Default</.badge>
      <.badge variant="destructive">Error</.badge>
      <.badge variant="success">Online</.badge>
      <.badge variant="success">
        <:icon><Icons.icon_checkmark class="h-3 w-3" /></:icon>
        Online
      </.badge>

  `size="xs"` with `bevel="sunken"` is the status pill a panel header carries
  in its facets — "Offline", "Playing", "Incoming": one word of state with a
  border in the variant's colour, so the state reads before the word does.

      <.badge variant="success" size="xs" bevel="sunken">Playing</.badge>
  """
  attr :class, :string, default: nil

  attr :variant, :string,
    values: ~w(default secondary destructive outline success warning muted),
    default: "default",
    doc: "the badge variant style"

  attr :size, :string, values: ~w(default xs), default: "default"

  attr :bevel, :string,
    values: ~w(field sunken),
    default: "field",
    doc: "`sunken` takes a border in the variant's colour — the status pill"

  attr :rest, :global
  slot :icon, doc: "optional leading icon"
  slot :inner_block, required: true

  def badge(assigns) do
    assigns = assign(assigns, :variant_class, variant(assigns))

    ~H"""
    <span
      class={
        classes([
          "inline-flex items-center font-bold leading-tight select-none",
          size_class(@size),
          bevel_class(@bevel),
          @variant_class,
          @class
        ])
      }
      {@rest}
    >
      <span
        :if={@icon != []}
        class="mr-1 inline-flex h-3 w-3 shrink-0 items-center justify-center"
      >
        {render_slot(@icon)}
      </span>
      {render_slot(@inner_block)}
    </span>
    """
  end

  @variants Variants.new(
              variant: %{
                "default" => "bg-white text-primary",
                "secondary" => "bg-white text-black",
                "destructive" => "bg-white text-destructive",
                "outline" => "bg-transparent text-foreground",
                "success" => "bg-white text-success-dark",
                "warning" => "bg-white text-warning",
                "muted" => "bg-muted text-muted-foreground"
              }
            )

  defp variant(%{bevel: "sunken", variant: variant}), do: sunken_variant(variant)
  defp variant(props), do: Variants.classes(@variants, props)

  defp size_class("xs"), do: "px-1.5 py-0.5 text-[10px]"
  defp size_class(_default), do: "px-1.5 py-px text-[11px]"

  defp bevel_class("sunken"), do: "border"
  defp bevel_class(_field), do: "border border-border"

  # As a status pill the badge's colour moves to its border, and a state that
  # wants an answer — an incoming offer, a failure — tints the pill.
  defp sunken_variant("success"), do: "border-success bg-white text-success"
  defp sunken_variant("warning"), do: "border-warning bg-warning-bg text-foreground"
  defp sunken_variant("destructive"), do: "border-destructive bg-destructive/10 text-destructive"
  defp sunken_variant("muted"), do: "border-border bg-muted text-muted-foreground"
  defp sunken_variant("outline"), do: "border-border bg-transparent text-foreground"
  defp sunken_variant(_default), do: "border-border bg-white text-primary"
end
