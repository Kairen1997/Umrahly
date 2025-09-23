defmodule UmrahlyWeb.Timezone do
  @moduledoc """
  Helpers for converting and formatting datetimes in the application's local timezone.
  """

  @local_tz "Asia/Kuala_Lumpur"

  @doc """
  Convert a DateTime or NaiveDateTime to the local timezone.
  Returns the original value for Date or unsupported types.
  """
  @spec to_local(DateTime.t() | NaiveDateTime.t() | Date.t() | any()) :: DateTime.t() | NaiveDateTime.t() | Date.t() | any()
  def to_local(%DateTime{} = dt) do
    case DateTime.shift_zone(dt, @local_tz) do
      {:ok, local} -> local
      {:error, _} -> dt
    end
  end

  def to_local(%NaiveDateTime{} = ndt) do
    ndt
    |> DateTime.from_naive!("Etc/UTC")
    |> to_local()
  end

  def to_local(other), do: other

  @doc """
  Format a date or datetime in local timezone with a strftime pattern.
  If a Date is provided, it is formatted directly.
  """
  @spec format_local(DateTime.t() | NaiveDateTime.t() | Date.t() | nil, String.t()) :: String.t()
  def format_local(nil, _pattern), do: ""

  def format_local(%Date{} = date, pattern) when is_binary(pattern) do
    Calendar.strftime(date, pattern)
  end

  def format_local(datetime, pattern) when is_binary(pattern) do
    datetime
    |> to_local()
    |> Calendar.strftime(pattern)
  end
end
