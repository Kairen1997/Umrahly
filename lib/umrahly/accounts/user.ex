defmodule Umrahly.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :full_name, :string
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :current_password, :string, virtual: true, redact: true
    field :confirmed_at, :utc_datetime
    field :is_admin, :boolean, default: false

    # Profile fields merged from profiles table
    field :address, :string
    field :identity_card_number, :string
    field :phone_number, :string
    field :monthly_income, :integer
    field :birthdate, :date
    field :gender, :string
    field :profile_photo, :string

    timestamps(type: :utc_datetime)
  end

  @doc """
  A user changeset for registration.

  It is important to validate the length of both email and password.
  Otherwise databases may truncate the email without warnings, which
  could lead to unpredictable or insecure behaviour. Long passwords may
  also be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.

    * `:validate_email` - Validates the uniqueness of the email, in case
      you don't want to validate the uniqueness of the email (like when
      using this changeset for validations on a LiveView form before
      submitting the form), this option can be set to `false`.
      Defaults to `true`.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:full_name, :email, :password, :is_admin, :address, :identity_card_number, :phone_number, :monthly_income, :birthdate, :gender, :profile_photo])
    |> validate_full_name(opts)
    |> validate_email(opts)
    |> validate_password(opts)
    |> validate_admin_role()
    |> validate_profile_fields()
  end

  defp validate_full_name(changeset, _opts) do
    changeset
    |>validate_required([:full_name])
    |>validate_length(:full_name, min: 3, max: 100)
    |>validate_format(:full_name, ~r/^[A-Za-z\s'.-]+$/)
  end
  defp validate_email(changeset, opts) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> maybe_validate_unique_email(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    # Examples of additional password validation:
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp validate_admin_role(changeset) do
    # Only set default if is_admin is not already set
    if get_change(changeset, :is_admin) == nil do
      changeset |> put_change(:is_admin, false)
    else
      changeset
    end
  end

  # Profile field validations
  defp validate_profile_fields(changeset) do
    changeset
    |> validate_monthly_income()
    |> validate_gender()
    |> validate_length(:profile_photo, max: 255)
  end

  defp validate_monthly_income(changeset) do
    case get_field(changeset, :monthly_income) do
      nil -> changeset
      income when is_integer(income) and income > 0 -> changeset
      _ -> add_error(changeset, :monthly_income, "must be a positive integer")
    end
  end

  defp validate_gender(changeset) do
    case get_field(changeset, :gender) do
      nil -> changeset
      gender when gender in ["male", "female"] -> changeset
      _ -> add_error(changeset, :gender, "must be either male or female")
    end
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`, but that
      # would keep the database transaction open longer and hurt performance.
      |> put_change(:hashed_password, Pbkdf2.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, Umrahly.Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end

  @doc """
  A user changeset for updating profile information.
  """
  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:address, :identity_card_number, :phone_number, :monthly_income, :birthdate, :gender, :profile_photo])
    |> validate_identity_card_number()
    |> validate_phone_number()
    |> validate_monthly_income()
    |> validate_gender()
    |> validate_length(:profile_photo, max: 255)
  end

  defp validate_identity_card_number(changeset) do
    case get_field(changeset, :identity_card_number) do
      nil -> changeset
      ic_number when is_binary(ic_number) and byte_size(ic_number) > 0 -> changeset
      _ -> add_error(changeset, :identity_card_number, "must be a valid identity card number")
    end
  end

  defp validate_phone_number(changeset) do
    case get_field(changeset, :phone_number) do
      nil -> changeset
      phone when is_binary(phone) and byte_size(phone) > 0 -> changeset
      _ -> add_error(changeset, :phone_number, "must be a valid phone number")
    end
  end

  @doc """
  A user changeset for changing the email.

  It requires the email to change otherwise an error is added.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  @doc """
  A user changeset for changing the password.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  A user changeset for updating user information.
  """
  def update_changeset(user, attrs) do
    user
    |> cast(attrs, [:full_name, :address, :identity_card_number, :phone_number, :monthly_income, :birthdate, :gender, :profile_photo])
    |> validate_full_name(validate_email: false)
    |> validate_profile_fields()
  end

  @doc """
  A user changeset for updating profile information only.
  """
  def profile_update_changeset(user, attrs) do
    user
    |> cast(attrs, [:address, :identity_card_number, :phone_number, :monthly_income, :birthdate, :gender, :profile_photo])
    |> validate_profile_fields()
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Pbkdf2.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%Umrahly.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Pbkdf2.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Pbkdf2.no_user_verify()
    false
  end

  @doc """
  Validates the current password otherwise adds an error to the changeset.
  """
  def validate_current_password(changeset, password) do
    changeset = cast(changeset, %{current_password: password}, [:current_password])

    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end
end
