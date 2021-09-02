import 'dart:async';

typedef Reducer<State> = Future<State> Function(
    State currentState, Action action);

typedef Middleware<State> = Future<void> Function(
    Store<State> currentState, Action action, NextDispatcher next);

typedef NextDispatcher = Future<void> Function(Action action);

abstract class Action {}

class Store<State> {
  Store(Reducer<State> reducer,
      {required State initialState,
      List<Middleware<State>> middleware = const [],
      bool syncStream = false,
      bool distinct = false})
      : _state = initialState,
        _controller = StreamController<State>.broadcast(sync: syncStream),
        _actionStream = StreamController<Action>() {
    _chain = [
      for (var i = 0; i < middleware.length; i++)
        (Action action) => middleware[i](this, action, _chain[i + 1]),
      (Action action) async {
        final newState = await reducer(_state, action);
        if (!distinct || newState != _state) _controller.add(_state = newState);
      }
    ];
    _actionStream.stream.listen(_chain.first);
  }

  State _state;
  State get state => _state;

  late List<NextDispatcher> _chain;

  StreamController<State> _controller;
  Stream<State> get onChange => _controller.stream;

  StreamController<Action> _actionStream;
  Sink<Action> get dispatchStream => _actionStream.sink;

  void dispatch(Action action) => dispatchStream.add(action);

  Future<void> dispose() async {
    _actionStream.close();
    _controller.close();
  }
}
