Code.require_file("deploy_rollout.exs", __DIR__)

ExUnit.start()

defmodule DeployRolloutTest do
  use ExUnit.Case, async: true

  @expected "0.1.0-4d1a34e9a"
  @old ~s({"version":"0.1.0-5917af959","commit":"5917af959"})
  @new ~s({"version":"0.1.0-4d1a34e9a","commit":"4d1a34e9a"})

  describe "expected_version/1" do
    test "reads the version deploy.sh printed" do
      output =
        "==> Fetching origin...\n==> Version: 0.1.0-4d1a34e9a (SHA: 4d1a34e9a1b2)\n==> Building...\n"

      assert DeployRollout.expected_version(output) == {:ok, @expected}
    end

    test "no version line is an error, not a guess" do
      assert DeployRollout.expected_version("==> Building...\n") == :error
    end
  end

  describe "served_version/1" do
    test "reads the version from the endpoint's JSON" do
      assert DeployRollout.served_version(@new) == {:ok, @expected}
    end

    test "an error page or garbage is not a version" do
      assert DeployRollout.served_version("<html>502 Bad Gateway</html>") == :error
      assert DeployRollout.served_version(~s({"status":"ok"})) == :error
    end
  end

  describe "streak/3" do
    test "a match extends the run, anything else resets it" do
      assert DeployRollout.streak(4, {:ok, @expected}, @expected) == 5
      assert DeployRollout.streak(4, {:ok, "0.1.0-5917af959"}, @expected) == 0
      assert DeployRollout.streak(4, :error, @expected) == 0
    end
  end

  describe "wait/3" do
    # A clock that advances by the interval on every sleep, and a fetch that
    # replays a scripted list of answers, the last one repeating.
    defp scripted(answers) do
      {:ok, agent} = Agent.start_link(fn -> %{answers: answers, now: 0} end)

      fetch = fn ->
        Agent.get_and_update(agent, fn
          %{answers: [only]} = s -> {only, s}
          %{answers: [next | rest]} = s -> {next, %{s | answers: rest}}
        end)
      end

      now = fn -> Agent.get(agent, & &1.now) end
      sleep = fn ms -> Agent.update(agent, &%{&1 | now: &1.now + ms}) end
      {fetch, now, sleep}
    end

    defp wait(answers, opts \\ []) do
      {fetch, now, sleep} = scripted(answers)

      DeployRollout.wait(
        fetch,
        @expected,
        Keyword.merge(
          [required: 3, interval_ms: 1_000, timeout_ms: 20_000, now_ms: now, sleep: sleep],
          opts
        )
      )
    end

    test "confirmed once the new version answers enough times in a row" do
      assert {:ok, %{version: @expected, polls: 5}} =
               wait([{:ok, @old}, {:ok, @old}, {:ok, @new}])
    end

    test "an old backend in the middle of the run starts the count again" do
      answers = [{:ok, @new}, {:ok, @new}, {:ok, @old}, {:ok, @new}]

      assert {:ok, %{polls: 6}} = wait(answers)
    end

    test "a failed request also starts the count again" do
      answers = [{:ok, @new}, {:ok, @new}, {:error, "curl: (52) Empty reply"}, {:ok, @new}]

      assert {:ok, %{polls: 6}} = wait(answers)
    end

    test "never confirmed is a timeout that names what production still serves" do
      assert {:error, %{reason: :timeout, last_seen: "0.1.0-5917af959"}} =
               wait([{:ok, @old}], timeout_ms: 5_000)
    end

    test "reports every answer as it arrives" do
      parent = self()
      wait([{:ok, @new}], on_poll: &send(parent, {:poll, &1}))

      assert_received {:poll, {:ok, @expected}}
    end
  end
end
