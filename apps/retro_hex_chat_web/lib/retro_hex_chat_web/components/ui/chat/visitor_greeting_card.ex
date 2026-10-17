defmodule RetroHexChatWeb.Components.UI.VisitorGreetingCard do
  @moduledoc """
  The card the chat greets a visitor with, under a System line in the channel
  they arrived at: the guest name they are listed under, how to move between
  channels without an account, what an account opens — each feature leading to
  its help topic — and the way to create one.

  The controls it names are named by the labels the screen shows, translated by
  the same calls, so a reader finds them where the card says.

  ## Usage

      <.visitor_greeting_card server="RetroHexChat" guest="Guest4821" channel="#lobby" />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.FeatureList
  import RetroHexChatWeb.Components.UI.Inset
  import RetroHexChatWeb.Components.UI.VisitorSignUpButton

  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.PublicPages

  attr :server, :string,
    required: true,
    doc: "the server's name (`RetroHexChat.Admin.server_name/0`)"

  attr :guest, :string,
    required: true,
    doc: "the guest name the user list shows the visitor under"

  attr :channel, :string, required: true, doc: "the channel the visitor is reading"
  attr :class, :any, default: nil
  attr :rest, :global

  @doc "Renders the greeting card for a visitor reading `channel`."
  @spec visitor_greeting_card(map()) :: Phoenix.LiveView.Rendered.t()
  def visitor_greeting_card(assigns) do
    ~H"""
    <.inset
      class={["chat-card mt-1 p-2 text-xs space-y-2", @class]}
      data-testid="visitor-greeting"
      {@rest}
    >
      <h3 class="font-bold">
        {dgettext("chat", "Welcome to %{server}, %{guest}!", server: @server, guest: @guest)}
      </h3>
      <p>
        {dgettext("chat", "You are reading %{channel} live as a visitor.", channel: @channel)}
        {dgettext("chat", "The user list shows you as a guest.")}
        {dgettext("chat", "You can read every public channel, but writing needs an account.")}
      </p>
      <p>
        {dgettext(
          "chat",
          "In %{conversations}, %{open} and %{popular} take you to other channels, and %{browse} lists every public one.",
          conversations: dgettext("chat", "Conversations"),
          open: dgettext("chat", "Open channels"),
          popular: dgettext("chat", "Popular channels"),
          browse: dgettext("chat", "Browse All Channels...")
        )}
      </p>
      <p class="font-bold">{dgettext("chat", "With a free account you can also:")}</p>
      <.feature_list>
        <:item :for={feature <- features()} icon={feature.icon}>
          <.link patch={topic_path(feature.topic)} class="font-bold underline">{feature.name}</.link>
          — {feature.text}
        </:item>
      </.feature_list>
      <p>{dgettext("chat", "An account only needs a nickname and a password.")}</p>
      <div class="flex flex-wrap gap-2">
        <.visitor_sign_up_button data-testid="visitor-greeting-sign-up" />
        <.button
          size="sm"
          variant="secondary"
          patch={topic_path("watching-without-account")}
          data-testid="visitor-greeting-help"
        >
          <:icon><Icons.icon_btn_help_topics class="h-4 w-4" /></:icon>
          {dgettext("ui", "Help Topics")}
        </.button>
      </div>
    </.inset>
    """
  end

  # What an account opens, each named by the label the screen shows it under
  # and leading to the help topic that explains it.
  defp features do
    [
      %{
        icon: :icon_chat,
        topic: "channels",
        name: dgettext("chat", "Talk"),
        text: dgettext("chat", "Write here, in any channel, or privately to anyone.")
      },
      %{
        icon: :icon_toolbar_community,
        topic: "feature-virtual-spaces",
        name: dgettext("chat", "Space"),
        text: dgettext("chat", "Walk this channel's 8-bit world with your own character.")
      },
      %{
        icon: :icon_toolbar_conference,
        topic: "feature-channel-conference",
        name: dgettext("group_call", "Group Call"),
        text: dgettext("chat", "An audio and video call for the whole channel.")
      },
      %{
        icon: :icon_p2p,
        topic: "feature-universal-lobby",
        name: dgettext("chat", "P2P"),
        text: dgettext("chat", "A direct call, file transfer or game with one person.")
      },
      %{
        icon: :icon_game_arcade,
        topic: "feature-arcade",
        name: dgettext("ui", "Arcade"),
        text: dgettext("chat", "Doom, Quake and other classics in the browser.")
      }
    ]
  end

  defp topic_path(topic), do: PublicPages.localized_path("/chat/help/#{topic}")
end
