require 'io-tail'

module Resque
  class Pool
    class Dynamic
      # Logfile path
      # @return [String] Path to the log file
      # @api cli
      def log_path
        # pid! call will raise an exception if process is not running yet
        @log_path ||= ENV['RESQUE_POOL_LOG'] || "resque-pool.#{pid!}.log"
      end

      # Open log of resque-pool process
      # @return [Logfile] Logfile instance
      # @api cli
      def log
        # pid! call will raise an exception if process is not running yet
        @log ||= Logfile.open(log_path, :pid => pid!)
      end

      # True if we have an open log file
      # @api cli
      def has_log?
        !!@log
      end

      # Slightly customized tailable file class
      class Logfile < IO::Tail::Logfile
        # PID of process that writes the log file
        # @return [Integer, NilClass]
        attr_accessor :pid

        def self.open(filename, opts = {}, &block)
          raise "Need :pid" unless opts.has_key? :pid
          super
        end

        # True if child process is alive
        def alive?
          Process.getpgid(pid) rescue nil
        end

        # Make sure to return on EOF if process is dead
        def restat
          self.return_if_eof = true unless alive?
          super
        end

        # Show last n lines of the file, or follow the file
        # @param [Integer, NilClass] n Number of lines or nil
        # @yield [ln] Called for every line of file
        # @yieldparam [String] ln Input line
        # @api cli
        def tail(n = nil, &block)
          super(n) do |ln|
            $stderr.puts ln
            block.call(ln) if block
          end
        rescue Interrupt => e
          nil
        end

        # Follow the file until a line matches regexp
        # @api cli
        def tail_until(rx)
          self.tail do |ln|
            raise IO::Tail::ReturnException if ln =~ rx
          end
        end

        # Print contents of the file until current end of file
        # @api cli
        def tail_to_eof
          orig_return_if_eof, return_if_eof = return_if_eof, true
          tail
        ensure
          return_if_eof = orig_return_if_eof
        end

        # convenience

        # Fast forward until end of file (see IO::Tail#backward)
        # @api cli
        alias_method :ff, :backward

        # Rewind until beginning of file (see IO::Tail#forward)
        # @api cli
        alias_method :rew, :forward

        # Rewind until beginning of file (see IO::Tail#forward)
        # @api cli
        alias_method :rewind, :forward
      end
    end
  end
end
