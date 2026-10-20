# A threaded TCPServer speaking minimal HTTP/1.1, and a pool of client threads reusing keep-alive
# Net::HTTP connections. (1.rb is a socket demo that never answers the benchmark's requests.)
require 'socket'
require 'json'
require 'net/http'

CLIENTS = 32

def serve_connection(socket)
  loop do
    length = 0
    while (line = socket.gets)
      break if line == "\r\n"
      length = line.split(':', 2)[1].to_i if line.downcase.start_with?('content-length:')
    end
    break if line.nil?
    value = JSON.parse(socket.read(length))['value']
    body = value.to_s
    socket.write("HTTP/1.1 200 OK\r\nContent-Length: #{body.bytesize}\r\n\r\n#{body}")
  end
rescue IOError, SystemCallError
  # the client went away
ensure
  socket.close
end

n = (ARGV[0] || 10).to_i
server = nil
port = nil
loop do
  port = 20_000 + rand(30_000)
  server = TCPServer.new('127.0.0.1', port)
  break
rescue Errno::EADDRINUSE
  next
end
Thread.new { loop { Thread.new(server.accept) { |socket| serve_connection(socket) } } }

queue = Queue.new
(1..n).each { |i| queue << i }
queue.close
sums = Array.new(CLIENTS) do
  Thread.new do
    sum = 0
    http = Net::HTTP.start('127.0.0.1', port)
    while (value = queue.pop)
      begin
        response = http.post('/', { value: value }.to_json, 'Content-Type' => 'application/json')
        sum += response.body.to_i
      rescue IOError, SystemCallError, Net::HTTPBadResponse
        http = Net::HTTP.start('127.0.0.1', port)
        retry
      end
    end
    http.finish
    sum
  end
end
puts sums.sum(&:value)
