# HTTP::Server plus a fixed pool of fibers, each reusing one keep-alive HTTP::Client.
# Opening one connection per request (as 1.cr does) runs out of sockets at 3000 requests.
require "json"
require "http/server"
require "http/client"

CLIENTS = 32

n = ARGV.size > 0 ? ARGV[0].to_i : 10
port = 20000 + Random.rand(30000)

server = HTTP::Server.new do |context|
  body = context.request.body.try(&.gets_to_end) || "{}"
  context.response.print JSON.parse(body)["value"].as_i
end
server.bind_tcp "127.0.0.1", port, true
spawn { server.listen }

queue = Channel(Int32).new(n)
(1..n).each { |i| queue.send(i) }
queue.close
results = Channel(Int32).new(CLIENTS)

CLIENTS.times do
  spawn do
    client = HTTP::Client.new("127.0.0.1", port)
    sum = 0
    while value = queue.receive?
      loop do
        begin
          response = client.post("/", body: %({"value":#{value}}))
          sum += response.body.to_i
          break
        rescue IO::Error | Socket::Error
          client.close
          sleep 1.millisecond
          client = HTTP::Client.new("127.0.0.1", port)
        end
      end
    end
    client.close
    results.send(sum)
  end
end

puts (1..CLIENTS).sum { results.receive }
