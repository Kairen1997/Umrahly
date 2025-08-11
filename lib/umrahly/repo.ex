defmodule Umrahly.Repo do
  use Ecto.Repo,
    otp_app: :umrahly,
    adapter: Ecto.Adapters.Postgres
end
