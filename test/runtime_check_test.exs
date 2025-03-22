defmodule RuntimeCheckTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  doctest RuntimeCheck

  defmodule Checks do
    use RuntimeCheck

    @impl true
    def run? do
      true
    end

    @impl true
    def checks do
      [
        check(:test, fn ->
          send(self(), :ran_check)
          :ok
        end),
        check(:nested, [
          check(:test, fn ->
            send(self(), :ran_nested_check)
            :ok
          end),
          check(:test_ignored, fn -> :ignore end),
          check(:maybe_fails, fn ->
            if Process.get(:fail_check?) do
              {:error, "the check did fail"}
            else
              :ok
            end
          end)
        ])
      ]
    end
  end

  describe "run/1" do
    test "runs checks and succeeds" do
      assert RuntimeCheck.run(Checks, log: false) == {:ok, %{nested: %{test_ignored: :ignored}}}
      assert_received :ran_check
      assert_received :ran_nested_check
    end

    test "runs checks and fails" do
      Process.put(:fail_check?, true)

      assert RuntimeCheck.run(Checks, log: false) ==
               {:error, %{nested: %{test_ignored: :ignored, maybe_fails: "the check did fail"}}}

      assert_received :ran_check
      assert_received :ran_nested_check
    end
  end

  describe "init/1" do
    test "runs checks and succeeds" do
      log =
        capture_log(fn ->
          assert RuntimeCheck.init(Checks) == :ignore
        end)

      assert_received :ran_check
      assert_received :ran_nested_check

      assert log =~ "[RuntimeCheck] starting..."
      assert log =~ "[RuntimeCheck] test: passed"
      assert log =~ "[RuntimeCheck] done"
    end

    test "runs checks and fails" do
      Process.put(:fail_check?, true)

      log =
        capture_log(fn ->
          assert RuntimeCheck.init(Checks) == {:stop, :runtime_check_failed}
        end)

      assert_received :ran_check
      assert_received :ran_nested_check

      assert log =~ "[RuntimeCheck] starting..."
      assert log =~ "[RuntimeCheck] test: passed"
      assert log =~ "[RuntimeCheck] some checks failed!"
    end
  end
end
