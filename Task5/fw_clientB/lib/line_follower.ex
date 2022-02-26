defmodule FWClientRobotB.LineFollower do
  require Logger
  use Bitwise
  alias Circuits.GPIO

  @sensor_pins [cs: 5, clock: 25, address: 24, dataout: 23]
  @ir_pins [dr: 16, dl: 19]
  @motor_pins [lf: 12, lb: 13, rf: 20, rb: 21]
  @pwm_pins [enl: 6, enr: 26]
  @servo_a_pin 27
  @servo_b_pin 22
  @servo_c_pin 5
  @servo_d_pin 17

  @ref_atoms [:cs, :clock, :address, :dataout]
  @lf_sensor_data %{sensor0: 0, sensor1: 0, sensor2: 0, sensor3: 0, sensor4: 0, sensor5: 0}
  @lf_sensor_map %{
    0 => :sensor0,
    1 => :sensor1,
    2 => :sensor2,
    3 => :sensor3,
    4 => :sensor4,
    5 => :sensor5
  }

  @forward [0, 1, 1, 0]
  @backward [1, 0, 0, 1]
  # @left [0, 1, 1, 0]
  # @right [1, 0, 0, 1]
  @stop [0, 0, 0, 0]
  @onlyright [0, 0, 1, 0]
  @onlyleft [0, 1, 0, 0]

  @duty_cycles [100, 70, 0]
  @pwm_frequency 50

  @black_MARGIN 400
  @white_MARGIN 1000
  @weights [0, -3, -1, 0, 1, 3]

  #Speed given to motors while straight motion
  @optimum_duty_cycle 120
  @lower_duty_cycle 95
  @higher_duty_cycle 145

  # Speed Given to motors while turning
  @turn 125
  @slight_turn 115

  # Pid constants
  @kp 5
  @ki 0
  @kd 5

  # Function for Straight motion of robot
  def start do
    error = 0
    prev_error = 0
    cumulative_error = 0
    left_duty_cycle = 0
    right_duty_cycle = 0
    main_node = 0
    same_node = false

    line_follow(
      error,
      prev_error,
      cumulative_error,
      left_duty_cycle,
      right_duty_cycle,
      main_node,
      same_node
    )
  end

  # Line following Function with PID implementation
  def line_follow(
        error,
        prev_error,
        cumulative_error,
        left_duty_cycle,
        right_duty_cycle,
        main_node,
        same_node
      ) do
    map_sens_list = test_wlf_sensors()
    # IO.inspect(map_sens_list)

    {error, prev_error} = calculate_error(map_sens_list, error, prev_error)

    {error, prev_error, cumulative_error, correction} =
      calculate_correction(error, prev_error, cumulative_error)

    # Node detection for stopping on nodes
    {main_node, same_node} =
      if same_node == false && get_high_no(map_sens_list) >= 3 do
        same_node = true
        main_node = main_node + 1
        IO.inspect(map_sens_list)
        {main_node, same_node}
      else
        {main_node, same_node}
      end

    same_node =
      if same_node == true && Enum.at(map_sens_list, 4) < 600 do
        same_node = false
      else
        same_node
      end

    IO.inspect(main_node)

    left_duty_cycle = round(@optimum_duty_cycle - correction)
    right_duty_cycle = round(@optimum_duty_cycle + correction)

    left_duty_cycle =
      if left_duty_cycle > @higher_duty_cycle do
        left_duty_cycle = @higher_duty_cycle
      else
        left_duty_cycle
      end

    left_duty_cycle =
      if left_duty_cycle < @lower_duty_cycle do
        left_duty_cycle = @lower_duty_cycle
      else
        left_duty_cycle
      end

    right_duty_cycle =
      if right_duty_cycle < @lower_duty_cycle do
        right_duty_cycle = @lower_duty_cycle
      else
        right_duty_cycle
      end

    right_duty_cycle =
      if right_duty_cycle > @higher_duty_cycle do
        right_duty_cycle = @higher_duty_cycle
      else
        right_duty_cycle
      end

    motor_ref = Enum.map(@motor_pins, fn {_atom, pin_no} -> GPIO.open(pin_no, :output) end)

    # Stopping the robot when node is detected else recursively call the line_follow function to continue forward motion
    main_node =
      if main_node == 1 do
        motor_action(motor_ref, @stop)
        my_motion(0, 0)
        # Process.sleep(350)
        main_node = 0
        main_node
      else
        motor_action(motor_ref, @forward)
        my_motion(left_duty_cycle, right_duty_cycle)

        line_follow(
          error,
          prev_error,
          cumulative_error,
          left_duty_cycle,
          right_duty_cycle,
          main_node,
          same_node
        )

        main_node
      end
  end

  def get_high_no(map_sens_list) do
    Enum.reduce(map_sens_list, 0, fn v, acc ->
      acc =
        if v > 700 do
          acc + 1
        else
          acc
        end

      acc
    end)
  end

  # Function to Calculate error in LSA readings for Line following
  def calculate_error(map_sens_list, error, prev_error) do
    all_black_flag = 1
    weighted_sum = 0
    sum = 0
    pos = 0

    all_black_flag =
      Enum.reduce(map_sens_list, 1, fn val, acc ->
        if val > @black_MARGIN do
          acc = 0
        else
          acc
        end
      end)

    weighted_sum_list =
      map_sens_list |> Enum.zip(@weights) |> Enum.map(fn {map, weight} -> map * weight end)

    weighted_sum = Enum.sum(weighted_sum_list)
    sum = Enum.sum(map_sens_list)

    pos =
      if sum != 0 do
        pos = weighted_sum / sum
      else
        pos = 0
      end

    error =
      if all_black_flag == 1 do
        error =
          if prev_error > 0 do
            error = 2.5
          else
            error = -2.5
          end
      else
        error = pos
      end

    # IO.inspect(error)
    {error, prev_error}
  end

  #Function to calculate correction value for duty cycles after PID tuning
  def calculate_correction(error, prev_error, cumulative_error) do
    error = error * 10
    difference = error - prev_error
    cumulative_error = cumulative_error + error

    cumulative_error =
      if cumulative_error < -30 do
        cumulative_error = -30
      else
        cumulative_error
      end

    cumulative_error =
      if cumulative_error > 30 do
        cumulative_error = 30
      else
        cumulative_error
      end

    correction = @kp * error + @ki * cumulative_error + @kd * difference

    prev_error = error

    {error, prev_error, cumulative_error, correction}
  end

  # Assigning duty_cycles (speed) to both motors via pwm pins

  def my_motion(left_duty_cycle, right_duty_cycle) do
    # IO.inspect(left_duty_cycle,label: "left_motor_speed")
    # IO.inspect(right_duty_cycle,label: "right_motor_speed")
    {_, lvalue} = Enum.at(@pwm_pins, 0)
    {_, rvalue} = Enum.at(@pwm_pins, 1)
    Pigpiox.Pwm.gpio_pwm(lvalue, left_duty_cycle)
    Pigpiox.Pwm.gpio_pwm(rvalue, right_duty_cycle)
  end

   # Function call to give robot a right turn
  def turn_right do
    right_detect = false
    motor_ref = Enum.map(@motor_pins, fn {_atom, pin_no} -> GPIO.open(pin_no, :output) end)
    move_right(right_detect, motor_ref)
  end

   # Helper Function for right motion of robot
  def move_right(right_detect, motor_ref) do
    map_sens_list = test_wlf_sensors()
    motor_action(motor_ref, @onlyright)

    {old_map_sens,i} = Agent.get(:line_sensor, fn {list, i} -> {list, i} end)
    speed = if old_map_sens == map_sens_list do
      Agent.update(:line_sensor, fn {list, i} ->  {list, i+1} end)
      IO.inspect(@slight_turn + (i*5), label: "Speed is increasing")
      @turn + (i*5)
    else
      Agent.update(:line_sensor, fn list -> {map_sens_list, 0} end)
      @turn
    end
    my_motion(speed, speed)

    right_detect =
      if Enum.at(map_sens_list, 1) < 900 && Enum.at(map_sens_list, 2) < 900 && Enum.at(map_sens_list, 3) < 900 &&
      Enum.at(map_sens_list, 4) < 900 do
        right_detect = true
      else
        right_detect
      end

      #stopping right turn of robot when white line is detected
      if Enum.at(map_sens_list, 3) > 900 && right_detect == true do
        motor_action(motor_ref, @stop)
        my_motion(0, 0)
        # map_sens_list = test_wlf_sensors()
      if Enum.at(map_sens_list, 2) < 900 && Enum.at(map_sens_list, 3) < 900 &&
         Enum.at(map_sens_list, 4) < 900 do
        IO.puts("Sliding Left")
        slide_left()
      end
    else
      move_right(right_detect, motor_ref)
    end
  end

   # Function to be called for turning the robot left
  def turn_left do
    left_detect = false
    motor_ref = Enum.map(@motor_pins, fn {_atom, pin_no} -> GPIO.open(pin_no, :output) end)
    move_left(left_detect, motor_ref)
  end


  #Helper Function for left turn
  def move_left(left_detect, motor_ref) do
    map_sens_list = test_wlf_sensors()
    motor_action(motor_ref, @onlyleft)

    {old_map_sens,i} = Agent.get(:line_sensor, fn {list, i} -> {list, i} end)
    speed = if old_map_sens == map_sens_list do
      Agent.update(:line_sensor, fn {list, i} ->  {list, i+1} end)
      @turn + (i*5)
    else
      Agent.update(:line_sensor, fn list -> {map_sens_list, 0} end)
      @turn
    end
    my_motion(speed, speed)


    left_detect =
      if Enum.at(map_sens_list, 2) < 900 && Enum.at(map_sens_list, 3) < 900 &&
      Enum.at(map_sens_list, 4) < 900 do
        left_detect = true
      else
        left_detect
      end

    # Stopping the left turn of robot when white line is detected
    if Enum.at(map_sens_list, 3) > 900 && left_detect == true do
      motor_action(motor_ref, @stop)
      my_motion(0, 0)
      if Enum.at(map_sens_list, 2) < 900 && Enum.at(map_sens_list, 3) < 900 &&
        Enum.at(map_sens_list, 4) < 900 do
        IO.puts("Sliding Right")
        slide_right()
      end
    else
      move_left(left_detect, motor_ref)
    end
  end

  #Helper Function for when bot overshoots while turning right
  def slide_left do
    left_detect = false
    motor_ref = Enum.map(@motor_pins, fn {_atom, pin_no} -> GPIO.open(pin_no, :output) end)
    drift_left(left_detect, motor_ref)
  end

  def drift_left(left_detect, motor_ref) do
    map_sens_list = test_wlf_sensors()
    if (Enum.at(map_sens_list, 2) > 900 || Enum.at(map_sens_list, 3) > 900 ||
          Enum.at(map_sens_list, 4) > 900) do
      motor_action(motor_ref, @stop)
      IO.puts("Stopped")
      my_motion(0, 0)
    else
      motor_action(motor_ref, @onlyleft)
      {old_map_sens,i} = Agent.get(:line_sensor, fn {list, i} -> {list, i} end)
      speed = if old_map_sens == map_sens_list do
        Agent.update(:line_sensor, fn {list, i} ->  {list, i+1} end)
        IO.inspect(@slight_turn + (i*5), label: "Speed is increasing")

        @slight_turn + (i*5)
      else
        Agent.update(:line_sensor, fn list -> {map_sens_list, 0} end)
        @slight_turn
      end
      my_motion(speed, speed)
      drift_left(left_detect, motor_ref)
    end
  end

  #Helper Function for when bot overshoots while turning left
  def slide_right do
    left_detect = false
    motor_ref = Enum.map(@motor_pins, fn {_atom, pin_no} -> GPIO.open(pin_no, :output) end)
    drift_right(left_detect, motor_ref)
  end

  def drift_right(left_detect, motor_ref) do
    map_sens_list = test_wlf_sensors()
    if (Enum.at(map_sens_list, 2) > 900 || Enum.at(map_sens_list, 3) > 900 ||
          Enum.at(map_sens_list, 4) > 900) do
      motor_action(motor_ref, @stop)
      my_motion(0, 0)

    else
      motor_action(motor_ref, @onlyright)
      {old_map_sens,i} = Agent.get(:line_sensor, fn {list, i} -> {list, i} end)
      speed = if old_map_sens == map_sens_list do
        Agent.update(:line_sensor, fn {list, i} ->  {list, i+1} end)
        IO.inspect(@slight_turn + (i*5), label: "Speed is increasing")
        @slight_turn + (i*5)
      else
        Agent.update(:line_sensor, fn list -> {map_sens_list, 0} end)
        @slight_turn
      end
      my_motion(speed, speed)
      drift_right(left_detect, motor_ref)
    end
  end

  # Function for backward movement of robot
  def move_back do
    motor_ref = Enum.map(@motor_pins, fn {_atom, pin_no} -> GPIO.open(pin_no, :output) end)
    motor_action(motor_ref, @backward)
    my_motion(@optimum_duty_cycle, @optimum_duty_cycle)
    Process.sleep(300)
    motor_action(motor_ref, @stop)
    my_motion(0, 0)
  end

  # Function to be called for stopping the bot based on side IR sensor for seeding/weeding
  def stop_seeder do
    error = 0
    prev_error = 0
    cumulative_error = 0
    left_duty_cycle = 0
    right_duty_cycle = 0

    seed_follow(
      error,
      prev_error,
      cumulative_error,
      left_duty_cycle,
      right_duty_cycle
    )
  end

  #Helper Function for stopping the bot for seeding/weeding
  def seed_follow(
        error,
        prev_error,
        cumulative_error,
        left_duty_cycle,
        right_duty_cycle
      ) do
    map_sens_list = test_wlf_sensors()
    # IO.inspect(map_sens_list)

    {error, prev_error} = calculate_error(map_sens_list, error, prev_error)

    {error, prev_error, cumulative_error, correction} =
      calculate_correction(error, prev_error, cumulative_error)

    # IO.inspect(main_node)

    left_duty_cycle = round(@optimum_duty_cycle - correction)
    right_duty_cycle = round(@optimum_duty_cycle + correction)

    left_duty_cycle =
      if left_duty_cycle > @higher_duty_cycle do
        left_duty_cycle = @higher_duty_cycle
      else
        left_duty_cycle
      end

    left_duty_cycle =
      if left_duty_cycle < @lower_duty_cycle do
        left_duty_cycle = @lower_duty_cycle
      else
        left_duty_cycle
      end

    right_duty_cycle =
      if right_duty_cycle < @lower_duty_cycle do
        right_duty_cycle = @lower_duty_cycle
      else
        right_duty_cycle
      end

    right_duty_cycle =
      if right_duty_cycle > @higher_duty_cycle do
        right_duty_cycle = @higher_duty_cycle
      else
        right_duty_cycle
      end

    motor_ref = Enum.map(@motor_pins, fn {_atom, pin_no} -> GPIO.open(pin_no, :output) end)

    seed_value = side_ir()

    if seed_value == true do
      motor_action(motor_ref, @stop)
      my_motion(0, 0)
    else
      motor_action(motor_ref, @forward)
      my_motion(left_duty_cycle, right_duty_cycle)

      seed_follow(
        error,
        prev_error,
        cumulative_error,
        left_duty_cycle,
        right_duty_cycle
      )
    end
  end
  @doc """
  Note: On executing above function servo motor A will rotate by 90 degrees. You can provide
  values from 0 to 180
  """
  #Function used for giving angles to servo for seeding
  def test_servo_a(angle) do
    Logger.debug("Testing Servo A")
    val = trunc(((2.5 + 10.0 * angle / 180) / 100 ) * 255)
    Pigpiox.Pwm.set_pwm_frequency(@servo_a_pin, @pwm_frequency)
    Pigpiox.Pwm.gpio_pwm(@servo_a_pin, val)
  end



  @doc """
  Tests white line sensor modules reading

  Example:

      iex> FW_DEMO.test_wlf_sensors
      [0, 958, 851, 969, 975, 943]  // on white surface
      [0, 449, 356, 312, 321, 267]  // on black surface
  """
  def test_wlf_sensors do
    sensor_ref = Enum.map(@sensor_pins, fn {atom, pin_no} -> configure_sensor({atom, pin_no}) end)
    sensor_ref = Enum.map(sensor_ref, fn {_atom, ref_id} -> ref_id end)
    sensor_ref = Enum.zip(@ref_atoms, sensor_ref)
    map_sens_list = get_lfa_readings([0, 1, 2, 3, 4], sensor_ref)
    map_sens_list
  end

  @doc """
  Tests IR Proximity sensor's readings

  Example:

      iex> FW_DEMO.test_ir
      [1, 1]     // No obstacle
      [1, 0]     // Obstacle in front of Right IR Sensor
      [0, 1]     // Obstacle in front of Left IR Sensor
      [0, 0]     // Obstacle in front of both Sensors

  Note: You can adjust the potentiometer provided on the IR sensor to get proper results
  """
  def test_ir do
    Logger.debug("Testing IR Proximity Sensors")

    ir_ref =
      Enum.map(@ir_pins, fn {_atom, pin_no} -> GPIO.open(pin_no, :input, pull_mode: :pullup) end)

    ir_values = Enum.map(ir_ref, fn {_, ref_no} -> GPIO.read(ref_no) end)
  end

  # Function returns true when front IR sensor detects obstacle else false
  def front_ir do
    sense = false
    {_, rvalue} = Enum.at(@ir_pins, 0)
    ir_ref = GPIO.open(rvalue, :input, pull_mode: :pullup)
    {_, rv} = ir_ref
    ir_value = GPIO.read(rv)

    sense =
      if ir_value == 0 do
        sense = true
      else
        sense
      end

    sense
  end

  # Function returns true when side IR sensor detects obstacle else false
  def side_ir do
    sense = false
    {_, lvalue} = Enum.at(@ir_pins, 1)
    ir_ref = GPIO.open(lvalue, :input, pull_mode: :pullup)
    {_, lv} = ir_ref
    ir_value = GPIO.read(lv)

    sense =
      if ir_value == 0 do
        sense = true
      else
        sense
      end

    sense
  end

  @doc """
  Tests motion of the Robot

  Example:

      iex> FW_DEMO.test_motion
      :ok

  Note: On executing above function Robot will move forward, backward, left, right
  for 500ms each and then stops
  """
  def test_motion do
    Logger.debug("Testing Motion of the Robot ")
    motor_ref = Enum.map(@motor_pins, fn {_atom, pin_no} -> GPIO.open(pin_no, :output) end)
    pwm_ref = Enum.map(@pwm_pins, fn {_atom, pin_no} -> GPIO.open(pin_no, :output) end)
    Enum.map(pwm_ref, fn {_, ref_no} -> GPIO.write(ref_no, 1) end)
    motion_list = [@forward, @stop, @backward, @stop, @left, @stop, @right, @stop]
    Enum.each(motion_list, fn motion -> motor_action(motor_ref, motion) end)
  end

  @doc """
  Controls speed of the Robot

  Example:

      iex> FW_DEMO.test_pwm
      Forward with pwm value = 150
      Forward with pwm value = 70
      Forward with pwm value = 0
      {:ok, :ok, :ok}

  Note: On executing above function Robot will move in forward direction with different velocities
  """
  def test_pwm do
    Logger.debug("Testing PWM for Motion control")
    motor_ref = Enum.map(@motor_pins, fn {_atom, pin_no} -> GPIO.open(pin_no, :output) end)
    motor_action(motor_ref, @forward)
    Enum.map(@duty_cycles, fn value -> motion_pwm(value) end)
  end

  @doc """
  Supporting function for test_wlf_sensors
  Configures sensor pins as input or output

  [cs: output, clock: output, address: output, dataout: input]
  """
  defp configure_sensor({atom, pin_no}) do
    if atom == :dataout do
      GPIO.open(pin_no, :input, pull_mode: :pullup)
    else
      GPIO.open(pin_no, :output)
    end
  end

  @doc """
  Supporting function for test_wlf_sensors
  Reads the sensor values into an array. "sensor_list" is used to provide list
  of the sesnors for which readings are needed


  The values returned are a measure of the reflectance in abstract units,
  with higher values corresponding to lower reflectance (e.g. a black
  surface or void)
  """
  defp get_lfa_readings(sensor_list, sensor_ref) do
    append_sensor_list = sensor_list ++ [5]
    temp_sensor_list = [5 | append_sensor_list]

    my_sens_list =
      append_sensor_list
      |> Enum.with_index()
      |> Enum.map(fn {sens_num, sens_idx} ->
        analog_read(sens_num, sensor_ref, Enum.fetch(temp_sensor_list, sens_idx))
      end)

    bounded_sens_list_L =
      my_sens_list
      |> Enum.map(fn x ->
        if x < @black_MARGIN do
          x = @black_MARGIN
          x
        else
          x
        end
      end)

    bounded_sens_list =
      bounded_sens_list_L
      |> Enum.map(fn x ->
        if x > @white_MARGIN do
          x = @white_MARGIN
          x
        else
          x
        end
      end)

    map_sens_list =
      bounded_sens_list
      |> Enum.map(fn x ->
        round((x - @black_MARGIN) * (@white_MARGIN / (@white_MARGIN - @black_MARGIN)))
      end)

    Enum.each(0..5, fn n -> provide_clock(sensor_ref) end)
    GPIO.write(sensor_ref[:cs], 1)
    map_sens_list
  end

  @doc """
  Supporting function for test_wlf_sensors
  """
  defp analog_read(sens_num, sensor_ref, {_, sensor_atom_num}) do
    GPIO.write(sensor_ref[:cs], 0)
    %{^sensor_atom_num => sensor_atom} = @lf_sensor_map

    Enum.reduce(0..9, @lf_sensor_data, fn n, acc ->
      read_data(n, acc, sens_num, sensor_ref, sensor_atom_num)
      |> clock_signal(n, sensor_ref)
    end)[sensor_atom]
  end

  @doc """
  Supporting function for test_wlf_sensors
  """
  defp read_data(n, acc, sens_num, sensor_ref, sensor_atom_num) do
    if n < 4 do
      if (sens_num >>> (3 - n) &&& 0x01) == 1 do
        GPIO.write(sensor_ref[:address], 1)
      else
        GPIO.write(sensor_ref[:address], 0)
      end

      Process.sleep(1)
    end

    %{^sensor_atom_num => sensor_atom} = @lf_sensor_map

    if n <= 9 do
      Map.update!(acc, sensor_atom, fn sensor_atom ->
        sensor_atom <<< 1 ||| GPIO.read(sensor_ref[:dataout])
      end)
    end
  end

  @doc """
  Supporting function for test_wlf_sensors used for providing clock pulses
  """
  defp provide_clock(sensor_ref) do
    GPIO.write(sensor_ref[:clock], 1)
    GPIO.write(sensor_ref[:clock], 0)
  end

  @doc """
  Supporting function for test_wlf_sensors used for providing clock pulses
  """
  defp clock_signal(acc, n, sensor_ref) do
    GPIO.write(sensor_ref[:clock], 1)
    GPIO.write(sensor_ref[:clock], 0)
    acc
  end

  @doc """
  Supporting function for test_motion
  """
  defp motor_action(motor_ref, motion) do
    motor_ref
    |> Enum.zip(motion)
    |> Enum.each(fn {{_, ref_no}, value} -> GPIO.write(ref_no, value) end)

    # Process.sleep(2000)
  end

  @doc """
  Supporting function for test_pwm
  """
  defp motion_pwm(value) do
    IO.puts("Forward with pwm value = #{value}")
    pwm(value)
    Process.sleep(2000)
  end

  @doc """
  Supporting function for test_pwm

  Note: "duty" variable can take value from 0 to 255. Value 255 indicates 100% duty cycle
  """
  defp pwm(duty) do
    Enum.each(@pwm_pins, fn {_atom, pin_no} -> Pigpiox.Pwm.gpio_pwm(pin_no, duty) end)
  end
end
