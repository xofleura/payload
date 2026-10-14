require "fileutils"
require_relative "ui"

module Payload
  class Project
    def self.create(name)
      unless name.match?(/\A[a-zA-Z][a-zA-Z0-9_-]*\z/)
        raise "invalid project name '#{name}'"
      end

      raise "destination '#{name}' already exists" if File.exist?(name)

      root = File.expand_path(name)

      FileUtils.mkdir_p(File.join(root, "src"))
      FileUtils.mkdir_p(File.join(root, "test"))

      File.write(File.join(root, "payload.toml"), <<~TOML)
        [package]
        name = "#{name}"
        version = "0.1.0"
        ruby = ">= 3.0"

        [dependencies]
      TOML

      File.write(File.join(root, "src", "message.rb"), <<~'RUBY')
        module Message
          TEXT = "So, someone wanted to know what I use C for. I use it to download GCC to compile Ruby. What do you use Internet Explorer for? You use Internet Explorer to download Firefox. There you have it. "

          def self.print
            puts TEXT
          end

          def self.word_count
            TEXT.split.size
          end

          def self.character_count
            TEXT.length
          end
        end
      RUBY

      File.write(File.join(root, "src", "main.rb"), <<~'RUBY')
        require_relative "message"

        Message.print
      RUBY

      File.write(File.join(root, "test", "message_test.rb"), <<~'RUBY')
        require "minitest/autorun"
        require "stringio"
        require_relative "../src/message"

        class MessageTest < Minitest::Test
          def test_message_contains_the_expected_text
            assert_equal(
              "So, someone wanted to know what I use C for. I use it to download GCC to compile Ruby. What do you use Internet Explorer for? You use Internet Explorer to download Firefox. There you have it. ",
              Message::TEXT
            )
          end

          def test_print_outputs_the_message
            output = StringIO.new

            original_stdout = $stdout
            $stdout = output

            Message.print
          ensure
            $stdout = original_stdout
            assert_equal("#{Message::TEXT}\n", output.string)
          end

          def test_word_count
            assert_equal(Message::TEXT.split.size, Message.word_count)
            assert_operator Message.word_count, :>, 0
          end

          def test_character_count
            assert_equal(Message::TEXT.length, Message.character_count)
            assert_operator Message.character_count, :>, Message.word_count
          end

          def test_message_mentions_gcc_and_ruby
            assert_includes Message::TEXT, "GCC"
            assert_includes Message::TEXT, "Ruby"
          end

          def test_message_mentions_internet_explorer_and_firefox
            assert_includes Message::TEXT, "Internet Explorer"
            assert_includes Message::TEXT, "Firefox"
          end
        end
      RUBY

      File.write(File.join(root, ".gitignore"), <<~IGNORE)
        /build/
        /vendor/
        /payload.lock
      IGNORE

      UI.info("created project #{name}")
      puts "  #{UI.color("└─", UI::DIM)} cd #{name}"
      puts "     #{UI.color("└─", UI::DIM)} payload run"
    end
  end
end
