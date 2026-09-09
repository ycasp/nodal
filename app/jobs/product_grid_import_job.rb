class ProductGridImportJob < ApplicationJob
  include Trackable

  queue_as :default

  def perform(task_id, organisation_id:, rows:, zip_path: nil, images_dir: nil, photo_mode: "append")
    find_task(task_id)
    organisation = Organisation.find(organisation_id)

    update_progress(0, rows.size)

    service = ProductGridImportService.new(
      organisation: organisation,
      rows: rows,
      zip_path: zip_path,
      images_dir: images_dir,
      photo_mode: photo_mode
    )
    result = service.call

    save_result({ stats: result.to_h.except(:errors), errors: result.errors })
    update_progress(rows.size)
  ensure
    File.delete(zip_path) if zip_path && File.exist?(zip_path)
    FileUtils.rm_rf(images_dir) if images_dir && File.exist?(images_dir)
  end
end
