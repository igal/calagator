class EventListing
  # Start date of listing or nil.
  attr_accessor :start_date

  # End date of listing or nil.
  attr_accessor :end_date

  # Order of events
  attr_accessor :order

  # Array of errors when loading listing, may be empty.
  attr_accessor :errors

  # Instantiate a new EventListing object.
  #
  # Options:
  # * :order => String with the desired ordering. Can be nil.
  # * :start_and_end_date => Hash containing :start and :end key-value pairs. Can be nil.
  def initialize(opts={})
    @errors = []

    @order = opts[:order] if opts[:order].present?

    @_dates_given = opts[:start_and_end_date].present?

    @start_date = self.date_or_default_for :start, opts[:start_and_end_date]
    @end_date   = self.date_or_default_for :end,   opts[:start_and_end_date]
  end

  # Should the listing be cached?
  def cache?
    return !(@order || self.dates?)
  end

  # Were dates specified?
  def dates?
    return @_dates_given && @start_date && @end_date
  end

  # Return an array of events. Caches them once retrieved.
  def events
    @_events ||= self.find_events
  end

  # Return an array of events. No caching.
  def find_events
    ordering = \
      case @order
        when 'name'
          'lower(events.title), start_time'
        when 'venue'
          'lower(venues.title), start_time'
        when 'date'
          'start_time'
        else
          'start_time'
        end

    self.dates? ?
      Event.find_by_dates(@start_date, @end_date, :order => ordering) :
      Event.find_future_events(:order => ordering)
  end

  # Return the Date for the +kind+ (e.g. :start) from the +opts+ (e.g. {:start => Date.now})
  def date_or_default_for(kind, opts)
    result = self.class.send("default_#{kind}_date")

    if opts.nil?
      # No date specified, just use the default
    elsif not opts.respond_to?(:has_key?)
      self.errors << "Can't filter by invalid #{kind} date."
    elsif not opts.has_key?(kind)
      self.errors << "Can't filter by missing #{kind} date."
    elsif opts[kind].blank?
      self.errors << "Can't filter by empty #{kind} date."
    else
      begin
        result = Date.parse(opts[kind])
      rescue ArgumentError => e
        self.errors << "Can't filter by an malformed #{kind} date."
      end
    end

    return result
  end

  # Return the default start date.
  def self.default_start_date
    return Time.today
  end

  # Return the default end date.
  def self.default_end_date
    return Time.today + 3.months
  end
end
