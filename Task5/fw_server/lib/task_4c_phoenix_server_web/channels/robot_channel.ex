defmodule FWServerWeb.RobotChannel do
  use Phoenix.Channel

  def start_agents() do
    #Apparently some Agents exist and some don't when B calls this process
    #So seperate conditions for each seems best
    if Process.whereis(:start_store) == nil do
      {:ok, agent} = Agent.start_link(fn -> %{} end)
      Process.register(agent, :start_store)
    end

    if Process.whereis(:coords_store) == nil do
      {:ok, pid} = Agent.start_link(fn -> %{} end)
      Process.register(pid, :coords_store)
    end

    if Process.whereis(:previous_store_A) == nil do
      {:ok, pid_prev_a} = Agent.start_link(fn -> %{} end)
      Process.register(pid_prev_a, :previous_store_A)
    end

    if Process.whereis(:previous_store_B) == nil do
      {:ok, pid_prev_b} = Agent.start(fn -> %{} end)
      Process.register(pid_prev_b, :previous_store_B)
    end

    if Process.whereis(:goal_choice) == nil do
      #Only useful for dynamic goal changing
      #So not really implementing rn
      {:ok, pid_choice} = Agent.start_link(fn -> %{} end)
      Process.register(pid_choice, :goal_choice)
    end

    if Process.whereis(:turns) == nil do
      {:ok, pid_turns} = Agent.start_link(fn -> %{} end)
      Process.register(pid_turns, :turns)
      Agent.update(:turns, fn map -> Map.put(map, :A, true) end)
      Agent.update(:turns, fn map -> Map.put(map, :B, false) end)

    end

    if Process.whereis(:goal_store) == nil do
      {:ok, pid_goal} = Agent.start_link(fn -> [] end)
      Process.register(pid_goal, :goal_store)
    end

    if Process.whereis(:stopped) == nil do
      {:ok, pid_stopped} = Agent.start_link(fn -> %{"A" => false, "B" => false} end)
      Process.register(pid_stopped, :stopped)
    end

  end

  @doc """
  Handler function for any Client joining the channel with topic "robot:status".
  Subscribe to the topic named "robot:update" on the Phoenix Server using Endpoint.
  Reply or Acknowledge with socket PID received from the Client.
  """
  def join("robot:status", _params, socket) do
    FWServerWeb.Endpoint.subscribe("robot:update")
    :ok = Phoenix.PubSub.subscribe(Task4CPhoenixServer.PubSub, "start")

    #Agents to store the info supplied by clients which is used for robot communication
    start_agents()

    FWServerWeb.Endpoint.subscribe("timer:update")
    socket = assign(socket, :timer_tick, 180)

    {:ok, socket}
  end

  @doc """
  Callback function for messages that are pushed to the channel with "robot:status" topic with an event named "new_msg".
  Receive the message from the Client, parse it to create another Map strictly of this format:
  %{"client" => < "robot_A" or "robot_B" >,  "left" => < left_value >, "bottom" => < bottom_value >, "face" => < face_value > }

  These values should be pixel locations for the robot's image to be displayed on the Dashboard
  corresponding to the various actions of the robot as recevied from the Client.

  Broadcast the created Map of pixel locations, so that the ArenaLive module can update
  the robot's image and location on the Dashboard as soon as it receives the new data.

  Based on the message from the Client, determine the obstacle's presence in front of the robot
  and return the boolean value in this format {:ok, < true OR false >}.

  If an obstacle is present ahead of the robot, then broadcast the pixel location of the obstacle to be displayed on the Dashboard.
  """
  @robot_map_y_string_to_num %{"a" => 1, "b" => 2, "c" => 3, "d" => 4, "e" => 5, "f" => 6}
  #Map format from now on
  # %{"event_id" => <integer>, "sender" => <"A" OR "B" OR "Server">, "value" => <data_required_by_server>, ...}
  def handle_in("new_msg", message, socket) do

    # decodes the message
    x = message["x"]
    y = message["y"]
    facing = message["face"]
    client = message["client"] #robot_A or robot_B
    # goals = Agent.get(:goal_store, fn list -> list end)
    # pixel values and facing
    y = @robot_map_y_string_to_num[y] #converts y's string to a number
    left_value = 150 * (x - 1)
    bottom_value = 150 * (y - 1)
    face_value = facing

    # creates a map for the output message
    msg_map = %{"client" => client,"left" => left_value, "bottom" => bottom_value,"face" => face_value}

    Phoenix.PubSub.broadcast!(Task4CPhoenixServer.PubSub, "view:update", {"update", msg_map})

    # determine the obstacle's presence in front of the robot and return the boolean value
    is_obs_ahead = FWServerWeb.FindObstaclePresence.is_obstacle_ahead?(message["x"], message["y"], message["face"])

    # file object to write each action taken by each Robot (A as well as B)
    {:ok, out_file} = File.open("task_4c_output.txt", [:append])
    # write the robot actions to a text file
    IO.binwrite(out_file, "#{message["client"]} => #{message["x"]}, #{message["y"]}, #{message["face"]}\n")

    ############################
    ## complete this function ##
    ############################
    # if is_obs_ahead do
    #   {left, bottom} = get_obs_pixels(left_value, bottom_value, facing)
    #   msg_obs = %{"position" => {left, bottom}}
    #   Phoenix.PubSub.broadcast!(Task4CPhoenixServer.PubSub, "view:update", {"update_obs", msg_obs})
    # end

    {:reply, {:ok, is_obs_ahead}, socket}
  end

  def handle_info(%{event: "update_timer_tick", payload: timer_data, topic: "timer:update"}, socket) do
    socket = assign(socket, :timer_tick, timer_data.time)
    {:noreply, socket}
  end

  def handle_in("event_msg", message = %{"event_id" => 2, "sender" => sender, "value" => value}, socket) do
    message = Map.put(message, "timer", socket.assigns[:timer_tick])
    x = value["x"]
    y = value["y"]
    facing = value["face"]
    y = @robot_map_y_string_to_num[y] #converts y's string to a number
    left_value = 150 * (x - 1)
    bottom_value = 150 * (y - 1)
    {left, bottom} = get_obs_pixels(left_value, bottom_value, facing)
    msg_obs = %{"position" => {left, bottom}}
    Phoenix.PubSub.broadcast!(Task4CPhoenixServer.PubSub, "view:update", {"update_obs", msg_obs})

    FWServerWeb.Endpoint.broadcast_from(self(), "robot:status", "event_msg", message)
    {:reply, {:ok, true}, socket}
  end

  def handle_in("event_msg", message = %{"event_id" => 3, "sender" => sender, "value" => value}, socket) do
    message = Map.put(message, "timer", socket.assigns[:timer_tick])
    {x,y} = convert_goal_to_locations(value)
    left_value = 150 * (x - 1)
    bottom_value = 150 * (y - 1)
    msg_map = %{"left" => left_value, "bottom" => bottom_value, "plant" => value}
    Phoenix.PubSub.broadcast!(Task4CPhoenixServer.PubSub, "view:update", {"gray_out", msg_map})

    {:reply, {:ok, true}, socket}
  end

  def handle_in("event_msg", message = %{"event_id" => 4, "sender" => sender, "value" => value}, socket) do
    message = Map.put(message, "timer", socket.assigns[:timer_tick])
    {x,y} = convert_goal_to_locations(value)
    left_value = 150 * (x - 1)
    bottom_value = 150 * (y - 1)
    msg_map = %{"left" => left_value, "bottom" => bottom_value, "plant" => value}
    Phoenix.PubSub.broadcast!(Task4CPhoenixServer.PubSub, "view:update", {"gray_out", msg_map})

    {:reply, {:ok, true}, socket}
  end

  def convert_goal_to_locations(loc) do
    loc = if is_bitstring(loc), do: String.to_integer(loc), else: loc
    no =  loc - 1
    x = rem(no, 5) + 1
    y = Integer.floor_div(no, 5) + 1

    bl = {x, y} # Bottom left
  end

  def handle_in("event_msg", message, socket) do
    message = Map.put(message, "timer", socket.assigns[:timer_tick])
    IO.inspect(message)
    FWServerWeb.Endpoint.broadcast_from(self(), "robot:status", "event_msg", message)
    {:reply, {:ok, true}, socket}
  end

  def get_obs_pixels(left_value, bottom_value, facing) do
    bottom_value = if facing == "north" do
      bottom_value = bottom_value + 75
    else
      bottom_value
    end

    bottom_value = if facing == "south" do
      bottom_value = bottom_value - 75
    else
      bottom_value
    end

    left_value = if facing == "east" do
      left_value = left_value + 75
    else
      left_value
    end

    left_value = if facing == "west" do
      left_value = left_value - 75
    else
      left_value
    end

    {left_value, bottom_value}
  end

  #########################################
  ## define callback functions as needed ##
  #########################################

  def handle_in("goals_msg", message, socket) do
    csv = "../../../Plant_Positions.csv" |> Path.expand(__DIR__) |> File.stream! |> CSV.decode |> Enum.take_every(1)
    |> Enum.filter(fn {:ok, [a, b]} -> (a != "Sowing") end)
    |> Enum.map(fn {:ok, [a, b]} -> [a, b] end)
    |> Enum.reduce(fn [a, b], acc -> acc ++ [a, b] end )

    seeding = csv |> Enum.with_index |> Enum.map(fn {x, i} -> if rem(i, 2) == 0 do x end end)
      |> Enum.reject(fn x -> x == nil end)# 0, 2, 4
    weeding = csv |> Enum.with_index |> Enum.map(fn {x, i} -> if rem(i, 2) == 1 do x end end)
      |> Enum.reject(fn x -> x == nil end)# 1, 3, 5

    if message["sender"] == "A" do
      {:reply, {:ok, weeding}, socket}
    else
      {:reply, {:ok, seeding}, socket}
    end
  end

  def handle_in("start_msg", message, socket) do

    msg = Agent.get(:start_store, fn map -> map end)

    #Split strings into lists
    start_A = if Map.get(msg, :A) != nil, do: String.split(Map.get(msg, :A), ","), else: nil
    start_B = if Map.get(msg, :B) != nil, do: String.split(Map.get(msg, :B), ","), else: nil

    msg = %{A: start_A, B: start_B}

    {:reply, {:ok, msg}, socket}
  end

  #########
  ## GET ##
  #########

  def handle_in("coords_store_get", message, socket) do
    IO.inspect(message, label: "Co-ords Store Get message")

    if message["A"] == "A" do
      res = Agent.get(:coords_store, fn map -> Map.get(map, :A) end)
      {x, y, facing} = if res != nil, do: res, else: {1, "a", "north"}
      message = %{x: x, y: y, face: facing}
      {:reply, {:ok, message}, socket}
    else
      res = Agent.get(:coords_store, fn map -> Map.get(map, :B) end)
      {x, y, facing} = if res != nil, do: res, else: {6, "e", "south"}
      message = %{x: x, y: y, face: facing}
      {:reply, {:ok, message}, socket}
    end

  end

  def handle_in("previous_store_get", message, socket) do
    IO.inspect(message, label: "Previous Store Get message")
    if message["A"] == "A" do
      res = Agent.get(:previous_store_A, fn map -> Map.get(map, :prev) end)
      {x, y, facing} = if res != nil, do: res, else: {1, "a", "north"}
      message = %{x: x, y: y, face: facing}
      {:reply, {:ok, message}, socket}
    else
      res = Agent.get(:previous_store_B, fn map -> Map.get(map, :prev) end)
      {x, y, facing} = if res != nil, do: res, else: {6, "f", "south"}
      message = %{x: x, y: y, face: facing}
      {:reply, {:ok, message}, socket}
    end
  end

  def handle_in("goal_choice_get", message, socket) do
    IO.inspect(message, label: "Goal Choice Get message")
    msg = if message["A"] != nil do
      Agent.get(:goal_choice, fn map -> Map.get(map, :A) end)
    else
      Agent.get(:goal_choice, fn map -> Map.get(map, :B) end)
    end
    {:reply, {:ok, msg}, socket}
  end

  def handle_in("turns_get", message, socket) do
    t_a = Agent.get(:turns, fn map -> Map.get(map, :A) end)
    t_b = Agent.get(:turns, fn map -> Map.get(map, :B) end)
    msg = %{"A" => t_a, "B" => t_b}
    {:reply, {:ok, msg}, socket}
  end

  def handle_in("goal_store_get", message, socket) do
    list_goal = Agent.get(:goal_store, fn list -> list end)
    {:reply, {:ok, %{list: list_goal}}, socket}
  end

  def handle_in("stopped_get", message, socket) do
    status = if Process.whereis(:stopped) != nil do
      Agent.get(:stopped, fn map -> map end)
    else
      %{"A" => false, "B" => false}
    end
    {:reply, {:ok, status}, socket}
  end

  ############
  ## UPDATE ##
  ############

  def handle_in("coords_store_update", message, socket) do
    x = message["x"]
    y = message["y"]
    facing = message["face"]
    IO.inspect(message, label: "Co-ords Update Message")
    if message["client"] == "robot_A" do
      Agent.update(:coords_store, fn map -> Map.put(map, :A, {x, y, facing}) end)
    else
      Agent.update(:coords_store, fn map -> Map.put(map, :B, {x, y, facing}) end)
    end
    {:reply, :ok, socket}
  end

  def handle_in("previous_store_update", message, socket) do
    x = message["x"]
    y = message["y"]
    facing = message["face"]
    IO.inspect(message, label: "Previous Update Message")
    if message["client"] == "robot_A" do
      Agent.update(:previous_store_A, fn map -> Map.put(map, :prev, {x, y, facing}) end)
    else
      Agent.update(:previous_store_B, fn map -> Map.put(map, :prev, {x, y, facing}) end)
    end
    {:reply, :ok, socket}
  end

  def handle_in("goal_choice_update", message, socket) do
    x = message["x"]
    y = message["y"]
    facing = message["face"]
    IO.inspect(message, label: "Previous Update Message")
    if message["client"] == "robot_A" do
      Agent.update(:goal_choice, fn map -> Map.put(map, :A, {x, y, facing}) end)
    else
      Agent.update(:goal_choice, fn map -> Map.put(map, :B, {x, y, facing}) end)
    end
    {:reply, :ok, socket}
  end

  def handle_in("turns_update", message, socket) do
    IO.inspect(message, label: "Received data for turns update")

    if message["A"] == true do
      Agent.update(:turns, fn map -> Map.put(map, :A, true) end)
    end
    if message["A"] == false do
      Agent.update(:turns, fn map -> Map.put(map, :A, false) end)
    end

    if message["B"] == true do
      Agent.update(:turns, fn map -> Map.put(map, :B, true) end)
    end
    if message["B"] == false do
      Agent.update(:turns, fn map -> Map.put(map, :B, false) end)
    end

    {:reply, :ok, socket}
  end

  def handle_in("goal_store_update", message, socket) do
    IO.inspect(message["list"], label: "Received data for goal store")
    Agent.update(:goal_store, fn list -> list ++ message["list"] end)
    {:reply, :ok, socket}
  end



  ############
  ## DELETE ##
  ############
  def handle_in("goal_store_delete", message, socket) do
    # IO.inspect(message["list"], label: "Received data for goal store")
    Agent.update(:goal_store, &List.delete(&1, message["key"]))
    {:reply, :ok, socket}
  end

  def handle_info({"start", data}, socket) do

    #IO.inspect(data, label: "Data is sent to Channel PubSub")
    Agent.update(:start_store, fn map -> data end)
    ###########################
    ## complete this funcion ##
    ###########################

    {:noreply, socket}

  end

  def handle_info({"stop_event", data}, socket) do

    #IO.inspect(data, label: "Data is sent to Channel PubSub")
    msg = %{"event_id" => 6, "sender" => "Server", "value" => data}
    broadcast!(socket, "event_msg", msg)
    ###########################
    ## complete this funcion ##
    ###########################

    {:noreply, socket}

  end

  def handle_info({"stop_robot", data}, socket) do
    IO.inspect(data["robot"], label: "Stopped")
    Agent.update(:stopped, fn map -> Map.put(map, data["robot"], true) end)
    {:noreply, socket}
  end

  def handle_info({"start_robot", data}, socket) do
    IO.inspect(data["robot"], label: "Start")
    Agent.update(:stopped, fn map -> Map.put(map, data["robot"], false) end)
    {:noreply, socket}
  end

end
