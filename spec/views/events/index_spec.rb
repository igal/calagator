require File.dirname(__FILE__) + '/../../spec_helper'

describe "/events" do
  fixtures :events
  
  before(:each) do
    @codesprint = events(:calagator_codesprint)
    @tomorrow = events(:tomorrow)
    @day_after_tomorrow = events(:day_after_tomorrow)
    assigns[:listing] = EventListing.new.tap do
      self.stub!(:events, [@codesprint, @tomorrow, @day_after_tomorrow])
    end
  end
  
  it "should render valid XHTML" do
    render "/events/index"
    response.should be_valid_xhtml_fragment
  end
end
