defmodule RetroHexChatWeb.Components.UI.ChatAttachment do
  @moduledoc """
  Rich attachment tiles for chat messages.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Components.UI.Format
  alias RetroHexChatWeb.Icons

  attr :attachments, :list, default: []

  @spec attachment_gallery(map()) :: Phoenix.LiveView.Rendered.t()
  def attachment_gallery(assigns) do
    ~H"""
    <div
      :if={@attachments != []}
      class="mt-1 flex max-w-full flex-wrap gap-1"
      data-testid="message-attachments"
    >
      <.attachment_tile :for={attachment <- @attachments} attachment={attachment} />
    </div>
    """
  end

  attr :attachment, :map, required: true

  @spec attachment_tile(map()) :: Phoenix.LiveView.Rendered.t()
  def attachment_tile(assigns) do
    assigns = assign(assigns, :preview_kind, preview_kind(assigns.attachment))

    ~H"""
    <%= case inline_kind(@attachment) do %>
      <% "image" -> %>
        <.image_tile attachment={@attachment} />
      <% "video" -> %>
        <.video_tile attachment={@attachment} />
      <% "audio" -> %>
        <.audio_tile attachment={@attachment} />
      <% _kind_or_nil -> %>
        <.file_tile attachment={@attachment} />
    <% end %>
    """
  end

  attr :attachment, :map, required: true

  defp image_tile(assigns) do
    ~H"""
    <a
      href={attachment_href(@attachment)}
      target="_blank"
      rel="noopener"
      class="block w-60 max-w-full border border-border bg-surface text-xs shadow-retro-field hover:bg-muted"
      data-testid="message-attachment"
      data-preview-kind={preview_kind(@attachment)}
      title={logical_path(@attachment)}
    >
      <div class="flex h-6 items-center gap-1 border-b border-border bg-muted px-1">
        <Icons.icon_file_send class="h-4 w-4 shrink-0" />
        <span class="min-w-0 flex-1 truncate font-mono">{filename(@attachment)}</span>
        <span class="shrink-0 text-muted-foreground">
          {Format.bytes(attachment_byte_size(@attachment))}
        </span>
      </div>
      <div class="flex h-36 w-full items-center justify-center bg-white p-1">
        <img
          src={preview_href(@attachment)}
          alt={filename(@attachment)}
          loading="lazy"
          class="max-h-full max-w-full object-contain"
          data-testid="message-attachment-image-preview"
        />
      </div>
    </a>
    """
  end

  attr :attachment, :map, required: true

  defp video_tile(assigns) do
    ~H"""
    <div
      class="w-72 max-w-full border border-border bg-surface text-xs shadow-retro-field"
      data-testid="message-attachment"
      data-preview-kind={preview_kind(@attachment)}
      title={logical_path(@attachment)}
    >
      <.tile_header attachment={@attachment} />
      <video
        src={preview_href(@attachment)}
        controls
        preload="metadata"
        class="block h-40 w-full bg-black"
        data-testid="message-attachment-video-preview"
      >
      </video>
      <.tile_footer attachment={@attachment} />
    </div>
    """
  end

  attr :attachment, :map, required: true

  defp audio_tile(assigns) do
    ~H"""
    <div
      class="w-72 max-w-full border border-border bg-surface text-xs shadow-retro-field"
      data-testid="message-attachment"
      data-preview-kind={preview_kind(@attachment)}
      title={logical_path(@attachment)}
    >
      <.tile_header attachment={@attachment} />
      <div class="bg-white p-1">
        <audio
          src={preview_href(@attachment)}
          controls
          preload="metadata"
          class="h-8 w-full"
          data-testid="message-attachment-audio-preview"
        >
        </audio>
      </div>
      <.tile_footer attachment={@attachment} />
    </div>
    """
  end

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
        class="flex shrink-0 items-center border-l border-border bg-muted px-2 font-bold hover:bg-surface"
        data-testid="message-attachment-preview"
      >
        {dgettext("chat", "Preview")}
      </a>
    </div>
    """
  end

  attr :attachment, :map, required: true

  defp tile_header(assigns) do
    ~H"""
    <div class="flex h-6 items-center gap-1 border-b border-border bg-muted px-1">
      <Icons.icon_file_send class="h-4 w-4 shrink-0" />
      <span class="min-w-0 flex-1 truncate font-mono">{filename(@attachment)}</span>
      <span class="shrink-0 text-muted-foreground">
        {Format.bytes(attachment_byte_size(@attachment))}
      </span>
    </div>
    """
  end

  attr :attachment, :map, required: true

  defp tile_footer(assigns) do
    ~H"""
    <div class="flex items-center gap-1 border-t border-border px-1 py-0.5 text-muted-foreground">
      <span class="min-w-0 flex-1 truncate font-mono" data-testid="message-attachment-path">
        {directory_path(@attachment)}
      </span>
      <a
        href={attachment_href(@attachment)}
        target="_blank"
        rel="noopener"
        class="shrink-0 font-bold text-foreground hover:underline"
        data-testid="message-attachment-download"
      >
        {dgettext("chat", "Open")}
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
