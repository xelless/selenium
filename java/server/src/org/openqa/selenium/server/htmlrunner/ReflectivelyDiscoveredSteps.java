// Licensed to the Software Freedom Conservancy (SFC) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The SFC licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

package org.openqa.selenium.server.htmlrunner;


import com.google.common.base.Supplier;
import com.google.common.base.Suppliers;
import com.google.common.collect.ImmutableMap;

import com.thoughtworks.selenium.SeleneseTestBase;
import com.thoughtworks.selenium.Selenium;
import com.thoughtworks.selenium.SeleniumException;

import java.lang.reflect.Method;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;
import java.util.logging.Logger;
import java.util.regex.Matcher;
import java.util.regex.Pattern;


class ReflectivelyDiscoveredSteps implements Supplier<ImmutableMap<String, CoreStepFactory>> {
  private static final Logger LOG = Logger.getLogger("Selenium Core Step");

  private static Supplier<ImmutableMap<String, CoreStepFactory>> REFLECTIVE_STEPS =
    Suppliers.memoize(() -> discover());

  public ImmutableMap<String, CoreStepFactory> get() {
    return REFLECTIVE_STEPS.get();
  }

  private static ImmutableMap<String, CoreStepFactory> discover() {
    ImmutableMap.Builder<String, CoreStepFactory> factories = ImmutableMap.builder();

    Set<String> seenNames = new HashSet<>();
    // seed the seen names with methods we definitely don't want folks accessing
    seenNames.add("addCustomRequestHeader");
    seenNames.add("allowNativeXpath");
    seenNames.add("pause");
    seenNames.add("rollup");
    seenNames.add("setBrowserLogLevel");
    seenNames.add("setExtensionJs");
    seenNames.add("start");
    seenNames.add("stop");

    for (final Method method : Selenium.class.getMethods()) {
      if (!seenNames.add(method.getName())) {
        continue;
      }

      if (method.getParameterCount() > 2) {
        continue;
      }

      CoreStepFactory factory = ((remainingSteps, locator, value) -> (selenium) ->
        invokeMethod(method, selenium, buildArgs(method, locator, value)));

      factories.put(method.getName(), factory);

      // Methods of the form getFoo(target) result in commands:
      // getFoo, assertFoo, verifyFoo, assertNotFoo, verifyNotFoo
      // storeFoo, waitForFoo, and waitForNotFoo.
      final String shortName;
      if (method.getName().startsWith("get")) {
        shortName = method.getName().substring("get".length());
      } else if (method.getName().startsWith("is")) {
        shortName = method.getName().substring("is".length());
      } else {
        shortName = null;
      }

      if (shortName != null && method.getParameterCount() < 2) {
        String negatedName = negateName(shortName);

        factories.put("assert" + shortName, ((remainingSteps, locator, value) -> (selenium) -> {
          Object seen = invokeMethod(method, selenium, buildArgs(method, locator, value));
          String expected = getExpectedValue(method, locator, value);

          SeleneseTestBase.assertEquals(expected, seen);
          return null;
        }));

        factories.put("assert" + negatedName, ((remainingSteps, locator, value) -> (selenium) -> {
          Object seen = invokeMethod(method, selenium, buildArgs(method, locator, value));
          String expected = getExpectedValue(method, locator, value);

          SeleneseTestBase.assertNotEquals(expected, seen);
          return null;
        }));

        factories.put("verify" + shortName, ((remainingSteps, locator, value) -> (selenium) -> {
          Object seen = invokeMethod(method, selenium, buildArgs(method, locator, value));
          String expected = getExpectedValue(method, locator, value);

          // TODO: Not this. Actual verification.
          SeleneseTestBase.assertEquals(expected, seen);
          return null;
        }));

        factories.put("verify" + negatedName, ((remainingSteps, locator, value) -> (selenium) -> {
          Object seen = invokeMethod(method, selenium, buildArgs(method, locator, value));
          String expected = getExpectedValue(method, locator, value);

          // TODO: Not this. Actual verification.
          SeleneseTestBase.assertNotEquals(expected, seen);
          return null;
        }));
      }

      factories.put(
        method.getName() + "AndWait",
        ((remainingSteps, locator, value) -> (selenium -> {
          Object result = invokeMethod(method, selenium, buildArgs(method, locator, value));
          // TODO: Hard coding this is obviously bogus
          selenium.waitForPageToLoad("30000");
          return result;
        })));
    }

    return factories.build();
  }

  private static String negateName(String shortName) {
    Pattern pattern = Pattern.compile("^(.*)Present$");
    Matcher matcher = pattern.matcher(shortName);
    if (matcher.matches()) {
      return matcher.group(1) + "NotPresent";
    }
    return "Not" + shortName;
  }

  private static String[] buildArgs(Method method, String locator, String value) {
    String[] args = new String[method.getParameterCount()];
    switch (method.getParameterCount()) {
      case 2:
        args[1] = value;
        // Fall through

      case 1:
        args[0] = locator;
        break;

      case 0:
        // Nothing to do. Including for completeness.
        break;
    }
    return args;
  }

  private static String getExpectedValue(Method method, String locator, String value) {
    switch (method.getParameterCount()) {
      case 0:
        return locator;

      case 1:
        return value;

      default:
        throw new SeleniumException("Unable to find expected result: " + method.getName());
    }
  }

  private static Object invokeMethod(Method method, Selenium selenium, String[] args) {
    try {
      return method.invoke(selenium, args);
    } catch (ReflectiveOperationException e) {
      for (Throwable cause = e; cause != null; cause = cause.getCause()) {
        if (cause instanceof SeleniumException) {
          throw (SeleniumException) cause;
        }
      }
      throw new CoreRunnerError(
        String.format(
          "Unable to emulate %s %s",
          method.getName(),
          Arrays.asList(args)),
        e);
    }
  }
}
