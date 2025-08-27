defmodule Umrahly.Bookings.TravelerDetailTest do
  use Umrahly.DataCase

  alias Umrahly.Bookings.TravelerDetail

  @valid_attrs %{
    full_name: "John Doe",
    identity_card_number: "123456789012",
    passport_number: "A12345678",
    passport_expiry_date: ~D[2030-12-31],
    phone_number: "+60123456789",
    email_address: "john@example.com",
    gender: "male",
    date_of_birth: ~D[1990-01-01],
    nationality: "Malaysian",
    emergency_contact_name: "Jane Doe",
    emergency_contact_phone: "+60123456788",
    emergency_contact_relationship: "Spouse",
    room_preference: "single",
    vaccination_record: "COVID-19 vaccinated",
    medical_conditions: "None",
    mahram_info: "Traveling with husband",
    special_needs_requests: "Vegetarian meals",
    booking_id: 1,
    user_id: 1
  }

  @invalid_attrs %{
    full_name: nil,
    identity_card_number: nil,
    passport_number: nil,
    passport_expiry_date: nil,
    phone_number: nil,
    email_address: nil,
    gender: nil,
    date_of_birth: nil,
    booking_id: nil,
    user_id: nil
  }

  describe "changeset/2" do
    test "changeset with valid attributes" do
      changeset = TravelerDetail.changeset(%TravelerDetail{}, @valid_attrs)
      assert changeset.valid?
    end

    test "changeset with invalid attributes" do
      changeset = TravelerDetail.changeset(%TravelerDetail{}, @invalid_attrs)
      refute changeset.valid?
    end

    test "changeset validates required fields" do
      changeset = TravelerDetail.changeset(%TravelerDetail{}, @invalid_attrs)

      assert %{
        full_name: ["can't be blank"],
        identity_card_number: ["can't be blank"],
        passport_number: ["can't be blank"],
        passport_expiry_date: ["can't be blank"],
        phone_number: ["can't be blank"],
        email_address: ["can't be blank"],
        gender: ["can't be blank"],
        date_of_birth: ["can't be blank"],
        booking_id: ["can't be blank"],
        user_id: ["can't be blank"]
      } = errors_on(changeset)
    end

    test "changeset validates gender inclusion" do
      attrs = Map.put(@valid_attrs, :gender, "invalid")
      changeset = TravelerDetail.changeset(%TravelerDetail{}, attrs)
      refute changeset.valid?
      assert %{gender: ["is invalid"]} = errors_on(changeset)
    end

    test "changeset validates email format" do
      attrs = Map.put(@valid_attrs, :email_address, "invalid-email")
      changeset = TravelerDetail.changeset(%TravelerDetail{}, attrs)
      refute changeset.valid?
      assert %{email_address: ["has invalid format"]} = errors_on(changeset)
    end

    test "changeset validates passport expiry date" do
      attrs = Map.put(@valid_attrs, :passport_expiry_date, ~D[2020-01-01])
      changeset = TravelerDetail.changeset(%TravelerDetail{}, attrs)
      refute changeset.valid?
      assert %{passport_expiry_date: ["Passport must be valid (not expired)"]} = errors_on(changeset)
    end

    test "changeset validates date of birth" do
      attrs = Map.put(@valid_attrs, :date_of_birth, ~D[1900-01-01])
      changeset = TravelerDetail.changeset(%TravelerDetail{}, attrs)
      refute changeset.valid?
      assert %{date_of_birth: ["Date of birth must be valid"]} = errors_on(changeset)
    end
  end

  describe "phase1_changeset/2" do
    test "phase1_changeset with valid phase 1 attributes" do
      phase1_attrs = Map.take(@valid_attrs, [
        :full_name, :identity_card_number, :passport_number, :passport_expiry_date,
        :phone_number, :email_address, :gender, :date_of_birth, :booking_id, :user_id
      ])

      changeset = TravelerDetail.phase1_changeset(%TravelerDetail{}, phase1_attrs)
      assert changeset.valid?
    end

    test "phase1_changeset without optional fields" do
      phase1_attrs = Map.take(@valid_attrs, [
        :full_name, :identity_card_number, :passport_number, :passport_expiry_date,
        :phone_number, :email_address, :gender, :date_of_birth, :booking_id, :user_id
      ])

      changeset = TravelerDetail.phase1_changeset(%TravelerDetail{}, phase1_attrs)
      assert changeset.valid?
    end
  end

  describe "phase2_changeset/2" do
    test "phase2_changeset with valid phase 2 attributes" do
      phase2_attrs = %{
        nationality: "Malaysian",
        emergency_contact_name: "Jane Doe",
        emergency_contact_phone: "+60123456788",
        emergency_contact_relationship: "Spouse",
        room_preference: "single",
        vaccination_record: "COVID-19 vaccinated",
        medical_conditions: "None"
      }

      changeset = TravelerDetail.phase2_changeset(%TravelerDetail{}, phase2_attrs)
      assert changeset.valid?
    end

    test "phase2_changeset without required nationality" do
      phase2_attrs = %{
        emergency_contact_name: "Jane Doe",
        emergency_contact_phone: "+60123456788"
      }

      changeset = TravelerDetail.phase2_changeset(%TravelerDetail{}, phase2_attrs)
      refute changeset.valid?
      assert %{nationality: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "phase3_changeset/2" do
    test "phase3_changeset with valid phase 3 attributes" do
      phase3_attrs = %{
        mahram_info: "Traveling with husband",
        special_needs_requests: "Vegetarian meals"
      }

      changeset = TravelerDetail.phase3_changeset(%TravelerDetail{}, phase3_attrs)
      assert changeset.valid?
    end

    test "phase3_changeset with empty attributes" do
      phase3_attrs = %{
        mahram_info: "",
        special_needs_requests: ""
      }

      changeset = TravelerDetail.phase3_changeset(%TravelerDetail{}, phase3_attrs)
      assert changeset.valid?
    end
  end
end
