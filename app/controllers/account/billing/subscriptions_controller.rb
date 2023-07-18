class Account::Billing::SubscriptionsController < Account::ApplicationController
  account_load_and_authorize_resource :subscription, through: :team, through_association: :billing_subscriptions

  # GET /account/teams/:team_id/billing/subscriptions
  # GET /account/teams/:team_id/billing/subscriptions.json
  def index
    # if you only want these objects shown on their parent's show page, uncomment this:
    # redirect_to [:account, @team]
  end

  # GET /account/billing/subscriptions/:id
  # GET /account/billing/subscriptions/:id.json
  def show
    redirect_to [:account, @team, :billing_subscriptions]
  end

  # GET /account/teams/:team_id/billing/subscriptions/new
  def new
    if @team.billing_subscriptions.not_canceled.any?
      return redirect_to [:account, @team, :billing_subscriptions], notice: "You can only have one active subscription at a time!"
    end

    if @subscription.provider_subscription_type_valid?
      @subscription.build_provider_subscription
    elsif params[:commit]
      @subscription.valid?
    end

    @back = if @team.needs_billing_subscription?
      [:account, :teams]
    else
      [:account, @team, :billing_subscriptions]
    end

    render :new, layout: "pricing"
  end

  # GET /account/billing/subscriptions/:id/edit
  def edit
  end

  # POST /account/teams/:team_id/billing/subscriptions
  # POST /account/teams/:team_id/billing/subscriptions.json
  def create
    if @subscription.provider_subscription_type_valid? && !@subscription.provider_subscription
      @subscription.build_provider_subscription
    end

    @subscription.provider_subscription.team = @team

    # TODO When we try to save normally, we get:
    #  @errors=[#<ActiveModel::NestedError attribute=included_prices.subscription, type=blank, options={:message=>:required}>]>
    # Why isn't this working for us automatically? This seems like something Rails should be handling for us.
    included_prices = @subscription.included_prices.to_a
    @subscription.included_prices.clear

    respond_to do |format|
      if @subscription.save

        # TODO Figure out why this is required. See note above.
        included_prices.each do |included_price|
          included_price.subscription = @subscription
          included_price.save!
        end

        format.html { redirect_to [:checkout, :account, @subscription.provider_subscription], notice: I18n.t("billing/subscriptions.notifications.created") }
        format.json { render :show, status: :created, location: [:account, @subscription] }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @subscription.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /account/billing/subscriptions/:id
  # PATCH/PUT /account/billing/subscriptions/:id.json
  def update
    respond_to do |format|
      if @subscription.update(subscription_params)
        format.html { redirect_to [:account, @subscription], notice: I18n.t("billing/subscriptions.notifications.updated") }
        format.json { render :show, status: :ok, location: [:account, @subscription] }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @subscription.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /account/billing/subscriptions/:id
  # DELETE /account/billing/subscriptions/:id.json
  def destroy
    @subscription.destroy
    respond_to do |format|
      format.html { redirect_to [:account, @team, :billing_subscriptions], notice: I18n.t("billing/subscriptions.notifications.destroyed") }
      format.json { head :no_content }
    end
  end

  private

  # Never trust parameters from the scary internet, only allow the white list through.
  def subscription_params
    strong_params = params.require(:billing_subscription).permit(
      :provider_subscription_type,
      :cycle_ends_at,
      :status,
      # 🚅 super scaffolding will insert new fields above this line.
      # 🚅 super scaffolding will insert new arrays above this line.
      included_prices_attributes: [
        [
          :id,
          :price_id,
          :quantity # TODO It's possible we don't want to allow them to set this.
        ]
      ],

      provider_subscription_attributes: [
        :id,

        # TODO We need a way for `bullet_train-billing-stripe` to define this.
        # Stripe subscription attributes:
        :stripe_subscription_id,

        # TODO We need a way for `bullet_train-billing-umbrella_subscriptions` to define this.
        # Umbrella subscription attributes:
        :covering_team_id,

        *BulletTrain::Billing.provider_subscription_attributes,

        # External subscription attributes:
        :notes
      ]
    )

    assign_date_and_time(strong_params, :cycle_ends_at)
    # 🚅 super scaffolding will insert processing for new fields above this line.

    strong_params
  end
end
