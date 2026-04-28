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

    # Enforce checks below low-risk remediations; skip SAFE (40) and above (risk < 40).
    SAFE = 40

    # Enforce checks below moderate-risk remediations; skip MODERATE (60) and above (risk < 60).
    MODERATE = 60

    # Enforce checks below remediations that affect access; skip ACCESS (80) and above (risk < 80).
    ACCESS = 80

    # Enforce all checks, including those that may cause breaking changes (risk < 100).
    BREAKING = 100
  end
end
