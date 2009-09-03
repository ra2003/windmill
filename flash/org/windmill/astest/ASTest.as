/*
Copyright 2009, Matthew Eernisse (mde@fleegix.org) and Slide, Inc.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
*/

package org.windmill.astest {
  import org.windmill.WMLogger;
  import flash.utils.*;
  import flash.external.ExternalInterface;

  public class ASTest {
    // How long to wait between each test action
    private static const TEST_INTERVAL:int = 10;
    // List of all the test classes for this test run
    public static var testClassList:Array = [];
    // The complete list of all methods for each class
    // in this test run
    private static var testListComplete:Array = [];
    // Copy of the list of tests -- items are popped
    // of to run the tests
    private static var testList:Array = [];
    private static var previousTest:Object = null;
    public static var previousError:Object = false;
    public static var inProgress:Boolean = false;
    public static var waiting:Boolean = false;

    public static function run(files:Array = null):void {
      //['/flash/TestFoo.swf', '/flash/TestBar.swf']
      // If we're passed some files, load 'em up first
      // the loader will call back to this again when
      // it's done, with no args
      if (files) {
        ASTest.loadTestFiles(files);
        return;
      }
      ASTest.getCompleteListOfTests();
      ASTest.start();
    }
  
    public static function loadTestFiles(files:Array):void {
      ASTest.testClassList = [];
      ASTest.testList = [];
      WMLoader.load(files);
    }

    public static function start():void {
      ASTest.testList = ASTest.testListComplete.slice();
      ASTest.inProgress = true;
      // Run recursively in a setTimeout loop so
      // we can implement sleeps and waits
      ASTest.runNextTest();
    }

    public static function runNextTest():void {
      var test:Object = null;
      if (ASTest.waiting) {
        setTimeout(function ():void {
          ASTest.runNextTest.call(ASTest);
        }, 1000);
        return; 
      }
      if (ASTest.previousTest) {
        test = ASTest.previousTest;
        if (ASTest.previousError) {
          res = ExternalInterface.call('wm_asTestResult', ASTest.previousError);
          if (!res) {
            WMLogger.log('FAILURE: ' + ASTest.previousError.message);
          }
        }
        else {
          // Success
          res = ExternalInterface.call('wm_asTestResult', {
            className: test.className,
            methodName: test.methodName
          });
          if (!res) {
            WMLogger.log('SUCCESS');
          }
        }
        ASTest.previousTest = null;
        ASTest.previousError = null;
      }
      if (ASTest.testList.length == 0) {
        ASTest.inProgress = false;
      }
      else {
        test = ASTest.testList.shift();
        ASTest.previousTest = test;
        var res:*;
        WMLogger.log('Running ' + test.className + '.' + test.methodName + ' ...');
        try {
          test.instance[test.methodName].call(test.instance);
        }
        catch (e:Error) {
          ASTest.previousError = e;
        }
        setTimeout(function ():void {
          ASTest.runNextTest.call(ASTest);
        }, ASTest.TEST_INTERVAL);
      }
    }

    public static function getCompleteListOfTests():void {
      var createTestItem:Function = function (item:Object,
          methodName:String):Object {
        return {
          methodName: methodName,
          instance: item.instance,
          className: item.className,
          classDescription: item.classDescription
        };
      }
      var testList:Array = [];
      // No args -- this is being re-invoked from WMLoader
      // now that we have our tests loaded
      for each (var item:Object in ASTest.testClassList) {
        var currTestList:Array = [];
        var descr:XML;
        var hasSetup:Boolean = false;
        var hasTeardown:Boolean = false;
        descr = flash.utils.describeType(
            item.classDescription);
        var meth:*;
        var methods:Object = {};
        for each (meth in descr..method) {
          var methodName:String = meth.@name.toXMLString();
          if (/^test/.test(methodName)) {
            methods[methodName] = item;
          }
          // If there's a setup or teardown somewhere in there
          // flag them so we can prepend/append after adding all
          // the tests
          if (methodName == 'setup') {
            hasSetup = true;
          }
          if (methodName == 'teardown') {
            hasTeardown = true;
          }
        }

        // Normal test methods
        // -----
        // If there's an 'order' array defined, run any tests
        // it contains in the defined order
        var key:String;
        if ('order' in item.instance) {
          for each (key in item.instance.order) {
            if (!key in methods) {
              throw new Error(key + ' is not a method in ' + item.className);
            }
            currTestList.push(createTestItem(methods[key], key));
            delete methods[key];
          }
        }
        // Run any other methods in whatever order
        for (key in methods) {
          currTestList.push(createTestItem(methods[key], key));
        }

        
        // -----
        // Prepend list with setup if one exists
        if (hasSetup) {
          currTestList.unshift(createTestItem(item, 'setup'));
        }
        // Append list with teardown if one exists
        if (hasTeardown) {
          currTestList.push(createTestItem(item, 'teardown'));
        }
        testList = testList.concat.apply(testList, currTestList);
      }
      ASTest.testListComplete = testList;
    }
  }
}


