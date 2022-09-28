//
//  Service.swift
//  
//
//  Created by Markus Kasperczyk on 24.05.22.
//


public protocol _ServiceProtocol : AnyObject {
    
    @MainActor
    func appWillInit()
    @MainActor
    func appWillShutdown()
    @MainActor
    func appWillRunAction()
    @MainActor
    func run(_ command: Any)
    
}

public protocol ServiceProtocol : _ServiceProtocol {
    
    associatedtype Command
    
    @MainActor
    func run(_ command: Command)
    
}

public extension ServiceProtocol {
    
    @MainActor
    func run(_ command: Any) {
        if let command = command as? Command {
            run(command)
        }
    }
    
}

open class _Service<_State, _Command> {
    
    public typealias State = _State
    public typealias Command = _Command
    
    internal(set) public final weak var store : Store<State, _Command>!
    
    public init() {}
    
}

public typealias Service<State, Command> = _Service<State,Command> & _ServiceProtocol


open class _LifeCycleService<_State, _Command> : _Service<_State, _Command> {
    
    public final func appWillDispatch() {}
    
    public final func appWillRunAction() {}
    
    public final func run(_ command: Command) {}
    
    public final func appDidDispatch() {}
    
    public override init() {
        super.init()
    }
    
}

public typealias LifeCycleService<State, Command> = _LifeCycleService<State, Command> & ServiceProtocol
public typealias BasicLifeCycleService<State> = LifeCycleService<State, Void>


public protocol DetailServiceProtocol : ServiceProtocol {
    
    associatedtype State
    associatedtype Property : Equatable
    
    func propertyDidChange()
    
    func readDetail() -> Property
    
    var oldValueExists : Bool {get}
    
    var oldValue : Property {get set}
    
    var newValue : Property {get set}
    
}

extension DetailServiceProtocol {
    
    public func appWillRunAction() {
        if !oldValueExists {
            oldValue = readDetail()
        }
    }
    
    public func run(_ command: Command) {
        newValue = readDetail()
        if newValue != oldValue {
            propertyDidChange()
        }
        oldValue = newValue
    }
    
}

open class _DetailService<_State, _Property : Equatable, _Command> : _Service<_State, _Command> {
    
    public typealias Property = _Property
    
    public final var oldValue : Property {
        get {_oldValue}
        set(nw) {_oldValue =  nw}
    }
    
    private final var _oldValue : Property!
    
    public var oldValueExists : Bool {
        _oldValue != nil
    }
    
    public final var newValue : Property {
        get {_newValue}
        set(nw) {_newValue = nw}
    }
    
    private final var _newValue : Property!
    
    public final func appWillInit() {}
    
    public final func appWillShutdown() {}
    
    public override init() {
        super.init()
    }
    
}

public typealias DetailService<State, Property : Equatable, Command> = _DetailService<State, Property, Command> & DetailServiceProtocol
public typealias BasicDetailService<State, Property : Equatable> = DetailService<State, Property, Void>


open class _CommandService<_State, _Command> : _Service<_State, _Command> {
    
    public final func appWillInit() {}
    
    public final func appWillShutdown() {}
    
    public override init() {
        super.init()
    }
    
    public final func appWillRunAction() {}
    
}

public typealias CommandService<State, Command> = _CommandService<State, Command> & ServiceProtocol


class AcceptingService<State, SmallCommand, BigCommand> : Service<State, BigCommand>, ServiceProtocol {
    
    let wrapped : Service<State, SmallCommand>
    let transform : (BigCommand) -> SmallCommand?
    
    init(wrapped: Service<State, SmallCommand>, transform: @escaping (BigCommand) -> SmallCommand?) {
        self.wrapped = wrapped
        self.transform = transform
    }
    
    func appWillInit() {
        wrapped.appWillInit()
    }
    
    func appWillRunAction() {
        wrapped.appWillRunAction()
    }
    
    func run(_ command: BigCommand) {
        if let command = transform(command) {
            wrapped.run(command)
        }
    }
    
    func appWillShutdown() {
        wrapped.appWillShutdown()
    }
    
}

public extension _Service {
    
    func handling<BigCommand>(_ type: BigCommand.Type = BigCommand.self, _ transform: @escaping (BigCommand) -> Command?) -> Service<State, BigCommand> {
        guard let self = self as? Service<State, Command> else {
            fatalError("Please inherit from ServiceProtocol.")
        }
        return AcceptingService(wrapped: self, transform: transform)
    }
    
}
