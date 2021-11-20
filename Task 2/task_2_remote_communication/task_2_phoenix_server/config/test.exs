import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :task_2_phoenix_server, Task2PhoenixServerWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "qvHZacx1Dgw6nKc1KenjY4TFvh42EP56swX0qb7o2UZrTmheDI8L9xd1Yzb30y6e",
  server: false

# In test we don't send emails.
config :task_2_phoenix_server, Task2PhoenixServer.Mailer,
  adapter: Swoosh.Adapters.Test

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
