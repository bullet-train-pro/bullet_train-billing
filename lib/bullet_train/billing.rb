require "bullet_train/billing/version"
require "bullet_train/billing/engine"

module BulletTrain
  module Billing
    module Teams
      module Base
        extend ActiveSupport::Concern

        included do
          has_many :billing_subscriptions, class_name: "Billing::Subscription", dependent: :destroy, foreign_key: :team_id
        end

        def current_billing_subscription
          # If by some bug we have two subscriptions, we want to use the one that existed first.
          # The reasoning here is that it's more likely to be on some legacy plan that benefits the customer.
          billing_subscriptions.active.order(:created_at).first
        end

        def needs_billing_subscription?
          return false if freemium_enabled?
          billing_subscriptions.active.empty?
        end
      end
    end
  end
end

def freemium_enabled?
  Billing::Product.find_by(id: "free").present?
end

ActiveSupport.on_load(:bullet_train_teams_base) { include BulletTrain::Billing::Teams::Base }
