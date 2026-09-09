class ProductImportJob < ApplicationJob
  include Trackable

  queue_as :default

  def perform(task_id, organisation_id:, csv_content:, column_mapping:, col_sep: ",", zip_path: nil, images_dir: nil, photo_mode: "append", form_category_id: nil)
    find_task(task_id)
    organisation = Organisation.find(organisation_id)

    service = ProductImportService.new(
      organisation: organisation,
      csv_content: csv_content,
      column_mapping: column_mapping,
      col_sep: col_sep,
      zip_path: zip_path,
      images_dir: images_dir,
      photo_mode: photo_mode,
      form_category_id: form_category_id,
      on_progress: ->(processed, total) { update_progress(processed, total) }
    )
    result = service.call

    save_result({ stats: result.to_h.except(:errors), errors: result.errors })
  ensure
    File.delete(zip_path) if zip_path && File.exist?(zip_path)
    FileUtils.rm_rf(images_dir) if images_dir && File.exist?(images_dir)
  end
end
