defmodule RetroHexChatWeb.Components.UI.ServerEmojiDialog do
  @moduledoc """
  The window where a server's own emoji are added and taken away.

  Administrators only, because the set belongs to the server: anybody who could
  add to it could put a picture in front of every conversation on it.

  The form is a picture and a name, in that order, because that is the order
  somebody has them in — the file is already on their disk, the name is what
  they are still deciding. The list underneath shows every name the server
  answers to, drawn with the picture it answers with, so a wrong upload is
  visible rather than merely listed.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.ListStates

  alias RetroHexChatWeb.Icons

  @doc "Renders the Server Emoji window body."
  attr :id, :string, required: true
  attr :emojis, :list, default: []
  attr :max_count, :integer, required: true
  attr :upload, :any, default: nil, doc: "the `@uploads.emoji` entry list"
  attr :name, :string, default: ""
  attr :error, :string, default: nil
  attr :target, :any, default: nil

  @spec server_emoji_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def server_emoji_panel(assigns) do
    ~H"""
    <div id={"#{@id}-panel"} class="flex h-full min-h-0 flex-col gap-retro-4">
      <form
        id={"#{@id}-form"}
        class="shrink-0 space-y-retro-4 bg-white p-2 shadow-retro-field"
        phx-submit="server_emoji_add"
        phx-change="server_emoji_validate"
        phx-target={@target}
      >
        <%!-- The native control is hidden behind a label styled like every other
              control here: a browser's own file button is the one thing on this
              desktop that looks like it came from a different decade. --%>
        <label class="flex items-center gap-retro-4">
          <span class="w-20 shrink-0">{dgettext("dialogs", "Picture")}</span>
          <span class="shadow-retro-raised cursor-pointer bg-surface px-2 py-[2px]">
            {dgettext("dialogs", "Choose...")}
          </span>
          <span class="min-w-0 flex-1 truncate text-muted-foreground" data-testid="server-emoji-file">
            {chosen(@upload)}
          </span>
          <.live_file_input upload={@upload} class="sr-only" />
        </label>

        <label class="flex items-center gap-retro-4">
          <span class="w-20 shrink-0">{dgettext("dialogs", "Name")}</span>
          <span class="text-muted-foreground">:</span>
          <input
            type="text"
            name="name"
            value={@name}
            maxlength="32"
            autocomplete="off"
            class="flex-1 bg-white px-1 shadow-retro-field"
            placeholder={dgettext("dialogs", "shrug")}
            data-testid="server-emoji-name"
          />
          <span class="text-muted-foreground">:</span>
        </label>

        <div class="flex items-center gap-retro-4">
          <.button type="submit" size="sm" data-testid="server-emoji-submit">
            <:icon><Icons.icon_btn_ok class="h-4 w-4" /></:icon>
            {dgettext("dialogs", "Add")}
          </.button>
          <span class="text-muted-foreground">
            {dngettext(
              "dialogs",
              "%{count} of %{max} used",
              "%{count} of %{max} used",
              length(@emojis),
              count: length(@emojis),
              max: @max_count
            )}
          </span>
        </div>

        <p :if={@error} class="text-destructive" data-testid="server-emoji-error">{@error}</p>
      </form>

      <.list_empty_state
        :if={@emojis == []}
        icon={:chat}
        title={dgettext("dialogs", "This server has no emoji of its own yet.")}
        text={
          dgettext(
            "dialogs",
            "Add one and everybody here can write it between two colons, like :shrug:."
          )
        }
      />

      <div
        :if={@emojis != []}
        class="min-h-[120px] flex-1 overflow-y-auto bg-white p-1 shadow-retro-field retro-scrollbar"
        data-testid="server-emoji-list"
      >
        <div
          :for={emoji <- @emojis}
          class="flex items-center gap-retro-4 border-b border-border p-2 last:border-b-0"
          data-testid={"server-emoji-row-#{emoji.name}"}
        >
          <img
            class="chat-emoji"
            src={"/chat/emoji/#{emoji.id}"}
            alt={":#{emoji.name}:"}
            loading="lazy"
          />
          <span class="flex-1 truncate">:{emoji.name}:</span>
          <.button
            type="button"
            size="sm"
            variant="outline"
            phx-click="server_emoji_remove"
            phx-target={@target}
            phx-value-id={emoji.id}
            data-testid={"server-emoji-remove-#{emoji.name}"}
          >
            <:icon><Icons.icon_reject class="h-4 w-4" /></:icon>
            {dgettext("dialogs", "Remove")}
          </.button>
        </div>
      </div>
    </div>
    """
  end

  # What the reader picked, or the fact that they have not. The entry list is
  # LiveView's; reading it here keeps the label honest without a second copy of
  # the upload state.
  @spec chosen(map() | nil) :: String.t()
  defp chosen(%{entries: [entry | _rest]}), do: entry.client_name

  defp chosen(_upload), do: dgettext("dialogs", "no picture chosen")
end
