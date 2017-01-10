class Admin::Admins::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  skip_after_action :verify_authorized

  # For the developer strategy, simply find or create a new admin account with
  # whatever login details they give. This is not for use on production.
  def developer
    unless(Rails.env == "development")
      raise "The developer OmniAuth strategy should not be used outside of development or test."
    end

    @username = request.env["omniauth.auth"]["uid"]
    @admin = Admin.find_for_database_authentication(:username => @username)
    unless(@admin)
      @admin = Admin.new(:username => @username, :superuser => true)
      @admin.save!
    end

    login
  rescue Mongoid::Errors::Validations
    flash[:error] = @admin.errors.full_messages.join(", ")
    redirect_to admin_developer_omniauth_authorize_path
  end

  def cas
    @username = request.env["omniauth.auth"]["uid"]
    login
  end

  def facebook
    if(request.env["omniauth.auth"]["info"]["verified"])
      @username = request.env["omniauth.auth"]["info"]["email"]
    end

    login
  end

  def github
    if(request.env["omniauth.auth"]["info"]["email_verified"])
      @username = request.env["omniauth.auth"]["info"]["email"]
    end

    login
  end

  def google_oauth2
    if(request.env["omniauth.auth"]["extra"]["raw_info"]["email_verified"])
      @username = request.env["omniauth.auth"]["info"]["email"]
    end

    login
  end

  def ldap
    uid_field = request.env["omniauth.strategy"].options[:uid]
    uid = [request.env["omniauth.auth"]["extra"]["raw_info"][uid_field]].flatten.compact.first
    @username = uid
    login
  end

  private

  def login
    if(!@admin && @username.present?)
      @admin = Admin.find_for_database_authentication(:username => @username)
    end

    if @admin
      @admin.last_sign_in_provider = request.env["omniauth.auth"]["provider"]
      if request.env["omniauth.auth"]["info"].present?
        if request.env["omniauth.auth"]["info"]["email"].present?
          @admin.email = request.env["omniauth.auth"]["info"]["email"]
        end

        if request.env["omniauth.auth"]["info"]["name"].present?
          @admin.name = request.env["omniauth.auth"]["info"]["name"]
        end
      end

      @admin.save!

      sign_in_and_redirect(:admin, @admin)
    else
      flash[:error] = ActionController::Base.helpers.safe_join([
        "The account for '",
        @username,
        "' is not authorized to access the admin. Please ",
        ActionController::Base.helpers.content_tag(:a, "contact us", :href => ApiUmbrellaConfig[:contact_url]),
        " for further assistance.",
      ])

      redirect_to new_admin_session_path
    end
  end

  def after_omniauth_failure_path_for(scope)
    new_admin_session_path
  end
end