defmodule RuntimeCheckTest do
  use ExUnit.Case
  doctest RuntimeCheck

  defmodule Checks do
    use RuntimeCheck

    alias RuntimeCheck.Check

    @impl true
    def run? do
      true
    end

    @impl true
    def checks do
      [
        %Check{
          name: :test,
          checker: fn ->
            send(self(), :ran_check)
            :ok
          end
        }
      ]
    end
  end

  describe "run/1" do
    test "runs checks" do
      assert RuntimeCheck.run(Checks) == :ok
      assert_received :ran_check
    end
  end
end
