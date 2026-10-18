defmodule RetroHexChatWeb.Components.UI.InlineHelpCard do
  @moduledoc """
  A help topic, drawn in the conversation under the `/help` line that asked
  for it. Displays a help topic inline within a chat message, with title,
  rendered content, and a link to the full help page.

  ## Usage

      <.inline_help_card
        topic_id="nickserv"
        topic_title="NickServ Commands"
        help_url="/chat/help/nickserv"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.ChatCard

  @doc "Renders an inline help card within a chat message."
  attr :topic_id, :string, required: true, doc: "Help topic ID for rendering content"
  attr :topic_title, :string, required: true, doc: "Display title of the help topic"
  attr :help_url, :string, required: true, doc: "Full URL to the help page"
  attr :class, :any, default: nil
  attr :rest, :global

  @spec inline_help_card(map()) :: Phoenix.LiveView.Rendered.t()
  def inline_help_card(assigns) do
    ~H"""
    <.chat_card class={@class} data-testid="inline-help" {@rest}>
      <:title>{@topic_title}</:title>
      <RetroHexChatWeb.HelpLive.HelpHelpers.render_topic_content id={@topic_id} />
      <div class="text-muted-foreground">
        <a
          href={@help_url}
          target="_blank"
          rel="noopener noreferrer"
          class="underline"
        >
          {dgettext("chat", "Open in Help Topics")}
        </a>
      </div>
    </.chat_card>
    """
  end
end
