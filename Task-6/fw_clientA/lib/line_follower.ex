defmodule FWClientRobotA.LineFollower do
  @doc """
  * Team Id : 2339
  * Author List : Kunal Agarwal,Om Sheladia,Toshan Luktuke.
  * Filename: line_follower.ex
  * Theme: Functional Weeder
  * Functions: Too many to meaningfully list here
  * Global Variables: @sensor_pins, @ir_pins, @motor_pins, @pwm_pins, @servo_a_pin, @servo_b_pin, @servo_c_pin, @ref_atoms,
                      @lf_sensor_data, @lf_sensor_map, @forward, @backward, @left, @right, @stop, @onlyright, @onlyleft,
                      @duty_cycles, @pwm_frequency, @black_MARGIN, @white_MARGIN,  @weights, @optimum_duty_cycle, @lower_duty_cycle,
                      @higher_duty_cycle, @turn, @slight_turn, @kp, @ki, @kd
  """
  require Logger
  use Bitwise
  alias Circuits.GPIO

  @sensor_pins [cs: 5, clock: 25, address: 24, dataout: 23]
  @ir_pins [dr: 16, dl: 19]
  @motor_pins [lf: 12, lb: 13, rf: 20, rb: 21]
  @pwm_pins [enl: 6, enr: 26]
  @servo_a_pin 27
  @servo_b_pin 22
  @servo_c_pin 4

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
  @left [0, 1, 0, 1]
  @right [1, 0, 1, 0]
  @stop [0, 0, 0, 0]
  @onlyright [0, 0, 1, 0]
  @onlyleft [0, 1, 0, 0]

  @duty_cycles [100, 70, 0]
  @pwm_frequency 50

  # Margin values set to distinguish between black and white lines
  @black_MARGIN 400
  @white_MARGIN 1000

  # weights assigned to wlf_sensors for error calculation
  @weights [0, -3, -1, 0, 1, 3]

  # Speed given to motors for straight motion
  # @optimum_duty_cycle 110
  # @lower_duty_cycle 85
  # @higher_duty_cycle 135

  @optimum_duty_cycle 115
  @lower_duty_cycle 90
  @higher_duty_cycle 140

  # @optimum_duty_cycle 103
  # @lower_duty_cycle 83
  # @higher_duty_cycle 128

  # Speed Given to motors for turning
  @turn 115
  @slight_turn 115

  # @turn 100
  # @slight_turn 100

  # Pid constants
  @kp 5
  @ki 0
  @kd 5

  @doc """
    * Function Name: start
    * Input: none
    * Output: Moves the robot straight till a node is detected
    * Logic: Initialized variables to be used globally and passed them in function call of line_follow()
    * Example Call: start()
  """
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

  @doc """
    * Function Name: line_follow
    * Input: error, prev_error, cumulative_error, left_duty_cycle, right_duty_cycle, main_node, same_node
    * Output: Moves the robot straight till a node is detected.
    * Logic: 1) Read values of wlf sensors
             2) Calculated error in readings (when robot moves) using calculate_error()
             3) Calculated correction value for error using calculate_correction()
             4) detected and stored nodes in main_node; main_node = main_node + 1 by setting a flag same_node initially as false
                so that only 1 white line is counted for node_detection
             5) Assigned duty cycles (speeds) to left and right motors after error correction
             6) bounded left and right duty cycles
             7) Stop the robot if node is detected else continue following line
    * Example Call: line_follow(error, prev_error, cumulative_error, left_duty_cycle, right_duty_cycle, main_node, same_node)
                    (Supporting function for start(); Need to call start() for line following)
  """
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

    # Node detection for the robot to stop on nodes
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

    # assigning corrected speeds to variables
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

  @doc """
    * Function Name: get_high_no
    * Input: map_sens_list
    * Output: Count of LSA readings > 700
    * Logic: traversing through list and incrementing counter if reading>700
    * Example Call: get_high_no(map_sens_list)
                   (Supporting function for start(); Need to call start() for line following)
  """
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

  @doc """
    * Function Name: calculate_error
    * Input: map_sens_list, error, prev_error
    * Output: error and prev_error
    * Logic: 1) Set all_black_flag = 1 for all black condition, i.e. when none of the sensors are on white line
             2) calculate weighted_sum_list by multiplying Lsa values with defined weights
             3) Calculate sum and weighted_sum by adding respective list
             4) Calculate pos i.e. weighted_sum/sum
             5) assign error = pos when all_black_flag is 0
    * Example Call: calculate_error(map_sens_list, error, prev_error)
                   (Supporting function for start(); Need to call start() for line following)

  """
  def calculate_error(map_sens_list, error, prev_error) do
    all_black_flag = 1
    weighted_sum = 0
    sum = 0
    pos = 0

    # flag which is set to 1 if all sensors are on black surface (not on white line)
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

  @doc """
    * Function Name: calculate_correction()
    * Input: error, prev_error, cumulative_error
    * Output: error, prev_error, cumulative_error, correction
    * Logic: 1) update the calculated error by multiplying it with 10, calculate difference in current and previous errors
                and error to cumulative error
             2) Calculate correction value after PID tuning it with PID constants
             3) assign prev_error = error
    * Example Call: calculate_correction(error, prev_error, cumulative_error)
                    (Supporting function for start(); Need to call start() for line following)
  """
  def calculate_correction(error, prev_error, cumulative_error) do
    error = error * 10
    difference = error - prev_error
    cumulative_error = cumulative_error + error

    # bounding cumulative_error between -30 to 30
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

    # calculating correction value by adjusting values of PID constants
    correction = @kp * error + @ki * cumulative_error + @kd * difference

    prev_error = error

    {error, prev_error, cumulative_error, correction}
  end

  @doc """
  * Function Name: my_motion
  * Input: left_duty_cycle, right_duty_cycle
  * Output: Assigns duty_cycles to both motors
  * Logic: Assigns left_duty_cycle and right_duty_cycles to respective PWM pins
  * Example Call: my_motion(left_duty_cycle, right_duty_cycle)
                  (Supporting function for start(); Need to call start() for line following)
  """

  def my_motion(left_duty_cycle, right_duty_cycle) do
    IO.inspect(left_duty_cycle, label: "left_motor_speed")
    IO.inspect(right_duty_cycle, label: "right_motor_speed")
    {_, lvalue} = Enum.at(@pwm_pins, 0)
    {_, rvalue} = Enum.at(@pwm_pins, 1)
    Pigpiox.Pwm.gpio_pwm(lvalue, left_duty_cycle)
    Pigpiox.Pwm.gpio_pwm(rvalue, right_duty_cycle)
  end

  @doc """
    * Function Name: turn_right
    * Input: none
    * Output: move_right(right_detect, motor_ref) function call
    * Logic: Initialized variables to be used globally for move_right()
    * Example Call: turn_right()
  """
  def turn_right do
    right_detect = false
    motor_ref = Enum.map(@motor_pins, fn {_atom, pin_no} -> GPIO.open(pin_no, :output) end)
    move_right(right_detect, motor_ref)
  end

  @doc """
    * Function Name: move_right
    * Input: right_detect, motor_ref
    * Output: Turns the robot right
    * Logic: 1) Increase speed of robot if old_map_list == map_sens_list (if its on the same position)
             2) Give duty cycles to my_motion()
             3) set flag value as true if robot is not on white line
             4) Stop the robot if white line is reached after turn else continue turning.
                Also a Function slide_left() is called in case robot overshoots while turning right
    * Example Call: move_right(right_detect, motor_ref)
                    (Supporting function for turn_right(); Need to call turn_right() for Right turn)
  """
  def move_right(right_detect, motor_ref) do
    map_sens_list = test_wlf_sensors()
    motor_action(motor_ref, @onlyright)

    {old_map_sens, i} = Agent.get(:line_sensor, fn {list, i} -> {list, i} end)

    # increasing speed if robot takes time to take turn/doesn't turn by comparing wlf_sensor readings
    speed =
      if old_map_sens == map_sens_list do
        Agent.update(:line_sensor, fn {list, i} -> {list, i + 1} end)
        IO.inspect(@slight_turn + i * 5, label: "Speed is increasing")
        @turn + i * 5
      else
        Agent.update(:line_sensor, fn list -> {map_sens_list, 0} end)
        @turn
      end

    my_motion(speed, speed - 10)

    right_detect =
      if Enum.at(map_sens_list, 1) < 900 && Enum.at(map_sens_list, 2) < 900 &&
           Enum.at(map_sens_list, 3) < 900 &&
           Enum.at(map_sens_list, 4) < 900 do
        right_detect = true
      else
        right_detect
      end

    # stopping right turn of robot when white line is detected
    if Enum.at(map_sens_list, 3) > 900 && right_detect == true do
      motor_action(motor_ref, @stop)
      my_motion(0, 0)
      # map_sens_list = test_wlf_sensors()
      # Call the slide_left function if any of the middle 3 sensors are not on the white line
      if Enum.at(map_sens_list, 2) < 900 && Enum.at(map_sens_list, 3) < 900 &&
           Enum.at(map_sens_list, 4) < 900 do
        IO.puts("Sliding Left")
        slide_left()
      end
    else
      move_right(right_detect, motor_ref)
    end
  end

  @doc """
    * Function Name: turn_left
    * Input: none
    * Output: move_left(left_detect, motor_ref) function call
    * Logic: Initialized variables to be used globally for move_left()
    * Example Call: turn_left()
  """
  def turn_left do
    left_detect = false
    motor_ref = Enum.map(@motor_pins, fn {_atom, pin_no} -> GPIO.open(pin_no, :output) end)
    move_left(left_detect, motor_ref)
  end

  @doc """
    * Function Name: move_left
    * Input: left_detect, motor_ref
    * Output: Turns the robot left
    * Logic: 1) Increase speed of robot if old_map_list == map_sens_list (if its on the same position)
             2) Give duty cycles to my_motion()
             3) set flag value as true if robot is not on white line
             4) Stop the robot if white line is reached after turn else continue turning.
                Also a Function slide_right() is called in case robot overshoots while turning left
    * Example Call: move_left(left_detect, motor_ref)
                    (Supporting function for turn_left(); Need to call turn_left() for Left turn)
  """
  def move_left(left_detect, motor_ref) do
    map_sens_list = test_wlf_sensors()
    motor_action(motor_ref, @onlyleft)

    {old_map_sens, i} = Agent.get(:line_sensor, fn {list, i} -> {list, i} end)

    # increasing speed if robot takes time to take turn/doesn't turn by comparing wlf_sensor readings
    speed =
      if old_map_sens == map_sens_list do
        Agent.update(:line_sensor, fn {list, i} -> {list, i + 1} end)
        @turn + i * 5
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

  @doc """
    * Function Name: slide_left
    * Input: none
    * Output: drift_left(left_detect, motor_ref) function call
    * Logic: Initialized variables to be used globally for drift_left()
    * Example Call: slide_left()
  """
  def slide_left do
    left_detect = false
    motor_ref = Enum.map(@motor_pins, fn {_atom, pin_no} -> GPIO.open(pin_no, :output) end)
    drift_left(left_detect, motor_ref)
  end

  @doc """
    * Function Name: drift_left
    * Input: left_detect, motor_ref
    * Output: Turns the robot a slight left
    * Logic: 1) Increase speed of robot if old_map_list == map_sens_list (if its on the same position)
             2) Give duty cycles to my_motion()
             4) Stop the robot if white line is reached after turn else continue turning.
    * Example Call: drift_left(left_detect, motor_ref)
                    (Supporting function for slide_left(); Need to call slide_left() for slight Left turn)
  """
  def drift_left(left_detect, motor_ref) do
    map_sens_list = test_wlf_sensors()

    # stop the robot if any of the middle 3 sensors read value > 900 else continue moving left
    if Enum.at(map_sens_list, 2) > 900 || Enum.at(map_sens_list, 3) > 900 ||
         Enum.at(map_sens_list, 4) > 900 do
      motor_action(motor_ref, @stop)
      IO.puts("Stopped")
      my_motion(0, 0)
    else
      motor_action(motor_ref, @onlyleft)
      {old_map_sens, i} = Agent.get(:line_sensor, fn {list, i} -> {list, i} end)

      # increasing speed if robot takes time to take turn/doesn't turn by comparing wlf_sensor readings
      speed =
        if old_map_sens == map_sens_list do
          Agent.update(:line_sensor, fn {list, i} -> {list, i + 1} end)
          IO.inspect(@slight_turn + i * 5, label: "Speed is increasing")

          @slight_turn + i * 5
        else
          Agent.update(:line_sensor, fn list -> {map_sens_list, 0} end)
          @slight_turn
        end

      my_motion(speed, speed)
      drift_left(left_detect, motor_ref)
    end
  end

  @doc """
    * Function Name: slide_right
    * Input: none
    * Output: drift_right(right_detect, motor_ref) function call
    * Logic: Initialized variables to be used globally for drift_right()
    * Example Call: slide_right()
  """

  def slide_right do
    left_detect = false
    motor_ref = Enum.map(@motor_pins, fn {_atom, pin_no} -> GPIO.open(pin_no, :output) end)
    drift_right(left_detect, motor_ref)
  end

  @doc """
    * Function Name: drift_right
    * Input: left_detect, motor_ref
    * Output: Turns the robot a slight right
    * Logic: 1) Increase speed of robot if old_map_list == map_sens_list (if its on the same position)
             2) Give duty cycles to my_motion()
             4) Stop the robot if white line is reached after turn else continue turning.
    * Example Call: drift_right(left_detect, motor_ref)
                    (Supporting function for slide_right(); Need to call slide_right() for slight Right turn)
  """
  def drift_right(left_detect, motor_ref) do
    map_sens_list = test_wlf_sensors()

    # stop the robot if any of the middle 3 sensors read value > 900 else continue moving right
    if Enum.at(map_sens_list, 2) > 900 || Enum.at(map_sens_list, 3) > 900 ||
         Enum.at(map_sens_list, 4) > 900 do
      motor_action(motor_ref, @stop)
      my_motion(0, 0)
    else
      motor_action(motor_ref, @onlyright)
      {old_map_sens, i} = Agent.get(:line_sensor, fn {list, i} -> {list, i} end)

      # increasing speed if robot takes time to take turn/doesn't turn by comparing wlf_sensor readings
      speed =
        if old_map_sens == map_sens_list do
          Agent.update(:line_sensor, fn {list, i} -> {list, i + 1} end)
          IO.inspect(@slight_turn + i * 5, label: "Speed is increasing")
          @slight_turn + i * 5
        else
          Agent.update(:line_sensor, fn list -> {map_sens_list, 0} end)
          @slight_turn
        end

      my_motion(speed, speed)
      drift_right(left_detect, motor_ref)
    end
  end

  @doc """
    * Function Name: move_back
    * Input: none
    * Output: Moves the robot in backward direction
    * Logic: Set @backward pins in motor_action() and duty_cycles to my_motion. Moves for 3s and then stops
    * Example Call: move_back()
  """
  def move_back do
    motor_ref = Enum.map(@motor_pins, fn {_atom, pin_no} -> GPIO.open(pin_no, :output) end)
    motor_action(motor_ref, @backward)
    my_motion(@optimum_duty_cycle, @optimum_duty_cycle)
    Process.sleep(300)
    motor_action(motor_ref, @stop)
    my_motion(0, 0)
  end

  @doc """
    * Function Name: stop_seeder
    * Input: none
    * Output: Moves the robot straight till a plant is detected
    * Logic: Initialized variables to be used globally and passed them in function call of seed_follow()
    * Example Call: stop_seeder()
  """

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

  @doc """
    * Function Name: seed_follow
    * Input: error, prev_error, cumulative_error, left_duty_cycle, right_duty_cycle
    * Output: Moves the robot straight till a node is detected.
    * Logic: 1) Read values of wlf sensors
             2) Calculated error in readings (when robot moves) using calculate_error()
             3) Calculated correction value for error using calculate_correction()
             4) bounded left and right duty cycles
             5) Read boolean value from side_ir()
             6) Assigned duty cycles (speeds) to left and right motors after error correction
             7) Stop the robot if plant is detected by side IR sensor else continue following line
    * Example Call: seed_follow(error, prev_error, cumulative_error, left_duty_cycle, right_duty_cycle)
                    (Supporting function for stop_seeder(); Need to call stop_seeder() for line following)
  """
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

    # Reading boolean value from side IR sensor via side_ir()
    seed_value = side_ir()

    # stop when seed_value is true else continue following line
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
  def test_servo_a(angle) do
    Logger.debug("Testing Servo A")
    val = trunc((2.5 + 10.0 * angle / 180) / 100 * 255)
    Pigpiox.Pwm.set_pwm_frequency(@servo_a_pin, @pwm_frequency)
    Pigpiox.Pwm.gpio_pwm(@servo_a_pin, val)
  end

  @doc """
  Note: On executing above function servo motor B will rotate by 90 degrees. You can provide
  values from 0 to 180
  """
  def test_servo_b(angle) do
    Logger.debug("Testing Servo B")
    val = trunc((2.5 + 10.0 * angle / 180) / 100 * 255)
    Pigpiox.Pwm.set_pwm_frequency(@servo_b_pin, @pwm_frequency)
    Pigpiox.Pwm.gpio_pwm(@servo_b_pin, val)
  end

  @doc """
  Note: On executing above function servo motor C will rotate by 90 degrees. You can provide
  values from 0 to 180
  """
  def test_servo_c(angle) do
    Logger.debug("Testing Servo C")
    val = trunc((2.5 + 10.0 * angle / 180) / 100 * 255)
    Pigpiox.Pwm.set_pwm_frequency(@servo_c_pin, @pwm_frequency)
    Pigpiox.Pwm.gpio_pwm(@servo_c_pin, val)
  end

  @doc """
    * Function Name: servo_initialize
    * Input: none
    * Output: Moves the servos by given degrees
    * Logic: Called test_servo_a(),test_servo_b(),test_servo_c() with appropriate angles and delays to initialize arm at proper angles
    * Example Call: servo_initialize()
  """
  def servo_initialize do
    test_servo_b(120)
    Process.sleep(500)
    test_servo_a(100)
    Process.sleep(500)
    test_servo_c(60)
    Process.sleep(500)
  end

  @doc """
    * Function Name: weeder
    * Input: none
    * Output: Moves the servos by given degrees
    * Logic: Called test_servo_a(),test_servo_b(),test_servo_c() with appropriate angles and delays for completion of weeding action by arm
    * Example Call: weeder()
  """
  def weeder do
    test_servo_b(120)
    Process.sleep(1000)
    test_servo_a(105)
    Process.sleep(1000)
    test_servo_c(40)
    Process.sleep(1000)
    test_servo_b(50)
    Process.sleep(1000)
    # close
    test_servo_c(120)
    Process.sleep(1500)
    test_servo_b(140)
    Process.sleep(1250)
    test_servo_a(10)
    Process.sleep(1000)
    # open
    test_servo_c(60)
    Process.sleep(500)
  end

  @doc """
    * Function Name: depo
    * Input: none
    * Output: Moves the servos by given degrees
    * Logic: Called test_servo_a(),test_servo_b(),test_servo_c() with appropriate angles and delays for completion of deposition of stalks
    * Example Call: depo()
  """
  def depo do
    test_servo_b(120)
    Process.sleep(1000)
    test_servo_a(100)
    Process.sleep(1000)
    test_servo_c(120)
    Process.sleep(1000)
    test_servo_b(60)
    Process.sleep(1000)
    test_servo_a(0)
    Process.sleep(1000)
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

  @doc """
   function to check obstacle detection by front IR sensor

   true // obstacle detected
   false // No obstacle
  """

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

  @doc """
  function to check obstacle detection by side IR sensor

  true // obstacle detected
  false // No obstacle
  """

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
