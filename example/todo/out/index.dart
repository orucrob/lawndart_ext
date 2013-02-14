// Auto-generated from index.html.
// DO NOT EDIT.

library index;

import 'dart:html' as autogenerated;
import 'dart:svg' as autogenerated_svg;
import 'package:web_ui/web_ui.dart' as autogenerated;

import '../app.dart' as app;

import 'todo_input_component.dart';
import 'todo_component.dart';


// Original code
main() {
   app.init();
}


// Additional generated code
void init_autogenerated() {
  var _root = autogenerated.document.body;
  var __e3, __e4;

  var __t = new autogenerated.Template(_root);
  __e3 = _root.query('#__e-3');
  __t.conditional(__e3, () => (app.initialized), (__t) {
    var __e0, __todos;
    __e0 = new autogenerated.Element.tag('x-todo-input');
    new TodoInput.forElement(__e0);
    __t.component(__e0);
    __todos = new autogenerated.Element.html('<ul id="todos"></ul>');
    __t.loop(__todos, () => (app.todoItems), (todo, __t) {
      var __e1, __e2;
      __e2 = new autogenerated.Element.html('<li>\n          <x-todo-item id="__e-1"></x-todo-item>\n        </li>');
      __e1 = __e2.query('#__e-1');
      __t.oneWayBind(() => (todo), (e) { __e1.xtag.todo = e; }, false);
      __t.oneWayBind(() => __e1.xtag.todo, (__e) { todo = __e; });
      new TodoItemComponent.forElement(__e1);
      __t.component(__e1);
      __t.addAll([
        new autogenerated.Text('\n        '),
        __e2,
        new autogenerated.Text('\n      ')
      ]);
    }, isTemplateElement: false);
    __t.addAll([
      new autogenerated.Text('\n    \n      '),
      __e0,
      new autogenerated.Text('\n      \n      '),
      __todos,
      new autogenerated.Text('\n    \n    ')
    ]);
  });
  
  __e4 = _root.query('#__e-4');
  __t.conditional(__e4, () => (!app.initialized), (__t) {
    
    __t.addAll([
      new autogenerated.Text('\n      '),
      new autogenerated.Element.html('<div>Loading...</div>'),
      new autogenerated.Text('\n    ')
    ]);
  });
  

  __t.create();
  __t.insert();
}