module Payload
  module UI
    RESET = "\e[0m"
    DIM = "\e[2m"
    CYAN = "\e[36m"
    GREEN = "\e[32m"
    RED = "\e[31m"
    YELLOW = "\e[33m"

    def self.color(text, code, stream = $stdout)
      return text unless stream.tty?
      return text if ENV.key?("NO_COLOR")

      "#{code}#{text}#{RESET}"
    end

    def self.info(message)
      puts "#{color("info:", CYAN)} #{message}"
    end

    def self.error(message)
      $stderr.puts "#{color("error:", RED, $stderr)} #{message}"
    end

    def self.step(label, status, elapsed, last: false)
      connector = last ? "└─" : "├─"
      state = status == :success ? "success" : "failure"
      stateColor = status == :success ? GREEN : RED
      prefix = color(connector, DIM)
      name = " #{label} "
      dots = "." * [32 - label.length, 2].max

      puts "#{prefix}#{name}#{color(dots, DIM)} #{color(state, stateColor)} #{color(duration(elapsed), DIM)}"
    end

    def self.duration(seconds)
      if seconds < 1
        "#{(seconds * 1000).round}ms"
      else
        "#{seconds.round(2)}s"
      end
    end

    class Progress
      def initialize(command, package)
        @command = command
        @package = package
        @startedAt = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        @total = 0
        @succeeded = 0
        @finished = false

        puts "#{command} #{package}"
      end

      def step(label, last: false)
        startedAt = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        @total += 1

        begin
          result = yield
          elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - startedAt

          UI.step(label, :success, elapsed, last: last)
          @succeeded += 1

          result
        rescue StandardError
          elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - startedAt
          UI.step(label, :failure, elapsed, last: last)
          raise
        end
      end

      def finish
          return if @finished

  	  @finished = true
 	  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @startedAt

	  puts UI.color("#{@command.capitalize} Summary: #{@succeeded}/#{@total} steps succeeded", DIM)
	  puts "#{UI.color("└─", DIM)} total #{UI.color(UI.duration(elapsed), DIM)}"
      end
    end
  end
end
