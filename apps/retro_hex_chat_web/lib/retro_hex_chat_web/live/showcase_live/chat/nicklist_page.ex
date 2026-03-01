defmodule RetroHexChatWeb.ShowcaseLive.Chat.NicklistPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Nicklist
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Nicklist", active_page: "nicklist")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Nicklist</h2>

      <.showcase_card title="Basic Nicklist" description="User list with status indicators.">
        <div class="max-w-[180px]">
          <.nicklist class="min-h-[120px]">
            <.nicklist_item
              nick="Troll"
              status="online"
              role={:operator}
              nick_color="text-success-dark"
            />
            <.nicklist_item nick="Brutus" status="online" nick_color="text-teal" />
            <.nicklist_item nick="Patches" status="online" nick_color="text-error" />
            <.nicklist_item nick="Reginald" status="away" nick_color="text-link" />
          </.nicklist>
        </div>
        <.code_example>
          &lt;.nicklist&gt;
          &lt;.nicklist_item nick="Troll" status="online" role={:operator} nick_color="text-success-dark" /&gt;
          &lt;.nicklist_item nick="Brutus" status="online" nick_color="text-teal" /&gt;
          &lt;.nicklist_item nick="Reginald" status="away" nick_color="text-link" /&gt;
          &lt;/.nicklist&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card title="User Statuses" description="Online, away, and offline status indicators.">
        <div class="max-w-[180px]">
          <.nicklist>
            <.nicklist_item nick="OnlineUser" status="online" />
            <.nicklist_item nick="AwayUser" status="away" />
            <.nicklist_item nick="OfflineUser" status="offline" />
          </.nicklist>
        </div>
        <.code_example>
          &lt;.nicklist_item nick="OnlineUser" status="online" /&gt;
          &lt;.nicklist_item nick="AwayUser" status="away" /&gt;
          &lt;.nicklist_item nick="OfflineUser" status="offline" /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card title="Roles" description="Users with operator (@) and voice (+) prefixes.">
        <div class="max-w-[180px]">
          <.nicklist>
            <.nicklist_item nick="Admin" status="online" role={:operator} nick_color="text-error" />
            <.nicklist_item nick="Moderator" status="online" role={:voiced} nick_color="text-warning" />
            <.nicklist_item nick="Regular" status="online" />
            <.nicklist_item nick="Lurker" status="away" />
          </.nicklist>
        </div>
        <.code_example>
          &lt;.nicklist_item nick="Admin" role={:operator} nick_color="text-error" /&gt;
          &lt;.nicklist_item nick="Moderator" role={:voiced} nick_color="text-warning" /&gt;
          &lt;.nicklist_item nick="Regular" /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
