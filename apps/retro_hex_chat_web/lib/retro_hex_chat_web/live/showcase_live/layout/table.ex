defmodule RetroHexChatWeb.ShowcaseLive.Layout.Table do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Table
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Table"), active_page: "table")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{gettext("Table")}</h2>

      <.showcase_card
        title={gettext("Usage")}
        description="Displays tabular data with header and body rows."
      >
        <.table>
          <.table_header>
            <.table_row>
              <.table_head>{gettext("Nickname")}</.table_head>
              <.table_head>{gettext("Status")}</.table_head>
              <.table_head>{gettext("Channel")}</.table_head>
            </.table_row>
          </.table_header>
          <.table_body>
            <.table_row>
              <.table_cell>{gettext("Alice")}</.table_cell>
              <.table_cell>{gettext("Online")}</.table_cell>
              <.table_cell>#general</.table_cell>
            </.table_row>
            <.table_row>
              <.table_cell>{gettext("Bob")}</.table_cell>
              <.table_cell>{gettext("Away")}</.table_cell>
              <.table_cell>#random</.table_cell>
            </.table_row>
            <.table_row>
              <.table_cell>{gettext("Charlie")}</.table_cell>
              <.table_cell>{gettext("Offline")}</.table_cell>
              <.table_cell>#help</.table_cell>
            </.table_row>
          </.table_body>
        </.table>
        <.code_example>
          &lt;.table&gt;
          &lt;.table_header&gt;
          &lt;.table_row&gt;
          &lt;.table_head&gt;Nickname&lt;/.table_head&gt;
          &lt;.table_head&gt;Status&lt;/.table_head&gt;
          &lt;/.table_row&gt;
          &lt;/.table_header&gt;
          &lt;.table_body&gt;
          &lt;.table_row&gt;
          &lt;.table_cell&gt;Alice&lt;/.table_cell&gt;
          &lt;.table_cell&gt;Online&lt;/.table_cell&gt;
          &lt;/.table_row&gt;
          &lt;/.table_body&gt;
          &lt;/.table&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={gettext("Caption & Footer")}
        description="Table with caption and footer row for summaries."
      >
        <.table>
          <.table_caption>{gettext("Server statistics — March 2026")}</.table_caption>
          <.table_header>
            <.table_row>
              <.table_head>{gettext("Server")}</.table_head>
              <.table_head>{gettext("Users")}</.table_head>
              <.table_head>{gettext("Channels")}</.table_head>
            </.table_row>
          </.table_header>
          <.table_body>
            <.table_row>
              <.table_cell>{gettext("Sun")}</.table_cell>
              <.table_cell>128</.table_cell>
              <.table_cell>24</.table_cell>
            </.table_row>
            <.table_row>
              <.table_cell>{gettext("Moon")}</.table_cell>
              <.table_cell>64</.table_cell>
              <.table_cell>12</.table_cell>
            </.table_row>
          </.table_body>
          <.table_footer>
            <.table_row>
              <.table_cell class="font-bold">{gettext("Total")}</.table_cell>
              <.table_cell class="font-bold">192</.table_cell>
              <.table_cell class="font-bold">36</.table_cell>
            </.table_row>
          </.table_footer>
        </.table>
        <.code_example>
          &lt;.table&gt;
          &lt;.table_caption&gt;Server statistics&lt;/.table_caption&gt;
          &lt;.table_header&gt;...&lt;/.table_header&gt;
          &lt;.table_body&gt;...&lt;/.table_body&gt;
          &lt;.table_footer&gt;
          &lt;.table_row&gt;
          &lt;.table_cell class="font-bold"&gt;Total&lt;/.table_cell&gt;
          &lt;/.table_row&gt;
          &lt;/.table_footer&gt;
          &lt;/.table&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
