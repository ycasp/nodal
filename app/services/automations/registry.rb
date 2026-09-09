module Automations
  # Maps automations.kind -> report class. Mirrors Erp::AdapterRegistry: adding
  # an automation type is one entry here plus the class.
  class Registry
    REPORTS = [
      Automations::OutOfStockDigest
    ].freeze

    class << self
      def all = REPORTS

      def keys = REPORTS.map { |r| r.key.to_s }

      def find(key) = REPORTS.find { |r| r.key.to_s == key.to_s }

      def build(key, automation:)
        klass = find(key)
        return nil if klass.nil?

        klass.new(organisation: automation.organisation, filters: automation.filters)
      end

      # For the BO form's type picker.
      def options
        REPORTS.map { |r| { key: r.key.to_s, label: r.label, description: r.description } }
      end
    end
  end
end
