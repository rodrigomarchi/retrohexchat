defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.AliasDialogPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.AliasDialog
  import RetroHexChatWeb.ShowcaseHelpers

  @sample_aliases [
    %{name: "hi", expansion: dgettext("showcase", "/msg $1 hello!")},
    %{name: "bye", expansion: dgettext("showcase", "/msg $1 goodbye!")},
    %{name: "away", expansion: dgettext("showcase", "/away $1-")},
    %{name: "op", expansion: dgettext("showcase", "/mode $chan +o $1")}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "Alias Dialog"),
       active_page: "alias-dialog",
       aliases: @sample_aliases
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
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Alias Dialog")}</h2>

      <.showcase_card
        title={dgettext("showcase", "Default State")}
        description="Alias editor with sample entries. No row selected — Edit and Remove buttons are disabled."
      >
        <div class="relative h-[380px] shadow-retro-field overflow-hidden p-2">
          <.alias_panel id="alias-dialog-default" aliases={@aliases} />
        </div>
        <.code_example>
          &lt;.alias_panel
          id="aliases"
          aliases=&#123;@aliases&#125;
          on_add="alias_add"
          on_edit="alias_edit"
          on_delete="alias_delete"
          on_save="alias_save"
          on_cancel_edit="alias_cancel"
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Row Selected")}
        description="A row is selected (highlighted). Edit and Remove buttons become active."
      >
        <div class="relative h-[380px] shadow-retro-field overflow-hidden p-2">
          <.alias_panel id="alias-dialog-selected" aliases={@aliases} selected_alias="hi" />
        </div>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Editing State")}
        description="Edit form panel is visible below the table. Form shows 'Edit Alias' with pre-filled values."
      >
        <div class="relative h-[380px] shadow-retro-field overflow-hidden p-2">
          <.alias_panel
            id="alias-dialog-editing"
            aliases={@aliases}
            selected_alias="hi"
            editing={true}
            draft_name="hi"
            draft_expansion="/msg $1 hello!"
          />
        </div>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Adding New Alias")}
        description="Edit form in 'add' mode — name field is editable, form shows 'Add Alias'."
      >
        <div class="relative h-[380px] shadow-retro-field overflow-hidden p-2">
          <.alias_panel
            id="alias-dialog-adding"
            aliases={@aliases}
            editing={true}
            draft_name=""
            draft_expansion=""
          />
        </div>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Empty List")}
        description="No aliases configured — table shows empty state message."
      >
        <div class="relative h-[380px] shadow-retro-field overflow-hidden p-2">
          <.alias_panel id="alias-dialog-empty" aliases={[]} />
        </div>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
