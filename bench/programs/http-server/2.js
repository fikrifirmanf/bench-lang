// Upstream's 1.js listens on "localhost" and requests "localhost". Node resolves the two to different addresses
// (::1 for the server, 127.0.0.1 for the client), so every request is refused and its retry loop never ends.
// This version binds and connects to 127.0.0.1 and gives up after repeated failures instead of hanging.
const http = require("http");

const host = "127.0.0.1";
const MAX_ATTEMPTS = 100;

function requestListener(req, res) {
	let body = "";
	req.on("data", (chunk) => {
		body += chunk;
	});
	req.on("end", () => {
		const payload = JSON.parse(body);
		res.writeHead(200);
		res.end(payload.value.toString());
	});
}

function send(api, value) {
	return new Promise((onFulfilled, onRejected) => {
		const req = http.request(
			api,
			{ method: "POST", headers: { "content-type": "application/json" } },
			(res) => {
				let content = "";
				res.on("data", (chunk) => {
					content += chunk;
				});
				res.on("end", () => onFulfilled(+content));
			},
		);
		req.on("error", onRejected);
		req.write(JSON.stringify({ value: value }));
		req.end();
	});
}

async function sendAsync(api, value) {
	for (let attempt = 1; ; attempt++) {
		try {
			return await send(api, value);
		} catch (e) {
			if (attempt >= MAX_ATTEMPTS) throw e;
		}
	}
}

async function calculateSum(port, n) {
	const api = `http://${host}:${port}/`;
	const tasks = [];
	for (let i = 1; i <= n; i++) {
		tasks.push(sendAsync(api, i));
	}
	let sum = 0;
	for (const task of tasks) {
		sum += await task;
	}
	console.log(sum);
}

function main() {
	const n = +process.argv[2] || 10;
	const port = 20000 + Math.floor(Math.random() * 30000);
	const server = http.createServer(requestListener);
	server.listen(port, host, async () => {
		try {
			await calculateSum(port, n);
		} catch (e) {
			console.error(e);
			process.exitCode = 1;
		}
		server.close();
		server.closeAllConnections();
	});
}

main();
