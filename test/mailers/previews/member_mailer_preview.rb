# Preview all emails at http://localhost:3000/rails/mailers/member_mailer
class MemberMailerPreview < ActionMailer::Preview
  def confirm_order
    order = Order.placed.last
    customer = order.customer
    CustomerMailer.with(customer: customer, order: order).confirm_order
  end
end
