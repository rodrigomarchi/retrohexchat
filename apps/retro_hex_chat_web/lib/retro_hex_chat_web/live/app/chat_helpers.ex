defmodule RetroHexChatWeb.App.ChatHelpers do
  @moduledoc """
  Shared helper functions for app LiveViews.
  Extracted from ChatLive private functions to enable reuse across app modules.
  """

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Accounts.{NickColors, Session}
  alias RetroHexChat.Chat.{Content, URLDetector}
  alias RetroHexChat.Chat.Content.Html
  alias RetroHexChatWeb.Timezone

  @nick_color_count 12

  @spec build_nick_color_fn(Session.t()) :: (String.t() -> String.t())
  def build_nick_color_fn(session) do
    fn nickname ->
      case NickColors.color_index_for(session.nick_colors, nickname) do
        nil -> default_nick_color(nickname)
        irc_index -> "irc-fg-#{irc_index}"
      end
    end
  end

  @doc """
  Deterministic nick color class from the nickname hash, with no per-user
  overrides. Used by surfaces without a `%Session{}` (e.g. the P2P lobby).
  """
  @spec default_nick_color(String.t()) :: String.t()
  def default_nick_color(nickname),
    do: "nick-color-#{:erlang.phash2(nickname, @nick_color_count)}"

  @spec format_content(String.t(), boolean()) :: String.t()
  def format_content(content, strip_formatting) do
    format_content(content, "irc", strip_formatting)
  end

  @spec format_content(String.t(), Content.format_input(), boolean()) :: String.t()
  def format_content(content, content_format, strip_formatting) do
    normalized_format = normalize_content_format(content_format)

    html =
      if strip_formatting do
        content |> Content.strip_formatting(normalized_format) |> URLDetector.linkify()
      else
        {:safe, raw} = Content.render_html(content, normalized_format)
        maybe_linkify_rendered_html(raw, normalized_format)
      end

    linkify_channels(html)
  end

  defp normalize_content_format(content_format) do
    case Content.normalize_format(content_format) do
      {:ok, normalized_format} -> normalized_format
      :error -> :irc
    end
  end

  defp maybe_linkify_rendered_html(html, :markdown), do: html
  defp maybe_linkify_rendered_html(html, _content_format), do: URLDetector.linkify_html(html)

  @spec linkify_channels(String.t()) :: String.t()
  def linkify_channels(html) do
    Html.rewrite_text(html, &linkify_channel_part/1)
  end

  @channel_name_regex ~r/#[a-zA-Z][a-zA-Z0-9_-]{0,49}/

  defp linkify_channel_part(text) do
    Regex.replace(@channel_name_regex, text, fn match ->
      ~s(<span class="chat-channel-link" data-channel="#{match}">#{match}</span>)
    end)
  end

  @doc """
  Formats a message timestamp for the metadata column. Bare (no brackets): the
  two-line meta column carries its own visual framing, so `[ ]` would only add
  noise on small screens.
  """
  @spec format_time(DateTime.t() | any(), atom(), String.t()) :: String.t()
  def format_time(%DateTime{} = dt, :hh_mm, tz),
    do: dt |> Timezone.shift(tz) |> Calendar.strftime("%H:%M")

  def format_time(%DateTime{} = dt, :hh_mm_ss, tz),
    do: dt |> Timezone.shift(tz) |> Calendar.strftime("%H:%M:%S")

  def format_time(%DateTime{} = dt, :dd_mm_hh_mm, tz),
    do: dt |> Timezone.shift(tz) |> Calendar.strftime("%d/%m %H:%M")

  def format_time(_, :none, _tz), do: ""

  def format_time(%DateTime{} = dt, _, tz),
    do: dt |> Timezone.shift(tz) |> Calendar.strftime("%H:%M")

  def format_time(_, _, _tz), do: "--:--"

  @spec format_edit_timestamp(DateTime.t() | any(), String.t()) :: String.t()
  def format_edit_timestamp(%DateTime{} = dt, tz) do
    dt |> Timezone.shift(tz) |> Calendar.strftime("%H:%M %d/%m/%Y")
  end

  def format_edit_timestamp(_, _tz), do: "--:--"

  @spec format_datetime(DateTime.t() | any(), String.t()) :: String.t() | nil
  def format_datetime(%DateTime{} = dt, tz) do
    dt |> Timezone.shift(tz) |> Calendar.strftime("%d/%m/%Y %H:%M")
  end

  def format_datetime(_, _tz), do: nil

  @doc """
  Formats a session duration (in seconds) as a compact `MMm SSs` string, or
  `HHh MMm` once it passes an hour. Returns `nil` for a missing/invalid value so
  callers can omit the line entirely.
  """
  @spec format_duration(integer() | any()) :: String.t() | nil
  def format_duration(seconds) when is_integer(seconds) and seconds >= 0 do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    secs = rem(seconds, 60)

    if hours > 0 do
      "#{hours}h #{pad2(minutes)}m"
    else
      "#{pad2(minutes)}m #{pad2(secs)}s"
    end
  end

  def format_duration(_), do: nil

  defp pad2(n), do: String.pad_leading(Integer.to_string(n), 2, "0")

  @spec extract_p2p_label(String.t()) :: String.t()
  def extract_p2p_label(content) when is_binary(content) do
    case Regex.run(~r{^(.+?)[.!?]?\s*Join the lobby:}, content) do
      [_, label] -> label
      _ -> content
    end
  end

  @spec extract_p2p_link(String.t()) :: String.t()
  def extract_p2p_link(content) when is_binary(content) do
    case Regex.run(~r{(/(?:p2p|game|lobby)/[^\s]+)}, content) do
      [_, path] -> path
      _ -> "#"
    end
  end

  @spec highlight_bg_class(map()) :: String.t()
  def highlight_bg_class(%{highlighted: true, highlight_color: nil}), do: " highlight-bg-default"
  def highlight_bg_class(%{highlighted: true, highlight_color: idx}), do: " irc-bg-#{idx}"
  def highlight_bg_class(_), do: ""

  @spec input_placeholder(map()) :: String.t()
  def input_placeholder(assigns) do
    cond do
      assigns.show_status_tab ->
        dgettext("chat", "Type a command — / for list")

      assigns.session.active_pm != nil ->
        dgettext("chat", "Message to %{target} — / for commands",
          target: assigns.session.active_pm
        )

      assigns.session.active_channel != nil ->
        dgettext("chat", "Message to %{target} — / for commands",
          target: assigns.session.active_channel
        )

      true ->
        dgettext("chat", "Type a command — / for list")
    end
  end
end
