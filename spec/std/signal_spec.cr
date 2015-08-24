require "spec"
require "signal"

describe "Signal" do
  typeof(Signal::PIPE.reset)
  typeof(Signal::PIPE.ignore)
  typeof(Signal::PIPE.trap { 1 })
  typeof(Signal::PIPE.trap_raw { 1 })
end
