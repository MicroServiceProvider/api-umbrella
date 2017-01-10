class Admin::SessionsController < Devise::SessionsController
  before_action :first_time_setup
  skip_after_action :verify_authorized

  def auth
    response = {
      "authenticated" => !current_admin.nil?,
      "enable_beta_analytics" => (ApiUmbrellaConfig[:analytics][:adapter] == "kylin" || (ApiUmbrellaConfig[:analytics][:outputs] && ApiUmbrellaConfig[:analytics][:outputs].include?("kylin"))),
    }

    if current_admin
      response["api_umbrella_version"] = API_UMBRELLA_VERSION
      response["admin"] = current_admin.as_json
      response["api_key"] = ApiUser.where(:email => "web.admin.ajax@internal.apiumbrella").order_by(:created_at.asc).first.api_key
      response["csrf_token"] = form_authenticity_token if(protect_against_forgery?)
    end

    respond_to do|format|
      format.json { render(:json => response) }
    end
  end

  private

  def set_flash_message(key, kind, options = {})
    # Don't set the "signed in" flash message, since we redirect to the Ember
    # app after signing in, where flashes won't be displayed (so displaying the
    # "signed in" message the next time they get back to the Rails login page
    # is confusing).
    if(kind != :signed_in)
      super(key, kind, options)
    end
  end

  def first_time_setup
    if(Admin.needs_first_account?)
      redirect_to new_admin_registration_path
    end
  end
end