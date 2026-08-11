defmodule RetroHexChatWeb.Components.UI.Badge do
  @moduledoc false
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Components.UI.Variants

  @doc """
  Renders a badge — a small, non-interactive status label styled as a
  Win98 status-bar panel (sunken inset, compact).

  ## Examples

      <.badge>Default</.badge>
      <.badge variant="destructive">Error</.badge>
      <.badge variant="success">Online</.badge>
      <.badge variant="success">
        <:icon><Icons.icon_checkmark class="h-3 w-3" /></:icon>
        Online
      </.badge>
  """
  attr :class, :string, default: nil

  attr :variant, :string,
    values: ~w(default secondary destructive outline success warning),
    default: "default",
    doc: "the badge variant style"

  attr :rest, :global
  slot :icon, doc: "optional leading icon"
  slot :inner_block, required: true

  def badge(assigns) do
    assigns = assign(assigns, :variant_class, variant(assigns))

    ~H"""
    <span
      class={
        classes([
          "inline-flex items-center shadow-retro-field px-1.5 py-px text-[11px] font-bold leading-tight select-none",
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
                "warning" => "bg-white text-warning"
              }
            )

  defp variant(props), do: Variants.classes(@variants, props)
end
