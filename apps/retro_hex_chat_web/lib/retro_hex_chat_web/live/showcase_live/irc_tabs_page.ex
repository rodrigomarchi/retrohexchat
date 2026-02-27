defmodule RetroHexChatWeb.ShowcaseLive.IrcTabsPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.IrcTabs
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "IRC Tabs", active_page: "irc-tabs")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">IRC Tabs</h2>

      <.showcase_card title="Channel Tabs" description="Tab strip with channel-type tabs.">
        <.irc_tab_bar>
          <.irc_tab_item type="status" label="Status" closeable={false} />
          <.irc_tab_item type="channel" label="#lobby" active />
          <.irc_tab_item type="channel" label="#general" />
          <.irc_tab_item type="channel" label="#help" />
        </.irc_tab_bar>
        <.code_example>
          &lt;.irc_tab_bar&gt;
          &lt;.irc_tab_item type="status" label="Status" closeable=&#123;false&#125; /&gt;
          &lt;.irc_tab_item type="channel" label="#lobby" active /&gt;
          &lt;.irc_tab_item type="channel" label="#general" /&gt;
          &lt;/.irc_tab_bar&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card title="Mixed Types" description="Channels and private message tabs together.">
        <.irc_tab_bar>
          <.irc_tab_item type="status" label="Status" closeable={false} />
          <.irc_tab_item type="channel" label="#lobby" active />
          <.irc_tab_item type="pm" label="bruno" />
          <.irc_tab_item type="pm" label="DoeJoe" unread />
          <.irc_tab_item type="channel" label="#general" />
        </.irc_tab_bar>
        <.code_example>
          &lt;.irc_tab_item type="channel" label="#lobby" active /&gt;
          &lt;.irc_tab_item type="pm" label="bruno" /&gt;
          &lt;.irc_tab_item type="pm" label="DoeJoe" unread /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card title="States" description="Active, unread, and normal tab states.">
        <.irc_tab_bar>
          <.irc_tab_item type="channel" label="Normal" />
          <.irc_tab_item type="channel" label="Active" active />
          <.irc_tab_item type="channel" label="Unread" unread />
          <.irc_tab_item type="pm" label="PM Normal" />
          <.irc_tab_item type="pm" label="PM Unread" unread />
        </.irc_tab_bar>
        <.code_example>
          &lt;.irc_tab_item type="channel" label="Normal" /&gt;
          &lt;.irc_tab_item type="channel" label="Active" active /&gt;
          &lt;.irc_tab_item type="channel" label="Unread" unread /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card title="Without Close Button" description="Tabs can hide their close button.">
        <.irc_tab_bar>
          <.irc_tab_item type="status" label="Status" closeable={false} active />
          <.irc_tab_item type="channel" label="#lobby" closeable={false} />
        </.irc_tab_bar>
        <.code_example>
          &lt;.irc_tab_item type="status" label="Status" closeable=&#123;false&#125; /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
