# Preview all emails at http://localhost:3000/rails/mailers/customer_mailer
class CustomerMailerPreview < ActionMailer::Preview
  def confirm_order
    order = Order.placed.last
    customer = order.customer
    CustomerMailer.with(customer: customer, order: order).confirm_order
  end

  def notify_clients_about_discount_product
    organisation = Organisation.last
    product_discount = organisation.product_discounts.last
    CustomerMailer.with(discount: product_discount, organisation: organisation).notify_clients_about_discount
  end

  def notify_clients_about_discount_order
    organisation = Organisation.last
    order_discount = organisation.order_discounts.last
    CustomerMailer.with(discount: order_discount, organisation: organisation).notify_clients_about_discount
  end

  def notify_customer_about_discount_customer
    organisation = Organisation.last
    customer_discount = organisation.customer_discounts.last
    CustomerMailer.with(discount: customer_discount, organisation: organisation).notify_customer_about_discount
  end

  def notify_customer_about_discount_customer_product
    organisation = Organisation.last
    customer_product_discount = organisation.customer_product_discounts.last
    CustomerMailer.with(discount: customer_product_discount, organisation: organisation).notify_customer_about_discount
  end
end
