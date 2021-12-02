defmodule ToyRobot.PhoenixSocketClient do
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

    # socket_opts gets the url from config
    socket_opts = [
      url: Application.get_env(:phoenix_server, :url)
    ]

    {:ok, socket} = PhoenixClient.Socket.start_link(socket_opts)

    wait_for_socket(socket)
    #Process.sleep(1000) # sleep statement is needed to avoid race condition
    # client tries to join the server before the socket finishes establishing the connection

    # joins the robot:status channel
    {:ok, _response, channel} = PhoenixClient.Channel.join(socket, "robot:status")

    {:ok, _response, channel}

  end


def wait_for_socket(socket) do
  if !Socket.connected?(socket) do
    Process.sleep(10)
    wait_for_socket(socket)
  end
end

  @doc """
  Send Toy Robot's current status i.e. location (x, y) and facing
  to the channel's PID with topic "robot:status" on Phoenix Server with the event named "new_msg". The message to be sent should be a Map.
  In return from Phoenix server, receive the boolean value < true OR false > indicating the obstacle's presence
  in this format: {:ok, < true OR false >}.
  Create a tuple of this format: '{:obstacle_presence, < true or false >}' as a return of this function.
  """
  def send_robot_status(channel, %ToyRobot.Position{x: x, y: y, facing: facing} = _robot) do
    ###########################
    ## complete this funcion ##
    ###########################
    message = %{x: x, y: y, face: facing} #formats the message

    # pushes the message to the RobotChannel at Server on the robot:status channel with a type of "new_msg"
    {:ok, obstaclePresence} = PhoenixClient.Channel.push(channel, "new_msg", message)

    {:obstacle_presence, obstaclePresence}
  end
end
