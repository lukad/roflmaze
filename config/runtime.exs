import Config

config :bot,
  username: System.get_env("USERNAME", "bot"),
  password: System.get_env("PASSWORD", "password"),
  host: System.get_env("HOST", "gpn-mazing.v6.rocks"),
  port: System.get_env("PORT", "4000")
