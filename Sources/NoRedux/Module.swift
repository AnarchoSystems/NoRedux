//
//  Module.swift
//  
//
//  Created by Markus Kasperczyk on 24.05.22.
//

import Combine

public class Module<_Store : StoreProtocol, Part> : Store<Part, _Store.Command> {
    
    public typealias Command = _Store.Command
    public typealias Whole = _Store.State
    
    @usableFromInline
    let store : _Store
    @usableFromInline
    let lens : WritableKeyPath<Whole, Part>
    
    @inlinable
    @MainActor
    public override var state : Part {
        store.state[keyPath: lens]
    }
    
    init(_ store: _Store, lens: WritableKeyPath<Whole, Part>) {
        self.store = store
        self.lens = lens
    }
    
    public var objectWillChange : some Publisher {
        store.objectWillChange
    }
    
    @MainActor
    public override func send(_ change: @escaping (inout Part) -> Command?) {
        store.send{
            change(&$0[keyPath: self.lens])
        }
    }
    
}

public extension StoreProtocol {
    
    func map<Part>(_ lens: WritableKeyPath<State, Part>) -> Module<Self, Part> {
        Module(self, lens: lens)
    }
    
}

public extension Module {
    
    func map<Next>(_ keyPath: WritableKeyPath<Part, Next>) -> Module<_Store, Next> {
        .init(store, lens: lens.appending(path: keyPath))
    }
    
}
