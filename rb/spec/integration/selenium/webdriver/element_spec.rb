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

require_relative 'spec_helper'

describe "Element" do

  it "should click" do
    driver.navigate.to url_for("formPage.html")
    driver.find_element(:id, "imageButton").click
  end

  # Marionette BUG - AutomatedTester: "known bug with execute script"
  not_compliant_on :driver => :marionette do
    it "should submit" do
      driver.navigate.to url_for("formPage.html")
      wait(5).until {driver.find_elements(:id, "submitButton").size > 0}
      driver.find_element(:id, "submitButton").submit
    end
  end

  it "should send string keys" do
    driver.navigate.to url_for("formPage.html")
    driver.find_element(:id, "working").send_keys("foo", "bar")
  end

  not_compliant_on :browser => [:android, :iphone, :safari] do
    it "should send key presses" do
      driver.navigate.to url_for("javascriptPage.html")
      key_reporter = driver.find_element(:id, 'keyReporter')

      key_reporter.send_keys("Tet", :arrow_left, "s")
      expect(key_reporter.attribute('value')).to eq("Test")
    end
  end

  # FIXME - Find alternate implementation for File Uploads
  # TODO - Figure out if/how this works on Firefox/Chrome without Remote server
  # PhantomJS on windows issue: https://github.com/ariya/phantomjs/issues/10993
  not_compliant_on({:browser => [:android, :iphone, :safari, :edge, :marionette]},
                   {:browser => :phantomjs, :platform => [:windows, :linux]},
                   {:driver => :marionette}) do
    it "should handle file uploads" do
      driver.navigate.to url_for("formPage.html")

      element = driver.find_element(:id, 'upload')
      expect(element.attribute('value')).to be_empty

      file = Tempfile.new('file-upload')
      path = file.path
      path.gsub!("/", "\\") if WebDriver::Platform.windows?

      element.send_keys path

      expect(element.attribute('value')).to include(File.basename(path))
    end
  end

  it "should get attribute value" do
    driver.navigate.to url_for("formPage.html")
    expect(driver.find_element(:id, "withText").attribute("rows")).to eq("5")
  end

  not_compliant_on :browser => :edge do
    it "should return nil for non-existent attributes" do
      driver.navigate.to url_for("formPage.html")
      expect(driver.find_element(:id, "withText").attribute("nonexistent")).to be_nil
    end
  end

  # Per W3C spec this should return Invalid Argument not Unknown Error, but there is no comparable error code
  compliant_on :browser => :edge do
    it "should return nil for non-existent attributes" do
      driver.navigate.to url_for("formPage.html")
      element = driver.find_element(:id, "withText")
      expect {element.attribute("nonexistent")}.to raise_error(Selenium::WebDriver::Error::UnknownError)
    end
  end

  it "should clear" do
    driver.navigate.to url_for("formPage.html")
    driver.find_element(:id, "withText").clear
  end

  not_compliant_on :browser => :android do
    it "should get and set selected" do
      driver.navigate.to url_for("formPage.html")

      cheese = driver.find_element(:id, "cheese")
      peas   = driver.find_element(:id, "peas")

      cheese.click

      expect(cheese).to be_selected
      expect(peas).not_to be_selected

      peas.click

      expect(peas).to be_selected
      expect(cheese).not_to be_selected
    end
  end

  it "should get enabled" do
    driver.navigate.to url_for("formPage.html")
    expect(driver.find_element(:id, "notWorking")).not_to be_enabled
  end

  it "should get text" do
    driver.navigate.to url_for("xhtmlTest.html")
    expect(driver.find_element(:class, "header").text).to eq("XHTML Might Be The Future")
  end

  it "should get displayed" do
    driver.navigate.to url_for("xhtmlTest.html")
    expect(driver.find_element(:class, "header")).to be_displayed
  end

  # Location not currently supported in Spec, but should be?
  not_compliant_on :driver => :marionette do
    it "should get location" do
      driver.navigate.to url_for("xhtmlTest.html")
      loc = driver.find_element(:class, "header").location

      expect(loc.x).to be >= 1
      expect(loc.y).to be >= 1
    end

    not_compliant_on :browser => [:iphone] do
      it "should get location once scrolled into view" do
        driver.navigate.to url_for("javascriptPage.html")
        loc = driver.find_element(:id, 'keyUp').location_once_scrolled_into_view

        expect(loc.x).to be >= 1
        expect(loc.y).to be >= 0 # can be 0 if scrolled to the top
      end
    end
  end

  # Marionette BUG:
  # GET /session/f7082a32-e685-2843-ad2c-5bb6f376dac5/element/b6ff4468-ed6f-7c44-be4b-ca5a3ea8bf26/size
  # did not match a known command"
  not_compliant_on :driver => :marionette do
    it "should get size" do
      driver.navigate.to url_for("xhtmlTest.html")
      size = driver.find_element(:class, "header").size

      expect(size.width).to be > 0
      expect(size.height).to be > 0
    end
  end

  compliant_on :driver => [:ie, :chrome, :edge] do # Firefox w/native events: issue 1771
    it "should drag and drop" do
      driver.navigate.to url_for("dragAndDropTest.html")

      img1 = driver.find_element(:id, "test1")
      img2 = driver.find_element(:id, "test2")

      driver.action.drag_and_drop_by(img1, 100, 100).
                    drag_and_drop(img2, img1).
                    perform

      expect(img1.location).to eq(img2.location)
    end
  end

  not_compliant_on :browser => [:android] do # android returns 'green'
    it "should get css property" do
      driver.navigate.to url_for("javascriptPage.html")
      element = driver.find_element(:id, "green-parent")

      style1 = element.css_value("background-color")
      style2 = element.style("background-color") # backwards compatibility

      acceptable = ["rgb(0, 128, 0)", "#008000", 'rgba(0,128,0,1)', 'rgba(0, 128, 0, 1)']
      expect(acceptable).to include(style1, style2)
    end
  end

  it "should know when two elements are equal" do
    driver.navigate.to url_for("simpleTest.html")

    body = driver.find_element(:tag_name, 'body')
    xbody = driver.find_element(:xpath, "//body")

    expect(body).to eq(xbody)
    expect(body).to eql(xbody)
  end

  not_compliant_on :browser => :phantomjs do
    it "should know when two elements are not equal" do
      driver.navigate.to url_for("simpleTest.html")

      elements = driver.find_elements(:tag_name, 'p')
      p1 = elements.fetch(0)
      p2 = elements.fetch(1)

      expect(p1).not_to eq(p2)
      expect(p1).not_to eql(p2)
    end
  end

  it "should return the same #hash for equal elements when found by Driver#find_element" do
    driver.navigate.to url_for("simpleTest.html")

    body = driver.find_element(:tag_name, 'body')
    xbody = driver.find_element(:xpath, "//body")

    expect(body.hash).to eq(xbody.hash)
  end

  it "should return the same #hash for equal elements when found by Driver#find_elements" do
    driver.navigate.to url_for("simpleTest.html")

    body = driver.find_elements(:tag_name, 'body').fetch(0)
    xbody = driver.find_elements(:xpath, "//body").fetch(0)

    expect(body.hash).to eq(xbody.hash)
  end

end
