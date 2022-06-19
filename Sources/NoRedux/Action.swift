//
//  Action.swift
//  
//
//  Created by Markus Kasperczyk on 14.06.22.
//

import Foundation


public protocol Action {
    associatedtype State
    func run(on state: inout State)
}

public protocol Undoable : Action where Inverse.State == State {
    associatedtype Inverse : Action
    func inverse(given state: State) -> Inverse
}

public extension Action {
    
    func callAsFunction(_ state: inout State) {
        run(on: &state)
    }
    
}

public extension StoreProtocol {
    
    @MainActor
    func send<Act : Action>(_ action: Act) where Act.State == State {
        send{action(&$0)}
    }
    
    @MainActor
    func send<Module>(to kp: WritableKeyPath<State, Module>,
                      _ action: @escaping (inout Module) -> Void) {
        send{action(&$0[keyPath: kp])}
    }
    
    @MainActor
    func sendWithUndo<Act : Undoable>(undoManager: UndoManager?,
                                      _ action: Act) where Act.State == State {
        let inverse = action.inverse(given: state)
        send(action)
        undoManager?.registerUndo(withTarget: self) {store in
            store.send(inverse)
        }
    }
    
}

public extension Action {
    
    func then<A : Action>(_ next: A) -> ChainedActions<Self, A> {
        ChainedActions(action1: self, action2: next)
    }
    
    func on<Whole>(_ keyPath: WritableKeyPath<Whole, State>) -> KeyPathBoundAction<Whole, Self> {
        KeyPathBoundAction(keyPath: keyPath, action: self)
    }
    
}

public struct ChainedActions<A1 : Action, A2 : Action> : Action where A1.State == A2.State {
    
    public let action1 : A1
    public let action2 : A2
    
    public func run(on state: inout A1.State) {
        action1.run(on: &state)
        action2.run(on: &state)
    }
    
}

extension ChainedActions : Undoable where A1 : Undoable, A2 : Undoable {
    
    public func inverse(given state: A1.State) -> ChainedActions<A2.Inverse, A1.Inverse> {
        .init(action1: action2.inverse(given: state), action2: action1.inverse(given: state))
    }
    
}

public struct KeyPathBoundAction<State, A : Action> : Action {
    
    public let keyPath : WritableKeyPath<State, A.State>
    public let action : A
    
    public func run(on state: inout State) {
        action(&state[keyPath: keyPath])
    }
    
}

extension KeyPathBoundAction : Undoable where A : Undoable {
    
    public func inverse(given state: State) -> KeyPathBoundAction<State, A.Inverse> {
        .init(keyPath: keyPath, action: action.inverse(given: state[keyPath: keyPath]))
    }
    
}

public protocol Script : Action where Body.State == State {
    
    associatedtype State = Body.State
    associatedtype Body : Action
    var body : Body {get}
    
}

public extension Script {
    
    func run(on state: inout State) {
        body.run(on: &state)
    }
    
    func inverse(given state: State) -> Body.Inverse where Body : Undoable {
        body.inverse(given: state)
    }
    
}

public struct Block<Act : Action> : Script {
    
    public init(@ActionBuilder _ make: () -> Act) {
        self.body = make()
    }
    
    public let body : Act
    
}

extension Block : Undoable where Act : Undoable {}

@resultBuilder
public struct ActionBuilder {
    
    public static func buildBlock<Act : Action>(_ act: Act) -> Act {
        act
    }
    
    public static func buildPartialBlock<A1, A2>(accumulated: A1, next: A2) -> ChainedActions<A1, A2> {
        ChainedActions(action1: accumulated, action2: next)
    }
    
}
