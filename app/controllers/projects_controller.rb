require 'dupondius'

class ProjectsController < ApplicationController

  respond_to :json

  def new
  end

  def show
    @project = Project.find(params[:id])
  end

  def create
    project = Project.create(params[:project].except(:github, :support, :environments, :aws))
    Jobs::Skeleton.new(project.id).run if Rails.configuration.launchpad_jobs
    if Rails.configuration.aws_enabled
      Jobs::LaunchCi.new(project, params).run if params[:project][:support].include?('Jenkins')
    end
    respond_with(project, :location => :projects)
  end

end
