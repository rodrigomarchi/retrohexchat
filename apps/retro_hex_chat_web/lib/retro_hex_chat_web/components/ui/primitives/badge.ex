defmodule RetroHexChatWeb.Components.UI.Badge do
  @moduledoc false
  use RetroHexChatWeb.Component

  @doc """
  Renders a badge — a small, non-interactive status label styled as a
  Win98 status-bar panel (sunken inset, compact).

  ## Examples

      <.badge>Default</.badge>
      <.badge variant="destructive">Error</.badge>
      <.badge variant="success">Online</.badge>
  """
  attr :class, :string, default: nil

  attr :variant, :string,
    values: ~w(default secondary destructive outline success),
    default: "default",
    doc: "the badge variant style"

  attr :rest, :global
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
      {render_slot(@inner_block)}
    </span>
    """
  end

  @variants %{
    variant: %{
      "default" => "bg-white text-primary",
      "secondary" => "bg-white text-black",
      "destructive" => "bg-white text-destructive",
      "outline" => "bg-transparent text-foreground",
      "success" => "bg-white text-success-dark"
    }
  }

  @default_variants %{
    variant: "default"
  }

  defp variant(props) do
    variants = Map.merge(@default_variants, props)

    Enum.map_join(variants, " ", fn {key, value} -> @variants[key][value] end)
  end
end
