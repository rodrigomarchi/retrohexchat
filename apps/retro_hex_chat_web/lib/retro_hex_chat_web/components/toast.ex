defmodule RetroHexChatWeb.Components.Toast do
  @moduledoc """
  Toast container component for contextual tips and notifications.

  Renders an empty container div that the ContextualTipsHook JS hook
  attaches to. The hook manages all toast creation, queuing, and
  dismissal client-side using server-provided state.
  """
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Chat.ContextualTips

  attr :tips_state, :map, default: %{seen_tips: [], suppressed: false}

  attr :tips, :boolean,
    default: true,
    doc: """
    Whether the chat's tips run here. A page of its own — a call, a session, a
    Space — mounts the container only for toasts like "Copied!": the tips are
    about the chat's input and lists, and that page has neither, nor the
    person's own tips setting to honour.
    """

  @spec toast_container(map()) :: Phoenix.LiveView.Rendered.t()
  def toast_container(%{tips: false} = assigns) do
    toast_container(%{assigns | tips: true, tips_state: %{seen_tips: [], suppressed: true}})
  end

  def toast_container(assigns) do
    ~H"""
    <div
      id="contextual-tips-hook"
      phx-hook="ContextualTipsHook"
      class="toast-container"
      data-tips-state={Jason.encode!(ContextualTips.to_client_state(@tips_state))}
    >
    </div>
    """
  end
end
