defmodule RetroHexChatWeb.Components.Toast do
  @moduledoc """
  Toast container component for contextual tips and notifications.

  Renders an empty container div that the ContextualTipsHook JS hook
  attaches to. The hook manages all toast creation, queuing, and
  dismissal client-side via localStorage state.
  """
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  @spec toast_container(map()) :: Phoenix.LiveView.Rendered.t()
  def toast_container(assigns) do
    ~H"""
    <div id="contextual-tips-hook" phx-hook="ContextualTipsHook" class="toast-container"></div>
    """
  end
end
