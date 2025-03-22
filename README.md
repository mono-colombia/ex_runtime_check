# RuntimeCheck

<!-- MDOC !-->

A `GenServer` to run a set of system checks on application start up.

The process is normally run after the rest of the children in the supervisor, so processes like
`Ecto`, `Oban`, and `FunWithFlags` are available.
Additionally, it is not actually kept in the supervision tree as `init/1` returns `:ignore` when
the checks succeed.

## Usage

Define a module that uses `RuntimeCheck`:

```elixir
defmodule MyApp.RuntimeChecks do
  use RuntimeCheck

  @impl true
  def run? do
    # Decide if checks should run. Maybe skip them during tests or if an env var is set.
    true
  end

  @impl true
  def checks do
    # Return a list of checks. See `RuntimeCheck.DSL`.
    [
      check(:foo, fn ->
        # Run function that should return :ok, {:ok, something}, :ignore or {:error, reason}
        :ok
      end),
      check(:nested, [
        check(:bar, fn -> :ignore end),
        check(:baz, fn ->
          if everything_ok() do
            :ok
          else
            {:error, "not everything is ok!"}
          end
        end)
      ]),
      # If FunWithFlags is installed. Run nested checks only if the flag is enabled.
      feature_check(:some_flag, [
        app_var(:quzz_url :my_app, [:quzz, :url]),
        env_var("QUZZ_API_KEY")
      ])
    ]
  end
end
```

Then in `MyApp.application` add the worker

```elixir
children = [
  # ...
  MyApp.Repo,
  MyAppWeb.Endpoint,
  # ...
  MyApp.RuntimeChecks
]
```

Then when running the app, something like this will be logged:

```text
[info] [RuntimeCheck] starting...
[info] [RuntimeCheck] foo: passed
[info] [RuntimeCheck] nested:
[warning] [RuntimeCheck] > bar: ignored
[info] [RuntimeCheck] > baz: passed
[info] [RuntimeCheck] nested: passed
[info] [RuntimeCheck] some_flag:
[info] [RuntimeCheck] > quzz_url: passed
[info] [RuntimeCheck] > QUZZ_API_KEY: passed
[info] [RuntimeCheck] some_flag: passed
[info] [RuntimeCheck] done
```

Or if some checks fail:

```text
[info] [RuntimeCheck] starting...
[info] [RuntimeCheck] foo: passed
[info] [RuntimeCheck] nested:
[warning] [RuntimeCheck] > bar: ignored
[error] [RuntimeCheck] > baz: failed. Reason: "not everything is ok!"
[error] [RuntimeCheck] nested: failed
[info] [RuntimeCheck] some_flag:
[info] [RuntimeCheck] > quzz_url: passed
[info] [RuntimeCheck] > QUZZ_API_KEY: passed
[info] [RuntimeCheck] some_flag: passed
[error] [RuntimeCheck] some checks failed!
** (Mix) Could not start application my_app: MyApp.Application.start(:normal, []) returned an error: shutdown: failed to start child: MyApp.RuntimeChecks
    ** (EXIT) :runtime_check_failed
```

## Checks

Each check is a `RuntimeCheck.Check` but normally, they are constructed using the functions
in `RuntimeCheck.DSL`.

### Feature flag checks

If [fun_with_flags](https://github.com/tompave/fun_with_flags) is installed, a `feature_check`
function will be available in the DSL. It allows running checks only if a feature flag is
enabled.

If you add `fun_with_flags` after adding `runtime_check` make sure to recompile with
`mix deps.compile --force runtime_check`.

## Testing

To test the checks you can run `MyApp.RuntimeChecks.run()`, which will run the checks in the
current process instead of starting a new one. You can pass `log: false` to disable logging.

```elixir
assert MyApp.RuntimeChecks.run(log: false) == {:ok, %{}}
```

See `RuntimeCheck.run/2` for details on the return value.

<!-- MDOC !-->

## Installation

Add `runtime_check` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:runtime_check, github: "mono-colombia/ex_runtime_check"}
  ]
end
```
