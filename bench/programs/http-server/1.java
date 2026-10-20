// JDK-only HTTP: com.sun.net.httpserver on virtual threads, java.net.http.HttpClient for the requests.
import com.sun.net.httpserver.HttpServer;
import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.Executors;
import java.util.concurrent.ThreadLocalRandom;

final class app {
  public static void main(String[] args) throws Exception {
    int n = args.length > 0 ? Integer.parseInt(args[0]) : 10;
    var server = bind();
    server.createContext("/", exchange -> {
      String body = new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8);
      byte[] response = String.valueOf(parseValue(body)).getBytes(StandardCharsets.UTF_8);
      exchange.sendResponseHeaders(200, response.length);
      try (OutputStream out = exchange.getResponseBody()) {
        out.write(response);
      }
    });
    server.setExecutor(Executors.newVirtualThreadPerTaskExecutor());
    server.start();

    var client = HttpClient.newBuilder().version(HttpClient.Version.HTTP_1_1).build();
    var uri = URI.create("http://127.0.0.1:" + server.getAddress().getPort() + "/");
    List<CompletableFuture<Integer>> futures = new ArrayList<>(n);
    for (int i = 1; i <= n; i++) {
      futures.add(send(client, uri, i));
    }
    long sum = 0;
    for (var future : futures) {
      sum += future.join();
    }
    System.out.println(sum);
    server.stop(0);
    System.exit(0);
  }

  static HttpServer bind() throws IOException {
    for (;;) {
      int port = 20000 + ThreadLocalRandom.current().nextInt(30000);
      try {
        return HttpServer.create(new InetSocketAddress("127.0.0.1", port), 512);
      } catch (java.net.BindException taken) {
        // try another port
      }
    }
  }

  static int parseValue(String body) {
    int colon = body.indexOf(':', body.indexOf("\"value\""));
    int end = colon + 1;
    while (end < body.length() && (body.charAt(end) == '-' || Character.isDigit(body.charAt(end)) || body.charAt(end) == ' ')) {
      end++;
    }
    return Integer.parseInt(body.substring(colon + 1, end).trim());
  }

  static CompletableFuture<Integer> send(HttpClient client, URI uri, int value) {
    var request = HttpRequest.newBuilder(uri)
        .header("Content-Type", "application/json")
        .POST(HttpRequest.BodyPublishers.ofString("{\"value\":" + value + "}"))
        .build();
    return client.sendAsync(request, HttpResponse.BodyHandlers.ofString())
        .thenApply(response -> Integer.parseInt(response.body()))
        .exceptionallyCompose(error -> send(client, uri, value));
  }
}
