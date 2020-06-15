defmodule LittlechatWeb.Room.ShowLive do
  @moduledoc """
  A LiveView for creating and joining chat rooms.
  """

  use LittlechatWeb, :live_view

  alias Littlechat.Organizer
  alias Littlechat.ConnectedUser

  alias LittlechatWeb.Presence
  alias Phoenix.Socket.Broadcast

  @impl true
  def render(assigns) do
    ~L"""
    <script>window.roomSlug = "<%= @room.slug %>"</script>

    <h1><%= @room.title %></h1>

    <h3>Connected Users:</h3>
    <ul>
    <%= for uuid <- @connected_users do %>
      <li><%= uuid %></li>
    <% end %>
    </ul>

    <video id="local-video" playsinline autoplay muted width="500"></video>
    <video id="remote-video" playsinline autoplay muted width="500"></video>

    <button phx-click="join-call" phx-hook="Call">Join Call</button>
    <button phx-click="leave-call" <%= if !@in_call?, do: "disabled" %>>Hang Up</button>
    """
  end

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    # User presence tracking.
    user = create_connected_user()
    Phoenix.PubSub.subscribe(Littlechat.PubSub, "room:" <> slug)
    {:ok, _} = Presence.track(self(), "room:" <> slug, user.uuid, %{})

    # Subscribe the LiveView to video offers. See the handle_info/3 method below
    # for how this is handled.
    Phoenix.PubSub.subscribe(Littlechat.PubSub, "room:" <> slug <> ":video_offer")

    {:ok,
      socket
      |> assign(:slug, slug)
      |> assign(:user, create_connected_user())
      |> assign(:connected_users, [])
      |> assign(:in_call?, false)
      |> assign(:room, Organizer.get_room(slug))
    }
  end

  @impl true
  def handle_event("join-call", params, socket) do
    other_users = socket.assigns.connected_users |> List.delete(socket.assigns.user)

    {:noreply, assign(socket, :in_call?, true)}
  end

  def handle_event("video-offer", %{"sdp" => sdp}, socket) do
    # Send to others.

    {:noreply, socket}
  end

  @impl true
  def handle_event("leave-call", params, socket) do
    {:noreply, assign(socket, :in_call?, false)}
  end

  @impl true
  def handle_info(%Broadcast{event: "presence_diff"}, socket) do
    {:noreply,
      socket
      |> assign(:connected_users, list_present(socket))}
  end

  defp create_connected_user do
    %ConnectedUser{uuid: UUID.uuid4()}
  end

  defp list_present(socket) do
    Presence.list("room:" <> socket.assigns.slug)
    |> Enum.map(fn {k, _} -> k end)
  end
end
