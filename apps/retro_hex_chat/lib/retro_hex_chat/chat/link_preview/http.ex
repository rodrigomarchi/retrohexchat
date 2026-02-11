defmodule RetroHexChat.Chat.LinkPreview.HTTP do
  @moduledoc """
  HTTP implementation of the LinkPreview behaviour.
  Fetches page titles using Req.
  """

  @behaviour RetroHexChat.Chat.LinkPreview

  @max_body_size 50_000
  @max_title_length 200
  @title_regex ~r/<title[^>]*>(.*?)<\/title>/is

  @impl true
  @spec fetch_title(String.t()) :: {:ok, String.t()} | {:error, atom()}
  def fetch_title(url) do
    case Req.get(url,
           connect_options: [timeout: 5_000],
           receive_timeout: 5_000,
           max_redirects: 3,
           decode_body: false,
           max_retries: 0
         ) do
      {:ok, %{status: status, headers: headers, body: body}} when status in 200..299 ->
        if html_content?(get_content_type(headers)) do
          body |> String.slice(0, @max_body_size) |> parse_title()
        else
          {:error, :not_html}
        end

      {:ok, %{status: status}} when status in 400..499 ->
        {:error, :not_found}

      {:ok, %{status: _}} ->
        {:error, :server_error}

      {:error, _} ->
        {:error, :fetch_failed}
    end
  rescue
    _ -> {:error, :fetch_failed}
  end

  @spec parse_title(String.t()) :: {:ok, String.t()} | {:error, :no_title}
  def parse_title(html) do
    case Regex.run(@title_regex, html) do
      [_, raw_title] ->
        title = raw_title |> String.replace(~r/\s+/, " ") |> String.trim()

        if title == "" do
          {:error, :no_title}
        else
          {:ok, title |> html_escape() |> truncate()}
        end

      _ ->
        {:error, :no_title}
    end
  end

  defp get_content_type(headers) do
    case Map.get(headers, "content-type", [""]) do
      [value | _] -> value
      _ -> ""
    end
  end

  defp html_content?(ct) do
    String.contains?(ct, "text/html") or String.contains?(ct, "application/xhtml")
  end

  defp html_escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end

  defp truncate(text) do
    if String.length(text) > @max_title_length do
      String.slice(text, 0, @max_title_length) <> "..."
    else
      text
    end
  end
end
