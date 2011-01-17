require File.dirname(__FILE__) + '/../spec_helper'

describe EventsController, "when displaying index" do
  integrate_views

  it "should produce HTML" do
    get :index, :format => "html"

    response.should have_tag("table.event_table")
  end

  describe "in XML format" do

    it "should produce XML" do
      post :index, :format => "xml"

      hash = Hash.from_xml(response.body)
      hash["events"].should be_a_kind_of(Array)
    end

    it "should include venue details" do
      post :index, :format => "xml"

      hash = Hash.from_xml(response.body)

      event = hash["events"].first
      venue = event["venue"]
      venue_title = venue["title"]  # Why XML? Why?
      venue_title.should be_a_kind_of(String)
      venue_title.length.should > 0
    end

  end

  describe "in JSON format" do

    it "should produce JSON" do
      post :index, :format => "json"

      struct = ActiveSupport::JSON.decode(response.body)
      struct.should be_a_kind_of(Array)
    end

    it "should accept a JSONP callback" do
      post :index, :format => "json", :callback => "some_function"

      response.body.split("\n").join.should match(/^\s*some_function\(.*\);?\s*$/)
    end

    it "should include venue details" do
      post :index, :format => "json"

      struct = ActiveSupport::JSON.decode(response.body)
      event = struct.first
      event["venue"]["title"].should be_a_kind_of(String)
      event["venue"]["title"].length.should > 0
    end

  end

  it "should produce ATOM" do
    post :index, :format => "atom"

    hash = Hash.from_xml(response.body)
    hash["feed"]["entry"].should be_a_kind_of(Array)
  end

  describe "in ICS format" do
    fixtures :events, :venues

    it "should produce ICS" do
      post :index, :format => "ics"

      response.body.should have_text(/BEGIN:VEVENT/)
    end

    it "should render all future events" do
      post :index, :format => "ics"
      response.body.should =~ /SUMMARY:#{events(:tomorrow).title}/
      response.body.should_not =~ /SUMMARY:#{events(:old_event).title}/
    end

  end

  describe "and ordering" do
    def events_by(ordering)
      get :index, :order => ordering
      return assigns[:listing].events
    end

    before :each do
      Event.destroy_all
      Venue.destroy_all

      @venue2 = Venue.create!(:title => "venue2")
      @venue1 = Venue.create!(:title => "venue1")

      @event2 = Event.create!(:title => "event2", :start_time => 1.year.from_now, :end_time => 1.year.from_now+1.hour)
      @event1 = Event.create!(:title => "event1", :start_time => 1.week.from_now, :end_time => 1.week.from_now+1.hour)
    end

    it "by event date" do
      events_by("date").should == [@event1, @event2]
    end

    it "by event name" do
      events_by("name").should == [@event1, @event2]
    end

    it "by venue name" do
      events_by("venue").should == [@event1, @event2]
    end
  end

  describe "and filtering by date range" do
    def resulting_date
      assigns[:listing].send("#{@date_kind}_date")
    end

    def default_date
      EventListing.send("default_#{@date_kind}_date")
    end

    def assert_error(message)
      response.should have_tag(".flash_failure", message)
    end

    [:start, :end].each do |date_kind|
      describe "for #{date_kind} date" do
        before :all do
          @date_kind = date_kind
          @date_kind_other = \
            case date_kind
            when :start then :end
            when :end then :start
            else raise ArgumentError, "Unknown date_kind: #{date_kind}"
            end
        end

        it "should use the default if not given the parameter" do
          get :index, :date => {}
          resulting_date.should == default_date
          flash[:failure].should be_nil
        end

        it "should use the default if given an invalid top-level parameter" do
          get :index, :date => "omgkittens"
          resulting_date.should == default_date
          assert_error /invalid.+#{@date_kind}/
        end

        it "should use the default if given an empty parameter" do
          get :index, :date => {@date_kind => ""}
          resulting_date.should == default_date
          assert_error /empty.+#{@date_kind}/
        end

        it "should use the default if given an invalid parameter" do
          get :index, :date => {@date_kind => "omgkittens"}
          resulting_date.should == default_date
          assert_error /malformed.+#{@date_kind}/
        end

        it "should use the value if valid" do
          expected = Date.yesterday
          get :index, :date => {@date_kind => expected.to_s("%Y-%m-%d")}
          resulting_date.should == expected
        end
      end
    end

    it "should return matching events" do
      # Given
      matching = [
        Event.create!(
          :title => "matching1",
          :start_time => Time.parse("2010-01-16 00:00"),
          :end_time => Time.parse("2010-01-16 01:00")
        ),
        Event.create!(:title => "matching2",
          :start_time => Time.parse("2010-01-16 23:00"),
          :end_time => Time.parse("2010-01-17 00:00")
        ),
      ]

      non_matching = [
        Event.create!(
          :title => "nonmatchingbefore",
          :start_time => Time.parse("2010-01-15 23:00"),
          :end_time => Time.parse("2010-01-15 23:59")
        ),
        Event.create!(
          :title => "nonmatchingafter",
          :start_time => Time.parse("2010-01-17 00:01"),
          :end_time => Time.parse("2010-01-17 01:00")
        ),
      ]

      # When
      get :index, :date => {:start => "2010-01-16", :end => "2010-01-16"}
      results = assigns[:listing].events

      # Then
      results.size.should == 2
      results.should == matching
    end
  end
