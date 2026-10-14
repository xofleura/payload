module Payload
  class Manifest
    attr_reader :data, :root

    def initialize(root = Dir.pwd)
      @root = File.expand_path(root)
      @path = File.join(@root, "payload.toml")
      @data = {}
    end

    def load
      unless File.file?(@path)
        raise "could not find payload.toml"
      end

      section = nil

      File.foreach(@path) do |line|
        line = line.strip

        next if line.empty?

        if line.match?(/\A\[[a-zA-Z_]+\]\z/)
          section = line[1..-2]
          @data[section] ||= {}
          next
        end

        match = line.match(/\A([a-zA-Z_][a-zA-Z0-9_-]*)\s*=\s*"([^"]*)"\z/)

        unless match
          raise "invalid manifest syntax: #{line}"
        end

        unless section
          raise "manifest values must belong to a section"
        end

        @data[section][match[1]] = match[2]
      end

      validate
      self
    end

    def name
      @data.dig("package", "name")
    end

    def version
      @data.dig("package", "version")
    end

    def source
      File.join(@root, "src", "main.rb")
    end

    def validate
      package = @data["package"]

      raise "missing [package] section" unless package
      raise "missing package name" unless package["name"]
      raise "missing package version" unless package["version"]
      raise "invalid package name" unless package["name"].match?(/\A[a-zA-Z][a-zA-Z0-9_-]*\z/)
      raise "missing source file: src/main.rb" unless File.file?(source)

      true
    end
  end
end
