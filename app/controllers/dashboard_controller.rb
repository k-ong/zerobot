class DashboardController < ApplicationController
  before_filter :authenticate_user! if Rails.configuration.auth_enabled

  def index
    params[:project_name] = ENV['PROJECT_NAME']
    params[:aws_region] = ENV['AWS_REGION']

    render :layout => false
  end

end
