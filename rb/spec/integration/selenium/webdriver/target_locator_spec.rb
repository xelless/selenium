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

require File.expand_path("../spec_helper", __FILE__)

describe "Selenium::WebDriver::TargetLocator" do
  let(:wait) { Selenium::WebDriver::Wait.new }

  # Edge does not yet support session/:session_id/element/active
  not_compliant_on :browser => :edge do
    it "should find the active element" do
      driver.navigate.to url_for("xhtmlTest.html")
      driver.switch_to.active_element.should be_an_instance_of(WebDriver::Element)
    end
  end

  # Edge does not yet support /session/:sessionId/frame
  not_compliant_on :browser => [:iphone, :edge] do
    it "should switch to a frame" do
      driver.navigate.to url_for("iframes.html")
      driver.switch_to.frame("iframe1")

      driver.find_element(:name, 'login').should be_kind_of(WebDriver::Element)
    end

    # Edge does not yet support /session/:sessionId/frame
    not_compliant_on :browser => :edge do
      it "should switch to a frame by Element" do
        driver.navigate.to url_for("iframes.html")

        iframe = driver.find_element(:tag_name => "iframe")
        driver.switch_to.frame(iframe)

        driver.find_element(:name, 'login').should be_kind_of(WebDriver::Element)
      end
    end
  end

  # Edge does not yet support /session/:sessionId/frame/parent
  not_compliant_on :browser => [:safari, :phantomjs, :edge] do
    it "should switch to parent frame" do
      driver.navigate.to url_for("iframes.html")

      iframe = driver.find_element(:tag_name => "iframe")
      driver.switch_to.frame(iframe)

      driver.find_element(:name, 'login').should be_kind_of(WebDriver::Element)

      driver.switch_to.parent_frame
      driver.find_element(:id, 'iframe_page_heading').should be_kind_of(WebDriver::Element)
    end
  end

  # Edge implements switching with w3c specs, not json
  # Edge also appears to have issues closing windows
  # switching by name not yet supported by safari
  not_compliant_on :browser => [:ie, :iphone, :safari, :edge] do
    after do
      reset_driver!
    end

    it "should switch to a window and back when given a block" do
      driver.navigate.to url_for("xhtmlTest.html")

      driver.find_element(:link, "Open new window").click
      driver.title.should == "XHTML Test Page"

      driver.switch_to.window("result") do
        wait.until { driver.title == "We Arrive Here" }
      end

      wait.until { driver.title == "XHTML Test Page" }

    end

    it "should handle exceptions inside the block" do
      driver.navigate.to url_for("xhtmlTest.html")

      driver.find_element(:link, "Open new window").click
      driver.title.should == "XHTML Test Page"

      lambda {
        driver.switch_to.window("result") { raise "foo" }
      }.should raise_error(RuntimeError, "foo")

      driver.title.should == "XHTML Test Page"
    end

    it "should switch to a window" do
      driver.navigate.to url_for("xhtmlTest.html")

      driver.find_element(:link, "Open new window").click
      driver.title.should == "XHTML Test Page"

      driver.switch_to.window("result")
      driver.title.should == "We Arrive Here"
    end

    it "should use the original window if the block closes the popup" do
      driver.navigate.to url_for("xhtmlTest.html")

      driver.find_element(:link, "Open new window").click
      driver.title.should == "XHTML Test Page"

      driver.switch_to.window("result") do
        wait.until { driver.title == "We Arrive Here" }
        driver.close
      end

      driver.current_url.should include("xhtmlTest.html")
      driver.title.should == "XHTML Test Page"
    end

    it "should close current window when more than two windows exist" do
      driver.navigate.to url_for("xhtmlTest.html")
      driver.find_element(:link, "Create a new anonymous window").click
      driver.find_element(:link, "Open new window").click

      wait.until { driver.window_handles.size == 3 }

      driver.switch_to.window(driver.window_handle) {driver.close}
      expect(driver.window_handles.size).to eq 2
    end

    it "should close another window when more than two windows exist" do
      driver.navigate.to url_for("xhtmlTest.html")
      driver.find_element(:link, "Create a new anonymous window").click
      driver.find_element(:link, "Open new window").click

      wait.until { driver.window_handles.size == 3 }

      window_to_close = driver.window_handles.last

      driver.switch_to.window(window_to_close) { driver.close }
      expect(driver.window_handles.size).to eq 2
    end

    it "should iterate over open windows when current window is not closed" do
      driver.navigate.to url_for("xhtmlTest.html")
      driver.find_element(:link, "Create a new anonymous window").click
      driver.find_element(:link, "Open new window").click

      wait.until { driver.window_handles.size == 3 }

      new_window = driver.window_handles.find do |wh|
        driver.switch_to.window(wh) { driver.title == "We Arrive Here" }
      end

      driver.switch_to.window(new_window)
      driver.title.should == "We Arrive Here"
    end

    it "should iterate over open windows when current window is closed" do
      driver.navigate.to url_for("xhtmlTest.html")
      driver.find_element(:link, "Create a new anonymous window").click
      driver.find_element(:link, "Open new window").click

      wait.until { driver.window_handles.size == 3 }

      driver.close

      new_window = driver.window_handles.find do |wh|
        driver.switch_to.window(wh) { driver.title == "We Arrive Here" }
      end

      driver.switch_to.window(new_window)
      driver.title.should == "We Arrive Here"
    end

    it "should switch to a window and execute a block when current window is closed" do
      driver.navigate.to url_for("xhtmlTest.html")
      driver.find_element(:link, "Open new window").click

      wait.until { driver.window_handles.size == 2 }

      driver.switch_to.window("result")
      wait.until { driver.title == "We Arrive Here" }

      driver.close

      driver.switch_to.window(driver.window_handles.first) do
        wait.until { driver.title == "XHTML Test Page" }
      end

      driver.title.should == "XHTML Test Page"
    end
  end

  # Edge does not yet support /session/:sessionId/frame
  not_compliant_on :browser => [:android, :iphone, :safari, :edge] do
    it "should switch to default content" do
      driver.navigate.to url_for("iframes.html")

      driver.switch_to.frame 0
      driver.switch_to.default_content

      driver.find_element(:id => "iframe_page_heading")
    end
  end

  describe "alerts" do
    not_compliant_on :browser => [:iphone, :safari, :phantomjs] do
      it "allows the user to accept an alert" do
        driver.navigate.to url_for("alerts.html")
        driver.find_element(:id => "alert").click

        alert = wait_for_alert
        alert.accept

        driver.title.should == "Testing Alerts"
      end
    end

    not_compliant_on({:browser => :chrome, :platform => :macosx},
                     {:browser => :iphone},
                     {:browser => :safari},
                     {:browser => :phantomjs}) do
      it "allows the user to dismiss an alert" do
        driver.navigate.to url_for("alerts.html")
        driver.find_element(:id => "alert").click

        alert = wait_for_alert
        alert.dismiss

        wait_for_no_alert

        driver.title.should == "Testing Alerts"
      end
    end

    # Edge does not yet support session/:session_id/alert_text
    not_compliant_on :browser => [:iphone, :safari, :phantomjs, :edge] do
      it "allows the user to set the value of a prompt" do
        driver.navigate.to url_for("alerts.html")
        driver.find_element(:id => "prompt").click

        alert = wait_for_alert
        alert.send_keys "cheese"
        alert.accept

        text = driver.find_element(:id => "text").text
        text.should == "cheese"
      end

      # Edge does not yet support session/:session_id/alert_text
      not_compliant_on :browser => :edge do
        it "allows the user to get the text of an alert" do
          driver.navigate.to url_for("alerts.html")
          driver.find_element(:id => "alert").click

          alert = wait_for_alert
          text = alert.text
          alert.accept

          text.should == "cheese"
        end
      end

      # Edge does not yet support session/:session_id/alert_text
      not_compliant_on :browser => :edge do
        it "raises when calling #text on a closed alert" do
          driver.navigate.to url_for("alerts.html")
          driver.find_element(:id => "alert").click

          alert = wait_for_alert
          alert.accept

          expect { alert.text }.to raise_error(Selenium::WebDriver::Error::NoAlertPresentError)
        end
      end

    end

    not_compliant_on :browser => [:ie, :iphone, :safari, :phantomjs] do
      it "raises NoAlertOpenError if no alert is present" do
        lambda { driver.switch_to.alert }.should raise_error(
          Selenium::WebDriver::Error::NoAlertPresentError, /alert|modal dialog/i)
      end
    end

    compliant_on :browser => [:firefox, :ie] do
      it "raises an UnhandledAlertError if an alert has not been dealt with" do
        driver.navigate.to url_for("alerts.html")
        driver.find_element(:id => "alert").click
        wait_for_alert

        lambda { driver.title }.should raise_error(Selenium::WebDriver::Error::UnhandledAlertError, /cheese/)

        driver.title.should == "Testing Alerts" # :chrome does not auto-dismiss the alert
      end
    end

  end
end

