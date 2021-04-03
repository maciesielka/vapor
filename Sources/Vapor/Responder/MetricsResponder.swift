import Metrics

/// Decorator used to record request metrics for an underlying responder
private struct MetricsResponder: Responder {
    private let responder: Responder
    
    init(downstream: Responder) {
        self.responder = downstream
    }
    
    func respond(to request: Request) -> EventLoopFuture<Response> {
        let startTime = DispatchTime.now().uptimeNanoseconds
        return responder.respond(to: request)
            .always { result in
                let status: HTTPStatus
                switch result {
                case .success(let response):
                    status = response.status
                case .failure:
                    status = .internalServerError
                }
                self.updateMetrics(
                    for: request,
                    startTime: startTime,
                    statusCode: status.code
                )
            }
    }
    
    /// Records the requests metrics.
    func updateMetrics(
        for request: Request,
        startTime: UInt64,
        statusCode: UInt
    ) {
        let pathForMetrics: String
        let methodForMetrics: String
        if let route = request.route {
            // We don't use route.description here to avoid duplicating the method in the path
            pathForMetrics = "/\(route.path.map { "\($0)" }.joined(separator: "/"))"
            methodForMetrics = request.method.string
        } else {
            // If the route is undefined (i.e. a 404 and not something like /users/:userID
            // We rewrite the path and the method to undefined to avoid DOSing the
            // application and any downstream metrics systems. Otherwise an attacker
            // could spam the service with unlimited requests and exhaust the system
            // with unlimited timers/counters
            pathForMetrics = "vapor_route_undefined"
            methodForMetrics = "undefined"
        }
        let dimensions = [
            ("method", methodForMetrics),
            ("path", pathForMetrics),
            ("status", statusCode.description),
        ]
        Counter(label: "http_requests_total", dimensions: dimensions).increment()
        if statusCode >= 500 {
            Counter(label: "http_request_errors_total", dimensions: dimensions).increment()
        }
        Timer(
            label: "http_request_duration_seconds",
            dimensions: dimensions,
            preferredDisplayUnit: .seconds
        ).recordNanoseconds(DispatchTime.now().uptimeNanoseconds - startTime)
    }
}

extension Responder {
    /// Decorator used to record request metrics for an underlying responder
    func addingMetrics() -> Responder {
        return MetricsResponder(downstream: self)
    }
}
