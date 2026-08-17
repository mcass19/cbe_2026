import Config
config :ash, policies: [show_policy_breakdowns?: true]

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :lobby_tui, LobbyTuiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "YWAIfsnj6kdlvNhjtDb44u0BGfvKJ0e4CXQLQNZedcI2PCnBVY23XMv5X2Prm1gn",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# No SSH endpoint under test — the integration test starts its own
# daemon on an ephemeral port instead.
config :lobby_tui, :ssh, enabled: false
