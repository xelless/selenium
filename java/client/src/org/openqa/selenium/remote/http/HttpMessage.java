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

package org.openqa.selenium.remote.http;

import static com.google.common.base.Charsets.UTF_8;
import static com.google.common.net.HttpHeaders.CONTENT_TYPE;

import com.google.common.base.Supplier;
import com.google.common.collect.Lists;
import com.google.common.collect.Maps;
import com.google.common.collect.Multimap;
import com.google.common.collect.Multimaps;
import com.google.common.net.MediaType;

import java.nio.charset.Charset;
import java.util.Collection;
import java.util.List;
import java.util.Map;

class HttpMessage {

  private final Multimap<String, String> headers = Multimaps.newListMultimap(
      Maps.<String, Collection<String>>newHashMap(), new Supplier<List<String>>() {
        @Override
        public List<String> get() {
          return Lists.newLinkedList();
        }
      });

  private final Map<String, Object> attributes = Maps.newHashMap();

  private byte[] content = new byte[0];

  /**
   * Retrieves a user-defined attribute of this message. Attributes are stored as simple key-value
   * pairs and are not included in a message's serialized form.
   *
   * @param key attribute name
   * @return attribute object
   */
  public Object getAttribute(String key) {
    return attributes.get(key);
  }

  public void setAttribute(String key, Object value) {
    attributes.put(key, value);
  }

  public void removeAttribute(String key) {
    attributes.remove(key);
  }

  public Iterable<String> getHeaderNames() {
    return headers.keySet();
  }

  public Iterable<String> getHeaders(String name) {
    return headers.get(name);
  }

  public String getHeader(String name) {
    Collection<String> values = headers.get(name);
    return values.isEmpty() ? null : values.iterator().next();
  }

  public void setHeader(String name, String value) {
    removeHeader(name);
    headers.put(name, value);
  }

  public void addHeader(String name, String value) {
    headers.put(name, value);
  }

  public void removeHeader(String name) {
    headers.removeAll(name);
  }

  public void setContent(byte[] data) {
    this.content = data;
  }

  public byte[] getContent() {
    return content;
  }

  public String getContentString() {
    Charset charset = UTF_8;
    try {
      String contentType = getHeader(CONTENT_TYPE);
      if (contentType != null) {
        MediaType mediaType = MediaType.parse(contentType);
        charset = mediaType.charset().or(UTF_8);
      }
    } catch (IllegalArgumentException ignored) {
      // Do nothing.
    }
    return new String(content, charset);
  }
}
