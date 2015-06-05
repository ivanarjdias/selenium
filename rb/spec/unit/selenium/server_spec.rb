# encoding: utf-8

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

require File.expand_path('../webdriver/spec_helper', __FILE__)
require 'selenium/server'

describe Selenium::Server do
  let(:mock_process) { double(ChildProcess).as_null_object }
  let(:mock_poller)  { double("SocketPoller", :connected? => true, :closed? => true)}

  it "raises an error if the jar file does not exist" do
    lambda {
      Selenium::Server.new("doesnt-exist.jar")
    }.should raise_error(Errno::ENOENT)
  end

  it "uses the given jar file and port" do
    File.should_receive(:exist?).with("selenium-server-test.jar").and_return(true)

    ChildProcess.should_receive(:build).
                 with("java", "-jar", "selenium-server-test.jar", "-port", "1234").
                 and_return(mock_process)

    server = Selenium::Server.new("selenium-server-test.jar", :port => 1234, :background => true)
    server.stub(:socket).and_return(mock_poller)

    server.start
  end

  it "waits for the server process by default" do
    File.should_receive(:exist?).with("selenium-server-test.jar").and_return(true)

    ChildProcess.should_receive(:build).
                 with("java", "-jar", "selenium-server-test.jar", "-port", "4444").
                 and_return(mock_process)

    server = Selenium::Server.new("selenium-server-test.jar")
    server.stub(:socket).and_return(mock_poller)

    mock_process.should_receive(:wait)
    server.start
  end

  it "adds additional args" do
    File.should_receive(:exist?).with("selenium-server-test.jar").and_return(true)

    ChildProcess.should_receive(:build).
                 with("java", "-jar", "selenium-server-test.jar", "-port", "4444", "foo", "bar").
                 and_return(mock_process)

    server = Selenium::Server.new("selenium-server-test.jar", :background => true)
    server.stub(:socket).and_return(mock_poller)

    server << ["foo", "bar"]

    server.start
  end

  it "downloads the specified version from the selenium site" do
    required_version = '10.2.0'
    expected_download_file_name = "selenium-server-standalone-#{required_version}.jar"

    stub_request(:get, "http://selenium-release.storage.googleapis.com/10.2/selenium-server-standalone-10.2.0.jar").to_return(:body => "this is pretending to be a jar file for testing purposes")

    begin
      actual_download_file_name = Selenium::Server.download(required_version)
      actual_download_file_name.should == expected_download_file_name
      File.should exist(expected_download_file_name)
    ensure
      FileUtils.rm_rf expected_download_file_name
    end
  end

  it "gets a server instance and downloads the specified version" do
    required_version = '10.4.0'
    expected_download_file_name = "selenium-server-standalone-#{required_version}.jar"
    expected_options = {:port => 5555}
    fake_server = Object.new

    Selenium::Server.should_receive(:download).with(required_version).and_return(expected_download_file_name)
    Selenium::Server.should_receive(:new).with(expected_download_file_name, expected_options).and_return(fake_server)
    server = Selenium::Server.get required_version, expected_options
    server.should == fake_server
  end

  it "automatically repairs http_proxy settings that do not start with http://" do
    with_env("http_proxy" => "proxy.com") do
      Selenium::Server.net_http.proxy_address.should == 'proxy.com'
    end

    with_env("HTTP_PROXY" => "proxy.com") do
      Selenium::Server.net_http.proxy_address.should == 'proxy.com'
    end
  end

  it "only downloads a jar if it is not present in the current directory" do
    required_version = '10.2.0'
    expected_download_file_name = "selenium-server-standalone-#{required_version}.jar"

    File.should_receive(:exists?).with(expected_download_file_name).and_return true

    Selenium::Server.download required_version
  end

  it "should know what the latest version available is" do
    latest_version = '2.42.2'
    example_xml ="<?xml version='1.0' encoding='UTF-8'?><ListBucketResult xmlns='http://doc.s3.amazonaws.com/2006-03-01'><Name>selenium-release</Name><Contents><Key>2.39/selenium-server-2.39.0.zip</Key></Contents><Contents><Key>2.42/selenium-server-standalone-#{latest_version}.jar</Key></Contents></ListBucketResult>"
    stub_request(:get, "http://selenium-release.storage.googleapis.com/").to_return(:body => example_xml)

    Selenium::Server.latest.should == latest_version
  end

  it "should download the latest version if that has been specified" do
    required_version, minor_version = '2.42.2', '2.42'
    expected_download_file_name = "selenium-server-standalone-#{required_version}.jar"

    Selenium::Server.should_receive(:latest).and_return required_version
    stub_request(:get, "http://selenium-release.storage.googleapis.com/#{minor_version}/#{expected_download_file_name}").to_return(:body => "this is pretending to be a jar file for testing purposes")

    begin
      actual_download_file_name = Selenium::Server.download(:latest)
      actual_download_file_name.should == expected_download_file_name
      File.should exist(expected_download_file_name)
    ensure
      FileUtils.rm_rf expected_download_file_name
    end
  end

  it "raises Selenium::Server::Error if the server is not launched within the timeout" do
    File.should_receive(:exist?).with("selenium-server-test.jar").and_return(true)

    poller = double('SocketPoller')
    poller.should_receive(:connected?).and_return(false)

    server = Selenium::Server.new("selenium-server-test.jar", :background => true)
    server.stub(:socket).and_return(poller)

    lambda { server.start }.should raise_error(Selenium::Server::Error)
  end

  it "sets options after instantiation" do
    File.should_receive(:exist?).with("selenium-server-test.jar").and_return(true)
    server = Selenium::Server.new("selenium-server-test.jar")
    server.port.should == 4444
    server.timeout.should == 30
    server.background.should be false
    server.log.should be_nil

    server.port = 1234
    server.timeout = 5
    server.background = true
    server.log = "/tmp/server.log"
  end
end
