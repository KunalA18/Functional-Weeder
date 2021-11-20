defmodule Task2PhoenixServerWeb.ArenaLive do
  use Task2PhoenixServerWeb,:live_view

  @doc """
  Mount the Dashboard when this module is called with requesting for the Arena view from the client like browser.
  Subsribe to the "robot:update" topic as PubSub.
  Assign default values to the variables which will be updated
  when new data arrives from the RobotChannel module.
  """
  def mount(_params, _session, socket) do
    :ok = Phoenix.PubSub.subscribe(Task2PhoenixServer.PubSub, "robot:update")

    socket = assign(socket, :img, "robot_facing_north.png")
    socket = assign(socket, :bottom, 0)
    socket = assign(socket, :left, 0)

    {:ok,socket}
  end

  @doc """
  Render the Grid with the coordinates and robot's location based
  on the "img" variable assigned in the mount/3 function.
  This function will be dynamically called when there is a change
  in the values of any of these 3 variables => "img", "bottom", "left".
  """
  def render(assigns) do
    ~H"""
    <h1> Grid view</h1>

    <div class="grid-container">
      <div id="alphabets">
        <div> A </div>
        <div> B </div>
        <div> C </div>
        <div> D </div>
        <div> E </div>
      </div>

      <div class="board-container">
        <div class="game-board">
          <div class="box"></div>
          <div class="box"></div>
          <div class="box"></div>
          <div class="box"></div>
          <div class="box"></div>
          <div class="box"></div>
          <div class="box"></div>
          <div class="box"></div>
          <div class="box"></div>
          <div class="box"></div>
          <div class="box"></div>
          <div class="box"></div>
          <div class="box"></div>
          <div class="box"></div>
          <div class="box"></div>
          <div class="box"></div>
        </div>

        <div class="robot-container" style={"bottom: #{@bottom}px; left: #{@left}px"}>
          <img id="robot" src={"/images/#{@img}"} style="height:70px;">

        </div>
      </div>

      <div id="numbers">
        <div> 1 </div>
        <div> 2 </div>
        <div> 3 </div>
        <div> 4 </div>
        <div> 5 </div>
      </div>

    </div>
    """
  end

  @doc """
  Callback function to handle any incoming data from the RobotChannel module
  broadcasted on the "robot:update" topic.
  Assign the values to the variables => "img", "bottom", "left"
  based on the data recevied.
  """
  def handle_info(data ,socket) do

    ###########################
    ## complete this funcion ##
    ###########################

    {:noreply, socket}
  end

end
