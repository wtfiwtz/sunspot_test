require 'net/http'

$original_sunspot_session = Sunspot.session

Before("@searchrunning") do
  $sunspot = true
end

Before("~@search") do
  Sunspot.session = Sunspot::Rails::StubSessionProxy.new($original_sunspot_session)
end

Before("@search") do
  unless $sunspot
    $sunspot = Sunspot::Rails::Server.new
    pid = fork do
      STDERR.reopen('/dev/null')
      STDOUT.reopen('/dev/null')
      $sunspot.run
    end
    # shut down the Solr server
    at_exit { Process.kill('TERM', pid) }
    SunspotTestHelper.wait_until_solr_starts
  end
  
  Sunspot.session = $original_sunspot_session
  Sunspot.remove_all!
  Sunspot.commit
end

AfterStep('@search') do
  Sunspot.commit
end

module SunspotTestHelper
  @@startup_timeout = 15
  def self.startup_timeout; @@startup_timeout; end
  def self.startup_timeout=(seconds); @@startup_timeout = seconds; end
  
  def self.wait_until_solr_starts
    solr_started = false
    ping_uri = URI.parse("#{Sunspot.session.config.solr.url}/ping")
    (@@startup_timeout * 10).times do
      begin
        Net::HTTP.get(ping_uri)
        solr_started = true
        break
      rescue
        sleep(0.1)
      end
    end
    raise "Solr failed to start after 15 seconds" unless solr_started
  end
end