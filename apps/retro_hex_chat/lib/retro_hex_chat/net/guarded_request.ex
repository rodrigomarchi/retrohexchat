defmodule RetroHexChat.Net.GuardedRequest do
  @moduledoc """
  A GET of an address the server did not choose: a pasted link, a feed, a
  publisher's image.

  Every hop is checked by `RetroHexChat.Net.URLGuard` and pinned to the address
  it resolved to, redirects are followed by hand so each new location is checked
  again, and the body is read only up to a cap. What the response means (a page,
  a feed, an image) is the caller's business: any status that is not a redirect
  comes back as it arrived.

  Options:

    * `:headers` — request headers (`user-agent`, `accept`, conditional ones)
    * `:max_body_size` — bytes read before the body stops (required)
    * `:timeout_ms` — connect and receive timeout (default 15 000)
    * `:max_redirects` — redirects followed (default 3)
    * `:overrides` — an application env key whose keyword list is merged over
      the Req options, so a test can install `plug: {Req.Test, ...}`
  """

  alias RetroHexChat.Net.URLGuard

  @default_timeout_ms 15_000
  @default_max_redirects 3
  @redirect_statuses [301, 302, 303, 307, 308]

  @type error ::
          {:blocked, String.t()}
          | :too_many_redirects
          | :redirect_without_location
          | {:transport, term()}

  @doc """
  Fetches `url`, following up to `:max_redirects` redirects. Returns the final
  response with the address it came from.
  """
  @spec get(String.t(), keyword()) :: {:ok, Req.Response.t(), String.t()} | {:error, error()}
  def get(url, opts) do
    get(url, opts, Keyword.get(opts, :max_redirects, @default_max_redirects))
  end

  defp get(url, opts, redirects_left) do
    with {:ok, target} <- guard(url),
         {:ok, response} <- request(target, opts) do
      if response.status in @redirect_statuses do
        follow(url, response, opts, redirects_left)
      else
        {:ok, response, url}
      end
    end
  end

  defp guard(url) do
    case URLGuard.fetch_target(url) do
      {:ok, target} -> {:ok, target}
      {:error, reason} -> {:error, {:blocked, reason}}
    end
  end

  defp request(target, opts) do
    case Req.get(request_options(target, opts)) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, {:transport, reason}}
    end
  end

  defp follow(_url, _response, _opts, 0), do: {:error, :too_many_redirects}

  defp follow(url, response, opts, redirects_left) do
    case redirect_url(url, first_header(response.headers, "location")) do
      nil -> {:error, :redirect_without_location}
      next_url -> get(next_url, opts, redirects_left - 1)
    end
  end

  @spec request_options(URLGuard.fetch_target(), keyword()) :: keyword()
  defp request_options(target, opts) do
    timeout = Keyword.get(opts, :timeout_ms, @default_timeout_ms)
    max_body_size = Keyword.fetch!(opts, :max_body_size)

    options = [
      url: target.url,
      headers: Keyword.get(opts, :headers, []),
      redirect: false,
      compressed: false,
      decode_body: false,
      max_retries: 0,
      connect_options: Keyword.put(target.connect_options, :timeout, timeout),
      receive_timeout: timeout,
      into: &collect_limited_body(&1, &2, max_body_size)
    ]

    options = if Map.get(target, :inet6?), do: Keyword.put(options, :inet6, true), else: options

    case Keyword.get(opts, :overrides) do
      nil -> options
      key -> merge_overrides(options, Application.get_env(:retro_hex_chat, key, []))
    end
  end

  defp merge_overrides(options, overrides) do
    Keyword.merge(options, overrides, fn
      :connect_options, left, right -> Keyword.merge(left, right)
      _key, _left, right -> right
    end)
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
    body = current <> binary_part(data, 0, min(byte_size(data), remaining))
    response = %{response | body: body}

    if byte_size(body) >= max_size do
      {:halt, {request, response}}
    else
      {:cont, {request, response}}
    end
  end

  @doc "The absolute address a `Location` header points to, relative to `url`."
  @spec redirect_url(String.t(), String.t() | nil) :: String.t() | nil
  def redirect_url(_url, nil), do: nil

  def redirect_url(url, location) do
    url
    |> URI.merge(String.trim(location))
    |> URI.to_string()
  rescue
    _ -> nil
  end

  @doc """
  The first value of a response header. Req keys headers in lower case; a map
  built by hand may not, so the name is also tried as given.
  """
  @spec first_header(map(), String.t()) :: String.t() | nil
  def first_header(headers, name) do
    case Map.get(headers, String.downcase(name)) || Map.get(headers, name) do
      [value | _] -> value
      value when is_binary(value) -> value
      _ -> nil
    end
  end
end
