# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :umrahly,
  ecto_repos: [Umrahly.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :umrahly, UmrahlyWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: UmrahlyWeb.ErrorHTML, json: UmrahlyWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Umrahly.PubSub,
  live_view: [signing_salt: "DDt5NKMk"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :umrahly, Umrahly.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  umrahly: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  umrahly: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Payment Gateway Configuration
config :umrahly, :payment_gateway,
  # Stripe configuration (example)
  stripe: [
    publishable_key: System.get_env("STRIPE_PUBLISHABLE_KEY") || "pk_test_example",
    secret_key: System.get_env("STRIPE_SECRET_KEY") || "sk_test_example",
    webhook_secret: System.get_env("STRIPE_WEBHOOK_SECRET") || "whsec_example",
    mode: System.get_env("STRIPE_MODE") || "test"
  ],
  # PayPal configuration (example)
  paypal: [
    client_id: System.get_env("PAYPAL_CLIENT_ID") || "client_id_example",
    client_secret: System.get_env("PAYPAL_CLIENT_SECRET") || "client_secret_example",
    mode: System.get_env("PAYPAL_MODE") || "sandbox" # or "live"
  ],
  # E-Wallet configuration (Boost, Touch 'n Go, etc.)
  ewallet: [
    boost_api_key: System.get_env("BOOST_API_KEY") || "boost_api_key_example",
    touchngo_api_key: System.get_env("TOUCHNGO_API_KEY") || "touchngo_api_key_example",
    mode: System.get_env("EWALLET_MODE") || "test"
  ],
  # Generic payment gateway (for development/testing)
  generic: [
    base_url: System.get_env("PAYMENT_GATEWAY_URL") || "https://payment-gateway.example.com",
    merchant_id: System.get_env("PAYMENT_MERCHANT_ID") || "merchant_example",
    api_key: System.get_env("PAYMENT_API_KEY") || "api_key_example"
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
