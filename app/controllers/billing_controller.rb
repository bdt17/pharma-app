class BillingController < ApplicationController
  before_action :authenticate_user!
  
  def new
    Stripe.api_key = ENV['STRIPE_SECRET_KEY']
    
    @session = Stripe::Checkout::Session.create({
      mode: 'subscription',
      payment_method_types: ['card'],
      line_items: [{
        price_data: {
          currency: 'usd',
          product_data: {
            name: 'PharmaTransport Enterprise',
            description: 'All features: Digital Twin, AI Alerts, Multi-tenant, SLA',
          },
          unit_amount: 99900, # $999/mo
          recurring: { interval: 'month' }
        },
        quantity: 1,
      }],
      success_url: "#{root_url}billing/success?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: "#{root_url}billing/cancel",
      metadata: { user_id: current_user.id }
    })
  end
  
  def success
    @session_id = params[:session_id]
  end
  
  def cancel
  end
end
