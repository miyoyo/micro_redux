import 'dart:async';

typedef Reducer<State extends StoreState> = Future<State> Function(
    State currentState, Action action);

typedef Middleware<State extends StoreState> = Future<void> Function(
    Store<State> currentState, Action action, NextDispatcher next);

typedef NextDispatcher = Future<void> Function(Action action);

abstract class Action {}

abstract class StoreState {
  StoreState copyWith();
}

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
  State get state => _state.copyWith() as State;

  late List<NextDispatcher> _chain;

  StreamController<State> _controller;
  Stream<State> get onChange => _controller.stream;

  void dispatch(Action action) => _chain.first(action);

  Future<void> dispose() => _controller.close();
}
