require 'pathname'
require 'json'

require 'ripl'

require 'resque/pool/dynamic'

module Resque
  class Pool
    # Add-on to resque-pool to allow manually controlled, dynamic sessions
    class Dynamic
      # Run a dynamic resque pool session.
      # @param [Hash] options Options passed to the Shell instance
      # @option opts [String] :no_start Don't start resque-pool automatically
      def self.shell(options={})
        myself = self.new
        myself.start unless options[:no_start]
        myself.status
        Shell.run(myself, options)
        puts "\nBye!"
      ensure
        myself.stop if myself
      end

      # Ripl shell subclassed for nicer CLI experience
      class Shell < Ripl::Shell
        # When printing error, cut backtrace at (ripl)
        def print_eval_error(e)
          i = e.backtrace.index { |ln| ln =~ /\(ripl\):\d+:in `run'/ }
          if not i
            bt = e.backtrace
          elsif i > 0
            bt = e.backtrace[0..i-1]
          else
            bt = []
          end
          bt = bt.map { |ln| "  " << ln }.join("\n")
          puts "ERROR: #{e.to_s}\n#{bt}"
        end

        # Don't print nil return values
        def print_result(result)
          super if @error_raised or !result.nil?
        end

        # Show help
        # @param [String] subject Topic to display
        def help(subject=nil)
          @help ||= File.open(
            Pathname.new(__FILE__).dirname.join('help.json')
            ) { |f| JSON::load(f.read) }
          if subject
            if @help.has_key?(subject)
              puts @help[subject]['full']
              return
            end
            puts "I don't know anything about #{subject}."
          end
          puts "Known commands:"
          @help.keys.sort.each do |cmd|
            puts "  #{cmd} - #{@help[cmd]['summary']}"
          end
          puts "For details, type: help command"
        end

        # Handle help as special command
        # @param [String] input Input string
        def eval_input(input)
          splut = input.split(/\s+/,2)
          if splut.first == 'help'
            help(splut[1])
          else
            super
          end
        end

        # Run the Ripl shell in context of specified instance
        # @param [Object] instance Instance to get bindings from
        # @param [Hash] opts Options passed to Ripl::Shell
        def self.run(instance, opts={})
          options = {
            :readline => true, 
            :riplrc => ENV['RIPL_RC'] || '~/.riplrc',
            :completion => {},
            :binding => instance.instance_eval { binding }
          }
          options.update(opts)
          Ripl::Runner::load_rc(options[:riplrc]) if options[:riplrc]!=''
          create(options).loop
        end
      end

      ### Utility functions

      # Loop, providing index to the block
      # @yield [i] Ever increasing index
      def loop_with_index
        index = 0
        loop do
          yield(index)
          index += 1
        end
      end
    end
  end
end
