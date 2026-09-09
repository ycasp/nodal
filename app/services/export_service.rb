require "csv"

class ExportService
  def initialize(records:, columns:, format:)
    @records = records
    @columns = columns
    @format = format.to_sym
  end

  def call
    case @format
    when :xlsx
      generate_xlsx
    else
      generate_csv
    end
  end

  private

  def generate_csv
    data = CSV.generate("\xEF\xBB\xBF") do |csv|
      csv << @columns.map { |c| c[:label] }
      @records.each do |record|
        csv << @columns.map { |c| c[:value].call(record) }
      end
    end

    { data: data, content_type: "text/csv; charset=utf-8" }
  end

  def generate_xlsx
    require "caxlsx"
    package = Axlsx::Package.new
    workbook = package.workbook

    bold = workbook.styles.add_style(b: true)

    workbook.add_worksheet(name: "Export") do |sheet|
      sheet.add_row @columns.map { |c| c[:label] }, style: bold
      @records.each do |record|
        sheet.add_row @columns.map { |c| c[:value].call(record) }
      end
    end

    { data: package.to_stream.read, content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" }
  end
end
