require_relative "version"
require_relative "ui"
require_relative "project"
require_relative "runner"

module Payload
  class CLI
    def self.start(args)
      command = args.shift

      case command
      when "--version", "-V", "version"
        puts "payload #{VERSION}"
      when "--help", "-h", "help", nil
        help
      when "new"
        name = args.shift
        raise "expected a project name" unless name

        Project.create(name)
      when "run", "check", "test", "build", "package", "clean"
        Runner.new.public_send(command)
      when "add", "remove", "install", "update"
        raise "dependency management is not implemented yet"
      else
        raise "unknown command '#{command}'. Run 'payload help' for usage."
      end
    rescue Interrupt
      UI.error("interrupted")
      exit 130
    rescue StandardError => error
      UI.error(error.message)
      exit 1
    end

    def self.help
      puts <<~HELP
        payload #{VERSION}
        Ruby package manager

        usage: payload <command>

        commands:
          new <name>          Create a project
          run                 Run the current project
          check               Check project syntax
          test                Run project tests
          build               Prepare distribution files
          package             Create a .tar.gz archive
          clean               Remove generated files
          add <gem> [version] Add a dependency
          remove <gem>        Remove a dependency
          install             Install dependencies
          update [gem]        Update dependencies
          version             Show version
          help                Show help
      HELP
    end
  end
end
