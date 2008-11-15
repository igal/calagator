class Accounts::MyEventsController < ApplicationController
  before_filter :login_required

  def index
    @my_events = current_user.my_events.sort_by{|t| t.event.end_time.to_i}.reverse
  end

  def create_or_update
    if my_event = current_user.my_event_for(params[:event_id])
      # Update
      my_event.update_attribute(:status, params[:status])
    else
      # Create
      current_user.my_events.create!(:status => params[:status], :event_id => params[:event_id])
    end

    if request.xhr?
      render :text => "" # Nothing
    else
      redirect_to(event_path(params[:event_id]))
    end
  end
end