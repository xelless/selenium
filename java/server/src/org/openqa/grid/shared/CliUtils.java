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

package org.openqa.grid.shared;

import java.io.File;
import java.io.PrintStream;

/**
 * CLI utility methods shared among RC and WebDriver server implementations.
 */
public class CliUtils {

  public static void printWrappedLine(String prefix, String msg) {
    printWrappedLine(System.out, prefix, msg, true);
  }

  public static void printWrappedLine(PrintStream output, String prefix, String msg, boolean first) {
    output.print(prefix);
    if (!first) {
      output.print("  ");
    }
    int defaultWrap = 70;
    int wrap = defaultWrap - prefix.length();
    if (wrap > msg.length()) {
      output.println(msg);
      return;
    }
    String lineRaw = msg.substring(0, wrap);
    int spaceIndex = lineRaw.lastIndexOf(' ');
    if (spaceIndex == -1) {
      spaceIndex = lineRaw.length();
    }
    String line = lineRaw.substring(0, spaceIndex);
    output.println(line);
    printWrappedLine(output, prefix, msg.substring(spaceIndex + 1), false);
  }

}
