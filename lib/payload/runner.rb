require "fileutils"
require "rbconfig"
require "open3"
require "rubygems/package"
require "zlib"
require_relative "manifest"
require_relative "ui"

module Payload
  class Runner
    def initialize(root = Dir.pwd)
      @root = File.expand_path(root)
      @manifest = nil
    end

    def run
      progress = UI::Progress.new("run", package_name)
      output = +""
      status = nil

      begin
        progress.step("validate manifest") do
          load_manifest
        end

        progress.step("launch Ruby interpreter") do
          output, status = Open3.capture2e(
            RbConfig.ruby,
            @manifest.source,
            chdir: @root
          )
        end
      ensure
        progress.finish
      end

      unless output.empty?
        puts
        print output
        puts unless output.end_with?("\n")
      end

      exit(status.exitstatus || 1) unless status&.success?
    end

    def check
      progress = UI::Progress.new("check", package_name)

      begin
        progress.step("validate manifest") do
          load_manifest
        end

        progress.step("check Ruby syntax") do
          rubyFiles.each do |file|
            RubyVM::InstructionSequence.compile_file(file)
          end
        end
      ensure
        progress.finish
      end
    end

    def test
      progress = UI::Progress.new("test", package_name)

      begin
        progress.step("validate manifest") do
          load_manifest
        end

        tests = Dir.glob(File.join(@root, "test", "**", "*_test.rb")).sort

        if tests.empty?
          progress.step("discover tests") do
            UI.info("no tests found in test/**/*_test.rb")
          end
        else
          tests.each do |testFile|
            relativePath = testFile.delete_prefix("#{@root}/")

            progress.step("run #{relativePath}") do
              output, status = Open3.capture2e(
                RbConfig.ruby,
                testFile,
                chdir: @root
              )

              unless status.success?
                print output unless output.empty?
                raise "test failed: #{relativePath}"
              end

              print output unless output.empty?
            end
          end
        end
      ensure
        progress.finish
      end
    end

    def build
      progress = UI::Progress.new("build", package_name)

      begin
        progress.step("validate manifest") do
          load_manifest
        end

        progress.step("check Ruby syntax") do
          rubyFiles.each do |file|
            RubyVM::InstructionSequence.compile_file(file)
          end
        end

        progress.step("stage package files") do
          stagePackage
        end
      ensure
        progress.finish
      end

      puts "#{UI.color("Output:", UI::DIM)} #{buildDirectory}"
    end

    def package
      build

      progress = UI::Progress.new("package", package_name)
      archivePath = nil

      begin
        progress.step("validate staged files") do
          raise "build output not found" unless File.directory?(buildDirectory)

          manifestPath = File.join(buildDirectory, "payload.toml")
          raise "staged manifest not found" unless File.file?(manifestPath)
        end

        progress.step("create compressed archive") do
          archivePath = createArchive
        end
      ensure
        progress.finish
      end

      puts "#{UI.color("Output:", UI::DIM)} #{archivePath}"
    end

    def clean
      progress = UI::Progress.new("clean", package_name)

      begin
        progress.step("remove build artifacts") do
          FileUtils.rm_rf(File.join(@root, "build"))
        end
      ensure
        progress.finish
      end
    end

    private

    def package_name
      return @manifest.name if @manifest

      manifestPath = File.join(@root, "payload.toml")

      if File.file?(manifestPath)
        inPackageSection = false

        File.foreach(manifestPath) do |line|
          stripped = line.strip

          if stripped.match?(/\A\[[^\]]+\]\z/)
            inPackageSection = stripped == "[package]"
            next
          end

          next unless inPackageSection

          match = stripped.match(/\Aname\s*=\s*"([^"]+)"/)
          return match[1] if match
        end
      end

      File.basename(@root)
    end

    def load_manifest
      @manifest = Manifest.new(@root).load
    end

    def rubyFiles
      files = Dir.glob([
        File.join(@root, "src", "**", "*.rb"),
        File.join(@root, "test", "**", "*.rb")
      ]).sort

      files.uniq
    end

    def buildDirectory
      File.join(@root, "build", "#{@manifest.name}-#{@manifest.version}")
    end

    def stagePackage
      raise "missing source file: src/main.rb" unless File.file?(@manifest.source)

      FileUtils.rm_rf(buildDirectory)
      FileUtils.mkdir_p(buildDirectory)

      FileUtils.cp(
        File.join(@root, "payload.toml"),
        buildDirectory
      )

      %w[src test].each do |directory|
        sourceDirectory = File.join(@root, directory)
        next unless File.directory?(sourceDirectory)

        FileUtils.cp_r(
          sourceDirectory,
          buildDirectory
        )
      end

      %w[README.md LICENSE].each do |filename|
        sourceFile = File.join(@root, filename)
        next unless File.file?(sourceFile)

        FileUtils.cp(sourceFile, buildDirectory)
      end
    end

    def createArchive
      packageDirectory = buildDirectory
      archiveName = "#{@manifest.name}-#{@manifest.version}.tar.gz"
      archivePath = File.join(@root, "build", archiveName)
      temporaryPath = "#{archivePath}.tmp"

      FileUtils.rm_f(temporaryPath)

      begin
        Zlib::GzipWriter.open(temporaryPath) do |gzip|
          Gem::Package::TarWriter.new(gzip) do |tar|
            rootName = File.basename(packageDirectory)
            tar.mkdir(rootName, 0o755)

            addDirectoryToArchive(
              tar,
              packageDirectory,
              rootName
            )
          end
        end

        File.rename(temporaryPath, archivePath)
      ensure
        FileUtils.rm_f(temporaryPath)
      end

      archivePath
    end

    def addDirectoryToArchive(tar, directory, archivePrefix)
      Dir.children(directory).sort.each do |entry|
        sourcePath = File.join(directory, entry)
        archivePath = "#{archivePrefix}/#{entry}"

        if File.directory?(sourcePath)
          tar.mkdir(archivePath, 0o755)

          addDirectoryToArchive(
            tar,
            sourcePath,
            archivePath
          )
        elsif File.file?(sourcePath)
          mode = File.stat(sourcePath).mode & 0o777
          size = File.size(sourcePath)

          tar.add_file_simple(archivePath, mode, size) do |file|
            File.open(sourcePath, "rb") do |source|
              IO.copy_stream(source, file)
            end
          end
        end
      end
    end
  end
end
