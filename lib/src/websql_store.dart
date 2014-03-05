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
 * Wraps the WebSQL API and exposes it as a [Store].
 * WebSQL is a transactional database.
 */
class WebSqlStore<V> extends Store<V> {

  static final String VERSION = "1";
  static const int INITIAL_SIZE = 4 * 1024 * 1024;

  String dbName;
  String storeName;
  int estimatedSize;
  static SqlDatabase _db;
  final List<IndexDesc> indexes;
  final Map<String, IndexDesc> _indexMap= {};
  String _updateCols = "id, value";
  String _updateQ = "?, ?";
  List<String> _idxPaths = new List();

  WebSqlStore(this.dbName, this.storeName, {this.estimatedSize: INITIAL_SIZE, this.indexes}) : super._();

  /// Returns true if WebSQL is supported on this platform.
  static bool get supported => SqlDatabase.supported;

  @override
  Future<bool> open({force: false}) {
    if (!supported) {
      return new Future.error(
        new UnsupportedError('WebSQL is not supported on this platform'));
    }
    var completer = new Completer();
//    window.alert('initing DB $_db');
    if(_db==null){
      _db = window.openDatabase(dbName, VERSION, dbName, 4*1024);
    }
//    window.alert('DB opened');
    _initDb(completer);
//    window.alert('DB $storeName inited');
    return completer.future;
  }

  void _initDb(Completer completer) {
    var sql = 'CREATE TABLE IF NOT EXISTS $storeName (id NVARCHAR(32) UNIQUE PRIMARY KEY, value TEXT';
    if(indexes!=null && indexes.isNotEmpty){
      indexes.forEach((idx){
        var col = idx.keyPath;
        //TODO repeating columns
        if(col is List){
          col.forEach((colName){
            sql += ", ${colName} ${idx.websqlType}";
            _updateCols += ",${colName}";
            _updateQ += ", ?";
            _idxPaths.add(colName);
          });
        }else if(col is String){
          sql += ", ${col} ${idx.websqlType}";
          _updateCols += ",${col}";
          _updateQ += ", ?";
          _idxPaths.add(col);
        }else{
          print('Not supported INDEX in WEBSQL - $idx');
        }
        _indexMap[idx.name] = idx;
      });
    }
    sql+=')';
   // window.alert('init sql: $sql');
    _db.transaction((txn) {
      txn.executeSql(sql, [], (txn, resultSet) {
        _isOpen = true;
        completer.complete(true);
      });
    }, (error) => completer.completeError(error));
  }

  @override
  Stream<String> _keys() {
    var sql = 'SELECT id FROM $storeName';
    var controller = new StreamController();
    _db.transaction((txn) {
      txn.executeSql(sql, [], (txn, resultSet) {
        for (var i = 0; i < resultSet.rows.length; ++i) {
          var row = resultSet.rows.item(i);
          controller.add(row['id']);
        }
      });
    },
    (error) => controller.addError(error),
    () => controller.close());

    return controller.stream;
  }

  @override
  Future _save(V obj, String key) {
    var completer = new Completer();
    //var upsertSql = 'INSERT OR REPLACE INTO $storeName (id, value) VALUES (?, ?)';

    var val = [key, JSON.encode(obj)].toList();
    if(_idxPaths!=null && _idxPaths.isNotEmpty){
      if(obj is Map){
        var objM = obj;
        _idxPaths.forEach((String col){
          val.add(objM[col]);
        });
      }else{
        print('ERROR: saving strings not supported when indexes defined.');
      }
    }
    var upsertSql = 'INSERT OR REPLACE INTO $storeName ($_updateCols) VALUES ($_updateQ)';


    _db.transaction((txn) {
      txn.executeSql(upsertSql, val/*[key, obj]*/, (txn, resultSet) {
        completer.complete(key);
      });
    }, (error) => completer.completeError(error));

    return completer.future;
  }

  @override
  Future<bool> _exists(String key) {
    return _getByKey(key).then((v) => v != null);
  }

