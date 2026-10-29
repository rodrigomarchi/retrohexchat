defmodule RetroHexChatWeb.Components.UI.ChatAttachment do
  @moduledoc """
  Rich attachment tiles for chat messages.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.HexPlayer, only: [hex_player: 1]

  alias RetroHexChat.Chat.VoiceMessages
  alias RetroHexChatWeb.Components.UI.Format
  alias RetroHexChatWeb.Icons

  attr :attachments, :list, default: []

  attr :scope, :string,
    default: "chat",
    doc: "where the line is drawn, so the same file's players never share an id"

  @spec attachment_gallery(map()) :: Phoenix.LiveView.Rendered.t()
  def attachment_gallery(assigns) do
    ~H"""
    <div
      :if={@attachments != []}
      class="message-attachments mt-1 flex max-w-full flex-wrap gap-1"
      data-testid="message-attachments"
    >
      <.attachment_tile :for={attachment <- @attachments} attachment={attachment} scope={@scope} />
    </div>
    """
  end

  attr :attachment, :map, required: true
  attr :scope, :string, default: "chat"

  @spec attachment_tile(map()) :: Phoenix.LiveView.Rendered.t()
  def attachment_tile(assigns) do
    assigns = assign(assigns, :preview_kind, preview_kind(assigns.attachment))

    ~H"""
    <%= case tile_kind(@attachment) do %>
      <% "image" -> %>
        <.image_tile attachment={@attachment} />
      <% "video" -> %>
        <.video_tile attachment={@attachment} scope={@scope} />
      <% "voice" -> %>
        <.voice_tile attachment={@attachment} scope={@scope} />
      <% "audio" -> %>
        <.audio_tile attachment={@attachment} scope={@scope} />
      <% _kind_or_nil -> %>
        <.file_tile attachment={@attachment} />
    <% end %>
    """
  end

  attr :attachment, :map, required: true

  # The picture is the content, so it is drawn alone: no title bar, no frame.
  # Its name and size are what the file manager says about it, and they stay
  # where they are looked for — the tooltip and the accessible name.
  defp image_tile(assigns) do
    assigns =
      assign(
        assigns,
        :label,
        "#{filename(assigns.attachment)} · #{Format.bytes(attachment_byte_size(assigns.attachment))}"
      )

    ~H"""
    <a
      href={attachment_href(@attachment)}
      target="_blank"
      rel="noopener"
      data-confirm-tab="attachment"
      data-confirm-label={confirm_label(@attachment)}
      class="message-attachment-picture"
      data-testid="message-attachment"
      data-preview-kind={preview_kind(@attachment)}
      title={@label}
      aria-label={@label}
    >
      <img
        src={preview_href(@attachment)}
        alt={filename(@attachment)}
        loading="lazy"
        data-testid="message-attachment-image-preview"
      />
    </a>
    """
  end

  attr :attachment, :map, required: true
  attr :scope, :string, required: true

  defp video_tile(assigns) do
    ~H"""
    <div
      data-testid="message-attachment"
      data-preview-kind={preview_kind(@attachment)}
      title={logical_path(@attachment)}
    >
      <.hex_player
        id={player_id(@scope, @attachment)}
        kind={:video}
        src={preview_href(@attachment)}
        title={filename(@attachment)}
        testid="message-attachment-video-preview"
      >
        <.player_foot attachment={@attachment} />
      </.hex_player>
    </div>
    """
  end

  attr :attachment, :map, required: true
  attr :scope, :string, required: true

  defp audio_tile(assigns) do
    ~H"""
    <div
      data-testid="message-attachment"
      data-preview-kind={preview_kind(@attachment)}
      title={logical_path(@attachment)}
    >
      <.hex_player
        id={player_id(@scope, @attachment)}
        kind={:audio}
        src={preview_href(@attachment)}
        title={filename(@attachment)}
        testid="message-attachment-audio-preview"
      >
        <.player_foot attachment={@attachment} />
      </.hex_player>
    </div>
    """
  end

  attr :attachment, :map, required: true
  attr :scope, :string, required: true

  # Somebody speaking, and for how long. The filename is a timestamp the
  # recorder invented and the directory is a fact about storage, so neither is
  # on the tile — the length is the one measurement a listener decides with.
  defp voice_tile(assigns) do
    assigns = assign(assigns, :duration_ms, VoiceMessages.duration_ms(assigns.attachment))

    ~H"""
    <div data-testid="message-voice" data-preview-kind="voice">
      <.hex_player
        id={player_id(@scope, @attachment)}
        kind={:audio}
        src={preview_href(@attachment)}
        title={dgettext("chat", "Voice message")}
        length_ms={@duration_ms}
        length_testid="message-voice-duration"
        testid="message-attachment-audio-preview"
      >
        <span class="min-w-0 flex-1 truncate">
          {Format.bytes(attachment_byte_size(@attachment))}
        </span>
        <.open_link attachment={@attachment} />
      </.hex_player>
    </div>
    """
  end

  attr :attachment, :map, required: true

  # Under a file's player: its size, where it is kept, and the link that opens it.
  defp player_foot(assigns) do
    ~H"""
    <span class="shrink-0">{Format.bytes(attachment_byte_size(@attachment))}</span>
    <span class="min-w-0 flex-1 truncate font-mono" data-testid="message-attachment-path">
      {directory_path(@attachment)}
    </span>
    <.open_link attachment={@attachment} />
    """
  end

  attr :attachment, :map, required: true

  defp open_link(assigns) do
    ~H"""
    <a
      href={attachment_href(@attachment)}
      target="_blank"
      rel="noopener"
      data-confirm-tab="attachment"
      data-confirm-label={confirm_label(@attachment)}
      class="font-bold"
      data-testid="message-attachment-download"
    >
      {dgettext("chat", "Open")}
    </a>
    """
  end

  # A player's id: the same line can be drawn in the conversation and in its
  # thread at once, and each copy is a player of its own.
  defp player_id(scope, attachment), do: "hex-player-#{scope}-#{attachment_id(attachment)}"

  defp attachment_id(attachment), do: Map.get(attachment, :id) || Map.get(attachment, "id")

  attr :attachment, :map, required: true

  defp file_tile(assigns) do
    assigns = assign(assigns, :preview_kind, preview_kind(assigns.attachment))

    ~H"""
    <div
      class="flex max-w-full items-stretch border border-border bg-surface text-xs shadow-retro-field"
      data-testid="message-attachment"
      data-preview-kind={@preview_kind}
      title={logical_path(@attachment)}
    >
      <div class="flex w-10 shrink-0 items-center justify-center border-r border-border bg-muted">
        <.attachment_icon kind={@preview_kind} />
      </div>
      <div class="min-w-0 flex-1 px-1 py-0.5">
        <a
          href={attachment_href(@attachment)}
          target="_blank"
          rel="noopener"
          data-confirm-tab="attachment"
          data-confirm-label={confirm_label(@attachment)}
          class="block max-w-[28rem] truncate font-mono font-bold text-foreground hover:underline"
          data-testid="message-attachment-download"
        >
          {filename(@attachment)}
        </a>
        <div class="flex flex-wrap gap-x-1 text-muted-foreground">
          <span data-testid="message-attachment-type">{type_label(@preview_kind)}</span>
          <span>{Format.bytes(attachment_byte_size(@attachment))}</span>
        </div>
        <div
          class="max-w-[28rem] truncate font-mono text-[10px] text-muted-foreground"
          data-testid="message-attachment-path"
        >
          {directory_path(@attachment)}
        </div>
      </div>
      <a
        :if={preview_action?(@attachment)}
        href={preview_href(@attachment)}
        target="_blank"
        rel="noopener"
        data-confirm-tab="attachment"
        data-confirm-label={confirm_label(@attachment)}
        class="flex shrink-0 items-center border-l border-border bg-muted px-2 font-bold hover:bg-surface"
        data-testid="message-attachment-preview"
      >
        {dgettext("chat", "Preview")}
      </a>
    </div>
    """
  end

  attr :kind, :string, required: true

  defp attachment_icon(assigns) do
    ~H"""
    <%= case @kind do %>
      <% "code" -> %>
        <Icons.icon_code class="h-5 w-5" />
      <% "archive" -> %>
        <Icons.icon_folder class="h-5 w-5" />
      <% "office" -> %>
        <Icons.icon_file_send class="h-5 w-5" />
      <% "pdf" -> %>
        <Icons.icon_document_alert class="h-5 w-5" />
      <% _kind -> %>
        <Icons.icon_file_send class="h-5 w-5" />
    <% end %>
    """
  end

  defp preview_action?(attachment) do
    preview_kind(attachment) == "pdf" and preview_status(attachment) == "ready"
  end

  # A recording is an audio file with a fact attached, so it only takes its own
  # tile where an ordinary audio file would have played inline anyway.
  defp tile_kind(attachment) do
    case inline_kind(attachment) do
      "audio" -> if VoiceMessages.voice?(attachment), do: "voice", else: "audio"
      kind_or_nil -> kind_or_nil
    end
  end

  defp inline_kind(attachment) do
    kind = preview_kind(attachment)

    if kind in ~w(image video audio) and preview_status(attachment) == "ready" do
      kind
    end
  end

  defp preview_kind(attachment) do
    Map.get(attachment, :preview_kind) || Map.get(attachment, "preview_kind") || "download"
  end

  defp preview_status(attachment) do
    Map.get(attachment, :preview_status) || Map.get(attachment, "preview_status") || "none"
  end

  defp filename(attachment) do
    Map.get(attachment, :filename) || Map.get(attachment, "filename") || dgettext("chat", "file")
  end

  # What the confirmation may call this attachment, which is whatever the tile
  # itself calls it. A recording's filename is a timestamp the recorder made up
  # and the voice tile deliberately never shows it — so neither does the dialog,
  # or the name is back in the markup by a side door.
  defp confirm_label(attachment) do
    case tile_kind(attachment) do
      "voice" -> dgettext("chat", "Voice message")
      _named -> filename(attachment)
    end
  end

  defp attachment_byte_size(attachment) do
    Map.get(attachment, :byte_size) || Map.get(attachment, "byte_size") || 0
  end

  defp directory_path(attachment) do
    Map.get(attachment, :directory_path) || Map.get(attachment, "directory_path") || "/"
  end

  defp logical_path(attachment) do
    Map.get(attachment, :logical_path) || Map.get(attachment, "logical_path") ||
      filename(attachment)
  end

  defp attachment_href(%{id: id}), do: "/chat/attachments/#{id}"
  defp attachment_href(%{"id" => id}), do: "/chat/attachments/#{id}"
  defp attachment_href(_attachment), do: "#"

  defp preview_href(%{id: id}), do: "/chat/attachments/#{id}/preview"
  defp preview_href(%{"id" => id}), do: "/chat/attachments/#{id}/preview"
  defp preview_href(_attachment), do: "#"

  defp type_label("image"), do: dgettext("chat", "Image")
  defp type_label("video"), do: dgettext("chat", "Video")
  defp type_label("audio"), do: dgettext("chat", "Audio")
  defp type_label("pdf"), do: dgettext("chat", "PDF")
  defp type_label("text"), do: dgettext("chat", "Text")
  defp type_label("code"), do: dgettext("chat", "Code")
  defp type_label("archive"), do: dgettext("chat", "Archive")
  defp type_label("office"), do: dgettext("chat", "Office")
  defp type_label(_kind), do: dgettext("chat", "File")
end
