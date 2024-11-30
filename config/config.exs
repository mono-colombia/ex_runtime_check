import Config

config :fun_with_flags, :cache, enabled: false
config :fun_with_flags, :persistence, adapter: RuntimeCheck.FlagAdapter
