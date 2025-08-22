defmodule UmrahlyWeb.UserPackageDetailsLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.SidebarComponent
  alias Umrahly.Packages

  def mount(%{"id" => package_id}, _session, socket) do
    package = Packages.get_package_with_schedules!(package_id)

    # Only show active packages to users
    if package.status != "active" do
      {:ok, push_navigate(socket, to: ~p"/packages")}
    else
      socket =
        socket
        |> assign(:package, package)
        |> assign(:current_page, "packages")
        |> assign(:page_title, package.name)

      {:ok, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <.sidebar page_title={@page_title}>
      <div class="max-w-4xl mx-auto space-y-8">
        <!-- Back Button -->
        <div class="flex items-center">
          <a
            href="/packages"
            class="inline-flex items-center px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 transition-colors"
          >
            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
            Back to Packages
          </a>
        </div>

        <!-- Package Header -->
        <div class="bg-white rounded-lg shadow-lg overflow-hidden">
          <!-- Package Image -->
          <div class="h-96 bg-gray-200 relative">
            <%= if @package.picture do %>
              <img
                src={@package.picture}
                alt={"#{@package.name} picture"}
                class="w-full h-full object-cover"
              />
            <% else %>
              <div class="w-full h-full flex items-center justify-center">
                <svg class="w-32 h-32 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 002 2v12a2 2 0 002 2z" />
                </svg>
              </div>
            <% end %>

            <!-- Status Badge -->
            <div class="absolute top-4 right-4">
              <span class="inline-flex px-3 py-1 text-sm font-semibold rounded-full bg-green-100 text-green-800">
                <%= @package.status %>
              </span>
            </div>
          </div>

          <!-- Package Info -->
          <div class="p-8">
            <div class="flex flex-col lg:flex-row lg:items-start lg:justify-between">
              <div class="flex-1">
                <h1 class="text-3xl font-bold text-gray-900 mb-4"><%= @package.name %></h1>

                <%= if @package.description && @package.description != "" do %>
                  <p class="text-lg text-gray-600 mb-6 leading-relaxed"><%= @package.description %></p>
                <% end %>

                <!-- Key Details Grid -->
                <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
                  <div class="text-center">
                    <div class="text-3xl font-bold text-blue-600">RM <%= @package.price %></div>
                    <div class="text-sm text-gray-500">Total Price</div>
                  </div>
                  <div class="text-center">
                    <div class="text-3xl font-bold text-gray-900"><%= @package.duration_days %></div>
                    <div class="text-sm text-gray-500">Days</div>
                  </div>
                  <div class="text-center">
                    <div class="text-3xl font-bold text-gray-900"><%= @package.duration_nights %></div>
                    <div class="text-sm text-gray-500">Nights</div>
                  </div>
                  <div class="text-center">
                    <div class="text-3xl font-bold text-green-600">
                      <%= length(@package.package_schedules) %>
                    </div>
                    <div class="text-sm text-gray-500">Available Schedules</div>
                  </div>
                </div>
              </div>

              <!-- Action Buttons -->
              <div class="lg:ml-8 mt-6 lg:mt-0">
                <div class="space-y-3">
                  <button class="w-full bg-blue-600 text-white px-6 py-3 rounded-lg hover:bg-blue-700 transition-colors font-medium text-lg">
                    Book Now
                  </button>
                  <button class="w-full bg-gray-100 text-gray-700 px-6 py-3 rounded-lg hover:bg-gray-200 transition-colors font-medium">
                    Download Brochure
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Package Details Grid -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <!-- Accommodation Details -->
          <div class="bg-white rounded-lg shadow-lg p-6">
            <h3 class="text-xl font-semibold text-gray-900 mb-4 flex items-center">
              <svg class="w-6 h-6 mr-2 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
              </svg>
              Accommodation
            </h3>
            <%= if @package.accommodation_type && @package.accommodation_type != "" do %>
              <div class="space-y-3">
                <div>
                  <span class="font-medium text-gray-900">Type:</span>
                  <span class="ml-2 text-gray-600"><%= @package.accommodation_type %></span>
                </div>
                <%= if @package.accommodation_details && @package.accommodation_details != "" do %>
                  <div>
                    <span class="font-medium text-gray-900">Details:</span>
                    <p class="mt-1 text-gray-600"><%= @package.accommodation_details %></p>
                  </div>
                <% end %>
              </div>
            <% else %>
              <p class="text-gray-500">Accommodation details not available</p>
            <% end %>
          </div>

          <!-- Transport Details -->
          <div class="bg-white rounded-lg shadow-lg p-6">
            <h3 class="text-xl font-semibold text-gray-900 mb-4 flex items-center">
              <svg class="w-6 h-6 mr-2 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
              </svg>
              Transportation
            </h3>
            <%= if @package.transport_type && @package.transport_type != "" do %>
              <div class="space-y-3">
                <div>
                  <span class="font-medium text-gray-900">Type:</span>
                  <span class="ml-2 text-gray-600"><%= @package.transport_type %></span>
                </div>
                <%= if @package.transport_details && @package.transport_details != "" do %>
                  <div>
                    <span class="font-medium text-gray-900">Details:</span>
                    <p class="mt-1 text-gray-600"><%= @package.transport_details %></p>
                  </div>
                <% end %>
              </div>
            <% else %>
              <p class="text-gray-500">Transportation details not available</p>
            <% end %>
          </div>
        </div>

        <!-- Available Schedules -->
        <%= if length(@package.package_schedules) > 0 do %>
          <div class="bg-white rounded-lg shadow-lg p-6">
            <h3 class="text-xl font-semibold text-gray-900 mb-6 flex items-center">
              <svg class="w-6 h-6 mr-2 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
              </svg>
              Available Departure Dates
            </h3>

            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              <%= for schedule <- @package.package_schedules do %>
                <div class="border border-gray-200 rounded-lg p-4 hover:border-blue-300 transition-colors">
                  <div class="text-center">
                    <div class="text-lg font-semibold text-gray-900">
                      <%= Calendar.strftime(schedule.departure_date, "%B %d, %Y") %>
                    </div>
                    <div class="text-sm text-gray-500 mt-1">
                      <%= Calendar.strftime(schedule.departure_date, "%A") %>
                    </div>
                    <div class="mt-3">
                      <span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-blue-100 text-blue-800">
                        Quota: <%= schedule.quota %>
                      </span>
                    </div>
                    <button class="mt-3 w-full bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 transition-colors text-sm font-medium">
                      Select This Date
                    </button>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- Itinerary Preview -->
        <%= if length(@package.itineraries) > 0 do %>
          <div class="bg-white rounded-lg shadow-lg p-6">
            <h3 class="text-xl font-semibold text-gray-900 mb-6 flex items-center">
              <svg class="w-6 h-6 mr-2 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
              </svg>
              Itinerary Preview
            </h3>

            <div class="space-y-4">
              <%= for itinerary <- Enum.take(@package.itineraries, 3) do %>
                <div class="border-l-4 border-blue-500 pl-4">
                  <div class="flex items-start">
                    <div class="flex-shrink-0 w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center mr-3">
                      <span class="text-sm font-semibold text-blue-600">Day <%= itinerary.day_number %></span>
                    </div>
                    <div class="flex-1">
                      <h4 class="font-medium text-gray-900"><%= itinerary.title %></h4>
                      <%= if itinerary.description && itinerary.description != "" do %>
                        <p class="text-sm text-gray-600 mt-1"><%= itinerary.description %></p>
                      <% end %>
                    </div>
                  </div>
                </div>
              <% end %>

              <%= if length(@package.itineraries) > 3 do %>
                <div class="text-center pt-4">
                  <p class="text-sm text-gray-500">
                    +<%= length(@package.itineraries) - 3 %> more days in the full itinerary
                  </p>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- Call to Action -->
        <div class="bg-gradient-to-r from-blue-600 to-purple-600 rounded-lg shadow-lg p-8 text-center text-white">
          <h3 class="text-2xl font-bold mb-4">Ready to Book Your Umrah Journey?</h3>
          <p class="text-lg mb-6 opacity-90">
            Don't miss out on this amazing opportunity. Book now and secure your spot!
          </p>
          <div class="flex flex-col sm:flex-row gap-4 justify-center">
            <button class="bg-white text-blue-600 px-8 py-3 rounded-lg font-semibold hover:bg-gray-100 transition-colors">
              Book This Package
            </button>
            <button class="border-2 border-white text-white px-8 py-3 rounded-lg font-semibold hover:bg-white hover:text-blue-600 transition-colors">
              Contact Us
            </button>
          </div>
        </div>
      </div>
    </.sidebar>
    """
  end
end
