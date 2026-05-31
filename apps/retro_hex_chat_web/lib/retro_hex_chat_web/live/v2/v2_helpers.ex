defmodule RetroHexChatWeb.V2.V2Helpers do
  @moduledoc """
  Shared helper functions for v2 LiveViews.
  Extracted from ChatLive private functions to enable reuse across v2 modules.
  """

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Accounts.{NickColors, Session}
  alias RetroHexChat.Chat.{Formatter, URLDetector}
  alias RetroHexChatWeb.Timezone

  @nick_color_count 12

  @spec build_nick_color_fn(Session.t()) :: (String.t() -> String.t())
  def build_nick_color_fn(session) do
    fn nickname ->
      case NickColors.color_index_for(session.nick_colors, nickname) do
        nil -> "nick-color-#{:erlang.phash2(nickname, @nick_color_count)}"
        irc_index -> "irc-fg-#{irc_index}"
      end
    end
  end

  @spec format_content(String.t(), boolean()) :: String.t()
  def format_content(content, strip_formatting) do
    html =
      if strip_formatting do
        content |> Formatter.strip() |> URLDetector.linkify()
      else
        {:safe, raw} = Formatter.to_safe_html(content)
        URLDetector.linkify_html(raw)
      end

    linkify_channels(html)
  end

  @spec linkify_channels(String.t()) :: String.t()
  def linkify_channels(html) do
    ~r/(<[^>]+>)/
    |> Regex.split(html, include_captures: true)
    |> Enum.map_join(&linkify_channel_part/1)
  end

  @channel_name_regex ~r/#[a-zA-Z][a-zA-Z0-9_-]{0,49}/
  defp linkify_channel_part("<" <> _ = tag), do: tag

  defp linkify_channel_part(text) do
    Regex.replace(@channel_name_regex, text, fn match ->
      ~s(<span class="chat-channel-link" data-channel="#{match}">#{match}</span>)
    end)
  end

  @spec format_time(DateTime.t() | any(), atom(), String.t()) :: String.t()
  def format_time(%DateTime{} = dt, :hh_mm, tz),
    do: "[#{dt |> Timezone.shift(tz) |> Calendar.strftime("%H:%M")}]"

  def format_time(%DateTime{} = dt, :hh_mm_ss, tz),
    do: "[#{dt |> Timezone.shift(tz) |> Calendar.strftime("%H:%M:%S")}]"

  def format_time(%DateTime{} = dt, :dd_mm_hh_mm, tz),
    do: "[#{dt |> Timezone.shift(tz) |> Calendar.strftime("%d/%m %H:%M")}]"

  def format_time(_, :none, _tz), do: ""

  def format_time(%DateTime{} = dt, _, tz),
    do: "[#{dt |> Timezone.shift(tz) |> Calendar.strftime("%H:%M")}]"

  def format_time(_, _, _tz), do: "[--:--]"

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

  @spec extract_p2p_label(String.t()) :: String.t()
  def extract_p2p_label(content) when is_binary(content) do
    case Regex.run(~r{^(.+?)[.!?]?\s*Join the lobby:}, content) do
      [_, label] -> label
      _ -> content
    end
  end

  @spec extract_p2p_link(String.t()) :: String.t()
  def extract_p2p_link(content) when is_binary(content) do
    case Regex.run(~r{(/(?:p2p|game)/[^\s]+)}, content) do
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
