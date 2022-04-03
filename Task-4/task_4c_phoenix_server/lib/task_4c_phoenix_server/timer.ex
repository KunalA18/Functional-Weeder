defmodule Task4CPhoenixServer.Timer do
  use GenServer
  require Logger

  def start_link(args) do
    GenServer.start_link __MODULE__, args
  end

  def init(_state) do
    Task4CPhoenixServerWeb.Endpoint.subscribe "timer:start", []
    Task4CPhoenixServerWeb.Endpoint.subscribe "timer:stop", []
    state = %{timer_ref: nil, timer: nil}
    {:ok, state}
  end

  def handle_info(:update, %{timer: 0}) do
    broadcast 0, "TIMEEEE"
    {:noreply, %{timer_ref: nil, timer: 0}}
  end

  def handle_info(:update, %{timer: time}) do
    leftover = time - 1
    broadcast leftover, "tick tock... tick tock"
    timer_ref = schedule_timer 1_000
    {:noreply, %{timer_ref: timer_ref, timer: leftover}}
  end

  def handle_info(%{event: "start_timer"}, %{timer_ref: old_timer_ref}) do
    cancel_timer(old_timer_ref)
    duration = 300
    timer_ref = schedule_timer 1_000
    broadcast duration, "Started timer!"
    {:noreply, %{timer_ref: timer_ref, timer: duration}}
  end

  def handle_info(%{event: "stop_timer"}, %{timer_ref: old_timer_ref}) do
    IO.inspect('stop timer...')
    cancel_timer(old_timer_ref)
    {:noreply, %{timer_ref: nil, timer: 0}}
  end

  defp cancel_timer(nil), do: :ok
  defp cancel_timer(ref), do: Process.cancel_timer(ref)

  defp schedule_timer(interval) do
    Process.send_after self(), :update, interval
  end

  defp broadcast(tick, response) do
    Task4CPhoenixServerWeb.Endpoint.broadcast! "timer:update", "update_timer_tick", %{
      response: response,
      time: tick,
    }
  end
end
