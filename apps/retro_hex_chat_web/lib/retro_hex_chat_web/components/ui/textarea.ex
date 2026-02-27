defmodule RetroHexChatWeb.Components.UI.Textarea do
  @moduledoc false
  use RetroHexChatWeb.Component

  @doc """
  Displays a form textarea

  ## Example

  ```heex
      <.textarea field={f[:description]} placeholder="Type your message here" />
  ```


  """
  attr :id, :any, default: nil
  attr :name, :string, default: nil
  attr :value, :string
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(disabled form)

  def textarea(assigns) do
    ~H"""
    <textarea
      class={
        classes([
          "min-h-[80px] border-none shadow-retro-field bg-white flex w-full px-3 py-2 text-sm placeholder:text-muted-foreground focus-visible:outline focus-visible:outline-2 focus-visible:outline-black disabled:cursor-not-allowed disabled:opacity-50",
          @class
        ])
      }
      {%{id: @id, name: @name}}
      {@rest}
    ><%= HTMLForm.normalize_value("textarea", assigns[:value]) %></textarea>
    """
  end
end
