//
//  Promise+Extras.swift
//  Promise
//
//  Created by Soroush Khanlou on 8/3/16.
//
//

import Foundation

extension Promise {

    /// Wait for all the promises you give it to fulfill, and once they have, fulfill itself
    /// with the array of all fulfilled values.
    public static func all<T>(promises: [Promise<T>]) -> Promise<[T]> {
        return Promise<[T]>(work: { fulfill, reject in
            guard !promises.isEmpty else { fulfill([]); return }
            for promise in promises {
                promise.then({ value in
                    if !promises.contains({ $0.isRejected || $0.isPending }) {
                        fulfill(promises.flatMap({ $0.value }))
                    }
                }).onFailure({ error in
                    reject(error)
                })
            }
        })
    }

    /// Resolves itself after some delay.
    public static func delay(delay: NSTimeInterval) -> Promise<()> {
        return Promise<()>(work: { fulfill, reject in
            let nanoseconds = Int64(delay*Double(NSEC_PER_SEC))
            let time = dispatch_time(DISPATCH_TIME_NOW, nanoseconds)
            dispatch_after(time, dispatch_get_main_queue(), {
                fulfill(())
            })
        })
    }

    /// This promise will be rejected after a delay.
    public static func timeout<T>(timeout: NSTimeInterval) -> Promise<T> {
        return Promise<T>(work: { fulfill, reject in
            delay(timeout).then({ _ in
                reject(NSError(domain: "com.khanlou.Promise", code: -1111, userInfo: [ NSLocalizedDescriptionKey: "Timed out" ]))
            })
        })
    }

    /// Fulfills or rejects with the first promise that completes
    /// (as opposed to waiting for all of them, like `.all()` does).
    public static func race<T>(promises: [Promise<T>]) -> Promise<T> {
        return Promise<T>(work: { fulfill, reject in
            guard !promises.isEmpty else { fatalError() }
            for promise in promises {
                promise.then(fulfill, reject)
            }
        })
    }

    public func addTimeout(timeout: NSTimeInterval) -> Promise<Value> {
        return Promise.race(Array([self, Promise<Value>.timeout(timeout)]))
    }

    public func always(on queue: dispatch_queue_t, _ onComplete: Void -> Void) -> Promise<Value> {
        return then(on: queue, { _ in
            onComplete()
            }, { _ in
                onComplete()
        })
    }

    public func always(onComplete: Void -> Void) -> Promise<Value> {
        return always(on: dispatch_get_main_queue(), onComplete)
    }


    public func recover(recovery: (ErrorType) -> Promise<Value>) -> Promise<Value> {
        return Promise(work: { fulfill, reject in
            self.then(fulfill).onFailure({ error in
                recovery(error).then(fulfill, reject)
            })
        })
    }

    public static func retry<T>(count count: Int, delay: NSTimeInterval, generate: () -> Promise<T>) -> Promise<T> {
        if count <= 0 {
            return generate()
        }
        return Promise<T>(work: { fulfill, reject in
            generate().recover({ error in
                return self.delay(delay).then({
                    return retry(count: count-1, delay: delay, generate: generate)
                })
            }).then(fulfill).onFailure(reject)
        })
    }


    public static func zip<T, U>(first: Promise<T>, second: Promise<U>) -> Promise<(T, U)> {
        return Promise<(T, U)>(work: { fulfill, reject in
            let resolver: (Any) -> () = { _ in
                if let firstValue = first.value, secondValue = second.value {
                    fulfill((firstValue, secondValue))
                }
            }
            first.then(resolver, reject)
            second.then(resolver, reject)
        })
    }
}
