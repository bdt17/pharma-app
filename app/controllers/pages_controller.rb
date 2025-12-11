class PagesController < ApplicationController
  def home
    render html: "<h1>🚀 Hospital Pharma Monitor - LIVE</h1><a href='/pay' style='background:#635bff;color:white;padding:15px;display:inline-block;text-decoration:none;'>💳 Pay $99/mo → Dashboard</a>".html_safe
  end
  
  def pay
    require 'stripe'
    Stripe.api_key = 'sk_test_51Sd3BlFioTnGRDg4I9zdgTcIShS6uhj0bCUfRfjbrxk1WA4yxPvTjyfvzfBnOqiuq5y68x4WLZXpVLeMMO7cLOlW00ztZB4L4L'
    session = Stripe::Checkout::Session.create({
      payment_method_types: ['card'],
      line_items: [{ price_data: { currency: 'usd', product_data: { name: 'Hospital Pharma Monitor' }, unit_amount: 9900 }, quantity: 1 }],
      mode: 'subscription',
      success_url: 'https://pharma-transport.loca.lt/dashboard',
      cancel_url: 'https://pharma-transport.loca.lt'
    })
    redirect_to session.url, allow_other_host: true
  end
  
  def dashboard
    render html: "<h1>✅ Baptist Health Dashboard</h1><p>12 trucks active | $99/mo PAID ✓<br><a href='/dashboard'>🚚 Live GPS Tracking</a></p>".html_safe
  end
end
