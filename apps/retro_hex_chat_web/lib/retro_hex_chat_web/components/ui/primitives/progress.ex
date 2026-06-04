defmodule RetroHexChatWeb.Components.UI.Progress do
  @moduledoc false
  use RetroHexChatWeb.Component

  @doc """
  Render progress bar

  ## Example


      <.progress class="w-[60%]" value={20}/>

  """
  attr :class, :string, default: nil
  attr :value, :integer, default: 0, doc: ""
  attr :rest, :global

  def progress(assigns) do
    assigns = assign(assigns, :value, normalize_integer(assigns[:value]))

    ~H"""
    <div
      class={classes(["relative h-4 w-full overflow-hidden shadow-retro-sunken bg-surface", @class])}
      style={"--retro-progress-value: #{@value || 0}%;"}
      {@rest}
    >
      <div class="h-full bg-primary transition-all w-[var(--retro-progress-value)]"></div>
    </div>
    """
  end
end
