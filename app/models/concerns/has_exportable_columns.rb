module HasExportableColumns
  extend ActiveSupport::Concern

  class_methods do
    def exportable_columns
      raise NotImplementedError, "#{name} must define exportable_columns"
    end

    def exportable_columns_for(keys)
      return exportable_columns.select { |c| c[:default] } if keys.blank?

      allowed = keys.map(&:to_sym)
      exportable_columns.select { |c| allowed.include?(c[:key]) }
    end
  end
end
