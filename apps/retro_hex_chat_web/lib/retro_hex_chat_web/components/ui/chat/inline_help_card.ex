defmodule RetroHexChatWeb.Components.UI.InlineHelpCard do
  @moduledoc """
  Inline help card component for the showcase design system.

  Displays a help topic inline within a chat message, with title,
  rendered content, and a link to the full help page.

  ## Usage

      <.inline_help_card
        topic_id="nickserv"
        topic_title="NickServ Commands"
        help_url="/chat/help/nickserv"
      />
  """
  use RetroHexChatWeb.Component

  @doc "Renders an inline help card within a chat message."
  attr :topic_id, :string, required: true, doc: "Help topic ID for rendering content"
  attr :topic_title, :string, required: true, doc: "Display title of the help topic"
  attr :help_url, :string, required: true, doc: "Full URL to the help page"
  attr :class, :any, default: nil
  attr :rest, :global

  @spec inline_help_card(map()) :: Phoenix.LiveView.Rendered.t()
  def inline_help_card(assigns) do
    ~H"""
    <div
      class={classes(["mt-1 p-2 bg-canvas shadow-retro-field text-xs", @class])}
      data-testid="inline-help"
      {@rest}
    >
      <h3 class="font-bold mb-1">{@topic_title}</h3>
      <RetroHexChatWeb.HelpLive.HelpHelpers.render_topic_content id={@topic_id} />
      <div class="mt-1 text-muted-foreground">
        <a
          href={@help_url}
          target="_blank"
          rel="noopener noreferrer"
          class="underline"
        >
          Open in Help Topics (F1)
        </a>
      </div>
    </div>
    """
  end
end
