defmodule Task4CClientRobotA.PhoenixSocketClient do

  alias PhoenixClient.{Socket, Channel, Message}

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

    ###########################
    ## complete this funcion ##
    ###########################
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
  def send_robot_status(channel, %Task4CClientRobotA.Position{x: x, y: y, facing: facing} = _robot, goal_locs) do

    goals_string = convert_to_numbers(goal_locs)
    # IO.inspect(goals_string, label: "Goal string to be sent")

    message = %{x: x, y: y, face: facing, robot: :A, goals: goals_string} #formats the message

    {:ok, obstaclePresence} = PhoenixClient.Channel.push(channel, "new_msg", message)

    {:obstacle_presence, obstaclePresence}

    ###########################
    ## complete this funcion ##
    ###########################

  end

  def get_goals (channel) do
    {:ok, goal_list} = PhoenixClient.Channel.push(channel, "goals_msg", %{})
  end

  def get_start(channel) do
    {:ok, start_map} = PhoenixClient.Channel.push(channel, "start_msg", %{})
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
