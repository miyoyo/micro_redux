library micro_redux;

import 'dart:async';

/// This is a [Reducer], this function is intended to be
/// the only one that transforms and return the state.
/// 
/// It gets called at the end of the Middleware chain.
/// 
/// Compared to the original Redux Reducer, this Reducer
/// is asynchroneous, simply because I don't believe in
/// abusing middleware for most async actions, especially
/// when async dispatch is used for everything else.
///
/// This is not optimal when used in synchroneous code, but
/// why would you use Redux in that case?
/// No, really, I'm not sure, open up an issue if you know.
typedef Reducer<State extends StoreState> = Future<State> Function(
    State currentState, Action action);

/// This is [Middleware], a function that is called everytime
/// you dispatch something, and must call the `next` function to
/// continue the shell.
///
/// By doing this, you can
/// - Edit the Action
/// - Dispatch other actions
/// - Not continue the chain
/// 
/// This is usually done for things like request modification,
/// action save and replay, permission-based restrictions...
typedef Middleware<State extends StoreState> = Future<void> Function(
    Store<State> currentState, Action action, NextDispatcher next);

/// The [NextDispatcher] is a function you recieve as a Middleware,
/// which you call to continue the chain.
typedef NextDispatcher = Future<void> Function(Action action);

/// Generic type to let you mark objects as Actions.
///
/// If you don't want to be able to dispatch anything,
/// edit the source to replace any references of
/// "Action" (case sensitive) to "Object"
///
/// To figure out the exact action you have, use
///
/// ```dart
/// if(action is CustomAction) {
///   ...
/// }
/// ```
///
/// Dart will automatically cast the value to the checked type.
abstract class Action {}

abstract class StoreState {
  /// Clone the [StoreState]
  ///
  /// If you extend this, use named **optional** arguments to
  /// be able to give your own arguments.
  ///
  /// This function MUST always return something when given no arguments.
  /// This function MUST return the type of the implementing class.
  StoreState copyWith();
}

/// This is the [Store], *the* spline reticulator.
///
/// Your [State] can be anything, but remember that
/// you're only supposed to have a single Store.
/// Preferrably, one god object with all your state.
class Store<State extends StoreState> {
  Store(Reducer<State> reducer,
      {required State initialState,
      List<Middleware<State>> middleware = const [],
      bool syncStream = false,
      bool distinct = false})
      : _state = initialState,
        _controller = StreamController<State>.broadcast(sync: syncStream) {
    _chain = [
      for (var i = 0; i < middleware.length; i++)
        (Action action) => middleware[i](this, action, _chain[i + 1]),
      (Action action) async {
        final newState = await reducer(_state, action);
        if (!distinct || newState != _state) {
          _state = newState;
          _controller.add(state);
        }
      }
    ];
  }

  State _state;
  /// Get a copy of the state
  State get state => _state.copyWith() as State;

  late List<NextDispatcher> _chain;

  StreamController<State> _controller;
  /// Stream emitting [state] changes
  Stream<State> get onChange => _controller.stream;

  /// Send an action to be processed through the store
  void dispatch(Action action) => _chain.first(action);

  /// Close the store, you usually shouldn't need to call this.
  Future<void> dispose() => _controller.close();
}
