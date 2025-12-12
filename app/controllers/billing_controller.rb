class BillingController < ApplicationController
  def new
    @session = Stripe::Checkout::Session.create({
      mode: 'subscription',
      payment_method_types: ['card'],
      line_items: [{price: 'price_12345', quantity: 1}],
      success_url: "#{root_url}billing/success?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: "#{root_url}billing/cancel"
    })
  end
end
