defmodule RetroHexChatWeb.Components.UI.Checkbox do
  @moduledoc false
  use RetroHexChatWeb.Component

  @doc """
  Implement checkbox input component

  ## Examples:
      <.checkbox class="!border-destructive" name="agree" value={true} />
  """
  attr :name, :any, default: nil
  attr :value, :any, default: nil
  attr :"default-value", :any, values: [true, false, "true", "false"], default: false
  attr :field, Phoenix.HTML.FormField
  attr :class, :string, default: nil
  attr :rest, :global

  def checkbox(assigns) do
    assigns =
      prepare_assign(assigns)

    assigns =
      assign_new(assigns, :checked, fn ->
        HTMLForm.normalize_value("checkbox", assigns.value)
      end)

    ~H"""
    <input type="hidden" name={@name} value="false" />
    <input
      type="checkbox"
      class={
        classes([
          "retro-checkbox peer shrink-0 focus-visible:outline focus-visible:outline-2 focus-visible:outline-black",
          @class
        ])
      }
      name={@name}
      value="true"
      checked={@checked}
      {@rest}
    />
    """
  end
end
