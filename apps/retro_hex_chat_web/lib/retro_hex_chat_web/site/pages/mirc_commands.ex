defmodule RetroHexChatWeb.Site.Pages.MircCommands do
  @moduledoc """
  The mIRC commands a reader's fingers remember, and what each one does here.

  This is the page a search for "mIRC commands" should land on. It does not
  list this product's commands — the help's commands overview does that — it
  answers the question a mIRC user arrives with: does what I used to type
  still work? The rows come from `RetroHexChat.Commands.MircParity`.
  """
  use RetroHexChatWeb.Site.Page

  alias RetroHexChat.Commands.MircParity
  alias RetroHexChatWeb.PublicPages
  alias RetroHexChatWeb.Site.Pages.Guides

  @impl RetroHexChatWeb.Site.Page
  def load(_params, _ctx) do
    groups =
      for {group, label} <- MircParity.groups() do
        %{id: "parity-#{group}", label: label, rows: Enum.map(MircParity.rows(group), &row/1)}
      end

    {:ok,
     %{
       active_page: :mirc_commands,
       groups: groups,
       links: Guides.links(:mirc_commands),
       windows:
         [
           Window.new(
             "intro",
             dgettext("landing", "Your mIRC commands, in the browser"),
             :icon_terminal,
             width: 640,
             taskbar_label: dgettext("landing", "mIRC commands"),
             body: &page_intro/1,
             assigns: %{
               heading_id: "mirc-commands-heading",
               description:
                 dgettext(
                   "landing",
                   "Retro Hex Chat is a chat in the style of mIRC that runs in the browser, and most of what your fingers remember still works. Below are the commands mIRC users type most, each marked the same, different, or not here — with what to type instead."
                 )
             },
             status: [dgettext("landing", "Commands start with a slash")]
           )
         ] ++ Enum.map(groups, &Guides.parity_window/1) ++ [Guides.read_next_window()],
       canonical_path: PublicPages.path(:mirc_commands),
       json_ld: [Guides.breadcrumb(:mirc_commands)],
       page_title:
         dgettext("landing", "mIRC commands that work in your browser — Retro Hex Chat"),
       page_description:
         dgettext(
           "landing",
           "Coming from mIRC? See which of its commands, such as /join, /msg and /mode, work the same in this browser chat, which work differently, and what to type instead."
         )
     }}
  end

  defp row(row) do
    Map.put(
      row,
      :help_path,
      row.help_topic && PublicPages.help_topic_path(row.help_topic)
    )
  end
end
