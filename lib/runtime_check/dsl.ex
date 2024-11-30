defmodule RuntimeCheck.DSL do
  @moduledoc """
  Utility functions for creating checks.

  The most basic functions are `check/2` and `check/3`.
  """
  alias RuntimeCheck.Check

  @type checker_or_list :: Check.checker() | [Check.t()]

  @doc """
  Creates a basic check.

  It can be called using:
  `check(name, function)`
  `check(name, list)`
  `check(name, function, list)`

  When the second argument is a function with arity 0, it should return:
  - `:ok` or `{:ok, term()}` when the check passes. Nested checks are executed.
  - `:ignore` when the check is ignored, nested checks are ignored too.
  - `{:error, term()}` when the check fails. Nested checks are not executed.

  When the second or third argument is a list of checks, they are executed in order
  and only if the parent check initally passes.

  When the check has nested checks, the parent check only passes if all nested checks either pass or are ignored.
  When there are no nested checks, the check passes immediately.
  """
  @spec check(atom(), checker_or_list()) :: Check.t()
  def check(name, checker) when is_atom(name) and is_function(checker, 0) do
    %Check{name: name, checker: checker}
  end

  def check(name, nested_checks) when is_atom(name) and is_list(nested_checks) do
    %Check{name: name, nested_checks: nested_checks}
  end

  @doc """
  Creates a basic check with a function and a list of nested checks.

  See `check/2` for more info.
  """
  @spec check(atom(), Check.checker(), [Check.t()]) :: Check.t()
  def check(name, checker, nested_checks)
      when is_atom(name) and is_function(checker, 0) and is_list(nested_checks) do
    %Check{name: name, checker: checker, nested_checks: nested_checks}
  end

  if Code.ensure_loaded?(FunWithFlags) do
    @doc """
    Creates a feature flag check.

    The name of the check is used as the feature flag name as well.
    The function and/or nested checks are only executed if the feature is enabled using a boolean gate.
    If not, the check is ignored.

    The second and third argument behave like `check/2-3`.  See `check/2` for more info.
    """
    @spec feature_check(atom(), checker_or_list()) :: Check.t()
    def feature_check(name, fun) when is_atom(name) and is_function(fun, 0) do
      checker = fn ->
        with :ok <- feature_checker(name) do
          fun.()
        end
      end

      %Check{name: name, checker: checker}
    end

    def feature_check(name, nested_checks) when is_atom(name) and is_list(nested_checks) do
      %Check{name: name, checker: fn -> feature_checker(name) end, nested_checks: nested_checks}
    end

    @doc """
    Creates a feature flag check.

    See `feature_check/2` for more info.
    """
    @spec feature_check(atom(), Check.checker(), [Check.t()]) :: Check.t()
    def feature_check(name, fun, nested_checks)
        when is_atom(name) and is_function(fun, 0) and is_list(nested_checks) do
      checker = fn ->
        with :ok <- feature_checker(name) do
          fun.()
        end
      end

      %Check{name: name, checker: checker, nested_checks: nested_checks}
    end

    @spec feature_checker(atom()) :: :ok | :ignore
    defp feature_checker(name) do
      if FunWithFlags.enabled?(name) or flag_gate_enabled?(name) do
        :ok
      else
        :ignore
      end
    end

    @spec flag_gate_enabled?(atom()) :: boolean()
    defp flag_gate_enabled?(name) do
      case FunWithFlags.get_flag(name) do
        %FunWithFlags.Flag{gates: gates} ->
          Enum.any?(gates, & &1.enabled)

        nil ->
          false
      end
    end
  end

  @doc """
  Creates a environment variable check.

  The name of the environment variable is used as the name of the check.
  The check fails when the variable is not present or when it's empty, unless `allow_empty: true` is given in the opts.

  This check is intended to be used as a nested check, as always-required variables should be enfored in `config/runtime.exs`, not here.
  """
  @spec env_var(String.t(), [allow_empty: boolean()] | []) :: Check.t()
  def env_var(var_name, opts \\ []) do
    allow_empty = Keyword.get(opts, :allow_empty, false)

    %Check{name: var_name, checker: fn -> env_var_checker(var_name, allow_empty) end}
  end

  @spec env_var_checker(String.t(), boolean()) :: :ok | {:error, String.t()}
  defp env_var_checker(var_name, allow_empty) do
    case System.fetch_env(var_name) do
      {:ok, ""} ->
        if allow_empty do
          :ok
        else
          {:error, "Env var #{var_name} is empty"}
        end

      {:ok, _value} ->
        :ok

      :error ->
        {:error, "Env var #{var_name} is missing"}
    end
  end

  @doc """
  Creates an application variable check.

  The third argument can be either an atom or a list of atoms.
  If it's a list, the first element is used as key for Application.fetch_env/2 and the rest looked up using get_in, so the value should implement the Access protocol.

  The check fails when the config is not present or results in a nil value.
  """
  @spec app_var(atom(), atom(), atom() | [atom()], Keyword.t()) :: Check.t()
  def app_var(name, otp_app, key_or_keys, opts \\ [])

  def app_var(name, otp_app, key, opts)
      when is_atom(name) and is_atom(otp_app) and is_atom(key) do
    checker = fn ->
      with {:ok, value} <- app_var_checker(otp_app, key) do
        maybe_reject_value(key, value, opts)
      end
    end

    %Check{name: name, checker: checker}
  end

  def app_var(name, otp_app, [key | key_path] = keys, opts)
      when is_atom(name) and is_atom(otp_app) and is_atom(key) do
    checker = fn ->
      with {:ok, config} <- app_var_checker(otp_app, key) do
        case get_in(config, key_path) do
          nil -> {:error, "Key path #{inspect(key_path)} in key #{key} is missing or nil"}
          value -> maybe_reject_value(keys, value, opts)
        end
      end
    end

    %Check{name: name, checker: checker}
  end

  @spec app_var_checker(atom(), atom()) :: {:ok, term()} | {:error, String.t()}
  defp app_var_checker(otp_app, key) do
    case Application.fetch_env(otp_app, key) do
      {:ok, nil} -> {:error, "Value for key #{key} is nil in app config for #{otp_app}"}
      {:ok, value} -> {:ok, value}
      :error -> {:error, "Key #{key} not found in app config for #{otp_app}"}
    end
  end

  @spec maybe_reject_value(atom() | [atom()], term(), Keyword.t()) :: :ok | {:error, String.t()}
  defp maybe_reject_value(key_or_keys, value, opts) do
    rejected = opts[:reject] || []

    if value in rejected do
      {:error, "Value #{value} is not allowed for #{inspect(key_or_keys)}"}
    else
      :ok
    end
  end
end
