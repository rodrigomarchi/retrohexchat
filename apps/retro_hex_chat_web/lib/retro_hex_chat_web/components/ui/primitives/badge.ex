defmodule RetroHexChatWeb.Components.UI.Badge do
  @moduledoc false
  use RetroHexChatWeb.Component

  @doc """
  Renders a badge component

  ## Examples

      <.badge>Badge</.badge>
      <.badge variant="destructive">Badge</.badge>
  """
  attr :class, :string, default: nil

  attr :variant, :string,
    values: ~w(default secondary destructive outline),
    default: "default",
    doc: "the badge variant style"

  attr :rest, :global
  slot :inner_block, required: true

  def badge(assigns) do
    assigns = assign(assigns, :variant_class, variant(assigns))

    ~H"""
    <div
      class={
        classes([
          "inline-flex items-center border-none shadow-retro-raised px-2.5 py-0.5 text-xs font-semibold focus:outline focus:outline-2 focus:outline-black",
          @variant_class,
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @variants %{
    variant: %{
      "default" => "border-transparent bg-primary text-primary-foreground hover:bg-primary/80",
      "secondary" =>
        "border-transparent bg-secondary text-secondary-foreground hover:bg-secondary/80",
      "destructive" =>
        "border-transparent bg-destructive text-destructive-foreground hover:bg-destructive/80",
      "outline" => "text-foreground"
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
