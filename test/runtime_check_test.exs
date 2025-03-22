defmodule RuntimeCheckTest do
  use ExUnit.Case, async: true
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
      assert RuntimeCheck.run(Checks) == {:ok, %{nested: %{test_ignored: :ignored}}}
      assert_received :ran_check
      assert_received :ran_nested_check
    end

    test "runs checks and fails" do
      Process.put(:fail_check?, true)

      assert RuntimeCheck.run(Checks) ==
               {:error, %{nested: %{test_ignored: :ignored, maybe_fails: "the check did fail"}}}

      assert_received :ran_check
      assert_received :ran_nested_check
    end
  end
end
