defmodule FWClientRobotA.PhoenixSocketClient do

  alias PhoenixClient.{Socket, Channel, Message}

  @robot_map_y_atom_to_num %{:a => 1, :b => 2, :c => 3, :d => 4, :e => 5, :f => 6}

  @doc """
  Connect to the Phoenix Server URL (defined in config.exs) via socket.
  Once ensured that socket is connected, join the channel on the server with topic "robot:status".
  Get the channel's PID in return after joining it.

  NOTE:
  The socket will automatically attempt to connect when it starts.
  If the socket becomes disconnected, it will attempt to reconnect automatically.
  Please note that start_link is not synchronous,
  so you must wait for the socket to become connected before attempting to join a channel.
  Reference to above note: https://github.com/mobileoverlord/phoenix_client#usage

  You may refer: https://github.com/mobileoverlord/phoenix_client/issues/29#issuecomment-660518498
  """
  def connect_server do

    socket_opts = [url: Application.get_env(:task_4c_client_robota, :phoenix_server_url )]

    {:ok, socket} = PhoenixClient.Socket.start_link(socket_opts)

    wait_for_socket(socket)
    IO.inspect(socket, label: "Socket ")

    # joins the robot:status channel
    {:ok, _response, channel} = PhoenixClient.Channel.join(socket, "robot:status")

    {:ok, _response, channel}
  end

  def wait_for_socket(socket) do
    if !Socket.connected?(socket) do
      wait_for_socket(socket)
    end
  end

  @doc """
  Send Toy Robot's current status i.e. location (x, y) and facing
  to the channel's PID with topic "robot:status" on Phoenix Server with the event named "new_msg".

  The message to be sent should be a Map strictly of this format:
  %{"client": < "robot_A" or "robot_B" >,  "x": < x_coordinate >, "y": < y_coordinate >, "face": < facing_direction > }

  In return from Phoenix server, receive the boolean value < true OR false > indicating the obstacle's presence
  in this format: {:ok, < true OR false >}.
  Create a tuple of this format: '{:obstacle_presence, < true or false >}' as a return of this function.
  """
  def send_robot_status(channel, %FWClientRobotA.Position{x: x, y: y, facing: facing} = _robot, goal_locs) do

    # goals_string = convert_to_numbers(goal_locs)
    # IO.inspect(goals_string, label: "Goal string to be sent")

    message = %{client: "robot_A", x: x, y: y, face: facing, goals: goal_locs} #formats the message

    #New format for task 5
    # %{"event_id" => <integer>, "sender" => <"A" OR "B" OR "Server">, "value" => <data_required_by_server>, ...}
    event_message = %{"event_id" => 1, "sender" => "A", "value" => %{"x" => x, "y" => y, "face" => facing}} #formats the message

    {:ok, _} = PhoenixClient.Channel.push(channel, "event_msg", event_message)

    {:ok, obstaclePresence} = PhoenixClient.Channel.push(channel, "new_msg", message)

    {:obstacle_presence, obstaclePresence}

    ###########################
    ## complete this funcion ##
    ###########################
  end

  def send_obstacle_presence(channel, %FWClientRobotA.Position{x: x, y: y, facing: facing} = _robot) do
    event_message = %{"event_id" => 2, "sender" => "A", "value" => %{"x" => x, "y" => y, "face" => facing}}
    {:ok, _} = PhoenixClient.Channel.push(channel, "event_msg", event_message)
  end

  def send_weeding_msg(channel, location) do
    event_message = %{"event_id" => 4, "sender" => "A", "value" => location}
    {:ok, _} = PhoenixClient.Channel.push(channel, "event_msg", event_message)
  end

  def send_seeding_msg(channel, location) do
    event_message = %{"event_id" => 3, "sender" => "A", "value" => location}
    {:ok, _} = PhoenixClient.Channel.push(channel, "event_msg", event_message)
  end

  @doc """
  Takes in x (integer) and y(atom) to convert them into the corresponding square location
  """
  def convert_to_location(x, y) do
    y = @robot_map_y_atom_to_num[y]
    location = x + ((y-1) * 5)
  end

  ###########
  ### GET ###
  ###########
  def get_goals (channel) do
    {:ok, goal_list} = PhoenixClient.Channel.push(channel, "goals_msg", %{"sender" => "A"})
  end

  def get_start(channel) do
    {:ok, start_map} = PhoenixClient.Channel.push(channel, "start_msg", %{})
  end

  def coords_store_get(channel) do
    {:ok, coord_map} = PhoenixClient.Channel.push(channel, "coords_store_get", %{A: nil, B: "B"})
    #Add further processing according to requirements
    # IO.inspect(coord_map, label: "Co-ord Map recieved from Server")
    new_coord_map = {coord_map["face"] |> String.to_atom, coord_map["x"], coord_map["y"] |> String.to_atom}
  end

  def previous_store_get(channel) do
    {:ok, prev_map} = PhoenixClient.Channel.push(channel, "previous_store_get", %{A: "A", B: nil})
    new_prev_map = {prev_map["face"] |> String.to_atom, prev_map["x"], prev_map["y"] |> String.to_atom}
  end

  def goal_choice_get(channel) do
    {:ok, choice_map} = PhoenixClient.Channel.push(channel, "goal_choice_get", %{A: "A", B: nil})
    #Add further processing according to requirements
    IO.inspect(choice_map, label: "Choice Map recieved from Server")
    choice_map
  end

  def turns_get(channel) do
    {:ok, turns_map} = PhoenixClient.Channel.push(channel, "turns_get", %{})
    #Add further processing according to requirements
    # IO.inspect(turns_map, label: "Turn Map recieved from Server")
    turns_map
  end

  def goal_store_get(channel) do
    {:ok, goal_list} = PhoenixClient.Channel.push(channel, "goal_store_get", %{})
    #IO.inspect(goal_map["list"], label: "Goal Store Output")
    if(goal_list["list"] != nil) do
      Enum.map(goal_list["list"], fn s -> String.to_atom(s) end)
    else
      nil
    end
  end

  def stopped_get(channel) do
    {:ok, status} = PhoenixClient.Channel.push(channel, "stopped_get", %{})
    if status["A"] == true do
      # Acknowledge stop
      event_msg = %{"event_id" => 7, "sender" => "A", "value" => nil}
    end
  end

  ##############
  ### UPDATE ###
  ##############

  def coords_store_update(channel, {x, y, facing} = _msg) do
    message = %{x: x, y: y, face: facing, client: "robot_A"}
    {:ok, _} = PhoenixClient.Channel.push(channel, "coords_store_update", message)
  end

  def previous_store_update(channel, {x, y, facing} = _msg) do
    message = %{x: x, y: y, face: facing, client: "robot_A"}
    {:ok, _} = PhoenixClient.Channel.push(channel, "previous_store_update", message)
  end

  def goal_store_update(channel, msg) do
    {:ok, _} = PhoenixClient.Channel.push(channel, "goal_store_update", %{list: msg})
  end

  def turns_update(channel, msg) do
    # %{"A" => "true", "B" => "false"}
    {:ok, _} = PhoenixClient.Channel.push(channel, "turns_update", msg)
  end

  ############
  ## DELETE ##
  ############
  def goal_store_delete(channel, key) do
    {:ok, _} = PhoenixClient.Channel.push(channel, "goal_store_delete", %{key: key})
  end

  ######################################################
  ## You may create extra helper functions as needed. ##
  ######################################################
  # mapping of y-coordinates
  @robot_map_y_atom_to_num %{:a => 1, :b => 2, :c => 3, :d => 4, :e => 5, :f => 6}
  def convert_to_numbers(goal_locs) do
    # Goals: [
    #   ["3", "e"],
    #   ["3", "b"],
    #   ["1", "a"],
    #   ["4", "a"],
    #   ["4", "b"],
    #   ["5", "c"],
    #   ["3", "d"],
    #   ["5", "c"]
    # ]

    ans = Enum.reduce(goal_locs, [], fn [x, y], acc ->
      x = String.to_integer(x)
      y = @robot_map_y_atom_to_num[String.to_atom(y)]
      res = 5 * (y-1) + x
      acc ++ [Integer.to_string(res)]
    end)
  end

end
