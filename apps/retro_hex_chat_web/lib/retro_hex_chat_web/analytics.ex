defmodule RetroHexChatWeb.Analytics do
  @moduledoc """
  The facts about a visit that only the server knows, handed to the browser's
  Google Analytics (`assets/js/lib/analytics/google_analytics.js`).

  Addresses are measured in the browser. What happens without changing the
  address — asking to register, a refused nickname, a line typed — is pushed
  from here, because the server is the one that knows it happened. `@events`
  is the list of reports, so a misspelt name crashes rather than starting a new
  one nobody reads.
  """
  import Phoenix.LiveView, only: [push_event: 3]

  @events ~w(arcade_start call_join channel_join channel_view channel_watch command_use
             game_start login login_start message_send p2p_start pm_open sign_up signup_error
             signup_prompt signup_start space_enter tool_open)

  @doc """
  Sends `event` once the page has it. `across_navigation: true` is for the moment
  the browser is about to leave the page: it is sent from the next one.
  """
  @spec track(Phoenix.LiveView.Socket.t(), String.t(), map(), keyword()) ::
          Phoenix.LiveView.Socket.t()
  def track(socket, event, params \\ %{}, opts \\ []) when event in @events do
    push_event(socket, "analytics", %{
      name: event,
      params: params,
      next_page: Keyword.get(opts, :across_navigation, false)
    })
  end

  @doc "Who the rest of this visit belongs to: a visitor, or a member's account id."
  @spec identify(Phoenix.LiveView.Socket.t(), integer() | nil) :: Phoenix.LiveView.Socket.t()
  def identify(socket, user_id) do
    push_event(socket, "analytics_user", %{
      member: if(user_id, do: "yes", else: "no"),
      user_id: user_id
    })
  end
end
