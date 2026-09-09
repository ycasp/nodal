require "test_helper"

class Bo::AutomationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @organisation = Organisation.create!(name: "Automations Org", currency: "EUR",
                                         timezone: "Europe/Lisbon", low_stock_threshold: 5)
    @owner = Member.create!(email: "auto-owner@example.com", password: "password123",
                            first_name: "Owner", last_name: "One")
    @organisation.org_members.create!(member: @owner, role: "owner", active: true)
  end

  def plain_member
    member = Member.create!(email: "auto-plain@example.com", password: "password123",
                            first_name: "Plain", last_name: "Member")
    @organisation.org_members.create!(member: member, role: "member", active: true)
    member
  end

  def valid_params(overrides = {})
    {
      name: "Rupturas da semana",
      kind: "out_of_stock_digest",
      schedule_kind: "weekly",
      schedule_day: "5",
      schedule_hour: "9",
      skip_if_empty: "1",
      external_emails_text: "fornecedor@exemplo.pt, comercial@exemplo.pt"
    }.merge(overrides)
  end

  def create_automation
    Automation.create!(
      organisation: @organisation, name: "Existente", kind: "out_of_stock_digest",
      schedule_kind: "weekly", schedule_day: 5, schedule_hour: 9,
      recipients: { "external_emails" => [ "a@exemplo.pt" ] }
    )
  end

  test "an owner sees the index" do
    sign_in @owner
    get bo_automations_path(org_slug: @organisation.slug)
    assert_response :success
  end

  test "a plain member is not allowed in" do
    sign_in plain_member

    # Pundit's rescue_from is commented out app-wide, so denial surfaces as a
    # raise rather than a redirect. What matters here is that the policy denies.
    assert_raises(Pundit::NotAuthorizedError) do
      get bo_automations_path(org_slug: @organisation.slug)
    end
  end

  test "creating an automation splits the external email list" do
    sign_in @owner

    assert_difference -> { Automation.count }, 1 do
      post bo_automations_path(org_slug: @organisation.slug), params: { automation: valid_params }
    end

    automation = Automation.last
    assert_equal [ "fornecedor@exemplo.pt", "comercial@exemplo.pt" ], automation.external_emails
    assert_not_nil automation.next_run_at
  end

  test "team recipients are stored alongside external ones" do
    sign_in @owner
    org_member = @organisation.org_members.first

    post bo_automations_path(org_slug: @organisation.slug), params: {
      automation: valid_params(recipients: { org_member_ids: [ org_member.id.to_s, "" ] })
    }

    automation = Automation.last
    assert_equal [ org_member.id ], automation.org_member_ids
    assert_equal 2, automation.external_emails.size
  end

  test "multiple suppliers and categories are stored, blanks dropped" do
    sign_in @owner

    post bo_automations_path(org_slug: @organisation.slug), params: {
      automation: valid_params(filters: {
        suppliers: [ "", "Fornecedor A", "Fornecedor B" ],
        category_ids: [ "", "7", "9" ]
      })
    }

    automation = Automation.last
    assert_equal [ "Fornecedor A", "Fornecedor B" ], automation.filters["suppliers"]
    assert_equal [ "7", "9" ], automation.filters["category_ids"]
  end

  test "an invalid automation re-renders instead of blowing up" do
    sign_in @owner

    assert_no_difference -> { Automation.count } do
      post bo_automations_path(org_slug: @organisation.slug),
           params: { automation: valid_params(name: "", external_emails_text: "") }
    end
    assert_response :unprocessable_entity
  end

  test "send now runs the automation without moving the schedule" do
    sign_in @owner
    automation = create_automation
    before = automation.next_run_at

    post run_now_bo_automation_path(org_slug: @organisation.slug, id: automation.id)
    assert_redirected_to bo_automation_path(org_slug: @organisation.slug, id: automation.id)

    automation.reload
    assert_equal 1, automation.automation_runs.count
    assert automation.automation_runs.last.manual?
    assert_equal before.to_i, automation.next_run_at.to_i
    assert_nil automation.last_run_at
  end

  test "toggle flips active" do
    sign_in @owner
    automation = create_automation

    patch toggle_bo_automation_path(org_slug: @organisation.slug, id: automation.id)
    assert_not automation.reload.active

    patch toggle_bo_automation_path(org_slug: @organisation.slug, id: automation.id)
    assert automation.reload.active
  end

  test "the show page lists the run history" do
    sign_in @owner
    automation = create_automation
    automation.automation_runs.create!(organisation: @organisation, status: AutomationRun::COMPLETED,
                                       started_at: 1.hour.ago, completed_at: 1.hour.ago, rows_count: 3)

    get bo_automation_path(org_slug: @organisation.slug, id: automation.id)
    assert_response :success
  end

  test "another organisation's automation is not reachable" do
    other_org = Organisation.create!(name: "Other Org", currency: "EUR")
    other = Automation.create!(organisation: other_org, name: "Alheio", kind: "out_of_stock_digest",
                               schedule_kind: "weekly", schedule_day: 1, schedule_hour: 9,
                               recipients: { "external_emails" => [ "x@exemplo.pt" ] })
    sign_in @owner

    get bo_automation_path(org_slug: @organisation.slug, id: other.id)
    assert_response :not_found
  end

  test "the new and edit forms render" do
    sign_in @owner
    get new_bo_automation_path(org_slug: @organisation.slug)
    assert_response :success

    get edit_bo_automation_path(org_slug: @organisation.slug, id: create_automation.id)
    assert_response :success
  end
end
