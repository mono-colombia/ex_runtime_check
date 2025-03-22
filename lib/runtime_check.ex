defmodule RuntimeCheck do
  @external_resource "README.md"
  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC !-->")
             |> Enum.fetch!(1)

  require Logger

  alias RuntimeCheck.Check

  defmacro __using__(_) do
    quote do
      use GenServer

      import RuntimeCheck.DSL

      @behaviour RuntimeCheck

      @doc """
      Starts the RuntimeCheck GenServer.

      Set the module doc for more details.
      """
      def start_link(arg) do
        GenServer.start_link(__MODULE__, arg)
      end

      @impl true
      def init(_arg) do
        RuntimeCheck.init(__MODULE__)
      end

      @spec run([{:log, boolean()}]) :: {:ok, map()} | {:error, map()}
      def run(opts \\ []) do
        RuntimeCheck.run(__MODULE__, opts)
      end
    end
  end

  @doc """
  Whether the checks should run on startup.
  """
  @callback run?() :: boolean()

  @doc """
  A list of checks to run.
  """
  @callback checks() :: [RuntimeCheck.Check.t()]

  @doc false
  def init(module) do
    if module.run?() do
      case run(module) do
        {:ok, _} -> :ignore
        {:error, _reasons} -> {:stop, :runtime_check_failed}
      end
    else
      :ignore
    end
  end

  @doc """
  Runs the checks in the module.

  Returns `{:ok, ignored_map}` if checks pass. `ignored_map` is a a nested map of checks that
  were ignored. Like `%{check1: :ignored, check2: %{subcheck1: :ignored}}`. The map is empty if
  no checks are ignored.

  If at least one check fails, `{:error, map}` is returned. Where `map` is a nested map with
  ignored and failed checks like

  ```
  %{
    check1: :ignored,
    check2: "failure reason",
    check3: %{
      subcheck1: :ignored,
      subcheck2: "another reason"
    }
  }
  ```

  By default, the result will be logged, but it can be disabled by passing `log: false`.

  Use the module directly when starting in a supervisor tree. See the moduledocs for
  `RuntimeCheck`.
  """
  @spec run(module(), [{:log, boolean()}]) :: {:ok, map()} | {:error, map()}
  def run(module, opts \\ []) do
    log? = Keyword.get(opts, :log, true)

    if log?, do: Logger.info("[RuntimeCheck] starting...")

    case Check.run(module.checks(), 0, log?) do
      {:ok, _} = res ->
        if log?, do: Logger.info("[RuntimeCheck] done")
        res

      {:error, _} = res ->
        if log?, do: Logger.error("[RuntimeCheck] some checks failed!")
        res
    end
  end
end
