defmodule RetroHexChatWeb.ShowcaseLive.Primitives.BreadcrumbPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Breadcrumb
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Breadcrumb", active_page: "breadcrumb")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Breadcrumb</h2>

      <.showcase_card title="Basic Breadcrumb" description="Navigation breadcrumb trail.">
        <.breadcrumb>
          <.breadcrumb_list>
            <.breadcrumb_item>
              <.breadcrumb_link href="#">Home</.breadcrumb_link>
            </.breadcrumb_item>
            <.breadcrumb_separator />
            <.breadcrumb_item>
              <.breadcrumb_link href="#">Settings</.breadcrumb_link>
            </.breadcrumb_item>
            <.breadcrumb_separator />
            <.breadcrumb_item>
              <.breadcrumb_page>Profile</.breadcrumb_page>
            </.breadcrumb_item>
          </.breadcrumb_list>
        </.breadcrumb>
        <.code_example>
          &lt;.breadcrumb&gt;
          &lt;.breadcrumb_list&gt;
          &lt;.breadcrumb_item&gt;
          &lt;.breadcrumb_link href="#"&gt;Home&lt;/.breadcrumb_link&gt;
          &lt;/.breadcrumb_item&gt;
          &lt;.breadcrumb_separator /&gt;
          &lt;.breadcrumb_item&gt;
          &lt;.breadcrumb_page&gt;Profile&lt;/.breadcrumb_page&gt;
          &lt;/.breadcrumb_item&gt;
          &lt;/.breadcrumb_list&gt;
          &lt;/.breadcrumb&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="With Ellipsis"
        description="Breadcrumb with collapsed intermediate items."
      >
        <.breadcrumb>
          <.breadcrumb_list>
            <.breadcrumb_item>
              <.breadcrumb_link href="#">Home</.breadcrumb_link>
            </.breadcrumb_item>
            <.breadcrumb_separator />
            <.breadcrumb_item>
              <.breadcrumb_ellipsis />
            </.breadcrumb_item>
            <.breadcrumb_separator />
            <.breadcrumb_item>
              <.breadcrumb_link href="#">Components</.breadcrumb_link>
            </.breadcrumb_item>
            <.breadcrumb_separator />
            <.breadcrumb_item>
              <.breadcrumb_page>Breadcrumb</.breadcrumb_page>
            </.breadcrumb_item>
          </.breadcrumb_list>
        </.breadcrumb>
        <.code_example>
          &lt;.breadcrumb_item&gt;
          &lt;.breadcrumb_ellipsis /&gt;
          &lt;/.breadcrumb_item&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
