require 'tempfile'
require 'yaml'

require "resque/pool/dynamic/version"
require "resque/pool/dynamic/logfile"

module Resque
  class Pool
    class Dynamic
      # PID of the resque-pool process, or nil if it's not running
      # @return [Integer, NilClass]
      # @api cli
      attr_reader :pid

      def initialize
        # Make myself a project group leader
        Process.setpgid(0, 0)
      end

      # Tempfile instance for configuration file
      # @return [Tempfile]
      def config_tempfile
        @config_tempfile ||= Tempfile.new(%w(resque-pool-dynamic .yaml))
      end

      # Path to the temporary config file
      # @return [String]
      # @api cli
      def config_path
        config_tempfile.path
      end

      # Parse workers configuration
      # @param [String] spec Workers specification string
      #   Format: queue2=number:queue2=number2:queue3,queue5=number4:*=number5
      # @return [Hash] Configuration dictionary
      # @example
      #   parse_config_string('foo=1:bar=2:baz,quux=4')
      #   #=> {"baz,quux"=>4, "foo"=>1, "bar"=>2}
      def parse_config_string(spec)
        return {} unless spec
        Hash[ 
          spec.split(':').map { |w|
            k, v = w.split('=') ; [ k, v.to_i ] } 
        ]
      end

      # @overload config
      #   Show current workers configuration
      #   @return [Hash]
      # @overload config(opts)
      #   Update workers configuration.
      #   If configuration has change and resque-pool is running, it is reloaded.
      #   @param [Hash] opts Dictionary of worker process counts to update
      #     (pass 0 or nil as value to delete all workers for a queue from pool)
      #   @return [Hash] Updated config
      # @note Default configuration is taken from environment variable
      #   "WORKERS", as interpreted by the #parse_config_string method.
      # @example config
      #   #=> {"foo"=>1, "bar"=>2}
      #   config :foo => 2, :baz => 7
      #   #=> {"foo"=>2, "baz"=>7, "bar"=>2}
      #   config :bar => 0
      #   #=> {"foo"=>2, "baz"=>7}
      # @api cli
      def config(args=nil)
        @config ||= parse_config_string(ENV['WORKERS'])

        if args
          oldconfig = config.clone

          args.each do |w, n|
            w = w.to_s
            if n.nil? || n==0
              @config.delete w
            else
              @config[w] = n
            end
          end

          if pid && @config != oldconfig
            write_config
            reload
          end
        end

        @config
      end

      # Write temporary configuration file
      # @api cli
      def write_config
        File.open(config_path, 'w') do |cf|
          cf.write(YAML::dump(config))
        end
      end

      # Start resque-pool master
      # This is executed in a forked child process.
      def run_pool
        @pid = $$
        ENV["RESQUE_POOL_CONFIG"] = config_path

        $stdin.reopen '/dev/null'
        log = File.new(log_path, "a")
        $stdout.reopen log
        $stderr.reopen log
        $stdout.sync = $stderr.sync = true

        require 'rake'
        Rake::Task['resque:pool'].invoke 
      end

      # Fork a child process for resque-pool master
      # @return [Integer] PID of the child process
      # @api cli
      def start!
        raise "Already running: #{pid}" if pid
        write_config
        @pid = fork { self.run_pool }
        Process.setpgid(pid, 0) # don't broadcast ^C to child

        if 30.times { |i| sleep 1 ; break if File.exist? log_path }
          # Loop will return nil if broken. If value is returned, file does not exist.
          raise "Log file #{log_path} still not present after #{i} seconds, giving up"
          stop!
        end

        pid
      end

      # Start resque-pool, showing startup logs
      # @api cli
      def start
        unless pid
          start!
          log.rewind
          log.tail_until /started manager/
        else
          warn "Already started as #{pid}"
        end
      end

      # Return pid of running resque-pool or raise an exception
      # @return [Integer]
      # @raise [RuntimeError]
      def pid!
        pid or raise "Not started!"
      end

      # Send signal to a running resque-pool
      # @param [String, Integer] sig Signal name or number
      # @api cli
      def kill!(sig)
        Process.kill(sig, pid!)
      end

      # Stop running resque-pool
      # @api cli
      def stop!
        if pid
          kill! "INT"
          wpid, status = Process.wait2(pid)
          @pid = nil
          status
        end
      end

      # Stop running resque-pool, show shutdown logs
      # @api cli
      def stop
        puts "Shutting down resque-pool-master #{pid}"
        log.ff if has_log?
        status = stop!
        log.tail if has_log?
        return status
      end

      # Reload resque-pool configuration
      # @api cli
      def reload
        puts "Reloading resque-pool-master #{pid!} configuration"
        write_config
        kill!('HUP')
      end

      # Show child process tree by calling `pstree` system command
      # @api cli
      def pstree
        system case RUBY_PLATFORM
               when /darwin/
                 "pstree -w #{pid!}"
               when /linux/
                 "pstree -l -a -p #{pid!}"
               else
                 "pstree #{pid!}"
               end
        nil
      end

      # Show current status
      # @api cli
      def status
        puts( '',
          "Status: " << ( pid ? "running, pid: #{pid}" : "not running" ),
          "Configuration:",
          YAML::dump(config).lines.grep(/^(?!---\s*$)/).map { |v| "  " << v }
          )
        if pid
          puts "Process tree:"
          pstree
        end
        puts
      end
    end
  end
end