end

describe EventsController, "when displaying events" do
  it "should show an event" do
    event = Event.new(:start_time => Time.now)
    Event.should_receive(:find).and_return(event)

    get "show", :id => 1234
    response.should be_success
  end

  it "should redirect from a duplicate event to its master" do
    master = mock_model(Event, :id => 4321)
    event = Event.new(:start_time => Time.now, :duplicate_of => master)
    Event.should_receive(:find).and_return(event)

    get "show", :id => 1234
    response.should redirect_to(event_path(master))
  end

  it "should show an error when asked to display a non-existent event" do
    Event.should_receive(:find).and_raise(ActiveRecord::RecordNotFound)

    get "show", :id => 1234
    response.should redirect_to(events_path)
    flash[:failure].should_not be_blank
  end
end

describe EventsController, "when creating or updating events" do
  fixtures :events, :venues

  before(:each) do
    # Fields marked with "###" may be filled in by examples to alter behavior
    @params = {
      :end_date       => "2008-06-04",
      :start_date     => "2008-06-03",
      :event => {
        "title"       => "MyVenue",
        "url"         => "http://my.venue",
        "description" => "Wheeeee"
      },
      :end_time       => "",
      :start_time     => ""
    }
    @venue = mock_model(Venue)
    @event = mock_model(Event, {
      :title          => "MyEvent",
      :start_time=    => true,
      :end_time=      => true,
    })
  end

  describe "when creating events" do
    it "should display form for creating new event" do
      get "new"
      response.should be_success
      response.should render_template(:new)
    end

    it "should create a new event without a venue" do
      Event.should_receive(:new).with(@params[:event]).and_return(@event)
      @event.stub!(:associate_with_venue).with(@params[:venue_name])
      @event.stub!(:venue).and_return(nil)
      @event.should_receive(:save).and_return(true)

      post "create", @params
      response.should redirect_to(event_path(@event))
    end

    it "should associate a venue based on a given venue id" do
      @params[:event]["venue_id"] = @venue.id.to_s
      Event.should_receive(:new).with(@params[:event]).and_return(@event)
      @event.should_receive(:associate_with_venue).with(@venue.id)
      @event.stub!(:venue).and_return(@venue)
      @event.should_receive(:save).and_return(true)

      post "create", @params
    end

    it "should associate a venue based on a given venue name" do
      @params[:venue_name] = "Some Event"
      Event.should_receive(:new).with(@params[:event]).and_return(@event)
      @event.should_receive(:associate_with_venue).with("Some Event")
      @event.stub!(:venue).and_return(@venue)
      @event.should_receive(:save).and_return(true)

      post "create", @params
    end

    it "should associate a venue by id when both an id and a name are provided" do
      @params[:event]["venue_id"] = @venue.id.to_s
      @params[:venue_name] = "Some Event"
      Event.should_receive(:new).with(@params[:event]).and_return(@event)
      @event.should_receive(:associate_with_venue).with(@venue.id)
      @event.stub!(:venue).and_return(@venue)
      @event.should_receive(:save).and_return(true)

      post "create", @params
    end

    it "should create a new event for an existing venue" do
      @params[:venue_name] = "Old Venue"
      Event.should_receive(:new).with(@params[:event]).and_return(@event)
      @event.stub!(:associate_with_venue).with(@params[:venue_name])
      @event.stub!(:venue).and_return(@venue)
      @event.should_receive(:save).and_return(true)
      @venue.stub!(:new_record?).and_return(false)

      post "create", @params
      response.should redirect_to(event_path(@event))
    end

    it "should create a new event and new venue, and redirect to venue edit form" do
      @params[:venue_name] = "New Venue"
      Event.should_receive(:new).with(@params[:event]).and_return(@event)
      @event.stub!(:associate_with_venue).with(@params[:venue_name])
      @event.stub!(:venue).and_return(@venue)
      @event.should_receive(:save).and_return(true)
      @venue.stub!(:new_record?).and_return(true)

      post "create", @params
      response.should redirect_to(edit_venue_url(@venue, :from_event => @event.id))
    end

    it "should catch errors and redisplay the new event form" do
      post "create"
      response.should render_template(:new)
    end

    it "should stop evil robots" do
      post "create", :trap_field => "I AM AN EVIL ROBOT, I EAT OLD PEOPLE'S MEDICINE FOR FOOD!"
      response.should render_template(:new)
      flash[:failure].should match(/evil robot/i)
    end
    
    it "should allow the user to preview the event" do
      event = Event.new(:title => "Awesomeness")
      Event.should_receive(:new).and_return(event)

      event.should_not_receive(:save)
      
      post "create", :event => { :title => "Awesomeness" }, :start_time => Time.now, :start_date => Date.today, :preview => "Preview"
      response.should render_template(:new)
      event.should be_valid
    end
  end

  describe "when updating events" do
    before(:each) do
      @event = mock_model(Event, {
        :title          => "MyEvent",
        :start_time=    => true,
        :end_time=      => true,
        :associate_with_venue => true,
        :venue => @venue
      })
      Event.stub!(:find).and_return(@event)
    end

    it "should display form for editing event" do
      Event.should_receive(:find).and_return(@event)

      get "edit", :id => 1
      response.should be_success
      response.should render_template(:edit)
    end

    it "should update an event without a venue" do
      Event.should_receive(:find).and_return(@event)
      @event.stub!(:associate_with_venue).with(@params[:venue_name])
      @event.stub!(:venue).and_return(nil)
      @event.should_receive(:update_attributes).and_return(true)

      put "update", @params
      response.should redirect_to(event_path(@event))
    end

    it "should associate a venue based on a given venue id" do
      @params[:event]["venue_id"] = @venue.id.to_s
      Event.should_receive(:find).and_return(@event)
      @event.should_receive(:associate_with_venue).with(@venue.id)
      @event.stub!(:venue).and_return(@venue)
      @event.should_receive(:update_attributes).and_return(true)

      post "update", @params
    end

    it "should associate a venue based on a given venue name" do
      @params[:venue_name] = "Some Event"
      Event.should_receive(:find).and_return(@event)
      @event.should_receive(:associate_with_venue).with("Some Event")
      @event.stub!(:venue).and_return(@venue)
      @event.should_receive(:update_attributes).and_return(true)

      post "update", @params
    end

    it "should associate a venue by id when both an id and a name are provided" do
      @params[:event]["venue_id"] = @venue.id.to_s
      @params[:venue_name] = "Some Event"
      Event.should_receive(:find).and_return(@event)
      @event.should_receive(:associate_with_venue).with(@venue.id)
      @event.stub!(:venue).and_return(@venue)
      @event.should_receive(:update_attributes).and_return(true)

      post "update", @params
    end

    it "should update an event and associate it with an existing venue" do
      @params[:venue_name] = "Old Venue"
      Event.should_receive(:find).and_return(@event)
      @event.stub!(:associate_with_venue).with(@params[:venue_name])
      @event.stub!(:venue).and_return(@venue)
      @event.should_receive(:update_attributes).and_return(true)
      @venue.stub!(:new_record?).and_return(false)

      put "update", @params
      response.should redirect_to(event_path(@event))
    end

    it "should update an event and create a new venue, and redirect to the venue edit form" do
      @params[:venue_name] = "New Venue"
      Event.should_receive(:find).and_return(@event)
      @event.stub!(:associate_with_venue).with(@params[:venue_name])
      @event.stub!(:venue).and_return(@venue)
      @event.should_receive(:update_attributes).and_return(true)
      @venue.stub!(:new_record?).and_return(true)

      put "update", @params
      response.should redirect_to(edit_venue_url(@venue, :from_event => @event.id))
    end

    it "should catch errors and redisplay the new event form" do
      Event.should_receive(:find).and_return(@event)
      @event.stub!(:associate_with_venue)
      @event.stub!(:venue).and_return(nil)
      @event.should_receive(:update_attributes).and_return(false)

      post "update", :id => 1234
      response.should render_template(:edit)
    end

    it "should stop evil robots" do
      put "update", :id => 1234, :trap_field => "I AM AN EVIL ROBOT, I EAT OLD PEOPLE'S MEDICINE FOR FOOD!"
      response.should render_template(:edit)
      flash[:failure].should match(/evil robot/i)
    end

    it "should allow the user to preview the event" do
      Event.should_receive(:find).and_return(@event)
      @event.should_not_receive(:update_attributes)
      @event.should_receive(:attributes=)
      @event.should_receive(:valid?).and_return(true)

      put "update", @params.merge(:preview => "Preview")
      response.should render_template(:edit)
    end

  end

  describe "when cloning event" do
    fixtures :events, :venues

    before(:each) do
      @event = events(:calagator_codesprint)
      Event.stub!(:find).and_return(@event)
      get "clone", :id => 1
    end

    it "should use the cloned object" do
      record = assigns[:event]
      record.should be_a_new_record
      record.id.should be_nil
    end

    it "should display a new event form" do
      response.should be_success
      response.should render_template(:new)
    end

    it "should have notice with cloning instructions" do
      flash[:success].should =~ /clone/i
    end
  end
