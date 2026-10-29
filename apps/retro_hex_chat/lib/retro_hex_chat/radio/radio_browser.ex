defmodule RetroHexChat.Radio.RadioBrowser do
  @moduledoc """
  Hex Radio's catalog in production: Radio Browser
  (https://www.radio-browser.info), the open, community-kept directory of
  internet radio stations.

  The server asks, never the reader's browser, so the directory sees one
  client with a name (`user-agent`) and `RetroHexChat.Radio.Cache` can answer
  the same genre for everyone. Only HTTPS stations that passed their last check
  are asked for; `Radio.Station` drops the rest of what the page cannot play.

  `:radio_req_options` in the application env is merged over the Req options,
  so a test can install `plug: {Req.Test, ...}`.
  """

  @behaviour RetroHexChat.Radio.Catalog

  require Logger

  @base_url "https://all.api.radio-browser.info"
  @user_agent "RetroHexChat/1.0 (+https://retrohexchat.app)"
  @timeout_ms 8_000

  @impl true
  def records(query, limit) do
    {path, params} = request(query, limit)

    case Req.get(options(path, params)) do
      {:ok, %Req.Response{status: 200, body: body}} when is_list(body) ->
        {:ok, body}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:status, status}}

      {:error, reason} ->
        {:error, {:transport, reason}}
    end
  end

  @impl true
  def played(id) do
    {:ok, _pid} =
      Task.start(fn ->
        case Req.get(options("/json/url/" <> URI.encode(id), [])) do
          {:ok, %Req.Response{status: 200}} ->
            :ok

          other ->
            Logger.debug("radio: the play of #{id} was not counted: #{inspect(other)}")
        end
      end)

    :ok
  end

  defp request({:ids, ids}, _limit),
    do: {"/json/stations/byuuid", [uuids: Enum.join(ids, ",")]}

  defp request(query, limit) do
    {"/json/stations/search",
     filter(query) ++
       [
         hidebroken: true,
         is_https: true,
         order: "clickcount",
         reverse: true,
         limit: limit
       ]}
  end

  defp filter(:top), do: []
  defp filter({:tag, tag}), do: [tag: tag, tagExact: true]
  defp filter({:name, name}), do: [name: name]

  defp options(path, params) do
    Keyword.merge(
      [
        url: @base_url <> path,
        params: params,
        headers: [{"user-agent", @user_agent}],
        connect_options: [timeout: @timeout_ms],
        receive_timeout: @timeout_ms,
        retry: false
      ],
      Application.get_env(:retro_hex_chat, :radio_req_options, [])
    )
  end
end
