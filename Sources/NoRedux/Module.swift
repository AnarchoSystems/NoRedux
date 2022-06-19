//
//  Module.swift
//  
//
//  Created by Markus Kasperczyk on 24.05.22.
//

import Foundation

public class Module<Whole, Part> : Store<Part> {
    
    @usableFromInline
    let store : Store<Whole>
    @usableFromInline
    let lens : WritableKeyPath<Whole, Part>
    
    @inlinable
    @MainActor
    public override var state : Part {
        store.state[keyPath: lens]
    }
    
    init(_ store: Store<Whole>, lens: WritableKeyPath<Whole, Part>) {
        self.store = store
        self.lens = lens
    }
    
    public var objectWillChange: Store<Whole>.ObjectWillChangePublisher {
        store.objectWillChange
    }
    
    @MainActor
    public override func send(_ change: @escaping (inout Part) -> Void) {
        store.send{
            change(&$0[keyPath: self.lens])
        }
    }
    
}

public extension Store {
    
    func map<Part>(_ lens: WritableKeyPath<State, Part>) -> Module<State, Part> {
        Module(self, lens: lens)
    }
    
}

public extension Module {
    
    func map<Next>(_ keyPath: WritableKeyPath<Part, Next>) -> Module<Whole, Next> {
        .init(store, lens: lens.appending(path: keyPath))
    }
    
}
