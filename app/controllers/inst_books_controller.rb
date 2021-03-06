class InstBooksController < ApplicationController
  load_and_authorize_resource

  #~ Action methods ...........................................................

  # -------------------------------------------------------------
  # POST /inst_books/:id
  def compile
    if params[:operation] == 'generate_course'
      launch_url = request.protocol + request.host_with_port + "/lti/launch"
      @job = Delayed::Job.enqueue GenerateCourseJob.new(params[:id], launch_url, current_user.id)
    else
      @job = Delayed::Job.enqueue CompileBookJob.new(params[:id], current_user.id)
    end
  end

  #~ Private instance methods .................................................
end
