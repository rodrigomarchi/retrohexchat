defmodule RetroHexChat.Jobs.IndexNowWorkerTest do
  @moduledoc """
  Which URLs each scope announces, and how each answer becomes a job result.
  """
  use ExUnit.Case, async: false

  @moduletag :unit

  alias RetroHexChat.Jobs.IndexNowWorker

  defmodule Source do
    @moduledoc false
    @behaviour RetroHexChat.SEO.IndexNow.UrlSource

    @impl true
    def pages_changed_since(since) do
      send(self(), {:pages_changed_since, since})
      ["https://example.app/pt-BR/faq"]
    end

    @impl true
    def archive_day(day) do
      send(self(), {:archive_day, day})
      ["https://example.app/archive/lobby", "https://example.app/archive/lobby/#{day}"]
    end
  end

  setup do
    previous = Application.get_env(:retro_hex_chat, :index_now)

    Application.put_env(:retro_hex_chat, :index_now,
      enabled: true,
      key: "0123456789abcdef0123456789abcdef",
      url_source: Source
    )

    Application.put_env(:retro_hex_chat, :index_now_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.put_env(:retro_hex_chat, :index_now, previous)
      Application.delete_env(:retro_hex_chat, :index_now_req_options)
    end)
  end

  defp perform(args, attempt \\ 1) do
    IndexNowWorker.perform(%Oban.Job{args: args, attempt: attempt, max_attempts: 3})
  end

  defp accept_and_capture do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      send(test_pid, {:sent, Jason.decode!(body)["urlList"]})
      Plug.Conn.send_resp(conn, 200, "")
    end)
  end

  describe "the deploy scope" do
    test "announces the pages changed in the last two days" do
      accept_and_capture()

      assert {:ok, %{submitted: 1, batches: 1}} = perform(%{"scope" => "deploy"})
      assert_received {:pages_changed_since, since}
      assert since == Date.add(Date.utc_today(), -2)
      assert_received {:sent, ["https://example.app/pt-BR/faq"]}
    end

    test "takes another window by hand" do
      accept_and_capture()

      assert {:ok, _} = perform(%{"scope" => "deploy", "since" => "2026-01-01"})
      assert_received {:pages_changed_since, ~D[2026-01-01]}
    end
  end

  describe "the archive scope" do
    test "announces yesterday's pages" do
      accept_and_capture()
      yesterday = Date.add(Date.utc_today(), -1)

      assert {:ok, %{submitted: 2}} = perform(%{"scope" => "archive"})
      assert_received {:archive_day, ^yesterday}
    end

    test "takes another day by hand" do
      accept_and_capture()

      assert {:ok, _} = perform(%{"scope" => "archive", "date" => "2026-10-05"})

      assert_received {:sent,
                       [
                         "https://example.app/archive/lobby",
                         "https://example.app/archive/lobby/2026-10-05"
                       ]}
    end

    test "an unreadable date is cancelled, not retried" do
      assert {:cancel, "invalid_date"} = perform(%{"scope" => "archive", "date" => "yesterday"})
    end
  end

  describe "the answer" do
    test "a refusal is cancelled: the same list gets the same answer" do
      Req.Test.stub(__MODULE__, &Plug.Conn.send_resp(&1, 422, ""))

      assert {:cancel, "http_422"} = perform(%{"scope" => "deploy"})
    end

    test "throttling and server errors retry" do
      for status <- [429, 503] do
        Req.Test.stub(__MODULE__, &Plug.Conn.send_resp(&1, status, ""))

        assert {:error, {:http_status, ^status}} = perform(%{"scope" => "deploy"})
      end
    end

    test "an unverified key waits an hour, then gives up with that reason" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, ~s({"errorCode":"SiteVerificationNotCompleted"}))
      end)

      assert {:snooze, 3600} = perform(%{"scope" => "deploy"}, 1)
      assert {:snooze, 3600} = perform(%{"scope" => "deploy"}, 5)
      assert {:cancel, "verification_pending"} = perform(%{"scope" => "deploy"}, 6)
    end

    test "an unknown scope is cancelled" do
      assert {:cancel, "unknown_scope"} = perform(%{"scope" => "everything"})
    end
  end

  test "switched off, nothing is asked of the source or the network" do
    Application.put_env(
      :retro_hex_chat,
      :index_now,
      Keyword.put(Application.get_env(:retro_hex_chat, :index_now), :enabled, false)
    )

    assert {:ok, :disabled} = perform(%{"scope" => "deploy"})
    refute_received {:pages_changed_since, _}
  end

  test "reports the count, never a URL, on the job's telemetry" do
    accept_and_capture()
    test_pid = self()
    handler = "index-now-#{System.unique_integer()}"

    :telemetry.attach(
      handler,
      [:retro_hex_chat, :seo, :index_now, :submit, :stop],
      fn _event, _measurements, metadata, _ -> send(test_pid, {:stop, metadata}) end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler) end)

    perform(%{"scope" => "deploy"})

    assert_received {:stop, metadata}
    assert metadata.scope == "deploy"
    assert metadata.result == "ok"
    assert metadata.url_count == 1
    refute inspect(metadata) =~ "example.app"
  end
end
