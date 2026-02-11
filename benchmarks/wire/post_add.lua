wrk.method = "POST"
wrk.headers["Content-Type"] = "text/plain"
wrk.body = "~add(a: 3, b: 4)\n| sum s |> result { value: s }"
