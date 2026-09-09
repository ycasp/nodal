class GenerateQuickAccessPdfsJob < ApplicationJob
  queue_as :default

  # Chrome on the web dyno can transiently fail with EAGAIN when memory
  # is tight. Retry a couple of times with backoff so the merchant gets
  # their PDFs without intervention.
  retry_on Grover::JavaScript::Error, wait: :polynomially_longer, attempts: 5
  retry_on Grover::JavaScript::TimeoutError, wait: :polynomially_longer, attempts: 5

  def perform(token_id)
    # Token might have been destroyed between enqueue and execution
    # (e.g. revoke / regenerate landed first). find_by handles that.
    token = QuickAccessToken.find_by(id: token_id)
    return unless token

    QuickAccessToken::PDF_FORMATS.each do |format|
      attachment = token.attached_pdf(format)
      next if attachment.attached?

      pdf_data = QuickAccessPdfRenderer.new(token: token, layout: format).render_pdf
      attachment.attach(
        io: StringIO.new(pdf_data),
        filename: pdf_filename(token, format),
        content_type: "application/pdf"
      )
    end
  end

  private

  def pdf_filename(token, format)
    safe_name = token.customer_user.customer.company_name.to_s.parameterize.presence || "cliente"
    "qr-#{format}-#{safe_name}.pdf"
  end
end
