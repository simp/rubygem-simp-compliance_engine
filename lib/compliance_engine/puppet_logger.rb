# frozen_string_literal: true

module ComplianceEngine
  # Routes ComplianceEngine log messages through Puppet's logging system.
  # Used as a drop-in replacement for the default Logger when running inside Puppet.
  class PuppetLogger
    def debug(msg)
      Puppet.debug(msg)
    end

    def info(msg)
      Puppet.info(msg)
    end

    def warn(msg)
      Puppet.warning(msg)
    end

    def error(msg)
      Puppet.err(msg)
    end

    def fatal(msg)
      Puppet.crit(msg)
    end

    def level; end

    def level=(_val); end
  end
end
