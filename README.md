# Dynamic Resque Pool

[Resque pool](https://github.com/nevans/resque-pool) by Nicholas Evans
is a library for managing a pool of
[resque](http://github.com/defunkt/resque) workers.  Given a a config
file, it manages your workers for you, starting up the appropriate
number of workers for each worker type.

While the resque pool is convenient for a permanent process
overlooking a fairly constant set of workers, it is less than
convenient to use for more dynamic tasks - one-time long running batch
processing worker families that need to be started and supervised
manually, and often require adjusting number of worker processes for
maximum performance.

Workflow for this kind of task would be:

* prepare a yaml file with number of workers
* start resque-pool
* `tail -f` the log file on the other console
* look into `pstree` (or `ps faxuw` on Linux)
* babysit the process, check the system load whether number of workers
  needs to be adjusted
* edit the yaml file
* `kill -HUP` the resque pool master (hope you remembered the PID from
  pstree!)
* rinse, repeat

Or you can add `gem "resque-pool-dynamic"` to your Gemfile, `require
'resque/pool/dynamic/tasks'` to your Rakefile, and start an
interactive CLI interface that controls the resque-pool-master.

## Example resque-pool-manager session

    $ bundle exec rake resque:pool:dynamic WORKERS=foo=2:bar=2:\*=1           
    resque-pool-manager[21134]: started manager
    
    Status: running, pid: 21134
    Configuration:
      bar: 2
      "*": 1
      foo: 2
    Process tree:
    -+= 21134 japhy resque-pool-master: managing [21136, 21135, 21137, 21138, 21141]
     |--- 21135 japhy resque-1.20.0: Waiting for bar
     |--- 21136 japhy resque-1.20.0: Waiting for bar
     |--- 21137 japhy resque-1.20.0: Waiting for *
     |--- 21138 japhy resque-1.20.0: Waiting for foo
     \--- 21141 japhy resque-1.20.0: Waiting for foo

    >> log.tail
    resque-pool-manager[21134]: Pool contains worker PIDs: [21136, 21135, 21137, 21138, 21141]
    resque-pool-worker[21135]: Starting worker portinari.local:21135:bar
    resque-pool-worker[21137]: Starting worker portinari.local:21137:*
    
    resque-pool-worker[21136]: Starting worker portinari.local:21136:bar
    resque-pool-worker[21141]: Starting worker portinari.local:21141:foo
    resque-pool-worker[21138]: Starting worker portinari.local:21138:foo

(log.tail is following the logfile like `tail -f` until you break with ^C)
    
    ^C>> config :foo => 1, :bar => 4
    Reloading resque-pool-master 21134 configuration
    => {"bar"=>4, "*"=>1, "foo"=>1}
    >> status
    
    Status: running, pid: 21134
    Configuration:
      bar: 4
      "*": 1
      foo: 1
    Process tree:
    -+= 21134 japhy resque-pool-master: managing [21176, 21178, 21162, 21163, 21180, 21181]
     |--- 21162 japhy resque-1.20.0: Waiting for bar
     |--- 21163 japhy resque-1.20.0: Waiting for bar
     |--- 21176 japhy resque-1.20.0: Waiting for bar
     |--- 21178 japhy resque-1.20.0: Waiting for bar
     |--- 21180 japhy resque-1.20.0: Waiting for *
     \--- 21181 japhy resque-1.20.0: Waiting for foo
    
    >> log.tail
    resque-pool-manager[21134]: HUP: reload config file and reload logfiles
    resque-pool-manager[21134]: Flushing logs
    resque-pool-manager[21134]: HUP: gracefully shutdown old children (which have old logfiles open)
    resque-pool-manager[21134]: HUP: new children will inherit new logfiles
    resque-pool-worker[21163]: Starting worker portinari.local:21163:bar
    resque-pool-worker[21162]: Starting worker portinari.local:21162:bar
    resque-pool-manager[21134]: Reaped resque worker[21136] (status: 0) queues: bar
    resque-pool-manager[21134]: Reaped resque worker[21135] (status: 0) queues: bar
    resque-pool-worker[21176]: Starting worker portinari.local:21176:bar
    resque-pool-worker[21178]: Starting worker portinari.local:21178:bar
    resque-pool-manager[21134]: Reaped resque worker[21141] (status: 0) queues: foo
    resque-pool-manager[21134]: Reaped resque worker[21138] (status: 0) queues: foo
    resque-pool-worker[21180]: Starting worker portinari.local:21180:*
    resque-pool-worker[21181]: Starting worker portinari.local:21181:foo
    ^C>> exit
    Bye!
    Shutting down resque-pool-master 21134
    resque-pool-manager[21134]: INT: immediate shutdown (graceful worker shutdown)
    resque-pool-manager[21134]: manager finished
    $ _

## Command Line Interface

The CLI is a slightly customized Ripl shell (an IRB replacement)
started in context of a `Resque::Pool::Dynamic` instance. You can use
all Ruby you want, and call all the methods for controlling the resque
pool. A simple built-in help for the custom methods is included:

    >> help
    Known commands:
      config - "WORKERS", as interpreted by the #parse_config_string method.
      config_path - Path to the temporary config file.
      exit - Finish work
      has_log? - True if we have an open log file.
      kill! - Send signal to a running resque-pool.
      log - Open log of resque-pool process.
      log.ff - Fast forward until end of file (see IO::Tail#backward).
      log.rew - Rewind until beginning of file (see IO::Tail#forward).
      log.rewind - Rewind until beginning of file (see IO::Tail#forward).
      log.tail - Show last n lines of the file, or follow the file.
      log.tail_to_eof - Print contents of the file until current end of file.
      log.tail_until - Follow the file until a line matches regexp.
      log_path - Logfile path.
      pid - PID of the resque-pool process, or nil if it's not running.
      pstree - Show child process tree by calling `pstree` system command.
      reload - Reload resque-pool configuration.
      start - Start resque-pool, showing startup logs.
      start! - Fork a child process for resque-pool master.
      status - Show current status.
      stop - Stop running resque-pool, show shutdown logs.
      stop! - Stop running resque-pool.
      write_config - Write temporary configuration file.
    For details, type: help command
    >> help config
    -------------------------------- Method: #config (Resque::Pool::Dynamic)
                            (Defined in: lib/resque/pool/dynamic/process.rb)
        dynamic.config -> Hash 
        dynamic.config(opts) -> Hash 
    ------------------------------------------------------------------------
        Note: Default configuration is taken from environment variable
        "WORKERS", as interpreted by the #parse_config_string method.
    Examples:
    ---------
        # config
        #=> {"foo"=>1, "bar"=>2}
        config :foo => 2, :baz => 7
        #=> {"foo"=>2, "baz"=>7, "bar"=>2}
        config :bar => 0
        #=> {"foo"=>2, "baz"=>7}
    Overloads:
    ----------
    ------------------------------------------------------------------------
        dynamic.config -> Hash 
    ------------------------------------------------------------------------
            Show current workers configuration 
        Returns:
        --------
            (Hash) - 
    ------------------------------------------------------------------------
        dynamic.config(opts) -> Hash 
    ------------------------------------------------------------------------
            Update workers configuration. If configuration has change and
            resque-pool is running, it is reloaded. 
        Parameters:
        -----------
            (Hash) opts - Dictionary of worker process counts to update
            (pass 0 or nil as value to delete all workers for a queue from pool)
        Returns:
        --------
            (Hash) - Updated config
    >> _

The built-in help is autogenerated from Yard documentation on methods;
if you're curious, look into the Rakefile for details.

## Rake task documentation

    $ bundle exec rake -D resque:pool:dynamic
    rake resque:pool:dynamic
        Starts a dynamic pool of Resque worker processes.
        
        Variables:
        WORKERS=worker spec - specify initial numbers of workers
                              (look below for format description)
        NO_START=1 - don't start resque-pool master automatically
                     (default is to start)
        
        Workers spec format:
        queue_name=process_number[:queue_name=process_number[:...]]
        
        queue_name can be whatever resque:work will accept as QUEUE=
        parameter.
        
        Example:
        $ rake resque:pool:dynamic WORKERS=foo=1:bar=1:baz,quux,xyzzy=5:*=2
        will start:
         - one worker for queue 'foo'
         - one worker for queue 'bar'
         - five workers for queues baz,quux,xyzzy
         - two workers for all queues

## API and code structure

The Rake task, defined in `resque/pool/dynamic/tasks.rb`, is a
one-liner calling out to `Resque::Pool::Dynamic.shell`, which starts
the command line interface.

The CLI itself, defined in `resque/pool/dynamic/shell.rb`, is a thin
layer (8 lines of code + Ripl UI tweaks) over an instance of the
`Resque::Pool::Dynamic` class.

The workhorse `Resque::Pool::Dynamic` class is defined in
`resque/pool/dynamic.rb`. It can be easily instantiated in the code
independent from the CLI; the CLI commands are just instance methods
you can call then.

### Ideas

Besides interactive, supervised work, `Resque::Pool::Dynamic` can be
used separately from the UI for dynamic, reactive management of
workers, implementing some kind of autoscaling and load distribution
logic.

It can be used during load tests to automatically optimize best number
of workers for maximum processing speed, while keeping load average
and memory or CPU usage goals.

It may also react to queue depths, e.g. temporarily reallocating idle
workers to overloaded queues or shutting them down to conserve memory,
or actively managing sudden short peak usage by stopping other workers
and switching them to peaking queue.

It may also simply allocate workers dynamically based on time of day,
to e.g. have more workers performing UI-related task in the day, which
increases perceived responsiveness, and switch them to process
long-running reports overnight when there are less users.

## Detailed documentation and source code

 - http://rubydoc.info/github/mpasternacki/resque-pool-dynamic
 - http://github.com/mpasternacki/resque-pool-dynamic
