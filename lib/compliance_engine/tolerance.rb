# frozen_string_literal: true

module ComplianceEngine
  # Named constants for enforcement tolerance levels.
  #
  # The enforcement tolerance controls which remediation risk levels are
  # enforced. A check whose risk level is greater than or equal to the
  # tolerance value is filtered out. For example, setting
  # +enforcement_tolerance+ to +ComplianceEngine::Tolerance::MODERATE+
  # enforces checks with risk levels below 60 while skipping anything
  # rated MODERATE (60) or higher.
  module Tolerance
    # Enforce only checks with no meaningful risk (risk < 20).
    NONE = 20

    # Enforce checks up to and including low-risk remediations (risk < 40).
    SAFE = 40

    # Enforce checks up to and including moderate-risk remediations (risk < 60).
    MODERATE = 60

    # Enforce checks up to and including remediations that affect access (risk < 80).
    ACCESS = 80

    # Enforce all checks, including those that may cause breaking changes (risk < 100).
    BREAKING = 100
  end
end
