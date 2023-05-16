module Billing::AbilitySupport
  extend ActiveSupport::Concern

  def apply_billing_abilities(user)
    can :read, Billing::Subscription, team_id: user.team_ids
    can :read, Billing::Subscriptions::IncludedPrice, subscription: {team_id: user.team_ids}

    # Certain payment providers handle the sign-up and subscription workflows out-of-app.
    unless billing_subscription_creation_disabled?
      can [:create], Billing::Subscription, team_id: user.administrating_team_ids
    end

    can :manage, Billing::Subscriptions::IncludedPrice, subscription: {team_id: user.administrating_team_ids}

    # TODO We need a way for `bullet_train-billing-stripe` to define these.
    if defined?(Billing::Stripe::Subscription)
      can :read, Billing::Stripe::Subscription, team_id: user.team_ids
      can :manage, Billing::Stripe::Subscription, team_id: user.administrating_team_ids
    end

    # TODO We need a way for `bullet_train-billing-umbrella_subscriptions` to define these.
    if defined?(Billing::Umbrella::Subscription)
      can :read, Billing::Umbrella::Subscription, team_id: user.team_ids
      can :manage, Billing::Umbrella::Subscription, team_id: user.administrating_team_ids
    end

    # You can destroy subscriptions that haven't been checked out yet.
    can :destroy, Billing::Subscription, team_id: user.administrating_team_ids, status: "initiated"
  end
end
