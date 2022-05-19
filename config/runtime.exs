import Config

config :bot,
  username: System.get_env("USERNAME", "bot"),
  password: System.get_env("PASSWORD", "password")
