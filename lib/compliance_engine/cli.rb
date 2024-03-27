# frozen_string_literal: true

require 'compliance_engine'
require 'optparse'

# Compliance Engine CLI
class ComplianceEngine::CLI
  def initialize(args)
    # Immediately return with an exit value if options
    # include --help or --version.
    return options(args) if options(args).is_a?(Integer)

    # Otherwise, run the CLI with `data` as the
    # object containing the compliance data.
    data = ComplianceEngine::Data.new(*args)
    require 'irb'
    # rubocop:disable Lint/Debugger
    binding.irb
    # rubocop:enable Lint/Debugger
  end

  private

  def usage
    "Usage: #{File.basename($PROGRAM_NAME)} [options] path [path ...]"
  end

  def parse_options(args)
    o = {}

    opts = OptionParser.new do |opt|
      opt.banner = usage

      opt.on('-h', '--help', 'Prints this help') do
        puts opt
        return 0
      end

      opt.on('-v', '--version', 'Prints the version') do
        puts ComplianceEngine::VERSION
        return 0
      end
    end

    begin
      opts.parse!(args)
    rescue OptionParser::ParseError => e
      warn e
      warn opts
      return 1
    end

    o
  end

  def options(args)
    @options ||= parse_options(args)
  end
end
