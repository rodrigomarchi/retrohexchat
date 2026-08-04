defmodule RetroHexChat.Chat.Content do
  @moduledoc """
  Format-aware message content facade.

  This module is the domain boundary for rendering, visible text, previews,
  validation and URL extraction. Callers should pass the persisted
  `content_format` instead of deciding how IRC, Markdown or plain text works.
  """

  alias RetroHexChat.Chat.Content.{Irc, Markdown, Plain}

  @type format :: :irc | :markdown | :plain
  @type format_input :: format() | String.t()
  @type safe_html :: {:safe, String.t()}

  @default_max_length 1000
  @default_preview_length 160

  @doc """
  Renders content to Phoenix safe HTML according to its format.
  """
  @spec render_html(String.t(), format_input(), keyword()) :: safe_html()
  def render_html(content, format, opts \\ []) when is_binary(content) do
    format
    |> normalize_format!()
    |> renderer()
    |> apply(:render_html, [content, opts])
  end

  @doc """
  Returns the visible text represented by the formatted content.
  """
  @spec plain_text(String.t(), format_input()) :: String.t()
  def plain_text(content, format) when is_binary(content) do
    format
    |> normalize_format!()
    |> renderer()
    |> apply(:plain_text, [content])
  end

  @doc """
  Builds a single-line preview from visible text.
  """
  @spec preview(String.t(), format_input(), keyword()) :: String.t()
  def preview(content, format, opts \\ []) when is_binary(content) do
    max_length = Keyword.get(opts, :max_length, @default_preview_length)

    content
    |> plain_text(format)
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> truncate(max_length)
  end

  @doc """
  Validates content against the shared format contract.
  """
  @spec validate(String.t(), format_input(), keyword()) ::
          :ok | {:error, :unsupported_format | :blank | :too_long}
  def validate(content, format, opts \\ [])

  def validate(content, format, opts) when is_binary(content) do
    max_length = Keyword.get(opts, :max_length, @default_max_length)

    case normalize_format(format) do
      {:ok, normalized_format} ->
        cond do
          String.length(content) > max_length ->
            {:error, :too_long}

          content |> plain_text(normalized_format) |> String.trim() == "" ->
            {:error, :blank}

          true ->
            :ok
        end

      :error ->
        {:error, :unsupported_format}
    end
  end

  def validate(_content, format, _opts) do
    case normalize_format(format) do
      {:ok, _format} -> {:error, :blank}
      :error -> {:error, :unsupported_format}
    end
  end

  @doc """
  Removes presentation formatting and returns visible text.
  """
  @spec strip_formatting(String.t(), format_input()) :: String.t()
  def strip_formatting(content, format) when is_binary(content), do: plain_text(content, format)

  @doc """
  Extracts URLs from content according to its format.
  """
  @spec extract_urls(String.t(), format_input()) :: [String.t()]
  def extract_urls(content, format) when is_binary(content) do
    format
    |> normalize_format!()
    |> renderer()
    |> apply(:extract_urls, [content])
  end

  @doc """
  Normalizes persisted or UI format values.
  """
  @spec normalize_format(format_input()) :: {:ok, format()} | :error
  def normalize_format(:irc), do: {:ok, :irc}
  def normalize_format(:markdown), do: {:ok, :markdown}
  def normalize_format(:plain), do: {:ok, :plain}
  def normalize_format("irc"), do: {:ok, :irc}
  def normalize_format("markdown"), do: {:ok, :markdown}
  def normalize_format("plain"), do: {:ok, :plain}
  def normalize_format(_), do: :error

  @spec normalize_format!(format_input()) :: format()
  defp normalize_format!(format) do
    case normalize_format(format) do
      {:ok, normalized_format} ->
        normalized_format

      :error ->
        raise ArgumentError, "unsupported content format: #{inspect(format)}"
    end
  end

  @spec renderer(format()) :: module()
  defp renderer(:irc), do: Irc
  defp renderer(:markdown), do: Markdown
  defp renderer(:plain), do: Plain

  @spec truncate(String.t(), non_neg_integer()) :: String.t()
  defp truncate(_text, max_length) when max_length <= 0, do: ""

  defp truncate(text, max_length) do
    if String.length(text) > max_length do
      text
      |> String.graphemes()
      |> Enum.take(max_length)
      |> Enum.join()
      |> Kernel.<>("...")
    else
      text
    end
  end
end
