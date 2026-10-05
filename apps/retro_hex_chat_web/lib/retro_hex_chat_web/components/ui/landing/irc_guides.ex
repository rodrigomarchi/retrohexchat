defmodule RetroHexChatWeb.Components.UI.Landing.IrcGuides do
  @moduledoc """
  The pieces the mIRC and IRC guide pages share: a group of the mIRC parity
  table, the questions a page answers, and the window that leads to the other
  guides.

  Built on the shared `desktop_window`, `table`, `badge` and `accordion`
  primitives. Every path and every string arrives prepared by the page — these
  components never read the locale or build an address themselves.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Accordion
  import RetroHexChatWeb.Components.UI.Badge
  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.Table
  import RetroHexChatWeb.Components.UI.Window

  alias RetroHexChatWeb.Icons

  attr :id, :string, required: true
  attr :title, :string, required: true

  attr :rows, :list,
    required: true,
    doc: "`RetroHexChat.Commands.MircParity` rows, each with a `help_path` or nil"

  @doc """
  One group of the parity table: what a mIRC user types, whether it works the
  same here, and what to type instead. A command with a help topic links to it,
  so the page says what changes and the help says how it works.
  """
  @spec parity_window(map()) :: Phoenix.LiveView.Rendered.t()
  def parity_window(assigns) do
    ~H"""
    <.desktop_window id={@id} width={720} title={@title}>
      <:icon><Icons.icon_terminal class="w-4 h-4" /></:icon>
      <h2 class="text-sm font-bold mb-2">{@title}</h2>
      <.table data-testid={"parity-#{@id}"}>
        <.table_header>
          <.table_row>
            <.table_head>{dgettext("landing", "In mIRC")}</.table_head>
            <.table_head>{dgettext("landing", "Here")}</.table_head>
            <.table_head>{dgettext("landing", "What to know")}</.table_head>
          </.table_row>
        </.table_header>
        <.table_body>
          <.table_row :for={row <- @rows}>
            <.table_cell class="font-mono whitespace-nowrap">{row.mirc}</.table_cell>
            <.table_cell class="whitespace-nowrap">
              <.parity_badge status={row.status} />
              <.link
                :if={row.here && row.help_path}
                navigate={row.help_path}
                class="font-mono underline ml-1"
              >
                /{row.here}
              </.link>
              <span :if={row.here && !row.help_path} class="font-mono ml-1">/{row.here}</span>
            </.table_cell>
            <.table_cell>
              {row.note}
              <code :if={row.usage} class="font-mono whitespace-nowrap ml-1">{row.usage}</code>
            </.table_cell>
          </.table_row>
        </.table_body>
      </.table>
      <:status>
        <.window_status_bar_field grow>
          {dngettext("landing", "%{count} command", "%{count} commands", length(@rows))}
        </.window_status_bar_field>
      </:status>
    </.desktop_window>
    """
  end

  attr :status, :atom, required: true

  defp parity_badge(%{status: :same} = assigns) do
    ~H"""
    <.badge variant="success">{dgettext("landing", "Same")}</.badge>
    """
  end

  defp parity_badge(%{status: :different} = assigns) do
    ~H"""
    <.badge variant="warning">{dgettext("landing", "Different")}</.badge>
    """
  end

  defp parity_badge(%{status: :missing} = assigns) do
    ~H"""
    <.badge variant="outline">{dgettext("landing", "Not here")}</.badge>
    """
  end

  attr :id, :string, default: "questions"
  attr :entries, :list, required: true, doc: "{question, answer} pairs, translated"

  @doc """
  The questions a guide answers. The page states the same pairs as `FAQPage`
  structured data, so they come from one list and cannot drift apart.
  """
  @spec guide_questions(map()) :: Phoenix.LiveView.Rendered.t()
  def guide_questions(assigns) do
    ~H"""
    <.desktop_window id={@id} width={560} title={dgettext("landing", "Questions")}>
      <:icon><Icons.icon_question class="w-4 h-4" /></:icon>
      <h2 class="text-sm font-bold mb-2">{dgettext("landing", "Questions")}</h2>
      <.accordion>
        <.accordion_item :for={{question, answer} <- @entries}>
          <.accordion_trigger group={"#{@id}-faq"}>
            <:icon><Icons.icon_question class="w-4 h-4" /></:icon>
            {question}
          </.accordion_trigger>
          <.accordion_content>
            <p class="text-sm">{answer}</p>
          </.accordion_content>
        </.accordion_item>
      </.accordion>
    </.desktop_window>
    """
  end

  attr :links, :list, required: true, doc: "%{label, path, icon} per link, paths localized"

  @doc "Where to go from a guide: the other guides, the full command help and the games."
  @spec guide_links(map()) :: Phoenix.LiveView.Rendered.t()
  def guide_links(assigns) do
    ~H"""
    <.desktop_window id="read-next" width={360} title={dgettext("landing", "Read next")}>
      <:icon><Icons.icon_link class="w-4 h-4" /></:icon>
      <h2 class="text-sm font-bold mb-2">{dgettext("landing", "Read next")}</h2>
      <ul class="text-sm space-y-1" data-testid="guide-links">
        <li :for={link <- @links}>
          <.link navigate={link.path} class="inline-flex items-center gap-1 underline">
            {apply(Icons, link.icon, [%{class: "w-3 h-3 shrink-0"}])}
            {link.label}
          </.link>
        </li>
      </ul>
    </.desktop_window>
    """
  end
end
