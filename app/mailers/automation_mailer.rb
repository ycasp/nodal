require "csv"

class AutomationMailer < ApplicationMailer
  include OrgEmailDefaults

  helper :application

  # The default "mailer" layout hard-codes the Nodal logo; this one renders the
  # organisation's own logo (falling back to its name). It is not
  # customer-specific despite the name — reused rather than duplicated.
  layout "customer_mailer"

  # Generic digest: the table is driven by the report's `columns`, so a new
  # automation type needs no new template.
  #
  # Deliberately link-free. Recipients can be external (a supplier, a rep's
  # personal address) and have no BO login — a "view in Nodal" button would
  # dead-end on a sign-in screen. The email carries the whole table, plus a CSV
  # attachment for whoever wants to work it in a spreadsheet.
  def digest
    @automation   = params[:automation]
    @organisation = params[:organisation]
    @columns      = params[:columns]
    @rows         = params[:rows]
    @period       = params[:period]
    recipients    = params[:recipients]

    unless EmailDeliveryGuard.should_send?(organisation: @organisation, email_type: "automation_digest")
      log_skipped(@organisation, "automation_digest", recipients.join(", "))
      return
    end

    I18n.with_locale(@organisation.default_locale) do
      attach_csv if @rows.any?

      subject = t("mailers.automation_mailer.digest.subject",
                  name: @automation.name,
                  period: @automation.period_label(@period),
                  organisation: @organisation.name)

      # bcc, not to: external recipients must not see each other's addresses,
      # and a supplier has no business reading the internal distribution list.
      mail_with_org_defaults(
        @organisation,
        to: @organisation.email_from_address,
        bcc: recipients,
        subject: subject
      )
    end
  end

  private

  def logged_email_type = "automation_digest"

  def attach_csv
    filename = [
      @automation.name.parameterize,
      @period.last.in_time_zone(@automation.time_zone).strftime("%Y-%m-%d")
    ].join("-") + ".csv"

    # Same BOM as ExportService: without it Excel mangles the accents.
    attachments[filename] = {
      mime_type: "text/csv; charset=utf-8",
      content: CSV.generate("\xEF\xBB\xBF") { |csv|
        csv << @columns.map { |column| column[:label] }
        @rows.each do |row|
          csv << @columns.map { |column| csv_value(row[column[:key]]) }
        end
      }
    }
  end

  def csv_value(value)
    return I18n.l(value.in_time_zone(@automation.time_zone), format: :short) if value.is_a?(Time) ||
                                                                               value.is_a?(ActiveSupport::TimeWithZone)

    value
  end
end
