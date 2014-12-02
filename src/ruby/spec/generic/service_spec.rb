# Copyright 2014, Google Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
#     * Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above
# copyright notice, this list of conditions and the following disclaimer
# in the documentation and/or other materials provided with the
# distribution.
#     * Neither the name of Google Inc. nor the names of its
# contributors may be used to endorse or promote products derived from
# this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

require 'grpc'
require 'grpc/generic/rpc_desc'
require 'grpc/generic/service'


class GoodMsg
  def marshal
    ''
  end

  def self.unmarshal(o)
    GoodMsg.new
  end
end

class EncodeDecodeMsg
  def encode
    ''
  end

  def self.decode(o)
    GoodMsg.new
  end
end

GenericService = GRPC::GenericService
RpcDesc = GRPC::RpcDesc
Dsl = GenericService::Dsl


describe 'String#underscore' do
  it 'should convert CamelCase to underscore separated' do
    expect('AnRPC'.underscore).to eq('an_rpc')
    expect('AMethod'.underscore).to eq('a_method')
    expect('PrintHTML'.underscore).to eq('print_html')
    expect('PrintHTMLBooks'.underscore).to eq('print_html_books')
  end
end

describe Dsl do

  it 'can be included in new classes' do
    blk = Proc.new do
      c = Class.new { include Dsl }
    end
    expect(&blk).to_not raise_error
  end

end

