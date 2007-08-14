$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../lib"
require 'test/unit'
require 'mocha'
require 'net/ssh/buffer'
require 'net/ssh/loggable'
require 'net/ssh/packet'
require 'net/ssh/transport/session'
require 'ostruct'

def P(*args)
  Net::SSH::Packet.new(Net::SSH::Buffer.from(*args))
end

class MockTransport < Net::SSH::Transport::Session
  class BlockVerifier
    def initialize(block)
      @block = block
    end

    def verify(data)
      @block.call(data)
    end
  end

  attr_reader :host_key_verifier
  attr_accessor :host_as_string
  attr_accessor :server_version

  attr_reader :client_options
  attr_reader :server_options
  attr_reader :hints

  def initialize(options={})
    self.logger = options[:logger]
    self.host_as_string = "net.ssh.test,127.0.0.1"
    self.server_version = OpenStruct.new(:version => "SSH-2.0-Ruby/Net::SSH::Test")
    @expectation = nil
    @queue = []
    @hints = {}
    verifier { |data| true }
  end

  def send_message(message)
    buffer = Net::SSH::Buffer.new(message.to_s)
    if @expectation.nil?
      raise "got #{message.to_s.inspect} but was not expecting anything"
    else
      block, @expectation = @expectation, nil
      block.call(self, Net::SSH::Packet.new(buffer))
    end
  end

  def next_message
    @queue.shift or raise "expected a message from the server but nothing was ready to send"
  end

  def return(type, *args)
    @queue << P(:byte, type, *args)
  end

  def expect(&block)
    @expectation = block
  end

  def expect!
    expect {}
  end

  def verifier(&block)
    @host_key_verifier = BlockVerifier.new(block)
  end

  def configure_client(options)
    @client_options = options
  end

  def configure_server(options)
    @server_options = options
  end

  def hint(name, value=true)
    @hints[name] = value
  end
end