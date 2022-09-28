//
//  Store.swift
//  
//
//  Created by Markus Kasperczyk on 24.05.22.
//

import Foundation

public protocol StoreProtocol<State, Command> : ObservableObject {
    associatedtype State
    associatedtype Command
    @MainActor
    var state : State {get}
    @MainActor
    func send(_ action: @escaping (inout State) -> Command?)
}

public extension StoreProtocol {
    
    @inlinable
    @MainActor
    func send(_ action: @escaping (inout State) -> Void) {
        send {action(&$0); return nil}
    }
    
}

public typealias BasicStore<State> = Store<State, Void>

public final class Store<State, Command> : StoreProtocol {
    
    private var _state : State
    @MainActor
    public var state : State {_state}
    private let services : [any Service<State, Command>]
    
    
    private var warnActionsAfterShutdown : Bool
    @usableFromInline
    internal var hasInitialized = false
    @usableFromInline
    internal var hasShutdown = false
    
    @usableFromInline
    internal var actionQueue : [(inout State) -> Command?] = []
    
    @MainActor
    public init(environment: Dependencies = [],
                services: [any Service<State, Command>] = [],
                initialize: (Dependencies) -> State)
    {
        self.services = services
        self._state = initialize(environment)
        self.warnActionsAfterShutdown = environment.internalFlags.warnActionsAfterShutdown
        for service in services {
            service.store = self
            inject(environment: environment, to: service)
        }
        for service in services {
            service.appWillInit()
        }
        hasInitialized = true
        if !actionQueue.isEmpty {
            dispatchActions(expectedActions: actionQueue.count)
        }
    }
    
    @inlinable
    @MainActor
    public convenience init(environment: Dependencies = [],
                            services: [any Service<State, Command>] = [],
                            state: State) {
        self.init(environment: environment,
                  services: services,
                  initialize: {_ in state})
    }
    
    @inlinable
    @MainActor
    public func send(_ action: @escaping (inout State) -> Command?) {
        actionQueue.append(action)
        dispatchActions(expectedActions: 1)
        
    }
    
    @usableFromInline
    @MainActor
    internal func dispatchActions(expectedActions: Int) {
        
        guard hasInitialized else {
            return
        }
        
        guard actionQueue.count == expectedActions else {
            // All calls to this method are assumed to happen on
            // main dispatch queue - a serial queue.
            // Therefore, if more than one action is in the queue,
            // the action must have been enqueued by the below while loop
            return
        }
        
        guard !hasShutdown else {
            return maybeWarnShutdown()
        }
        
        objectWillChange.send()
        
        var idx = 0
        
        while idx < actionQueue.count {
            
            let action = actionQueue[idx]
            
            for service in services {
                service.appWillRunAction()
            }
            
            let command = action(&_state)
            
            for service in services {
                service.run(command)
            }
            
            idx += 1
            
        }
        
        actionQueue = []
        
    }
    
    @MainActor
    public final func shutDown() {
        guard !hasShutdown else {
            return maybeWarnShutdown()
        }
        for service in services.reversed() {
            service.appWillShutdown()
        }
        hasShutdown = true
    }
    
    @MainActor
    private func maybeWarnShutdown() {
#if DEBUG
        if warnActionsAfterShutdown {
            print("NoRedux: The store has been invalidated, actions are no longer accepted.\n If sending actions to a dead store is somehow acceptable for your app, you can silence this warning  by setting internalFlags.warnActionsAfterShutdown to false in the environment or by compiling in release mode.")
        }
#endif
    }
    
}

public enum InternalFlags : Dependency {
    public static let defaultValue = ResolvedInternalFlags()
}


public extension Dependencies {
    /// Flags that RedCat uses internally, but can be overridden.
    var internalFlags : ResolvedInternalFlags {
        get {self[InternalFlags.self]}
        set {self[InternalFlags.self] = newValue}
    }
}


public struct ResolvedInternalFlags {
    
    /// If true, the store will print warnings, if it receives any actions after it has been invalidated.
    public var warnActionsAfterShutdown = true
    
}
