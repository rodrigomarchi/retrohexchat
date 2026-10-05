defmodule RetroHexChatWeb.LandingLive.MircCommands do
  @moduledoc """
  The mIRC commands a reader's fingers remember, and what each one does here.

  This is the page a search for "mIRC commands" should land on. It does not
  list this product's commands — the help's commands overview does that — it
  answers the question a mIRC user arrives with: does what I used to type
  still work? The rows come from `RetroHexChat.Commands.MircParity`.
  """
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.LandingLive.LandingHelpers
  import RetroHexChatWeb.Components.UI.Landing.IrcGuides

  alias RetroHexChat.Commands.MircParity
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.LandingLive.Guides
  alias RetroHexChatWeb.PublicPages

  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    groups =
      for {group, label} <- MircParity.groups() do
        %{id: "parity-#{group}", label: label, rows: Enum.map(MircParity.rows(group), &row/1)}
      end

    {:ok,
     assign(socket,
       active_page: :mirc_commands,
       groups: groups,
       links: Guides.links(:mirc_commands),
       windows:
         [%{id: "intro", label: dgettext("landing", "mIRC commands"), icon: :icon_terminal}] ++
           Enum.map(groups, &%{id: &1.id, label: &1.label, icon: :icon_terminal}) ++
           [%{id: "read-next", label: dgettext("landing", "Read next"), icon: :icon_link}],
       canonical_path: PublicPages.path(:mirc_commands),
       json_ld: [Guides.breadcrumb(:mirc_commands)],
       page_title:
         dgettext("landing", "mIRC commands that work in your browser — Retro Hex Chat"),
       page_description:
         dgettext(
           "landing",
           "Coming from mIRC? See which of its commands, such as /join, /msg and /mode, work the same in this browser chat, which work differently, and what to type instead."
         )
     )}
  end

  defp row(row) do
    Map.put(
      row,
      :help_path,
      row.help_topic && PublicPages.localized_path("/chat/help/#{row.help_topic}")
    )
  end
end
