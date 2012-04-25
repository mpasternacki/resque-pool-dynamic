
desc <<EOF
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
EOF
task "resque:pool:dynamic" do
  require 'resque/pool/dynamic/shell'

  Resque::Pool::Dynamic.shell(:no_start => ENV['NO_START'])
end
