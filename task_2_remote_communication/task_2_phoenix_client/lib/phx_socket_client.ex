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
    socket_opts = [
      url: "ws://localhost:4000/socket/websocket"
    ]

    {:ok, socket} = PhoenixClient.Socket.start_link(socket_opts)

    IO.inspect(socket)
    #wait_for_socket(socket)
    Process.sleep(1000)

    {:ok, _response, channel} = PhoenixClient.Channel.join(socket, "robot:status")

    IO.inspect(channel)

    {:ok, _response, channel}

    # t() :: %Phoenix.Socket.Message{
    #   event: new_msg,
    #   payload: term(),
    #   ref: term(),
    #   topic: robot
    # }
  end

  def wait_for_socket(socket) do
    unless Socket.connected?(socket) do
      wait_for_socket(socket)
    end
    #IO.puts("Connected")
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
    message = %{x: x, y: y, face: facing}

    # message = %PhoenixClient.Message{
    #   channel_pid: channel,
    #   event: "new_msg",
    #   payload: %ToyRobot.Position{x: x, y: y, facing: facing},
    #   ref: nil,
    #   topic: "robot:status"
    # }

    {:ok, obstaclePresence} = PhoenixClient.Channel.push(channel, "new_msg", message)
    # flush

    {:obstacle_presence, obstaclePresence}
  end
end