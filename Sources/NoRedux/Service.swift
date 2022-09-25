//
//  Service.swift
//  
//
//  Created by Markus Kasperczyk on 24.05.22.
//


public protocol ServiceProtocol : AnyObject {
    
    @MainActor
    func appWillInit()
    @MainActor
    func appWillShutdown()
    @MainActor
    func appWillDispatch()
    @MainActor
    func appWillRunAction()
    @MainActor
    func appDidRunAction()
    @MainActor
    func appDidDispatch()
    
}

open class _Service<State> {
    
    internal(set) public final weak var store : Store<State>!
    
}

public typealias Service<State> = _Service<State> & ServiceProtocol


open class _LifeCycleService<State> : _Service<State> {
    
    public final func appWillDispatch() {}
    
    public final func appWillRunAction() {}
    
    public final func appDidRunAction() {}
    
    public final func appDidDispatch() {}
    
}

public typealias LifeCycleService<State> = _LifeCycleService<State> & ServiceProtocol

public struct PropertyEvents : OptionSet {
    
    public let rawValue : UInt8
    
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    
    public static let none : PropertyEvents = []
    
    public static let perAction = PropertyEvents(rawValue: 1)
    
    public static let perDispatch = PropertyEvents(rawValue: 2)
    
    public static let all : PropertyEvents = [.perAction, .perDispatch]
    
}

public protocol DetailServiceProtocol : ServiceProtocol {
    
    associatedtype State
    associatedtype Property : Equatable
    
    func propertyDidChange()
    
    func readDetail() -> Property
    
    var observedEvents : PropertyEvents {get}
    
    var oldValue : Property? {get set}
    
    var newValue : Property {get set}
    
}

extension DetailServiceProtocol {
    
    public func appDidRunAction() {
        guard observedEvents.contains(.perAction) else {return}
        let newVal = readDetail()
        guard newVal != oldValue else {return}
        propertyDidChange()
        oldValue = newVal
    }
    
    public func appDidDispatch() {
        guard observedEvents.contains(.perDispatch) else {return}
        newValue = readDetail()
        guard newValue != oldValue else {return}
        propertyDidChange()
        oldValue = newValue
    }
    
}

open class _DetailService<_State, _Property : Equatable> : _Service<_State> {
    
    public typealias State = _State
    public typealias Property = _Property
    
    public final var oldValue : Property?
    
    public final var newValue : Property {
        get {_newValue!}
        set(nw) {_newValue = nw}
    }
    
    private final var _newValue : Property?
    
    public final func appWillInit() {}
    
    public final func appWillShutdown() {}
    
    public final func appWillDispatch() {}
    
    public final func appWillRunAction() {}
    
    open var observedEvents : PropertyEvents {.perDispatch}

}

public typealias DetailService<State, Property : Equatable> = _DetailService<State, Property> & DetailServiceProtocol
