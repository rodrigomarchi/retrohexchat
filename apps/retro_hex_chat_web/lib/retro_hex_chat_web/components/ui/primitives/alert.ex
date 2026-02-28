defmodule RetroHexChatWeb.Components.UI.Alert do
  @moduledoc false
  use RetroHexChatWeb.Component

  @doc """
  Render alert with mandatory icon.

  ## Examples

      <.alert variant="destructive">
        <:icon><Icons.icon_warning /></:icon>
        <.alert_title>Alert title</.alert_title>
        <.alert_description>Alert description</.alert_description>
      </.alert>
  """

  attr :variant, :string, default: "default", values: ~w(default destructive)
  attr :class, :string, default: nil
  slot :icon, required: true, doc: "16×16 severity icon — mandatory for visual consistency"
  slot :inner_block, required: true
  attr :rest, :global, default: %{}

  def alert(assigns) do
    assigns = assign(assigns, :variant_class, variant(assigns))

    ~H"""
    <div
      class={
        classes([
          "relative w-full border-none shadow-retro-window p-4 pl-11",
          @variant_class,
          @class
        ])
      }
      {@rest}
    >
      <span class="absolute left-4 top-4 w-[16px] h-[16px] inline-flex items-center justify-center">
        {render_slot(@icon)}
      </span>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Render alert title
  """
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled form name value)
  slot :inner_block, required: true

  def alert_title(assigns) do
    ~H"""
    <h5
      class={
        classes([
          "mb-1 font-medium leading-none tracking-tight",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </h5>
    """
  end

  @doc """
  Render alert description
  """
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled form name value)
  slot :inner_block, required: true

  def alert_description(assigns) do
    ~H"""
    <div
      class={
        classes([
          "text-sm [&_p]:leading-relaxed",
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
      "default" => "bg-background text-foreground",
      "destructive" =>
        "bg-background border-destructive/50 text-destructive dark:border-destructive [&>span]:text-destructive"
    }
  }

  @default_variants %{
    variant: "default"
  }

  defp variant(variants) do
    variants = Map.merge(@default_variants, variants)

    Enum.map_join(variants, " ", fn {key, value} -> @variants[key][value] end)
  end
end
