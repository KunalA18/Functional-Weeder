import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :task_4c_phoenix_server, Task4CPhoenixServerWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "qF6ZU6m6jxh9TQDm0KZGoLrlsklk9flcTTkaKhD7SN8FkPvzOg6erpWjg4tMfEsu",
  server: false

# In test we don't send emails.
config :task_4c_phoenix_server, Task4CPhoenixServer.Mailer,
  adapter: Swoosh.Adapters.Test

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
