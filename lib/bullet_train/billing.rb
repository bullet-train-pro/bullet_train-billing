require "bullet_train/billing/version"
require "bullet_train/billing/engine"

module BulletTrain
  module Billing
    singleton_class.attr_reader :provider_subscription_attributes
    @provider_subscription_attributes = []

    module Records
      module Base
        extend ActiveSupport::Concern

        included do
          # By default, any model in a collection is considered active for billing purposes.
          # This can be overloaded in the child model class to specify more specific criteria for billing.
          # See `Memberships::Base` below for an example.
          scope :billable, -> { order("TRUE") } # TODO: Replace empty condition with just `all` to return the current relation.
        end
      end
    end

    module Memberships
      module Base
        extend ActiveSupport::Concern

        included do
          scope :billable, -> { current_and_invited }
        end
      end
    end

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

ActiveSupport.on_load(:bullet_train_records_base) { include BulletTrain::Billing::Records::Base }
ActiveSupport.on_load(:bullet_train_memberships_base) { include BulletTrain::Billing::Memberships::Base }
ActiveSupport.on_load(:bullet_train_teams_base) { include BulletTrain::Billing::Teams::Base }
ActiveSupport.on_load(:bullet_train_account_controllers_base) { include Billing::ControllerSupport }
