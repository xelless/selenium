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

package com.thoughtworks.selenium.webdriven;

import static org.openqa.selenium.remote.server.DriverServlet.SESSIONS_KEY;

import com.google.common.base.Joiner;
import com.google.common.base.Supplier;
import com.google.common.cache.Cache;
import com.google.common.cache.CacheBuilder;
import com.google.common.cache.RemovalListener;
import com.google.common.cache.RemovalNotification;
import com.google.common.collect.ImmutableMap;

import com.thoughtworks.selenium.CommandProcessor;
import com.thoughtworks.selenium.SeleniumException;

import org.openqa.selenium.WebDriver;
import org.openqa.selenium.remote.BrowserType;
import org.openqa.selenium.remote.DesiredCapabilities;
import org.openqa.selenium.remote.SessionId;
import org.openqa.selenium.remote.server.DefaultDriverSessions;
import org.openqa.selenium.remote.server.DriverSessions;
import org.openqa.selenium.remote.server.Session;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;
import java.util.concurrent.TimeUnit;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

/**
 * An implementation of the original selenium rc server endpoint, using a webdriver-backed selenium
 * in order to get things working.
 */
public class WebDriverBackedSeleniumServlet extends HttpServlet {

  private static final Random UUID_SEED = new Random();

  // Prepare the shared set of thingies
  static Cache<SessionId, CommandProcessor> SESSIONS = CacheBuilder.newBuilder()
    .expireAfterAccess(5, TimeUnit.MINUTES)
    .removalListener(new RemovalListener<SessionId, CommandProcessor>() {
      @Override
      public void onRemoval(RemovalNotification<SessionId, CommandProcessor> notification) {
        CommandProcessor holder = notification.getValue();
        if (holder != null) {
          try {
            holder.stop();
          } catch (Exception e) {
            // Nothing sane to do.
          }
        }
      }
    })
    .build();

  private final ImmutableMap<String, DesiredCapabilities> drivers =
    ImmutableMap.<String, DesiredCapabilities>builder()
      .put("*" + BrowserType.FIREFOX_PROXY, DesiredCapabilities.firefox())
      .put("*" + BrowserType.FIREFOX, DesiredCapabilities.firefox())
      .put("*" + BrowserType.CHROME, DesiredCapabilities.firefox())
      .put("*" + BrowserType.FIREFOX_CHROME, DesiredCapabilities.firefox())
      .put("*" + BrowserType.IEXPLORE_PROXY, DesiredCapabilities.internetExplorer())
      .put("*" + BrowserType.SAFARI, DesiredCapabilities.safari())
      .put("*" + BrowserType.IE_HTA, DesiredCapabilities.internetExplorer())
      .put("*" + BrowserType.IEXPLORE, DesiredCapabilities.internetExplorer())
      .put("*" + BrowserType.GOOGLECHROME, DesiredCapabilities.chrome())
      .build();

  private final Supplier<DriverSessions> sessionsSupplier;

  public WebDriverBackedSeleniumServlet() {
    this.sessionsSupplier = new Supplier<DriverSessions>() {
      @Override
      public DriverSessions get() {
        Object attribute = getServletContext().getAttribute(SESSIONS_KEY);
        if (attribute == null) {
          attribute = new DefaultDriverSessions();
        }
        return (DriverSessions) attribute;
      }
    };
  }

  @Override
  protected void doPost(HttpServletRequest req, HttpServletResponse resp)
    throws ServletException, IOException {

    String cmd = req.getParameter("cmd");
    SessionId sessionId = new SessionId(req.getParameter("sessionId"));
    String[] args = deserializeArgs(req);

    if (cmd == null) {
      resp.sendError(HttpServletResponse.SC_NOT_FOUND);
      return;
    }

    StringBuilder printableArgs = new StringBuilder("[");
    Joiner.on(", ").appendTo(printableArgs, args);
    printableArgs.append("]");
    getServletContext().log(
      String.format("Command request: %s%s on session %s", cmd, printableArgs, sessionId));

    if ("getNewBrowserSession".equals(cmd)) {
      // We wait until we see the start command before actually getting the webdriver instance. For
      // now, pre-allocate a session id we can use to refer to the session properly.

      // browserStartCommand, browserURL, extensionJs, optionsString
      final DesiredCapabilities capabilities = new DesiredCapabilities(drivers.get(args[0]));

      try {
        sessionId = sessionsSupplier.get().newSession(capabilities);
        Session session = sessionsSupplier.get().get(sessionId);
        WebDriver driver = session.getDriver();
        CommandProcessor commandProcessor = new WebDriverCommandProcessor(args[1], driver);
        SESSIONS.put(sessionId, commandProcessor);
        sendResponse(resp, sessionId.toString());
      } catch (Exception e) {
        sendError(resp, "Unable to create session: " + e.getMessage());
      }
      return;
    } else if ("testComplete".equals(cmd)) {
      sessionsSupplier.get().deleteSession(sessionId);

      CommandProcessor commandProcessor = SESSIONS.getIfPresent(sessionId);
      if (commandProcessor == null) {
        resp.sendError(HttpServletResponse.SC_NOT_FOUND);
        return;
      }
      SESSIONS.invalidate(sessionId);
      sendResponse(resp, null);
      return;
    }

    // Common case.
      CommandProcessor commandProcessor = SESSIONS.getIfPresent(sessionId);
      if (commandProcessor == null) {
        resp.sendError(HttpServletResponse.SC_NOT_FOUND);
        return;
      }
      try {
        String result = commandProcessor.doCommand(cmd, args);
        sendResponse(resp, result);
      } catch (SeleniumException e) {
        sendError(resp, e.getMessage());
    }
  }

  private void sendResponse(HttpServletResponse resp, String result) throws IOException {
    resp.setStatus(HttpServletResponse.SC_OK);
    resp.setCharacterEncoding(StandardCharsets.UTF_8.displayName());
    resp.getWriter().append("OK").append(result == null ? "" : "," + result);
    resp.flushBuffer();
  }

  private void sendError(HttpServletResponse resp, String result) throws IOException {
    resp.setStatus(HttpServletResponse.SC_OK);
    resp.setCharacterEncoding(StandardCharsets.UTF_8.displayName());
    resp.getWriter().append("ERROR").append(result == null ? "" : ": " + result);
    resp.flushBuffer();
  }

  private String[] deserializeArgs(HttpServletRequest req) {
    // 5 was picked as the maximum length used by the `start` command
    List<String> args = new ArrayList<>();
    for (int i = 0; i < 5; i++) {
      String value = req.getParameter(String.valueOf(i + 1));
      if (value != null) {
        args.add(value);
      } else {
        break;
      }
    }
    return args.toArray(new String[args.size()]);
  }

}
