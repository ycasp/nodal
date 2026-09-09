# Preview all emails at http://localhost:3000/rails/mailers/automation_mailer
class AutomationMailerPreview < ActionMailer::Preview
  # Uses a real automation when one exists, otherwise renders an in-memory one
  # over whatever stock events the database has — so the preview works on a
  # fresh dev database too.
  def digest
    organisation = Automation.first&.organisation || Organisation.first
    raise "No organisations found." unless organisation

    automation = Automation.first || Automation.new(
      organisation: organisation,
      name: "Rupturas da semana",
      kind: "out_of_stock_digest",
      schedule_kind: "weekly",
      schedule_day: 5,
      schedule_hour: 9
    )

    period = 7.days.ago..Time.current
    report = Automations::Registry.build(automation.kind, automation: automation)
    rows = report.rows(period)
    rows = sample_rows if rows.empty?

    AutomationMailer.with(
      automation: automation,
      organisation: organisation,
      columns: report.columns,
      rows: rows,
      period: period,
      recipients: [ "fornecedor@exemplo.pt" ]
    ).digest
  end

  private

  def sample_rows
    [
      { sku: "B1380C/00", product: "Anel Prata 925", variant: "Tamanho 16",
        supplier: "Fornecedor A", last_qty: 3, occurred: 2.days.ago },
      { sku: "A301C", product: "Pulseira Bilaminado", variant: nil,
        supplier: "Fornecedor A", last_qty: 1, occurred: 4.days.ago }
    ]
  end
end
