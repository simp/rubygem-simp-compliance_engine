# frozen_string_literal: true

require 'compliance_engine'

class ComplianceEngine::Data
  def initialize(paths = [Dir.pwd])
    @data ||= {}
    paths.each do |path|
      if File.directory?(path)
        # In this directory, we want to look for all yaml and json files
        # under SIMP/compliance_profiles and simp/compliance_profiles.
        globs = ['SIMP/compliance_profiles', 'simp/compliance_profiles']
                .select { |dir| Dir.exist?("#{path}/#{dir}") }
                .map { |dir|
          ['yaml', 'json'].map { |type| "#{path}/#{dir}/**/*.#{type}" }
        }.flatten
        debug "Globs: #{globs}"
        Dir.glob(globs) do |file|
          update(file)
        end
      elsif File.file?(path)
        update(path)
      else
        raise Error, "Could not find #{path}"
      end
    end
  end

  # Update the data for a given file.
  def update(file)
    # If we've already scanned this file, and the size and modification
    # time of the file haven't changed, skip it.
    size = File.size(file)
    mtime = File.mtime(file)
    if @data.key?(file) && @data[file][:size] == size && @data[file][:mtime] == mtime
      return
    end

    begin
      @data[file] = {
        size: size,
        mtime: mtime,
        content: parse(file),
      }
    rescue => e
      warn e
    end
  end

  # Parse YAML or JSON files.
  def parse(file)
    if File.extname(file) == '.json'
      JSON.parse(File.read(file))
    else
      YAML.safe_load(File.read(file))
    end
  end

  # Print debugging messages to the console.
  def debug(msg)
    warn msg
  end
end
