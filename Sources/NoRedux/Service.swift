//
//  Service.swift
//  
//
//  Created by Markus Kasperczyk on 24.05.22.
//


public protocol ServiceProtocol {
    
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
