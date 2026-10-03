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

  attr :rest, :global,
    include: ~w(autocomplete disabled form maxlength minlength placeholder readonly required rows)

  def textarea(assigns) do
    ~H"""
    <textarea
      class={
        classes([
          "min-h-[80px] border-none shadow-retro-field bg-white flex w-full px-3 py-2 text-sm placeholder:text-muted-foreground disabled:cursor-not-allowed",
          @class
        ])
      }
      {%{id: @id, name: @name}}
      {@rest}
    ><%= HTMLForm.normalize_value("textarea", assigns[:value]) %></textarea>
    """
  end
end
