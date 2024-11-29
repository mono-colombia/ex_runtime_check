defmodule RuntimeCheck do
  @moduledoc """
  A GenServer to run a set of system checks on application start up.

  The process is normally run after the rest of the children in the supervisor, so processes like Ecto and FunWithFlags are available.
  Additionally, it is not actually kept in the supervision tree as `init/1` returns `:ignore` when the checks succeed.
  """

  require Logger

  alias RuntimeCheck.Check

  defmacro __using__(_) do
    quote do
      use GenServer

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

      def run do
        RuntimeCheck.run(__MODULE__)
      end
    end
  end

  @callback run?() :: boolean()
  @callback checks() :: [RuntimeCheck.Check.t()]

  @doc false
  def init(module) do
    if module.run?() do
      case run(module) do
        :ok -> :ignore
        {:error, reason} -> {:stop, reason}
      end
    else
      :ignore
    end
  end

  @doc """
  Runs the checks in the module.

  Returns `:ok` when the checks pass, `{:error, :runtime_check_failed}` when they fail.

  Use the module directly when starting in a supervisor tree.
  """
  @spec run(module()) :: :ok | {:error, :runtime_check_failed}
  def run(module) do
    Logger.info("RuntimeCheck] starting...")

    case Check.run(module.checks(), 0, true) do
      :ok ->
        Logger.info("[RuntimeCheck] done")
        :ok

      :error ->
        Logger.error("[RuntimeCheck] some checks failed!")
        {:error, :runtime_check_failed}
    end
  end
end
