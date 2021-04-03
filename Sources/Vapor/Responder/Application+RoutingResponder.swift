extension Application.Responder {
    /// Create a new `Responder` using an underlying `Router` type.
    ///
    /// - Note: This method does not register any routes to the Router
    public func routed<Router>(by router: Router) -> Vapor.Responder
        where Router: RoutingKit.Router, Router.Output: RouteResponder {
        RoutingResponder(
            router: router,
            middleware: self.application.middleware.resolve()
        )
    }
    
    /// Create a new `Responder` using an underlying `Router` type, registering all routes
    /// using the provided bootstrapping closure.
    public func routed<Router>(
        by router: Router,
        bootstrapper: (Route) -> Router.Output
    ) -> Vapor.Responder where Router: RoutingKit.Router, Router.Output: RouteResponder {
        var router = RoutingResponder(
            router: router,
            middleware: self.application.middleware.resolve()
        )
        router.bootstrap(with: application, createOutput: bootstrapper)
        return router
    }
}
