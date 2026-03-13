# frozen_string_literal: true

# Scans files for malware using ClamAV via the clamd TCP socket.
#
# Required:
#   - ClamAV daemon (clamd) running on the configured host/port
#   - Settings.clamav.host and Settings.clamav.port
#
# Usage:
#   result = ClamavScanner.scan(file_content)
#   result.clean?   # => true/false
#   result.virus     # => "Win.Test.EICAR_HDB-1" or nil
#
class ClamavScanner
  Result = Struct.new(:clean, :virus, keyword_init: true) do
    alias_method :clean?, :clean
  end

  class Error < StandardError; end
  class ConnectionError < Error; end

  def self.scan(data)
    new.scan(data)
  end

  def self.available?
    new.ping
  rescue
    false
  end

  def initialize
    @host = ENV["PWP__CLAMAV__HOST"] ||
      (Settings.respond_to?(:clamav) && Settings.clamav.respond_to?(:host) ? Settings.clamav.host : "localhost")
    @port = (ENV["PWP__CLAMAV__PORT"] ||
      (Settings.respond_to?(:clamav) && Settings.clamav.respond_to?(:port) ? Settings.clamav.port : 3310)).to_i
  end

  def ping
    response = command("PING")
    response.strip == "PONG"
  end

  def scan(data)
    socket = connect
    socket.write("zINSTREAM\0")

    # Send data in chunks (max 2048 bytes per chunk)
    offset = 0
    while offset < data.bytesize
      chunk = data.byteslice(offset, 2048)
      socket.write([chunk.bytesize].pack("N"))
      socket.write(chunk)
      offset += 2048
    end

    # Signal end of stream
    socket.write([0].pack("N"))

    response = socket.gets
    socket.close

    parse_response(response)
  rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ETIMEDOUT => e
    raise ConnectionError, "Cannot connect to ClamAV at #{@host}:#{@port}: #{e.message}"
  end

  private

  def connect
    TCPSocket.new(@host, @port)
  end

  def command(cmd)
    socket = connect
    socket.write("z#{cmd}\0")
    response = socket.gets
    socket.close
    response || ""
  end

  def parse_response(response)
    return Result.new(clean: true, virus: nil) if response.nil?

    response = response.strip
    if response.end_with?("OK")
      Result.new(clean: true, virus: nil)
    elsif response.include?("FOUND")
      virus_name = response.match(/: (.+) FOUND/)&.captures&.first
      Result.new(clean: false, virus: virus_name)
    else
      raise Error, "Unexpected ClamAV response: #{response}"
    end
  end
end
