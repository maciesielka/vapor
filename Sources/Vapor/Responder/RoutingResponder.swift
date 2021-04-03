/// A `Responder` associated with a particular `Route`
public protocol RouteResponder: Responder {
    var route: Route { get }
}

/// Configurable top-level `Responder` type. Combines configured middleware + customizable router to create a responder.
struct RoutingResponder<Router>: Responder
    where Router: RoutingKit.Router, Router.Output: RouteResponder {
    
    private var router: Router
    private let notFoundResponder: Responder
    
    init(router: Router, middleware: [Middleware] = []) {
        self.router = router
        self.notFoundResponder = middleware.makeResponder(chainingTo: NotFoundResponder())
    }
    
    /// See `Responder`
    func respond(to request: Request) -> EventLoopFuture<Response> {
        let response: EventLoopFuture<Response>
        if let existing = getRoute(for: request) {
            request.route = existing.route
            response = existing.respond(to: request)
        } else {
            response = notFoundResponder.respond(to: request)
        }
        return response
    }
    
    /// Register all `application.routes`, using the provided block to create output for each Route.
    mutating func bootstrap(with application: Application, createOutput: (Route) -> Router.Output) {
        for route in application.routes.all {
            // create the output to register
            let output = createOutput(route)
            
            // remove any empty path components
            let path = route.path.filter { component in
                switch component {
                case .constant(let string):
                    return string != ""
                default:
                    return true
                }
            }
            
            router.register(output, at: [.constant(route.method.string)] + path)
        }
    }
    
    /// Gets a `Route` from the underlying `Router`.
    private func getRoute(for request: Request) -> Router.Output? {
        let pathComponents = request.url.path
            .split(separator: "/")
            .map(String.init)
        
        let method = (request.method == .HEAD) ? .GET : request.method
        return self.router.route(
            path: [method.string] + pathComponents,
            parameters: &request.parameters
        )
    }
}

private struct NotFoundResponder: Responder {
    func respond(to request: Request) -> EventLoopFuture<Response> {
        request.eventLoop.makeFailedFuture(RouteNotFound())
    }
}

struct RouteNotFound: Error { }

extension RouteNotFound: AbortError {
    static var typeIdentifier: String {
        "Abort"
    }
    
    var status: HTTPResponseStatus {
        .notFound
    }
}

extension RouteNotFound: DebuggableError {
    var logLevel: Logger.Level {
        .debug
    }
}
