defmodule RetroHexChat.Scraper.HTTPImageFetcher do
  @moduledoc """
  Downloads publisher images for the scraper thumbnail cache.

  The fetch follows the same SSRF posture as page scraping: every redirect is
  re-checked through `RetroHexChat.Net.URLGuard`, bodies are capped, and only
  safe raster image formats are accepted.
  """

  @behaviour RetroHexChat.Scraper.ImageFetcher

  alias RetroHexChat.Net.GuardedRequest
  alias RetroHexChat.Scraper.ImageFetcher

  require Logger

  @accept "image/jpeg, image/png, image/webp;q=0.9, */*;q=0.1"
  @max_body_size 8_000_000
  @max_redirects 3
  @timeout_ms 6_000
  @user_agent "RetroHexChat-Scraper/1.0"

  @impl true
  @spec fetch(String.t(), keyword()) :: {:ok, ImageFetcher.fetched_image()} | {:error, term()}
  def fetch(url, opts \\ []) do
    max_body_size = Keyword.get(opts, :max_body_size, @max_body_size)

    url
    |> GuardedRequest.get(
      headers: [{"user-agent", @user_agent}, {"accept", @accept}],
      # One byte past the cap, so a body that is exactly too large is seen.
      max_body_size: max_body_size + 1,
      timeout_ms: Keyword.get(opts, :timeout, @timeout_ms),
      max_redirects: Keyword.get(opts, :max_redirects, @max_redirects),
      overrides: :scraper_image_req_options
    )
    |> case do
      {:ok, response, final_url} -> handle_response(response, final_url, max_body_size)
      {:error, {:blocked, _reason}} -> {:error, :blocked}
      {:error, :too_many_redirects} -> {:error, :too_many_redirects}
      {:error, :redirect_without_location} -> {:error, :server_error}
      {:error, {:transport, reason}} -> transport_error(url, reason)
    end
  rescue
    exception ->
      Logger.warning("scrape_image_fetch_raise url=#{url} error=#{Exception.message(exception)}")
      {:error, :fetch_failed}
  end

  @spec handle_response(Req.Response.t(), String.t(), pos_integer()) ::
          {:ok, ImageFetcher.fetched_image()} | {:error, term()}
  defp handle_response(%{status: status, body: body, headers: headers}, url, max_body_size)
       when status in 200..299 and is_binary(body) do
    with :ok <- body_size_ok(body, max_body_size),
         {:ok, content_type} <-
           image_content_type(body, GuardedRequest.first_header(headers, "content-type")) do
      {:ok,
       %{
         body: body,
         content_type: content_type,
         final_url: url,
         byte_size: byte_size(body)
       }}
    end
  end

  defp handle_response(%{status: status}, _url, _max_body_size) when is_integer(status),
    do: {:error, {:http_status, status}}

  @spec transport_error(String.t(), term()) :: {:error, :fetch_failed}
  defp transport_error(url, reason) do
    Logger.warning("scrape_image_transport_error url=#{url} reason=#{inspect(reason)}")
    {:error, :fetch_failed}
  end

  @spec body_size_ok(binary(), pos_integer()) :: :ok | {:error, :too_large}
  defp body_size_ok(body, max_body_size) do
    if byte_size(body) <= max_body_size, do: :ok, else: {:error, :too_large}
  end

  @spec image_content_type(binary(), String.t() | nil) ::
          {:ok, String.t()} | {:error, :unsupported_image_type}
  defp image_content_type(body, header) do
    detected = detected_content_type(body)
    header = header |> base_content_type() |> allowed_header_content_type()

    case detected || header do
      content_type when content_type in ["image/jpeg", "image/png", "image/webp"] ->
        {:ok, content_type}

      _other ->
        {:error, :unsupported_image_type}
    end
  end

  @spec detected_content_type(binary()) :: String.t() | nil
  defp detected_content_type(<<0xFF, 0xD8, 0xFF, _rest::binary>>), do: "image/jpeg"

  defp detected_content_type(<<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, _rest::binary>>),
    do: "image/png"

  defp detected_content_type(<<"RIFF", _size::binary-size(4), "WEBP", _rest::binary>>),
    do: "image/webp"

  defp detected_content_type(_body), do: nil

  @spec base_content_type(String.t() | nil) :: String.t() | nil
  defp base_content_type(nil), do: nil

  defp base_content_type(content_type) do
    content_type
    |> String.split(";", parts: 2)
    |> hd()
    |> String.trim()
    |> String.downcase()
  end

  @spec allowed_header_content_type(String.t() | nil) :: String.t() | nil
  defp allowed_header_content_type(content_type)
       when content_type in ["image/jpeg", "image/png", "image/webp"],
       do: content_type

  defp allowed_header_content_type(_content_type), do: nil
end