describe GenericService do

  describe 'including it' do

    it 'adds a class method, rpc' do
      c = Class.new do
        include GenericService
      end
      expect(c.methods).to include(:rpc)
    end

    it 'adds rpc descs using the added class method, #rpc' do
      c = Class.new do
        include GenericService
        rpc :AnRpc, GoodMsg, GoodMsg
      end

      expect(c.rpc_descs).to include(:AnRpc)
      expect(c.rpc_descs[:AnRpc]).to be_a(RpcDesc)
    end

    it 'give subclasses access to #rpc_descs' do
      base = Class.new do
        include GenericService
        rpc :AnRpc, GoodMsg, GoodMsg
      end
      c = Class.new(base) do
      end
      expect(c.rpc_descs).to include(:AnRpc)
      expect(c.rpc_descs[:AnRpc]).to be_a(RpcDesc)
    end

  end

  describe '#include' do

    it 'raises if #rpc is missing an arg' do
      blk = Proc.new do
        Class.new do
          include GenericService
          rpc :AnRpc, GoodMsg
        end
      end
      expect(&blk).to raise_error ArgumentError

      blk = Proc.new do
        Class.new do
          include GenericService
          rpc :AnRpc
        end
      end
      expect(&blk).to raise_error ArgumentError
    end

    describe 'when #rpc args are incorrect' do

      it 'raises if an arg does not have the marshal or unmarshal methods' do
        blk = Proc.new do
          Class.new do
            include GenericService
            rpc :AnRpc, GoodMsg, Object
          end
        end
        expect(&blk).to raise_error ArgumentError
      end

      it 'raises if a type arg only has the marshal method' do
        class OnlyMarshal
          def marshal(o)
            o
          end
        end

        blk = Proc.new do
          Class.new do
            include GenericService
            rpc :AnRpc, OnlyMarshal, GoodMsg
          end
        end
        expect(&blk).to raise_error ArgumentError
      end

      it 'raises if a type arg only has the unmarshal method' do
        class OnlyUnmarshal
          def self.ummarshal(o)
            o
          end
        end
        blk = Proc.new do
          Class.new do
            include GenericService
            rpc :AnRpc, GoodMsg, OnlyUnmarshal
          end
        end
        expect(&blk).to raise_error ArgumentError
      end
    end

    it 'is ok for services that expect the default {un,}marshal methods' do
      blk = Proc.new do
        Class.new do
          include GenericService
          rpc :AnRpc, GoodMsg, GoodMsg
        end
      end
      expect(&blk).not_to raise_error
    end

    it 'is ok for services that override the default {un,}marshal methods' do
      blk = Proc.new do
        Class.new do
          include GenericService
          self.marshal_instance_method = :encode
          self.unmarshal_class_method = :decode
          rpc :AnRpc, EncodeDecodeMsg, EncodeDecodeMsg
        end
      end
      expect(&blk).not_to raise_error
    end

  end

  describe '#rpc_stub_class' do

    it 'generates a client class that defines any of the rpc methods' do
      s = Class.new do
        include GenericService
        rpc :AnRpc, GoodMsg, GoodMsg
        rpc :AServerStreamer, GoodMsg, stream(GoodMsg)
        rpc :AClientStreamer, stream(GoodMsg), GoodMsg
        rpc :ABidiStreamer, stream(GoodMsg), stream(GoodMsg)
      end
      client_class = s.rpc_stub_class
      expect(client_class.instance_methods).to include(:an_rpc)
      expect(client_class.instance_methods).to include(:a_server_streamer)
      expect(client_class.instance_methods).to include(:a_client_streamer)
      expect(client_class.instance_methods).to include(:a_bidi_streamer)
    end

    describe 'the generated instances' do

      it 'can be instanciated with just a hostname' do
        s = Class.new do
          include GenericService
          rpc :AnRpc, GoodMsg, GoodMsg
          rpc :AServerStreamer, GoodMsg, stream(GoodMsg)
          rpc :AClientStreamer, stream(GoodMsg), GoodMsg
          rpc :ABidiStreamer, stream(GoodMsg), stream(GoodMsg)
        end
        client_class = s.rpc_stub_class
        expect { client_class.new('fakehostname') }.not_to raise_error
      end

      it 'has the methods defined in the service' do
        s = Class.new do
          include GenericService
          rpc :AnRpc, GoodMsg, GoodMsg
          rpc :AServerStreamer, GoodMsg, stream(GoodMsg)
          rpc :AClientStreamer, stream(GoodMsg), GoodMsg
          rpc :ABidiStreamer, stream(GoodMsg), stream(GoodMsg)
        end
        client_class = s.rpc_stub_class
        o = client_class.new('fakehostname')
        expect(o.methods).to include(:an_rpc)
        expect(o.methods).to include(:a_bidi_streamer)
        expect(o.methods).to include(:a_client_streamer)
        expect(o.methods).to include(:a_bidi_streamer)
      end

    end

  end

  describe '#assert_rpc_descs_have_methods' do

    it 'fails if there is no instance method for an rpc descriptor' do
      c1 = Class.new do
        include GenericService
        rpc :AnRpc, GoodMsg, GoodMsg
      end
      expect { c1.assert_rpc_descs_have_methods }.to raise_error

      c2 = Class.new do
        include GenericService
        rpc :AnRpc, GoodMsg, GoodMsg
        rpc :AnotherRpc, GoodMsg, GoodMsg

        def an_rpc
        end
      end
      expect { c2.assert_rpc_descs_have_methods }.to raise_error
    end

    it 'passes if there are corresponding methods for each descriptor' do
      c = Class.new do
        include GenericService
        rpc :AnRpc, GoodMsg, GoodMsg
        rpc :AServerStreamer, GoodMsg, stream(GoodMsg)
        rpc :AClientStreamer, stream(GoodMsg), GoodMsg
        rpc :ABidiStreamer, stream(GoodMsg), stream(GoodMsg)

        def an_rpc(req, call)
        end

        def a_server_streamer(req, call)
        end

        def a_client_streamer(call)
        end

        def a_bidi_streamer(call)
        end
      end
      expect { c.assert_rpc_descs_have_methods }.to_not raise_error
    end

    it 'passes for subclasses of that include GenericService' do
      base = Class.new do
        include GenericService
        rpc :AnRpc, GoodMsg, GoodMsg

        def an_rpc(req, call)
        end
      end
      c = Class.new(base)
      expect { c.assert_rpc_descs_have_methods }.to_not raise_error
      expect(c.include?(GenericService)).to be(true)
    end

    it 'passes if subclasses define the rpc methods' do
      base = Class.new do
        include GenericService
        rpc :AnRpc, GoodMsg, GoodMsg
      end
      c = Class.new(base) do
        def an_rpc(req, call)
        end
      end
      expect { c.assert_rpc_descs_have_methods }.to_not raise_error
      expect(c.include?(GenericService)).to be(true)
    end

  end

end