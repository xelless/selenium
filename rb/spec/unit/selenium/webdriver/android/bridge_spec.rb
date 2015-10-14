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

require File.expand_path("../../spec_helper", __FILE__)


module Selenium
  module WebDriver
    module Android
      describe Android do
        let(:default_url) { URI.parse(Android::Bridge::DEFAULT_URL) }
        let(:resp)        { {"sessionId" => "foo", "value" => Remote::Capabilities.android.as_json }}
        let(:http)        { double(Remote::Http::Default, :call => resp).as_null_object   }

        it "uses the default Android driver URL" do
          expect(http).to receive(:server_url=).with default_url
          Bridge.new(:http_client => http)
        end

        it "uses the user-provided URL" do
          expect(http).to receive(:server_url=).with URI.parse("http://example.com")
          Bridge.new(:http_client => http, :url => "http://example.com")
        end

        it "uses the default HTTP client when none is specified" do
          expect(Remote::Http::Default).to receive(:new).and_return http
          Bridge.new
        end

        it 'takes desired capabilities' do
          custom_caps = Remote::Capabilities.new
          custom_caps['foo'] = 'bar'

          expect(http).to receive(:call) do |_, _, payload|
            expect(payload[:desiredCapabilities]['foo']).to eq('bar')
            resp
          end

          Bridge.new(:http_client => http, :desired_capabilities => custom_caps)
        end
      end

    end # IPhone
  end # WebDriver
end # Selenium

