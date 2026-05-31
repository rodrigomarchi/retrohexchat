defmodule RetroHexChat.Chat.Policy do
  @moduledoc """
  Content validation and authorization for chat messages.
  """
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Chat.Formatter
  alias RetroHexChat.RateLimit.Limiter

  @max_content_length 1000
  @edit_window_seconds 300
  @edit_debounce_seconds 3

  @spec validate_content(String.t()) :: :ok | {:error, String.t()}
  def validate_content(content) when is_binary(content) do
    cond do
      byte_size(content) == 0 ->
        {:error, dgettext("chat", "Message cannot be empty")}

      String.length(content) > @max_content_length ->
        {:error, "Message exceeds maximum length of #{@max_content_length} characters"}

      not Formatter.has_visible_text?(content) ->
        {:error, dgettext("chat", "Message cannot be empty")}

      true ->
        :ok
    end
  end

  @spec can_edit?(map(), String.t()) :: :ok | {:error, String.t()}
  def can_edit?(message, nickname) do
    cond do
      message.author_nickname != nickname ->
        {:error, dgettext("chat", "You cannot edit other users' messages.")}

      message.deleted_at != nil ->
        {:error, dgettext("chat", "Message has already been deleted.")}

      not within_window?(message.inserted_at, @edit_window_seconds) ->
        {:error, dgettext("chat", "Edit window has expired.")}

      debounced?(message.edited_at, @edit_debounce_seconds) ->
        {:error, dgettext("chat", "Please wait a few seconds before editing again.")}

      true ->
        :ok
    end
  end

  @spec can_edit_with_grace?(map(), String.t(), DateTime.t()) :: :ok | {:error, String.t()}
  def can_edit_with_grace?(message, nickname, edit_started_at) do
    grace_window = @edit_window_seconds + 120

    cond do
      message.author_nickname != nickname ->
        {:error, dgettext("chat", "You cannot edit other users' messages.")}

      message.deleted_at != nil ->
        {:error, dgettext("chat", "Message has already been deleted.")}

      within_window?(message.inserted_at, @edit_window_seconds) ->
        check_debounce(message)

      within_window?(edit_started_at, grace_window) and
          within_window?(message.inserted_at, grace_window) ->
        check_debounce(message)

      true ->
        {:error, dgettext("chat", "Edit window has expired.")}
    end
  end

  @spec can_delete?(map(), String.t()) :: :ok | {:error, String.t()}
  def can_delete?(message, nickname) do
    cond do
      message.author_nickname != nickname ->
        {:error, dgettext("chat", "You cannot delete other users' messages.")}

      message.deleted_at != nil ->
        {:error, dgettext("chat", "Message has already been deleted.")}

      not within_window?(message.inserted_at, @edit_window_seconds) ->
        {:error, dgettext("chat", "Delete window has expired.")}

      true ->
        :ok
    end
  end

  @spec check_rate_limit(atom() | :ets.tid(), String.t()) :: :ok | {:error, :rate_limited}
  def check_rate_limit(table, nickname) do
    Limiter.check_rate(table, nickname, :message)
  end

  defp within_window?(timestamp, window_seconds) do
    diff = DateTime.diff(DateTime.utc_now(), timestamp, :second)
    diff <= window_seconds
  end

  defp debounced?(nil, _seconds), do: false

  defp debounced?(edited_at, seconds) do
    DateTime.diff(DateTime.utc_now(), edited_at, :second) < seconds
  end

  defp check_debounce(message) do
    if debounced?(message.edited_at, @edit_debounce_seconds) do
      {:error, dgettext("chat", "Please wait a few seconds before editing again.")}
    else
      :ok
    end
  end
end
