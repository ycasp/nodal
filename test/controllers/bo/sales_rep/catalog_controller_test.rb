require "test_helper"

# Covers the sales-rep catalog PDF entry point: a pure rep can reach the page
# and enqueue a catalog, the task is owned by the rep, non-reps are turned away,
# and a rep can only view/download the background tasks they own.
class Bo::SalesRep::CatalogControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  setup do
    @organisation = Organisation.create!(name: "Catalog Rep Org", currency: "EUR")

    @rep = Member.create!(email: "rep@example.com", password: "password123",
                          first_name: "Rita", last_name: "Rep")
    @organisation.org_members.create!(member: @rep, role: "member", active: true, is_sales_rep: true)

    @admin = Member.create!(email: "admin@example.com", password: "password123",
                            first_name: "Ana", last_name: "Admin")
    @organisation.org_members.create!(member: @admin, role: "owner", active: true)

    @plain_member = Member.create!(email: "plain@example.com", password: "password123",
                                   first_name: "Pedro", last_name: "Plain")
    @organisation.org_members.create!(member: @plain_member, role: "member", active: true)
  end

  test "sales rep can open the catalog page" do
    sign_in @rep
    get bo_sales_rep_catalog_path(org_slug: @organisation.slug)
    assert_response :success
  end

  test "non-rep member is redirected away from the catalog page" do
    sign_in @plain_member
    get bo_sales_rep_catalog_path(org_slug: @organisation.slug)
    assert_redirected_to bo_path(org_slug: @organisation.slug)
  end

  test "creating a catalog enqueues the job and owns the task as the rep" do
    sign_in @rep

    assert_enqueued_with(job: GenerateCatalogJob) do
      assert_difference -> { @organisation.background_tasks.count }, 1 do
        post bo_sales_rep_catalog_path(org_slug: @organisation.slug), params: {
          catalog_title: "Catálogo Rita",
          show_prices: "1",
          catalog_layout: "grid"
        }
      end
    end

    task = @organisation.background_tasks.order(:created_at).last
    assert_equal @rep, task.member
    assert_equal "generate_catalog", task.task_type
    assert_redirected_to bo_background_task_path(@organisation.slug, task)
  end

  test "rep can view a background task they own" do
    sign_in @rep
    task = @organisation.background_tasks.create!(member: @rep, task_type: "generate_catalog", status: :pending)

    get bo_background_task_path(org_slug: @organisation.slug, id: task.id)
    assert_response :success
  end

  test "rep cannot view a background task owned by another member" do
    sign_in @rep
    others_task = @organisation.background_tasks.create!(member: @admin, task_type: "export", status: :pending)

    get bo_background_task_path(org_slug: @organisation.slug, id: others_task.id)
    assert_redirected_to bo_sales_rep_carteira_path(org_slug: @organisation.slug)
  end
end
