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
    func run(_ command: Any?)
    
}

public protocol ServiceProtocol : _ServiceProtocol {
    
    associatedtype Command
    
    @MainActor
    func run(_ command: Command?)
    
}

public extension ServiceProtocol {
    
    @MainActor
    func run(_ command: Any?) {
        guard let command = command as? Command else {
            return run(nil)
        }
        run(command)
    }
    
}

open class _Service<_State, _Command> {
    
    public typealias State = _State
    public typealias Command = _Command
    
    internal(set) public var store : Store<_State, _Command>!
    
    public init() {}
    
}

public typealias Service<State, Command> = _Service<State,Command> & _ServiceProtocol


open class _LifeCycleService<_State, _Command> : _Service<_State, _Command> {
    
    internal(set) public override var store: Store<_State, _Command>! {
        get {_store}
        set {_store = newValue}
    }
    
    final weak var _store : Store<_State, _Command>!
    
    public final func appWillDispatch() {}
    
    public final func appWillRunAction() {}
    
    public final func run(_ command: Command?) {}
    
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
    
    @MainActor
    func propertyDidChange()
    
    @MainActor
    func readDetail() -> Property
    
    @MainActor
    var oldValueExists : Bool {get}
    
    @MainActor
    var oldValue : Property {get set}
    
    @MainActor
    var newValue : Property {get set}
    
}

extension DetailServiceProtocol {
    
    @MainActor
    public func appWillRunAction() {
        if !oldValueExists {
            oldValue = readDetail()
        }
    }
    
    @MainActor
    public func run(_ command: Command?) {
        newValue = readDetail()
        if newValue != oldValue {
            propertyDidChange()
        }
        oldValue = newValue
    }
    
}

open class _DetailService<_State, _Property : Equatable, _Command> : _Service<_State, _Command> {
    
    internal(set) public override var store: Store<_State, _Command>! {
        get {_store}
        set {_store = newValue}
    }
    
    final weak var _store : Store<_State, _Command>!
    
    public typealias Property = _Property
    
    @MainActor
    public final var oldValue : Property {
        get {_oldValue}
        set(nw) {_oldValue =  nw}
    }
    
    private final var _oldValue : Property!
    
    public var oldValueExists : Bool {
        _oldValue != nil
    }
    
    @MainActor
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

public protocol CommandServiceProtocol : ServiceProtocol {
    
    @MainActor
    func run(_ command: Command)
    
}

public extension CommandServiceProtocol {
    
    @MainActor
    func run(_ command: Command?) {
        guard let command else {
            return
        }
        run(command)
    }
    
}

open class _CommandService<_State, _Command> : _Service<_State, _Command> {
    
    public final func appWillInit() {}
    
    public final func appWillShutdown() {}
    
    public override init() {
        super.init()
    }
    
    public final func appWillRunAction() {}
    
}

public typealias CommandService<State, Command> = _CommandService<State, Command> & CommandServiceProtocol


public struct DownCast<Whole, Part> {
    
    let _extract : (Whole) -> Part?
    let _inject : (Part) -> Whole
    
    public init(extract: @escaping (Whole) -> Part?,
                inject: @escaping (Part) -> Whole) {
        self._extract = extract
        self._inject = inject
    }
    
    public func extract(_ whole: Whole) -> Part? {_extract(whole)}
    public func inject(_ part: Part) -> Whole {_inject(part)}
    
}

final class AcceptingService<State, SmallCommand, BigCommand> : Service<State, BigCommand>, ServiceProtocol, Reader {
    
    final class AcceptingStore : Store<State, SmallCommand> {
        
        weak var store : Store<State, BigCommand>!
        let inject : (SmallCommand) -> BigCommand
        
        init(store: Store<State, BigCommand>, inject: @escaping (SmallCommand) -> BigCommand) {
            self.store = store
            self.inject = inject
        }
        
        override var state : State {store.state}
        
        override func send(_ action: @escaping (inout State) -> SmallCommand?) {
            store.send {state in
                action(&state).map(self.inject)
            }
        }
        
    }
    
    internal(set) public final override var store : Store<State, BigCommand>? {
        get{_store.store}
        set {guard let newValue else {return}; _store = AcceptingStore(store: newValue, inject: transform.inject)}
    }
    
    private var _store : AcceptingStore!
    
    let wrapped : Service<State, SmallCommand>
    let transform : DownCast<BigCommand, SmallCommand>
    
    init(wrapped: Service<State, SmallCommand>, transform: DownCast<BigCommand, SmallCommand>) {
        self.wrapped = wrapped
        self.transform = transform
    }
    
    func appWillInit() {
        wrapped.appWillInit()
    }
    
    func appWillRunAction() {
        wrapped.appWillRunAction()
    }
    
    func run(_ command: BigCommand?) {
        guard let command else {
            return wrapped.run(nil)
        }
        let cmd = transform.extract(command)
        wrapped.run(cmd)
    }
    
    func appWillShutdown() {
        wrapped.appWillShutdown()
    }
    
    func readValue(from environment: Any) {
        let environment = environment as! Dependencies
        inject(environment: environment, to: wrapped)
    }
    
}

public extension _Service {
    
    func handling<BigCommand>(_ type: BigCommand.Type = BigCommand.self, _ transform: DownCast<BigCommand, Command>) -> Service<State, BigCommand> {
        guard let self = self as? Service<State, Command> else {
            fatalError("Please inherit from ServiceProtocol.")
        }
        return AcceptingService(wrapped: self, transform: transform)
    }
    
}