end

describe EventsController, "managing duplicates" do
  integrate_views
  fixtures :events, :venues

  it "should find new duplicates and not old duplicates" do
    get 'duplicates'

    # New duplicates
    web3con = assigns[:grouped_events].select{|keys,values| keys.include?("Web 3.0 Conference")}
    web3con.should_not be_blank
    web3con.first.last.size.should == 2

    # Old duplicates
    web1con = assigns[:grouped_events].select{|keys,values| keys.include?("Web 1.0 Conference")}
    web1con.should be_blank
  end

  it "should redirect duplicate events to their master" do
    event_master = events(:calagator_codesprint)
    event_duplicate = events(:tomorrow)

    get 'show', :id => event_duplicate.id
    response.should_not be_redirect
    assigns(:event).id.should == event_duplicate.id

    event_duplicate.duplicate_of = event_master
    event_duplicate.save!

    get 'show', :id => event_duplicate.id
    response.should be_redirect
    response.should redirect_to(event_url(event_master.id))
  end

  it "should display an error message if given invalid arguments" do
    get 'duplicates', :type => 'omgwtfbbq'

    response.should be_success
    response.should have_tag('.failure', :text => /omgwtfbbq/)
  end

end

describe EventsController, "when searching" do

  it "should search" do
    Event.should_receive(:search_grouped_by_currentness).and_return({:current => [], :past => []})

    post :search, :query => "myquery"
  end

  it "should fail if given no search query" do
    post :search

    flash[:failure].should_not be_blank
    response.should redirect_to(root_path)
  end

  it "should be able to only return current events" do
    Event.should_receive(:search).with("myquery", :order => nil, :skip_old => true).and_return([])

    post :search, :query => "myquery", :current => "1"
  end

  it "should be able to only return events matching specific tag" do
    Event.should_receive(:tagged_with).with("foo", :current => false, :order => nil).and_return([])

    post :search, :tag => "foo"
  end

  it "should warn if user tries ordering tags by score" do
    Event.should_receive(:tagged_with).with("foo", :current => false, :order => nil).and_return([])

    post :search, :tag => "foo", :order => "score"
    flash[:failure].should_not be_blank
  end

  describe "when returning results" do
    integrate_views
    fixtures :events, :venues

    before do
      @results = {
        :current => [events(:calagator_codesprint), events(:tomorrow)],
        :past    => [events(:old_event)],
      }
      Event.should_receive(:search_grouped_by_currentness).and_return(@results)
    end

    it "should produce HTML" do
      post :search, :query => "myquery", :format => "html"

      response.should have_tag("table.event_table")
      assigns[:events].should == @results[:past] + @results[:current]
    end

    describe "in XML format" do

      it "should produce XML" do
        post :search, :query => "myquery", :format => "xml"

        hash = Hash.from_xml(response.body)
        hash["events"].should be_a_kind_of(Array)
      end

      it "should include venue details" do
        post :search, :query => "myquery", :format => "xml"

        hash = Hash.from_xml(response.body)
        event = hash["events"].first
        venue = event["venue"]
        venue_title = venue["title"]
        venue_title.should be_a_kind_of(String)
        venue_title.length.should > 0
      end

    end

    describe "in JSON format" do

      it "should produce JSON" do
        post :search, :query => "myquery", :format => "json"

        struct = ActiveSupport::JSON.decode(response.body)
        struct.should be_a_kind_of(Array)
      end

      it "should accept a JSONP callback" do
        post :search, :query => "myquery", :format => "json", :callback => "some_function"

        response.body.split("\n").join.should match(/^\s*some_function\(.*\);?\s*$/)
      end

      it "should include venue details" do
        post :search, :query => "myquery", :format => "json"

        struct = ActiveSupport::JSON.decode(response.body)
        event = struct.first
        event["venue"]["title"].should be_a_kind_of(String)
        event["venue"]["title"].length.should > 0
      end

    end

    it "should produce ATOM" do
      post :search, :query => "myquery", :format => "atom"

      hash = Hash.from_xml(response.body)
      hash["feed"]["entry"].should be_a_kind_of(Array)
    end

    describe "in ICS format" do

      it "should produce ICS" do
        post :search, :query => "myquery", :format => "ics"

        response.body.should have_text(/BEGIN:VEVENT/)
      end

      it "should produce events matching the query" do
        post :search, :query => "myquery", :format => "ics"
        response.body.should =~ /SUMMARY:#{events(:tomorrow).title}/
        response.body.should =~ /SUMMARY:#{events(:old_event).title}/
      end

    end
  end
