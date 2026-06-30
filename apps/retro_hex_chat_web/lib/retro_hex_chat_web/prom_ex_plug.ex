defmodule RetroHexChatWeb.PromExPlug do
  @moduledoc """
  Exposes all RetroHexChat PromEx collectors through one `/metrics` endpoint.
  """

  @behaviour Plug

  import Plug.Conn

  require Logger

  alias Plug.Conn

  @prom_ex_modules [RetroHexChat.PromEx, RetroHexChatWeb.PromEx]

  @impl true
  def init(opts) do
    %{
      metrics_path: Keyword.get(opts, :path, "/metrics"),
      prom_ex_modules: Keyword.get(opts, :prom_ex_modules, @prom_ex_modules)
    }
  end

  @impl true
  def call(%Conn{request_path: metrics_path} = conn, %{
        metrics_path: metrics_path,
        prom_ex_modules: prom_ex_modules
      }) do
    case collect_metrics(prom_ex_modules) do
      {:ok, metrics} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(200, Enum.intersperse(metrics, "\n"))
        |> halt()

      {:error, prom_ex_module} ->
        Logger.warning(
          "Attempted to fetch metrics from #{inspect(prom_ex_module)}, but it is not initialized"
        )

        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(503, "Service Unavailable")
        |> halt()
    end
  end

  def call(conn, _opts), do: conn

  defp collect_metrics(prom_ex_modules) do
    Enum.reduce_while(prom_ex_modules, {:ok, []}, fn prom_ex_module, {:ok, metrics} ->
      case PromEx.get_metrics(prom_ex_module) do
        :prom_ex_down ->
          {:halt, {:error, prom_ex_module}}

        module_metrics ->
          PromEx.ETSCronFlusher.defer_ets_flush(prom_ex_module.__ets_cron_flusher_name__())
          {:cont, {:ok, [module_metrics | metrics]}}
      end
    end)
    |> case do
      {:ok, metrics} -> {:ok, Enum.reverse(metrics)}
      error -> error
    end
  end
end
