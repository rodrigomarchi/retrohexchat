defmodule RetroHexChatWeb.LandingLive.Index do
  @moduledoc false
  use Phoenix.LiveView

  import RetroHexChatWeb.LandingLive.LandingHelpers
  import RetroHexChatWeb.Components.UI.Window
  import RetroHexChatWeb.Components.Diagrams

  alias Phoenix.LiveView.JS
  alias RetroHexChatWeb.Icons

  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    {:ok, assign(socket, active_page: :home)}
  end

  @readme_content """
  In the 2000s, the internet was ours.

  We had IRC, forums, blogs, and a freedom
  we didn't know we could lose. We ran servers
  in our basements. We built networks with
  friends. The code was free. The web was
  decentralized.

  Then we traded that for convenience.
  And when we noticed, the internet belonged
  to five companies.

  Retro Hex Chat is a reminder that we can
  have both: the convenience of 2026
  and the freedom of 2000.

  Run your server. Talk directly with your
  friends. Your data stays with you.

  — The creators of Retro Hex Chat\
  """

  defp readme_text(assigns) do
    assigns = assign(assigns, :text, @readme_content)

    ~H"""
    <pre class="text-xs whitespace-pre-wrap">{@text}</pre>
    """
  end
end
