defmodule RuntimeCheck.FlagAdapter do
  alias FunWithFlags.Flag

  @behaviour FunWithFlags.Store.Persistent

  @proc_key :fun_with_flags

  @impl true
  def worker_spec, do: nil

  defp all do
    Process.get(@proc_key, %{})
  end

  @impl true
  def get(flag_name) do
    {:ok, Map.get(all(), flag_name, Flag.new(flag_name))}
  end

  @impl true
  def put(flag_name, gate) do
    {:ok, flag} = get(flag_name)
    new_flag = %Flag{flag | gates: [gate | flag.gates]}
    Process.put(@proc_key, Map.put(all(), flag_name, new_flag))
    {:ok, new_flag}
  end

  @impl true
  def delete(_flag_name, _gate) do
    raise "not implemented"
  end

  @impl true
  def delete(_flag_name) do
    raise "not implemented"
  end

  @impl true
  def all_flags do
    {:ok, Map.values(all())}
  end

  @impl true
  def all_flag_names do
    {:ok, Map.keys(all())}
  end
end
