//Copyright 2012 Seth Ladd
//
//Licensed under the Apache License, Version 2.0 (the "License");
//you may not use this file except in compliance with the License.
//You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//Unless required by applicable law or agreed to in writing, software
//distributed under the License is distributed on an "AS IS" BASIS,
//WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//See the License for the specific language governing permissions and
//limitations under the License.

part of lawndart_ext;

/**
 * Wraps the IndexedDB API and exposes it as a [Store].
 * IndexedDB is generally the preferred API if it is available.
 */
class IndexedDbStore<V> extends Store<V> {

  static Map<String, idb.Database> _databases = new Map<String, idb.Database>();

  final String dbName;
  final String storeName;
  final List<IndexDesc> indexes;

  IndexedDbStore(this.dbName, this.storeName,{this.indexes}) : super._();

  /// Returns true if IndexedDB is supported on this platform.
  static bool get supported => idb.IdbFactory.supported;

  Future open({force: false}) {
    if (!supported) {
      return new Future.error(
        new UnsupportedError('IndexedDB is not supported on this platform'));
    }

    if (_db != null && force) {
      _db.close();
      _databases[dbName]=null;

    }
    if(_db !=null){
      return _initIdb(_db)
        .then((db){
          _databases[dbName] = db;
          _isOpen = true;
          return true;
        });
    }else{
      return window.indexedDB.open(dbName).then((db){
        return db;
      }).then(_initIdb)
        .then((db){
          _databases[dbName] = db;
          _isOpen = true;
          return true;
        });
    }
  }
  bool _checkIndexes(idb.Database db){
    if(indexes==null || indexes.isEmpty){
      return true;
    }
    var trans = db.transaction(storeName, 'readonly');
      var store = trans.objectStore(storeName);
      for(var idx in indexes){
        if(!store.indexNames.contains(idx.name)){
          return false;
        }
      }
      return true;
  }
  Future _initIdb(idb.Database db){
    if (!db.objectStoreNames.contains(storeName) || !_checkIndexes(db)) {
      db.close();
      //print('Attempting upgrading $storeName from ${db.version}');
      return window.indexedDB.open(dbName, version: db.version + 1,
          onUpgradeNeeded: (e) {
            //print('Upgrading db $dbName to ${db.version + 1}');
            idb.Database db = e.target.result;
            idb.ObjectStore os;
            if(db.objectStoreNames.contains(storeName)){
              db.deleteObjectStore(storeName);
            }else{
//              var trans = db.transaction(storeName, 'readwrite');
//              os = trans.objectStore(storeName);
            }
            os = db.createObjectStore(storeName);
            //correct indexes
            if(indexes!=null){
              for(var index in indexes){
                if(!os.indexNames.contains(index.name)){
                  os.createIndex(index.name, index.keyPath, unique: index.unique, multiEntry: index.multi);
                }
              }
            }
          }
      );
    } else {

     // print('The store $storeName exists in $dbName');
      return new Future.value(db);
    }
  }

  idb.Database get _db => _databases[dbName];

  @override
  Future _removeByKey(String  key) {
    return _doCommand((idb.ObjectStore store) => store.delete(key));
  }

  @override
  Future _save(V obj, String key) {
    return _doCommand((idb.ObjectStore store) {
      return store.put(obj, key);
    });
  }

  @override
  Future<V> _getByKey(String key) {
    return _doCommand((idb.ObjectStore store) => store.getObject(key),
        'readonly');
  }

  @override
  Future _nuke() {
    return _doCommand((idb.ObjectStore store) => store.clear());
  }

  @override
  Future _drop() {
    _db.deleteObjectStore(storeName);
    return new Future.value();
  }

  Future _doCommand(Future requestCommand(idb.ObjectStore store),
             [String txnMode = 'readwrite']) {
    var completer = new Completer();
    var trans = _db.transaction(storeName, txnMode);
    var store = trans.objectStore(storeName);
    var future = requestCommand(store);
    return trans.completed.then((_) => future);
  }

  Stream _doGetAll(dynamic onCursor(idb.CursorWithValue cursor)) {
    var controller = new StreamController<V>();
    var trans = _db.transaction(storeName, 'readonly');
    var store = trans.objectStore(storeName);
    // Get everything in the store.
    store.openCursor(autoAdvance: true).listen(
        (cursor) => controller.add(onCursor(cursor)),
        onDone: () => controller.close(),
        onError: (e) => controller.addError(e));
    return controller.stream;
  }

  Stream _doGetByIndex(String idxName, idb.KeyRange range, dynamic onCursor(idb.CursorWithValue cursor),{String direction}) {
    var controller = new StreamController<V>();
    var trans = _db.transaction(storeName, 'readonly');
    var store = trans.objectStore(storeName);
    var index = store.index(idxName);
    // Get everything in the store.
    index.openCursor(range: range, autoAdvance: true, direction: direction).listen(
        (cursor) => controller.add(onCursor(cursor)),
        onDone: () => controller.close(),
        onError: (e) => controller.addError(e));
    return controller.stream;
  }

  @override
  Stream<V> _all() {
    return _doGetAll((idb.CursorWithValue cursor) => cursor.value);
  }

  @override
  Stream<V> _allByIndex(String idxName,{Object only, Object lower, Object upper, bool lowerOpen:false, bool upperOpen:false, String direction} ) {
    idb.KeyRange range = null;
    if(only!=null){
     range = new idb.KeyRange.only(only);
    }else if(lower!=null && upper!=null){
      range = new idb.KeyRange.bound(lower, upper, lowerOpen, upperOpen );
    }else if(lower!=null ){
      range = new idb.KeyRange.lowerBound(lower, lowerOpen);
    }else if(upper!=null){
      range = new idb.KeyRange.upperBound(upper, upperOpen );
    }
    return _doGetByIndex(idxName, range, (idb.CursorWithValue cursor) => cursor.value, direction: direction);
  }

  @override
  Future _batch(Map<String, V> objs) {
    var futures = <Future>[];

    for (var key in objs.keys) {
      var obj = objs[key];
      futures.add(save(obj, key));
    }

    return Future.wait(futures);
  }

  @override
  Stream<V> _getByKeys(Iterable<String> keys) {
    var controller = new StreamController<V>();
    Future.forEach(keys, (key) {
      return getByKey(key).then((value) {
        if (value != null) {
          controller.add(value);
        }
      });
    })
    .then((_) => controller.close())
    .catchError((e) => controller.addError(e));
    return controller.stream;
  }

  @override
  Future<bool> _removeByKeys(Iterable<String> keys) {
    var completer = new Completer();
    Future.wait(keys.map((key) => removeByKey(key))).then((_) {
      completer.complete(true);
    });
    return completer.future;
  }

  @override
  Future<bool> _exists(String key) {
    return getByKey(key).then((value) => value != null);
  }

  @override
  Stream<String> _keys() {
    return _doGetAll((idb.CursorWithValue cursor) => cursor.key);
  }
}