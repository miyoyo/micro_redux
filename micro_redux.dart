import 'dart:async';

typedef Reducer<State> = Future<State> Function(
    State currentState, dynamic action);

typedef Middleware<State> = Future<void> Function(
    Store<State> currentState, dynamic action, NextDispatcher next);

typedef NextDispatcher = Future<void> Function(dynamic action);

class Store<State> {
  Store(this.reducer,
      {State initialState,
      List<Middleware<State>> middleware = const [],
      bool syncStream = false,
      bool distinct = false})
      : _state = initialState,
        _controller = StreamController<State>.broadcast(sync: syncStream) {
    _chain = [
      for (var i = 0; i < middleware.length; i++)
        (dynamic action) => middleware[i](this, action, _chain[i + 1]),
      (dynamic action) {
        final newState = reducer(_state, action);
        if (!distinct || newState != _state) _controller.add(_state = newState);
      }
    ];
    _actionStream.listen(_chain.first);
  }

  Reducer<State> reducer;
  State _state;
  State get state => _state;
  List<NextDispatcher> _chain;
  StreamController<State> _controller;
  Stream<State> get onChange => _controller.stream;

  StreamController<dynamic> _actionStream = StreamController<dynamic>();
  Sink<dynamic> get dispatchStream => _actionStream.sink; 

  void dispatch(dynamic action) => dispatchStream.add(action);

  Future<void> dispose() => _controller.close();
}
