defmodule RetroHexChat.PromEx.Plugins.Oban do
  @moduledoc """
  PromEx metrics for Oban jobs and queue lengths.

  `PromEx.Plugins.Oban` is compiled conditionally by the dependency and can
  fall back to a no-op module in an umbrella build when Oban is not loaded at
  that exact compilation step. This local plugin keeps the important Oban
  metric contract explicit in this application instead of depending on that
  optional compilation order.
  """

  use PromEx.Plugin

  import Ecto.Query

  @job_stop [:oban, :job, :stop]
  @job_exception [:oban, :job, :exception]
  @queue_poll [:prom_ex, :plugin, :oban, :queue, :length, :count]

  @duration_buckets [10, 100, 500, 1_000, 5_000, 20_000]
  @attempt_buckets [1, 5, 10]

  @impl true
  def event_metrics(opts) do
    metric_prefix = Keyword.get(opts, :metric_prefix, PromEx.metric_prefix(opts[:otp_app], :oban))
    keep = keep_oban_instance_metrics(oban_supervisors(opts))

    Event.build(
      :retro_hex_chat_oban_event_metrics,
      [
        distribution(
          metric_prefix ++ [:job, :processing, :duration, :milliseconds],
          event_name: @job_stop,
          measurement: :duration,
          description: "The amount of time it takes to process an Oban job.",
          reporter_options: [buckets: @duration_buckets],
          tag_values: &job_tags/1,
          tags: [:name, :queue, :state, :worker],
          unit: {:native, :millisecond},
          keep: keep
        ),
        distribution(
          metric_prefix ++ [:job, :queue, :time, :milliseconds],
          event_name: @job_stop,
          measurement: :queue_time,
          description: "The amount of time an Oban job waited before processing.",
          reporter_options: [buckets: @duration_buckets],
          tag_values: &job_tags/1,
          tags: [:name, :queue, :state, :worker],
          unit: {:native, :millisecond},
          keep: keep
        ),
        distribution(
          metric_prefix ++ [:job, :complete, :attempts],
          event_name: @job_stop,
          measurement: &job_attempt/2,
          description: "The number of attempts before an Oban job completed.",
          reporter_options: [buckets: @attempt_buckets],
          tag_values: &job_tags/1,
          tags: [:name, :queue, :state, :worker],
          keep: keep
        ),
        distribution(
          metric_prefix ++ [:job, :exception, :duration, :milliseconds],
          event_name: @job_exception,
          measurement: :duration,
          description: "The amount of time it takes an Oban job to fail.",
          reporter_options: [buckets: @duration_buckets],
          tag_values: &exception_tags/1,
          tags: [:name, :queue, :state, :worker, :kind, :error],
          unit: {:native, :millisecond},
          keep: keep
        ),
        distribution(
          metric_prefix ++ [:job, :exception, :queue, :time, :milliseconds],
          event_name: @job_exception,
          measurement: :queue_time,
          description: "The amount of time a failed Oban job waited before processing.",
          reporter_options: [buckets: @duration_buckets],
          tag_values: &exception_tags/1,
          tags: [:name, :queue, :state, :worker, :kind, :error],
          unit: {:native, :millisecond},
          keep: keep
        ),
        distribution(
          metric_prefix ++ [:job, :exception, :attempts],
          event_name: @job_exception,
          measurement: &job_attempt/2,
          description: "The number of attempts before an Oban job failed.",
          reporter_options: [buckets: @attempt_buckets],
          tag_values: &exception_tags/1,
          tags: [:name, :queue, :state, :worker, :kind, :error],
          keep: keep
        )
      ]
    )
  end

  @impl true
  def polling_metrics(opts) do
    metric_prefix = Keyword.get(opts, :metric_prefix, PromEx.metric_prefix(opts[:otp_app], :oban))
    poll_rate = Keyword.get(opts, :poll_rate, 5_000)
    supervisors = oban_supervisors(opts)

    Polling.build(
      :retro_hex_chat_oban_queue_poll_metrics,
      poll_rate,
      {__MODULE__, :execute_queue_metrics, [supervisors]},
      [
        last_value(
          metric_prefix ++ [:queue, :length, :count],
          event_name: @queue_poll,
          description: "The total number of jobs in each Oban queue state.",
          measurement: :count,
          tags: [:name, :queue, :state]
        )
      ],
      Keyword.get(opts, :opts, [])
    )
  end

  @doc false
  @spec execute_queue_metrics([module()]) :: :ok
  def execute_queue_metrics(supervisors) when is_list(supervisors) do
    Enum.each(supervisors, &execute_queue_metrics_for/1)
  end

  defp execute_queue_metrics_for(supervisor) do
    if oban_running?(supervisor) do
      config = Oban.config(supervisor)

      config
      |> Oban.Repo.all(queue_query())
      |> include_zero_queue_states(config)
      |> Enum.each(fn {{queue, state}, count} ->
        :telemetry.execute(
          @queue_poll,
          %{count: count},
          %{name: normalize_name(supervisor), queue: queue, state: state}
        )
      end)
    end
  rescue
    _error -> :ok
  catch
    :exit, _reason -> :ok
  end

  defp queue_query do
    Oban.Job
    |> group_by([job], [job.queue, job.state])
    |> select([job], {job.queue, job.state, count(job.id)})
  end

  defp include_zero_queue_states(results, config) do
    zeros =
      for {queue, _opts} <- config.queues,
          state <- Oban.Job.states(),
          into: %{} do
        {{to_string(queue), to_string(state)}, 0}
      end

    counts = for {queue, state, count} <- results, into: %{}, do: {{queue, state}, count}

    Map.merge(zeros, counts)
  end

  defp oban_supervisors(opts) do
    opts
    |> Keyword.get(:oban_supervisors, [Oban])
    |> List.wrap()
  end

  defp keep_oban_instance_metrics(supervisors) do
    supervisors = MapSet.new(supervisors)

    fn
      %{conf: %{name: name}} -> MapSet.member?(supervisors, name)
      %{name: name} -> MapSet.member?(supervisors, name)
      _metadata -> false
    end
  end

  defp job_tags(%{conf: %{name: name}, job: %Oban.Job{} = job} = metadata) do
    %{
      name: normalize_name(name),
      queue: job.queue,
      state: metadata |> Map.get(:state, job.state) |> to_string(),
      worker: normalize_name(job.worker)
    }
  end

  defp exception_tags(metadata) do
    metadata
    |> job_tags()
    |> Map.put(:kind, metadata |> Map.get(:kind, :unknown) |> to_string())
    |> Map.put(:error, metadata |> Map.get(:reason, "unknown") |> error_name())
  end

  defp job_attempt(_measurements, %{job: %Oban.Job{attempt: attempt}}), do: attempt
  defp job_attempt(_measurements, _metadata), do: 0

  defp oban_running?(supervisor) do
    case Oban.whereis(supervisor) do
      pid when is_pid(pid) -> Process.alive?(pid)
      _other -> false
    end
  end

  defp normalize_name(name) when is_atom(name) do
    name
    |> Atom.to_string()
    |> String.trim_leading("Elixir.")
  end

  defp normalize_name(name) when is_binary(name), do: name
  defp normalize_name({name, _opts}), do: normalize_name(name)
  defp normalize_name(name), do: inspect(name)

  defp error_name(%module{}), do: normalize_name(module)
  defp error_name(error) when is_atom(error), do: Atom.to_string(error)
  defp error_name(error) when is_binary(error), do: error
  defp error_name(_error), do: "unknown"
end
