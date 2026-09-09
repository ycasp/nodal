module Automations
  # Executes one Automation: computes the period, runs the report, sends the
  # digest and records an AutomationRun either way.
  #
  # Lives outside the job so it can be tested — and re-run from the BO's "send
  # now" button — without going through the queue.
  class Runner
    def initialize(automation)
      @automation = automation
      @organisation = automation.organisation
    end

    # `manual: true` is the BO's "send now": it delivers the same digest but
    # deliberately does NOT move last_run_at/next_run_at. Testing a digest must
    # not eat the content of the next scheduled one.
    def call(manual: false)
      period = @automation.period_for
      run = start_run(period, manual)

      report = @automation.report
      raise "Unknown automation kind: #{@automation.kind}" if report.nil?

      # The report's column labels are part of the digest, and they are
      # resolved here rather than inside the mailer's own with_locale block.
      # Without this the table header comes out in the ambient locale (English,
      # in a background job) while the body renders in the org's — one email,
      # two languages.
      I18n.with_locale(@organisation.default_locale) do
        rows = report.rows(period)
        recipients = @automation.recipient_emails

        reason = skip_reason(rows, recipients)
        if reason
          finish(run, AutomationRun::SKIPPED, rows: rows, recipients: recipients, skip_reason: reason)
        else
          deliver(report, rows, recipients, period)
          finish(run, AutomationRun::COMPLETED, rows: rows, recipients: recipients)
        end
      end

      advance_schedule! unless manual
      run
    rescue StandardError => e
      Rails.logger.error("[Automations::Runner] #{@automation.id} failed: #{e.class}: #{e.message}")
      run&.update(status: AutomationRun::FAILED, completed_at: Time.current, error_message: "#{e.class}: #{e.message}")
      # The schedule still advances on failure, otherwise a permanently broken
      # automation is retried by the dispatcher every 15 minutes forever.
      advance_schedule! unless manual
      run
    end

    private

    def start_run(period, manual)
      @automation.automation_runs.create!(
        organisation: @organisation,
        status: AutomationRun::RUNNING,
        manual: manual,
        started_at: Time.current,
        period_start: period.first,
        period_end: period.last
      )
    end

    def skip_reason(rows, recipients)
      return AutomationRun::SKIP_NO_RECIPIENTS if recipients.empty?
      return AutomationRun::SKIP_EMPTY if rows.empty? && @automation.skip_if_empty?

      nil
    end

    def deliver(report, rows, recipients, period)
      AutomationMailer.with(
        automation: @automation,
        organisation: @organisation,
        columns: report.columns,
        rows: rows,
        period: period,
        recipients: recipients
      ).digest.deliver_now
    end

    def finish(run, status, rows:, recipients:, skip_reason: nil)
      run.update!(
        status: status,
        completed_at: Time.current,
        rows_count: rows.size,
        recipients_count: status == AutomationRun::COMPLETED ? recipients.size : 0,
        skip_reason: skip_reason
      )
    end

    def advance_schedule!
      @automation.update_columns(
        last_run_at: Time.current,
        next_run_at: @automation.compute_next_run_at
      )
    end
  end
end
