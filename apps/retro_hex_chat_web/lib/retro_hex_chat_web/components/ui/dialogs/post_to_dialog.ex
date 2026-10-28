defmodule RetroHexChatWeb.Components.UI.PostToDialog do
  @moduledoc """
  "Post to…" for a picture made in a tool window: what will be posted, the
  conversation it goes to, an optional line of text with a drawing, and Post.

  Shared by Hex Paint and ASCII Art. The window that opens it owns the state
  and the events (`target`); this draws the form, anchored over that window.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog

  import RetroHexChatWeb.Components.UI.Form,
    only: [form_item: 1, form_description: 1, form_message: 1]

  import RetroHexChatWeb.Components.UI.Inset
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Label
  import RetroHexChatWeb.Components.UI.Select

  alias RetroHexChatWeb.Icons

  attr :id, :string, required: true
  attr :target, :any, required: true, doc: "the window island the events go to"
  attr :title, :string, required: true

  attr :options, :list,
    required: true,
    doc: "the conversations to post into (`ToolPost.options/1`)"

  attr :selected, :string, default: nil
  attr :caption?, :boolean, default: false, doc: "offer a line of text to send with it"
  attr :error, :string, default: nil
  attr :ready?, :boolean, default: true, doc: "whether there is something to post yet"
  attr :submit, :string, required: true
  attr :cancel, :string, required: true
  slot :preview, required: true, doc: "what will be posted"

  @spec post_to_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def post_to_dialog(assigns) do
    ~H"""
    <.dialog
      id={@id}
      show
      scope={:window}
      on_cancel={JS.push(@cancel, target: @target)}
      class="md:max-w-md"
    >
      <.dialog_header id={@id} title={@title} on_close={JS.push(@cancel, target: @target)}>
        <:icon><Icons.icon_file_send class="h-4 w-4" /></:icon>
      </.dialog_header>
      <.dialog_body>
        <.form
          for={%{}}
          id={"#{@id}-form"}
          phx-submit={@submit}
          phx-target={@target}
          class="flex flex-col gap-retro-8"
          data-testid={"#{@id}-form"}
        >
          <.inset bevel="sunken" tone="paper" class="p-retro-4" data-testid={"#{@id}-preview"}>
            {render_slot(@preview)}
          </.inset>

          <.form_item :if={@options != []}>
            <.label for={"#{@id}-target"}>{dgettext("dialogs", "Post to:")}</.label>
            <.select
              :let={builder}
              id={"#{@id}-target"}
              name="target"
              value={@selected}
              label={label_of(@options, @selected)}
              class="w-full"
              data-testid={"#{@id}-target"}
            >
              <.select_trigger builder={builder} class="h-8 text-sm" />
              <.select_content builder={builder}>
                <.select_group>
                  <.select_item
                    :for={option <- @options}
                    builder={builder}
                    value={option.value}
                    label={option.label}
                  >
                    {option.label}
                  </.select_item>
                </.select_group>
              </.select_content>
            </.select>
          </.form_item>

          <.form_item :if={@caption?}>
            <.label for={"#{@id}-caption"}>{dgettext("dialogs", "Message (optional):")}</.label>
            <.input
              id={"#{@id}-caption"}
              name="caption"
              type="text"
              maxlength="300"
              autocomplete="off"
              data-testid={"#{@id}-caption"}
            />
          </.form_item>

          <.form_description :if={@options == []} data-testid={"#{@id}-nowhere"}>
            {dgettext("dialogs", "Join a channel first: there is nowhere to post yet.")}
          </.form_description>
          <.form_message :if={@error} role="alert" data-testid={"#{@id}-error"}>
            {@error}
          </.form_message>

          <.dialog_footer>
            <.button
              type="submit"
              disabled={@options == [] or not @ready?}
              data-testid={"#{@id}-submit"}
            >
              <:icon><Icons.icon_file_send class="h-4 w-4" /></:icon>
              {dgettext("dialogs", "Post")}
            </.button>
            <.button
              type="button"
              variant="secondary"
              phx-click={@cancel}
              phx-target={@target}
              data-testid={"#{@id}-cancel"}
            >
              <:icon><Icons.icon_close class="h-4 w-4" /></:icon>
              {dgettext("dialogs", "Cancel")}
            </.button>
          </.dialog_footer>
        </.form>
      </.dialog_body>
    </.dialog>
    """
  end

  defp label_of(options, value), do: Enum.find_value(options, &(&1.value == value && &1.label))
end
