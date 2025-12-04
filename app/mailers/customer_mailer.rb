class CustomerMailer < ApplicationMailer
  helper :application
  default template_path: 'devise/mailer'
end
