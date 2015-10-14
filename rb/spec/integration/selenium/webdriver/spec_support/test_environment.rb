# encoding: utf-8
#
# Licensed to the Software Freedom Conservancy (SFC) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The SFC licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

module Selenium
  module WebDriver
    module SpecSupport
      class TestEnvironment

        attr_accessor :unguarded
        attr_reader :driver

        def initialize
          @create_driver_error       = nil
          @create_driver_error_count = 0

          # TODO: get rid of ENV
          @driver = (ENV['WD_SPEC_DRIVER'] || raise("must set WD_SPEC_DRIVER")).strip.to_sym
        end

        def browser
          if driver == :remote
            (ENV['WD_REMOTE_BROWSER'] || :firefox).to_sym
          elsif driver == :marionette
            :firefox
          else
            driver
          end
        end

        def driver_instance
          @driver_instance ||= new_driver_instance
        end

        def reset_driver!
          quit_driver
          @driver_instance = new_driver_instance
        end

        def quit_driver
          if @driver_instance
            @driver_instance.quit
            @driver_instance = nil
          end
        end

        def new_driver_instance
          check_for_previous_error
          create_driver
        end

        def app_server
          @app_server ||= (
            s = RackServer.new(root.join("common/src/web").to_s)
            s.start

            s
          )
        end

        def remote_server
          @remote_server ||= (
            Selenium::Server.new(remote_server_jar,
              :port       => PortProber.above(4444),
              :log        => !!$DEBUG,
              :background => true,
              :timeout    => 60
            )
          )
        end

        def remote_server_jar
          @remote_server_jar ||= root.join("build/java/server/test/org/openqa/selenium/server-with-tests-standalone.jar").to_s
        end

        def quit
          app_server.stop

          if defined?(@remote_server)
            @remote_server.stop
          end

          @driver_instance = @app_server = @remote_server = nil
        ensure
          Guards.report
        end

        def unguarded?
          @unguarded ||= false
        end

        def native_events?
          @native_events ||= !!ENV['native']
        end

        def url_for(filename)
          url = app_server.where_is filename
          url.sub!("127.0.0.1", "10.0.2.2") if browser == :android

          url
        end

        def root
          @root ||= Pathname.new("../../../../../../../").expand_path(__FILE__)
        end

        private

        def create_driver
          instance = case driver
                     when :remote
                       create_remote_driver
                     when :firefox
                       create_firefox_driver
                     when :marionette
                       create_marionette_driver
                     when :chrome
                       create_chrome_driver
                     when :iphone
                       create_iphone_driver
                     when :safari
                       create_safari_driver
                     when :phantomjs
                       create_phantomjs_driver
                     else
                       WebDriver::Driver.for driver
                     end

          @create_driver_error_count -= 1 unless @create_driver_error_count == 0
          instance
        rescue => ex
          @create_driver_error = ex
          @create_driver_error_count += 1
          raise ex
        end

        def remote_capabilities
          if ENV['WD_REMOTE_BROWSER'] == 'marionette'
            caps = WebDriver::Remote::W3CCapabilities.firefox
            caps[:marionette] = true
          else
            caps = WebDriver::Remote::Capabilities.send(ENV['WD_REMOTE_BROWSER'] || 'firefox')

            caps.javascript_enabled = true
            caps.css_selectors_enabled = true
          end

          caps
        end

        MAX_ERRORS = 4

        class DriverInstantiationError < StandardError
        end

        def check_for_previous_error
          return unless @create_driver_error && @create_driver_error_count >= MAX_ERRORS

          msg = "previous #{@create_driver_error_count} instantiations of driver #{driver.inspect} failed, not trying again"
          msg << " (#{@create_driver_error.message})"

          raise DriverInstantiationError, msg, @create_driver_error.backtrace
        end

        def create_remote_driver
          WebDriver::Driver.for(:remote,
            :desired_capabilities => remote_capabilities,
            :url                  => ENV['WD_REMOTE_URL'] || remote_server.webdriver_url,
            :http_client          => keep_alive_client || http_client
          )
        end

        def create_firefox_driver
          if native_events?
            profile = WebDriver::Firefox::Profile.new
            profile.native_events = true

            WebDriver::Driver.for :firefox, :profile => profile
          else
            WebDriver::Driver.for :firefox
          end
        end

        def create_marionette_driver
          caps = WebDriver::Remote::W3CCapabilities.firefox
          WebDriver.for :firefox, :desired_capabilities => caps
        end

        def create_chrome_driver
          binary = ENV['chrome_binary']
          if binary
            WebDriver::Chrome.path = binary
          end

          server = ENV['chromedriver'] || ENV['chrome_server']
          if server
            WebDriver::Chrome.driver_path = server
          end

          args = []
          args << "--no-sandbox" if ENV['TRAVIS']

          WebDriver::Driver.for :chrome,
                                :native_events => native_events?,
                                :args          => args
        end

        def create_phantomjs_driver
          binary = ENV['phantomjs_binary']
          if binary
            WebDriver::PhantomJS.path = binary
          end

          WebDriver::Driver.for :phantomjs
        end

        def create_iphone_driver
          url = ENV['iphone_url']
          if url
            WebDriver::Driver.for :iphone, :url => url
          else
            WebDriver::Driver.for :iphone
          end
        end

        def create_safari_driver
          if ENV['timeout']
            WebDriver::Driver.for :safari, :timeout => Integer(ENV['timeout'])
          else
            WebDriver::Driver.for :safari
          end
        end

        def keep_alive_client
          require 'selenium/webdriver/remote/http/persistent'
          STDERR.puts "INFO: using net-http-persistent"

          Selenium::WebDriver::Remote::Http::Persistent.new
        rescue LoadError
           # net-http-persistent not available
        end

        def http_client
          Selenium::WebDriver::Remote::Http::Default.new
        end

      end # TestEnvironment
    end # SpecSupport
  end # WebDriver
end # Selenium
