# frozen_string_literal: true

module ComplianceEngine
  # Routes ComplianceEngine log messages through Puppet's logging system.
  # Used as a drop-in replacement for the default Logger when running inside Puppet.
  class PuppetLogger
    def initialize(*_args, **_kwargs)
      ensure_puppet_available!
    end

    def debug(msg)
      ensure_puppet_available!
      ::Puppet.debug(msg)
    end

    def info(msg)
      ensure_puppet_available!
      ::Puppet.info(msg)
    end

    def warn(msg)
      ensure_puppet_available!
      ::Puppet.warning(msg)
    end

    def error(msg)
      ensure_puppet_available!
      ::Puppet.err(msg)
    end

    def fatal(msg)
      ensure_puppet_available!
      ::Puppet.crit(msg)
    end

    def level; end

    def level=(_val); end

    private

    def ensure_puppet_available!
      return if defined?(::Puppet)

      raise ComplianceEngine::Error,
            'ComplianceEngine::PuppetLogger requires Puppet to be loaded, but ::Puppet is not defined'
    end
  end
end
