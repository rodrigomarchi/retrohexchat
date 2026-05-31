defmodule RetroHexChatWeb.ShowcaseLive.Chat.SyntaxTooltipPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.SyntaxTooltip
  import RetroHexChatWeb.ShowcaseHelpers

  @join_tooltip %{
    command: "join",
    parameters: [
      %{name: "channel", required: true},
      %{name: "key", required: false}
    ],
    current_param_index: 0,
    description: gettext("Join a channel, optionally with a password key."),
    sub_options: [],
    context_message: gettext("Channel names begin with # or &"),
    examples: [gettext("/join #lobby"), gettext("/join #private secretkey")]
  }

  @kick_tooltip %{
    command: "kick",
    parameters: [
      %{name: "channel", required: true},
      %{name: "nick", required: true},
      %{name: "reason", required: false}
    ],
    current_param_index: 1,
    description: gettext("Kick a user from a channel. Requires operator status."),
    sub_options: [
      %{flag: "-q", description: gettext("Quiet — do not display kick message")},
      %{flag: "-b", description: gettext("Also ban the user after kicking")}
    ],
    context_message: gettext("You must be a channel operator to use this command."),
    examples: [gettext("/kick #lobby spammer"), gettext("/kick #lobby troll Violating rules")]
  }

  @msg_tooltip %{
    command: "msg",
    parameters: [
      %{name: "target", required: true},
      %{name: "message", required: true}
    ],
    current_param_index: nil,
    description: gettext("Send a private message to a user or channel."),
    sub_options: [],
    context_message: nil,
    examples: [gettext("/msg alice Hello!"), gettext("/msg #lobby Anyone around?")]
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Syntax Tooltip"), active_page: "syntax-tooltip")}
  end

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        join_tooltip: @join_tooltip,
        kick_tooltip: @kick_tooltip,
        msg_tooltip: @msg_tooltip
      )

    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{gettext("Syntax Tooltip")}</h2>

      <.showcase_card
        title={gettext("Beginner Mode — /join")}
        description="Full detail: command header, description, context message, and examples. First param is active."
      >
        <.syntax_tooltip tooltip={@join_tooltip} detail_level={:beginner} />
        <.code_example>
          &lt;.syntax_tooltip
          tooltip=&#123;%&#123;
          command: "join",
          parameters: [%&#123;name: "channel", required: true&#125;, %&#123;name: "key", required: false&#125;],
          current_param_index: 0,
          description: "Join a channel",
          sub_options: [],
          context_message: "Channel names begin with # or &amp;",
          examples: ["/join #lobby"]
          &#125;&#125;
          detail_level=&#123;:beginner&#125;
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={gettext("Beginner Mode — /kick (with sub-options)")}
        description="Shows sub-options list. Second param (nick) is active."
      >
        <.syntax_tooltip tooltip={@kick_tooltip} detail_level={:beginner} />
      </.showcase_card>

      <.showcase_card
        title={gettext("Expert Mode — /msg")}
        description="Expert mode: command header only, no description or examples."
      >
        <.syntax_tooltip tooltip={@msg_tooltip} detail_level={:expert} />
        <.code_example>
          &lt;.syntax_tooltip tooltip=&#123;@tooltip&#125; detail_level=&#123;:expert&#125; /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={gettext("Off Mode")}
        description="When detail_level is :off, nothing is rendered."
      >
        <p class="text-xs text-muted-foreground italic">
          {gettext("(Nothing rendered below — tooltip is hidden)")}
        </p>
        <.syntax_tooltip tooltip={@join_tooltip} detail_level={:off} />
        <.code_example>
          &lt;.syntax_tooltip tooltip=&#123;@tooltip&#125; detail_level=&#123;:off&#125; /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={gettext("Nil Tooltip")}
        description="When tooltip is nil (e.g. user hasn't typed a command yet), nothing is rendered."
      >
        <p class="text-xs text-muted-foreground italic">
          {gettext("(Nothing rendered below — tooltip is nil)")}
        </p>
        <.syntax_tooltip tooltip={nil} detail_level={:beginner} />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