  @override
  Future<V> _getByKey(String key) {
    var completer = new Completer();
    var sql = 'SELECT value FROM $storeName WHERE id = ?';

    _db.readTransaction((txn) {
      txn.executeSql(sql, [key], (txn, resultSet) {
        if (resultSet.rows.isEmpty) {
          completer.complete(null);
        } else {
          var row = resultSet.rows.item(0);
          var val = row['value'];
          if(val!=null){
            val = JSON.decode(val);
          }
//          controller.add(val);
          completer.complete(val);
        }
      });
    }, (error) => completer.completeError(error));

    return completer.future;
  }

  @override
  Future _removeByKey(String key) {
    var completer = new Completer();
    var sql = 'DELETE FROM $storeName WHERE id = ?';

    _db.transaction((txn) {
      txn.executeSql(sql, [key], (txn, resultSet) {
        // maybe later, if (resultSet.rowsAffected < 0)
        completer.complete(true);
      });
    }, (error) => completer.completeError(error));

    return completer.future;
  }

  @override
  Future _nuke() {
    var completer = new Completer();

    var sql = 'DELETE FROM $storeName';
    _db.transaction((txn) {
      txn.executeSql(sql, [], (txn, resultSet) => completer.complete(true));
    }, (error) => completer.completeError(error));
    return completer.future;
  }
  @override
  Future _drop() {
    var completer = new Completer();

    var sql = "DROP TABLE IF EXISTS $storeName";
    _db.transaction((txn) {
      txn.executeSql(sql, [], (txn, resultSet) => completer.complete(true));
    }, (error) => completer.completeError(error));
    return completer.future;
  }

  @override
  Stream<V> _all() {
    var sql = 'SELECT id,value FROM $storeName';
    var controller = new StreamController<V>();
    _db.transaction((txn) {
      txn.executeSql(sql, [], (txn, resultSet) {
        for (var i = 0; i < resultSet.rows.length; ++i) {
          var row = resultSet.rows.item(i);
          var val = row['value'];
          if(val!=null){
            val = JSON.decode(val);
          }
          controller.add(val);
        }
      });
    },
    (error) => controller.addError(error),
    () => controller.close());

    return controller.stream;
  }
  @override
  Stream<V> _allByIndex(String idxName,{Object only, Object lower, Object upper, bool lowerOpen:false, bool upperOpen:false, String direction} ) {
    var sql = 'SELECT id,value FROM $storeName';
    var idx = _indexMap[idxName];
    var order = " ORDER BY ";
    if(direction==null){
      direction = "asc";
    }else{
      direction = direction.toLowerCase().trim();
    }
    if(direction=="prev"){
      direction = "DESC";
    }else if(direction!="asc" && direction!="desc" ){
      print('ERROR: direction "$direction"not supported');
      direction = "ASC";
    }

    if(only!=null){
      //NO order for only
      order = "";

      if(idx.keyPath is List){
        if(only is List){
          var i=0;
          idx.keyPath.forEach((col){
            if(sql.contains("WHERE")){
              sql += " AND";
            }else{
              sql += " WHERE";
            }
            sql += ' $col = "${only[i++]}"'; //sql lite auto conversion to numbers if col is text or number
          });
        }else{
          print('ERROR value for index is not List ($only)');
        }
      }else{
        sql += ' WHERE ${idx.keyPath} = "${only}"'; //sql lite auto conversion to numbers if col is text or number

      }
    }else if(lower!=null && upper!=null){
      var cp1 = lowerOpen?">":">=";
      var cp2 = upperOpen?"<":"<=";
      if(idx.keyPath is List){
        if(lower is List && upper is List){
          var i=0;
          idx.keyPath.forEach((col){
            if(sql.contains("WHERE")){
              sql += " AND";
            }else{
              sql += " WHERE";
            }
            sql += ' $col $cp1 "${lower[i]}" AND $col $cp2 "${upper[i]}"';
            order += " $col $direction,";
            i++;
          });
          order = order.substring(0, order.length-1);
        }else{
          print('ERROR value for index is not List ($upper , $lower)');
        }
      }else{
        sql += ' WHERE ${idx.keyPath} $cp1 "$lower" AND ${idx.keyPath} $cp2 "$upper" ORDER BY ${idx.keyPath} $direction';
      }
    }else if(lower!=null){
      var cp1 = lowerOpen?">":">=";
      if(idx.keyPath is List){
        if(lower is List){
          var i=0;
          idx.keyPath.forEach((col){
            if(sql.contains("WHERE")){
              sql += " AND";
            }else{
              sql += " WHERE";
            }
            sql += ' $col $cp1 "${lower[i]}"';
            order += " $col $direction,";
            i++;
          });
          order = order.substring(0, order.length-1);
        }else{
          print('ERROR value for index is not List ( $lower)');
        }
      }else{
        sql += ' WHERE ${idx.keyPath} $cp1 "$lower" ORDER BY ${idx.keyPath} $direction';
      }
    }else if(upper!=null){
      var cp2 = upperOpen?"<":"<=";
      if(idx.keyPath is List){
        if(upper is List){
          var i=0;
          idx.keyPath.forEach((col){
            if(sql.contains("WHERE")){
              sql += " AND";
            }else{
              sql += " WHERE";
            }
            sql += ' $col $cp2 "${upper[i]}"';
            order += " $col $direction,";
            i++;
          });
          order = order.substring(0, order.length-1);
        }else{
          print('ERROR value for index is not List ($upper )');
        }
      }else{
        sql += ' WHERE ${idx.keyPath} $cp2 "$upper" ORDER BY ${idx.keyPath} $direction';
      }
    }else{
      if(idx.keyPath is List){
        idx.keyPath.forEach((col){
          order += " $col $direction,";
        });
        order = order.substring(0, order.length-1);
      }else{
        order += ' ${idx.keyPath} $direction';
      }
    }
    sql += order;

    var controller = new StreamController<V>();
    _db.transaction((txn) {
      txn.executeSql(sql, [], (txn, resultSet) {
        for (var i = 0; i < resultSet.rows.length; ++i) {
          var row = resultSet.rows.item(i);
          var val = row['value'];
          if(val!=null){
            val = JSON.decode(val);
          }
          controller.add(val);
        }
      });
    },
    (error) => controller.addError(error),
    () => controller.close());

    return controller.stream;
  }

