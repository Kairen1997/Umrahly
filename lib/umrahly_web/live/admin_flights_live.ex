defmodule UmrahlyWeb.AdminFlightsLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.AdminLayout
  alias Umrahly.Flights
  alias Umrahly.Flights.Flight


  def mount(_params, _session, socket) do
    flights = Flights.list_flights()
    changeset = Flights.change_flight(%Flight{})

    socket =
      socket
      |> assign(:flights, flights)
      |> assign(:current_page, "flights")
      |> assign(:has_profile, true)
      |> assign(:is_admin, true)
      |> assign(:profile, socket.assigns.current_user)
      |> assign(:show_new_flight_form, false)
      |> assign(:form, to_form(changeset))
      |> assign(:selected_flight, nil)
      |> assign(:show_view_flight_modal, false)
    {:ok, socket}
  end

  def handle_event("show_new_flight_form", _, socket) do
    {:noreply, assign(socket, :show_new_flight_form, true)}
  end

  def handle_event("hide_new_flight_form", _, socket) do
    {:noreply, assign(socket, :show_new_flight_form, false)}
  end

  def handle_event("save_flight", %{"flight" => flight_params}, socket) do
    case socket.assigns[:editing_flight_id] do
      nil ->
    flight_params = Map.put(flight_params, "capacity_booked", 0)

    case Flights.create_flight(flight_params) do
      {:ok, flight} ->
        {:noreply,
          socket
          |> update(:flights, fn flights -> [flight | flights] end)
          |> assign(:show_new_flight_form, false)
          |> put_flash(:info, "Flight created successfully")
        }

      {:error, changeset} ->
        {:noreply,
        socket
        |> assign(:form, to_form(changeset))
        |> put_flash(:error, "Failed to create flight. Please check the form and try again.")
        }
    end
    id ->
      flight = Flights.get_flight!(id)

      case Flights.update_flight(flight, flight_params) do
        {:ok, updated_flight} ->
          {:noreply,
            socket
            |> update(:flights, fn flights ->
              Enum.map(flights, fn f -> if f.id == updated_flight.id, do: updated_flight, else: f end)
            end)
            |> assign(:show_new_flight_form, false)
            |> assign(:editing_flight_id, nil)
            |> put_flash(:info, "Flight updated successfully")}

        {:error, changeset} ->
          {:noreply,
            socket
            |> assign(:form, to_form(changeset))
            |> put_flash(:error, "Failed to update flight.")}
      end
  end
  end

  def handle_event("validate", %{"flight" => flight_params}, socket) do
    changeset =
      %Flight{}
      |> Flights.change_flight(flight_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  # View Flight
  def handle_event("view_flight", %{"id" => id}, socket) do
    flight = Flights.get_flight!(id)

    {:noreply,
      socket
      |> assign(:selected_flight, flight)
      |> assign(:show_view_flight_modal, true)}
  end

  def handle_event("close_view_flight_modal", _, socket) do
    {:noreply,
      socket
      |> assign(:show_view_flight_modal, false)
      |> assign(:selected_flight, nil)}
  end


# Edit Flight
def handle_event("edit_flight", %{"id" => id}, socket) do
  flight = Flights.get_flight!(id)
  changeset = Flights.change_flight(flight)

  {:noreply,
    socket
    |> assign(:form, to_form(changeset))
    |> assign(:show_new_flight_form, true) # reuse the modal
    |> assign(:editing_flight_id, flight.id)}
end

# Delete Flight
def handle_event("delete_flight", %{"id" => id}, socket) do
  flight = Flights.get_flight!(id)
  {:ok, _} = Flights.delete_flight(flight)

  {:noreply,
    socket
    |> update(:flights, fn flights -> Enum.reject(flights, &(&1.id == flight.id)) end)
    |> put_flash(:info, "Flight deleted successfully")}
end



  def render(assigns) do
    ~H"""
    <.admin_layout current_page={@current_page} has_profile={@has_profile} current_user={@current_user} profile={@profile} is_admin={@is_admin}>
      <div class="max-w-6xl mx-auto">
        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-center justify-between mb-6">
            <h1 class="text-2xl font-bold text-gray-900">Flights Management</h1>
            <button type="button" phx-click="show_new_flight_form" class="bg-teal-600 text-white px-4 py-2 rounded-lg hover:bg-teal-700 transition-colors">
              Add New Flight
            </button>
          </div>

          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Flight Number</th>
                  <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Route</th>
                  <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Departure</th>
                  <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Arrival</th>
                  <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Aircraft</th>
                  <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Return Date</th>
                  <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Capacity</th>
                  <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                  <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <%= for flight <- @flights do %>
                  <tr class="hover:bg-gray-50">
                    <td class="px-3 py-3 whitespace-nowrap text-sm font-medium text-gray-900"><%= flight.flight_number %></td>
                    <td class="px-3 py-3 whitespace-nowrap">
                      <div class="text-sm text-gray-900">
                        <div><%= flight.origin %></div>
                        <div class="text-gray-500">→</div>
                        <div><%= flight.destination %></div>
                      </div>
                    </td>
                    <td class="px-3 py-3 whitespace-nowrap text-sm text-gray-900">
                      <%= Calendar.strftime(flight.departure_time, "%Y-%m-%d %H:%M") %>
                    </td>
                    <td class="px-3 py-3 whitespace-nowrap text-sm text-gray-900">
                      <%= Calendar.strftime(flight.arrival_time, "%Y-%m-%d %H:%M") %>
                    </td>

                    <td class="px-3 py-3 whitespace-nowrap text-sm text-gray-900"><%= flight.aircraft %></td>
                    <td class="px-3 py-3 whitespace-nowrap text-sm text-gray-900">
                      <%= if flight.return_date do %>
                        <%= Calendar.strftime(flight.return_date, "%Y-%m-%d %H:%M") %>
                      <% else %>
                        <span class="text-gray-500">N/A</span>
                      <% end %>
                    </td>
                    <td class="px-3 py-3 whitespace-nowrap text-sm text-gray-900">
                      <div class="flex items-center">
                        <span class="mr-2"><%= flight.capacity_booked %>/<%= flight.capacity_total %></span>
                        <div class="w-16 bg-gray-200 rounded-full h-2">
                          <div class="bg-teal-600 h-2 rounded-full" style={"width: #{flight.capacity_booked / flight.capacity_total * 100}%"}>
                          </div>
                        </div>
                      </div>
                    </td>
                    <td class="px-3 py-3 whitespace-nowrap">
                      <span class={[
                        "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                        case flight.status do
                          "Scheduled" -> "bg-green-100 text-green-800"
                          "Delayed" -> "bg-yellow-100 text-yellow-800"
                          "Cancelled" -> "bg-red-100 text-red-800"
                          "Boarding" -> "bg-blue-100 text-blue-800"
                          _ -> "bg-gray-100 text-gray-800"
                        end
                      ]}>
                        <%= flight.status %>
                      </span>
                    </td>
                    <td class="px-3 py-3 whitespace-nowrap text-sm font-medium">
                      <button phx-click="view_flight" phx-value-id={flight.id}
                              class="text-blue-600 hover:text-blue-900 mr-3">
                        View
                      </button>
                      <button phx-click="edit_flight" phx-value-id={flight.id}
                              class="text-teal-600 hover:text-teal-900 mr-3">
                        Edit
                      </button>
                      <button phx-click="delete_flight" phx-value-id={flight.id}
                              data-confirm="Are you sure?"
                              class="text-red-600 hover:text-red-900">
                        Delete
                      </button>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
          <%= if @show_new_flight_form do %>
            <div class="fixed inset-0 flex items-center justify-center bg-black bg-opacity-50 z-50">
              <div class="bg-white rounded-2xl shadow-2xl w-full max-w-3xl p-6">

                <!-- Header -->
                <div class="flex items-center justify-between border-b pb-3 mb-4">
                  <h2 class="text-xl font-semibold text-gray-800">Add New Flight</h2>
                  <button type="button" phx-click="hide_new_flight_form"
                          class="text-gray-500 hover:text-gray-700">
                    ✕
                  </button>
                </div>

                <!-- Form -->
                <.simple_form for={@form} phx-submit="save_flight" class="space-y-6">

                  <!-- Flight Info -->
                  <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <.input field={@form[:flight_number]} label="Flight Number" />
                    <.input field={@form[:aircraft]} label="Aircraft" />
                  </div>

                  <!-- Route -->
                  <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <.input field={@form[:origin]} label="Origin" />
                    <.input field={@form[:destination]} label="Destination" />
                  </div>

                  <!-- Schedule -->
                  <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <.input field={@form[:departure_time]} type="datetime-local" label="Departure Time" />
                    <.input field={@form[:arrival_time]} type="datetime-local" label="Arrival Time" />
                    <.input field={@form[:return_date]} type="datetime-local" label="Return Date" />
                  </div>

                  <!-- Capacity & Status -->
                  <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <.input field={@form[:capacity_total]} type="number" label="Total Capacity" />
                    <.input field={@form[:status]} type="select"
                            options={["Scheduled", "Boarding", "Delayed", "Cancelled"]}
                            label="Status" />
                  </div>

                  <!-- Actions -->
                  <div class="flex justify-end space-x-3 pt-4 border-t">
                    <.button type="button" phx-click="hide_new_flight_form"
                            class="bg-teal-100 text-teal-700 hover:bg-teal-200 rounded-lg px-4 py-2">
                      Cancel
                    </.button>
                    <.button phx-submit="save_flight" class="bg-teal-600 text-white hover:bg-teal-700 rounded-lg px-4 py-2">
                      Save Flight
                    </.button>
                  </div>
                </.simple_form>
              </div>
            </div>
          <% end %>
          <%= if @show_view_flight_modal && @selected_flight do %>
          <div class="fixed inset-0 flex items-center justify-center bg-black bg-opacity-50 z-50">
            <div class="bg-white rounded-2xl shadow-2xl w-full max-w-2xl p-6">

              <!-- Header -->
              <div class="flex items-center justify-between border-b pb-3 mb-4">
                <h2 class="text-xl font-semibold text-gray-800">
                  Flight Details
                </h2>
                <button type="button" phx-click="close_view_flight_modal"
                        class="text-gray-500 hover:text-gray-700">
                  ✕
                </button>
              </div>

              <!-- Flight Details -->
              <div class="space-y-4 text-sm text-gray-700">
                <div class="grid grid-cols-2 gap-4">
                  <div>
                    <p class="font-medium">Flight Number:</p>
                    <p><%= @selected_flight.flight_number %></p>
                  </div>
                  <div>
                    <p class="font-medium">Aircraft:</p>
                    <p><%= @selected_flight.aircraft %></p>
                  </div>
                  <div>
                    <p class="font-medium">Origin:</p>
                    <p><%= @selected_flight.origin %></p>
                  </div>
                  <div>
                    <p class="font-medium">Destination:</p>
                    <p><%= @selected_flight.destination %></p>
                  </div>
                  <div>
                    <p class="font-medium">Departure:</p>
                    <p><%= Calendar.strftime(@selected_flight.departure_time, "%Y-%m-%d %H:%M") %></p>
                  </div>
                  <div>
                    <p class="font-medium">Arrival:</p>
                    <p><%= Calendar.strftime(@selected_flight.arrival_time, "%Y-%m-%d %H:%M") %></p>
                  </div>
                  <div>
                    <p class="font-medium">Capacity:</p>
                    <p><%= @selected_flight.capacity_booked %> / <%= @selected_flight.capacity_total %></p>
                  </div>
                  <div>
                    <p class="font-medium">Status:</p>
                    <span class={[
                      "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                      case @selected_flight.status do
                        "Scheduled" -> "bg-green-100 text-green-800"
                        "Delayed" -> "bg-yellow-100 text-yellow-800"
                        "Cancelled" -> "bg-red-100 text-red-800"
                        "Boarding" -> "bg-blue-100 text-blue-800"
                        _ -> "bg-gray-100 text-gray-800"
                      end
                    ]}>
                      <%= @selected_flight.status %>
                    </span>
                  </div>
                  <div>
                    <p class="font-medium">Return Date:</p>
                    <p><%= if @selected_flight.return_date do %>
                      <%= Calendar.strftime(@selected_flight.return_date, "%Y-%m-%d %H:%M") %>
                    <% else %>
                      <span class="text-gray-500">N/A</span>
                    <% end %></p>
                  </div>
                </div>
              </div>

              <!-- Footer -->
              <div class="flex justify-end mt-6">
                <button type="button" phx-click="close_view_flight_modal"
                        class="bg-teal-600 text-white px-4 py-2 rounded-lg hover:bg-teal-700">
                  Close
                </button>
              </div>
            </div>
          </div>
        <% end %>

        </div>
      </div>
    </.admin_layout>
    """
  end
end
