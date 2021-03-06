
$VERBOSE = nil
require 'rubygems'
require 'rake' # echoe relies on Rake being present but doesn't require it itself
require 'echoe'
require 'test/unit'
require 'multi_rails_init'
#require 'ruby-debug' # uncomment if needed (for Ruby >= 1.9 use require 'debug' where needed)

if defined? ENV['MULTIRAILS_RAILS_VERSION']
  ENV['RAILS_GEM_VERSION'] = ENV['MULTIRAILS_RAILS_VERSION']
end

Echoe.silence do
  HERE = File.expand_path(File.dirname(__FILE__))
  $LOAD_PATH << HERE
  # $LOAD_PATH << "#{HERE}/integration/app"
end

LOG = "#{HERE}/integration/app/log/development.log"

### For unit tests

require 'integration/app/config/environment'
require 'test_help'

ActiveSupport::Inflector.inflections {|i| i.irregular 'fish', 'fish' }

$LOAD_PATH.unshift(ActiveSupport::TestCase.fixture_path = HERE + "/fixtures")
$LOAD_PATH.unshift(HERE + "/models")
$LOAD_PATH.unshift(HERE + "/modules")

class ActiveSupport::TestCase
  self.use_transactional_fixtures = !(ActiveRecord::Base.connection.is_a? ActiveRecord::ConnectionAdapters::MysqlAdapter rescue false)
  self.use_instantiated_fixtures  = false
end

Echoe.silence do
  load(HERE + "/schema.rb")
end

### For integration tests

def truncate
  system("> #{LOG}")
end

def log
  File.open(LOG, 'r') do |f|
    f.read
  end
end
