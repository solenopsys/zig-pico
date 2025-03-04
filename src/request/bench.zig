const std = @import("std");
const picozig = @import("./picozig.zig");

const REQ =
    "GET /wp-content/uploads/2010/03/hello-kitty-darth-vader-pink.jpg HTTP/1.1\r\n" ++
    "Host: www.kittyhell.com\r\n" ++
    "User-Agent: Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.6; ja-JP-mac; rv:1.9.2.3) Gecko/20100401 Firefox/3.6.3 " ++
    "Pathtraq/0.9\r\n" ++
    "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\r\n" ++
    "Accept-Language: ja,en-us;q=0.7,en;q=0.3\r\n" ++
    "Accept-Encoding: gzip,deflate\r\n" ++
    "Accept-Charset: Shift_JIS,utf-8;q=0.7,*;q=0.7\r\n" ++
    "Keep-Alive: 115\r\n" ++
    "Connection: keep-alive\r\n" ++
    "Cookie: wp_ozh_wsa_visits=2; wp_ozh_wsa_visit_lasttime=xxxxxxxxxx; " ++
    "__utma=xxxxxxxxx.xxxxxxxxxx.xxxxxxxxxx.xxxxxxxxxx.xxxxxxxxxx.x; " ++
    "__utmz=xxxxxxxxx.xxxxxxxxxx.x.x.utmccn=(referral)|utmcsr=reader.livedoor.com|utmcct=/reader/|utmcmd=referral\r\n" ++
    "\r\n";

pub fn main() !void {
    var headers: [32]picozig.Header = undefined;

    const httpParams = picozig.HttpParams{
        .method = "",
        .path = "",
        .minor_version = 0,
        .num_headers = 0,
        .bytes_read = 0,
    };

    var httpRequest = picozig.HttpRequest{
        .params = httpParams,
        .headers = &headers,
        .body = "",
    };

    var ret: i32 = 0;

    const startTime = std.time.milliTimestamp();

    const count = 10000000;
    for (0..count) |_| {
        httpRequest.params.num_headers = headers.len;
        ret = picozig.parseRequest(REQ, &httpRequest);

        std.mem.doNotOptimizeAway(ret);
        std.debug.assert(ret == REQ.len);
    }

    const endTime = std.time.milliTimestamp();
    const elapsed = endTime - startTime;
    const rps = @divTrunc(count, elapsed) * 1000;
    std.debug.print("Reps per second: {d}\n", .{rps});

    return;
}
