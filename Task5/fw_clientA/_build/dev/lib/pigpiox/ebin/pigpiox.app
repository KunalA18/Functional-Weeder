{application,pigpiox,
             [{applications,[kernel,stdlib,elixir,logger]},
              {description,"Use pigpiod on the Raspberry Pi.\n"},
              {modules,['Elixir.Pigpiox','Elixir.Pigpiox.Application',
                        'Elixir.Pigpiox.Command','Elixir.Pigpiox.GPIO',
                        'Elixir.Pigpiox.GPIO.Watcher',
                        'Elixir.Pigpiox.GPIO.Watcher.State',
                        'Elixir.Pigpiox.GPIO.WatcherSupervisor',
                        'Elixir.Pigpiox.Port','Elixir.Pigpiox.Pwm',
                        'Elixir.Pigpiox.Socket','Elixir.Pigpiox.Supervisor',
                        'Elixir.Pigpiox.Waveform',
                        'Elixir.Pigpiox.Waveform.Pulse']},
              {registered,[]},
              {vsn,"0.1.2"},
              {mod,{'Elixir.Pigpiox.Application',[]}}]}.