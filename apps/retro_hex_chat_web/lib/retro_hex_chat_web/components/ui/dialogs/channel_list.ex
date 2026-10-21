defmodule RetroHexChatWeb.Components.UI.ChannelList do
  @moduledoc """
  The window that lists the rooms you can go to.

  Each row is its own door: pressing it joins the channel, or asks for access
  when the channel is invite-only and you are not in it. The verb is drawn on
  the row, because two neighbouring rows can do different things — one press,
  and you can read which one before making it.

  ## Usage

      <.channel_list_panel id="channel-list" channels={@channels} />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.ActionList
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Badge
  import RetroHexChatWeb.Components.UI.ActivityIndicator
  import RetroHexChatWeb.Components.UI.DialogBanner
  import RetroHexChatWeb.Components.UI.NickFlag, only: [channel_badges: 1, channel_category: 1]
  import RetroHexChatWeb.Components.UI.Select
  import RetroHexChatWeb.Components.UI.ToolButton

  alias RetroHexChat.Channels.Categories
  alias RetroHexChat.Chat.TimeFormatter
  alias RetroHexChatWeb.Components.Diagrams
  alias RetroHexChatWeb.Icons

  @doc "Renders the channel list dialog."
  attr :id, :string, required: true
  attr :channels, :list, default: []
  attr :search, :string, default: ""
  attr :category, :string, default: nil, doc: "the subject the list is narrowed to, or nil"
  attr :loading, :boolean, default: false, doc: "Show loading state"
  attr :on_search, :any, default: nil, doc: "Search input change callback"
  attr :on_join, :any, default: nil, doc: "Row press callback for a joinable channel"
  attr :on_knock, :any, default: nil, doc: "Row press callback for an invite-only channel"

  @spec channel_list_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def channel_list_panel(assigns) do
    ~H"""
    <div
      id={"#{@id}-content"}
      data-testid="channel-list-panel"
      class="cl-dialog"
    >
      <.dialog_banner heading={dgettext("dialogs", "Rooms you can walk into")}>
        <:art>
          <Diagrams.diagram_dialog_preview
            kind={:tabs}
            title={dgettext("dialogs", "Chat")}
            lines={joinable_lines(@channels)}
            label={dgettext("dialogs", "A miniature of the tab a room opens as")}
          />
        </:art>
        <:glyph><Icons.icon_channels class="h-8 w-8" /></:glyph>
        {dgettext(
          "dialogs",
          "Pressing a row goes in and opens the room as a tab beside the ones you already have. A room marked invite-only asks to be let in instead, and the people inside decide."
        )}
      </.dialog_banner>

      <%!-- Search, and the subject. One form, so a change to either sends
            both and the list is always what the two together select. --%>
      <form
        class="cl-search-form"
        phx-change={@on_search}
        phx-submit={@on_search}
      >
        <.input
          type="text"
          value={@search}
          placeholder={dgettext("dialogs", "Filter channels...")}
          class="cl-search-input"
          phx-debounce="300"
          name="search"
          data-testid="channel-list-search"
        />
        <.select
          :let={builder}
          id={"#{@id}-category"}
          name="category"
          value={@category || ""}
          label={Categories.label(@category) || dgettext("dialogs", "All categories")}
          class="cl-category-select"
          data-testid="channel-list-category"
        >
          <.select_trigger
            builder={builder}
            class="cl-category-trigger text-xs"
            aria-label={dgettext("dialogs", "Category")}
          />
          <%!-- Every subject and "all" are more rows than the window is tall
                at its default size; the list scrolls rather than losing the
                last ones under the window's edge. --%>
          <.select_content builder={builder} class="max-h-60 overflow-y-auto">
            <.select_group>
              <.select_item builder={builder} value="" label={dgettext("dialogs", "All categories")}>
                {dgettext("dialogs", "All categories")}
              </.select_item>
              <.select_item
                :for={code <- Categories.codes()}
                builder={builder}
                value={code}
                label={Categories.label(code)}
                data-testid={"channel-list-category-#{code}"}
              >
                {Categories.label(code)}
              </.select_item>
            </.select_group>
          </.select_content>
        </.select>
        <.button size="sm" variant="outline" type="submit" class="cl-search-button">
          <:icon><Icons.icon_btn_find class="w-4 h-4" /></:icon>
          {dgettext("dialogs", "Search")}
        </.button>
      </form>

      <%!-- Said once above the rows, with its own way out: a list narrowed to
            one subject that does not say so reads as the whole catalogue. --%>
      <div :if={@category} class="cl-category-strip" data-testid="channel-list-category-strip">
        <.channel_category category={@category} />
        <span class="cl-category-strip__label">
          {dgettext("dialogs", "Category: %{category}", category: Categories.label(@category))}
        </span>
        <.tool_button
          label={dgettext("dialogs", "Show every category")}
          variant="flat"
          size="xs"
          phx-click={@on_search}
          phx-value-search={@search}
          phx-value-category=""
          data-testid="channel-list-category-clear"
        >
          <Icons.icon_close class="h-3 w-3" />
        </.tool_button>
      </div>

      <%!-- Channel list --%>
      <div class="cl-channel-list">
        <%= if @loading do %>
          <div class="cl-loading-state">
            <.activity_indicator
              icon={:channels}
              variant="panel"
              text={dgettext("dialogs", "Searching...")}
            />
          </div>
        <% else %>
          <%= if @channels == [] do %>
            <div class="cl-empty-state">
              <Icons.icon_channels class="w-4 h-4" />
              <p>{dgettext("dialogs", "No channels found")}</p>
            </div>
          <% else %>
            <.action_list id={"#{@id}-rows"} label={dgettext("dialogs", "Channels")}>
              <.action_row
                :for={ch <- @channels}
                on_activate={if request_access?(ch), do: @on_knock, else: @on_join}
                value={%{"channel" => ch.name}}
                data-testid={"channel-list-row-#{ch.name}"}
              >
                <:icon><Icons.icon_channels class="w-4 h-4" /></:icon>
                <:cta label={
                  if request_access?(ch),
                    do: dgettext("dialogs", "Request Access..."),
                    else: dgettext("dialogs", "Join")
                }>
                  <Icons.icon_btn_add :if={not request_access?(ch)} class="w-4 h-4" />
                  <Icons.icon_dialog_invite :if={request_access?(ch)} class="w-4 h-4" />
                </:cta>
                <:title>
                  <%!-- The language the founder says the room speaks, ahead
                        of its name as a nickname's flag is. The title is a
                        flex row, so its gap does the spacing. --%>
                  <.channel_badges category={Map.get(ch, :category)} locale={Map.get(ch, :locale)} />
                  {ch.name}
                  <.badge
                    :if={invite_only?(ch)}
                    variant="secondary"
                    class="cl-channel-badge"
                    data-testid={"channel-list-invite-only-#{ch.name}"}
                  >
                    +i
                  </.badge>
                </:title>
                <:meta>{display_topic(ch.topic)}</:meta>
                <:trailing>
                  <.action_figure label={dgettext("dialogs", "Users")} value={ch.user_count} />
                  <.action_figure
                    :if={invite_only?(ch)}
                    label={dgettext("dialogs", "Mode")}
                    value={dgettext("dialogs", "Invite only")}
                  />
                  <%!--
                    A room with nobody in it right now is still a room. Saying
                    when it was last used is the difference between "empty" and
                    "abandoned", and it is the only thing the reader can act on.
                  --%>
                  <.action_figure
                    :if={last_used(ch)}
                    label={dgettext("dialogs", "Last used")}
                    value={last_used(ch)}
                    data-testid={"channel-list-activity-#{ch.name}"}
                  />
                </:trailing>
              </.action_row>
            </.action_list>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  # A closed room you are not in cannot be entered, only knocked on. It is a
  # property of the row, so the verb it draws never changes under the pointer.
  defp request_access?(channel), do: invite_only?(channel) and not joined?(channel)

  defp invite_only?(channel), do: Map.get(channel, :invite_only?, false)
  defp joined?(channel), do: Map.get(channel, :joined?, false)

  # Asked of a room with nobody in it, and only then: with people inside, the
  # count is the fresher fact and two numbers competing for the same slot is how
  # a row stops being readable. Whether a process happens to be holding the
  # channel open is not the reader's question — "is anyone there" is.
  defp last_used(channel) do
    with 0 <- Map.get(channel, :user_count, 0),
         %DateTime{} = at <- Map.get(channel, :last_activity_at) do
      TimeFormatter.format_relative(at)
    else
      _occupied_or_unknown -> nil
    end
  end

  defp display_topic(nil), do: dgettext("dialogs", "No topic set")
  defp display_topic(""), do: dgettext("dialogs", "No topic set")
  defp display_topic(topic), do: topic

  # Joining opens a tab, which is where the reader meets the room next. The
  # first two rows become the tabs; anything after them is drawn in the well,
  # so the third line is what the first of those rooms is talking about.
  @spec joinable_lines([map()]) :: [map()]
  defp joinable_lines(channels) do
    joinable = channels |> Enum.reject(&Map.get(&1, :joined)) |> Enum.take(2)
    tabs = Enum.map(joinable, &%{text: &1.name, tone: :normal, tab: true})

    case joinable do
      [first | _rest] -> tabs ++ [%{text: display_topic(first.topic), tone: :system}]
      [] -> tabs
    end
  end
end
