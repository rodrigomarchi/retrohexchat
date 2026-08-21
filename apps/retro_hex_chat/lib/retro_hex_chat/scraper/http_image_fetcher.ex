defmodule RetroHexChat.Scraper.HTTPImageFetcher do
  @moduledoc """
  Downloads publisher images for the scraper thumbnail cache.

  The fetch follows the same SSRF posture as page scraping: every redirect is
  re-checked through `RetroHexChat.Net.URLGuard`, bodies are capped, and only
  safe raster image formats are accepted.
  """

  @behaviour RetroHexChat.Scraper.ImageFetcher

  alias RetroHexChat.Net.URLGuard
  alias RetroHexChat.Scraper.ImageFetcher

  require Logger

  @accept "image/jpeg, image/png, image/webp;q=0.9, */*;q=0.1"
  @max_body_size 8_000_000
  @max_redirects 3
  @timeout_ms 6_000
  @user_agent "RetroHexChat-Scraper/1.0"
  @redirect_statuses [301, 302, 303, 307, 308]

  @impl true
  @spec fetch(String.t(), keyword()) :: {:ok, ImageFetcher.fetched_image()} | {:error, term()}
  def fetch(url, opts \\ []) do
    fetch_resource(url, opts, Keyword.get(opts, :max_redirects, @max_redirects))
  rescue
    exception ->
      Logger.warning("scrape_image_fetch_raise url=#{url} error=#{Exception.message(exception)}")
      {:error, :fetch_failed}
  end

  @spec fetch_resource(String.t(), keyword(), non_neg_integer()) ::
          {:ok, ImageFetcher.fetched_image()} | {:error, term()}
  defp fetch_resource(url, opts, redirects_left) do
    case URLGuard.fetch_target(url) do
      {:ok, target} -> fetch_resource_target(target, url, opts, redirects_left)
      {:error, _reason} -> {:error, :blocked}
    end
  end

  @spec fetch_resource_target(URLGuard.fetch_target(), String.t(), keyword(), non_neg_integer()) ::
          {:ok, ImageFetcher.fetched_image()} | {:error, term()}
  defp fetch_resource_target(target, url, opts, redirects_left) do
    case Req.get(request_options(target, opts)) do
      {:ok, response} -> handle_response(response, url, opts, redirects_left)
      {:error, reason} -> transport_error(url, reason)
    end
  end

  @spec handle_response(Req.Response.t(), String.t(), keyword(), non_neg_integer()) ::
          {:ok, ImageFetcher.fetched_image()} | {:error, term()}
  defp handle_response(
         %{status: status, body: body, headers: headers},
         url,
         opts,
         _redirects_left
       )
       when status in 200..299 and is_binary(body) do
    max_body_size = Keyword.get(opts, :max_body_size, @max_body_size)

    with :ok <- body_size_ok(body, max_body_size),
         {:ok, content_type} <- image_content_type(body, first_header(headers, "content-type")) do
      {:ok,
       %{
         body: body,
         content_type: content_type,
         final_url: url,
         byte_size: byte_size(body)
       }}
    end
  end

  defp handle_response(%{status: status, headers: headers}, url, opts, redirects_left)
       when status in @redirect_statuses do
    follow_redirect(url, headers, opts, redirects_left)
  end

  defp handle_response(%{status: status}, _url, _opts, _redirects_left)
       when is_integer(status),
       do: {:error, {:http_status, status}}

  @spec transport_error(String.t(), term()) :: {:error, :fetch_failed}
  defp transport_error(url, reason) do
    Logger.warning("scrape_image_transport_error url=#{url} reason=#{inspect(reason)}")
    {:error, :fetch_failed}
  end

  @spec request_options(URLGuard.fetch_target(), keyword()) :: keyword()
  defp request_options(target, opts) do
    timeout = Keyword.get(opts, :timeout, @timeout_ms)
    max_body_size = Keyword.get(opts, :max_body_size, @max_body_size)

    options = [
      url: target.url,
      headers: [{"user-agent", @user_agent}, {"accept", @accept}],
      redirect: false,
      compressed: false,
      decode_body: false,
      max_retries: 0,
      connect_options: Keyword.put(target.connect_options, :timeout, timeout),
      receive_timeout: timeout,
      into: &collect_limited_body(&1, &2, max_body_size + 1)
    ]

    options =
      if Map.get(target, :inet6?), do: Keyword.put(options, :inet6, true), else: options

    merge_request_overrides(options)
  end

  @spec merge_request_overrides(keyword()) :: keyword()
  defp merge_request_overrides(options) do
    Keyword.merge(options, request_overrides(), fn
      :connect_options, left, right -> Keyword.merge(left, right)
      _key, _left, right -> right
    end)
  end

  @spec request_overrides() :: keyword()
  defp request_overrides do
    Application.get_env(:retro_hex_chat, :scraper_image_req_options, [])
  end

  @spec collect_limited_body(
          {:data, binary()},
          {Req.Request.t(), Req.Response.t()},
          pos_integer()
        ) ::
          {:cont | :halt, {Req.Request.t(), Req.Response.t()}}
  defp collect_limited_body({:data, data}, {request, response}, max_size) do
    current = if is_binary(response.body), do: response.body, else: ""
    remaining = max(max_size - byte_size(current), 0)
    data = binary_part(data, 0, min(byte_size(data), remaining))
    body = current <> data
    response = %{response | body: body}

    if byte_size(body) >= max_size do
      {:halt, {request, response}}
    else
      {:cont, {request, response}}
    end
  end

  @spec follow_redirect(String.t(), map(), keyword(), non_neg_integer()) ::
          {:ok, ImageFetcher.fetched_image()} | {:error, term()}
  defp follow_redirect(_url, _headers, _opts, 0), do: {:error, :too_many_redirects}

  defp follow_redirect(url, headers, opts, redirects_left) do
    case redirect_url(url, first_header(headers, "location")) do
      nil -> {:error, :server_error}
      next_url -> fetch_resource(next_url, opts, redirects_left - 1)
    end
  end

  @spec redirect_url(String.t(), String.t() | nil) :: String.t() | nil
  defp redirect_url(_url, nil), do: nil

  defp redirect_url(url, location) do
    url
    |> URI.merge(String.trim(location))
    |> URI.to_string()
  rescue
    _error -> nil
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

  @spec first_header(map(), String.t()) :: String.t() | nil
  defp first_header(headers, name) do
    case Map.get(headers, String.downcase(name)) || Map.get(headers, name) do
      [value | _] -> value
      value when is_binary(value) -> value
      _other -> nil
    end
  end
end
