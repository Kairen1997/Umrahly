defmodule Umrahly.PackagesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Umrahly.Packages` context.
  """

  @doc """
  Generate a package.
  """
  def package_fixture(attrs \\ %{}) do
    {:ok, package} =
      attrs
      |> Enum.into(%{

      })
      |> Umrahly.Packages.create_package()

    package
  end
end
