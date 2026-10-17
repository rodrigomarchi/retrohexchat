defmodule RetroHexChatWeb.Components.UI.VisitorSignUpButton do
  @moduledoc """
  The one way a visitor is offered an account in the chat: the button under
  the conversation, where the message box would be, and the one in the card
  that greets them. Both send `visitor_sign_in`, which the visitor gate turns
  into the sign-in window (`ChatLive.Visitor`).

  ## Usage

      <.visitor_sign_up_button data-testid="visitor-composer" />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Icons

  attr :class, :any, default: nil
  attr :rest, :global

  @doc "Renders the button that opens the sign-in window for a visitor."
  @spec visitor_sign_up_button(map()) :: Phoenix.LiveView.Rendered.t()
  def visitor_sign_up_button(assigns) do
    ~H"""
    <.button size="sm" class={@class} phx-click="visitor_sign_in" {@rest}>
      <:icon><Icons.icon_watching class="h-4 w-4" /></:icon>
      {dgettext("chat", "Create an account to talk")}
    </.button>
    """
  end
end
