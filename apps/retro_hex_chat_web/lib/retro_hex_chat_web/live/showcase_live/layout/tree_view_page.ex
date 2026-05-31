defmodule RetroHexChatWeb.ShowcaseLive.Layout.TreeViewPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.TreeView
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: dgettext("showcase", "Tree View"), active_page: "tree-view")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Tree View")}</h2>

      <.showcase_card
        title={dgettext("showcase", "Basic Tree")}
        description="A simple two-level tree with groups and items."
      >
        <div class="max-w-xs">
          <.tree_view>
            <.tree_view_group label={dgettext("showcase", "Documents")}>
              <.tree_view_item>{dgettext("showcase", "readme.txt")}</.tree_view_item>
              <.tree_view_item>{dgettext("showcase", "notes.md")}</.tree_view_item>
              <.tree_view_item active>{dgettext("showcase", "report.pdf")}</.tree_view_item>
            </.tree_view_group>
            <.tree_view_group label={dgettext("showcase", "Images")}>
              <.tree_view_item>{dgettext("showcase", "photo.jpg")}</.tree_view_item>
              <.tree_view_item>{dgettext("showcase", "logo.png")}</.tree_view_item>
            </.tree_view_group>
          </.tree_view>
        </div>
        <.code_example>
          &lt;.tree_view&gt;
          &lt;.tree_view_group label="Documents"&gt;
          &lt;.tree_view_item&gt;readme.txt&lt;/.tree_view_item&gt;
          &lt;.tree_view_item active&gt;report.pdf&lt;/.tree_view_item&gt;
          &lt;/.tree_view_group&gt;
          &lt;/.tree_view&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "IRC Sidebar")}
        description="Platform-style sidebar with channels, PMs, and collapsible groups."
      >
        <div class="max-w-[200px]">
          <.tree_view>
            <.tree_view_group label={dgettext("showcase", "My Channels")}>
              <.tree_view_item active>
                <:icon><span class="text-teal font-bold text-xs">#</span></:icon>
                {dgettext("showcase", "#lobby (4)")}
              </.tree_view_item>
            </.tree_view_group>
            <.tree_view_group label={dgettext("showcase", "Private Messages")}>
              <.tree_view_item>
                <:icon><span class="text-action font-bold text-xs">M</span></:icon>
                {dgettext("showcase", "DoeJoe")}
              </.tree_view_item>
              <.tree_view_item>
                <:icon><span class="text-action font-bold text-xs">M</span></:icon>
                bruno
              </.tree_view_item>
              <.tree_view_item>
                <:icon><span class="text-action font-bold text-xs">M</span></:icon>
                {dgettext("showcase", "Reginald")}
              </.tree_view_item>
            </.tree_view_group>
            <.tree_view_group label={dgettext("showcase", "Popular Channels")} open={false}>
              <.tree_view_item>
                <:icon><span class="text-teal font-bold text-xs">#</span></:icon>
                #general
              </.tree_view_item>
              <.tree_view_item>
                <:icon><span class="text-teal font-bold text-xs">#</span></:icon>
                #help
              </.tree_view_item>
            </.tree_view_group>
          </.tree_view>
        </div>
        <.code_example>
          &lt;.tree_view_group label="My Channels"&gt;
          &lt;.tree_view_item active&gt;
          &lt;:icon&gt;&lt;span class="text-teal font-bold"&gt;#&lt;/span&gt;&lt;/:icon&gt;
          #lobby (4)
          &lt;/.tree_view_item&gt;
          &lt;/.tree_view_group&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Collapsed Groups")}
        description="Groups can start collapsed using open={false}."
      >
        <div class="max-w-xs">
          <.tree_view>
            <.tree_view_group label={dgettext("showcase", "Open Group")}>
              <.tree_view_item>{dgettext("showcase", "Item 1")}</.tree_view_item>
              <.tree_view_item>{dgettext("showcase", "Item 2")}</.tree_view_item>
            </.tree_view_group>
            <.tree_view_group label={dgettext("showcase", "Collapsed Group")} open={false}>
              <.tree_view_item>{dgettext("showcase", "Hidden Item 1")}</.tree_view_item>
              <.tree_view_item>{dgettext("showcase", "Hidden Item 2")}</.tree_view_item>
            </.tree_view_group>
          </.tree_view>
        </div>
        <.code_example>
          &lt;.tree_view_group label="Open Group"&gt;...&lt;/.tree_view_group&gt;
          &lt;.tree_view_group label="Collapsed Group" open=&#123;false&#125;&gt;...&lt;/.tree_view_group&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
