# Preview all emails at http://localhost:3000/rails/mailers/member_mailer
class MemberMailerPreview < ActionMailer::Preview
  def notificate_customer_order
    order = Order.placed.last
    customer = order.customer
    org_slug = customer.organisation.slug
    MemberMailer.with(customer: customer, order: order, org_slug: org_slug).notificate_customer_order
  end
end
