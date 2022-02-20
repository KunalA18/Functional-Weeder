defmodule FWServerWeb.ArenaLive do
  use FWServerWeb,:live_view
  require Logger

  @duration 180
  @doc """
  Mount the Dashboard when this module is called with request
  for the Arena view from the client like browser.
  Subscribe to the "robot:update" topic using Endpoint.
  Subscribe to the "timer:update" topic as PubSub.
  Assign default values to the variables which will be updated
  when new data arrives from the RobotChannel module.
  """
  def mount(_params, _session, socket) do

    FWServerWeb.Endpoint.subscribe("robot:update")
    :ok = Phoenix.PubSub.subscribe(Task4CPhoenixServer.PubSub, "timer:update")
    :ok = Phoenix.PubSub.subscribe(Task4CPhoenixServer.PubSub, "view:update")

    if Process.whereis(:stop_times) == nil do
      {:ok, pid_stop} = Agent.start_link(fn -> [] end)
      Process.register(pid_stop, :stop_times)
      read_stop_times()
    end

    socket = assign(socket, :img_robotA, "robot_facing_north.png")
    socket = assign(socket, :bottom_robotA, 0)
    socket = assign(socket, :left_robotA, 0)
    socket = assign(socket, :robotA_start, "1, a, north")
    socket = assign(socket, :robotA_goals, [])
    socket = assign(socket, :robotA_status, "Inactive")

    socket = assign(socket, :img_robotB, "robot_facing_south.png")
    socket = assign(socket, :bottom_robotB, 750)
    socket = assign(socket, :left_robotB, 750)
    socket = assign(socket, :robotB_start, "6, f, south")
    socket = assign(socket, :robotB_goals, [])
    socket = assign(socket, :robotB_status, "Inactive")

    plants_list = get_plants()
    socket = assign(socket, :obstacle_pos, MapSet.new())
    socket = assign(socket, :plant_pos, plants_list)
    socket = assign(socket, :timer_tick, 180)

    {:ok,socket}
  end

  @doc """
  Render the Grid with the coordinates and robot's location based
  on the "img_robotA" or "img_robotB" variable assigned in the mount/3 function.
  This function will be dynamically called when there is a change
  in the values of any of these variables =>
  "img_robotA", "bottom_robotA", "left_robotA", "robotA_start", "robotA_goals",
  "img_robotB", "bottom_robotB", "left_robotB", "robotB_start", "robotB_goals",
  "obstacle_pos", "timer_tick"
  """
  def render(assigns) do

    ~H"""
    <div id="dashboard-container">

      <div class="grid-container">
        <div id="alphabets">
          <div> A </div>
          <div> B </div>
          <div> C </div>
          <div> D </div>
          <div> E </div>
          <div> F </div>
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

          <%= for obs <- @obstacle_pos do %>
            <img  class="obstacles"  src="/images/stone.png" width="50px" style={"bottom: #{elem(obs,1)}px; left: #{elem(obs,0)}px"}>
          <% end %>

          <%= for plant <- @plant_pos do %>
            <img  class="plants"  src={"/images/#{elem(plant, 2)}"} width="50px" style={"bottom: #{elem(plant,1)}px; left: #{elem(plant,0)}px"}>
          <% end %>

          <div class="robot-container" style={"bottom: #{@bottom_robotA}px; left: #{@left_robotA}px"}>
            <img id="robotA" src={"/images/#{@img_robotA}"} style="height:70px;">
          </div>

          <div class="robot-container" style={"bottom: #{@bottom_robotB}px; left: #{@left_robotB}px"}>
            <img id="robotB" src={"/images/#{@img_robotB}"} style="height:70px;">
          </div>

        </div>

        <div id="numbers">
          <div> 1 </div>
          <div> 2 </div>
          <div> 3 </div>
          <div> 4 </div>
          <div> 5 </div>
          <div> 6 </div>
        </div>

      </div>
      <div id="right-container">

        <div class="timer-card">
          <label style="text-transform:uppercase;width:100%;font-weight:bold;text-align:center" >Timer</label>
            <p id="timer" ><%= @timer_tick %></p>
        </div>

        <div class="goal-card">
          <div style="text-transform:uppercase;width:100%;font-weight:bold;text-align:center" > Goal positions </div>
          <div style="display:flex;flex-flow:wrap;width:100%">
            <div style="width:50%">
              <label>Robot A</label>
              <%= for i <- @robotA_goals do %>
                <div><%= i %></div>
              <% end %>
            </div>
            <div  style="width:50%">
              <label>Robot B</label>
              <%= for i <- @robotB_goals do %>
              <div><%= i %></div>
              <% end %>
            </div>
          </div>
        </div>

        <div class="position-card">
          <div style="text-transform:uppercase;width:100%;font-weight:bold;text-align:center"> Start Positions </div>
          <form phx-submit="start_clock" style="width:100%;display:flex;flex-flow:row wrap;">
            <div style="width:100%;padding:10px">
              <label>Robot A</label>
              <input name="robotA_start" style="background-color:white;" value={"#{@robotA_start}"}>
            </div>
            <div style="width:100%; padding:10px">
              <label>Robot B</label>
              <input name="robotB_start" style="background-color:white;" value={"#{@robotB_start}"}>
            </div>

            <button  id="start-btn" type="submit">
              <svg xmlns="http://www.w3.org/2000/svg" style="height:30px;width:30px;margin:auto" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z" clip-rule="evenodd" />
              </svg>
            </button>

            <button phx-click="stop_clock" id="stop-btn" type="button">
              <svg xmlns="http://www.w3.org/2000/svg" style="height:30px;width:30px;margin:auto" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8 7a1 1 0 00-1 1v4a1 1 0 001 1h4a1 1 0 001-1V8a1 1 0 00-1-1H8z" clip-rule="evenodd" />
              </svg>
            </button>
          </form>
        </div>

        <div class="status-card">
          <label style="text-transform:uppercase;width:100%;font-weight:bold;text-align:center" >Robot A</label>
            <p id="status" style={"color:#{if @robotA_status == "Inactive", do: "red", else: "green"}"}><%= @robotA_status %></p>
        </div>
        <div class="status-card">
          <label style="text-transform:uppercase;width:100%;font-weight:bold;text-align:center" >Robot B</label>
            <p id="status" style={"color:#{if @robotB_status == "Inactive", do: "red", else: "green"}"}><%= @robotB_status %></p>
        </div>

      </div>

    </div>
    """

  end

  @doc """
  Handle the event "start_clock" triggered by clicking
  the PLAY button on the dashboard.
  """
  def handle_event("start_clock", data, socket) do

    socket = assign(socket, :robotA_start, data["robotA_start"])
    socket = assign(socket, :robotB_start, data["robotB_start"])
    socket = assign(socket, :robotA_status, "Active")
    socket = assign(socket, :robotB_status, "Active")
    FWServerWeb.Endpoint.broadcast("timer:start", "start_timer", %{})

    Phoenix.PubSub.broadcast!(Task4CPhoenixServer.PubSub, "start", {"start", %{A: socket.assigns.robotA_start, B: socket.assigns.robotB_start}})
    #################################
    ## edit the function if needed ##
    #################################

    {:noreply, socket}

  end

  @doc """
  Handle the event "stop_clock" triggered by clicking
  the STOP button on the dashboard.
  """
  def handle_event("stop_clock", _data, socket) do

    FWServerWeb.Endpoint.broadcast("timer:stop", "stop_timer", %{})

    #################################
    ## edit the function if needed ##
    #################################

    {:noreply, socket}

  end

  @doc """
  Callback function to handle incoming data from the Timer module
  broadcasted on the "timer:update" topic.
  Assign the value to variable "timer_tick" for each countdown.
  """
  def handle_info(%{event: "update_timer_tick", payload: timer_data, topic: "timer:update"}, socket) do

    Logger.info("Timer tick: #{timer_data.time}")
    socket = assign(socket, :timer_tick, timer_data.time)

    stop_list = Agent.get(:stop_times, fn list -> list end)
    kill_list = Enum.find(stop_list, fn [sr, robot, kill_time, restart_time] -> kill_time == timer_data.time end)

    socket = if kill_list != nil do
      robot = Enum.at(kill_list, 1)
      msg = %{"robot" => robot}
      Phoenix.PubSub.broadcast!(Task4CPhoenixServer.PubSub, "start", {"stop_robot", msg})
      Phoenix.PubSub.broadcast!(Task4CPhoenixServer.PubSub, "stop_event", {"stop_robot", stop_list})

      if robot == "A" do
        assign(socket, :robotA_status, "Inactive")
      else
        assign(socket, :robotB_status, "Inactive")
      end
    else
      socket
    end

    start_list = Enum.find(stop_list, fn [sr, robot, kill_time, restart_time] -> restart_time == timer_data.time end)

    socket = if start_list != nil do
      robot = Enum.at(start_list, 1)
      msg = %{"robot" => robot}
      Phoenix.PubSub.broadcast!(Task4CPhoenixServer.PubSub, "start", {"start_robot", msg})
      if robot == "A" do
        assign(socket, :robotA_status, "Active")
      else
        assign(socket, :robotB_status, "Active")
      end
    else
      socket
    end


    {:noreply, socket}

  end

  @doc """
  Callback function to handle any incoming data from the RobotChannel module
  broadcasted on the "robot:update" topic.
  Assign the values to the variables => "img_robotA", "bottom_robotA", "left_robotA",
  "img_robotB", "bottom_robotB", "left_robotB" and "obstacle_pos" as received.
  Make sure to add a tuple of format: { < obstacle_x >, < obstacle_y > } to the MapSet object "obstacle_pos".
  These values must be in pixels. You may handle these variables in separate callback functions as well.
  """
  def handle_info({"move", data}, socket) do
    #IO.inspect(data, label: "Data is sent to ArenaLive PubSub move")
    ###########################
    ## complete this funcion ##
    ###########################

    {:noreply, socket}

  end

  def handle_info({"update", data}, socket) do
    ###########################
    ## complete this funcion ##
    ###########################
    img_name = get_img(data["face"])

    #Assign values according to the robot it is
    socket = if data["client"] == "robot_A" do
      socket = assign(socket, :img_robotA, img_name)
      socket = assign(socket, :bottom_robotA, data["bottom"])
      socket = assign(socket, :left_robotA, data["left"])
      #Need to add goal updation somehow
      socket = assign(socket, :robotA_goals, data["goals"])
    else
      socket = assign(socket, :img_robotB, img_name)
      socket = assign(socket, :bottom_robotB, data["bottom"])
      socket = assign(socket, :left_robotB, data["left"])
      socket = assign(socket, :robotB_goals, data["goals"])
    end
    # assigns data to the socket to update the LiveView

    # Gray Out
    # Search the plant pos mapset the location sent by the robot
    # If location exists, gray it out
    socket = gray_out(socket, data)

    {:noreply, socket}

  end

  def gray_out(socket, data) do
    x = floor(data["left"] / 150) + 1
    y = floor(data["bottom"] / 150) + 1
    left_pos = 150 * (x-1) + 75
    bottom_pos = 150 * (y-1) + 75
    IO.puts("Left: #{left_pos}, Bottom: #{bottom_pos}")
    plants_list = Enum.map(socket.assigns.plant_pos, fn {left, bottom, img} ->
      if ((left >= left_pos - 10 and left <= left_pos + 10)
      and (bottom >= bottom_pos - 10 and bottom <= bottom_pos + 10 ))
      and (img == "red_plant.png" or img == "green_plant.png") do
       {left, bottom, "gray_plant.png"}
     else
       {left, bottom, img}
      end
   end)
   socket = assign(socket, :plant_pos, plants_list)
  end

  def handle_info({"update_obs", data}, socket) do
    IO.inspect(data, label: "Data send to update_obs")
    #elem(obs,0)
    #"bottom: #{elem(obs,1)}px; left: #{elem(obs,0)}px"
    #{left, bottom} px value
    #socket.assigns.obstacle_pos Syntax to get the MapSet
    #Each cell is 150x150 pixels
    mapset = MapSet.put(socket.assigns.obstacle_pos, data["position"])
    socket = assign(socket, :obstacle_pos, mapset)
    {:noreply, socket}
  end
  ######################################################
  ## You may create extra helper functions as needed  ##
  ## and update remaining assign variables.           ##
  ######################################################

  def get_img(direction) do
    ans = "robot_facing_north.png"
    ans = if direction == "south", do: "robot_facing_south.png", else: ans
    ans = if direction == "east", do: "robot_facing_east.png", else: ans
    ans = if direction == "west", do: "robot_facing_west.png", else: ans
    ans
  end

  def get_plants() do

    csv = "../../../Plant_Positions.csv" |> Path.expand(__DIR__) |> File.stream! |> CSV.decode |> Enum.take_every(1)
    |> Enum.filter(fn {:ok, [a, b]} -> (a != "Sowing") end)
    |> Enum.map(fn {:ok, [a, b]} -> [a, b] end)
    |> Enum.reduce(fn [a, b], acc -> acc ++ [a, b] end )

    # IO.inspect(csv)
    seeding = csv |> Enum.with_index |> Enum.map(fn {x, i} -> if rem(i, 2) == 0 do x end end) |> Enum.reject(fn x -> x == nil end)# 0, 2, 4
    weeding = csv |> Enum.with_index |> Enum.map(fn {x, i} -> if rem(i, 2) == 1 do x end end) |> Enum.reject(fn x -> x == nil end)# 1, 3, 5

    # Red for Seeding
    map = Enum.reduce(seeding, [], fn loc, acc ->
      {x, y} = convert_to_coord(loc)
      # IO.puts("Loc: #{loc}")
      left = 150 * (x-1) + 75
      bottom = 150 * (y-1) + 75
      acc ++ [{left, bottom, "red_plant.png"}]
    end)

    # Green for Weeding
    map = Enum.reduce(weeding, map, fn loc, acc ->
      {x, y} = convert_to_coord(loc)
      # IO.puts("Loc: #{loc}")
      left = 150 * (x-1) + 75
      bottom = 150 * (y-1) + 75
      acc ++ [{left, bottom, "green_plant.png"}]
    end)
    map
  end

  # Note change to 300 in final run
  def read_stop_times() do
    csv = "../../../Robots_handle.csv" |> Path.expand(__DIR__) |> File.stream! |> CSV.decode |> Enum.take_every(1)
    |> Enum.filter(fn {:ok, [a, b, c, d]} -> (b != "Robot") end)
    |> Enum.map(fn {:ok, [a, b, c, d]} -> [a, b, @duration - String.to_integer(c), @duration - String.to_integer(c) - String.to_integer(d)] end)

    IO.inspect(csv, label: "Robot stop times")
    Agent.update(:stop_times, fn list -> csv end)
  end

  def convert_to_coord(loc) do
    loc = if !is_integer(loc), do: String.to_integer(loc), else: loc
    loc = loc - 1
    x = rem(loc, 5) + 1
    y = Integer.floor_div(loc, 5) + 1
    {x, y}
  end
end
