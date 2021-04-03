extension Application.Responder {
    private struct CachedRouteResponder: RouteResponder {
        let route: Route
        let responder: Responder
        
        func respond(to request: Request) -> EventLoopFuture<Response> {
            return responder.respond(to: request)
        }
    }
    
    public var trieRouter: Vapor.Responder {
        let routes = application.routes
        let middleware = application.middleware.resolve()
        
        let options = routes.caseInsensitive ?
            Set(arrayLiteral: TrieRouter<CachedRouteResponder>.ConfigurationOption.caseInsensitive) : []
        let router = TrieRouter(CachedRouteResponder.self, options: options)
        
        return routed(by: router) { route -> CachedRouteResponder in
            CachedRouteResponder(
                route: route,
                responder: middleware.makeResponder(chainingTo: route.responder)
            )
        }
    }
}

extension Application.Responder.Provider {
    public static var trieRouter: Self {
        .init {
            $0.responder.use { $0.responder.trieRouter }
        }
    }
}
