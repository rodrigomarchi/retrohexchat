defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.TimersDialogPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.TimersDialog
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "Timers"),
       active_page: "timers-dialog",
       timers: sample_timers()
     )}
  end

  # A showcase page renders the component and nothing behind it, so the
  # controls it draws have nowhere to go. Answering them is what keeps a
  # click from taking the page down with an unmatched event.
  @impl true
  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Timers")}</h2>

      <.showcase_card
        title={dgettext("showcase", "Scheduled commands")}
        description="Pressing a row opens it in the editor beside the list. Stop belongs to the timer it stops; Add belongs to the panel, because it has no timer to belong to."
      >
        <div class="h-[320px] shadow-retro-field overflow-hidden p-2">
          <.timers_panel id="timers-demo" timers={@timers} />
        </div>
        <.code_example>
          &lt;.timers_panel id="timers" timers=&#123;@timers&#125; on_edit="timers_dialog_edit"
          on_stop="timers_dialog_stop" /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Editing a timer")}
        description="The row the form is about stays marked while the editor is open."
      >
        <div class="h-[420px] shadow-retro-field overflow-hidden p-2">
          <.timers_panel
            id="timers-editing"
            timers={@timers}
            selected_timer="remind"
            editing={true}
            draft_name="remind"
            draft_repeat={true}
            draft_seconds="60"
            draft_command="/me stands up"
          />
        </div>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Nothing scheduled")}
        description="The empty state names what the reader can do about it."
      >
        <div class="h-[200px] shadow-retro-field overflow-hidden p-2">
          <.timers_panel id="timers-empty" timers={%{}} />
        </div>
      </.showcase_card>
    </.showcase_layout>
    """
  end

  defp sample_timers do
    %{
      "remind" => %{type: :repeat, interval: 60, command: "/me stands up", ref: nil},
      "afk" => %{type: :once, interval: 300, command: "/away back later", ref: nil}
    }
  end
end