end

describe EventsController, "when deleting" do

  it "should destroy events" do
    event = mock_model(Event)
    event.should_receive(:destroy)
    Event.should_receive(:find).and_return(event)

    delete 'destroy', :id => 1234
    response.should redirect_to(events_url)
  end

end

describe EventsController, "when running integration test" do
  integrate_views
  fixtures :events, :venues

  before(:each) do
    @venue         = venues(:cubespace)
    @event_params  = {
      :title       => "MyEvent#{$$}",
      :description => "Description",
      :start_time  => Time.today.strftime("%Y-%m-%d"),
      :end_time    => Time.today.strftime("%Y-%m-%d")
    }
  end

  it "should create event for existing venue" do
    post "create",
      :start_time => @event_params[:start_time],
      :end_time   => @event_params[:end_time],
      :event      => @event_params,
      :venue_name => @venue.title

    flash[:success].should_not be_blank
    event = assigns[:event]
    event.title.should == @event_params[:title]
    event.venue.title.should == @venue.title
  end

  it "should create event for exsiting venue and add tags" do
    post "create",
      :start_time => @event_params[:start_time],
      :end_time   => @event_params[:end_time],
      :event      => @event_params.merge(:tag_list => ",,foo,bar, baz,"),
      :venue_name => @venue.title

    flash[:success].should_not be_blank
    event = assigns[:event]
    event.tag_list.should == "bar, baz, foo"
  end
end