  @override
  Future _batch(Map<String, V> objs) {
    var completer = new Completer();
    //var upsertSql = 'INSERT OR REPLACE INTO $storeName (id, value) VALUES (?, ?)';
    var upsertSql = 'INSERT OR REPLACE INTO $storeName ($_updateCols) VALUES ($_updateQ)';

    _db.transaction((txn) {
      for (var key in objs.keys) {
          V obj = objs[key];
          //prepare value objects
          var val = [key, JSON.encode(obj)].toList();
          if(_idxPaths!=null && _idxPaths.isNotEmpty){
            if(obj is Map){
              var objM = obj;
              _idxPaths.forEach((String col){
                val.add(objM[col]);
              });
            }else{
              print('ERROR: saving strings not supported when indexes defined.');
            }
          }
          txn.executeSql(upsertSql, val/*[key, obj]*/);
        }
      },
      (error) => completer.completeError(error),
      () => completer.complete(true)
    );

    return completer.future;
  }

  @override
  Stream<V> _getByKeys(Iterable<String> _keys) {
    var sql = 'SELECT value FROM $storeName WHERE id = ?';

    var controller = new StreamController<V>();

    _db.transaction((txn) {
      _keys.forEach((key) {
        txn.executeSql(sql, [key], (txn, resultSet) {
          if (!resultSet.rows.isEmpty) {
            var val = resultSet.rows.item(0)['value'];
            if(val!=null){
              val = JSON.decode(val);
            }
            controller.add(val);

            //controller.add(resultSet.rows.item(0)['value']);
          }
        });
      });
    },
    (error) => controller.addError(error),
    () => controller.close());

    return controller.stream;
  }

  @override
  Future _removeByKeys(Iterable<String> _keys) {
    var sql = 'DELETE FROM $storeName WHERE id = ?';
    var completer = new Completer<bool>();

    _db.transaction((txn) {
      _keys.forEach((key) {
        // TODO verify I don't need to do anything in the callback
        txn.executeSql(sql, [key]);
      });
    },
    (error) => completer.completeError(error),
    () => completer.complete(true));

    return completer.future;
  }

}
