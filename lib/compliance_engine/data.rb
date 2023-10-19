# frozen_string_literal: true

require 'compliance_engine'

# Work with compliance data
class ComplianceEngine::Data
  # @param [Array<String>] paths The paths to the compliance data files
  def initialize(*paths)
    @data ||= {}
    open(*paths) unless paths.nil? || paths.empty?
  end

  attr_accessor :data

  # Scan paths for compliance data files
  #
  # @param [Array<String>] paths The paths to the compliance data files
  def open(*paths)
    paths.each do |path|
      if File.directory?(path)
        # In this directory, we want to look for all yaml and json files
        # under SIMP/compliance_profiles and simp/compliance_profiles.
        globs = ['SIMP/compliance_profiles', 'simp/compliance_profiles']
                .select { |dir| Dir.exist?("#{path}/#{dir}") }
                .map { |dir|
          ['yaml', 'json'].map { |type| "#{path}/#{dir}/**/*.#{type}" }
        }.flatten
        # debug "Globs: #{globs}"
        Dir.glob(globs) do |file|
          update(file)
        end
      elsif File.file?(path)
        update(path)
      else
        raise ComplianceEngine::Error, "Could not find path '#{path}'"
      end
    end
  end

  # Update the data for a given file
  #
  # @param [String] file The path to the compliance data file
  def update(file)
    # If we've already scanned this file, and the size and modification
    # time of the file haven't changed, skip it.
    size = File.size(file)
    mtime = File.mtime(file)
    if data.key?(file) && data[file][:size] == size && data[file][:mtime] == mtime
      return
    end

    data[file] = {
      size: size,
      mtime: mtime,
    }

    begin
      data[file][:content] = parse(file)
    rescue => e
      warn e.message
    end
  end

  # Get a list of files with compliance data
  #
  # @return [Array<String>]
  def files
    return @files unless @files.nil?
    @files = data.select { |_file, data| data.key?(:content) }.keys
  end

  # Get the compliance data for a given file
  #
  # @param [String] file The path to the compliance data file
  # @return [Hash]
  def get(file)
    data[file][:content]
  rescue
    nil
  end

  private

  # Parse YAML or JSON files
  #
  # @param [String] file The path to the compliance data file
  def parse(file)
    contents = if File.extname(file) == '.json'
                 require 'json'
                 JSON.parse(File.read(file))
               else
                 require 'yaml'
                 YAML.safe_load(File.read(file))
               end
    # The top-level key version must be present and must equal 2.0.0.
    raise ComplianceEngine::Error, "File must contain a hash, found #{contents.class} in #{file}" unless contents.is_a?(Hash)
    raise ComplianceEngine::Error, "Missing version in #{file}" unless contents.key?('version')
    raise ComplianceEngine::Error, "version must be 2.0.0, found '#{contents['version']}' in #{file}" unless contents['version'] == '2.0.0'
    contents
  end

  # Print debugging messages to the console.
  #
  # @param [String] msg The message to print
  def debug(msg)
    warn msg
  end
end
