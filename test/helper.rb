%w( rubygems test/spec mocha ).each { |f| require f }
# protect TextMate from redgreen
require 'redgreen' if ENV['TM_FILENAME'].nil?
 
$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require 'chewy'


require File.join(File.dirname(__FILE__), "helper")