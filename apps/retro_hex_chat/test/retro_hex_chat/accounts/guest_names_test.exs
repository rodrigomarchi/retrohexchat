defmodule RetroHexChat.Accounts.GuestNamesTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Accounts.GuestNames
  alias RetroHexChat.Accounts.NicknameValidator

  @moduletag :unit

  setup do
    server = start_supervised!({GuestNames, name: nil})
    %{server: server}
  end

  # A tab is a process: it claims, says which name it got, and stays open until
  # told to close. Linked, so a claim that fails fails the test with its own
  # reason; the wait is generous because a busy suite can stall it past the
  # default without anything being wrong.
  defp open_tab(server, browser_id) do
    test = self()

    pid =
      spawn_link(fn ->
        send(test, {:claimed, self(), GuestNames.claim(browser_id, server)})

        receive do
          :close -> :ok
        end
      end)

    assert_receive {:claimed, ^pid, name}, 2_000
    {pid, name}
  end

  defp close_tab(server, pid) do
    ref = Process.monitor(pid)
    send(pid, :close)
    assert_receive {:DOWN, ^ref, :process, ^pid, _reason}
    # The registry hears the same DOWN; a call behind it has seen it handled.
    :sys.get_state(server)
  end

  defp browser, do: "browser-#{System.unique_integer([:positive])}"

  # A draw that lands on the next number each time.
  defp counter do
    {:ok, agent} = Agent.start_link(fn -> 0 end)
    fn range -> Agent.get_and_update(agent, &{rem(&1, range) + 1, &1 + 1}) end
  end

  test "every tab of one browser gets the same name", %{server: server} do
    browser = browser()
    {_tab1, name1} = open_tab(server, browser)
    {_tab2, name2} = open_tab(server, browser)
    {_tab3, name3} = open_tab(server, browser)

    assert name1 == name2
    assert name2 == name3
    assert NicknameValidator.guest?(name1)
    assert NicknameValidator.valid?(name1)
  end

  test "two browsers drawing the same number get different names" do
    # A draw that always lands on the same number: every browser after the
    # first has to look past it.
    server = start_supervised!({GuestNames, name: nil, uniform: fn _range -> 1 end}, id: :fixed)

    {_tab1, first} = open_tab(server, browser())
    {_tab2, second} = open_tab(server, browser())
    {_tab3, third} = open_tab(server, browser())

    assert first == "Guest1000"
    assert second == "Guest10000"
    assert third not in [first, second]
    assert Enum.all?([first, second, third], &NicknameValidator.guest?/1)
    assert Enum.all?([first, second, third], &NicknameValidator.valid?/1)
  end

  test "many browsers at once all get names of their own", %{server: server} do
    names = for _ <- 1..300, do: server |> open_tab(browser()) |> elem(1)

    assert length(Enum.uniq_by(names, &String.downcase/1)) == 300
  end

  test "the name is held while any tab of the browser is open", %{server: server} do
    browser = browser()
    {tab1, name} = open_tab(server, browser)
    {tab2, _name} = open_tab(server, browser)

    close_tab(server, tab1)
    {_tab3, again} = open_tab(server, browser)
    assert again == name

    close_tab(server, tab2)
  end

  test "the name is freed when the last tab closes" do
    server = start_supervised!({GuestNames, name: nil, uniform: fn _range -> 1 end}, id: :fixed)
    {tab, name} = open_tab(server, browser())
    close_tab(server, tab)

    # Nobody holds it now, so the next browser drawing it gets it.
    assert {_tab, ^name} = open_tab(server, browser())
  end

  test "a browser that comes back after closing every tab draws again" do
    server = start_supervised!({GuestNames, name: nil, uniform: counter()}, id: :counted)
    browser = browser()
    {tab, name} = open_tab(server, browser)
    close_tab(server, tab)

    {_tab, again} = open_tab(server, browser)
    refute again == name
  end

  test "claiming twice from one tab keeps one name", %{server: server} do
    browser = browser()
    name = GuestNames.claim(browser, server)

    assert GuestNames.claim(browser, server) == name
  end

  test "a browser with no id gives each tab a visitor of its own", %{server: server} do
    {_tab1, name1} = open_tab(server, "")
    {_tab2, name2} = open_tab(server, nil)

    refute name1 == name2
    assert NicknameValidator.guest?(name1)
    assert NicknameValidator.guest?(name2)
  end

  describe "locales" do
    test "remembers the language a guest's tab reads in, by guest name", %{server: server} do
      test = self()

      pid =
        spawn_link(fn ->
          name = GuestNames.claim("b-#{System.unique_integer([:positive])}", server)
          :ok = GuestNames.put_locale("ja", server)
          send(test, {:claimed, name})

          receive do
            :close -> :ok
          end
        end)

      assert_receive {:claimed, name}, 2_000

      assert GuestNames.locales([name, "Guest0"], server) == %{name => "ja"}
      close_tab(server, pid)
      assert GuestNames.locales([name], server) == %{}
    end

    test "a tab that claimed nothing has nothing to record", %{server: server} do
      assert :ok = GuestNames.put_locale("ja", server)
      assert :sys.get_state(server).holders == %{}
    end
  end
end
