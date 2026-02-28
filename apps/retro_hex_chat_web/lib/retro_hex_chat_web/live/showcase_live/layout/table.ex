defmodule RetroHexChatWeb.ShowcaseLive.Layout.Table do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Table
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Table", active_page: "table")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Table</h2>

      <.showcase_card title="Usage" description="Displays tabular data with header and body rows.">
        <.table>
          <.table_header>
            <.table_row>
              <.table_head>Nickname</.table_head>
              <.table_head>Status</.table_head>
              <.table_head>Channel</.table_head>
            </.table_row>
          </.table_header>
          <.table_body>
            <.table_row>
              <.table_cell>Alice</.table_cell>
              <.table_cell>Online</.table_cell>
              <.table_cell>#general</.table_cell>
            </.table_row>
            <.table_row>
              <.table_cell>Bob</.table_cell>
              <.table_cell>Away</.table_cell>
              <.table_cell>#random</.table_cell>
            </.table_row>
            <.table_row>
              <.table_cell>Charlie</.table_cell>
              <.table_cell>Offline</.table_cell>
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
    </.showcase_layout>
    """
  end
end
